shader_type canvas_item;

// The Elderwild's background art, brought to life in place:
//   - breathing: a slow swell around breathe_center (the bear), fading
//     smoothly to nothing at breathe_radius
//   - runes: the pale carvings inside each rune rect light up, keyed on
//     brightness so only the carving glows, never the bark around it,
//     with a slow wave of light running down each one
//   - creek: the brightest ripples inside water_rect glint and twinkle

uniform float aspect = 1.0;  // image width / height

uniform vec2 breathe_center = vec2(0.5, 0.5);
uniform float breathe_radius = 0.2;  // in units of image height
uniform float breathe_amount = 0.0;
uniform float breathe_period = 4.0;

// UV x0, y0, x1, y1 - zero-size rects are off.
uniform vec4 rune_rect_a = vec4(0.0);
uniform vec4 rune_rect_b = vec4(0.0);
uniform vec4 rune_color : source_color = vec4(0.55, 1.0, 0.75, 1.0);
uniform float rune_strength = 1.4;
uniform float rune_threshold = 0.16;
uniform float rune_period = 6.0;

uniform vec4 water_rect = vec4(0.0);
uniform float water_strength = 0.9;
uniform float water_threshold = 0.38;

float luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

float rect_mask(vec2 uv, vec4 r, float feather) {
	if (r.z <= r.x) {
		return 0.0;
	}
	vec2 d = min(uv - r.xy, r.zw - uv);
	return smoothstep(0.0, feather, min(d.x, d.y));
}

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

// How much of a rune's carving is at `uv`, with a soft halo from a few
// taps around it so the glow bleeds a little onto the wood.
float rune_key(sampler2D tex, vec2 uv, vec2 px) {
	float k = smoothstep(rune_threshold, rune_threshold + 0.1, luma(texture(tex, uv).rgb));
	float halo = 0.0;
	for (int i = 0; i < 8; i++) {
		float a = float(i) * 0.7853982;
		vec2 o = vec2(cos(a), sin(a)) * px * 3.5;
		halo += smoothstep(rune_threshold, rune_threshold + 0.1, luma(texture(tex, uv + o).rgb));
	}
	return k + halo / 8.0 * 0.6;
}

void fragment() {
	vec2 uv = UV;

	// Breathing: sample slightly toward the center on the inhale.
	vec2 rel = uv - breathe_center;
	float d = length(rel * vec2(aspect, 1.0)) / breathe_radius;
	float falloff = d < 1.0 ? (1.0 - d * d) * (1.0 - d * d) : 0.0;
	float breath = 0.5 - 0.5 * cos(TIME * 6.2831853 / breathe_period);
	float swell = breathe_amount * breath * falloff;
	uv += -rel * swell + vec2(0.0, 0.3 * swell * breathe_radius);

	vec4 c = texture(TEXTURE, uv);

	// Runes.
	float in_a = rect_mask(UV, rune_rect_a, 0.01);
	float in_b = rect_mask(UV, rune_rect_b, 0.01);
	if (in_a + in_b > 0.0) {
		float key = rune_key(TEXTURE, uv, TEXTURE_PIXEL_SIZE);
		// A wave of light running down the carving, over a steady ember.
		float phase_a = TIME * 6.2831853 / rune_period - UV.y * 40.0;
		float phase_b = TIME * 6.2831853 / (rune_period * 1.3) - UV.y * 30.0 + 2.1;
		float wave = in_a * (0.35 + 0.65 * pow(0.5 + 0.5 * sin(phase_a), 3.0))
				+ in_b * (0.35 + 0.65 * pow(0.5 + 0.5 * sin(phase_b), 3.0));
		c.rgb += rune_color.rgb * key * wave * rune_strength;
	}

	// Creek glints: bright ripples catch the light as a noise pattern
	// drifts downstream over them.
	float in_w = rect_mask(UV, water_rect, 0.02);
	if (in_w > 0.0) {
		float bright = smoothstep(water_threshold, water_threshold + 0.25, luma(c.rgb));
		vec2 p = UV * vec2(260.0, 520.0) + vec2(-TIME * 1.2, TIME * 2.2);
		float sparkle = pow(value_noise(p), 6.0) * 6.0;
		float shimmer = 0.5 + 0.5 * sin(UV.x * 300.0 - TIME * 3.0 + UV.y * 120.0);
		c.rgb += vec3(0.85, 0.92, 1.0) * bright * (sparkle + 0.25 * shimmer) * water_strength * in_w;
	}

	COLOR = c;
}
