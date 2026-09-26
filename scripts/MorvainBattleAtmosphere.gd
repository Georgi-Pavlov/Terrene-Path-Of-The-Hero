extends Control
# ------------------------------------------------------------------
# MorvainBattleAtmosphere
# The Kingdom of Morvain's battle-area effects. BattleAtmosphere creates
# one of these (as its own child, so it sits over the Background and
# under the hero/creeps) and calls build(). Purely visual: never takes
# input, never touches game state.
#
#   - the hooded ghosts in the mist sway, their eyes glowing, flickering
#     and now and then blinking out
#   - the giant clawed hands slowly flex, fingers curling in and out
#   - fog rolling through the valley behind the bridge, and a low mist
#     creeping along the bridge deck
#
# Positions are fractions (0..1) of the battle-area image.
# ------------------------------------------------------------------

const BG_SHADER := preload("res://shaders/morvain_battle_background.gdshader")
const FOG_SHADER := preload("res://shaders/fog_drift.gdshader")

# The hooded ghosts: the rect each one fills (UV x0, y0, x1, y1), and its eyes.
const FIGURES := [
	{"rect": Vector4(0.036, 0.011, 0.144, 0.213), "eyes": [Vector2(0.1142, 0.0542), Vector2(0.1238, 0.0542)]},
	{"rect": Vector4(0.215, 0.223, 0.311, 0.446), "eyes": [Vector2(0.2614, 0.2625), Vector2(0.2721, 0.2625)]},
	{"rect": Vector4(0.179, 0.351, 0.263, 0.531), "eyes": [Vector2(0.2219, 0.3985), Vector2(0.2297, 0.4006)]},
	{"rect": Vector4(0.861, 0.276, 0.951, 0.468), "eyes": [Vector2(0.8858, 0.3177), Vector2(0.8953, 0.3177)]},
	{"rect": Vector4(0.718, 0.404, 0.801, 0.542), "eyes": [Vector2(0.7356, 0.4570), Vector2(0.7446, 0.4570)]},
]
const EYE_COLOR := Color(0.55, 1.0, 0.95)

# The clawed hands: the rect each one fills, and the wrist it flexes from.
const HANDS := [
	{"rect": Vector4(0.138, 0.074, 0.227, 0.234), "wrist": Vector2(0.1525, 0.1116)},
	{"rect": Vector4(0.281, 0.319, 0.356, 0.425), "wrist": Vector2(0.2901, 0.3666)},
	{"rect": Vector4(0.819, 0.361, 0.894, 0.510), "wrist": Vector2(0.8762, 0.3879)},
]

# Fog (image UV rects): the valley behind the bridge, and along the deck.
const VALLEY_FOG_RECT := Rect2(0.2, 0.28, 0.62, 0.34)
const DECK_MIST_RECT := Rect2(0.0, 0.53, 1.0, 0.14)

var _atm: Control
var _background: TextureRect
var _rng := RandomNumberGenerator.new()
var _time := 0.0
var _eyes: Array[Dictionary] = []


## `atm` is the owning BattleAtmosphere - its image mapping helpers are
## reused so positions line up with the Background exactly.
func build(atm: Control, background: TextureRect) -> void:
	_atm = atm
	_background = background
	_rng.randomize()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var tex_size := _background.texture.get_size()

	# Swaying ghosts and flexing hands, on the art itself.
	var mat := ShaderMaterial.new()
	mat.shader = BG_SHADER
	mat.set_shader_parameter("aspect", tex_size.x / tex_size.y)
	var figure_rects := PackedVector4Array()
	for figure in FIGURES:
		figure_rects.append(figure["rect"])
	mat.set_shader_parameter("figure_rect", figure_rects)
	var hand_rects := PackedVector4Array()
	var wrists := PackedVector2Array()
	for hand in HANDS:
		hand_rects.append(hand["rect"])
		wrists.append(hand["wrist"])
	mat.set_shader_parameter("hand_rect", hand_rects)
	mat.set_shader_parameter("hand_wrist", wrists)
	_background.material = mat

	# Fog through the valley, then the low mist along the deck.
	_add_fog(VALLEY_FOG_RECT, {
		"density": 0.32, "speed": 0.014, "scale": 2.4,
		"band_center": 0.6, "band_height": 0.55,
		"fog_color": Color(0.72, 0.82, 0.84),
		"edge_fade": Vector4(0.25, 0.3, 0.25, 0.3),
	})
	_add_fog(DECK_MIST_RECT, {
		"density": 0.34, "speed": 0.03, "scale": 3.5,
		"band_center": 0.62, "band_height": 0.5,
		"fog_color": Color(0.6, 0.88, 0.86),
		"edge_fade": Vector4(0.03, 0.4, 0.03, 0.25),
	})

	# The ghosts' eyes, over the fog so they burn through it.
	var s: float = _atm._image_scale()
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	g.colors = PackedColorArray([Color(0.85, 1.0, 1.0, 1.0), Color(EYE_COLOR, 0.5), Color(EYE_COLOR, 0.0)])
	var eye_tex := GradientTexture2D.new()
	eye_tex.gradient = g
	eye_tex.fill = GradientTexture2D.FILL_RADIAL
	eye_tex.fill_from = Vector2(0.5, 0.5)
	eye_tex.fill_to = Vector2(1.0, 0.5)
	eye_tex.width = 64
	eye_tex.height = 64
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_eyes.clear()
	for figure in FIGURES:
		var nodes: Array[TextureRect] = []
		for eye_uv in figure["eyes"]:
			var r := TextureRect.new()
			r.texture = eye_tex
			r.material = add
			r.mouse_filter = Control.MOUSE_FILTER_IGNORE
			r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			r.size = Vector2.ONE * 18.0 * s
			r.position = _atm._image_to_local(eye_uv) - r.size * 0.5
			add_child(r)
			nodes.append(r)
		_eyes.append({
			"nodes": nodes,
			"phase": _rng.randf() * TAU,
			"speed": _rng.randf_range(0.35, 0.7),
			"blink_in": _rng.randf_range(2.0, 9.0),
			"blink_t": -1.0,
		})

	set_process(true)


func _add_fog(rect_uv: Rect2, params: Dictionary) -> void:
	var a: Vector2 = _atm._image_to_local(rect_uv.position)
	var b: Vector2 = _atm._image_to_local(rect_uv.end)
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


## Eyes slowly brighten and dim, flicker a little, and every so often
## blink out for a moment.
func _process(delta: float) -> void:
	_time += delta
	for e in _eyes:
		e["blink_in"] -= delta
		if e["blink_t"] < 0.0 and e["blink_in"] <= 0.0:
			e["blink_t"] = 0.0
			e["blink_in"] = _rng.randf_range(4.0, 11.0)
		var open := 1.0
		if e["blink_t"] >= 0.0:
			e["blink_t"] += delta
			var p: float = e["blink_t"] / 0.3
			if p >= 1.0:
				e["blink_t"] = -1.0
			else:
				open = 1.0 - sin(p * PI)
		var bright: float = (0.4 + 0.5 * (0.5 + 0.5 * sin(_time * e["speed"] + e["phase"]))) \
				* (0.9 + 0.1 * sin(_time * 17.0 + e["phase"])) * open
		for eye: TextureRect in e["nodes"]:
			eye.modulate = Color(bright, bright, bright, 1.0)
