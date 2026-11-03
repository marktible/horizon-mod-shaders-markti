#include "/lib/atmosphere.glsl"
#if RADIANCE_DIMENSION == 0
uniform sampler2D shadowtex0;
uniform sampler2D shadowcolor0;
#include "/lib/shadow_transform.glsl"
#endif
#include "/lib/held_light.glsl"
#include "/lib/placed_light.glsl"

vec3 surfaceNormal(vec3 position, vec3 fallback) {
    // Horizon's non-flat terrain path supplies an up-vector even on walls.
    // Recover the actual face before computing lighting or shadow bias.
    vec3 n = cross(dFdx(position), dFdy(position));
    float magnitude = dot(n, n);
    if (magnitude < 1e-20) return normalize(fallback);
    n *= inversesqrt(magnitude);
    return dot(n, -position) < 0.0 ? -n : n;
}

#if RADIANCE_DIMENSION == 0
float planeShadow(vec3 coord, vec2 sampleUV, vec2 gradient) {
    // Compare against the receiver's depth at THIS texel centre. A single
    // comparison depth for a bilinear footprint self-shadows grazing faces.
    float depth = coord.z + dot(gradient, sampleUV - coord.xy);
    // Nearest raw-depth reads: each software-filter tap already lands at a
    // texel centre. A hardware bilinear comparison would fetch neighbours
    // again, multiplying the work without changing this filter's result.
    float lit = step(depth, texture2D(shadowtex0, sampleUV).r);
    float coverage = texture2D(shadowcolor0, sampleUV).r;
    return 1.0 - (1.0 - lit) * coverage;
}

float visibility(vec3 position, vec3 normal) {
    if (dot(normal, lightDirection()) <= 0.0) return 1.0;
    float worldTexel = 2.0 * SHADOW_DISTANCE / float(SHADOW_RESOLUTION);
    vec4 projected = shadowClip(position + normal * (worldTexel * 0.25));
    vec3 coord = projected.xyz / projected.w * 0.5 + 0.5;
    if (coord.z <= 0.0 || coord.z >= 1.0 || min(coord.x, coord.y) < 0.004 || max(coord.x, coord.y) > 0.996) return 1.0;
    vec3 lightNormal = shadowRotate(normal);
    float nz = (lightNormal.z < 0.0 ? -1.0 : 1.0) * max(abs(lightNormal.z), 0.025);
    vec2 gradient = -lightNormal.xy / nz * vec2(shadowProjection[2].z / shadowProjection[0].x,
                                               shadowProjection[2].z / shadowProjection[1].y);
    // A small world-space tolerance for raster/depth precision; the plane
    // correction handles slope without a large, detached-shadow bias.
    coord.z -= abs(shadowProjection[2].z) * 0.5 * (0.005 + worldTexel * 0.04);
    vec2 pixel = coord.xy * float(SHADOW_RESOLUTION) - 0.5;
    vec2 base = floor(pixel);
    vec2 phase = fract(pixel);
    float texel = 1.0 / float(SHADOW_RESOLUTION);
    float result = 0.0;
#if SHADOW_FILTER == 0
    vec2 uv00 = (base + 0.5) * texel;
    float a = planeShadow(coord, uv00, gradient);
    float b = planeShadow(coord, uv00 + vec2(texel, 0.0), gradient);
    float c = planeShadow(coord, uv00 + vec2(0.0, texel), gradient);
    float d = planeShadow(coord, uv00 + vec2(texel), gradient);
    result = mix(mix(a, b, phase.x), mix(c, d, phase.x), phase.y);
#elif SHADOW_FILTER == 1
    // Three texels across, anchored to the closest centre. Tent weights
    // vanish continuously when a texel enters/leaves the footprint, which
    // softens moving silhouettes without a frame-varying sample pattern.
    base = floor(pixel + 0.5);
    phase = pixel - base;
    float total = 0.0;
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 offset = vec2(float(x), float(y));
            vec2 w = max(vec2(1.5) - abs(offset - phase), vec2(0.0));
            float weight = w.x * w.y;
            result += planeShadow(coord, (base + offset + 0.5) * texel, gradient) * weight;
            total += weight;
        }
    }
    result /= total;
#else
    // A wider, phase-weighted tent for the higher quality settings. Every
    // fetch stays at a texel centre so hardware PCF cannot reintroduce acne.
    float total = 0.0;
    const float radius = 2.0;
    for (int y = -1; y <= 2; y++) {
        for (int x = -1; x <= 2; x++) {
            vec2 offset = vec2(float(x), float(y));
            vec2 w = max(vec2(radius) - abs(offset - phase), vec2(0.0));
            float weight = w.x * w.y;
            result += planeShadow(coord, (base + offset + 0.5) * texel, gradient) * weight;
            total += weight;
        }
    }
    result /= total;
#endif
    // Hide the finite map's boundary gradually; no abrupt square of shadows.
    float edge = max(abs(coord.x - 0.5), abs(coord.y - 0.5)) * 2.0;
    float fade = smoothstep(0.76, 0.98, edge);
    return mix(1.0 - SHADOW_STRENGTH * (1.0 - result), 1.0, fade);
}

#else
float visibility(vec3 position, vec3 normal) { return 1.0; }
#endif

vec3 shadowDirect;
float shadowVisibility;

vec3 illuminated(vec3 albedo, vec3 tint, vec2 lm, vec3 position, vec3 normal) {
    float day = daylight();
    float sky = pow(clamp((lm.y - 0.03125) / 0.9375, 0.0, 1.0), 2.0);
    float block = pow(clamp((lm.x - 0.03125) / 0.9375, 0.0, 1.0), 2.2);
#if RADIANCE_DIMENSION == 0
    float sunHeight = abs(lightDirection().y);
    float golden = (1.0 - smoothstep(0.15, 0.65, sunHeight)) * day;
    vec3 directColor = mix(vec3(2.5, 2.20, 1.72), vec3(3.15, 1.67, 0.72), golden);
    directColor = mix(vec3(0.055, 0.10, 0.22), directColor, day);
    float diffuse = max(dot(normal, lightDirection()), 0.0);
    float shadow = visibility(position, normal);
    vec3 ambient = mix(vec3(0.014, 0.025, 0.06), vec3(0.20, 0.26, 0.36), day) * sky;
    ambient *= 0.80 + max(normal.y, 0.0) * 0.20;
    vec3 direct = directColor * diffuse * sky * (0.16 + 0.67 * day) * (1.0 - rainStrength * 0.85);
#elif RADIANCE_DIMENSION == -1
    // Low warm cavern fill; actual lava, fire and lamps supply the local light.
    // Native biome fog keeps warped forests and soul valleys distinct.
    vec3 ambient = vec3(0.026) + netherAtmosphere(normal) * 0.35;
    ambient *= 0.65 + 0.35 * max(normal.y, 0.0);
    vec3 direct = vec3(0.0);
    float shadow = 1.0;
#else
    // Violet fill and a restrained pearl key keep End stone readable without
    // inventing an Overworld sun or a moving directional shadow map.
    vec3 ambient = vec3(0.085, 0.064, 0.135) * (0.65 + 0.35 * max(normal.y, 0.0));
    vec3 direct = vec3(0.25, 0.22, 0.34) * (0.30 + 0.70 * max(dot(normal, lightDirection()), 0.0));
    float shadow = 1.0;
#endif
    vec3 torch = placedLighting(position, normal, block);
    // Preserve vanilla's biome tint and corner AO, removing its fixed face-direction shade.
    float faceShade = 1.0 - abs(normal.x) * 0.4 - abs(normal.z) * 0.2 - max(-normal.y, 0.0) * 0.5;
#ifdef RADIANCE_ENTITIES
    // Entity colors have no terrain cardinal shade baked into them.
    faceShade = 1.0;
#endif
    vec3 biomeAO = clamp(tint / max(faceShade, 0.5), 0.0, 1.0);
    shadowDirect = toLinear(albedo * biomeAO) * direct * (1.0 - clamp(nightVision, 0.0, 1.0));
    shadowVisibility = shadow;
    vec3 light = vec3(0.008 + screenBrightness * 0.012) + ambient + direct * shadow + torch + heldLighting(position, normal);
    light = mix(light, max(light, vec3(0.95)), clamp(nightVision, 0.0, 1.0));
    return toLinear(albedo * biomeAO) * light;
}

float fogAmount(vec3 position) {
    float distanceToEye = length(position);
    float distanceFog = smoothstep(max(fogStart, 0.0), max(fogEnd, fogStart + 1.0), distanceToEye);
#if RADIANCE_DIMENSION == 0
    float altitude = max(position.y + cameraPosition.y - 64.0, 0.0);
    float haze = (1.0 - exp(-distanceToEye * 0.004)) * exp(-altitude * 0.025) * 0.38 * daylight();
    float amount = max(distanceFog, haze);
#elif RADIANCE_DIMENSION == -1
    // Volumetric-looking distance haze, without a full-screen raymarch.
    float amount = max(distanceFog, 1.0 - exp(-distanceToEye * 0.013));
#else
    // Keep the void dark and nearby islands crisp, then meet the sky at range.
    float amount = max(distanceFog, (1.0 - exp(-distanceToEye * 0.003)) * 0.35);
#endif
    if (isEyeInWater != 0) amount = max(amount, 1.0 - exp(-distanceToEye * 0.055));
    return clamp(amount, 0.0, 1.0);
}

vec3 atmosphericFog(vec3 color, vec3 position) {
    float amount = fogAmount(position);
    vec3 hazeColor = radianceSky(normalize(position), false);
    if (isEyeInWater != 0) hazeColor = toLinear(fogColor);
    return mix(color, hazeColor, clamp(amount, 0.0, 1.0));
}
