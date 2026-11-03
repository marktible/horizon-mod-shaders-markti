#version 120
#include "/lib/settings.glsl"
#include "/lib/lighting.glsl"
#include "/lib/ssr.glsl"
#include "/lib/material_id.glsl"
#include "/lib/water.glsl"
uniform sampler2D texture;
varying vec2 uv;
varying vec2 lightUV;
varying vec4 vertexColor;
varying vec3 worldPosition;
varying vec3 worldNormal;
varying float materialId;

void main() {
    vec4 texel = texture2D(texture, uv);
    vec3 normal = surfaceNormal(worldPosition, worldNormal);
    float id = blockMaterial(materialId, uv);
    // The 2026-10-30 client supplies -1 IDs and a placeholder normal for translucent
    // terrain. Water is its biome-tinted translucent material; glass/ice have neutral
    // vertex tints. Keep explicit IDs on render paths that do provide them.
    float tintChroma = max(vertexColor.r, max(vertexColor.g, vertexColor.b)) - min(vertexColor.r, min(vertexColor.g, vertexColor.b));
    bool isWater = abs(id - 10001.0) < 0.5 || (id < 1.0 && tintChroma > 0.035);
    vec3 geometricNormal = normal;
    vec3 color;
    float alpha = texel.a * vertexColor.a;
    if (isWater && normal.y > 0.5) {
        vec3 p = worldPosition + cameraPosition;
        normal = waterNormal(p.xz, frameTimeCounter);
        vec3 viewDir = normalize(worldViewOrigin() - worldPosition);
        float fresnel = 0.02 + 0.98 * pow(1.0 - max(dot(normal, viewDir), 0.0), 5.0);
        vec3 reflected = reflect(-viewDir, normal);
        vec3 viewPoint = (gbufferModelView * vec4(worldPosition, 1.0)).xyz;
        vec2 screenUV = gl_FragCoord.xy / vec2(viewWidth, viewHeight);
        vec3 bedPoint = viewPosition(screenUV, texture2D(depthtex1, screenUV).r);
        float thickness = bedPoint.z < viewPoint.z ? length(bedPoint - viewPoint) : 0.0;
        vec3 bedWorld = (gbufferModelViewInverse * vec4(bedPoint, 1.0)).xyz;
        vec2 bedUV = screenUV;
#if WATER_REFRACTION == 1
        // Bend relative to the flat interface, so waves move the submerged
        // scene without sliding shore geometry. Full projection includes view
        // bob, and candidate depth must remain behind AND below the surface.
        vec3 bent = refract(-viewDir, normal, 0.75188);
        vec3 flatRay = refract(-viewDir, geometricNormal, 0.75188);
        float column = max(worldPosition.y - bedWorld.y, 0.0);
        vec3 offset = (bent / max(-bent.y, 0.15) - flatRay / max(-flatRay.y, 0.15)) * min(column, 6.0);
        vec4 bentClip = gbufferProjection * vec4(viewPoint + mat3(gbufferModelView) * offset, 1.0);
        vec2 deltaUV = bentClip.w > 0.08 ? bentClip.xy / bentClip.w * 0.5 + 0.5 - screenUV : vec2(0.0);
        deltaUV *= min(1.0, 0.025 / max(length(deltaUV), 0.00001));
        vec2 candidateUV = screenUV + deltaUV * smoothstep(0.0, 0.35, thickness);
        vec3 candidate = viewPosition(candidateUV, texture2D(depthtex1, candidateUV).r);
        vec3 candidateWorld = (gbufferModelViewInverse * vec4(candidate, 1.0)).xyz;
        float edge = min(min(candidateUV.x, candidateUV.y), min(1.0 - candidateUV.x, 1.0 - candidateUV.y));
        if (edge > 0.001 && candidate.z < viewPoint.z - 0.02 && candidateWorld.y < worldPosition.y - 0.03) {
            bedUV = candidateUV;
            bedPoint = candidate;
            bedWorld = candidateWorld;
            thickness = length(bedPoint - viewPoint);
        }
#endif
        vec3 transmission = exp(-min(thickness, 48.0) * vec3(0.28, 0.095, 0.065) / WATER_CLARITY);
        vec3 bed = texture2D(colortex1, bedUV).rgb;
        float sky = pow(clamp((lightUV.y - 0.03125) / 0.9375, 0.0, 1.0), 2.0);
#if WATER_CAUSTICS == 1
        float shallow = 1.0 - smoothstep(2.0, 8.0, thickness);
        if (shallow > 0.0 && daylight() > 0.0) {
            bed *= 1.0 + waterCaustics((bedWorld + cameraPosition).xz, frameTimeCounter)
                         * shallow * daylight() * sky * (1.0 - rainStrength) * 0.22;
        }
#endif
        // Scatter is lit by local sky visibility, so covered water stays dark.
        vec3 deepWater = vec3(0.012, 0.085, 0.105) * (0.08 + 0.92 * daylight()) * sky;
        vec3 refractedColor = bed * transmission + deepWater * (vec3(1.0) - transmission);
        vec4 terrainReflection = reflectedTerrain(worldPosition + geometricNormal * 0.08, reflected, worldPosition.y);
        vec3 reflection = terrainReflection.rgb;
        if (terrainReflection.a < 0.995) reflection = mix(radianceSky(reflected, true) * sky, terrainReflection.rgb, terrainReflection.a);
        color = mix(refractedColor, reflection, fresnel * WATER_REFLECTION);
        // A tighter highlight breaks into wave glints instead of a large white
        // smear. Widen by the pixel's normal variance to keep tiny glints stable.
        vec3 normalDx = dFdx(normal), normalDy = dFdy(normal);
        float variance = max(dot(normalDx, normalDx), dot(normalDy, normalDy));
        float glintPower = 900.0 / (1.0 + 900.0 * variance);
        float sparkle = pow(max(dot(normal, normalize(viewDir + lightDirection())), 0.0), glintPower) * (glintPower / 900.0);
        // Shadow-map reads are only needed inside a visible sun/moon glint. The
        // underlying opaque riverbed already receives its terrain shadows.
        if (sparkle > 0.00001 && (daylight() > 0.0 || moonlight() > 0.0)) {
            vec3 glint = vec3(3.8, 2.7, 1.3) * daylight() + vec3(0.12, 0.18, 0.32) * moonlight();
            color += glint * sparkle * visibility(worldPosition, geometricNormal) * (1.0 - rainStrength * 0.8);
        }
        alpha = 1.0;
    } else {
        color = illuminated(texel.rgb, vertexColor.rgb, lightUV, worldPosition, normal);
        if (abs(id - 10002.0) < 0.5 || abs(id - 10004.0) < 0.5 || abs(id - 10005.0) < 0.5) {
            color = max(color, toLinear(texel.rgb * vertexColor.rgb) * 2.6);
        }
    }
    if (alpha < 0.01) discard;
#if SURFACE_REFLECTIONS == 1
    /* DRAWBUFFERS:025 */
#else
    /* DRAWBUFFERS:02 */
#endif
    gl_FragData[0] = vec4(atmosphericFog(color, worldPosition), alpha);
    gl_FragData[1] = vec4(isWater ? 1.0 : 0.0, 0.0, 0.0, 1.0);
#if SURFACE_REFLECTIONS == 1
    // Water and other translucent surfaces own this depth pixel; clear the
    // opaque material underneath so it cannot acquire the wrong reflection.
    gl_FragData[2] = vec4(0.0, 0.0, 0.0, 1.0);
#endif
}
