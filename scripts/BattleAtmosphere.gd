extends Control
# ------------------------------------------------------------------
# BattleAtmosphere
# Purely visual layer for the battle area, drawn right over the
# Background and under the hero/creeps (battle.gd places it). Never
# takes input, never touches game state. battle.gd calls setup() with
# the zone id; effects only exist for zones that have them (currently
# the Elderwild and the Kingdom of Morvain) and nothing is drawn
# anywhere else.
#
# Elderwild:
#   - autumn leaves blown across the forest on a gusting wind, in two
#     depths: distant ones small, dim and hazy, nearer ones larger and
#     brighter - both behind the fighters
#
# Positions are kept in background-image UV (0..1) and mapped to the
# screen when drawn, so they follow the Background's "keep aspect
# covered" stretch at any screen size.
# ------------------------------------------------------------------

@export var background_path: NodePath = ^"../Background"

# Kingdom of Morvain runs in its own child node - see MorvainBattleAtmosphere.gd.
const MORVAIN_FX := preload("res://scripts/MorvainBattleAtmosphere.gd")

# Leaves live above the battle UI panel painted into the art.
const ELD_LEAF_FLOOR := 0.64          # image UV y where they've faded out
const ELD_LEAF_COLORS := [
	Color(0.9, 0.42, 0.12), Color(0.75, 0.2, 0.09), Color(0.95, 0.64, 0.2),
	Color(0.66, 0.36, 0.14), Color(0.6, 0.62, 0.2),
]
# Distant haze the far leaves fade toward (the pale mountain mist, so
# they still read against the dark pines).
const ELD_HAZE := Color(0.5, 0.55, 0.6)
# Per depth: how many at once, size (px at a 1536-wide image), speed
# multiplier, opacity, how much haze.
const ELD_LAYERS := [
	{"count": 34, "size": Vector2(4.0, 6.0), "speed": 0.55, "alpha": 0.7, "haze": 0.3},
	{"count": 22, "size": Vector2(8.0, 12.0), "speed": 1.0, "alpha": 0.95, "haze": 0.0},
]
# Wind, in image widths per second: a steady breeze plus gusts.
const ELD_WIND_BASE := 0.035
const ELD_WIND_GUST := 0.05

var _background: TextureRect
var _zone := ""
var _time := 0.0
var _rng := RandomNumberGenerator.new()
# Each leaf: layer index plus its own UV position, motion and look.
var _leaves: Array[Dictionary] = []
var _spawn_accum: Array[float] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_process(false)
	_rng.randomize()
	_background = get_node_or_null(background_path) as TextureRect


## Starts the effects for `zone_id` (or clears them for a zone that has
## none).
func setup(zone_id: String) -> void:
	_zone = ""
	_leaves.clear()
	set_process(false)
	queue_redraw()
	if _background == null or _background.texture == null:
		return
	if zone_id == "kingdom_of_morvain":
		# Morvain's effects live in their own script, as a child.
		_zone = zone_id
		var fx: Control = MORVAIN_FX.new()
		add_child(fx)
		fx.build(self, _background)
		return
	if zone_id == "the_elderwild":
		_zone = zone_id
		_spawn_accum.clear()
		for layer in ELD_LAYERS:
			_spawn_accum.append(0.0)
		# Pre-warm (longer than a far leaf takes to cross) so the battle
		# doesn't open on an empty sky.
		for i in 900:
			_update_leaves(1.0 / 30.0)
		set_process(true)


# --- helpers --------------------------------------------------------

## Maps a point in the background image (0..1) to local coordinates,
## matching the Background's "keep aspect covered" stretch.
func _image_to_local(uv: Vector2) -> Vector2:
	var tex_size := _background.texture.get_size()
	var rect_size := _background.size
	var s: float = max(rect_size.x / tex_size.x, rect_size.y / tex_size.y)
	var drawn := tex_size * s
	return _background.position - position + (rect_size - drawn) * 0.5 + uv * drawn

func _image_scale() -> float:
	var tex_size := _background.texture.get_size()
	var rect_size := _background.size
	return max(rect_size.x / tex_size.x, rect_size.y / tex_size.y)


func _process(delta: float) -> void:
	_time += delta
	_update_leaves(delta)
	queue_redraw()


# --- Elderwild leaves -----------------------------------------------

## 0..1: how hard the wind is gusting right now - two slow waves
## multiplied so gusts come and go irregularly.
func _gust() -> float:
	var g := (0.5 + 0.5 * sin(_time * 0.37)) * (0.5 + 0.5 * sin(_time * 0.23 + 1.3))
	return smoothstep(0.1, 0.8, g)


func _update_leaves(delta: float) -> void:
	var gust := _gust()
	var wind := ELD_WIND_BASE + ELD_WIND_GUST * gust
	var i := _leaves.size() - 1
	while i >= 0:
		var l: Dictionary = _leaves[i]
		var layer: Dictionary = ELD_LAYERS[l["layer"]]
		l["age"] += delta
		l["x"] += (wind * layer["speed"] + l["drift"]) * delta
		l["y"] += l["fall"] * layer["speed"] * delta
		# Gusts set them spinning faster.
		l["spin"] += l["spin_speed"] * (1.0 + 1.5 * gust) * delta
		if l["x"] > 1.05 or l["y"] > ELD_LEAF_FLOOR:
			_leaves.remove_at(i)
		i -= 1

	for li in ELD_LAYERS.size():
		var layer: Dictionary = ELD_LAYERS[li]
		# Roughly how long one takes to cross, so `count` stay on screen;
		# a gust brings a few more in.
		var crossing: float = 1.0 / ((ELD_WIND_BASE + ELD_WIND_GUST * 0.5) * layer["speed"])
		_spawn_accum[li] += delta * layer["count"] / crossing * (0.7 + 0.8 * gust)
		while _spawn_accum[li] >= 1.0:
			_spawn_accum[li] -= 1.0
			_leaves.append(_new_leaf(li))


func _new_leaf(layer_index: int) -> Dictionary:
	var layer: Dictionary = ELD_LAYERS[layer_index]
	# Mostly blown in from the left edge, some dropping from the canopy.
	var x: float
	var y: float
	if _rng.randf() < 0.6:
		x = -0.03
		y = _rng.randf_range(0.02, 0.5)
	else:
		x = _rng.randf_range(0.0, 0.9)
		y = -0.03
	var size_range: Vector2 = layer["size"]
	var col: Color = ELD_LEAF_COLORS[_rng.randi() % ELD_LEAF_COLORS.size()]
	return {
		"layer": layer_index,
		"x": x,
		"y": y,
		"drift": _rng.randf_range(-0.006, 0.01),
		"fall": _rng.randf_range(0.012, 0.03),
		"size": _rng.randf_range(size_range.x, size_range.y),
		"sway": _rng.randf_range(0.004, 0.012),
		"freq": _rng.randf_range(1.0, 2.2),
		"phase": _rng.randf() * TAU,
		"spin": _rng.randf() * TAU,
		"spin_speed": _rng.randf_range(1.5, 4.5) * (1.0 if _rng.randf() < 0.5 else -1.0),
		"color": col.lerp(ELD_HAZE, layer["haze"]),
		"age": 0.0,
	}


func _draw() -> void:
	if _zone != "the_elderwild" or _background == null or _background.texture == null:
		return
	var s := _image_scale() * _background.texture.get_size().x / 1536.0
	# Far layer first, so nearer leaves pass over it.
	for li in ELD_LAYERS.size():
		var layer: Dictionary = ELD_LAYERS[li]
		for l in _leaves:
			if l["layer"] != li:
				continue
			var age: float = l["age"]
			var y: float = l["y"] + sin(age * l["freq"] + l["phase"]) * l["sway"] * 0.5
			var x: float = l["x"] + cos(age * l["freq"] * 0.7 + l["phase"]) * l["sway"]
			var fade: float = smoothstep(0.0, 0.8, age) * (1.0 - smoothstep(ELD_LEAF_FLOOR - 0.08, ELD_LEAF_FLOOR, l["y"]))
			var a: float = layer["alpha"] * fade
			if a <= 0.0:
				continue
			_draw_leaf(_image_to_local(Vector2(x, y)), l["size"] * s, l["spin"], sin(age * l["freq"] + l["phase"]) * 0.6, Color(l["color"], a))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A pointed oval with a center vein, squashed by cos(spin) so it seems
## to tumble through the air.
func _draw_leaf(pos: Vector2, size: float, spin: float, tilt: float, col: Color) -> void:
	draw_set_transform(pos, spin * 0.35 + tilt, Vector2(1.0, maxf(absf(cos(spin)), 0.15)))
	var pts := PackedVector2Array([
		Vector2(-size, 0.0), Vector2(-size * 0.4, -size * 0.45), Vector2(size * 0.4, -size * 0.4),
		Vector2(size, 0.0), Vector2(size * 0.4, size * 0.4), Vector2(-size * 0.4, size * 0.45),
	])
	draw_colored_polygon(pts, col)
	draw_line(Vector2(-size, 0.0), Vector2(size, 0.0), Color(col.darkened(0.4), col.a * 0.8), 1.0)
