shader_type canvas_item;

// Two layers of seamless noise scrolling sideways at different speeds,
// masked so the fog only lives in the lower part of the screen.

uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform vec4 fog_color : source_color = vec4(0.80, 0.82, 0.88, 1.0);
uniform float density = 0.5;
// Fog fades in from mask_top (0 = top of screen) and is full by mask_full.
uniform float mask_top = 0.42;
uniform float mask_full = 0.85;
uniform vec2 speed_a = vec2(0.010, 0.0);
uniform vec2 speed_b = vec2(-0.006, 0.0015);
// Optional: white = fog allowed, black = keep clear (the Map uses this
// to keep the zone name plates readable). Defaults to all white.
uniform sampler2D clear_mask : hint_default_white, filter_linear;

void fragment() {
	float a = texture(noise_tex, UV * vec2(1.1, 1.6) + TIME * speed_a).r;
	float b = texture(noise_tex, UV * vec2(2.0, 2.8) + TIME * speed_b + vec2(0.37, 0.61)).r;
	float n = smoothstep(0.38, 0.9, a * 0.65 + b * 0.5);
	float mask = smoothstep(mask_top, mask_full, UV.y);
	float clear = texture(clear_mask, UV).r;
	COLOR = vec4(fog_color.rgb, n * mask * density * clear);
}
