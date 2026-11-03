#include "/lib/frame.glsl"
float cloudHash(vec2 p) {
    vec3 q = fract(vec3(p.xyx) * 0.1031);
    q += dot(q, q.yzx + 33.33);
    return fract((q.x + q.y) * q.z);
}
float cloudNoise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(cloudHash(i), cloudHash(i + vec2(1.0, 0.0)), f.x),
               mix(cloudHash(i + vec2(0.0, 1.0)), cloudHash(i + vec2(1.0)), f.x), f.y);
}

// Density and coverage shared by sky shading and celestial cloud occlusion.
vec2 radianceCloudField(vec3 ray) {
    if (ray.y <= 0.025) return vec2(0.0);
    vec2 p = (cameraPosition.xz + ray.xz * max(160.0 - cameraPosition.y, 30.0) / (ray.y + 0.10)) * 0.011;
    p += vec2(frameTimeCounter * 0.006, 0.0);
    float density = cloudNoise(p) * 0.55 + cloudNoise(p * 2.7 + vec2(7.1, 3.9)) * 0.30;
    density += cloudNoise(p * 7.1 - vec2(3.1, 8.4)) * 0.15;
    return vec2(density, smoothstep(0.54, 0.73, density) * smoothstep(0.025, 0.14, ray.y));
}

// Linear-light sky, shared by the dome, aerial perspective and water reflections.
vec3 overworldSky(vec3 ray, bool clouds) {
    float day = daylight();
    vec3 sun = sunDirection();
    float low = 1.0 - smoothstep(0.05, 0.65, abs(sun.y));
    float height = 1.0 - exp(-max(ray.y, 0.0) * 4.0);
    vec3 horizon = mix(vec3(0.008, 0.014, 0.035), vec3(0.42, 0.64, 0.80), day);
    vec3 zenith = mix(vec3(0.0015, 0.0035, 0.014), vec3(0.035, 0.14, 0.40), day);
    vec3 color = mix(horizon, zenith, height);
    // A continuous directional twilight glow replaces the native sunset fan.
    // No latitude/depth threshold clips it in half at the horizon fill.
    float twilight = (1.0 - smoothstep(0.025, 0.22, abs(sun.y))) * smoothstep(-0.20, -0.025, sun.y);
    vec2 sunAzimuth = sun.xz / max(length(sun.xz), 0.001);
    vec2 rayAzimuth = ray.xz / max(length(ray.xz), 0.001);
    float towardSun = pow(max(dot(sunAzimuth, rayAzimuth), 0.0), 4.0);
    color += vec3(0.80, 0.20, 0.035) * twilight * towardSun * exp(-abs(ray.y) * 7.0);
    float facing = max(dot(ray, sun), 0.0);
    color += vec3(1.0, 0.33, 0.08) * pow(facing, 7.0) * low * day * 0.45;
    color += vec3(0.65, 0.42, 0.20) * pow(facing, 80.0) * day * 0.24;
    color = mix(color, mix(vec3(0.035, 0.045, 0.065), vec3(0.28, 0.34, 0.39), day), rainStrength * 0.7);
    if (clouds && ray.y > 0.025) {
        vec2 field = radianceCloudField(ray);
        float density = field.x, shape = field.y;
        vec3 cloudShade = mix(vec3(0.008, 0.013, 0.028), vec3(0.23, 0.30, 0.40), day);
        vec3 cloudLight = mix(vec3(0.025, 0.035, 0.065), vec3(1.55, 1.42, 1.15), day);
        vec3 cloud = mix(cloudShade, cloudLight, smoothstep(0.55, 0.76, density));
        cloud *= 1.0 - rainStrength * 0.5;
        color = mix(color, cloud, shape * 0.94);
    }
    return color;
}

// Native biome fog colors distinguish the five Nether biomes. A small hue
// floor retains dim biome colors; missing/black native fog has a warm fallback.
vec3 netherAtmosphere(vec3 ray) {
    vec3 biome = toLinear(fogColor);
    float peak = max(biome.r, max(biome.g, biome.b));
    vec3 base = peak > 0.0001 ? biome / peak * 0.020 : vec3(0.025, 0.009, 0.004);
    vec3 haze = biome * 0.40 + base;
    float low = 1.0 - smoothstep(-0.4, 0.4, ray.y);
    return haze * (0.70 + low * 0.45);
}

float endStars(vec3 ray) {
    // Octahedral coordinates cover the sphere without a polar singularity.
    vec3 n = ray / max(abs(ray.x) + abs(ray.y) + abs(ray.z), 0.0001);
    vec2 oct = n.z >= 0.0 ? n.xy : (1.0 - abs(n.yx)) * sign(n.xy + 0.000001);
    vec2 grid = oct * 185.0;
    vec2 cell = floor(grid), f = fract(grid);
    float seed = cloudHash(cell);
    vec2 center = vec2(cloudHash(cell + 13.7), cloudHash(cell - 9.3)) * 0.6 + 0.2;
    float footprint = max(length(dFdx(grid)), length(dFdy(grid))) * 0.5;
    float radius2 = 0.0036;
    float filter2 = radius2 + footprint * footprint;
    float star = exp(-dot(f - center, f - center) / filter2) * radius2 / filter2;
    return star * smoothstep(0.986, 0.999, seed);
}

vec3 endAtmosphere(vec3 ray, bool detail) {
    vec3 color = mix(vec3(0.002, 0.001, 0.008), vec3(0.014, 0.006, 0.029),
                     pow(1.0 - abs(ray.y), 3.0));
    if (detail) {
        // A fixed world-oriented nebula, not a pasted sky texture. A shared
        // low-frequency field modulates its width and fine internal wisps.
        vec2 p = vec2(dot(ray, vec3(0.80, 0.0, 0.60)), dot(ray, vec3(-0.25, 0.91, 0.33))) * 3.5;
        float cloud = cloudNoise(p + vec2(4.7, 8.1));
        cloud = cloud * 0.6 + cloudNoise(p * 2.8 - 5.3) * 0.28 + cloudNoise(p * 7.3 + 2.1) * 0.12;
        float band = dot(ray, normalize(vec3(0.12, 0.65, -0.75))) + (cloud - 0.5) * 0.32;
        float mist = exp(-band * band * 18.0) * smoothstep(0.28, 0.78, cloud);
        color += mix(vec3(0.016, 0.007, 0.038), vec3(0.055, 0.018, 0.072), cloud) * mist;
        color += vec3(0.95, 0.80, 1.25) * endStars(ray);
    }
    return color;
}

// Linear HDR atmosphere used consistently by background, fog and SSR misses.
// Solid surfaces request detail=false to avoid painting sky patterns on blocks.
vec3 radianceSky(vec3 ray, bool detail) {
#if RADIANCE_DIMENSION == -1
    return netherAtmosphere(ray);
#elif RADIANCE_DIMENSION == 1
    return endAtmosphere(ray, detail);
#else
    return overworldSky(ray, detail);
#endif
}
