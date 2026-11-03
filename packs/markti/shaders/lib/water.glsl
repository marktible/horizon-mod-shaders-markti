// World-anchored wind waves. Filter each phase by its screen footprint so
// distant, grazing water converges to a flat normal instead of a dot lattice.
float waveWeight(float phase) {
    return 1.0 - smoothstep(0.35, 2.2, fwidth(phase));
}

float rippleHash(vec2 p) {
    vec3 q = fract(vec3(p.xyx) * 0.1031);
    q += dot(q, q.yzx + 33.33);
    return fract((q.x + q.y) * q.z);
}

// Value-noise height and its analytic gradient. Two independently moving,
// rotated scales give irregular capillary ripples, without a sine-wave grid.
vec3 rippleField(vec2 p) {
    vec2 cell = floor(p), f = fract(p);
    // Quintic interpolation keeps both slope and curvature continuous at cell
    // edges; cubic value noise made the moving highlights look like tiles.
    vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
    vec2 du = 30.0 * f * f * (f * (f - 2.0) + 1.0);
    float a = rippleHash(cell), b = rippleHash(cell + vec2(1.0, 0.0));
    float c = rippleHash(cell + vec2(0.0, 1.0)), d = rippleHash(cell + vec2(1.0));
    float height = mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
    return vec3(height, mix(b - a, d - c, u.y) * du.x, mix(c - a, d - b, u.x) * du.y);
}

float rippleWeight(vec2 p) {
    float footprint = max(length(dFdx(p)), length(dFdy(p)));
    return 1.0 - smoothstep(0.07, 0.55, footprint);
}

vec3 waterNormal(vec2 position, float time) {
    vec2 warp = vec2(sin(dot(position, vec2(0.041, 0.029)) + time * 0.09),
                     cos(dot(position, vec2(-0.033, 0.047)) - time * 0.07));
    vec2 p = position + warp * 1.7;
    float a = dot(p, vec2(0.43, 0.27)) + time * 0.73;
    float b = dot(p, vec2(-0.31, 0.58)) - time * 0.61;
    float c = dot(p, vec2(0.91, -0.77)) + time * 0.93;
    vec2 slope = vec2(0.43, 0.27) * cos(a) * (0.055 * waveWeight(a));
    slope += vec2(-0.31, 0.58) * cos(b) * (0.035 * waveWeight(b));
    slope += vec2(0.91, -0.77) * cos(c) * (0.012 * waveWeight(c));
    vec2 fine = position * 1.35 + warp * 0.25 + vec2(time * 0.24, -time * 0.17);
    mat2 turn = mat2(0.8, 0.6, -0.6, 0.8);
    vec2 finer = turn * (position * 3.1) + warp * 0.16 + vec2(-time * 0.19, time * 0.27);
    vec2 ripple = rippleField(fine).yz * (0.030 * rippleWeight(fine));
    ripple += (rippleField(finer).yz * turn) * (0.012 * rippleWeight(finer));
    slope += ripple * WATER_RIPPLE_STRENGTH;
    return normalize(vec3(-slope.x, 1.0, -slope.y));
}

// Subtle moving light ribbons on shallow beds, filtered in world space. This
// modulates existing bed light rather than making an unlit cave floor glow.
float waterCaustics(vec2 position, float time) {
    vec2 p = position * 1.1 + vec2(time * 0.13, -time * 0.10);
    vec2 q = mat2(0.8, 0.6, -0.6, 0.8) * position * 1.6 - vec2(time * 0.11, time * 0.17);
    float field = rippleField(p).x * 0.65 + rippleField(q).x * 0.35;
    float width = max(fwidth(field), 0.012);
    float ribbon = 1.0 - smoothstep(0.025, 0.025 + width, abs(field - 0.5));
    return ribbon * rippleWeight(p) * rippleWeight(q);
}
