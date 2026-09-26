extends Control
# ------------------------------------------------------------------
# MenuAtmosphere
# Purely visual layer shared by MainMenu and PostLogin. Drop it into a
# scene right after the Background node (so the buttons draw on top).
# It never takes input (mouse_filter = IGNORE on everything) and never
# touches game state - it only animates what's already on screen:
#   - a pulsing glow over the eclipse in the art
#   - drifting fog along the bottom
#   - embers rising from the candle-lit ledge, ash falling from the sky
#   - fade in from black, buttons appearing one after another
#   - the settings gear slowly turning
# Positions of art features are given as fractions (0..1) of the
# background image, so they stay on target whatever the screen size.
# ------------------------------------------------------------------

@export var background_path: NodePath = ^"../Background"
@export var buttons_path: NodePath = ^"../ButtonsContainer"
@export var gear_path: NodePath = ^"../SettingsButton"

const ECLIPSE_UV := Vector2(0.749, 0.187)
const ECLIPSE_RADIUS_UV := 0.072          # fraction of image width
const EMBER_AREA_UV := Rect2(0.0, 0.70, 0.46, 0.22)

const ECLIPSE_PULSE_TIME := 3.0
const GEAR_TURN_TIME := 40.0
const FADE_IN_TIME := 1.2
const BUTTON_STAGGER := 0.12
const BUTTON_RISE := 14.0

const FOG_SHADER := preload("res://shaders/menu_fog.gdshader")

var _background: TextureRect

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background = get_node_or_null(background_path) as TextureRect

	_add_fade_from_black()
	_add_fog()
	_add_ash()
	# Layout sizes aren't final until the first frame is processed.
	await get_tree().process_frame
	if _background:
		_add_eclipse_glow()
	_add_embers()
	_animate_buttons()
	_spin_gear()

# --- helpers --------------------------------------------------------

## Maps a point in the background image (0..1) to the Background node's
## local coordinates, matching its "keep aspect covered" stretch mode.
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

func _soft_dot(size: int, inner: Color, outer: Color) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, inner)
	g.set_color(1, outer)
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

# --- effects --------------------------------------------------------

func _add_fade_from_black() -> void:
	# On its own CanvasLayer so it covers everything, popups included.
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(black)
	var tw := create_tween()
	tw.tween_property(black, "color:a", 0.0, FADE_IN_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(layer.queue_free)

func _add_fog() -> void:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.006
	noise.fractal_octaves = 4
	var tex := NoiseTexture2D.new()
	tex.width = 512
	tex.height = 512
	tex.seamless = true
	tex.noise = noise
	var mat := ShaderMaterial.new()
	mat.shader = FOG_SHADER
	mat.set_shader_parameter("noise_tex", tex)
	var fog := ColorRect.new()
	fog.material = mat
	fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fog.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fog)

func _add_eclipse_glow() -> void:
	# Child of the background so it stays lined up with the art.
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.40, 0.52, 0.66, 1.0])
	g.colors = PackedColorArray([
		Color(1.0, 0.85, 0.55, 0.05),
		Color(1.0, 0.85, 0.55, 0.20),
		Color(1.0, 0.88, 0.62, 0.55),
		Color(1.0, 0.80, 0.50, 0.18),
		Color(1.0, 0.80, 0.50, 0.0),
	])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256

	var radius := ECLIPSE_RADIUS_UV * _background.texture.get_size().x * _image_scale()
	var glow := TextureRect.new()
	glow.texture = tex
	glow.material = _additive()
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.size = Vector2.ONE * radius * 2.0 / 0.52
	glow.position = _image_to_local(ECLIPSE_UV) - glow.size * 0.5
	glow.modulate.a = 0.35
	_background.add_child(glow)

	var tw := create_tween().set_loops()
	tw.tween_property(glow, "modulate:a", 1.0, ECLIPSE_PULSE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(glow, "modulate:a", 0.35, ECLIPSE_PULSE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _add_embers() -> void:
	var p := CPUParticles2D.new()
	p.texture = _soft_dot(16, Color(1, 1, 1, 1), Color(1, 1, 1, 0))
	p.material = _additive()
	p.amount = 60
	p.lifetime = 4.5
	p.preprocess = 4.5
	p.lifetime_randomness = 0.5
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	var area := Rect2(0, size.y * 0.7, size.x * 0.46, size.y * 0.22)
	if _background:
		var a := _image_to_local(EMBER_AREA_UV.position)
		var b := _image_to_local(EMBER_AREA_UV.end)
		area = Rect2(a, b - a)
	p.position = area.get_center()
	p.emission_rect_extents = area.size * 0.5
	p.direction = Vector2(0.25, -1)
	p.spread = 25.0
	p.gravity = Vector2(4, -18)
	p.initial_velocity_min = 12.0
	p.initial_velocity_max = 40.0
	p.damping_min = 2.0
	p.damping_max = 6.0
	p.scale_amount_min = 0.35
	p.scale_amount_max = 0.85
	# Alpha bumps along the lifetime make each ember flicker as it rises.
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.1, 0.3, 0.45, 0.7, 1.0])
	ramp.colors = PackedColorArray([
		Color(1.0, 0.75, 0.35, 0.0),
		Color(1.0, 0.75, 0.35, 1.0),
		Color(1.0, 0.50, 0.15, 0.55),
		Color(1.0, 0.60, 0.20, 0.95),
		Color(0.9, 0.25, 0.05, 0.5),
		Color(0.6, 0.10, 0.02, 0.0),
	])
	p.color_ramp = ramp
	add_child(p)

func _add_ash() -> void:
	var p := CPUParticles2D.new()
	p.texture = _soft_dot(12, Color(1, 1, 1, 1), Color(1, 1, 1, 0))
	p.amount = 40
	p.lifetime = 14.0
	p.preprocess = 14.0
	p.lifetime_randomness = 0.3
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	# Spawn in a wide band above the screen; sideways drift covers the rest.
	var w := get_viewport_rect().size
	p.position = Vector2(w.x * 0.4, -20)
	p.emission_rect_extents = Vector2(w.x * 0.65, 10)
	p.direction = Vector2(0.35, 1)
	p.spread = 20.0
	p.gravity = Vector2(3, 4)
	p.initial_velocity_min = 18.0
	p.initial_velocity_max = 40.0
	p.scale_amount_min = 0.25
	p.scale_amount_max = 0.6
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.15, 0.8, 1.0])
	ramp.colors = PackedColorArray([
		Color(0.78, 0.78, 0.82, 0.0),
		Color(0.78, 0.78, 0.82, 0.5),
		Color(0.70, 0.70, 0.74, 0.4),
		Color(0.70, 0.70, 0.74, 0.0),
	])
	p.color_ramp = ramp
	add_child(p)

func _animate_buttons() -> void:
	var box := get_node_or_null(buttons_path) as Control
	if box == null:
		return
	var i := 0
	for child in box.get_children():
		var c := child as Control
		if c == null or not c.visible:
			continue
		var target := c.position
		c.modulate.a = 0.0
		c.position.y += BUTTON_RISE
		var delay := FADE_IN_TIME * 0.5 + i * BUTTON_STAGGER
		var tw := create_tween().set_parallel()
		tw.tween_property(c, "modulate:a", 1.0, 0.5).set_delay(delay)
		tw.tween_property(c, "position:y", target.y, 0.6).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		i += 1

func _spin_gear() -> void:
	var gear := get_node_or_null(gear_path) as Control
	if gear == null:
		return
	gear.pivot_offset = gear.size * 0.5
	var tw := create_tween().set_loops()
	tw.tween_property(gear, "rotation", TAU, GEAR_TURN_TIME).from(0.0)
