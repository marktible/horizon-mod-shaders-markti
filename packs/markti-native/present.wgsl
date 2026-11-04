fn post(input: PostInput) -> vec4<f32> {
    // Slot 7 is written only by the active Markti native mod. A standalone pack
    // retains the normal presentation path. RCAS follows in the mod render hook.
    if frame.mods[7].x > 0.5 {
        return vec4<f32>(fsr_easu(input.uv), 1.0);
    }
    return input.color;
}
