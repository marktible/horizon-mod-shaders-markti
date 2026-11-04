override colored_lights: bool = true;
override block_light_strength: f32 = 1.0;
override shadow_softness: f32 = 1.0;
override pbr_materials: bool = true;
override soft_shadows: bool = true;

fn shadow_sample(uv: vec2<f32>, depth: f32) -> vec3<f32> {
    let opaque = textureSampleCompareLevel(shadow_map, shadow_sampler, uv, depth);
    if opaque <= 0.0001 { return vec3<f32>(0.0); }
    let translucent = textureSampleCompareLevel(shadow_map_translucent, shadow_sampler, uv, depth);
    if translucent >= 0.9999 { return vec3<f32>(opaque); }
    let size = vec2<i32>(textureDimensions(shadow_color));
    let pixel = clamp(vec2<i32>(uv * vec2<f32>(size)), vec2<i32>(0), size - 1);
    let glass = textureLoad(shadow_color, pixel, 0);
    let transmission = mix(vec3<f32>(1.0), max(glass.rgb, vec3<f32>(0.025)),
        clamp(glass.a * 1.4, 0.0, 1.0));
    return opaque * mix(transmission, vec3<f32>(1.0), translucent);
}

fn shadow_tint(position: vec3<f32>, normal: vec3<f32>) -> vec3<f32> {
    if frame.has_shadow == 0u || frame.dimension != 0 { return vec3<f32>(1.0); }
    let bias = max(frame.shadow_center_texel * 0.65, 0.015);
    var coord = shadow_position(position + normal * bias);
    if any(coord < vec3<f32>(0.002)) || any(coord > vec3<f32>(0.998)) { return vec3<f32>(1.0); }
    coord.z -= 0.000025;
    let edge = max(abs(coord.x - 0.5), abs(coord.y - 0.5)) * 2.0;
    if !soft_shadows {
        return mix(shadow_sample(coord.xy, coord.z), vec3<f32>(1.0), smoothstep(0.80, 0.98, edge));
    }
    let texel = shadow_softness / max(frame.shadow_resolution, 1.0);
    var light = vec3<f32>(0.0);
    for (var y = -1; y <= 1; y++) {
        for (var x = -1; x <= 1; x++) {
            let uv = coord.xy + vec2<f32>(f32(x), f32(y)) * texel;
            light += shadow_sample(uv, coord.z);
        }
    }
    return mix(light / 9.0, vec3<f32>(1.0), smoothstep(0.80, 0.98, edge));
}

fn material(input: MaterialInput) -> Surface {
    var normal = input.normal;
    var smoothness = 0.0;
    var metal = 0.0;
    var ao = 1.0;
    if input.material == 10u { smoothness = 0.64; metal = 0.85; }
    if input.material == 11u { smoothness = 0.70; metal = 0.95; }
    if input.material == 12u { smoothness = 0.38; }
    if input.material == 13u { smoothness = 0.30; }
    if pbr_materials && block_pbr_maps() {
        let specular = block_specular_map(input.uv);
        let map = block_normal_map(input.uv);
        let xy = map.rg * 2.0 - 1.0;
        let local = vec3<f32>(xy, sqrt(max(1.0 - dot(xy, xy), 0.0)));
        let bitangent = cross(normal, input.tangent.xyz) * input.tangent.w;
        normal = normalize(input.tangent.xyz * local.x + bitangent * local.y + normal * local.z);
        // A pack can supply maps for only some sprites. Preserve our fallback
        // material on sprites whose specular lookup is the API's zero stand-in.
        if any(specular != vec4<f32>(0.0)) {
            smoothness = specular.r;
            metal = select(0.0, 1.0, specular.g >= 230.0 / 255.0);
        }
        ao = map.b;
    }
    let foliage = input.material == 2u;
    if foliage { normal = vec3<f32>(0.0, 1.0, 0.0); }
    let n = input.normal;
    let shade = select(1.0 - abs(n.x) * 0.4 - abs(n.z) * 0.2 - max(-n.y, 0.0) * 0.5, 1.0, foliage);
    let tint = clamp(input.tint.rgb / max(shade, 0.5), vec3<f32>(0.0), vec3<f32>(1.0));
    let albedo = linear_color(input.albedo.rgb * tint);
    let day = daylight();
    let sky = pow(clamp(input.light.y, 0.0, 1.0), 2.0);
    let block = pow(clamp(input.light.x, 0.0, 1.0), 2.2);
    var ambient = mix(vec3<f32>(0.018, 0.029, 0.065), vec3<f32>(0.20, 0.27, 0.36), day) * sky;
    var direct = vec3<f32>(0.0);
    if frame.dimension == 0 {
        let golden = (1.0 - smoothstep(0.15, 0.65, abs(frame.light_direction.y))) * day;
        let sun = mix(vec3<f32>(2.5, 2.20, 1.72), vec3<f32>(3.15, 1.67, 0.72), golden);
        let key = mix(vec3<f32>(0.055, 0.10, 0.22), sun, day);
        let cosine = max(dot(normal, frame.light_direction), 0.0);
        if cosine * sky > 0.0001 {
            direct = key * cosine * sky * (0.16 + 0.67 * day) *
                (1.0 - frame.rain * 0.85) * shadow_tint(input.position, input.normal);
        }
    } else if frame.dimension == -1 {
        ambient = vec3<f32>(0.035, 0.018, 0.025) + linear_color(frame.fog_color) * 0.12;
    } else {
        ambient = vec3<f32>(0.085, 0.064, 0.135) * (0.65 + 0.35 * max(normal.y, 0.0));
        direct = vec3<f32>(0.12, 0.10, 0.18) * max(normal.y, 0.0);
    }
    var lamp_color = vec3<f32>(2.7, 1.65, 0.70);
    var dynamic = vec3<f32>(0.0);
    if colored_lights {
        if block > 0.0001 {
            let lamp = block_light_color(input.position);
            if lamp.a > 0.001 { lamp_color = lamp.rgb * 2.2; }
        }
        dynamic = input.colored_light * 1.8;
    } else {
        dynamic = vec3<f32>(dot(input.colored_light, vec3<f32>(0.2126, 0.7152, 0.0722))) * vec3<f32>(1.8, 1.45, 0.85);
    }
    var lighting = vec3<f32>(0.008 + frame.brightness * 0.012) + ambient * ao + direct +
        lamp_color * block * block_light_strength + dynamic;
    lighting = mix(lighting, max(lighting, vec3<f32>(0.95)), frame.night_vision);
    var color = mapped_light(albedo * lighting);
    if input.emission > 0.0 {
        color = max(color, input.albedo.rgb * min(input.emission * 1.3, 1.0));
    }
    if input.fluid == 1u && input.face == 1u && frame.eye_in != 1u {
        return Surface(shade_water(input, color));
    }
    if !input.translucent { set_surface(normal, smoothness, metal); }
    return Surface(vec4<f32>(fogged(color, input.position), input.albedo.a * input.tint.a));
}
