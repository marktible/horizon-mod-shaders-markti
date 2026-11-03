fn sky(input: SkyInput) -> vec4<f32> {
    // A bounded ray/plane intersection; the cloud layer fades continuously at
    // the horizon instead of creating a clipped night/sunset half-plane.
    return vec4<f32>(cloudy_environment(input.direction), 1.0);
}
