class_name ThornbindVines
extends Node2D

## Purely cosmetic: Thornbind's root - gnarled vines bursting from the
## ground and coiling up around a unit's legs, holding it for as long as
## the root lasts, then unwinding back into the earth.
##
## The vines really wrap around the unit: each coil is a helix, and the
## stretches that pass behind the unit are drawn on a second node with
## show_behind_parent, underneath the unit's art, while the stretches in
## front draw over it. Same bark-and-moss look as Erynd's vine lash
## (VineLashFX).
##
## Added as a child of the unit's node (so it follows it around and is
## freed with it). battle.gd drives it with attach()/release().

const NODE_NAME := "ThornbindVines"
const GROW_TIME := 0.5
const RELEASE_TIME := 0.45
const VINE_COUNT := 3
const SEGMENTS := 44

# Where on the unit the coils sit, as fractions of its node's size.
const FEET_Y := 0.93
const WRAP_HEIGHT := 0.45
const WRAP_RADIUS := 0.2

const WOOD_DARK := VineLashFX.WOOD_DARK
const WOOD := VineLashFX.WOOD
const MOSS := VineLashFX.MOSS
const BARK_LIGHT := VineLashFX.BARK_LIGHT
const SPIRIT := VineLashFX.SPIRIT
const SOIL := Color(0.09, 0.07, 0.04)

var _target: Control
var _back: Node2D
var _grow := 0.0
var _fade := 1.0
var _age := 0.0
var _releasing := false
var _release_t := 0.0
var _vines: Array[Dictionary] = []


## Starts rooting `node` (no-op if it's already rooted).
static func attach(node: Control) -> void:
	if node.get_node_or_null(NODE_NAME) != null:
		return
	var vines := ThornbindVines.new()
	vines.name = NODE_NAME
	vines._target = node
	node.add_child(vines)


## Unwinds `node`'s vines back into the ground (no-op if it has none).
static func release(node: Variant) -> void:
	if not (node is Control) or not is_instance_valid(node):
		return
	var vines := (node as Control).get_node_or_null(NODE_NAME) as ThornbindVines
	if vines != null:
		vines._start_release()


func _ready() -> void:
	_back = Node2D.new()
	_back.show_behind_parent = true
	_back.draw.connect(_draw_layer.bind(false))
	_target.add_child(_back)
	for i in VINE_COUNT:
		_vines.append({
			"phase": TAU * i / VINE_COUNT + randf_range(-0.4, 0.4),
			"turns": randf_range(1.1, 1.6),
			# Alternate the winding direction so the coils criss-cross.
			"dir": 1.0 if i % 2 == 0 else -1.0,
			"height": randf_range(0.7, 1.1),
			"width": randf_range(6.5, 9.0),
			# Each climbs at its own slight slant.
			"lean": randf_range(-0.12, 0.12),
		})


func _exit_tree() -> void:
	if is_instance_valid(_back):
		_back.queue_free()


func _start_release() -> void:
	if _releasing:
		return
	_releasing = true
	# Renamed right away so a quick re-root grows a fresh set instead of
	# finding this one mid-unwind.
	name = NODE_NAME + "Releasing"


func _process(delta: float) -> void:
	_age += delta
	if _releasing:
		_release_t += delta / RELEASE_TIME
		_grow = 1.0 - smoothstep(0.0, 1.0, _release_t)
		_fade = 1.0 - smoothstep(0.5, 1.0, _release_t)
		if _release_t >= 1.0:
			queue_free()
			return
	else:
		var g := clampf(_age / GROW_TIME, 0.0, 1.0)
		_grow = 1.0 - pow(1.0 - g, 3.0)
	queue_redraw()
	_back.queue_redraw()


func _draw() -> void:
	_draw_layer(true)


## Point `s` (0 = ground, 1 = top of the coil) along vine `v`, plus
## whether that part of the coil is in front of the unit.
func _coil(v: Dictionary, s: float) -> Array:
	var size := _target.size
	# The coils squeeze a little in a slow rhythm while they hold.
	var squeeze := 1.0 - 0.05 * (0.5 + 0.5 * sin(_age * 2.6)) * (0.0 if _releasing else 1.0)
	# Wide where it bursts out of the ground, tightening as it wraps -
	# lumpy rather than a clean spring - and flaring back out at the tip
	# like a tendril still groping for a hold.
	var r: float = size.x * WRAP_RADIUS * squeeze * lerpf(1.9, 1.0, smoothstep(0.0, 0.18, s)) * (1.0 - 0.2 * s)
	r *= 1.0 + 0.22 * sin(s * 7.0 + v["phase"] * 3.0)
	var curl := smoothstep(0.82, 1.0, s)
	r *= 1.0 + 0.9 * curl
	var theta: float = v["dir"] * s * v["turns"] * TAU + v["phase"]
	var x: float = size.x * 0.5 + cos(theta) * r + s * v["lean"] * size.x
	var y: float = size.y * FEET_Y - s * size.y * WRAP_HEIGHT * v["height"] + sin(theta) * r * 0.42 - curl * size.y * 0.05
	# sin(theta) > 0 puts it lower on screen, i.e. nearer the viewer.
	return [Vector2(x, y), sin(theta) > 0.0]


func _draw_layer(front: bool) -> void:
	var canvas: CanvasItem = self if front else _back
	if _grow <= 0.0 or _target == null:
		return
	var size := _target.size
	var a := _fade

	# Churned earth where they burst out, behind the unit's feet.
	if not front:
		var soil_r := size.x * WRAP_RADIUS * 1.9 * minf(_grow * 1.6, 1.0)
		canvas.draw_set_transform(Vector2(size.x * 0.5, size.y * FEET_Y), 0.0, Vector2(1.0, 0.25))
		canvas.draw_circle(Vector2.ZERO, soil_r, Color(SOIL, 0.55 * a))
		canvas.draw_circle(Vector2.ZERO, soil_r * 0.7, Color(SOIL, 0.35 * a))
		canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	for v in _vines:
		var top: float = _grow
		for i in SEGMENTS:
			var s0 := float(i) / SEGMENTS * top
			var s1 := float(i + 1) / SEGMENTS * top
			var c0: Array = _coil(v, s0)
			var c1: Array = _coil(v, s1)
			var mid_front: bool = _coil(v, (s0 + s1) * 0.5)[1]
			if mid_front != front:
				continue
			var p0: Vector2 = c0[0]
			var p1: Vector2 = c1[0]
			# Thick at the ground, tapering up the coil and to a point at
			# the growing tip.
			var tip := smoothstep(0.0, 0.1, top - s0) * 0.75 + 0.25
			var w: float = v["width"] * (1.0 - 0.7 * s0) * tip
			var shade := 0.0 if front else 0.5
			var moss := smoothstep(0.55, 0.9, sin(s0 * 14.0 + v["phase"] * 1.7) * 0.5 + 0.5) * 0.6
			var col := WOOD.lerp(MOSS, moss).lerp(WOOD_DARK, shade)
			canvas.draw_line(p0, p1, Color(WOOD_DARK, a), w + 1.5, true)
			canvas.draw_line(p0, p1, Color(col, a), w, true)
			if front:
				var n := (p1 - p0).orthogonal().normalized() * w * 0.22
				canvas.draw_line(p0 - n, p1 - n, Color(BARK_LIGHT, 0.4 * a), maxf(w * 0.25, 1.0), true)
				# A faint thread of spirit light pulsing up the vine.
				var pulse := pow(0.5 + 0.5 * sin(s0 * 30.0 - _age * 6.0), 6.0)
				canvas.draw_line(p0, p1, Color(SPIRIT, 0.35 * pulse * a), maxf(w * 0.3, 1.0), true)
				# Thorns now and then, hooked downward.
				if i % 5 == 2 and w > 2.0:
					var dir := (p1 - p0).normalized()
					var side := n.normalized() * (1.0 if i % 10 == 2 else -1.0)
					var base := p0 + side * w * 0.4
					canvas.draw_colored_polygon(PackedVector2Array([
						base - dir * 2.0, base + side * (2.5 + w * 0.5) - dir * 2.5, base + dir * 2.0,
					]), Color(WOOD_DARK.lightened(0.15), a))

		# A leaf or two where the coil faces us.
		if front:
			for t in [0.35, 0.7]:
				if t > _grow:
					continue
				var c: Array = _coil(v, t)
				if not c[1]:
					continue
				var p: Vector2 = c[0]
				var ahead: Vector2 = _coil(v, minf(t + 0.03, 1.0))[0]
				var along: Vector2 = (ahead - p).normalized()
				var across: Vector2 = along.orthogonal()
				var size_l: float = 6.0 * smoothstep(0.0, 0.15, _grow - t)
				var leaf_col: Color = VineLashFX.LEAF_COLORS[absi(int(v["phase"] * 10.0 + t * 10.0)) % VineLashFX.LEAF_COLORS.size()]
				var center: Vector2 = p - across * size_l
				canvas.draw_colored_polygon(PackedVector2Array([
					center - across * size_l, center + along * size_l * 0.45,
					center + across * size_l, center - along * size_l * 0.45,
				]), Color(leaf_col, a))
