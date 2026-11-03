uniform sampler2D colortex3;
uniform sampler2D colortex4;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;
uniform vec3 previousCameraPosition;
uniform float frameTime;

vec2 encodeNormal(vec3 n) {
    n /= max(abs(n.x) + abs(n.y) + abs(n.z), 0.00001);
    return n.z >= 0.0 ? n.xy : (vec2(1.0) - abs(n.yx)) * sign(n.xy + 0.000001);
}

vec3 decodeNormal(vec2 oct) {
    vec3 n = vec3(oct, 1.0 - abs(oct.x) - abs(oct.y));
    float fold = max(-n.z, 0.0);
    n.xy += vec2(n.x >= 0.0 ? -fold : fold, n.y >= 0.0 ? -fold : fold);
    return normalize(n);
}

// History stores visibility, view depth and a world-space octahedral normal.
// Reprojection uses BOTH previous matrices, including the previous view bob.
// Depth/normal rejection prevents shadows smearing onto newly exposed faces.
vec4 stableShadow(vec2 coord, float depth, float current) {
    vec3 view = viewPosition(coord, depth);
    vec3 position = (gbufferModelViewInverse * vec4(view, 1.0)).xyz;
    vec3 n = normalize(cross(dFdx(position), dFdy(position)));
    if (dot(n, worldViewOrigin() - position) < 0.0) n = -n;
    float result = current;
#if SHADOW_TEMPORAL == 1
    vec3 previousPosition = position + cameraPosition - previousCameraPosition;
    vec4 previousView = gbufferPreviousModelView * vec4(previousPosition, 1.0);
    vec4 clip = gbufferPreviousProjection * previousView;
    vec2 previousUV = clip.xy / max(clip.w, 0.00001) * 0.5 + 0.5;
    if (clip.w > 0.05 && min(previousUV.x, previousUV.y) > 0.001 && max(previousUV.x, previousUV.y) < 0.999) {
        vec4 history = texture2D(colortex4, previousUV);
        float expectedDepth = -previousView.z;
        float depthError = abs(history.y - expectedDepth);
        float tolerance = max(0.035, expectedDepth * 0.003);
        if (history.y > 0.0 && depthError < tolerance && dot(decodeNormal(history.zw), n) > 0.95) {
            // About 120 ms of history, independent of FPS. Respond faster to
            // large changes such as a moving actor or a sudden time command.
            float currentWeight = 1.0 - exp(-max(frameTime, 0.001) / 0.12);
            currentWeight = max(currentWeight, smoothstep(0.65, 0.95, abs(history.x - current)) * 0.55);
            result = mix(history.x, current, currentWeight);
        }
    }
#endif
    return vec4(result, max(-view.z, 0.0), encodeNormal(n));
}
