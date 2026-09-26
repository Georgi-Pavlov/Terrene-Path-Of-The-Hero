shader_type canvas_item;

// Brings a single static creature portrait to life without touching the
// node's own position/scale/modulate (battle.gd already tweens those for
// its own hit flashes, lunges and pulses - see CreatureAnimator.gd).
//
// Idle, always running:
//   - breathing: a slow stretch/squash anchored at the feet
//   - sway: the top of the figure drifts sideways, feet stay planted
//   - ripple: a gentle underwater wobble, strongest at the top
// Event-driven, tweened from CreatureAnimator:
//   - move_offset / action_offset: pixel offsets (movement slide/hop,
//     attack lunge, hit knockback)
//   - squash / lean: extra stretch around the feet and top shear
//   - flash / glow: hit flash and cast glow
//   - dissolve: death burn-away along a noise pattern

uniform float time_offset = 0.0;
// Node size in local pixels, so the feet pivot and pixel offsets line up.
uniform vec2 rect_size = vec2(100.0, 100.0);

uniform float breath_amount = 0.015;
uniform float breath_speed = 1.6;
uniform float sway_amount = 0.01;
uniform float sway_speed = 0.8;
uniform float ripple_amount = 0.0;
uniform float ripple_freq = 9.0;
uniform float ripple_speed = 1.8;

uniform vec2 move_offset = vec2(0.0);
uniform vec2 action_offset = vec2(0.0);
uniform vec2 squash = vec2(1.0);
uniform float lean = 0.0;

uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float flash_amount = 0.0;
uniform vec4 glow_color : source_color = vec4(0.4, 0.9, 1.0, 1.0);
uniform float glow_amount = 0.0;

uniform float dissolve = 0.0;
uniform vec4 dissolve_edge_color : source_color = vec4(0.3, 0.9, 1.0, 1.0);

// The node's modulate/vertex color on its own. Fragment COLOR already
// has the texture multiplied in, and the texture has to be re-sampled
// here at the rippled UV - multiplying that by COLOR would apply the
// texture twice (darker, oversaturated art).
varying vec4 v_tint;

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

void vertex() {
	v_tint = COLOR;
	float t = TIME + time_offset;
	// 1 at the top of the art, 0 at the feet.
	float h = 1.0 - UV.y;
	vec2 feet = vec2(rect_size.x * 0.5, rect_size.y);

	float breath = sin(t * breath_speed) * breath_amount;
	vec2 s = squash * vec2(1.0 - breath * 0.5, 1.0 + breath);
	VERTEX = feet + (VERTEX - feet) * s;

	float sway = sin(t * sway_speed) * sway_amount + sin(t * sway_speed * 2.3 + 1.7) * sway_amount * 0.3;
	VERTEX.x += (sway + lean) * rect_size.x * h;

	VERTEX += move_offset + action_offset;
}

void fragment() {
	float t = TIME + time_offset;
	float h = 1.0 - UV.y;

	vec2 uv = UV;
	uv.x += sin(UV.y * ripple_freq + t * ripple_speed) * ripple_amount * h;
	uv.y += sin(UV.x * ripple_freq * 0.7 - t * ripple_speed * 0.8) * ripple_amount * 0.5 * h;
	vec4 c = texture(TEXTURE, clamp(uv, vec2(0.0), vec2(1.0))) * v_tint;

	c.rgb += glow_color.rgb * glow_amount * c.a;
	c.rgb = mix(c.rgb, flash_color.rgb * c.a, clamp(flash_amount, 0.0, 1.0));

	if (dissolve > 0.0) {
		// Mostly noise, biased so it burns from the top down.
		float n = value_noise(UV * 12.0) * 0.6 + value_noise(UV * 37.0) * 0.25 + (1.0 - h) * 0.15;
		float edge = 0.08;
		float cut = dissolve * (1.0 + edge);
		float alive = smoothstep(cut - edge, cut, n);
		float rim = 1.0 - smoothstep(cut, cut + edge, n);
		c.rgb = mix(c.rgb, dissolve_edge_color.rgb * 1.8 * c.a, rim * step(0.001, alive));
		c.a *= alive;
	}

	COLOR = c;
}
