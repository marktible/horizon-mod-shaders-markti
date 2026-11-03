vec2 surfaceOct(vec3 n) {
    n /= max(abs(n.x) + abs(n.y) + abs(n.z), 0.00001);
    vec2 oct = n.z >= 0.0 ? n.xy : (vec2(1.0) - abs(n.yx)) * sign(n.xy + 0.000001);
    return oct * 0.5 + 0.5;
}

vec3 surfaceNormalFromOct(vec2 encoded) {
    vec2 oct = encoded * 2.0 - 1.0;
    vec3 n = vec3(oct, 1.0 - abs(oct.x) - abs(oct.y));
    float fold = max(-n.z, 0.0);
    n.xy += vec2(n.x >= 0.0 ? -fold : fold, n.y >= 0.0 ? -fold : fold);
    return normalize(n);
}

float surfaceType(float id) {
    // Contiguous block.properties groups, zero for matte terrain/entities.
    return id >= 10200.0 && id < 10207.0 ? floor(id - 10199.0 + 0.5) : 0.0;
}

vec3 surfaceF0(float kind) {
    if (kind < 1.5) return vec3(0.035); // Obsidian: restrained stone sheen
    if (kind < 2.5) return vec3(0.64, 0.66, 0.68); // Satin iron/netherite
    if (kind < 3.5) return vec3(0.95, 0.68, 0.22); // Gold
    if (kind < 4.5) return vec3(0.85, 0.43, 0.22); // Unoxidized copper
    if (kind < 5.5) return vec3(0.10, 0.17, 0.18); // Diamond
    if (kind < 6.5) return vec3(0.09, 0.17, 0.10); // Emerald
    return vec3(0.055); // Polished stone/quartz
}

float surfaceRoughness(float kind) {
    if (kind < 1.5) return 0.30;
    if (kind < 2.5) return 0.36;
    if (kind < 3.5) return 0.19;
    if (kind < 4.5) return 0.25;
    if (kind < 6.5) return 0.16;
    return 0.38;
}

float surfaceReflectionStrength(float kind) {
    if (kind < 1.5) return 0.55;
    if (kind < 2.5) return 0.68;
    return 1.0;
}
