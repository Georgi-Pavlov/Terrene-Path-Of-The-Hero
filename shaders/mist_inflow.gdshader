shader_type canvas_item;

// The Mist Remembers: mist rising out of the ground around a creature
// and pouring into it. A low pool of mist gathers along the ground line,
// and several streams lift out of it, curving in from both sides to
// converge on `target` (the chest), their texture flowing upward along
// them. `intensity` (0..1) is driven from GDScript: a surge when the
// ultimate triggers, a gentler steady flow while it lasts.

uniform vec4 mist_color : source_color = vec4(0.62, 0.92, 0.88, 1.0);
uniform vec4 glow_color : source_color = vec4(0.3, 1.0, 0.85, 1.0);
uniform float intensity = 1.0;
uniform vec2 target = vec2(0.5, 0.4);     // rect UV
uniform float ground = 0.9;               // rect UV y of the ground line
uniform float aspect = 1.0;               // rect width / height
uniform float seed = 0.0;

const int STREAMS = 7;

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
	for (int i = 0; i < 4; i++) {
		v += a * value_noise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV;
	float span = max(ground - target.y, 0.01);
	// How far up from the ground toward the target this row is (0..1).
	float s = (ground - uv.y) / span;

	float streams = 0.0;
	if (s > -0.05 && s < 1.05) {
		for (int i = 0; i < STREAMS; i++) {
			float fi = float(i);
			// Roots spread along the ground on both sides of the figure.
			float root = mix(0.08, 0.92, (fi + 0.5) / float(STREAMS)) + (hash(vec2(fi, seed)) - 0.5) * 0.08;
			float sc = clamp(s, 0.0, 1.0);
			// Rises, bowing outward first, then is drawn in hard toward the
			// target near the top - a curl, not a straight line.
			float side = root < target.x ? -1.0 : 1.0;
			float x = mix(root, target.x, pow(sc, 2.2));
			x += side * sin(sc * 3.14159) * (0.06 + 0.04 * hash(vec2(fi, seed + 1.0)));
			// Wandering, like smoke caught in a draft.
			x += (fbm(vec2(sc * 2.5 - TIME * 0.5, fi * 4.3 + seed)) - 0.5) * 0.14 * (1.0 - sc);
			float w = mix(0.085, 0.02, sc);
			float d = abs(uv.x - x) * aspect / (w * aspect);
			float body = 1.0 - smoothstep(0.25, 1.0, d);
			// Smoke texture flowing up along the stream.
			float n = fbm(vec2((uv.x - x) / w * 0.8 + fi * 3.7, sc * 5.0 - TIME * 1.4 + seed));
			float smoke = smoothstep(0.3, 0.75, n);
			// Patches of it drifting up the stream with gaps between, so it
			// reads as mist being drawn in rather than a solid ribbon.
			float patches = smoothstep(0.3, 0.62, fbm(vec2(fi * 5.1 + seed, sc * 3.0 - TIME * 0.9)));
			float ends = smoothstep(-0.05, 0.12, s) * (1.0 - smoothstep(0.85, 1.02, s));
			streams += body * mix(0.35, 1.0, smoke) * mix(0.25, 1.0, patches) * ends;
		}
	}

	// The pool of mist gathering along the ground.
	float pool_n = fbm(vec2(uv.x * 5.0 * aspect + TIME * 0.3, uv.y * 8.0 - TIME * 0.5) + seed);
	float pool = (1.0 - smoothstep(0.0, 0.1, abs(uv.y - ground))) * smoothstep(0.35, 0.7, pool_n)
			* smoothstep(0.0, 0.12, uv.x) * (1.0 - smoothstep(0.88, 1.0, uv.x));

	// A glow where it all pours in.
	vec2 dt = (uv - target) * vec2(aspect, 1.0);
	float heart = exp(-dot(dt, dt) * 60.0);

	float a = clamp(streams * 0.9 + pool * 0.6 + heart * 0.6, 0.0, 1.0) * intensity;
	vec3 col = mix(mist_color.rgb, glow_color.rgb, clamp(heart + streams * 0.2, 0.0, 1.0) * 0.7);
	COLOR = vec4(col, a);
}
