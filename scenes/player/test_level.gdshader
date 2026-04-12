shader_type canvas_item;
render_mode blend_add;

uniform float grain_strength : hint_range(0.0, 1.0) = 0.08;
uniform float grain_scale : hint_range(1.0, 10.0) = 2.0;

float random(vec2 uv) {
    return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
    vec2 uv = FRAGCOORD.xy * 0.01 * grain_scale + TIME * 0.1;
    float grain = random(uv) * grain_strength;
    COLOR = vec4(grain, grain, grain, 1.0);
}