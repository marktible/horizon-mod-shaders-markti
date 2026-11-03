fn daylight() -> f32 {
    if frame.dimension != 0 { return 0.0; }
    return smoothstep(-0.08, 0.12, frame.sun_direction.y);
}

fn linear_color(c: vec3<f32>) -> vec3<f32> {
    return pow(max(c, vec3<f32>(0.0)), vec3<f32>(2.2));
}

fn display_color(c: vec3<f32>) -> vec3<f32> {
    return pow(max(c, vec3<f32>(0.0)), vec3<f32>(1.0 / 2.2));
}

fn mapped_light(c: vec3<f32>) -> vec3<f32> {
    // Native terrain shares the official client's display-range world target.
    // Compress the material's linear lighting before the shared post passes.
    return display_color(c / (vec3<f32>(1.0) + c * 0.35));
}

fn hash2(p: vec2<f32>) -> f32 {
    let q = fract(vec3<f32>(p.x, p.y, p.x) * 0.1031);
    let r = q + dot(q, q.yzx + 33.33);
    return fract((r.x + r.y) * r.z);
}

fn noise2(p: vec2<f32>) -> f32 {
    let cell = floor(p);
    let f = fract(p);
    let u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash2(cell), hash2(cell + vec2<f32>(1.0, 0.0)), u.x),
        mix(hash2(cell + vec2<f32>(0.0, 1.0)), hash2(cell + 1.0), u.x), u.y);
}

fn environment(direction: vec3<f32>) -> vec3<f32> {
    if frame.dimension == -1 {
        return mix(frame.fog_color * 0.7, vec3<f32>(0.045, 0.018, 0.025), max(direction.y, 0.0));
    }
    if frame.dimension == 1 {
        return mix(vec3<f32>(0.025, 0.014, 0.055), vec3<f32>(0.065, 0.035, 0.12), max(direction.y, 0.0));
    }
    let day = daylight();
    let up = pow(clamp(direction.y, 0.0, 1.0), 0.45);
    let horizon = mix(vec3<f32>(0.035, 0.045, 0.085), vec3<f32>(0.68, 0.81, 0.91), day);
    let zenith = mix(vec3<f32>(0.005, 0.010, 0.030), vec3<f32>(0.20, 0.48, 0.75), day);
    var color = mix(horizon, zenith, up);
    let twilight = (1.0 - smoothstep(0.02, 0.30, abs(frame.sun_direction.y))) *
        smoothstep(-0.12, -0.01, frame.sun_direction.y);
    let toward_sun = pow(max(dot(direction, normalize(vec3<f32>(frame.sun_direction.x, 0.05, frame.sun_direction.z))), 0.0), 6.0);
    color += vec3<f32>(0.34, 0.085, 0.025) * twilight * toward_sun * exp(-abs(direction.y) * 8.0);
    color = mix(color, frame.fog_color * 0.75, frame.rain * 0.65);
    return color;
}

fn cloudy_environment(d: vec3<f32>) -> vec3<f32> {
    var color = environment(d);
    if frame.dimension == 0 && d.y > 0.015 {
        let cloud = d.xz * (0.24 / max(d.y, 0.035)) + frame.camera_position.xz * 0.0008 + vec2<f32>(frame.time * 0.004, 0.0);
        let n = noise2(cloud) * 0.65 + noise2(cloud * 2.13) * 0.25 + noise2(cloud * 4.47) * 0.10;
        let coverage = smoothstep(0.50 - frame.rain * 0.12, 0.70, n) * smoothstep(0.015, 0.13, d.y);
        let cloud_color = mix(vec3<f32>(0.035, 0.045, 0.085), vec3<f32>(0.91, 0.92, 0.90), daylight());
        color = mix(color, cloud_color, coverage * 0.88);
    }
    return color;
}

fn reconstruct(uv: vec2<f32>, depth: f32) -> vec3<f32> {
    let view = frame.projection_inverse * vec4<f32>(uv.x * 2.0 - 1.0, 1.0 - uv.y * 2.0, depth, 1.0);
    return (frame.view_inverse * vec4<f32>(view.xyz / view.w, 1.0)).xyz;
}

fn screen_position(p: vec3<f32>) -> vec3<f32> {
    let clip = frame.projection * frame.view * vec4<f32>(p, 1.0);
    let uv = vec2<f32>(clip.x, -clip.y) / max(clip.w, 0.00001) * 0.5 + 0.5;
    return vec3<f32>(uv, clip.w);
}

fn fogged(color: vec3<f32>, p: vec3<f32>) -> vec3<f32> {
    let distance = length(p);
    var amount = smoothstep(max(frame.fog_start, 0.0), max(frame.fog_end, frame.fog_start + 1.0), distance);
    if frame.dimension == -1 { amount = max(amount, 1.0 - exp(-distance * 0.012)); }
    if frame.dimension == 1 { amount = max(amount, (1.0 - exp(-distance * 0.003)) * 0.35); }
    if frame.eye_in == 1u { amount = max(amount, 1.0 - exp(-distance * 0.055)); }
    let haze = select(environment(normalize(p)), frame.fog_color, frame.eye_in != 0u);
    return mix(color, haze, clamp(amount, 0.0, 1.0));
}
