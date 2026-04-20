shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float time_val : hint_range(0.0, 100.0) = 0.0;

void fragment() {
    vec2 uv = UV;

    // --- VOID DISTORTION (dominant) ---
    float void_strength = progress * 0.04;
    uv += vec2(
        sin(uv.y * 8.0 + time_val * 2.0) * void_strength,
        cos(uv.x * 6.0 + time_val * 1.5) * void_strength
    );

    // --- FLESH WARP ---
    float flesh = sin(uv.x * 20.0 + time_val) * cos(uv.y * 20.0 - time_val * 0.7);
    uv += vec2(flesh * 0.008 * progress, flesh * 0.005 * progress);

    // --- GLITCH HORIZONTAL SLICE ---
    float slice = floor(uv.y * 40.0) / 40.0;
    float glitch_trigger = step(0.92, sin(slice * 200.0 + time_val * 8.0));
    float glitch_offset = (fract(sin(slice * 91.3 + time_val) * 4831.2) - 0.5) * 0.04 * progress;
    uv.x += glitch_offset * glitch_trigger;

    // --- VOID COLOR BASE ---
    // Deep purple-black void pulling inward from edges
    float dist = distance(UV, vec2(0.5, 0.5));
    float vignette = smoothstep(0.3, 0.85, dist);
    vec3 void_color = mix(vec3(0.04, 0.0, 0.08), vec3(0.0, 0.0, 0.0), vignette);

    // --- BLOOD FLOOD from edges ---
    float blood_edge = smoothstep(0.35, 0.75, dist) * progress;
    float blood_drip = sin(uv.x * 30.0 + time_val * 0.5) * 0.5 + 0.5;
    blood_drip = pow(blood_drip, 3.0) * 0.3;
    vec3 blood_color = vec3(0.55, 0.0, 0.0) + vec3(blood_drip * 0.2, 0.0, 0.0);
    vec3 col = mix(void_color, blood_color, blood_edge * 0.85);

    // --- COSMIC EYE PULSE (void iris pattern) ---
    float eye_dist = distance(UV, vec2(0.5, 0.48));
    float iris = smoothstep(0.22, 0.18, eye_dist) * progress;
    float pupil = smoothstep(0.07, 0.04, eye_dist) * progress;
    float iris_pattern = sin(eye_dist * 80.0 - time_val * 2.0) * 0.5 + 0.5;
    vec3 iris_color = mix(vec3(0.25, 0.0, 0.35), vec3(0.55, 0.0, 0.6), iris_pattern);
    col = mix(col, iris_color, iris * 0.6);
    col = mix(col, vec3(0.0, 0.0, 0.0), pupil);

    // --- SCANLINES ---
    float scan = sin(UV.y * 800.0) * 0.04 * progress;
    col -= scan;

    // --- RGB SPLIT on glitch ---
    float r_shift = glitch_trigger * glitch_offset * 2.0;
    col.r += r_shift * progress;
    col.b -= r_shift * progress;

    // --- FADE IN ---
    float alpha = smoothstep(0.0, 0.3, progress);

    COLOR = vec4(col, alpha);
}