shader_type canvas_item;

// Kingdom of Morvain's background art, brought to life in place:
//   - hands: each blurred hand in the foreground swells toward the
//     viewer (a local magnification) and darkens as it comes closer.
//     How far each one reaches is driven per frame from GDScript.
//   - twister: the funnel of cloud in the sky spins. Uses two twisted
//     copies cross-faded on staggered cycles (the flow-map trick), so
//     it keeps turning without the twist ever piling up.
//   - figures: the shapes in the mist sway and their mist brightens and
//     fades, each on its own rhythm.
// A calm rect (UV x0/y0/x1/y1) keeps the painted stats frame still.

uniform float aspect = 1.0;  // image width / height
uniform vec4 calm_rect = vec4(0.0);
uniform float calm_feather = 0.015;

const int HAND_COUNT = 3;
uniform vec2 hand_center[HAND_COUNT];
uniform float hand_radius[HAND_COUNT];   // in units of image height
uniform float hand_amount[HAND_COUNT];   // 0 = resting; ~0.15 = right up in your face
uniform float hand_darken = 1.6;

uniform vec2 twister_center = vec2(0.0);
uniform float twister_radius = 0.0;      // in units of image height; 0 = off
uniform float twister_twist = 2.2;       // radians of twist per cycle at the core
uniform float twister_period = 3.0;

const int FIGURE_COUNT = 5;
uniform vec4 figure_rect[FIGURE_COUNT];  // UV x0, y0, x1, y1
uniform float figure_sway = 0.0035;
uniform vec4 figure_glow : source_color = vec4(0.62, 0.86, 0.86, 1.0);
uniform float figure_glow_strength = 0.16;

vec2 rotate(vec2 v, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec2(c * v.x - s * v.y, s * v.x + c * v.y);
}

float calm_factor(vec2 uv) {
	vec2 d = max(calm_rect.xy - uv, uv - calm_rect.zw);
	return smoothstep(0.0, calm_feather, max(d.x, d.y));
}

// Soft ellipse filling rect r, 1 in the middle fading to 0 at its edges.
float ellipse_mask(vec2 uv, vec4 r) {
	if (r.z <= r.x) {
		return 0.0;
	}
	vec2 c = (r.xy + r.zw) * 0.5;
	vec2 h = (r.zw - r.xy) * 0.5;
	float d = length((uv - c) / h);
	return 1.0 - smoothstep(0.55, 1.0, d);
}

vec2 twist_sample(vec2 uv, float phase) {
	vec2 rel = (uv - twister_center) * vec2(aspect, 1.0);
	float d = length(rel) / twister_radius;
	float w = d < 1.0 ? (1.0 - d) * (1.0 - d) : 0.0;
	rel = rotate(rel, -phase * twister_twist * w);
	return twister_center + rel / vec2(aspect, 1.0);
}

void fragment() {
	vec2 uv = UV;
	vec2 offset = vec2(0.0);
	float closeness = 0.0;

	for (int i = 0; i < HAND_COUNT; i++) {
		if (hand_radius[i] <= 0.0) {
			continue;
		}
		vec2 rel = uv - hand_center[i];
		float d = length(rel * vec2(aspect, 1.0)) / hand_radius[i];
		float fall = d < 1.0 ? (1.0 - d * d) * (1.0 - d * d) : 0.0;
		float a = hand_amount[i] * fall;
		// Sampling toward the center magnifies: the hand grows at you.
		offset -= rel * a / (1.0 + a);
		closeness += a;
	}

	float glow = 0.0;
	for (int i = 0; i < FIGURE_COUNT; i++) {
		float m = ellipse_mask(uv, figure_rect[i]);
		if (m <= 0.0) {
			continue;
		}
		float fi = float(i);
		offset.x += figure_sway * m * sin(TIME * (0.7 + 0.13 * fi) + fi * 1.9 + uv.y * 38.0);
		offset.y += figure_sway * 0.4 * m * sin(TIME * 0.5 + fi * 2.7);
		glow += m * (0.5 + 0.5 * sin(TIME * (0.45 + 0.07 * fi) + fi * 2.3));
	}

	float calm = calm_factor(uv);
	offset *= calm;
	closeness *= calm;
	vec2 src = clamp(uv + offset, vec2(0.0), vec2(1.0));

	vec4 col;
	if (twister_radius > 0.0) {
		float p1 = fract(TIME / twister_period);
		float p2 = fract(TIME / twister_period + 0.5);
		vec4 c1 = texture(TEXTURE, clamp(twist_sample(src, p1), vec2(0.0), vec2(1.0)));
		vec4 c2 = texture(TEXTURE, clamp(twist_sample(src, p2), vec2(0.0), vec2(1.0)));
		// Each copy is weighted out right as its twist wraps back to 0.
		col = mix(c1, c2, abs(p1 * 2.0 - 1.0));
	} else {
		col = texture(TEXTURE, src);
	}

	col.rgb *= 1.0 - clamp(closeness * hand_darken, 0.0, 0.45);
	float luma = dot(col.rgb, vec3(0.299, 0.587, 0.114));
	col.rgb += figure_glow.rgb * glow * figure_glow_strength * (0.4 + luma);
	COLOR = col;
}
