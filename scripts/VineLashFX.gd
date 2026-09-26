class_name VineLashFX
extends Node2D

## Purely cosmetic: a thorned vine lashing out from a caster's hand to a
## target - Erynd's normal attack. It whips out along a sinuous curve
## that straightens as it reaches, strikes with a burst of spirit sparks
## and leaves, holds a moment, then withers back toward the hand.
##
## Drawn in layers: a soft additive spirit glow around it, the dark wood
## body tapering to a point, a mossy highlight, thorns, and a few leaves
## that unfurl as the vine passes. A hero uses it by naming it in its
## GameManager definition ("attack_effect": "vine_lash") - see battle.gd's
## _play_hero_attack_effect().

const GROW_TIME := 0.2
const HOLD_TIME := 0.14
const WITHER_TIME := 0.3
const SEGMENTS := 30

const WOOD_DARK := Color(0.16, 0.1, 0.06)
const WOOD := Color(0.36, 0.23, 0.12)
const MOSS := Color(0.34, 0.47, 0.16)
const BARK_LIGHT := Color(0.68, 0.55, 0.38)
const SPIRIT := Color(0.35, 1.0, 0.45)
const LEAF_COLORS := [Color(0.38, 0.55, 0.16), Color(0.6, 0.25, 0.1), Color(0.3, 0.45, 0.12)]
# Where along the vine (0 = hand, 1 = tip) leaves sprout, and which side.
const LEAVES := [[0.22, 1.0], [0.38, -1.0], [0.55, 1.0], [0.7, -1.0], [0.84, 1.0]]

var _from: Vector2
var _to: Vector2
var _on_hit: Callable
var _age := 0.0
var _phase := 0.0
var _amplitude := 0.0
var _hit_done := false
var _glow: Node2D


## Plays one lash from `from` to `to` (global positions) under `host`.
## `on_hit` fires the moment the tip reaches the target.
static func play(host: Node, from: Vector2, to: Vector2, on_hit: Callable = Callable()) -> void:
	var fx := VineLashFX.new()
	fx._from = from
	fx._to = to
	fx._on_hit = on_hit
	fx._phase = randf() * TAU
	fx._amplitude = clampf(from.distance_to(to) * 0.12, 10.0, 34.0) * (1.0 if randf() < 0.5 else -1.0)
	host.add_child(fx)
	fx.global_position = Vector2.ZERO
	fx._burst(from, 10, 0.6)


func _ready() -> void:
	_glow = Node2D.new()
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = mat
	_glow.draw.connect(_draw_glow)
	add_child(_glow)
	# The vine body goes on its own child, added after the glow so it
	# draws on top of it.
	var body := Node2D.new()
	body.draw.connect(_draw_body)
	add_child(body)


func _process(delta: float) -> void:
	_age += delta
	if not _hit_done and _age >= GROW_TIME:
		_hit_done = true
		_burst(_to, 22, 1.0)
		if _on_hit.is_valid():
			_on_hit.call()
	if _age >= GROW_TIME + HOLD_TIME + WITHER_TIME:
		queue_free()
		return
	for child in get_children():
		child.queue_redraw()


## How far along the path the vine reaches (x: 0 = hand, 1 = target -
## it withers back from the tip toward the hand) and its opacity (y).
func _extent() -> Vector2:
	var grow := clampf(_age / GROW_TIME, 0.0, 1.0)
	grow = 1.0 - pow(1.0 - grow, 3.0)
	var wither := clampf((_age - GROW_TIME - HOLD_TIME) / WITHER_TIME, 0.0, 1.0)
	var tip := grow * (1.0 - wither * 0.85)
	return Vector2(tip, 1.0 - wither * wither)


## Point `t` (0..1) along the vine. It snakes in a curve that relaxes
## toward a straight line as it finishes reaching, pinned at both ends.
func _point(t: float) -> Vector2:
	var dir := _to - _from
	var normal := Vector2(-dir.y, dir.x).normalized()
	var reach := clampf(_age / GROW_TIME, 0.0, 1.0)
	var slack := 1.0 - 0.7 * reach
	var wave := sin(t * TAU * 1.25 + _phase - _age * 14.0) * _amplitude * slack
	# A smaller, faster kink on top so the curve isn't a clean sine.
	wave += sin(t * TAU * 3.7 + _phase * 2.3 - _age * 9.0) * _amplitude * 0.22
	# A slight upward bow so it reads as thrown, not drawn with a ruler.
	var bow := -absf(dir.x) * 0.06 * 4.0 * t * (1.0 - t)
	return _from + dir * t + normal * wave * sin(t * PI) + Vector2(0.0, bow)


func _points() -> PackedVector2Array:
	var e := _extent()
	var pts := PackedVector2Array()
	for i in SEGMENTS + 1:
		pts.append(_point(float(i) / SEGMENTS * e.x))
	return pts


func _draw_glow() -> void:
	var e := _extent()
	if e.x <= 0.0:
		return
	var pts := _points()
	for i in pts.size() - 1:
		var k := float(i) / SEGMENTS
		# Spirit energy streaming from the hand toward the target: bright
		# pulses riding along a faint, steady aura.
		var stream := pow(0.5 + 0.5 * sin(k * 22.0 - _age * 45.0), 4.0)
		var w := lerpf(12.0, 5.0, k)
		_glow.draw_line(pts[i], pts[i + 1], Color(SPIRIT, (0.08 + 0.22 * stream) * e.y), w, true)
		_glow.draw_line(pts[i], pts[i + 1], Color(SPIRIT, 0.3 * stream * e.y), w * 0.35, true)
	# A brief bloom where it strikes.
	if _hit_done and _age < GROW_TIME + HOLD_TIME:
		var flash := 1.0 - clampf((_age - GROW_TIME) / HOLD_TIME, 0.0, 1.0)
		_glow.draw_circle(pts[pts.size() - 1], 6.0 + 10.0 * flash, Color(SPIRIT, 0.3 * flash * e.y))


func _draw_body() -> void:
	var e := _extent()
	if e.x <= 0.0:
		return
	var body: Node2D = get_child(1)
	var pts := _points()
	var a := e.y
	# Two strands of bark twisted around each other, tapering from thick
	# at the hand to a sharp point at the tip. Where a strand crosses over
	# the other it's drawn lighter, so the twist reads as depth.
	for strand in 2:
		var offset := 0.0 if strand == 0 else PI
		for i in pts.size() - 1:
			var k := float(i) / SEGMENTS
			var w := lerpf(9.0, 1.2, pow(k, 0.8))
			var n := (pts[i + 1] - pts[i]).orthogonal().normalized()
			var twist := sin(k * 26.0 + offset - _age * 6.0)
			var shift := n * twist * w * 0.35
			var near := 0.5 + 0.5 * cos(k * 26.0 + offset - _age * 6.0)
			var sw := w * 0.62
			body.draw_line(pts[i] + shift, pts[i + 1] + shift, Color(WOOD_DARK, a), sw + 1.5, true)
			# Moss clings in patches, not stripes.
			var moss := smoothstep(0.55, 0.9, sin(k * 9.0 + offset * 1.7 + _phase) * 0.5 + 0.5) * 0.6
			var col := WOOD.lerp(MOSS, moss).lerp(WOOD_DARK, 0.45 * (1.0 - near))
			body.draw_line(pts[i] + shift, pts[i + 1] + shift, Color(col, a), sw, true)
			# Pale bark catching the light on the strand in front.
			if near > 0.6:
				var hl := n * sw * 0.2
				body.draw_line(pts[i] + shift - hl, pts[i + 1] + shift - hl, Color(BARK_LIGHT, 0.45 * a * (near - 0.6) / 0.4), maxf(sw * 0.25, 1.0), true)

	# Thorns every few segments, alternating sides, hooked back toward the hand.
	for i in range(3, pts.size() - 2, 3):
		var k := float(i) / SEGMENTS
		var dir := (pts[i + 1] - pts[i]).normalized()
		var side := 1.0 if i % 6 < 3 else -1.0
		var n := dir.orthogonal() * side
		var w := lerpf(9.0, 1.2, pow(k, 0.8))
		var base := pts[i] + n * w * 0.4
		var tip := base + n * (3.0 + w * 0.6) - dir * 3.0
		body.draw_colored_polygon(PackedVector2Array([base - dir * 2.0, tip, base + dir * 2.0]), Color(WOOD_DARK.lightened(0.15), a))

	# Leaves unfurl once the vine has grown past them.
	for j in LEAVES.size():
		var t: float = LEAVES[j][0]
		if t > e.x:
			continue
		var grown := clampf((e.x - t) * 6.0, 0.0, 1.0)
		var at := _point(t)
		var dir := (_point(minf(t + 0.02, 1.0)) - at).normalized()
		var n := dir.orthogonal() * float(LEAVES[j][1])
		var size := 7.0 * grown
		var center := at + n * size * 0.9
		var along := (n * 0.8 + dir * 0.6).normalized()
		var across := along.orthogonal()
		var col: Color = LEAF_COLORS[j % LEAF_COLORS.size()]
		body.draw_colored_polygon(PackedVector2Array([
			center - along * size, center - along * size * 0.2 + across * size * 0.45,
			center + along * size, center - along * size * 0.2 - across * size * 0.45,
		]), Color(col, a))
		body.draw_line(center - along * size, center + along * size * 0.8, Color(col.darkened(0.45), a * 0.8), 1.0, true)


## A puff of spirit sparks and leaf bits at `at`.
func _burst(at: Vector2, amount: int, strength: float) -> void:
	var host := get_parent()
	if host == null:
		return
	for pass_i in 2:
		var p := CPUParticles2D.new()
		p.one_shot = true
		p.explosiveness = 0.9
		p.amount = amount if pass_i == 0 else maxi(amount / 2, 4)
		p.lifetime = 0.45 if pass_i == 0 else 0.7
		p.spread = 180.0
		p.gravity = Vector2(0, -40) if pass_i == 0 else Vector2(0, 160)
		p.initial_velocity_min = 40.0 * strength
		p.initial_velocity_max = 140.0 * strength
		p.scale_amount_min = 1.5 if pass_i == 0 else 2.0
		p.scale_amount_max = 3.0 if pass_i == 0 else 4.0
		p.color = SPIRIT if pass_i == 0 else LEAF_COLORS[1]
		if pass_i == 0:
			var mat := CanvasItemMaterial.new()
			mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			p.material = mat
		host.add_child(p)
		p.global_position = at
		p.emitting = true
		p.finished.connect(p.queue_free)
