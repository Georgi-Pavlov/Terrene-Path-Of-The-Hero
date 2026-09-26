shader_type canvas_item;
render_mode blend_add;

// Soft beams of light fanning down from a point above the rect, slowly
// swaying and breathing in strength. Drawn additively over the art.

uniform vec2 origin = vec2(0.5, -0.2);      // in this rect's UV
uniform vec4 shaft_color : source_color = vec4(0.55, 0.82, 0.95, 1.0);
uniform float intensity = 0.3;
uniform float spread = 0.95;                 // half-angle of the fan, radians
uniform float reach = 1.5;                   // fades out by this distance
uniform float sway = 0.05;
uniform float aspect = 1.0;                  // rect width / height

void fragment() {
	vec2 d = (UV - origin) * vec2(aspect, 1.0);
	float r = length(d);
	// 0 = straight down, negative = left, positive = right.
	float ang = atan(d.x, d.y) + sin(TIME * 0.23) * sway;

	float a = 0.5 + 0.5 * sin(ang * 9.0 + TIME * 0.35);
	float b = 0.5 + 0.5 * sin(ang * 17.0 - TIME * 0.55 + 1.7);
	float c = 0.5 + 0.5 * sin(ang * 5.0 + TIME * 0.2 + 4.1);
	float rays = 0.6 * a * b + 0.4 * c;

	float fan = 1.0 - smoothstep(spread * 0.4, spread, abs(ang));
	float fall = 1.0 - smoothstep(0.15, reach, r);
	float edges = smoothstep(0.0, 0.12, UV.x) * (1.0 - smoothstep(0.88, 1.0, UV.x));
	float pulse = 0.8 + 0.2 * sin(TIME * 0.6);

	float alpha = rays * fan * fall * edges * pulse * intensity;
	COLOR = vec4(shaft_color.rgb, alpha);
}
