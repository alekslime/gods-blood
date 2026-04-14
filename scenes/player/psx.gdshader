shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture;
uniform float pixel_resolution : hint_range(64.0, 512.0) = 240.0;
uniform int color_steps : hint_range(2, 64) = 16;
uniform float noise_strength : hint_range(0.0, 1.0) = 0.1;
uniform bool enable_dither = true;
uniform float dither_strength : hint_range(0.0, 1.0) = 0.3;

uniform bool enable_glow = true;
uniform float glow_strength : hint_range(0.0, 1.0) = 0.4;
uniform float glow_spread : hint_range(0.001, 0.01) = 0.005;

uniform bool enable_vintage = true;  //  Toggle
uniform float vintage_strength : hint_range(0.0, 1.0) = 0.8;

float random(vec2 co) {
	return fract(sin(dot(co.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

float bayer_dither(vec2 pos) {
	int x = int(mod(pos.x, 4.0));
	int y = int(mod(pos.y, 4.0));
	int index = x + y * 4;

	float bayer[16] = float[](
		0.0, 8.0, 2.0, 10.0,
		12.0, 4.0, 14.0, 6.0,
		3.0, 11.0, 1.0, 9.0,
		15.0, 7.0, 13.0, 5.0
	);

	return bayer[index] / 16.0;
}

vec3 get_glow(vec2 uv) {
	vec3 col = vec3(0.0);
	float total = 0.0;

	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			vec2 offset = vec2(float(x), float(y)) * glow_spread;
			col += texture(screen_texture, uv + offset).rgb;
			total += 1.0;
		}
	}
	return col / total;
}

vec3 apply_black_vintage_edges(vec3 color, vec2 uv) {
	// Distance from screen center
	float dist = distance(uv, vec2(0.5));

	// Mask: only affects edges
	float edge_mask = smoothstep(0.4, 0.8, dist);

	// Blend edges to black
	color = mix(color, vec3(0.0), edge_mask * vintage_strength);

	return color;
}

void fragment() {
	vec2 pixel_uv = floor(UV * pixel_resolution) / pixel_resolution;
	vec3 color = texture(screen_texture, pixel_uv).rgb;

	if (enable_glow) {
		vec3 blurred = get_glow(UV);
		color += blurred * glow_strength;
	}

	float steps = float(color_steps);
	color = floor(color * steps + 0.5) / steps;

	float noise = (random(UV + TIME) - 0.5) * noise_strength;
	color += noise;

	if (enable_dither) {
		float threshold = bayer_dither(FRAGCOORD.xy);
		color += (dither_strength * (threshold - 0.5));
	}

	//  Black vintage only on edges
	if (enable_vintage) {
		color = apply_black_vintage_edges(color, UV);
	}

	COLOR.rgb = clamp(color, 0.0, 1.0);
}
