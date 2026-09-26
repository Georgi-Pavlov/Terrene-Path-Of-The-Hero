extends Control
# ------------------------------------------------------------------
# MorvainAtmosphere
# The Kingdom of Morvain's effects for the hero picker. ZoneAtmosphere
# creates one of these (and frees it again with the rest of its
# children) when Morvael's background is shown, then calls build().
# Purely visual: never takes input, never touches game state.
#
#   - the blurred hands in the foreground creep closer, then lunge at
#     the viewer, darkening as they come
#   - mist spilling slowly from Morvael's glowing eyes and sinking down
#     over him (swelling every few seconds as his eyes flare)
#   - the horse's eye glowing, mist spilling from its nostril
#   - the shapes in the mist swaying, their eyes glowing, flickering
#     and now and then blinking out
#   - the funnel of cloud in the sky spinning
#   - now and then one of the painted ghosts rises out of the mist
#     somewhere and drifts slowly toward the viewer, growing until it
#     passes through the screen and is gone - one at a time
#
# Positions of art features are fractions (0..1) of the background
# image, like ZoneAtmosphere's own.
# ------------------------------------------------------------------

const BG_SHADER := preload("res://shaders/morvain_background.gdshader")
const PLUME_SHADER := preload("res://shaders/mist_plume.gdshader")
const FOG_SHADER := preload("res://shaders/fog_drift.gdshader")
const GHOST_SHADER := preload("res://shaders/ghost_apparition.gdshader")

const MIST_COLOR := Color(0.62, 0.86, 0.86)

# The painted stats frame (UV x0, y0, x1, y1) - kept still.
const FRAME_CALM_RECT := Vector4(0.012, 0.59, 0.481, 0.994)

# The three blurred hands: center (UV), radius (image heights) and how
# far each one reaches at the peak of its lunge.
const HANDS := [
	{"uv": Vector2(0.0897, 0.4357), "r": 0.213, "peak": 0.17},  # big one, left
	{"uv": Vector2(0.8672, 0.6270), "r": 0.18, "peak": 0.16},   # right
	{"uv": Vector2(0.6130, 0.7970), "r": 0.13, "peak": 0.15},   # lower middle
]
const HAND_CYCLE := Vector2(5.5, 8.5)   # seconds per creep-lunge-retreat

const TWISTER_UV := Vector2(0.5443, 0.0765)
const TWISTER_RADIUS := 0.085

# The shapes in the mist: the rect each one fills (UV x0, y0, x1, y1)
# and its two eyes.
const FIGURES := [
	{"rect": Vector4(0.568, 0.298, 0.622, 0.468), "eyes": [Vector2(0.5927, 0.3528), Vector2(0.5993, 0.3539)]},
	{"rect": Vector4(0.562, 0.425, 0.604, 0.553), "eyes": [Vector2(0.5813, 0.4718), Vector2(0.5873, 0.4718)]},
	{"rect": Vector4(0.610, 0.436, 0.652, 0.595), "eyes": [Vector2(0.6250, 0.4888), Vector2(0.6334, 0.4888)]},
	{"rect": Vector4(0.616, 0.627, 0.688, 0.776), "eyes": [Vector2(0.6453, 0.6844), Vector2(0.6573, 0.6918)]},
	{"rect": Vector4(0.894, 0.425, 0.939, 0.531), "eyes": [Vector2(0.9145, 0.4633), Vector2(0.9199, 0.4633)]},
]

const RIDER_EYES := [Vector2(0.3648, 0.1297), Vector2(0.3798, 0.1307)]
const HORSE_EYE := Vector2(0.5251, 0.3241)

# Mist spilling from Morvael's eyes: the rect it's drawn in (image UV)
# and each eye in that rect's own UV. Same again for the horse's nostril.
const EYE_PLUME_RECT_UV := Rect2(0.30, 0.11, 0.16, 0.31)
const EYE_PLUME_ORIGINS := [Vector2(0.405, 0.0635), Vector2(0.4988, 0.0668)]
const NOSTRIL_PLUME_RECT_UV := Rect2(0.50, 0.42, 0.12, 0.20)
const NOSTRIL_PLUME_ORIGIN := Vector2(0.383, 0.087)
const SURGE_EVERY := Vector2(4.0, 7.0)
const SURGE_TIME := 2.5

const LOW_FOG_RECT_UV := Rect2(0.45, 0.45, 0.55, 0.55)

# Ghost apparitions: crops of the painted ghosts (source pixels, framed
# on the face) with where each one's eyes sit in the crop (UV), and the
# points (image UV) they can rise from - patches of mist around the
# ruins, kept out from under the zone description so they're seen.
const GHOST_CROPS := [
	{"rect": Rect2i(1025, 590, 130, 130), "eyes": [Vector2(0.415, 0.415), Vector2(0.569, 0.469)]},
	{"rect": Rect2i(1012, 405, 90, 110), "eyes": [Vector2(0.367, 0.5), Vector2(0.522, 0.5)]},
	{"rect": Rect2i(950, 285, 90, 110), "eyes": [Vector2(0.456, 0.427), Vector2(0.578, 0.436)]},
	{"rect": Rect2i(1490, 395, 85, 100), "eyes": [Vector2(0.459, 0.41), Vector2(0.565, 0.41)]},
]
const GHOST_SPAWNS := [
	Vector2(0.65, 0.69), Vector2(0.73, 0.66), Vector2(0.97, 0.78),
	Vector2(0.54, 0.63), Vector2(0.84, 0.71), Vector2(0.05, 0.30),
]
const GHOST_TIME := Vector2(8.0, 11.0)     # seconds from first sight to gone
const GHOST_GAP := Vector2(3.0, 7.0)       # quiet time between two ghosts
const GHOST_START_HEIGHT := 80.0           # px at 1280-wide
const GHOST_END_HEIGHT := 1.9              # in screen heights

var _atm: Control
var _background: TextureRect
var _bg_mat: ShaderMaterial
var _rng := RandomNumberGenerator.new()
var _time := 0.0
var _s := 1.0   # image scale, source px -> screen px

var _hands: Array[Dictionary] = []
var _hand_amounts := PackedFloat32Array([0.0, 0.0, 0.0])

var _rider_eyes: Array[TextureRect] = []
var _horse_eye: TextureRect
var _eye_plume: ShaderMaterial
var _figure_eyes: Array[Dictionary] = []
var _surge := 0.0
var _next_surge := 0.0

var _ghost_textures: Array[Texture2D] = []
var _ghost_eyes: Array = []   # per texture: its two eye UVs
var _ghost: Dictionary = {}          # the one on screen, or empty
var _next_ghost := 0.0
var _last_spawn := -1
var _last_crop := -1


## `atm` is the owning ZoneAtmosphere - its image mapping helpers are
## reused so positions line up exactly with its own effects.
func build(atm: Control, background: TextureRect) -> void:
	_atm = atm
	_background = background
	_rng.randomize()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_s = _atm._image_scale()
	var tex_size := _background.texture.get_size()

	# Hands, twister and swaying figures, all on the art itself.
	_bg_mat = ShaderMaterial.new()
	_bg_mat.shader = BG_SHADER
	_bg_mat.set_shader_parameter("aspect", tex_size.x / tex_size.y)
	_bg_mat.set_shader_parameter("calm_rect", FRAME_CALM_RECT)
	var centers := PackedVector2Array()
	var radii := PackedFloat32Array()
	_hands.clear()
	for hand in HANDS:
		centers.append(hand["uv"])
		radii.append(hand["r"])
		# Staggered so they never all lunge together.
		_hands.append({"peak": hand["peak"], "period": _rng.randf_range(HAND_CYCLE.x, HAND_CYCLE.y), "t": _rng.randf()})
	_bg_mat.set_shader_parameter("hand_center", centers)
	_bg_mat.set_shader_parameter("hand_radius", radii)
	_bg_mat.set_shader_parameter("hand_amount", _hand_amounts)
	_bg_mat.set_shader_parameter("twister_center", TWISTER_UV)
	_bg_mat.set_shader_parameter("twister_radius", TWISTER_RADIUS)
	var rects := PackedVector4Array()
	for figure in FIGURES:
		rects.append(figure["rect"])
	_bg_mat.set_shader_parameter("figure_rect", rects)
	_background.material = _bg_mat

	# Low mist rolling through the ruins, behind everything else.
	_add_rect(FOG_SHADER, LOW_FOG_RECT_UV, {
		"density": 0.3, "speed": 0.018, "scale": 2.6,
		"band_center": 0.6, "band_height": 0.5,
		"fog_color": Color(0.72, 0.8, 0.82),
		"edge_fade": Vector4(0.25, 0.25, 0.03, 0.05),
	})

	# Eyes of the shapes in the mist.
	var small_eye: Texture2D = _atm._radial(64,
		PackedFloat32Array([0.0, 0.2, 1.0]),
		PackedColorArray([Color(0.8, 1.0, 1.0, 1.0), Color(0.4, 1.0, 0.95, 0.45), Color(0.3, 0.9, 0.9, 0.0)]))
	_figure_eyes.clear()
	for figure in FIGURES:
		var nodes: Array[TextureRect] = []
		for eye_uv in figure["eyes"]:
			nodes.append(_glow(small_eye, eye_uv, 14.0 * _s))
		_figure_eyes.append({
			"nodes": nodes,
			"phase": _rng.randf() * TAU,
			"speed": _rng.randf_range(0.35, 0.7),
			"blink_in": _rng.randf_range(2.0, 9.0),
			"blink_t": -1.0,
		})

	# Mist spilling from Morvael's eyes and the horse's nostril.
	_eye_plume = _add_rect(PLUME_SHADER, EYE_PLUME_RECT_UV, {
		"origin_a": EYE_PLUME_ORIGINS[0], "origin_b": EYE_PLUME_ORIGINS[1],
		"mist_color": MIST_COLOR, "plume_length": 0.75,
		"width0": 0.012, "spread": 0.22, "drift": -0.04, "speed": 0.04,
	}).material
	_add_rect(PLUME_SHADER, NOSTRIL_PLUME_RECT_UV, {
		"origin_a": NOSTRIL_PLUME_ORIGIN,
		"mist_color": MIST_COLOR, "intensity": 0.4, "plume_length": 0.85,
		"width0": 0.02, "spread": 0.3, "drift": 0.12, "speed": 0.035,
	})

	# Morvael's eyes and his horse's, over their own mist.
	var big_eye: Texture2D = _atm._radial(128,
		PackedFloat32Array([0.0, 0.1, 0.3, 1.0]),
		PackedColorArray([
			Color(0.9, 1.0, 1.0, 1.0),
			Color(0.5, 1.0, 0.95, 0.75),
			Color(0.3, 0.85, 0.85, 0.25),
			Color(0.2, 0.7, 0.7, 0.0),
		]))
	_rider_eyes.clear()
	for eye_uv in RIDER_EYES:
		_rider_eyes.append(_glow(big_eye, eye_uv, 42.0 * _s))
	_horse_eye = _glow(big_eye, HORSE_EYE, 48.0 * _s)
	_next_surge = _rng.randf_range(1.5, 3.0)

	# Ghost faces, cut straight out of the painting.
	var image := _background.texture.get_image()
	if image.is_compressed():
		image.decompress()
	_ghost_textures.clear()
	_ghost_eyes.clear()
	for crop in GHOST_CROPS:
		_ghost_textures.append(ImageTexture.create_from_image(image.get_region(crop["rect"])))
		_ghost_eyes.append(crop["eyes"])
	_next_ghost = _rng.randf_range(2.0, 4.0)

	set_process(true)


# --- helpers --------------------------------------------------------

func _add_rect(shader: Shader, rect_uv: Rect2, params: Dictionary) -> ColorRect:
	var a: Vector2 = _atm._image_to_local(rect_uv.position)
	var b: Vector2 = _atm._image_to_local(rect_uv.end)
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("aspect", (b.x - a.x) / (b.y - a.y))
	for key in params:
		mat.set_shader_parameter(key, params[key])
	var r := ColorRect.new()
	r.material = mat
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.position = a
	r.size = b - a
	add_child(r)
	return r


func _glow(tex: Texture2D, uv: Vector2, diameter: float) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.size = Vector2.ONE * diameter
	r.position = _atm._image_to_local(uv) - r.size * 0.5
	r.pivot_offset = r.size * 0.5
	r.material = _atm._additive()
	add_child(r)
	return r


## A random index in 0..count-1 that isn't `avoid`.
func _pick_other(count: int, avoid: int) -> int:
	if avoid < 0:
		return _rng.randi_range(0, count - 1)
	var i := _rng.randi_range(0, count - 2)
	return i + 1 if i >= avoid else i


# --- per frame ------------------------------------------------------

func _process(delta: float) -> void:
	_time += delta
	_update_hands(delta)
	_update_eyes(delta)
	_update_figures(delta)
	_update_ghost(delta)


## Each hand: creeps slowly closer, lunges, hangs there trembling, then
## sinks back - on its own cycle length.
func _update_hands(delta: float) -> void:
	for i in _hands.size():
		var h: Dictionary = _hands[i]
		h["t"] = fmod(h["t"] + delta / h["period"], 1.0)
		var p: float = h["t"]
		var reach: float
		if p < 0.5:
			reach = 0.25 * smoothstep(0.0, 0.5, p)
		elif p < 0.58:
			reach = lerpf(0.25, 1.0, smoothstep(0.5, 0.58, p))
		elif p < 0.7:
			reach = 1.0 + 0.04 * sin(_time * 40.0)
		else:
			reach = 1.0 - smoothstep(0.7, 1.0, p)
		_hand_amounts[i] = h["peak"] * reach
	_bg_mat.set_shader_parameter("hand_amount", _hand_amounts)


## Morvael's eyes glow steadily and flare every few seconds, and the
## mist spilling from them swells and lengthens with each flare.
func _update_eyes(delta: float) -> void:
	_next_surge -= delta
	if _next_surge <= 0.0:
		_surge = 1.0
		_next_surge = _rng.randf_range(SURGE_EVERY.x, SURGE_EVERY.y)
	_surge = move_toward(_surge, 0.0, delta / SURGE_TIME)
	var surge := smoothstep(0.0, 0.5, _surge)
	var bright := 0.7 + 0.15 * sin(_time * 2.1) + 0.9 * surge
	for eye in _rider_eyes:
		eye.modulate = Color(bright, bright, bright, 1.0)
		eye.scale = Vector2.ONE * (1.0 + 0.5 * surge)
	_eye_plume.set_shader_parameter("intensity", lerpf(0.55, 0.95, surge))
	_eye_plume.set_shader_parameter("plume_length", lerpf(0.72, 0.92, surge))
	var horse := 0.6 + 0.2 * sin(_time * 1.3 + 1.0)
	_horse_eye.modulate = Color(horse, horse, horse, 1.0)


## Shapes in the mist: eyes slowly brighten and dim, flicker a little,
## and every so often blink out for a moment.
func _update_figures(delta: float) -> void:
	for f in _figure_eyes:
		f["blink_in"] -= delta
		if f["blink_t"] < 0.0 and f["blink_in"] <= 0.0:
			f["blink_t"] = 0.0
			f["blink_in"] = _rng.randf_range(4.0, 11.0)
		var open := 1.0
		if f["blink_t"] >= 0.0:
			f["blink_t"] += delta
			var p: float = f["blink_t"] / 0.3
			if p >= 1.0:
				f["blink_t"] = -1.0
			else:
				open = 1.0 - sin(p * PI)
		var bright: float = (0.35 + 0.55 * (0.5 + 0.5 * sin(_time * f["speed"] + f["phase"]))) \
				* (0.9 + 0.1 * sin(_time * 17.0 + f["phase"])) * open
		for eye: TextureRect in f["nodes"]:
			eye.modulate = Color(bright, bright, bright, 1.0)


## One ghost at a time rises out of the mist, then drifts toward the
## viewer - slowly at first, growing faster the closer it gets, like
## anything approaching - until it fills the screen and fades through.
func _update_ghost(delta: float) -> void:
	if _ghost.is_empty():
		_next_ghost -= delta
		if _next_ghost <= 0.0:
			_spawn_ghost()
		return

	_ghost["t"] += delta
	var p: float = _ghost["t"] / _ghost["duration"]
	var node: TextureRect = _ghost["node"]
	if p >= 1.0:
		node.queue_free()
		_ghost = {}
		_next_ghost = _rng.randf_range(GHOST_GAP.x, GHOST_GAP.y)
		return

	var h: float = _ghost["h0"] * pow(_ghost["h1"] / _ghost["h0"], pow(p, 2.2))
	node.size = Vector2(h * _ghost["aspect"], h)
	# Things coming at you slide away from the middle of your view.
	var center: Vector2 = _ghost["start"] + (_ghost["start"] - get_viewport_rect().size * 0.5) * 0.5 * p * p
	center.y += sin(_ghost["t"] * 0.9) * 6.0
	node.position = center - node.size * 0.5
	var mat := node.material as ShaderMaterial
	mat.set_shader_parameter("approach", p)
	mat.set_shader_parameter("fade", _ghost["peak"] * smoothstep(0.0, 0.2, p) * (1.0 - smoothstep(0.75, 1.0, p)))


func _spawn_ghost() -> void:
	_last_spawn = _pick_other(GHOST_SPAWNS.size(), _last_spawn)
	_last_crop = _pick_other(_ghost_textures.size(), _last_crop)
	var tex := _ghost_textures[_last_crop]
	var mat := ShaderMaterial.new()
	mat.shader = GHOST_SHADER
	mat.set_shader_parameter("seed", _rng.randf() * 10.0)
	mat.set_shader_parameter("fade", 0.0)
	mat.set_shader_parameter("eye_a", _ghost_eyes[_last_crop][0])
	mat.set_shader_parameter("eye_b", _ghost_eyes[_last_crop][1])
	var node := TextureRect.new()
	node.texture = tex
	node.material = mat
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(node)   # last child: over every other effect
	var k := _s / 0.7656   # tuned at 1280-wide
	_ghost = {
		"node": node,
		"t": 0.0,
		"duration": _rng.randf_range(GHOST_TIME.x, GHOST_TIME.y),
		"start": _atm._image_to_local(GHOST_SPAWNS[_last_spawn]),
		"aspect": tex.get_size().x / tex.get_size().y,
		"h0": GHOST_START_HEIGHT * k * _rng.randf_range(0.8, 1.2),
		"h1": GHOST_END_HEIGHT * get_viewport_rect().size.y,
		"peak": _rng.randf_range(0.75, 0.95),
	}
