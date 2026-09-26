shader_type canvas_item;

// Veil of the Forgotten: a shroud of living mist wrapped around a
// creature. Swirling noise laid out around the rect's center, thickest
// in a band around the figure and thin across its middle, so the
// creature stays visible inside it. `strength` (0..1) is how much of
// the veil is left: as it drops the mist thins out and breaks up into
// wisps with gaps between them, rather than just fading evenly.

uniform vec4 mist_color : source_color = vec4(0.6, 0.9, 0.88, 1.0);
uniform vec4 glow_color : source_color = vec4(0.3, 1.0, 0.9, 1.0);
uniform float strength = 1.0;
uniform float aspect = 1.0;       // rect width / height
uniform float seed = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * value_noise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 p = (UV - 0.5) * vec2(aspect, 1.0);
	float r = length(p * vec2(1.0 / aspect, 1.0)) * 2.0;  // 0 center, 1 at the rect's edge
	float t = TIME * 0.35 + seed;

	// Swirl: rotate the noise lookup around the center, faster near it.
	float ang = t * 0.6 + (1.0 - r) * 1.2;
	mat2 rot = mat2(vec2(cos(ang), sin(ang)), vec2(-sin(ang), cos(ang)));
	vec2 q = rot * p * 3.2;
	float warp = fbm(q * 0.8 + vec2(t, -t * 0.6));
	float n = fbm(q + vec2(-t * 0.9, t * 0.4) + warp * 1.6);

	// A band hugging the figure, thin across the middle, gone at the edge.
	float band = smoothstep(0.15, 0.6, r) * (1.0 - smoothstep(0.72, 1.0, r));
	float core = 0.28 * (1.0 - smoothstep(0.0, 0.6, r));
	float shape = band + core;

	// Weaker veil: higher threshold, so it breaks into separate wisps.
	float thresh = mix(0.62, 0.36, strength);
	float m = smoothstep(thresh, thresh + 0.22, n) * shape;
	float alpha = m * mix(0.35, 0.85, strength);

	// Brighter where the mist is densest, a faint glow at its heart.
	vec3 col = mix(mist_color.rgb, glow_color.rgb, smoothstep(0.55, 0.85, n) * 0.6);
	COLOR = vec4(col, clamp(alpha, 0.0, 1.0));
}
