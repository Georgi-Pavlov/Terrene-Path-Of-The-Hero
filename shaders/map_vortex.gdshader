shader_type canvas_item;
render_mode blend_add;

// Slowly turning spiral arms of light, drawn over the whirlpool painted
// on the map. Fades out towards the rect's edge, with a pulsing core.

uniform vec4 tint : source_color = vec4(0.95, 0.2, 0.3, 1.0);
uniform float arms = 3.0;
uniform float twist = 5.0;
uniform float speed = 0.12;       // turns per second
uniform float intensity = 0.5;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float spiral = sin(a * arms + log(r + 0.04) * twist + TIME * speed * 6.2831853);
	spiral = smoothstep(0.35, 1.0, spiral);
	float fall = smoothstep(1.0, 0.2, r) * smoothstep(0.02, 0.18, r);
	float core = smoothstep(0.28, 0.0, r);
	float pulse = 0.75 + 0.25 * sin(TIME * 1.4);
	COLOR = vec4(tint.rgb, (spiral * fall * 0.7 + core * 0.8 * pulse) * intensity);
}
