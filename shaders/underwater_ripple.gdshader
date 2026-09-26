shader_type canvas_item;

// Gentle underwater wobble for a whole background image: two crossing
// sine waves nudge the texture lookup by a pixel or two. A "calm" rect
// (in UV, x0/y0/x1/y1) is left undistorted - the Iron Abyss uses it to
// keep the painted stats frame crisp.
//
// Optional "breathing": a slow swell around breathe_center that fades
// smoothly to nothing at breathe_radius, so a painted figure seems to
// inhale and exhale. Off while breathe_amount is 0.

uniform float strength = 0.0014;
uniform float speed = 1.0;
uniform vec4 calm_rect = vec4(0.0, 0.0, 0.0, 0.0);
uniform float calm_feather = 0.02;

uniform vec2 breathe_center = vec2(0.5, 0.5);
// In units of image height, so the area stays round.
uniform float breathe_radius = 0.3;
uniform float breathe_amount = 0.0;
uniform float breathe_period = 4.0;
// Image width / height.
uniform float aspect = 1.0;

void fragment() {
	vec2 uv = UV;
	float t = TIME * speed;
	float w1 = sin(uv.y * 34.0 + t * 1.3);
	float w2 = sin(uv.x * 23.0 + uv.y * 8.0 - t * 0.9);
	vec2 offset = vec2(w1 * 0.65 + w2 * 0.35, w2 * 0.5 - w1 * 0.25) * strength;

	// Breathing: sample slightly toward the center (and from a touch
	// lower) on the inhale, which swells the figure and lifts it a hair.
	vec2 rel = uv - breathe_center;
	float d = length(rel * vec2(aspect, 1.0)) / breathe_radius;
	float falloff = d < 1.0 ? (1.0 - d * d) * (1.0 - d * d) : 0.0;
	float breath = 0.5 - 0.5 * cos(TIME * 6.2831853 / breathe_period);
	float swell = breathe_amount * breath * falloff;
	offset += -rel * swell + vec2(0.0, 0.3 * swell * breathe_radius);

	// Signed distance outside the calm rect: <= 0 inside, grows outward.
	vec2 dc = max(calm_rect.xy - uv, uv - calm_rect.zw);
	float outside = max(dc.x, dc.y);
	offset *= smoothstep(0.0, calm_feather, outside);

	COLOR = texture(TEXTURE, clamp(uv + offset, vec2(0.0), vec2(1.0)));
}
