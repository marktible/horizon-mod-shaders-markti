// Standard Horizon scalar block light; no custom client texture or CPU volume.
vec3 placedLighting(vec3 position, vec3 normal, float vanillaBlock) {
    return vec3(2.7, 1.12, 0.34) * vanillaBlock * BLOCK_LIGHT_STRENGTH;
}
