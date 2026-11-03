override water_ripples: f32 = 0.85;
override water_reflections: bool = true;
override water_mirror: bool = false;
override water_clarity: f32 = 1.0;
override water_caustics: bool = true;

fn ripple_field(p: vec2<f32>) -> vec3<f32> {
    let cell = floor(p);
    let f = fract(p);
    let u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
    let du = 30.0 * f * f * (f * (f - 2.0) + 1.0);
    let a = hash2(cell);
    let b = hash2(cell + vec2<f32>(1.0, 0.0));
    let c = hash2(cell + vec2<f32>(0.0, 1.0));
    let d = hash2(cell + 1.0);
    return vec3<f32>(mix(mix(a, b, u.x), mix(c, d, u.x), u.y),
        mix(b - a, d - c, u.y) * du.x, mix(c - a, d - b, u.x) * du.y);
}

fn ripple_weight(p: vec2<f32>) -> f32 {
    return 1.0 - smoothstep(0.07, 0.55, max(length(dpdx(p)), length(dpdy(p))));
}

fn water_normal(position: vec2<f32>) -> vec3<f32> {
    let time = frame.time;
    let warp = vec2<f32>(sin(dot(position, vec2<f32>(0.041, 0.029)) + time * 0.09),
        cos(dot(position, vec2<f32>(-0.033, 0.047)) - time * 0.07));
    let p = position + warp * 1.7;
    let a = dot(p, vec2<f32>(0.43, 0.27)) + time * 0.73;
    let b = dot(p, vec2<f32>(-0.31, 0.58)) - time * 0.61;
    var slope = vec2<f32>(0.43, 0.27) * cos(a) * 0.055 * (1.0 - smoothstep(0.35, 2.2, fwidth(a)));
    slope += vec2<f32>(-0.31, 0.58) * cos(b) * 0.035 * (1.0 - smoothstep(0.35, 2.2, fwidth(b)));
    let fine = position * 1.35 + warp * 0.25 + vec2<f32>(time * 0.24, -time * 0.17);
    let turn = mat2x2<f32>(0.8, 0.6, -0.6, 0.8);
    let finer = turn * (position * 3.1) + warp * 0.16 + vec2<f32>(-time * 0.19, time * 0.27);
    slope += (ripple_field(fine).yz * (0.030 * ripple_weight(fine)) +
        (ripple_field(finer).yz * turn) * (0.012 * ripple_weight(finer))) * water_ripples;
    return normalize(vec3<f32>(-slope.x, 1.0, -slope.y));
}

fn shade_water(input: MaterialInput, lit: vec3<f32>) -> vec4<f32> {
    let p = input.position;
    let normal = water_normal((p + frame.camera_position).xz);
    let facing = clamp(dot(normalize(-p), normal), 0.0, 1.0);
    let fresnel = 0.020 + 0.98 * pow(1.0 - facing, 5.0);
    let size = vec2<i32>(textureDimensions(opaque_depth));
    let pixel = clamp(vec2<i32>(input.screen * vec2<f32>(size)), vec2<i32>(0), size - 1);
    let depth = textureLoad(opaque_depth, pixel, 0);
    var thickness = 12.0;
    if depth > 0.0 { thickness = clamp(length(reconstruct(input.screen, depth) - p), 0.0, 30.0); }
    let refract_uv = input.screen + normal.xz * min(thickness, 3.0) * 0.002;
    let refract_pixel = clamp(vec2<i32>(refract_uv * vec2<f32>(size)), vec2<i32>(0), size - 1);
    let refract_depth = textureLoad(opaque_depth, refract_pixel, 0);
    let behind = reconstruct(refract_uv, max(refract_depth, 0.000001));
    // Reject foreground banks at the displaced coordinate. Never refract a
    // point above the receiving surface into the water when looking down.
    let safe_pixel = select(pixel, refract_pixel, refract_depth > 0.0 && behind.y < p.y - 0.015);
    var bed = textureLoad(opaque_color, safe_pixel, 0).rgb;
    if water_caustics && depth > 0.0 {
        let bed_point = reconstruct(input.screen, depth) + frame.camera_position;
        let phase = bed_point.xz * 1.1 + vec2<f32>(frame.time * 0.13, -frame.time * 0.10);
        let turn = mat2x2<f32>(0.8, 0.6, -0.6, 0.8);
        let second = turn * bed_point.xz * 1.6 - vec2<f32>(frame.time * 0.11, frame.time * 0.17);
        let field = ripple_field(phase).x * 0.65 + ripple_field(second).x * 0.35;
        let ribbon = 1.0 - smoothstep(0.025, 0.04 + fwidth(field), abs(field - 0.5));
        bed *= 1.0 + ribbon * ripple_weight(phase) * ripple_weight(second) * 0.12 * daylight() * exp(-thickness * 0.12);
    }
    let transmission = exp(-thickness * vec3<f32>(0.11, 0.045, 0.022) / max(water_clarity, 0.1));
    let tint = mix(vec3<f32>(0.025, 0.16, 0.19), input.tint.rgb * vec3<f32>(0.10, 0.22, 0.25), 0.5);
    var color = bed * transmission + tint * (vec3<f32>(1.0) - transmission) * (0.35 + 0.65 * daylight());
    let reflected = reflect(normalize(p), normal);
    var mirror = cloudy_environment(reflected);
    if water_mirror && frame.has_reflection == 1u {
        let uv = clamp(input.screen + normal.xz * 0.018, vec2<f32>(0.002), vec2<f32>(0.998));
        let same_plane = 1.0 - smoothstep(0.04, 0.25, abs(p.y + frame.camera_position.y - frame.water_plane));
        mirror = mix(mirror, textureSampleLevel(reflection, reflection_sampler, uv, 0.0).rgb, same_plane);
    }
    if water_reflections {
        let hit = screen_reflection(p, reflected, vec3<f32>(0.0, 1.0, 0.0), opaque_depth, opaque_color, reflection_steps);
        mirror = mix(mirror, hit.rgb, hit.a);
        color = mix(color, mirror, clamp(fresnel * 0.95, 0.0, 0.92));
    }
    let half_vector = normalize(frame.light_direction + normalize(-p));
    let highlight = pow(max(dot(normal, half_vector), 0.0), 220.0) * daylight() * (1.0 - frame.rain);
    color += vec3<f32>(0.60, 0.53, 0.37) * highlight * min(1.0, lit.r + 0.1);
    // Opaque composition already includes the bed: a second alpha blend
    // would double it and make ripples/transmission change with camera angle.
    return vec4<f32>(fogged(color, p), 1.0);
}
