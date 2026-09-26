extends Control

## Which scene to load once the bar finishes filling. Set this in the
## Inspector per-instance if this loading screen is reused before
## different destinations (e.g. Login vs. Map).
@export_file("*.tscn") var next_scene_path: String = "res://scenes/MainMenu.tscn"

## How long the bar takes to fill, in seconds. The game itself is
## ready almost instantly - this is purely a deliberate, fixed-length
## loading experience (branding/polish) rather than a reflection of
## real load time.
@export var loading_duration: float = 2.5

## Where the camera zooms to once loading finishes: the big eye in the
## sky of loading_screen.jpg, as a fraction (0..1) of the image.
const EYE_UV := Vector2(0.7297, 0.2200)
const ZOOM_SCALE := 4.0
const ZOOM_TIME := 3.0
const FADE_OUT_TIME := 0.8

## "Waking eyes": every eye in the sky starts dimmed and opens once the
## bar passes its threshold, the big one last. uv = position in the
## image, size = eye height as a fraction of the image height.
const WAKING_EYES := [
	{"uv": Vector2(0.5658, 0.1116), "size": 0.035, "at": 25.0},
	{"uv": Vector2(0.8290, 0.1562), "size": 0.030, "at": 50.0},
	{"uv": Vector2(0.6340, 0.1913), "size": 0.030, "at": 75.0},
	{"uv": EYE_UV, "size": 0.090, "at": 100.0},
]

@onready var progress_bar: ProgressBar = $ProgressBar
@onready var status_label: Label = $StatusLabel
@onready var background: TextureRect = $Background

var _eyes: Array[Dictionary] = []
var _bar_spark: TextureRect


func _ready() -> void:
	progress_bar.min_value = 0.0
	progress_bar.max_value = 100.0
	progress_bar.value = 0.0
	_setup_waking_eyes()
	_setup_bar_spark()

	var tween := create_tween()
	tween.tween_method(_on_progress_updated, 0.0, 100.0, loading_duration)
	tween.finished.connect(_on_loading_finished)


func _on_progress_updated(value: float) -> void:
	progress_bar.value = value
	status_label.text = "Loading... %d%%" % int(value)
	for eye in _eyes:
		if not eye.awake and value >= eye.at:
			eye.awake = true
			_wake_eye(eye)
	# Keep the glowing spark on the leading edge of the fill.
	_bar_spark.visible = value > 0.0
	_bar_spark.position = Vector2(progress_bar.size.x * value / 100.0, progress_bar.size.y * 0.5) - _bar_spark.size * 0.5


# --- waking eyes / bar spark (visual only) ---------------------------

func _setup_waking_eyes() -> void:
	var img_h := background.texture.get_size().y * _image_scale()
	for data in WAKING_EYES:
		var centre := _image_to_local(data.uv)
		var eye_px: float = data.size * img_h
		# A soft dark patch closes the eye until it wakes.
		var shade := _radial_rect(_soft_texture(Color(0.02, 0.01, 0.01, 0.92), Color(0.02, 0.01, 0.01, 0.0), 0.35), centre, eye_px * 1.9)
		background.add_child(shade)
		var glow := _radial_rect(_soft_texture(Color(0.60, 0.22, 0.07, 0.9), Color(0.35, 0.05, 0.01, 0.0), 0.2), centre, eye_px * 2.2)
		glow.material = _additive()
		glow.modulate.a = 0.0
		background.add_child(glow)
		_eyes.append({"at": data.at, "awake": false, "shade": shade, "glow": glow})


func _wake_eye(eye: Dictionary) -> void:
	var shade: TextureRect = eye.shade
	var glow: TextureRect = eye.glow
	create_tween().tween_property(shade, "modulate:a", 0.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	var tw := create_tween()
	tw.tween_property(glow, "modulate:a", 1.0, 0.12)
	tw.tween_property(glow, "modulate:a", 0.45, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# Then smoulder gently while the bar keeps filling.
	tw.tween_callback(func():
		var flicker := create_tween().set_loops()
		flicker.tween_property(glow, "modulate:a", 0.7, randf_range(0.5, 0.9)).set_trans(Tween.TRANS_SINE)
		flicker.tween_property(glow, "modulate:a", 0.4, randf_range(0.5, 0.9)).set_trans(Tween.TRANS_SINE))


func _setup_bar_spark() -> void:
	var h := progress_bar.size.y
	_bar_spark = _radial_rect(_soft_texture(Color(1.0, 0.55, 0.25, 1.0), Color(0.8, 0.12, 0.03, 0.0), 0.15), Vector2.ZERO, max(h, 8.0) * 4.0)
	_bar_spark.material = _additive()
	_bar_spark.visible = false
	progress_bar.add_child(_bar_spark)


func _radial_rect(tex: Texture2D, centre: Vector2, diameter: float) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.size = Vector2.ONE * diameter
	r.position = centre - r.size * 0.5
	return r


func _soft_texture(inner: Color, outer: Color, core: float) -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, core, 1.0])
	g.colors = PackedColorArray([inner, inner.lerp(outer, 0.4), outer])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	return t


func _additive() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m


func _on_loading_finished() -> void:
	if next_scene_path == "":
		return
	await _play_outro()
	get_tree().change_scene_to_file(next_scene_path)


## Purely visual: the bar fades away, the camera is pulled into the eye
## (which flares up as it gets close) and the screen goes black. The
## next scene's MenuAtmosphere fades in from black, so the two meet.
func _play_outro() -> void:
	var eye := _image_to_local(EYE_UV)
	background.pivot_offset = eye

	var glow := TextureRect.new()
	glow.texture = _eye_glow_texture()
	glow.material = CanvasItemMaterial.new()
	glow.material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.size = Vector2.ONE * background.size.y * 0.35
	glow.position = eye - glow.size * 0.5
	glow.modulate.a = 0.0
	background.add_child(glow)

	var black := ColorRect.new()
	black.color = Color(0, 0, 0, 0)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(black)

	var tw := create_tween().set_parallel()
	tw.tween_property(progress_bar, "modulate:a", 0.0, 0.3)
	tw.tween_property(status_label, "modulate:a", 0.0, 0.3)
	# Slow start, then steadily pulled in faster. The pivot stays put
	# on screen while scaling, so the background also slides to bring the
	# eye to the centre - in step with the zoom, so the enlarged image
	# always still covers the whole screen.
	var start_pos := background.position
	var pan := background.size * 0.5 - eye
	var set_zoom := func(s: float) -> void:
		background.scale = Vector2.ONE * s
		background.position = start_pos + pan * (s - 1.0) / (ZOOM_SCALE - 1.0)
	tw.tween_method(set_zoom, 1.0, ZOOM_SCALE, ZOOM_TIME) \
		.set_delay(0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(glow, "modulate:a", 1.0, ZOOM_TIME * 0.6) \
		.set_delay(0.15 + ZOOM_TIME * 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_property(black, "color:a", 1.0, FADE_OUT_TIME) \
		.set_delay(0.15 + ZOOM_TIME - FADE_OUT_TIME * 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tw.finished


## Maps a point in the background image (0..1) to the Background node's
## local coordinates, matching its "keep aspect covered" stretch mode.
func _image_to_local(uv: Vector2) -> Vector2:
	var drawn := background.texture.get_size() * _image_scale()
	return (background.size - drawn) * 0.5 + uv * drawn


func _image_scale() -> float:
	var tex_size := background.texture.get_size()
	var rect_size := background.size
	return max(rect_size.x / tex_size.x, rect_size.y / tex_size.y)


func _eye_glow_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	g.colors = PackedColorArray([
		Color(0.55, 0.22, 0.08, 0.8),
		Color(0.45, 0.10, 0.03, 0.45),
		Color(0.30, 0.04, 0.01, 0.0),
	])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 128
	t.height = 128
	return t
