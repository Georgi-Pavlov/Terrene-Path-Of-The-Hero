class_name MistTendrilFX
extends Node2D

## Purely cosmetic: a tendril of living mist reaching from a caster to a
## target - Morvael's Whisper of the Veil. It snakes out along a slow,
## sinuous curve, strikes with a burst of mist, clings for a moment, then
## frays apart and drifts away instead of retracting.
##
## Drawn in layers: a wide, faint additive glow, several soft strands of
## mist twisting around each other (widest at the caster, thinning to a
## wisp at the tip), and a thin pale core of light running through them.

const GROW_TIME := 0.3
const HOLD_TIME := 0.2
const FADE_TIME := 0.5
const SEGMENTS := 36
const STRANDS := 6

const MIST := Color(0.66, 0.9, 0.88)
const GLOW := Color(0.3, 1.0, 0.9)
const CORE := Color(0.85, 1.0, 0.98)

var _from: Vector2
var _to: Vector2
var _on_hit: Callable
var _age := 0.0
var _phase := 0.0
var _amplitude := 0.0
var _hit_done := false
var _glow: Node2D
var _body: Node2D
# Where the strands sit around the tendril's center line, and how fast
# each one twists, so they never move in lockstep.
var _strand_offsets: Array[float] = []
var _strand_speeds: Array[float] = []


## Plays one tendril from `from` to `to` (global positions) under `host`.
## `on_hit` fires the moment its tip reaches the target.
static func play(host: Node, from: Vector2, to: Vector2, on_hit: Callable = Callable()) -> void:
	var fx := MistTendrilFX.new()
	fx._from = from
	fx._to = to
	fx._on_hit = on_hit
	fx._phase = randf() * TAU
	fx._amplitude = clampf(from.distance_to(to) * 0.1, 8.0, 30.0) * (1.0 if randf() < 0.5 else -1.0)
	for i in STRANDS:
		fx._strand_offsets.append(TAU * i / STRANDS + randf_range(-0.4, 0.4))
		fx._strand_speeds.append(randf_range(3.0, 5.5) * (1.0 if i % 2 == 0 else -1.0))
	host.add_child(fx)
	fx.global_position = Vector2.ZERO


func _ready() -> void:
	_glow = Node2D.new()
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = mat
	_glow.draw.connect(_draw_glow)
	add_child(_glow)
	# The strands go on their own child, added after the glow so they
	# draw on top of it.
	_body = Node2D.new()
	_body.draw.connect(_draw_body)
	add_child(_body)


func _process(delta: float) -> void:
	_age += delta
	if not _hit_done and _age >= GROW_TIME:
		_hit_done = true
		ProjectileFX._spawn_impact(get_parent(), _to, Color(GLOW, 0.75), true)
		if _on_hit.is_valid():
			_on_hit.call()
	if _age >= GROW_TIME + HOLD_TIME + FADE_TIME:
		queue_free()
		return
	_glow.queue_redraw()
	_body.queue_redraw()


## How far along the path the tendril reaches (x: 0 = caster, 1 =
## target), how solid it is (y), and how far it has frayed apart (z).
func _state() -> Vector3:
	var grow := clampf(_age / GROW_TIME, 0.0, 1.0)
	grow = 1.0 - pow(1.0 - grow, 2.5)
	var fade := clampf((_age - GROW_TIME - HOLD_TIME) / FADE_TIME, 0.0, 1.0)
	return Vector3(grow, 1.0 - fade * fade, fade)


## Point `t` (0..1) along the tendril's center line. It snakes in a slow
## curve that relaxes a little once it reaches, pinned at both ends, and
## drifts upward as it frays away.
func _point(t: float) -> Vector2:
	var s := _state()
	var dir := _to - _from
	var normal := Vector2(-dir.y, dir.x).normalized()
	var slack := 1.0 - 0.5 * s.x
	var wave := sin(t * TAU * 1.1 + _phase - _age * 7.0) * _amplitude * slack
	wave += sin(t * TAU * 2.9 + _phase * 1.7 - _age * 5.0) * _amplitude * 0.3
	var bow := -absf(dir.x) * 0.05 * 4.0 * t * (1.0 - t)
	var drift := Vector2(0.0, -26.0 * s.z * sin(t * PI))
	return _from + dir * t + normal * wave * sin(t * PI) + Vector2(0.0, bow) + drift


func _points() -> PackedVector2Array:
	var reach := _state().x
	var pts := PackedVector2Array()
	for i in SEGMENTS + 1:
		pts.append(_point(float(i) / SEGMENTS * reach))
	return pts


## Width of the tendril at `k` (0 = caster, 1 = tip).
func _width(k: float) -> float:
	return lerpf(34.0, 7.0, pow(k, 0.8))


## Draws a soft ribbon through `centers` onto `canvas`: each point has its
## own half-width and color, the ribbon's edges fade to transparent, and
## neighboring pieces share their edges exactly - so nothing overlaps and
## no seams show where segments meet (as they would with draw_line).
static func _ribbon(canvas: CanvasItem, centers: PackedVector2Array, half_widths: PackedFloat32Array, colors: PackedColorArray) -> void:
	var n := centers.size()
	if n < 2:
		return
	var normals := PackedVector2Array()
	for i in n:
		var a := centers[maxi(i - 1, 0)]
		var b := centers[mini(i + 1, n - 1)]
		var d := b - a
		normals.append(d.orthogonal().normalized() if d.length() > 0.0001 else Vector2.UP)
	for i in n - 1:
		var c0 := colors[i]
		var c1 := colors[i + 1]
		var e0 := Color(c0, 0.0)
		var e1 := Color(c1, 0.0)
		var l0 := centers[i] + normals[i] * half_widths[i]
		var r0 := centers[i] - normals[i] * half_widths[i]
		var l1 := centers[i + 1] + normals[i + 1] * half_widths[i + 1]
		var r1 := centers[i + 1] - normals[i + 1] * half_widths[i + 1]
		# Two quads per piece: faded left edge -> solid middle -> faded right edge.
		canvas.draw_primitive(PackedVector2Array([l0, centers[i], centers[i + 1], l1]), PackedColorArray([e0, c0, c1, e1]), PackedVector2Array())
		canvas.draw_primitive(PackedVector2Array([centers[i], r0, r1, centers[i + 1]]), PackedColorArray([c0, e0, e1, c1]), PackedVector2Array())


func _draw_glow() -> void:
	var s := _state()
	if s.x <= 0.0:
		return
	var pts := _points()
	var widths := PackedFloat32Array()
	var colors := PackedColorArray()
	for i in pts.size():
		var k := float(i) / SEGMENTS
		# Faint pulses of light flowing out along it toward the target.
		var pulse := pow(0.5 + 0.5 * sin(k * 16.0 - _age * 24.0), 3.0)
		widths.append(_width(k) * (0.9 + 0.5 * s.z))
		colors.append(Color(GLOW, (0.12 + 0.14 * pulse) * s.y))
	_ribbon(_glow, pts, widths, colors)
	# A bloom where it strikes.
	if _hit_done and _age < GROW_TIME + HOLD_TIME + 0.1:
		var flash := 1.0 - clampf((_age - GROW_TIME) / (HOLD_TIME + 0.1), 0.0, 1.0)
		_glow.draw_circle(pts[pts.size() - 1], 10.0 + 16.0 * flash, Color(GLOW, 0.35 * flash))


func _draw_body() -> void:
	var s := _state()
	if s.x <= 0.0:
		return
	var pts := _points()
	# Soft strands twisting around the center line. As it frays, they
	# drift apart and thin out.
	for strand in STRANDS:
		var offset: float = _strand_offsets[strand]
		var speed: float = _strand_speeds[strand]
		var centers := PackedVector2Array()
		var widths := PackedFloat32Array()
		var colors := PackedColorArray()
		for i in pts.size():
			var k := float(i) / SEGMENTS
			var w := _width(k)
			var d := pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]
			var n := d.orthogonal().normalized() if d.length() > 0.0001 else Vector2.UP
			var twist := sin(k * 14.0 + offset - _age * speed)
			var spread := 0.3 + 0.9 * s.z
			centers.append(pts[i] + n * twist * w * spread)
			widths.append(w * 0.45 * (1.0 - 0.3 * s.z))
			# Patchy, like smoke: some stretches of each strand thin out.
			var patch := 0.5 + 0.5 * sin(k * 7.0 + offset * 2.3 - _age * 3.0)
			colors.append(Color(MIST, 0.3 * patch * s.y))
		_ribbon(_body, centers, widths, colors)
	# The pale core, fading first as it frays.
	var core_widths := PackedFloat32Array()
	var core_colors := PackedColorArray()
	var core_a := 0.4 * s.y * (1.0 - s.z)
	for i in pts.size():
		var k := float(i) / SEGMENTS
		core_widths.append(maxf(_width(k) * 0.12, 1.2))
		core_colors.append(Color(CORE, core_a * (1.0 - 0.6 * k)))
	_ribbon(_body, pts, core_widths, core_colors)
