extends Control
# ------------------------------------------------------------------
# MapFX
# Purely visual ambience over the Map background (sits between the
# Background and the zone buttons, takes no input):
#   - the crimson whirlpool next to the compass slowly turns
#   - the three black suns breathe with a soft corona
#   - mist drifts across the map, kept clear of the zone name plates
#   - embers rise from The Stonewake's volcano
#   - snow and icy glints over the frozen peaks
#   - gusts of sand blow across the two deserts
# (Lightning around the compass tentacles lives in CompassFX, so the
# bolts can strike over the tentacles.)
# Positions are for the 1280x720 viewport (the map background is
# stretched to fill the screen) and scaled from there.
# ------------------------------------------------------------------

const DESIGN_SIZE := Vector2(1280, 720)
const VORTEX := {"pos": Vector2(257, 204), "radius": 52.0}
# pos, disc radius, corona colour, pulse period (s)
const SUNS := [
	{"pos": Vector2(1162, 60), "radius": 24.0, "color": Color(0.85, 0.75, 0.95), "period": 7.0},
	{"pos": Vector2(1210, 435), "radius": 15.0, "color": Color(0.7, 0.35, 1.0), "period": 5.5},
	{"pos": Vector2(1208, 562), "radius": 18.0, "color": Color(1.0, 0.5, 0.25), "period": 6.3},
]
const VOLCANO := Rect2(392, 368, 36, 18)            # The Stonewake's crater
const ICE_AREA := Rect2(540, 0, 360, 200)           # The Veiled Reach, Frostspire, The Everfrost
const ICE_SHIMMER := [Vector2(655, 40), Vector2(655, 130)]  # the glowing crystal spires
# Sand blows in from each area's left edge and across it.
const DESERTS := [
	{"area": Rect2(15, 520, 230, 170), "amount": 34},  # The Sunscar
	{"area": Rect2(300, 470, 290, 130), "amount": 34},  # The Sandgrave / Qadaris
]

const FOG_SHADER := preload("res://shaders/menu_fog.gdshader")
const VORTEX_SHADER := preload("res://shaders/map_vortex.gdshader")

var _scale := Vector2.ONE
var _mist_mat: ShaderMaterial


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scale = get_viewport_rect().size / DESIGN_SIZE
	_add_vortex()
	for sun in SUNS:
		_add_sun_corona(sun)
	for desert in DESERTS:
		_add_wind(desert.area, desert.amount)
	_add_mist()
	_add_embers()
	_add_frost()


## Called by Map once the zone plates are placed: the mist is kept off
## these rects so the zone names stay readable.
func set_clear_rects(rects: Array) -> void:
	var w := 320
	var h := 180
	var img := Image.create(w, h, false, Image.FORMAT_L8)
	img.fill(Color.WHITE)
	var screen := get_viewport_rect().size
	var k := Vector2(w, h) / screen
	for r in rects:
		var rect: Rect2 = r
		var a := ((rect.position - Vector2(6, 6)) * k).floor()
		var b := ((rect.end + Vector2(6, 6)) * k).ceil()
		img.fill_rect(Rect2i(Vector2i(a), Vector2i(b - a)), Color.BLACK)
	# Downscale + linear filtering gives the cut-outs soft edges.
	img.resize(w / 2, h / 2, Image.INTERPOLATE_BILINEAR)
	_mist_mat.set_shader_parameter("clear_mask", ImageTexture.create_from_image(img))


# --- helpers -----------------------------------------------------------

func _to_screen(p: Vector2) -> Vector2:
	return p * _scale


func _additive() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m


func _radial(offsets: PackedFloat32Array, colors: PackedColorArray, size: int = 128) -> GradientTexture2D:
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


func _soft_dot() -> GradientTexture2D:
	return _radial(PackedFloat32Array([0.0, 1.0]), PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)]), 16)


func _ramp(offsets: Array, colors: Array) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offsets)
	g.colors = PackedColorArray(colors)
	return g


func _centred_rect(centre: Vector2, radius: float) -> Rect2:
	var r := radius * _scale.y
	return Rect2(_to_screen(centre) - Vector2(r, r), Vector2(r, r) * 2.0)


func _particles_in(area: Rect2) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.position = _to_screen(area.get_center())
	p.emission_rect_extents = area.size * _scale * 0.5
	return p


# --- whirlpool ---------------------------------------------------------

func _add_vortex() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = VORTEX_SHADER
	var rect := ColorRect.new()
	rect.material = mat
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var area := _centred_rect(VORTEX.pos, VORTEX.radius)
	rect.position = area.position
	rect.size = area.size
	add_child(rect)


# --- black suns --------------------------------------------------------

func _add_sun_corona(sun: Dictionary) -> void:
	var c: Color = sun.color
	# Ring of light hugging the dark disc (disc edge at ~40% of the rect).
	var tex := _radial(
		PackedFloat32Array([0.0, 0.34, 0.42, 0.55, 1.0]),
		PackedColorArray([Color(c, 0.0), Color(c, 0.0), Color(c, 0.85), Color(c, 0.3), Color(c, 0.0)]))
	var corona := TextureRect.new()
	corona.texture = tex
	corona.material = _additive()
	corona.mouse_filter = Control.MOUSE_FILTER_IGNORE
	corona.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var area := _centred_rect(sun.pos, sun.radius / 0.42)
	corona.position = area.position
	corona.size = area.size
	corona.pivot_offset = area.size / 2.0
	corona.modulate.a = 0.25
	add_child(corona)

	var half: float = sun.period / 2.0
	var tw := create_tween().set_loops().set_parallel()
	tw.tween_property(corona, "modulate:a", 0.75, half).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(corona, "scale", Vector2.ONE * 1.08, half).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.chain().tween_property(corona, "modulate:a", 0.25, half).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(corona, "scale", Vector2.ONE, half).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# --- mist --------------------------------------------------------------

func _add_mist() -> void:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.006
	noise.fractal_octaves = 4
	var tex := NoiseTexture2D.new()
	tex.width = 512
	tex.height = 512
	tex.seamless = true
	tex.noise = noise
	_mist_mat = ShaderMaterial.new()
	_mist_mat.shader = FOG_SHADER
	_mist_mat.set_shader_parameter("noise_tex", tex)
	_mist_mat.set_shader_parameter("density", 0.55)
	_mist_mat.set_shader_parameter("mask_top", -1.0)   # whole map (no bottom-only mask)
	_mist_mat.set_shader_parameter("mask_full", 0.0)
	_mist_mat.set_shader_parameter("fog_color", Color(0.78, 0.8, 0.88))
	_mist_mat.set_shader_parameter("speed_a", Vector2(0.008, 0.001))
	_mist_mat.set_shader_parameter("speed_b", Vector2(-0.005, 0.0))
	var fog := ColorRect.new()
	fog.material = _mist_mat
	fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fog.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fog)


# --- embers over The Stonewake -----------------------------------------

func _add_embers() -> void:
	var p := _particles_in(VOLCANO)
	p.texture = _soft_dot()
	p.material = _additive()
	p.amount = 40
	p.lifetime = 3.0
	p.preprocess = 3.0
	p.lifetime_randomness = 0.5
	p.direction = Vector2(0.1, -1)
	p.spread = 30.0
	p.gravity = Vector2(6, -22) * _scale.y
	p.initial_velocity_min = 14.0 * _scale.y
	p.initial_velocity_max = 38.0 * _scale.y
	p.damping_min = 2.0
	p.damping_max = 5.0
	p.scale_amount_min = 0.3 * _scale.y
	p.scale_amount_max = 0.7 * _scale.y
	p.color_ramp = _ramp([0.0, 0.1, 0.35, 0.5, 0.75, 1.0], [
		Color(1.0, 0.75, 0.35, 0.0), Color(1.0, 0.75, 0.35, 1.0), Color(1.0, 0.45, 0.12, 0.6),
		Color(1.0, 0.6, 0.2, 0.95), Color(0.9, 0.25, 0.05, 0.5), Color(0.6, 0.1, 0.02, 0.0)])
	add_child(p)


# --- frost over the ice peaks ------------------------------------------

func _add_frost() -> void:
	# cold shimmer around the crystal spires
	for pos in ICE_SHIMMER:
		var glow := TextureRect.new()
		glow.texture = _radial(PackedFloat32Array([0.0, 1.0]), PackedColorArray([Color(0.6, 0.85, 1.0, 0.5), Color(0.5, 0.8, 1.0, 0.0)]))
		glow.material = _additive()
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		var area := _centred_rect(pos, 70.0)
		glow.position = area.position
		glow.size = area.size
		glow.modulate.a = 0.3
		add_child(glow)
		var tw := create_tween().set_loops()
		tw.tween_property(glow, "modulate:a", 0.8, randf_range(2.2, 3.0)).set_trans(Tween.TRANS_SINE)
		tw.tween_property(glow, "modulate:a", 0.3, randf_range(2.2, 3.0)).set_trans(Tween.TRANS_SINE)

	# falling snow
	var snow := _particles_in(ICE_AREA)
	snow.texture = _soft_dot()
	snow.amount = 120
	snow.lifetime = 7.0
	snow.preprocess = 7.0
	snow.direction = Vector2(0.25, 1)
	snow.spread = 15.0
	snow.gravity = Vector2(2, 3) * _scale.y
	snow.initial_velocity_min = 6.0 * _scale.y
	snow.initial_velocity_max = 14.0 * _scale.y
	snow.scale_amount_min = 0.25 * _scale.y
	snow.scale_amount_max = 0.55 * _scale.y
	snow.color_ramp = _ramp([0.0, 0.15, 0.8, 1.0], [
		Color(0.95, 0.98, 1.0, 0.0), Color(0.95, 0.98, 1.0, 1.0), Color(0.9, 0.95, 1.0, 0.85), Color(0.9, 0.95, 1.0, 0.0)])
	add_child(snow)

	# icy glints twinkling on the peaks
	var glints := _particles_in(ICE_AREA.grow(-20))
	glints.texture = _sparkle_texture()
	glints.material = _additive()
	glints.amount = 12
	glints.lifetime = 1.4
	glints.preprocess = 1.4
	glints.lifetime_randomness = 0.4
	glints.gravity = Vector2.ZERO
	glints.initial_velocity_min = 0.0
	glints.initial_velocity_max = 0.0
	glints.angle_min = 0.0
	glints.angle_max = 45.0
	glints.scale_amount_min = 0.5 * _scale.y
	glints.scale_amount_max = 1.0 * _scale.y
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.0))
	grow.add_point(Vector2(0.4, 1.0))
	grow.add_point(Vector2(1.0, 0.0))
	glints.scale_amount_curve = grow
	glints.color = Color(0.8, 0.93, 1.0, 0.9)
	add_child(glints)


## Small four-pointed star for the ice glints.
func _sparkle_texture() -> ImageTexture:
	var n := 24
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := (n - 1) / 2.0
	for y in n:
		for x in n:
			var dx := absf(x - c) / c
			var dy := absf(y - c) / c
			var ray := maxf(clampf(1.0 - dx * 1.0 - dy * 9.0, 0, 1), clampf(1.0 - dy * 1.0 - dx * 9.0, 0, 1))
			var core := clampf(1.0 - sqrt(dx * dx + dy * dy) * 3.0, 0, 1)
			img.set_pixel(x, y, Color(1, 1, 1, clampf(ray + core, 0, 1)))
	return ImageTexture.create_from_image(img)


# --- wind over the deserts ---------------------------------------------

## A thin, soft wisp of blown sand: tapers towards both ends and fades
## out at the top and bottom, so it has no hard edges.
func _wisp_texture() -> ImageTexture:
	var w := 48
	var h := 8
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var v := (y - (h - 1) / 2.0) / (h / 2.0)
		for x in w:
			var u := float(x) / (w - 1)
			var along := sin(u * PI) * lerpf(0.6, 1.0, u)   # brighter head
			var thickness := lerpf(0.35, 1.0, sin(u * PI))
			var across := exp(-pow(v / thickness, 2.0) * 3.0)
			img.set_pixel(x, y, Color(1, 1, 1, clampf(along * across, 0, 1)))
	return ImageTexture.create_from_image(img)


func _add_wind(area: Rect2, amount: int) -> void:
	var streak := _wisp_texture()
	# enters along the area's left edge and blows across it
	var p := _particles_in(Rect2(area.position.x, area.position.y, 4, area.size.y))
	p.texture = streak
	p.amount = amount
	var speed := 95.0
	p.lifetime = area.size.x / speed
	p.preprocess = p.lifetime
	p.lifetime_randomness = 0.3
	p.direction = Vector2(1, -0.06)
	p.spread = 5.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = speed * 0.75 * _scale.x
	p.initial_velocity_max = speed * 1.25 * _scale.x
	p.scale_amount_min = 0.5 * _scale.y
	p.scale_amount_max = 1.0 * _scale.y
	p.color_ramp = _ramp([0.0, 0.2, 0.75, 1.0], [
		Color(1.0, 0.92, 0.75, 0.0), Color(1.0, 0.92, 0.75, 0.75), Color(1.0, 0.88, 0.68, 0.6), Color(1.0, 0.88, 0.68, 0.0)])
	add_child(p)

	# faint dust puffs drifting with the same wind
	var dust := _particles_in(Rect2(area.position.x, area.position.y, 4, area.size.y))
	dust.texture = _radial(PackedFloat32Array([0.0, 1.0]), PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)]), 64)
	dust.amount = 8
	dust.lifetime = area.size.x / (speed * 0.6)
	dust.preprocess = dust.lifetime
	dust.direction = Vector2(1, -0.04)
	dust.spread = 6.0
	dust.gravity = Vector2.ZERO
	dust.initial_velocity_min = speed * 0.5 * _scale.x
	dust.initial_velocity_max = speed * 0.7 * _scale.x
	dust.scale_amount_min = 0.7 * _scale.y
	dust.scale_amount_max = 1.3 * _scale.y
	dust.color_ramp = _ramp([0.0, 0.3, 0.7, 1.0], [
		Color(0.95, 0.8, 0.55, 0.0), Color(0.95, 0.8, 0.55, 0.22), Color(0.95, 0.8, 0.55, 0.16), Color(0.95, 0.8, 0.55, 0.0)])
	add_child(dust)
	# gusts: the wind rises and falls
	var tw := create_tween().set_loops()
	tw.tween_property(p, "speed_scale", 1.6, randf_range(1.8, 2.6)).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(dust, "speed_scale", 1.6, randf_range(1.8, 2.6)).set_trans(Tween.TRANS_SINE)
	tw.tween_property(p, "speed_scale", 0.7, randf_range(2.0, 3.0)).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(dust, "speed_scale", 0.7, randf_range(2.0, 3.0)).set_trans(Tween.TRANS_SINE)
