class_name ProjectileFX
extends RefCounted

## Purely cosmetic attack projectiles (arrows, bolts, spikes, ...) flying
## from an attacker to its target along an arc, rotating to follow it,
## with a particle trail and a spark burst on impact.
##
## Any creep can use one by naming a style in its GameManager enemy
## definition - "projectile": "abyss_arrow" - and battle.gd's ranged
## attack fires it (see _fire_enemy_projectile()). New looks are just
## new entries in STYLES.

## Every color/size a projectile needs. Any key a style leaves out
## falls back to DEFAULT_STYLE.
const DEFAULT_STYLE := {
	# "arrow" (shaft, head, fletching), "spike" (a tapering quill) or
	# "skull" (a ghostly skull; "length" is its height).
	"shape": "arrow",
	# Where it leaves the attacker: x = how far forward of the art's
	# center (fraction of its width, toward the way it faces), y = how
	# far down from its top (fraction of its height).
	"launch": Vector2(0.3, 0.42),
	# A volley: this many, released `stagger` s apart, each landing up
	# to `spread` px off the target's center.
	"count": 1,
	"stagger": 0.0,
	"spread": 0.0,
	"length": 54.0,
	"shaft_width": 3.0,
	"shaft_color": Color(0.55, 0.38, 0.22),
	"head_color": Color(0.82, 0.84, 0.88),
	# Arrows: the feathers. Spikes: the base color it fades from.
	"fletch_color": Color(0.92, 0.9, 0.85),
	"glow_color": Color(1, 1, 1, 0.0),
	"trail_color": Color(1, 1, 1, 0.35),
	"impact_color": Color(1.0, 0.9, 0.7),
	# Arc height as a fraction of the flight distance, capped at max_arc px.
	"arc": 0.12,
	"max_arc": 60.0,
	# Seconds: base + per_100px * (distance / 100).
	"base_duration": 0.14,
	"per_100px_duration": 0.045,
	# Soft, slow-fading mist puffs instead of sharp sparks, for the trail
	# and the impact burst.
	"mist": false,
}

const STYLES := {
	"arrow": {},
	# Iron Abyss range creeps: a dark iron bolt with a glowing teal head
	# and a trail of abyssal sparks.
	"abyss_arrow": {
		"shaft_color": Color(0.16, 0.18, 0.24),
		"head_color": Color(0.45, 1.0, 0.95),
		"fletch_color": Color(0.35, 0.3, 0.6),
		"glow_color": Color(0.3, 0.95, 1.0, 0.35),
		"trail_color": Color(0.35, 0.95, 1.0, 0.8),
		"impact_color": Color(0.45, 1.0, 1.0),
	},
	# Elderwild range creeps (the quill beast): a volley of dark,
	# moss-stained quills flung off its back in a high lob, bursting
	# into wood splinters.
	"thorn_quill": {
		"shape": "spike",
		"launch": Vector2(0.05, 0.3),
		"count": 3,
		"stagger": 0.06,
		"spread": 22.0,
		"length": 60.0,
		"shaft_width": 8.0,
		"shaft_color": Color(0.5, 0.41, 0.28),
		"head_color": Color(0.96, 0.9, 0.74),
		"fletch_color": Color(0.36, 0.46, 0.17),
		"trail_color": Color(0.6, 0.66, 0.35, 0.6),
		"impact_color": Color(0.62, 0.5, 0.3),
		"arc": 0.22,
		"max_arc": 90.0,
	},
	# Kingdom of Morvain range creeps: the glowing skull they hold out,
	# hurled - it drifts across trailing mist and bursts into a cloud of it.
	"mist_skull": {
		"shape": "skull",
		"mist": true,
		"launch": Vector2(0.45, 0.2),
		"length": 42.0,
		"head_color": Color(0.62, 0.9, 0.88, 0.62),
		"glow_color": Color(0.3, 1.0, 0.92, 0.75),
		"trail_color": Color(0.42, 0.92, 0.88, 0.7),
		"impact_color": Color(0.5, 1.0, 0.95, 0.8),
		"arc": 0.06,
		"max_arc": 30.0,
		"base_duration": 0.22,
		"per_100px_duration": 0.075,
	},
}


static func has_style(style_id: String) -> bool:
	return STYLES.has(style_id)


## The style's launch point (see DEFAULT_STYLE's "launch").
static func launch_point(style_id: String) -> Vector2:
	return _style(style_id)["launch"]


static func _style(style_id: String) -> Dictionary:
	var style: Dictionary = DEFAULT_STYLE.duplicate()
	style.merge(STYLES.get(style_id, {}), true)
	return style


## Fires a `style_id` projectile (or volley) from `from` to `to` (global
## positions), added under `host`. Calls `on_hit` once, when the first
## one lands.
static func fire(host: Node, style_id: String, from: Vector2, to: Vector2, on_hit: Callable = Callable()) -> void:
	var style := _style(style_id)
	var spread: float = style["spread"]
	for i in int(style["count"]):
		var aim := to
		if i > 0:
			aim += Vector2(randf_range(-spread, spread), randf_range(-spread, spread) * 0.7)
		_fire_one(host, style, from, aim, float(style["stagger"]) * i, on_hit if i == 0 else Callable())


static func _fire_one(host: Node, style: Dictionary, from: Vector2, to: Vector2, delay: float, on_hit: Callable) -> void:
	var shape: String = style["shape"]
	var projectile: Node2D
	match shape:
		"spike":
			projectile = _build_spike(style)
		"skull":
			projectile = _build_skull(style)
		_:
			projectile = _build_arrow(style)
	host.add_child(projectile)
	projectile.global_position = from
	projectile.visible = delay <= 0.0

	var trail := CPUParticles2D.new()
	trail.local_coords = false
	# Arrows and spikes trail from their tail; a skull from its middle.
	trail.position = Vector2.ZERO if shape == "skull" else Vector2(-float(style["length"]), 0.0)
	trail.amount = 28
	trail.lifetime = 0.28
	trail.spread = 18.0
	trail.direction = Vector2(-1, 0)
	trail.gravity = Vector2.ZERO
	trail.initial_velocity_min = 8.0
	trail.initial_velocity_max = 30.0
	trail.scale_amount_min = 1.2
	trail.scale_amount_max = 2.8
	trail.color = style["trail_color"]
	if style["mist"]:
		_make_misty(trail, style["trail_color"], 1.0)
		trail.amount = 110
		trail.scale_amount_min = 1.1
		trail.scale_amount_max = 2.0
		trail.spread = 180.0
		trail.initial_velocity_min = 4.0
		trail.initial_velocity_max = 14.0
	projectile.add_child(trail)
	trail.emitting = style["trail_color"].a > 0.0 and delay <= 0.0

	var distance: float = from.distance_to(to)
	var arc: float = minf(distance * float(style["arc"]), float(style["max_arc"]))
	var duration: float = float(style["base_duration"]) + float(style["per_100px_duration"]) * distance / 100.0

	var flight := func(p: float) -> void:
		var pos: Vector2 = from.lerp(to, p) + Vector2(0.0, -arc * 4.0 * p * (1.0 - p))
		if shape == "skull":
			# A skull stays upright, bobbing and rocking as it drifts.
			pos.y += sin(p * TAU * 1.5) * 5.0
			projectile.global_position = pos
			projectile.rotation = sin(p * TAU * 1.2) * 0.14
			return
		# Tangent of the arc, so the arrow noses up, then down.
		var tangent: Vector2 = (to - from) + Vector2(0.0, -arc * 4.0 * (1.0 - 2.0 * p))
		projectile.global_position = pos
		projectile.rotation = tangent.angle()
	flight.call(0.0)

	var tween := projectile.create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
		tween.tween_callback(func() -> void:
			projectile.visible = true
			trail.emitting = style["trail_color"].a > 0.0
		)
	tween.tween_method(flight, 0.0, 1.0, duration)
	tween.tween_callback(func() -> void:
		trail.emitting = false
		_spawn_impact(host, to, style["impact_color"], style["mist"])
		if on_hit.is_valid():
			on_hit.call()
	)
	tween.tween_property(projectile, "modulate:a", 0.0, 0.1)
	tween.tween_callback(projectile.queue_free)


## A quill/thorn pointing right (+x), TIP at the origin: a long tapering
## body darkening toward its base, a pale point, and a few tiny barbs.
static func _build_spike(style: Dictionary) -> Node2D:
	var spike := Node2D.new()
	var length: float = style["length"]
	var half: float = float(style["shaft_width"]) / 2.0
	var tip_len: float = length * 0.3

	var body := Polygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2(-length, -half * 0.6), Vector2(-tip_len, -half),
		Vector2(-tip_len, half), Vector2(-length, half * 0.6),
	])
	var base_color: Color = style["shaft_color"]
	var moss: Color = style["fletch_color"]
	# Mossy at the base, fading into the dark quill toward the tip.
	body.vertex_colors = PackedColorArray([moss, base_color, base_color, moss])
	spike.add_child(body)

	var tip := Polygon2D.new()
	var tip_color: Color = style["head_color"]
	tip.polygon = PackedVector2Array([
		Vector2(-tip_len, -half), Vector2(0.0, 0.0), Vector2(-tip_len, half),
	])
	tip.vertex_colors = PackedColorArray([base_color, tip_color, base_color])
	spike.add_child(tip)

	# A pale highlight along the top edge so it reads against dark art.
	var shine := Line2D.new()
	shine.points = PackedVector2Array([Vector2(-length * 0.85, -half * 0.35), Vector2(-tip_len * 0.4, -half * 0.25)])
	shine.width = 1.0
	shine.default_color = Color(tip_color, 0.55)
	spike.add_child(shine)

	for x in [-length * 0.7, -length * 0.5]:
		var barb := Polygon2D.new()
		barb.color = base_color
		barb.polygon = PackedVector2Array([
			Vector2(x, -half * 0.8), Vector2(x - 5.0, -half - 3.0), Vector2(x + 3.0, -half * 0.8),
		])
		spike.add_child(barb)

	return spike


## An arrow pointing right (+x) with its TIP at the origin, so its
## position is exactly where it strikes.
static func _build_arrow(style: Dictionary) -> Node2D:
	var arrow := Node2D.new()
	var length: float = style["length"]
	var shaft_half: float = float(style["shaft_width"]) / 2.0
	var head_len := 12.0
	var head_half := 5.5

	var glow_color: Color = style["glow_color"]
	if glow_color.a > 0.0:
		var glow := Polygon2D.new()
		glow.color = glow_color
		glow.polygon = PackedVector2Array([
			Vector2(-length, -shaft_half - 3.0), Vector2(-head_len, -head_half - 3.0),
			Vector2(4.0, 0.0),
			Vector2(-head_len, head_half + 3.0), Vector2(-length, shaft_half + 3.0),
		])
		arrow.add_child(glow)

	var shaft := Polygon2D.new()
	shaft.color = style["shaft_color"]
	shaft.polygon = PackedVector2Array([
		Vector2(-length, -shaft_half), Vector2(-head_len, -shaft_half),
		Vector2(-head_len, shaft_half), Vector2(-length, shaft_half),
	])
	arrow.add_child(shaft)

	var head := Polygon2D.new()
	head.color = style["head_color"]
	head.polygon = PackedVector2Array([
		Vector2(-head_len - 2.0, -head_half), Vector2(0.0, 0.0),
		Vector2(-head_len - 2.0, head_half), Vector2(-head_len + 2.0, 0.0),
	])
	arrow.add_child(head)

	for side in [-1.0, 1.0]:
		var fletch := Polygon2D.new()
		fletch.color = style["fletch_color"]
		fletch.polygon = PackedVector2Array([
			Vector2(-length + 12.0, side * shaft_half),
			Vector2(-length + 1.0, side * (shaft_half + 6.0)),
			Vector2(-length - 3.0, side * (shaft_half + 6.0)),
			Vector2(-length + 2.0, side * shaft_half),
		])
		arrow.add_child(fletch)

	return arrow


static func _spawn_impact(host: Node, at: Vector2, color: Color, mist: bool = false) -> void:
	if not is_instance_valid(host):
		return
	var burst := CPUParticles2D.new()
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.amount = 18
	burst.lifetime = 0.35
	burst.spread = 180.0
	burst.gravity = Vector2(0, 120)
	burst.initial_velocity_min = 60.0
	burst.initial_velocity_max = 160.0
	burst.scale_amount_min = 1.5
	burst.scale_amount_max = 3.5
	burst.color = color
	if mist:
		# A cloud of mist billowing out and hanging a moment.
		_make_misty(burst, color, 0.9)
		burst.amount = 26
		burst.explosiveness = 0.9
		burst.gravity = Vector2(0, -12)
		burst.initial_velocity_min = 25.0
		burst.initial_velocity_max = 75.0
		burst.damping_min = 40.0
		burst.damping_max = 70.0
	host.add_child(burst)
	burst.global_position = at
	burst.emitting = true
	burst.finished.connect(burst.queue_free)


## Turns `particles` into soft mist: round, feathered puffs that swell
## and fade out over `lifetime` seconds, instead of hard square sparks.
static func _make_misty(particles: CPUParticles2D, color: Color, lifetime: float) -> void:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 32
	tex.height = 32
	particles.texture = tex
	particles.lifetime = lifetime
	particles.scale_amount_min = 0.35
	particles.scale_amount_max = 0.75
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.5))
	grow.add_point(Vector2(1.0, 1.6))
	particles.scale_amount_curve = grow
	var ramp := Gradient.new()
	ramp.set_color(0, color)
	ramp.set_color(1, Color(color, 0.0))
	particles.color_ramp = ramp
	particles.color = Color.WHITE


## A ghostly skull facing the viewer, centered on the origin: a pale,
## half-see-through skull with hollow sockets burning teal, wrapped in a
## soft glow. "length" is its height.
static func _build_skull(style: Dictionary) -> Node2D:
	var skull := Node2D.new()
	var h: float = style["length"]
	var r := h * 0.5
	var bone: Color = style["head_color"]
	var glow_color: Color = style["glow_color"]
	var hollow := Color(0.02, 0.05, 0.06, 0.95)

	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	# The glow it's wrapped in.
	var g := Gradient.new()
	g.set_color(0, Color(glow_color, 1.0))
	g.set_color(1, Color(glow_color, 0.0))
	var glow_tex := GradientTexture2D.new()
	glow_tex.gradient = g
	glow_tex.fill = GradientTexture2D.FILL_RADIAL
	glow_tex.fill_from = Vector2(0.5, 0.5)
	glow_tex.fill_to = Vector2(1.0, 0.5)
	glow_tex.width = 64
	glow_tex.height = 64
	var glow := Sprite2D.new()
	glow.texture = glow_tex
	glow.scale = Vector2.ONE * (h * 3.2 / 64.0)
	glow.modulate.a = glow_color.a
	glow.material = add_mat
	skull.add_child(glow)

	# The face is drawn opaque inside a CanvasGroup and faded as one, so
	# where its pieces overlap never shows through as a seam.
	var face := CanvasGroup.new()
	face.self_modulate.a = bone.a
	skull.add_child(face)
	var solid := Color(bone, 1.0)

	# Cranium, then the narrower jaw below it.
	face.add_child(_ellipse(Vector2(0.0, -r * 0.18), Vector2(r * 0.95, r * 0.82), solid))
	var jaw := Polygon2D.new()
	jaw.color = solid
	jaw.polygon = PackedVector2Array([
		Vector2(-r * 0.62, r * 0.25), Vector2(r * 0.62, r * 0.25),
		Vector2(r * 0.5, r * 0.85), Vector2(r * 0.2, r),
		Vector2(-r * 0.2, r), Vector2(-r * 0.5, r * 0.85),
	])
	face.add_child(jaw)

	# Hollow eye sockets with a teal fire deep inside each.
	for side in [-1.0, 1.0]:
		var at := Vector2(side * r * 0.38, -r * 0.08)
		face.add_child(_ellipse(at, Vector2(r * 0.27, r * 0.3), hollow))
		var ember := _ellipse(at + Vector2(0.0, r * 0.03), Vector2(r * 0.1, r * 0.11), Color(0.55, 1.0, 0.95))
		ember.material = add_mat
		skull.add_child(ember)

	# Nose and a dark grin.
	var nose := Polygon2D.new()
	nose.color = hollow
	nose.polygon = PackedVector2Array([Vector2(0.0, r * 0.2), Vector2(-r * 0.1, r * 0.42), Vector2(r * 0.1, r * 0.42)])
	face.add_child(nose)
	var grin := Line2D.new()
	grin.width = maxf(1.0, r * 0.08)
	grin.default_color = hollow
	grin.points = PackedVector2Array([Vector2(-r * 0.42, r * 0.62), Vector2(r * 0.42, r * 0.62)])
	face.add_child(grin)
	for i in 5:
		var tooth := Line2D.new()
		tooth.width = maxf(1.0, r * 0.05)
		tooth.default_color = hollow
		var x := (-0.3 + 0.15 * i) * r
		tooth.points = PackedVector2Array([Vector2(x, r * 0.5), Vector2(x, r * 0.74)])
		face.add_child(tooth)

	return skull


static func _ellipse(center: Vector2, radii: Vector2, color: Color) -> Polygon2D:
	var poly := Polygon2D.new()
	poly.color = color
	var points := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		points.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	poly.polygon = points
	return poly
