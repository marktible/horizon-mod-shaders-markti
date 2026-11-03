override surface_reflections: bool = true;
override ao_strength: f32 = 0.45;
override exposure: f32 = 1.0;
override saturation: f32 = 1.05;

fn post(input: PostInput) -> vec4<f32> {
    var color = input.color.rgb;
    // The last pass can draw at window size while scene_surface is at the
    // internal render size. Map by UV, not output pixels, for native upscaling.
    let surface = surface_at(vec2<i32>(input.uv * frame.resolution));
    if input.depth == 0.0 && frame.dimension != 0 {
        let ray = normalize(reconstruct(input.uv, 0.00001));
        color = environment(ray);
        if frame.dimension == 1 {
            let nebula = noise2(ray.xz * 4.0 + ray.y * 2.0) * noise2(ray.zy * 9.0);
            color += vec3<f32>(0.055, 0.020, 0.075) * nebula;
        }
    }
    if input.depth > 0.0 && surface.present {
        let p = view_position(input.uv, input.depth);
        if ao_strength > 0.0 {
            var occlusion = 0.0;
            let step = 2.2 / frame.resolution;
            for (var i = 0; i < 6; i++) {
                let angle = f32(i) * 2.399963;
                let uv = input.uv + vec2<f32>(cos(angle), sin(angle)) * step * (1.0 + f32(i) * 0.65);
                let depth = depth_at(uv);
                if depth > 0.0 {
                    let delta = view_position(uv, depth) - p;
                    let distance = length(delta);
                    occlusion += max(dot(surface.normal, delta) / max(distance, 0.001) - 0.15, 0.0) *
                        (1.0 - smoothstep(0.1, 1.8, distance));
                }
            }
            color *= 1.0 - occlusion * ao_strength / 6.0;
        }
        if surface_reflections && surface.smoothness > 0.10 {
            let direction = reflect(normalize(p), surface.normal);
            var reflection_color = environment(direction);
            let hit = screen_reflection(p, direction, surface.normal, scene_depth, scene_color, 64);
            let confidence = hit.a;
            reflection_color = mix(reflection_color, hit.rgb, confidence);
            let facing = max(dot(surface.normal, normalize(-p)), 0.0);
            let fresnel = mix(0.035, 0.55, surface.data) + (1.0 - surface.data * 0.55) * pow(1.0 - facing, 5.0);
            // Misses have a small environment contribution; do not paint bright
            // clouds on indoor metals or make rough obsidian act like a mirror.
            let weight = fresnel * surface.smoothness * mix(0.025, 0.75, confidence);
            color = mix(color, reflection_color, clamp(weight, 0.0, 0.65));
        }
    }
    color *= exposure;
    let luma = dot(color, vec3<f32>(0.2126, 0.7152, 0.0722));
    color = mix(vec3<f32>(luma), color, saturation);
    return vec4<f32>(clamp(color, vec3<f32>(0.0), vec3<f32>(1.0)), input.color.a);
}
