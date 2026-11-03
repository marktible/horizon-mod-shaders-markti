uniform int heldItemId;
uniform int heldItemId2;
uniform int heldBlockLightValue;
uniform int heldBlockLightValue2;

vec3 heldColor(int item) {
#if COLORED_LIGHTS == 0
    return vec3(1.5);
#else
    if (item == 11002) return vec3(0.32, 1.55, 2.7); // Soul fire
    if (item == 11003) return vec3(3.8, 0.15, 0.08); // Redstone
    if (item == 11004) return vec3(0.4, 2.0, 1.3); // Sea lantern
    if (item == 11005) return vec3(1.7, 0.7, 2.7); // Amethyst
    if (item == 11006) return vec3(3.2, 0.85, 0.1); // Lava/magma
    if (item == 11007) return vec3(1.5, 1.6, 2.0); // End rod
    if (item == 11008) return vec3(1.25, 1.9, 0.4); // Lichen/berries
    if (item == 11009) return vec3(2.5, 1.15, 0.65); // Shroomlight
    if (item == 11011) return vec3(0.3, 1.7, 2.0); // Glow ink
    if (item == 11012) return vec3(0.36, 2.7, 1.05); // Copper flame
    return vec3(2.5, 1.25, 0.45);
#endif
}

float heldLevel(int item, int vanillaLevel) {
    if (item == 11010) return max(float(vanillaLevel), 10.0);
    if (item == 11011) return max(float(vanillaLevel), 8.0);
    if (item == 11008) return max(float(vanillaLevel), 7.0);
    return float(vanillaLevel);
}

vec3 handLight(vec3 position, vec3 normal, int item, int vanillaLevel, float side) {
    float level = heldLevel(item, vanillaLevel);
    if (level <= 0.0) return vec3(0.0);
    vec3 lamp = (gbufferModelViewInverse * vec4(side * 0.28, -0.30, -0.45, 1.0)).xyz;
    vec3 delta = lamp - position;
    float distanceToLight = length(delta);
    float falloff = max(1.0 - distanceToLight / max(level * 0.65, 0.1), 0.0);
    float facing = 0.20 + 0.80 * max(dot(normal, delta / max(distanceToLight, 0.001)), 0.0);
    return heldColor(item) * (falloff * falloff * facing * level / 15.0 * 2.0);
}

vec3 heldLighting(vec3 position, vec3 normal) {
#if HELD_LIGHTS == 1
    return handLight(position, normal, heldItemId, heldBlockLightValue, 1.0)
         + handLight(position, normal, heldItemId2, heldBlockLightValue2, -1.0);
#else
    return vec3(0.0);
#endif
}
