shader_type canvas_item;

// Kingdom of Morvain's battle area, brought to life in place:
//   - figures: the hooded ghosts in the mist sway gently, each on its
//     own rhythm, their mist brightening and fading
//   - hands: each giant clawed hand slowly flexes - the image is turned
//     a little around its wrist, more toward the fingertips, so the
//     fingers curl in and open out again
// Everything is masked to its own area; the rest of the art is untouched.

uniform float aspect = 1.0;  // image width / height

const int FIGURE_COUNT = 5;
uniform vec4 figure_rect[FIGURE_COUNT];   // UV x0, y0, x1, y1
uniform float figure_sway = 0.004;
uniform vec4 figure_glow : source_color = vec4(0.55, 0.85, 0.88, 1.0);
uniform float figure_glow_strength = 0.12;

const int HAND_COUNT = 3;
uniform vec4 hand_rect[HAND_COUNT];       // UV x0, y0, x1, y1
uniform vec2 hand_wrist[HAND_COUNT];      // UV - the point the hand pivots on
uniform float hand_curl = 0.09;           // radians at the fingertips

// Soft ellipse filling rect r: 1 in the middle, 0 at its edges.
float ellipse_mask(vec2 uv, vec4 r) {
	if (r.z <= r.x) {
		return 0.0;
	}
	vec2 c = (r.xy + r.zw) * 0.5;
	vec2 h = (r.zw - r.xy) * 0.5;
	float d = length((uv - c) / h);
	return 1.0 - smoothstep(0.5, 1.0, d);
}

vec2 rotate_around(vec2 uv, vec2 pivot, float angle) {
	vec2 p = (uv - pivot) * vec2(aspect, 1.0);
	float c = cos(angle);
	float s = sin(angle);
	p = vec2(c * p.x - s * p.y, s * p.x + c * p.y);
	return pivot + p / vec2(aspect, 1.0);
}

void fragment() {
	vec2 uv = UV;
	vec2 src = uv;
	float glow = 0.0;

	for (int i = 0; i < FIGURE_COUNT; i++) {
		float m = ellipse_mask(uv, figure_rect[i]);
		if (m <= 0.0) {
			continue;
		}
		float fi = float(i);
		src.x += figure_sway * m * sin(TIME * (0.55 + 0.11 * fi) + fi * 1.9 + uv.y * 30.0);
		src.y += figure_sway * 0.5 * m * sin(TIME * 0.4 + fi * 2.7);
		glow += m * (0.5 + 0.5 * sin(TIME * (0.4 + 0.07 * fi) + fi * 2.3));
	}

	for (int i = 0; i < HAND_COUNT; i++) {
		vec4 r = hand_rect[i];
		float m = ellipse_mask(uv, r);
		if (m <= 0.0) {
			continue;
		}
		// Farther from the wrist = more curl, like fingers closing.
		vec2 w = hand_wrist[i];
		float reach = length((r.zw - r.xy) * vec2(aspect, 1.0)) * 0.6;
		float d = clamp(length((uv - w) * vec2(aspect, 1.0)) / reach, 0.0, 1.0);
		float fi = float(i);
		// Slow flex with a lingering grip: sharpen the wave's peaks.
		float wave = sin(TIME * (0.45 + 0.08 * fi) + fi * 2.1);
		float flex = sign(wave) * pow(abs(wave), 0.7);
		src = rotate_around(src, w, flex * hand_curl * d * m);
	}

	vec4 col = texture(TEXTURE, clamp(src, vec2(0.0), vec2(1.0)));
	float luma = dot(col.rgb, vec3(0.299, 0.587, 0.114));
	col.rgb += figure_glow.rgb * glow * figure_glow_strength * (0.4 + luma);
	COLOR = col;
}
