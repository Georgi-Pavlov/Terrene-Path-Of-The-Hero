extends Control
# ------------------------------------------------------------------
# ZoneAtmosphere
# Purely visual layer for the hero picker (Zone.tscn). Sits right after
# the Background node so every label/panel draws on top, never takes
# input and never touches game state. zone.gd calls
# show_for_background() whenever the shown hero changes; effects only
# exist for backgrounds that have them (currently Veyrik's Iron Abyss,
# Erynd's Elderwild and Morvael's Kingdom of Morvain) and are torn down
# again when switching to any other hero. Morvain's effects live in
# their own script, MorvainAtmosphere.gd, run as a child of this node.
#
# Iron Abyss:
#   - Veyrik's eye: a cold glow that breathes, flaring every few seconds
#   - drool gathering on his lower jaw and dripping off
#   - Veyrik himself slowly breathing (a soft swell of his body)
#   - bubbles rising around him, wobbling and popping
#   - the giant red eye in the abyss pulsing, blinking now and then
#   - light shafts slanting down from the surface, slowly swaying
#   - the prison's lanterns and lit cages flickering, each on its own
#   - a subtle underwater ripple over the whole art (not the frame)
#
# Elderwild:
#   - fog rolling through the forest around the werewolf
#   - the werewolf's eyes smouldering, flaring now and then, and its
#     breath steaming from its jaws
#   - the carved runes (tree and standing stone) glowing with a slow
#     wave of light running down them
#   - the bear slowly breathing, a glint in its eye
#   - pale moonbeams through the canopy
#   - autumn leaves tumbling down and green spirit motes drifting
#     around Erynd
#   - light glinting on the creek
#
# Positions of art features are given as fractions (0..1) of the
# background image, so they stay on target whatever the screen size.
# ------------------------------------------------------------------

@export var background_path: NodePath = ^"../Background"

const IRON_ABYSS_BG := "res://assets/zones/the_iron_abyss.jpg"

const RIPPLE_SHADER := preload("res://shaders/underwater_ripple.gdshader")
const SHAFTS_SHADER := preload("res://shaders/light_shafts.gdshader")
# The painted stats frame (UV x0, y0, x1, y1) - kept free of ripple.
const FRAME_CALM_RECT := Vector4(0.01, 0.585, 0.455, 0.94)

# Breathing: centered on his torso, reaching out to (but not touching)
# his eye and jaws, so the glow and drips stay lined up with the art.
const BREATHE_CENTER_UV := Vector2(0.2, 0.33)
const BREATHE_RADIUS := 0.32             # in units of image height
const BREATHE_AMOUNT := 0.025
const BREATHE_PERIOD := 4.4

# Light shafts: the rect they're drawn in (image UV) and where, in that
# rect's own UV, the light comes from - above the central tower.
const SHAFTS_RECT_UV := Rect2(0.5, 0.0, 0.5, 0.8)
const SHAFTS_ORIGIN := Vector2(0.447, -0.3)

# Warm lit windows, cages and lanterns: image UV, glow radius in source
# pixels, and how strongly each one shows.
const LANTERNS := [
	{"uv": Vector2(0.7225, 0.3932), "r": 38.0, "base": 0.55},  # central tower, main windows
	{"uv": Vector2(0.7297, 0.1977), "r": 16.0, "base": 0.45},  # central tower, top
	{"uv": Vector2(0.7267, 0.5739), "r": 24.0, "base": 0.5},   # lower middle cage
	{"uv": Vector2(0.5682, 0.5845), "r": 32.0, "base": 0.5},   # left tower cage
	{"uv": Vector2(0.6513, 0.6440), "r": 16.0, "base": 0.4},   # small left tower
	{"uv": Vector2(0.5849, 0.8077), "r": 32.0, "base": 0.6},   # lantern cage, lower left
	{"uv": Vector2(0.9444, 0.4155), "r": 58.0, "base": 0.5},   # big cage, right
	{"uv": Vector2(0.9551, 0.6929), "r": 36.0, "base": 0.45},  # lower cage, right
	{"uv": Vector2(0.8911, 0.7673), "r": 22.0, "base": 0.55},  # hanging lantern
	{"uv": Vector2(0.8941, 0.1084), "r": 26.0, "base": 0.4},   # top right cage
]
const LANTERN_COLOR := Color(1.0, 0.68, 0.36)

# Where drool gathers along his lower jaw (image UV).
const DRIP_ORIGINS := [
	Vector2(0.3756, 0.3698),
	Vector2(0.3816, 0.3741),
	Vector2(0.3876, 0.3613),
	Vector2(0.3971, 0.3507),
]
const DRIP_WAIT := Vector2(1.5, 5.0)
const DRIP_FORM_TIME := Vector2(0.9, 1.8)
const DRIP_GRAVITY := 320.0              # px/s² at 1280-wide
const DRIP_FALL := Vector2(55.0, 100.0)  # source pixels before it fades out

const VEYRIK_EYE_UV := Vector2(0.3816, 0.2295)
const VEYRIK_EYE_RADIUS_PX := 9.0         # in source image pixels
const VEYRIK_EYE_PULSE_TIME := 3.6
const VEYRIK_EYE_FLARE_EVERY := Vector2(4.0, 8.0)

const ABYSS_EYE_UV := Vector2(0.8062, 0.8321)
const ABYSS_EYE_RADIUS_PX := 29.0         # the iris, in source image pixels
const ABYSS_EYE_PULSE_TIME := 5.2
const ABYSS_EYE_BLINK_EVERY := Vector2(9.0, 16.0)
const ABYSS_EYE_BLINK_TIME := 0.42

# Where bubbles are born (image UV rects) and how often, relative to
# each other. Kept off Veyrik's body and away from the description text.
const BUBBLE_SOURCES := [
	{"rect": Rect2(0.0, 0.22, 0.05, 0.45), "weight": 3.0},    # left edge
	{"rect": Rect2(0.44, 0.12, 0.05, 0.48), "weight": 3.0},   # right of his head
	{"rect": Rect2(0.08, 0.03, 0.30, 0.10), "weight": 1.0},   # above his crest
	{"rect": Rect2(0.93, 0.35, 0.07, 0.40), "weight": 2.0},   # right edge
	{"rect": Rect2(0.52, 0.60, 0.20, 0.28), "weight": 1.0},   # the city below
]
const BUBBLE_COUNT := 48
const BUBBLE_LIFE := Vector2(3.0, 7.0)
const BUBBLE_POP_TIME := 0.18
const BUBBLE_FADE_IN := 0.5

const MORVAIN_BG := "res://assets/zones/kingdom_of_morvain.jpg"
# Morvain runs in its own child node - see MorvainAtmosphere.gd.
const MORVAIN_FX := preload("res://scripts/MorvainAtmosphere.gd")

const ELDERWILD_BG := "res://assets/zones/The Elderwild.jpg"
const ELDERWILD_SHADER := preload("res://shaders/elderwild_background.gdshader")
const FOG_SHADER := preload("res://shaders/fog_drift.gdshader")

# The bear's chest, breathing (see the Iron Abyss constants for units).
const ELD_BREATHE_CENTER_UV := Vector2(0.3708, 0.4782)
const ELD_BREATHE_RADIUS := 0.14
const ELD_BREATHE_AMOUNT := 0.02
const ELD_BREATHE_PERIOD := 5.0

# Carved runes (UV x0, y0, x1, y1): the diamond on the tree, the spiral
# on the standing stone.
const ELD_RUNE_TREE := Vector4(0.4019, 0.0829, 0.4456, 0.1934)
const ELD_RUNE_STONE := Vector4(0.4856, 0.4198, 0.5323, 0.5792)
const ELD_RUNE_COLOR := Color(0.55, 1.0, 0.72)
# The creek, bottom right.
const ELD_WATER := Vector4(0.67, 0.829, 0.855, 1.0)

# Fog (image UV rect) and moonbeams (rect, then origin in its own UV).
const ELD_FOG_RECT_UV := Rect2(0.5, 0.14, 0.5, 0.68)
# Mist: thin wisps drifting across the whole scene, and a low ground
# mist creeping along the forest floor and the creek.
const ELD_WISPS_RECT_UV := Rect2(0.0, 0.0, 1.0, 1.0)
const ELD_GROUND_MIST_RECT_UV := Rect2(0.0, 0.55, 1.0, 0.45)
const ELD_MOON_RECT_UV := Rect2(0.55, 0.0, 0.45, 0.75)
const ELD_MOON_ORIGIN := Vector2(0.466, -0.12)

const WOLF_EYES_UV := [Vector2(0.7781, 0.3974), Vector2(0.8032, 0.3974)]
const WOLF_EYE_RADIUS_PX := 5.5
const WOLF_EYE_PULSE_TIME := 3.1
const WOLF_EYE_FLARE_EVERY := Vector2(3.5, 7.0)
const WOLF_MOUTH_UV := Vector2(0.7895, 0.4516)
const WOLF_BREATH_EVERY := Vector2(2.2, 3.4)

const BEAR_EYE_UV := Vector2(0.3624, 0.4006)

# Leaves fall on the right, kept clear of Erynd, the stats frame and the
# zone description (upper right): from the canopy gap left of the text,
# and out of the fog just below it. Motes drift around Erynd and his bear.
const LEAF_SOURCES := [
	{"rect": Rect2(0.46, -0.03, 0.06, 0.3), "weight": 1.0},
	{"rect": Rect2(0.55, 0.43, 0.43, 0.1), "weight": 2.5},
]
const LEAF_COUNT := 22
const LEAF_LIFE := Vector2(6.0, 11.0)
const LEAF_COLORS := [
	Color(0.78, 0.33, 0.1), Color(0.62, 0.14, 0.07), Color(0.86, 0.55, 0.16),
	Color(0.5, 0.28, 0.12), Color(0.72, 0.42, 0.12),
]
const MOTE_SOURCE := Rect2(0.02, 0.08, 0.44, 0.5)
const MOTE_COUNT := 16
const MOTE_LIFE := Vector2(4.0, 8.0)

var _background: TextureRect
var _active := false
# Which zone's effects are currently built ("iron_abyss" / "elderwild").
var _zone := ""
var _build_id := 0
var _time := 0.0
var _rng := RandomNumberGenerator.new()

var _bubble_tex: Texture2D
var _highlight_tex: Texture2D
var _bubbles: Array[Dictionary] = []
# Drawn on its own child, added last, so bubbles and drips pass over
# the glows.
var _bubble_layer: Control
var _spawn_accum := 0.0
var _source_weight_total := 0.0

var _veyrik_glow: TextureRect
# Wide, faint halo that only blooms while the eye flares.
var _veyrik_halo: TextureRect
var _veyrik_flare := 0.0
var _veyrik_next_flare := 0.0

var _abyss_glow: TextureRect
var _abyss_lid: TextureRect
var _abyss_blink_t := -1.0
var _abyss_next_blink := 0.0

# One entry per LANTERNS item: its glow node plus its own flicker rhythm.
var _lanterns: Array[Dictionary] = []

var _drop_tex: Texture2D
# One entry per DRIP_ORIGINS item - each spot has at most one drop.
var _drips: Array[Dictionary] = []

# Elderwild.
var _wolf_eyes: Array[TextureRect] = []
var _wolf_flare := 0.0
var _wolf_next_flare := 0.0
var _wolf_next_breath := 0.0
var _puff_tex: Texture2D
var _puffs: Array[Dictionary] = []
var _bear_glint: TextureRect
var _leaves: Array[Dictionary] = []
var _leaf_accum := 0.0
var _motes: Array[Dictionary] = []
var _mote_accum := 0.0
var _mote_tex: Texture2D
# Leaves, motes and breath puffs, drawn on top of everything else.
var _particle_layer: Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)
	_rng.randomize()
	_background = get_node_or_null(background_path) as TextureRect
	for source in BUBBLE_SOURCES:
		_source_weight_total += source["weight"]


## Called by zone.gd after it has set the background for the shown hero.
func show_for_background(path: String) -> void:
	_clear()
	if _background == null or not path in [IRON_ABYSS_BG, ELDERWILD_BG, MORVAIN_BG]:
		return
	# Guards against a hero switch landing during the await below.
	_build_id += 1
	var build_id := _build_id
	# Layout sizes aren't final until the first frame is processed.
	await get_tree().process_frame
	if build_id != _build_id or _background.texture == null:
		return
	if path == IRON_ABYSS_BG:
		_build_iron_abyss()
	elif path == MORVAIN_BG:
		_build_morvain()
	else:
		_build_elderwild()


func _clear() -> void:
	_build_id += 1
	_active = false
	set_process(false)
	for child in get_children():
		child.queue_free()
	_bubbles.clear()
	_lanterns.clear()
	_drips.clear()
	_veyrik_glow = null
	_veyrik_halo = null
	_abyss_glow = null
	_abyss_lid = null
	_bubble_layer = null
	_zone = ""
	_wolf_eyes.clear()
	_puffs.clear()
	_leaves.clear()
	_motes.clear()
	_bear_glint = null
	_particle_layer = null
	if _background:
		_background.material = null


# --- helpers --------------------------------------------------------

## Maps a point in the background image (0..1) to the Background node's
## local coordinates (which this node shares), matching its "keep
## aspect covered" stretch mode.
func _image_to_local(uv: Vector2) -> Vector2:
	var tex_size := _background.texture.get_size()
	var rect_size := _background.size
	var s: float = max(rect_size.x / tex_size.x, rect_size.y / tex_size.y)
	var drawn := tex_size * s
	return (rect_size - drawn) * 0.5 + uv * drawn

func _image_scale() -> float:
	var tex_size := _background.texture.get_size()
	var rect_size := _background.size
	return max(rect_size.x / tex_size.x, rect_size.y / tex_size.y)

func _radial(size: int, offsets: PackedFloat32Array, colors: PackedColorArray) -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = offsets
	g.colors = colors
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = size
	t.height = size
	return t

func _additive() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m

## A fog_drift.gdshader layer covering `rect_uv` of the image, with
## `params` passed straight through as shader parameters.
func _add_fog(rect_uv: Rect2, params: Dictionary) -> ColorRect:
	var a := _image_to_local(rect_uv.position)
	var b := _image_to_local(rect_uv.end)
	var mat := ShaderMaterial.new()
	mat.shader = FOG_SHADER
	mat.set_shader_parameter("aspect", (b.x - a.x) / (b.y - a.y))
	for key in params:
		mat.set_shader_parameter(key, params[key])
	var fog := ColorRect.new()
	fog.material = mat
	fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fog.position = a
	fog.size = b - a
	add_child(fog)
	return fog

func _centered_rect(tex: Texture2D, center: Vector2, rect_size: Vector2) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.size = rect_size
	r.position = center - rect_size * 0.5
	r.pivot_offset = rect_size * 0.5
	add_child(r)
	return r


# --- Iron Abyss -----------------------------------------------------

func _build_iron_abyss() -> void:
	var s := _image_scale()

	# Underwater ripple, straight on the background texture.
	var ripple := ShaderMaterial.new()
	ripple.shader = RIPPLE_SHADER
	ripple.set_shader_parameter("calm_rect", FRAME_CALM_RECT)
	var tex_size := _background.texture.get_size()
	ripple.set_shader_parameter("aspect", tex_size.x / tex_size.y)
	ripple.set_shader_parameter("breathe_center", BREATHE_CENTER_UV)
	ripple.set_shader_parameter("breathe_radius", BREATHE_RADIUS)
	ripple.set_shader_parameter("breathe_amount", BREATHE_AMOUNT)
	ripple.set_shader_parameter("breathe_period", BREATHE_PERIOD)
	_background.material = ripple

	# Light shafts, behind every other effect.
	var shafts_a := _image_to_local(SHAFTS_RECT_UV.position)
	var shafts_b := _image_to_local(SHAFTS_RECT_UV.end)
	var shafts_mat := ShaderMaterial.new()
	shafts_mat.shader = SHAFTS_SHADER
	shafts_mat.set_shader_parameter("origin", SHAFTS_ORIGIN)
	shafts_mat.set_shader_parameter("aspect", (shafts_b.x - shafts_a.x) / (shafts_b.y - shafts_a.y))
	var shafts := ColorRect.new()
	shafts.material = shafts_mat
	shafts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shafts.position = shafts_a
	shafts.size = shafts_b - shafts_a
	add_child(shafts)

	# Lanterns: a warm glow on each, flickering on its own rhythm.
	var lantern_tex := _radial(64,
		PackedFloat32Array([0.0, 0.25, 1.0]),
		PackedColorArray([
			Color(LANTERN_COLOR, 0.55),
			Color(LANTERN_COLOR, 0.3),
			Color(LANTERN_COLOR, 0.0),
		]))
	_lanterns.clear()
	for lantern in LANTERNS:
		var glow := _centered_rect(lantern_tex, _image_to_local(lantern["uv"]), Vector2.ONE * lantern["r"] * s * 3.0)
		glow.material = _additive()
		_lanterns.append({
			"node": glow,
			"base": lantern["base"],
			"f1": _rng.randf_range(5.0, 9.0),
			"f2": _rng.randf_range(11.0, 17.0),
			"p1": _rng.randf() * TAU,
			"p2": _rng.randf() * TAU,
			"dip": 0.0,
		})

	# The abyss eye: a red glow plus an eyelid for blinking.
	var abyss_r := ABYSS_EYE_RADIUS_PX * s
	_abyss_glow = _centered_rect(_radial(128,
		PackedFloat32Array([0.0, 0.18, 0.45, 1.0]),
		PackedColorArray([
			Color(1.0, 0.35, 0.25, 0.9),
			Color(0.95, 0.12, 0.08, 0.6),
			Color(0.6, 0.02, 0.02, 0.22),
			Color(0.4, 0.0, 0.0, 0.0),
		])), _image_to_local(ABYSS_EYE_UV), Vector2.ONE * abyss_r * 5.0)
	_abyss_glow.material = _additive()
	# Eyelid: a dark soft ellipse that squashes open/closed over the iris.
	_abyss_lid = _centered_rect(_radial(64,
		PackedFloat32Array([0.0, 0.6, 1.0]),
		PackedColorArray([
			Color(0.02, 0.04, 0.06, 0.95),
			Color(0.02, 0.04, 0.06, 0.85),
			Color(0.02, 0.04, 0.06, 0.0),
		])), _image_to_local(ABYSS_EYE_UV), Vector2(abyss_r * 3.4, abyss_r * 2.6))
	_abyss_lid.scale.y = 0.0
	_abyss_blink_t = -1.0
	_abyss_next_blink = _rng.randf_range(ABYSS_EYE_BLINK_EVERY.x * 0.5, ABYSS_EYE_BLINK_EVERY.y * 0.5)

	# Veyrik's eye.
	var eye_r := VEYRIK_EYE_RADIUS_PX * s
	_veyrik_halo = _centered_rect(_radial(128,
		PackedFloat32Array([0.0, 0.2, 1.0]),
		PackedColorArray([
			Color(0.7, 0.88, 1.0, 0.55),
			Color(0.4, 0.65, 1.0, 0.25),
			Color(0.2, 0.4, 0.9, 0.0),
		])), _image_to_local(VEYRIK_EYE_UV), Vector2.ONE * eye_r * 22.0)
	_veyrik_halo.material = _additive()
	_veyrik_halo.modulate = Color(0, 0, 0, 1)
	_veyrik_glow = _centered_rect(_radial(128,
		PackedFloat32Array([0.0, 0.12, 0.3, 1.0]),
		PackedColorArray([
			Color(1.0, 1.0, 1.0, 0.95),
			Color(0.8, 0.93, 1.0, 0.7),
			Color(0.45, 0.7, 0.95, 0.25),
			Color(0.3, 0.5, 0.9, 0.0),
		])), _image_to_local(VEYRIK_EYE_UV), Vector2.ONE * eye_r * 7.0)
	_veyrik_glow.material = _additive()
	_veyrik_flare = 0.0
	_veyrik_next_flare = _rng.randf_range(1.5, VEYRIK_EYE_FLARE_EVERY.x)

	# Bubbles: a thin bright rim around a nearly clear middle.
	_bubble_tex = _radial(64,
		PackedFloat32Array([0.0, 0.62, 0.82, 0.93, 1.0]),
		PackedColorArray([
			Color(1, 1, 1, 0.04),
			Color(1, 1, 1, 0.1),
			Color(1, 1, 1, 0.55),
			Color(1, 1, 1, 0.3),
			Color(1, 1, 1, 0.0),
		]))
	_highlight_tex = _radial(32,
		PackedFloat32Array([0.0, 1.0]),
		PackedColorArray([Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.0)]))
	_bubble_layer = Control.new()
	_bubble_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bubble_layer.draw.connect(_draw_bubbles)
	add_child(_bubble_layer)
	_bubbles.clear()
	_spawn_accum = 0.0
	# Pre-warm so the screen doesn't open empty.
	for i in 150:
		_update_bubbles(1.0 / 30.0)

	# Drips: a soft round drop, stretched as it falls.
	_drop_tex = _radial(32,
		PackedFloat32Array([0.0, 0.55, 1.0]),
		PackedColorArray([Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0.0)]))
	_drips.clear()
	for origin in DRIP_ORIGINS:
		_drips.append({"origin": _image_to_local(origin), "state": "wait",
			"t": _rng.randf_range(0.2, DRIP_WAIT.y)})

	_time = 0.0
	_zone = "iron_abyss"
	_active = true
	set_process(true)


func _process(delta: float) -> void:
	if not _active:
		return
	_time += delta
	if _zone == "elderwild":
		_process_elderwild(delta)
		return
	_update_veyrik_eye(delta)
	_update_abyss_eye(delta)
	_update_lanterns(delta)
	_update_bubbles(delta)
	_update_drips(delta)
	_bubble_layer.queue_redraw()


func _update_veyrik_eye(delta: float) -> void:
	_veyrik_next_flare -= delta
	if _veyrik_next_flare <= 0.0:
		_veyrik_flare = 1.0
		_veyrik_next_flare = _rng.randf_range(VEYRIK_EYE_FLARE_EVERY.x, VEYRIK_EYE_FLARE_EVERY.y)
	_veyrik_flare = move_toward(_veyrik_flare, 0.0, delta * 1.4)
	var breathe := 0.5 + 0.5 * sin(_time * TAU / VEYRIK_EYE_PULSE_TIME)
	# Sharp attack, slow decay: squaring the envelope keeps the tail soft.
	var flare := _veyrik_flare * _veyrik_flare
	var bright := 0.45 + 0.3 * breathe + 1.1 * flare
	_veyrik_glow.modulate = Color(bright, bright, bright, 1.0)
	_veyrik_glow.scale = Vector2.ONE * (1.0 + 0.35 * flare)
	_veyrik_halo.modulate = Color(flare, flare, flare, 1.0)
	_veyrik_halo.scale = Vector2.ONE * (0.6 + 0.4 * _veyrik_flare)


func _update_abyss_eye(delta: float) -> void:
	_abyss_next_blink -= delta
	if _abyss_blink_t < 0.0 and _abyss_next_blink <= 0.0:
		_abyss_blink_t = 0.0
		_abyss_next_blink = _rng.randf_range(ABYSS_EYE_BLINK_EVERY.x, ABYSS_EYE_BLINK_EVERY.y)
	var closed := 0.0
	if _abyss_blink_t >= 0.0:
		_abyss_blink_t += delta
		var p := _abyss_blink_t / ABYSS_EYE_BLINK_TIME
		if p >= 1.0:
			_abyss_blink_t = -1.0
		else:
			# Close fast, hang a moment, open a little slower.
			closed = smoothstep(0.0, 0.25, p) * (1.0 - smoothstep(0.45, 1.0, p))
	_abyss_lid.scale.y = closed
	var breathe := 0.5 + 0.5 * sin(_time * TAU / ABYSS_EYE_PULSE_TIME)
	var bright := (0.35 + 0.5 * breathe) * (1.0 - 0.85 * closed)
	_abyss_glow.modulate = Color(bright, bright, bright, 1.0)


func _update_lanterns(delta: float) -> void:
	for l in _lanterns:
		# Now and then a flame gutters: a quick dip that recovers.
		if _rng.randf() < delta * 0.12:
			l["dip"] = 1.0
		l["dip"] = move_toward(l["dip"], 0.0, delta * 4.0)
		var flicker: float = 0.8 + 0.12 * sin(_time * l["f1"] + l["p1"]) + 0.08 * sin(_time * l["f2"] + l["p2"])
		var bright: float = l["base"] * flicker * (1.0 - 0.55 * l["dip"])
		l["node"].modulate = Color(bright, bright, bright, 1.0)


func _update_drips(delta: float) -> void:
	var s := _image_scale()
	for d in _drips:
		d["t"] += delta if d["state"] != "wait" else -delta
		match d["state"]:
			"wait":
				if d["t"] <= 0.0:
					d["state"] = "form"
					d["t"] = 0.0
					d["form_time"] = _rng.randf_range(DRIP_FORM_TIME.x, DRIP_FORM_TIME.y)
					d["r"] = _rng.randf_range(1.4, 2.4) * s / 0.7656
					d["color"] = Color(0.62, 0.07, 0.07) if _rng.randf() < 0.3 else Color(0.85, 0.9, 0.95)
			"form":
				if d["t"] >= d["form_time"]:
					d["state"] = "fall"
					d["dist"] = 0.0
					d["v"] = 0.0
					d["fall_max"] = _rng.randf_range(DRIP_FALL.x, DRIP_FALL.y) * s
			"fall":
				d["v"] += DRIP_GRAVITY * (s / 0.7656) * delta
				d["dist"] += d["v"] * delta
				if d["dist"] >= d["fall_max"]:
					d["state"] = "wait"
					d["t"] = _rng.randf_range(DRIP_WAIT.x, DRIP_WAIT.y)


func _update_bubbles(delta: float) -> void:
	var s := _image_scale()
	var i := _bubbles.size() - 1
	while i >= 0:
		var b: Dictionary = _bubbles[i]
		b["age"] += delta
		if b["age"] >= b["life"] + BUBBLE_POP_TIME:
			_bubbles.remove_at(i)
		else:
			b["y"] -= b["speed"] * delta
		i -= 1

	var avg_life := (BUBBLE_LIFE.x + BUBBLE_LIFE.y) * 0.5
	_spawn_accum += delta * BUBBLE_COUNT / avg_life
	while _spawn_accum >= 1.0:
		_spawn_accum -= 1.0
		_bubbles.append(_new_bubble(s))


func _new_bubble(s: float) -> Dictionary:
	var pick := _rng.randf() * _source_weight_total
	var rect: Rect2 = BUBBLE_SOURCES[0]["rect"]
	for source in BUBBLE_SOURCES:
		pick -= source["weight"]
		if pick <= 0.0:
			rect = source["rect"]
			break
	var uv := rect.position + Vector2(_rng.randf(), _rng.randf()) * rect.size
	var pos := _image_to_local(uv)
	# Mostly tiny, now and then a big slow one.
	var radius := _rng.randf_range(1.5, 4.5)
	if _rng.randf() < 0.1:
		radius = _rng.randf_range(6.0, 9.0)
	radius *= s / 0.7656   # tuned at 1280-wide
	return {
		"x": pos.x,
		"y": pos.y,
		"r": radius,
		"speed": (18.0 + radius * 5.0) * _rng.randf_range(0.8, 1.2),
		"wobble": _rng.randf_range(1.5, 4.0),
		"freq": _rng.randf_range(1.2, 2.6),
		"phase": _rng.randf() * TAU,
		"age": 0.0,
		"life": _rng.randf_range(BUBBLE_LIFE.x, BUBBLE_LIFE.y),
		"alpha": _rng.randf_range(0.45, 0.85),
	}


func _draw_bubbles() -> void:
	_draw_drips()
	var tint := Color(0.75, 0.9, 1.0)
	for b in _bubbles:
		var age: float = b["age"]
		var life: float = b["life"]
		var r: float = b["r"]
		var a: float = b["alpha"] * clampf(age / BUBBLE_FADE_IN, 0.0, 1.0)
		if age > life:
			# Pop: swell quickly and vanish.
			var p := (age - life) / BUBBLE_POP_TIME
			r *= 1.0 + 0.7 * p
			a *= 1.0 - p
		var x: float = b["x"] + sin(age * b["freq"] + b["phase"]) * b["wobble"]
		var center := Vector2(x, b["y"])
		_bubble_layer.draw_texture_rect(_bubble_tex, Rect2(center - Vector2.ONE * r, Vector2.ONE * r * 2.0), false, Color(tint, a))
		var h := r * 0.55
		_bubble_layer.draw_texture_rect(_highlight_tex, Rect2(center + Vector2(-0.35, -0.35) * r - Vector2.ONE * h * 0.5, Vector2.ONE * h), false, Color(1, 1, 1, a * 0.8))


func _draw_drips() -> void:
	for d in _drips:
		if d["state"] == "wait":
			continue
		var origin: Vector2 = d["origin"]
		var r: float = d["r"]
		var col: Color = d["color"]
		if d["state"] == "form":
			# Swells and sags on the jaw, still tethered by a thin strand.
			var g: float = smoothstep(0.0, 1.0, d["t"] / d["form_time"])
			var center := origin + Vector2(0.0, r * 1.6 * g)
			var sz := Vector2(2.0 * r * g, 2.0 * r * g * (1.0 + 0.5 * g))
			_bubble_layer.draw_line(origin, center, Color(col, 0.5 * g), maxf(r * 0.5 * g, 0.5))
			_bubble_layer.draw_texture_rect(_drop_tex, Rect2(center - sz * 0.5, sz), false, Color(col, 0.85))
		else:
			var dist: float = d["dist"]
			var a: float = 0.85 * (1.0 - smoothstep(0.6, 1.0, dist / d["fall_max"]))
			var center := origin + Vector2(0.0, r * 1.6 + dist)
			var stretch := 1.0 + minf(d["v"] / 150.0, 1.5)
			var sz := Vector2(2.0 * r * 0.85, 2.0 * r * stretch)
			# A faint streak trailing behind it.
			_bubble_layer.draw_line(center - Vector2(0.0, d["v"] * 0.05), center, Color(col, a * 0.35), maxf(r * 0.6, 0.5))
			_bubble_layer.draw_texture_rect(_drop_tex, Rect2(center - sz * 0.5, sz), false, Color(col, a))


# --- Elderwild ------------------------------------------------------

func _build_elderwild() -> void:
	var s := _image_scale()
	var tex_size := _background.texture.get_size()

	# Breathing bear, glowing runes and glinting creek, on the art itself.
	var bg := ShaderMaterial.new()
	bg.shader = ELDERWILD_SHADER
	bg.set_shader_parameter("aspect", tex_size.x / tex_size.y)
	bg.set_shader_parameter("breathe_center", ELD_BREATHE_CENTER_UV)
	bg.set_shader_parameter("breathe_radius", ELD_BREATHE_RADIUS)
	bg.set_shader_parameter("breathe_amount", ELD_BREATHE_AMOUNT)
	bg.set_shader_parameter("breathe_period", ELD_BREATHE_PERIOD)
	bg.set_shader_parameter("rune_rect_a", ELD_RUNE_TREE)
	bg.set_shader_parameter("rune_rect_b", ELD_RUNE_STONE)
	bg.set_shader_parameter("rune_color", ELD_RUNE_COLOR)
	bg.set_shader_parameter("water_rect", ELD_WATER)
	_background.material = bg

	# Moonbeams through the canopy, pale and faint.
	var moon_a := _image_to_local(ELD_MOON_RECT_UV.position)
	var moon_b := _image_to_local(ELD_MOON_RECT_UV.end)
	var moon_mat := ShaderMaterial.new()
	moon_mat.shader = SHAFTS_SHADER
	moon_mat.set_shader_parameter("origin", ELD_MOON_ORIGIN)
	moon_mat.set_shader_parameter("aspect", (moon_b.x - moon_a.x) / (moon_b.y - moon_a.y))
	moon_mat.set_shader_parameter("shaft_color", Color(0.75, 0.8, 0.9))
	moon_mat.set_shader_parameter("intensity", 0.13)
	moon_mat.set_shader_parameter("spread", 0.7)
	var moon := ColorRect.new()
	moon.material = moon_mat
	moon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	moon.position = moon_a
	moon.size = moon_b - moon_a
	add_child(moon)

	# Thin mist wisps drifting across the whole scene, behind the rest.
	_add_fog(ELD_WISPS_RECT_UV, {
		"density": 0.16, "speed": 0.012, "scale": 1.6,
		"band_center": 0.45, "band_height": 0.8,
		"fog_color": Color(0.8, 0.84, 0.86),
		"edge_fade": Vector4(0.05, 0.1, 0.05, 0.1),
	})

	# Fog rolling through the forest.
	_add_fog(ELD_FOG_RECT_UV, {
		"density": 0.42, "band_center": 0.62, "band_height": 0.45,
		"edge_fade": Vector4(0.3, 0.15, 0.02, 0.2),
	})

	# Ground mist creeping along the forest floor and the creek - thick
	# low down, thinning upward, drifting a little faster than the fog.
	_add_fog(ELD_GROUND_MIST_RECT_UV, {
		"density": 0.4, "speed": 0.03, "scale": 4.0,
		"band_center": 0.85, "band_height": 0.7,
		"fog_color": Color(0.84, 0.87, 0.9),
		"edge_fade": Vector4(0.03, 0.45, 0.03, 0.02),
	})

	# The werewolf's eyes, over the fog so they burn through it.
	var eye_tex := _radial(128,
		PackedFloat32Array([0.0, 0.12, 0.35, 1.0]),
		PackedColorArray([
			Color(1.0, 0.95, 0.7, 0.95),
			Color(1.0, 0.65, 0.2, 0.7),
			Color(0.9, 0.35, 0.05, 0.25),
			Color(0.6, 0.15, 0.0, 0.0),
		]))
	_wolf_eyes.clear()
	for eye_uv in WOLF_EYES_UV:
		var eye := _centered_rect(eye_tex, _image_to_local(eye_uv), Vector2.ONE * WOLF_EYE_RADIUS_PX * s * 8.0)
		eye.material = _additive()
		_wolf_eyes.append(eye)
	_wolf_flare = 0.0
	_wolf_next_flare = _rng.randf_range(1.0, WOLF_EYE_FLARE_EVERY.x)
	_wolf_next_breath = _rng.randf_range(0.3, 1.2)

	# A small warm glint in the bear's eye.
	_bear_glint = _centered_rect(_radial(64,
		PackedFloat32Array([0.0, 0.3, 1.0]),
		PackedColorArray([Color(1.0, 0.85, 0.5, 0.8), Color(1.0, 0.6, 0.2, 0.3), Color(1.0, 0.5, 0.1, 0.0)])),
		_image_to_local(BEAR_EYE_UV), Vector2.ONE * 26.0 * s)
	_bear_glint.material = _additive()

	_puff_tex = _radial(64,
		PackedFloat32Array([0.0, 0.5, 1.0]),
		PackedColorArray([Color(1, 1, 1, 0.5), Color(1, 1, 1, 0.22), Color(1, 1, 1, 0.0)]))
	_mote_tex = _radial(32,
		PackedFloat32Array([0.0, 0.25, 1.0]),
		PackedColorArray([Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0.0)]))
	_particle_layer = Control.new()
	_particle_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_particle_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_particle_layer.draw.connect(_draw_elderwild_particles)
	add_child(_particle_layer)
	_puffs.clear()
	_leaves.clear()
	_motes.clear()
	_leaf_accum = 0.0
	_mote_accum = 0.0
	# Pre-warm so the screen doesn't open empty.
	for i in 240:
		_update_leaves(1.0 / 30.0)
		_update_motes(1.0 / 30.0)

	_time = 0.0
	_zone = "elderwild"
	_active = true
	set_process(true)


func _process_elderwild(delta: float) -> void:
	_update_wolf(delta)
	var glint := 0.55 + 0.25 * sin(_time * 0.9) + 0.2 * sin(_time * 2.3 + 1.0)
	_bear_glint.modulate = Color(glint, glint, glint, 1.0)
	_update_leaves(delta)
	_update_motes(delta)
	_particle_layer.queue_redraw()


func _update_wolf(delta: float) -> void:
	_wolf_next_flare -= delta
	if _wolf_next_flare <= 0.0:
		_wolf_flare = 1.0
		_wolf_next_flare = _rng.randf_range(WOLF_EYE_FLARE_EVERY.x, WOLF_EYE_FLARE_EVERY.y)
	_wolf_flare = move_toward(_wolf_flare, 0.0, delta * 1.2)
	var flare := _wolf_flare * _wolf_flare
	var breathe := 0.5 + 0.5 * sin(_time * TAU / WOLF_EYE_PULSE_TIME)
	var bright := 0.45 + 0.3 * breathe + 0.9 * flare
	for eye in _wolf_eyes:
		eye.modulate = Color(bright, bright, bright, 1.0)
		eye.scale = Vector2.ONE * (1.0 + 0.4 * flare)

	# Breath steaming from its jaws, a puff or two at a time.
	_wolf_next_breath -= delta
	if _wolf_next_breath <= 0.0:
		_wolf_next_breath = _rng.randf_range(WOLF_BREATH_EVERY.x, WOLF_BREATH_EVERY.y)
		var s := _image_scale() / 0.7656
		var mouth := _image_to_local(WOLF_MOUTH_UV)
		for i in _rng.randi_range(2, 3):
			_puffs.append({
				"pos": mouth + Vector2(_rng.randf_range(-6.0, 6.0), 0.0) * s,
				"vel": Vector2(_rng.randf_range(-14.0, 14.0), _rng.randf_range(4.0, 14.0)) * s,
				"r": _rng.randf_range(6.0, 10.0) * s,
				"age": -i * 0.12,
				"life": _rng.randf_range(1.3, 2.0),
			})
	var j := _puffs.size() - 1
	while j >= 0:
		var p: Dictionary = _puffs[j]
		p["age"] += delta
		if p["age"] >= p["life"]:
			_puffs.remove_at(j)
		elif p["age"] > 0.0:
			p["pos"] += p["vel"] * delta
			p["vel"] *= 1.0 - 0.8 * delta
		j -= 1


func _update_leaves(delta: float) -> void:
	var s := _image_scale() / 0.7656
	var i := _leaves.size() - 1
	while i >= 0:
		var l: Dictionary = _leaves[i]
		l["age"] += delta
		if l["age"] >= l["life"]:
			_leaves.remove_at(i)
		else:
			l["y"] += l["fall"] * delta
			l["x"] += l["drift"] * delta
			l["spin"] += l["spin_speed"] * delta
		i -= 1

	var avg_life := (LEAF_LIFE.x + LEAF_LIFE.y) * 0.5
	_leaf_accum += delta * LEAF_COUNT / avg_life
	while _leaf_accum >= 1.0:
		_leaf_accum -= 1.0
		var total := 0.0
		for source in LEAF_SOURCES:
			total += source["weight"]
		var pick := _rng.randf() * total
		var rect: Rect2 = LEAF_SOURCES[0]["rect"]
		for source in LEAF_SOURCES:
			pick -= source["weight"]
			if pick <= 0.0:
				rect = source["rect"]
				break
		var pos := _image_to_local(rect.position + Vector2(_rng.randf(), _rng.randf()) * rect.size)
		_leaves.append({
			"x": pos.x,
			"y": pos.y,
			"size": _rng.randf_range(6.0, 10.0) * s,
			"fall": _rng.randf_range(22.0, 45.0) * s,
			"drift": _rng.randf_range(-12.0, 4.0) * s,
			"sway": _rng.randf_range(10.0, 26.0) * s,
			"freq": _rng.randf_range(0.8, 1.7),
			"phase": _rng.randf() * TAU,
			"spin": _rng.randf() * TAU,
			"spin_speed": _rng.randf_range(1.5, 4.0) * (1.0 if _rng.randf() < 0.5 else -1.0),
			"color": LEAF_COLORS[_rng.randi() % LEAF_COLORS.size()],
			"age": 0.0,
			"life": _rng.randf_range(LEAF_LIFE.x, LEAF_LIFE.y),
		})


func _update_motes(delta: float) -> void:
	var s := _image_scale() / 0.7656
	var i := _motes.size() - 1
	while i >= 0:
		var m: Dictionary = _motes[i]
		m["age"] += delta
		if m["age"] >= m["life"]:
			_motes.remove_at(i)
		else:
			m["y"] -= m["rise"] * delta
		i -= 1

	var avg_life := (MOTE_LIFE.x + MOTE_LIFE.y) * 0.5
	_mote_accum += delta * MOTE_COUNT / avg_life
	while _mote_accum >= 1.0:
		_mote_accum -= 1.0
		var pos := _image_to_local(MOTE_SOURCE.position + Vector2(_rng.randf(), _rng.randf()) * MOTE_SOURCE.size)
		_motes.append({
			"x": pos.x,
			"y": pos.y,
			"r": _rng.randf_range(2.5, 4.5) * s,
			"rise": _rng.randf_range(4.0, 12.0) * s,
			"wander": _rng.randf_range(6.0, 16.0) * s,
			"freq": _rng.randf_range(0.4, 1.0),
			"phase": _rng.randf() * TAU,
			"blink": _rng.randf_range(1.5, 3.5),
			"gold": _rng.randf() < 0.35,
			"age": 0.0,
			"life": _rng.randf_range(MOTE_LIFE.x, MOTE_LIFE.y),
		})


func _draw_elderwild_particles() -> void:
	# Breath puffs: soft grey clouds swelling as they fade.
	for p in _puffs:
		var age: float = p["age"]
		if age <= 0.0:
			continue
		var k: float = age / p["life"]
		var r: float = p["r"] * (1.0 + 2.2 * k)
		var a: float = 0.75 * smoothstep(0.0, 0.15, k) * (1.0 - smoothstep(0.3, 1.0, k))
		_particle_layer.draw_texture_rect(_puff_tex, Rect2(p["pos"] - Vector2.ONE * r, Vector2.ONE * r * 2.0), false, Color(0.82, 0.84, 0.86, a))

	# Spirit motes: blinking green (now and then gold) sparks.
	for m in _motes:
		var age: float = m["age"]
		var life: float = m["life"]
		var fade: float = smoothstep(0.0, 0.8, age) * (1.0 - smoothstep(life - 1.0, life, age))
		var blink: float = 0.55 + 0.45 * sin(age * m["blink"] + m["phase"])
		var x: float = m["x"] + sin(age * m["freq"] + m["phase"]) * m["wander"]
		var col: Color = Color(1.0, 0.85, 0.45) if m["gold"] else Color(0.6, 1.0, 0.55)
		var r: float = m["r"]
		var mote_rect := Rect2(Vector2(x, m["y"]) - Vector2.ONE * r * 2.5, Vector2.ONE * r * 5.0)
		_particle_layer.draw_texture_rect(_mote_tex, mote_rect, false, Color(col, 0.9 * fade * blink))
		# A bright core so it reads as a spark, not just a smudge.
		_particle_layer.draw_texture_rect(_mote_tex, mote_rect.grow(-r * 1.6), false, Color(1, 1, 1, 0.7 * fade * blink))

	# Leaves: a pointed oval, squashed by cos(spin) so it seems to tumble.
	for l in _leaves:
		var age: float = l["age"]
		var life: float = l["life"]
		var a: float = smoothstep(0.0, 0.6, age) * (1.0 - smoothstep(life - 1.2, life, age))
		var x: float = l["x"] + sin(age * l["freq"] + l["phase"]) * l["sway"]
		var size: float = l["size"]
		var spin: float = l["spin"]
		_particle_layer.draw_set_transform(Vector2(x, l["y"]), spin * 0.35 + sin(age * l["freq"] + l["phase"]) * 0.6, Vector2(1.0, maxf(absf(cos(spin)), 0.15)))
		var pts := PackedVector2Array([
			Vector2(-size, 0.0), Vector2(-size * 0.4, -size * 0.45), Vector2(size * 0.4, -size * 0.4),
			Vector2(size, 0.0), Vector2(size * 0.4, size * 0.4), Vector2(-size * 0.4, size * 0.45),
		])
		var col: Color = l["color"]
		_particle_layer.draw_colored_polygon(pts, Color(col, a * 0.9))
		_particle_layer.draw_line(Vector2(-size, 0.0), Vector2(size, 0.0), Color(col.darkened(0.4), a * 0.8), 1.0)
	_particle_layer.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# --- Kingdom of Morvain ---------------------------------------------

func _build_morvain() -> void:
	var fx: Control = MORVAIN_FX.new()
	add_child(fx)
	fx.build(self, _background)
	_zone = "morvain"
