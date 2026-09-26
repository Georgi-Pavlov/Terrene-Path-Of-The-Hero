shader_type canvas_item;

// One of the painted ghosts from the background, lifted out of the art
// (its texture is a crop of the background image) and drifting toward
// the viewer. The crop is cut down to a soft, mist-eaten oval around the
// face, wavers like something seen through fog, and its eyes burn
// brighter than in the painting. `fade` and `approach` (0..1, how far
// along its approach it is) are driven from GDScript.

uniform float fade = 0.0;
uniform float approach = 0.0;
uniform float seed = 0.0;
uniform vec4 eye_color : source_color = vec4(0.45, 1.0, 0.95, 1.0);
uniform float eye_boost = 1.8;
// Where this crop's two eyes are (UV), and so where its face is.
uniform vec2 eye_a = vec2(0.42, 0.45);
uniform vec2 eye_b = vec2(0.58, 0.45);
uniform float eye_size = 0.018;

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
	float t = TIME * 0.35 + seed * 13.0;
	// Wavering, stronger as it closes in.
	vec2 warp = vec2(fbm(UV * 3.0 + vec2(t, seed)), fbm(UV * 3.0 + vec2(seed, t))) - 0.5;
	vec2 uv = UV + warp * (0.03 + 0.05 * approach);
	vec4 c = texture(TEXTURE, clamp(uv, vec2(0.0), vec2(1.0)));

	// Cold and drained, with the eyes pushed hot: they're the only
	// saturated teal in the crop.
	float luma = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	float teal = clamp((c.g + c.b) * 0.5 - c.r, 0.0, 1.0);
	float eyes = smoothstep(0.08, 0.2, teal) * smoothstep(0.35, 0.6, luma);
	vec3 col = mix(vec3(luma) * vec3(0.85, 0.97, 1.0), c.rgb, 0.35);
	// Harder contrast than the painting, so the hollow of the face reads
	// as a dark void against the mist around it.
	col = clamp((col - 0.45) * 1.5 + 0.4, 0.0, 1.0);
	// The eyes themselves: hot cores with a glow bleeding around them,
	// flickering, burning brighter as it closes in.
	vec2 ea = (uv - eye_a) / eye_size;
	vec2 eb = (uv - eye_b) / eye_size;
	float burn = exp(-dot(ea, ea)) + exp(-dot(eb, eb));
	float halo = exp(-dot(ea, ea) * 0.06) + exp(-dot(eb, eb) * 0.06);
	float flicker = 0.85 + 0.15 * sin(TIME * 13.0 + seed);
	eyes = max(eyes, burn);
	col += eye_color.rgb * (eyes * eye_boost + halo * 0.18) * flicker * (0.8 + 0.6 * approach);

	// Soft oval around the face, its edge eaten away by drifting mist.
	vec2 face = (eye_a + eye_b) * 0.5 + vec2(0.0, 0.06);
	float d = length((UV - face) * vec2(1.0, 0.8));
	float edge_noise = fbm(UV * 5.0 + vec2(0.0, -t * 1.5)) - 0.5;
	float mask = 1.0 - smoothstep(0.14, 0.4, d + edge_noise * 0.18);
	// And never let the crop's own edges show.
	mask *= smoothstep(0.0, 0.12, UV.x) * smoothstep(0.0, 0.12, UV.y) * smoothstep(0.0, 0.12, 1.0 - UV.x) * smoothstep(0.0, 0.12, 1.0 - UV.y);

	COLOR = vec4(col, clamp(mask * (0.85 + eyes), 0.0, 1.0) * fade);
}
