shader_type canvas_item;

// Slow smoke spilling from up to two points (e.g. a pair of glowing
// eyes) and sinking downward: a soft plume that widens as it falls,
// bends gently from side to side, and is textured by noise that drifts
// down along it - one continuous shape, not separate puffs. Drawn over
// the art in its own rect.

uniform vec2 origin_a = vec2(0.5, 0.05);    // in this rect's UV
uniform vec2 origin_b = vec2(-10.0);        // far off-rect = unused
uniform float aspect = 1.0;                 // rect width / height
uniform vec4 mist_color : source_color = vec4(0.62, 0.86, 0.86, 1.0);
uniform float intensity = 0.6;
uniform float plume_length = 0.8;           // in units of rect height
uniform float width0 = 0.012;               // at the source
uniform float spread = 0.25;                // added width per unit fallen
uniform float drift = 0.0;                  // sideways lean per unit fallen
uniform float speed = 0.05;                 // how fast the smoke sinks

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

float plume(vec2 uv, vec2 origin, float seed) {
	vec2 p = (uv - origin) * vec2(aspect, 1.0);
	float along = p.y;
	if (along < -0.03 || along > plume_length) {
		return 0.0;
	}
	float fallen = max(along, 0.0);
	// Gentle side-to-side bending, more the further it has fallen.
	float bend = (fbm(vec2(fallen * 2.5 - TIME * speed * 3.0, seed)) - 0.5) * fallen * 0.7;
	float x = p.x - bend - fallen * drift;
	float w = width0 + fallen * spread;
	float body = 1.0 - smoothstep(w * 0.2, w, abs(x));
	// Smoke texture sinking along the plume.
	float n = fbm(vec2(x / w * 1.2 + seed * 3.1, fallen * 7.0 - TIME * speed * 7.0));
	float smoke = smoothstep(0.25, 0.75, n);
	float fade = (1.0 - smoothstep(plume_length * 0.2, plume_length, fallen)) * smoothstep(-0.03, 0.01, along);
	// Densest right where it leaves the source.
	float source = 1.0 + 1.5 * (1.0 - smoothstep(0.0, 0.05, fallen));
	return body * mix(0.35, 1.0, smoke) * fade * source;
}

void fragment() {
	float m = plume(UV, origin_a, 0.0) + plume(UV, origin_b, 7.3);
	COLOR = vec4(mist_color.rgb, clamp(m * intensity, 0.0, 1.0));
}
