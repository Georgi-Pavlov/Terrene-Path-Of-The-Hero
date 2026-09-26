extends Control
# ------------------------------------------------------------------
# CompassFX
# Purely visual layer for the compass in the top-left of the Map: a
# breathing glow behind the rose, a slowly turning rune ring, and dark
# tentacles that coil around the dial and writhe. Hovering the Shop /
# World Status plaques makes the nearest tentacles stir and reach for
# them. Every few seconds lightning strikes down from the storm onto
# one of the tentacles, which jolt. Takes no input itself
# (mouse_filter = IGNORE everywhere).
# Coordinates are designed for the 1280x720 viewport and scaled from
# there; the map background is stretched to fill the screen.
# ------------------------------------------------------------------

@export var shop_button_path: NodePath = ^"../ShopButton"
@export var status_button_path: NodePath = ^"../WorldStatusButton"

const DESIGN_SIZE := Vector2(1280, 720)
const CENTRE := Vector2(128, 175)       # compass centre in map_bg.jpg, at 1280x720
const RING_RADIUS := 86.0
const POINTS := 40
const STRIKE_GAP := Vector2(2.5, 6.0)      # seconds between lightning strikes (min, max)
const STORM_GLOW := {"pos": Vector2(160, 110), "radius": 270.0}

# Each tentacle comes in from `r0` at angle `a0` (degrees, 0 = east,
# 90 = south) and coils `sweep` degrees around the dial down to `r1`.
# `reach` says which plaque it stirs for: -1 = Shop (north), 1 = World
# Status (south), 0 = neither.
const TENTACLES := [
	{"a0": -165.0, "sweep": 55.0, "r0": 165.0, "r1": 90.0, "width": 26.0, "speed": 0.9, "phase": 0.0, "reach": -1},
	{"a0": -10.0, "sweep": -55.0, "r0": 150.0, "r1": 92.0, "width": 21.0, "speed": 1.1, "phase": 1.7, "reach": -1},
	{"a0": 165.0, "sweep": -58.0, "r0": 170.0, "r1": 90.0, "width": 28.0, "speed": 0.8, "phase": 3.1, "reach": 1},
	{"a0": 15.0, "sweep": 52.0, "r0": 148.0, "r1": 93.0, "width": 20.0, "speed": 1.2, "phase": 4.4, "reach": 1},
]

var _k := 1.0                 # design px -> screen px
var _centre := Vector2.ZERO
var _time := 0.0
var _hover := 0.0             # -1 = Shop hovered, 1 = World Status, eased
var _hover_target := 0.0
var _stir := 0.0              # 0..1, eased while either plaque is hovered
var _bodies: Array[Line2D] = []
var _rims: Array[Line2D] = []
var _shadows: Array[Line2D] = []
var _suckers: Control
var _points: Array[PackedVector2Array] = []
var _runes: Control
var _glow: TextureRect
var _rune_angle := 0.0
var _jolt := 0.0              # 1 right after a strike, decays - tentacles lash
var _storm_glow: TextureRect
var _strike_timer: Timer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	await get_tree().process_frame
	var screen := get_viewport_rect().size
	_k = screen.y / DESIGN_SIZE.y
	_centre = CENTRE * Vector2(screen.x / DESIGN_SIZE.x, screen.y / DESIGN_SIZE.y)

	_build_glow()
	_build_runes()
	_build_tentacles()
	_build_storm()
	_hook_button(get_node_or_null(shop_button_path), -1.0)
	_hook_button(get_node_or_null(status_button_path), 1.0)


func _process(delta: float) -> void:
	if _bodies.is_empty():
		return
	_hover = move_toward(_hover, _hover_target, delta * 3.0)
	_stir = move_toward(_stir, 1.0 if _hover_target != 0.0 else 0.0, delta * 2.5)
	_jolt = move_toward(_jolt, 0.0, delta * 1.8)
	_time += delta * (1.0 + _stir * 1.6 + _jolt * 4.0)

	for i in TENTACLES.size():
		var pts := _tentacle_points(TENTACLES[i])
		_points[i] = pts
		_bodies[i].points = pts
		_rims[i].points = _offset_towards_centre(pts, TENTACLES[i].width * _k * 0.3)
		_shadows[i].points = _offset_towards_centre(pts, -TENTACLES[i].width * _k * 0.2)
	_suckers.queue_redraw()

	_rune_angle += delta * (0.05 + _stir * 0.12)
	_runes.queue_redraw()
	var pulse := 0.5 + 0.5 * sin(_time * 1.3)
	_glow.modulate.a = 0.35 + 0.25 * pulse + 0.3 * _stir


# --- tentacles -------------------------------------------------------

func _tentacle_points(t: Dictionary) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var phase: float = t.phase + _time * t.speed
	# Tentacles that belong to the hovered plaque reach further round
	# towards it (north is -90 deg, south is 90 deg).
	var mine: float = clamp(_hover * t.reach, 0.0, 1.0)
	var target_angle: float = -90.0 if t.reach < 0 else 90.0
	var end_angle: float = t.a0 + t.sweep
	var reach_extra: float = (target_angle - end_angle) * 0.55 * mine
	for j in POINTS:
		var u := float(j) / (POINTS - 1)
		var ease_u := u * u * (3.0 - 2.0 * u)
		# writhing grows towards the tip; the radial undulation makes the
		# tentacle weave in and out across the dial's ring
		var wave := sin(phase * 1.6 + u * 5.0) * 8.0 * u + sin(phase * 0.9 + u * 2.3) * 4.0
		var ang: float = t.a0 + (t.sweep + reach_extra) * ease_u + wave * (1.0 + mine)
		var rad: float = lerp(t.r0, t.r1, ease_u) 			+ sin(phase * 1.3 + u * 7.0) * 9.0 * u 			+ sin(phase * 0.7 + u * 3.0) * 5.0
		# the last stretch curls into a hook
		if u > 0.7:
			var c := (u - 0.7) / 0.3
			ang += sign(t.sweep) * c * c * 95.0
			rad -= c * c * 24.0
		pts.append(_centre + Vector2.from_angle(deg_to_rad(ang)) * rad * _k)
	return pts


func _offset_towards_centre(pts: PackedVector2Array, amount: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(p + (_centre - p).normalized() * amount)
	return out


func _build_tentacles() -> void:
	var taper := Curve.new()
	taper.add_point(Vector2(0.0, 1.0))
	taper.add_point(Vector2(0.55, 0.45))
	taper.add_point(Vector2(1.0, 0.04))

	var body_grad := Gradient.new()
	body_grad.set_color(0, Color(0.05, 0.035, 0.06, 0.0))    # fades in from "behind" the map
	body_grad.set_color(1, Color(0.16, 0.09, 0.16, 1.0))
	body_grad.add_point(0.07, Color(0.06, 0.04, 0.07, 1.0))

	var rim_grad := Gradient.new()
	rim_grad.set_color(0, Color(0.5, 0.28, 0.7, 0.0))
	rim_grad.set_color(1, Color(0.62, 0.38, 0.8, 0.5))
	rim_grad.add_point(0.15, Color(0.45, 0.26, 0.62, 0.22))

	var shadow_grad := Gradient.new()
	shadow_grad.set_color(0, Color(0, 0, 0, 0.0))
	shadow_grad.set_color(1, Color(0, 0, 0, 0.45))
	shadow_grad.add_point(0.08, Color(0, 0, 0, 0.5))

	var rim_mat := CanvasItemMaterial.new()
	rim_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	for t in TENTACLES:
		_points.append(PackedVector2Array())
		var shadow := Line2D.new()
		shadow.width = t.width * _k * 1.25
		shadow.width_curve = taper
		shadow.gradient = shadow_grad
		shadow.joint_mode = Line2D.LINE_JOINT_ROUND
		shadow.antialiased = true
		add_child(shadow)
		_shadows.append(shadow)

		var body := Line2D.new()
		body.width = t.width * _k
		body.width_curve = taper
		body.gradient = body_grad
		body.joint_mode = Line2D.LINE_JOINT_ROUND
		body.end_cap_mode = Line2D.LINE_CAP_ROUND
		body.antialiased = true
		add_child(body)
		_bodies.append(body)

		var rim := Line2D.new()
		rim.width = t.width * _k * 0.14
		rim.width_curve = taper
		rim.gradient = rim_grad
		rim.material = rim_mat
		rim.joint_mode = Line2D.LINE_JOINT_ROUND
		rim.antialiased = true
		add_child(rim)
		_rims.append(rim)

	_suckers = Control.new()
	_suckers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_suckers.set_anchors_preset(Control.PRESET_FULL_RECT)
	_suckers.draw.connect(_draw_suckers)
	add_child(_suckers)


## Pale sucker dots along each tentacle's inner (compass-facing) side.
func _draw_suckers() -> void:
	for i in TENTACLES.size():
		var pts := _points[i]
		if pts.size() < POINTS:
			continue  # first frame, before _process has laid the tentacle out
		var w: float = TENTACLES[i].width * _k
		for j in range(5, POINTS - 8, 2):
			var u := float(j) / (POINTS - 1)
			var taper_w: float = lerp(1.0, 0.3, u)
			var p := pts[j]
			var inward := (_centre - p).normalized()
			var r: float = w * 0.13 * taper_w
			_suckers.draw_circle(p + inward * w * 0.28 * taper_w, r * 1.3, Color(0.05, 0.03, 0.05, 0.8))
			_suckers.draw_circle(p + inward * w * 0.28 * taper_w, r, Color(0.62, 0.48, 0.58, 0.55))


# --- compass glow / runes --------------------------------------------

func _build_glow() -> void:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	g.colors = PackedColorArray([Color(1.0, 0.8, 0.45, 0.45), Color(0.9, 0.6, 0.3, 0.18), Color(0.8, 0.5, 0.2, 0.0)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	_glow = TextureRect.new()
	_glow.texture = tex
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_glow.size = Vector2.ONE * RING_RADIUS * 1.5 * _k
	_glow.position = _centre - _glow.size * 0.5
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = mat
	add_child(_glow)


func _build_runes() -> void:
	_runes = Control.new()
	_runes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_runes.set_anchors_preset(Control.PRESET_FULL_RECT)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_runes.material = mat
	_runes.draw.connect(_draw_runes)
	add_child(_runes)


func _draw_runes() -> void:
	var r := (RING_RADIUS + 5.0) * _k
	var col := Color(1.0, 0.78, 0.42, 0.22 + 0.2 * _stir)
	_runes.draw_arc(_centre, r, 0.0, TAU, 96, col, 1.2 * _k, true)
	# ticks and small rune marks turning slowly around the dial
	for i in 36:
		var a := _rune_angle + TAU * i / 36.0
		var dir := Vector2.from_angle(a)
		var long := i % 3 == 0
		var inner := r + 2.0 * _k
		var outer := r + (7.0 if long else 4.0) * _k
		_runes.draw_line(_centre + dir * inner, _centre + dir * outer, col, 1.0 * _k, true)
		if i % 9 == 4:
			_runes.draw_circle(_centre + dir * (r + 11.0 * _k), 1.6 * _k, col)


# --- plaque hover ------------------------------------------------------

func _hook_button(button: Control, side: float) -> void:
	if button == null:
		return
	button.mouse_entered.connect(func(): _hover_target = side)
	button.mouse_exited.connect(func():
		if _hover_target == side:
			_hover_target = 0.0)


# --- lightning ---------------------------------------------------------

func _build_storm() -> void:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	g.colors = PackedColorArray([Color(0.75, 0.82, 1.0, 0.5), Color(0.6, 0.7, 1.0, 0.16), Color(0.5, 0.6, 1.0, 0.0)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	_storm_glow = TextureRect.new()
	_storm_glow.texture = tex
	_storm_glow.material = _add_mat()
	_storm_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_storm_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var r: float = STORM_GLOW.radius * _k
	_storm_glow.size = Vector2(r, r) * 2.0
	_storm_glow.position = STORM_GLOW.pos * _k - Vector2(r, r)
	_storm_glow.modulate.a = 0.0
	add_child(_storm_glow)

	# A child Timer (not a SceneTree one) so it dies with the Map scene.
	_strike_timer = Timer.new()
	_strike_timer.one_shot = true
	_strike_timer.timeout.connect(_strike)
	add_child(_strike_timer)
	_strike_timer.start(randf_range(0.8, 2.0))


func _add_mat() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m


## A jagged, forked bolt from the storm clouds down onto a random point
## along one of the tentacles, with a flash over the sea.
func _strike() -> void:
	_strike_timer.start(randf_range(STRIKE_GAP.x, STRIKE_GAP.y))
	# Strike somewhere visible: the outer, open-water part of a tentacle,
	# never behind the Shop / World Status plaques drawn over this layer.
	var blocked: Array[Rect2] = []
	for path in [shop_button_path, status_button_path]:
		var b := get_node_or_null(path) as Control
		if b:
			blocked.append(b.get_global_rect().grow(10))
	var candidates := PackedVector2Array()
	for pts in _points:
		if pts.size() < POINTS:
			continue
		for j in range(int(POINTS * 0.1), int(POINTS * 0.65)):
			var p := pts[j]
			if p.y > 40.0 * _k and not blocked.any(func(r): return r.has_point(p)):
				candidates.append(p)
	if candidates.is_empty():
		return
	var target := candidates[randi() % candidates.size()]
	var start := Vector2(target.x + randf_range(-60, 60) * _k, 24.0 * _k)
	var main := _jagged(start, target, 0.22)

	var bolt := Node2D.new()
	add_child(bolt)
	_add_bolt_line(bolt, main, 1.0)
	# one or two thinner forks branching off partway down
	for f in randi_range(1, 2):
		var from := main[randi_range(main.size() / 4, main.size() * 2 / 3)]
		var dir := (target - start).normalized().rotated(randf_range(-0.9, 0.9))
		var to := from + dir * randf_range(30, 60) * _k
		_add_bolt_line(bolt, _jagged(from, to, 0.3), 0.5)

	# burst of light where it hits
	var hit := TextureRect.new()
	hit.texture = _storm_glow.texture
	hit.material = _add_mat()
	hit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hit.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hit.size = Vector2.ONE * 70.0 * _k
	hit.position = target - hit.size / 2.0
	bolt.add_child(hit)

	_jolt = 1.0
	var tw := create_tween()
	tw.tween_property(bolt, "modulate:a", 0.3, 0.07)
	tw.tween_property(bolt, "modulate:a", 1.0, 0.05)
	tw.tween_interval(0.12)
	tw.tween_property(bolt, "modulate:a", 0.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(bolt.queue_free)
	var sky := create_tween()
	sky.tween_property(_storm_glow, "modulate:a", 1.0, 0.04)
	sky.tween_property(_storm_glow, "modulate:a", 0.3, 0.1)
	sky.tween_property(_storm_glow, "modulate:a", 0.8, 0.05)
	sky.tween_property(_storm_glow, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## Midpoint displacement: a crooked lightning path between two points.
func _jagged(a: Vector2, b: Vector2, roughness: float) -> PackedVector2Array:
	var pts := PackedVector2Array([a, b])
	var offset := a.distance_to(b) * roughness
	for level in 5:
		var out := PackedVector2Array()
		for i in pts.size() - 1:
			var p := pts[i]
			var q := pts[i + 1]
			var normal := (q - p).orthogonal().normalized()
			out.append(p)
			out.append((p + q) / 2.0 + normal * randf_range(-offset, offset))
		out.append(pts[pts.size() - 1])
		pts = out
		offset *= 0.5
	return pts


func _add_bolt_line(parent: Node, pts: PackedVector2Array, weight: float) -> void:
	var glow := Line2D.new()
	glow.points = pts
	glow.width = 11.0 * _k * weight
	glow.default_color = Color(0.55, 0.65, 1.0, 0.45)
	glow.material = _add_mat()
	glow.joint_mode = Line2D.LINE_JOINT_ROUND
	glow.antialiased = true
	parent.add_child(glow)
	var core := Line2D.new()
	core.points = pts
	core.width = 3.0 * _k * weight
	core.default_color = Color(0.92, 0.95, 1.0, 1.0)
	core.material = _add_mat()
	core.joint_mode = Line2D.LINE_JOINT_ROUND
	core.antialiased = true
	parent.add_child(core)
