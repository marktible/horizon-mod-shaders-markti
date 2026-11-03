#ifndef SSR_TRACE_STEPS
#define SSR_TRACE_STEPS SSR_STEPS
#endif
#ifndef SSR_COLOR
#define SSR_COLOR colortex1
#define SSR_DEPTH depthtex1
#endif
uniform sampler2D SSR_COLOR;
uniform sampler2D SSR_DEPTH;

// Screen-space rays use the procedural environment when geometry is unavailable.
vec4 reflectionFallback(vec3 origin,vec3 direction) { return vec4(0.0); }

// Perspective-correct screen-space traversal. Uniform pixel steps avoid skipping
// thin silhouettes near the eye and avoid wasting steps on distant subpixel travel.
vec4 reflectedSurface(vec3 origin, vec3 rayDirection, vec3 planeNormal, float planeOffset, float roughness) {
    vec3 start = (gbufferModelView * vec4(origin, 1.0)).xyz;
    vec3 directionView = normalize(mat3(gbufferModelView) * rayDirection);
    vec4 clipStart = gbufferProjection * vec4(start, 1.0);
    vec4 clipDirection = gbufferProjection * vec4(directionView, 0.0);
    // Clip against the actual moving lens, not z=-near in the unbobbed
    // coordinate system. A negative endpoint w folds the perspective ray
    // across the camera and produces large triangular reflection streaks.
    if (clipStart.w <= 0.08) return reflectionFallback(origin,rayDirection);
    float distanceLimit = 52.0;
    if (clipDirection.w < 0.0) distanceLimit = min(distanceLimit, (0.08 - clipStart.w) / clipDirection.w);
    float nearStart = clipStart.z + clipStart.w;
    float nearDirection = clipDirection.z + clipDirection.w;
    if (nearStart <= 0.0) return reflectionFallback(origin,rayDirection);
    if (nearDirection < 0.0) distanceLimit = min(distanceLimit, nearStart * 0.999 / -nearDirection);
    if (distanceLimit < 0.1) return reflectionFallback(origin,rayDirection);
    vec3 end = start + directionView * distanceLimit;
    vec4 clipEnd = gbufferProjection * vec4(end, 1.0);
    float inverseStartW = 1.0 / clipStart.w;
    float inverseEndW = 1.0 / clipEnd.w;
    vec3 qStart = start * inverseStartW;
    vec3 qEnd = end * inverseEndW;
    vec2 uvStart = clipStart.xy * inverseStartW * 0.5 + 0.5;
    vec2 uvEnd = clipEnd.xy * inverseEndW * 0.5 + 0.5;
    vec2 span = uvEnd - uvStart;
    float screenLimit = 1.0;
    if (span.x > 0.00001) screenLimit = min(screenLimit, (0.999 - uvStart.x) / span.x);
    if (span.x < -0.00001) screenLimit = min(screenLimit, (0.001 - uvStart.x) / span.x);
    if (span.y > 0.00001) screenLimit = min(screenLimit, (0.999 - uvStart.y) / span.y);
    if (span.y < -0.00001) screenLimit = min(screenLimit, (0.001 - uvStart.y) / span.y);
    if (screenLimit <= 0.0 || length(span * screenLimit * vec2(viewWidth, viewHeight)) < 1.5) return reflectionFallback(origin,rayDirection);
    float previousScreen = 0.0;
    float previousDelta = -1.0;
    int candidates = 0;
    for (int i = 0; i < SSR_TRACE_STEPS; i++) {
        // Spend more of the fixed budget near the receiver, where thin mob
        // legs and silhouettes occupy little ray depth. Linear long-range
        // strides skipped them and left striped or detached reflections.
        float progress = float(i + 1) / float(SSR_TRACE_STEPS);
        float f = screenLimit * progress * progress;
        vec2 coord = uvStart + span * f;
        float pointDepth = -mix(qStart.z, qEnd.z, f) / mix(inverseStartW, inverseEndW, f);
        float sceneDepth = texture2D(SSR_DEPTH, coord).r;
        float delta = pointDepth + viewPosition(coord, sceneDepth).z;
        if (sceneDepth < 0.99999 && delta > 0.0 && delta < 2.5 + pointDepth * 0.12 && previousDelta < 0.0 && candidates < 2) {
            candidates++;
            float lower = previousScreen, upper = f;
            for (int refine = 0; refine < 6; refine++) {
                float middle = (lower + upper) * 0.5;
                float testPointDepth = -mix(qStart.z, qEnd.z, middle) / mix(inverseStartW, inverseEndW, middle);
                vec2 testUV = uvStart + span * middle;
                float testDepth = -viewPosition(testUV, texture2D(SSR_DEPTH, testUV).r).z;
                if (testPointDepth > testDepth) upper = middle;
                else lower = middle;
            }
            float hitScreen = (lower + upper) * 0.5;
            vec3 hit = mix(qStart, qEnd, hitScreen) / mix(inverseStartW, inverseEndW, hitScreen);
            float travel = length(hit - start);
            vec2 hitUV = uvStart + span * hitScreen;
            vec3 scenePoint = viewPosition(hitUV, texture2D(SSR_DEPTH, hitUV).r);
            vec3 sceneWorld = (gbufferModelViewInverse * vec4(scenePoint, 1.0)).xyz;
            float agreement = abs(scenePoint.z - hit.z);
            // Depth discontinuities can cross a submerged plant or riverbed
            // without intersecting its geometry. Those pixels cannot reflect
            // on the upper surface; reject them instead of stretching them.
            if (agreement < 0.12 + travel * 0.008 && dot(sceneWorld, planeNormal) >= planeOffset + 0.015 && travel > 0.10) {
                float edge = min(min(hitUV.x, hitUV.y), min(1.0 - hitUV.x, 1.0 - hitUV.y));
                float confidence = smoothstep(0.0, 0.055, edge) * (1.0 - smoothstep(38.0, 53.0, travel));
#ifdef SSR_MIPS
                // A filtered cone footprint makes polished stone softer than
                // obsidian/metals, without frame-varying random ray directions.
                float lod = roughness * roughness * (8.0 + log2(1.0 + travel * 0.10));
                vec3 reflectedColor = mix(texture2DLod(SSR_COLOR, hitUV, floor(lod)).rgb,
                                          texture2DLod(SSR_COLOR, hitUV, floor(lod) + 1.0).rgb, fract(lod));
#else
                vec2 texel = (0.65 + roughness * 4.0) / vec2(viewWidth, viewHeight);
                vec2 offsets[4] = vec2[4](vec2(texel.x, 0.0), vec2(-texel.x, 0.0), vec2(0.0, texel.y), vec2(0.0, -texel.y));
                vec3 reflectedColor = texture2D(SSR_COLOR, hitUV).rgb * 0.5;
                float colorWeight = 0.5;
                for (int tap = 0; tap < 4; tap++) {
                    vec2 sampleUV = hitUV + offsets[tap];
                    float sampleZ = viewPosition(sampleUV, texture2D(SSR_DEPTH, sampleUV).r).z;
                    // Keep sky/terrain color out of a foreground entity's
                    // reflection at silhouette edges, including dark mobs.
                    float weight = abs(sampleZ - scenePoint.z) < 0.12 + travel * 0.008 ? 0.125 : 0.0;
                    reflectedColor += texture2D(SSR_COLOR, sampleUV).rgb * weight;
                    colorWeight += weight;
                }
                reflectedColor /= colorWeight;
#endif

                return vec4(reflectedColor, confidence);
            }
        }
        previousScreen = f;
        previousDelta = delta;
    }
    return reflectionFallback(origin,rayDirection);
}

vec4 reflectedTerrain(vec3 origin, vec3 rayDirection, float surfaceHeight) {
    return reflectedSurface(origin, rayDirection, vec3(0.0, 1.0, 0.0), surfaceHeight, 0.0);
}
