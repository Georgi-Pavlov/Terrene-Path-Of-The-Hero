class_name CreatureAnimator
extends Node

## Makes a static creature portrait (a battle TextureRect) feel alive:
## idle breathing/sway/ripple plus attack, hit, cast, move and death
## reactions. Everything runs through creature_anim.gdshader's uniforms,
## never the node's own position/scale/modulate - battle.gd already
## tweens those for its own lunges, pulses and hit flashes, and this
## must stack on top of them instead of fighting them.
##
## Added as a child of the TextureRect it animates (so it's freed along
## with it). Look one up with CreatureAnimator.of(node); every play_*
## call site in battle.gd goes through that, so creatures without an
## animator are simply skipped.

const SHADER := preload("res://shaders/creature_anim.gdshader")

## Per-creature idle tuning. Any key left out falls back to the
## shader's own default.
const PROFILES := {
	"veyrik": {
		"breath_amount": 0.014, "breath_speed": 1.5,
		"sway_amount": 0.012, "sway_speed": 0.7,
		"ripple_amount": 0.0035, "ripple_freq": 8.0, "ripple_speed": 1.6,
		"glow_color": Color(0.35, 0.95, 0.85),
		"edge_color": Color(0.3, 1.0, 0.85),
	},
	"iron_abyss_melee": {
		"breath_amount": 0.02, "breath_speed": 1.9,
		"sway_amount": 0.008, "sway_speed": 1.0,
		"ripple_amount": 0.003, "ripple_freq": 10.0, "ripple_speed": 2.0,
		"glow_color": Color(0.3, 0.8, 1.0),
		"edge_color": Color(0.25, 0.85, 1.0),
	},
	"iron_abyss_range": {
		"breath_amount": 0.012, "breath_speed": 1.3,
		"sway_amount": 0.016, "sway_speed": 0.6,
		"ripple_amount": 0.004, "ripple_freq": 7.0, "ripple_speed": 1.4,
		"glow_color": Color(0.55, 0.6, 1.0),
		"edge_color": Color(0.5, 0.7, 1.0),
	},
	# Elderwild - on dry land, so no underwater ripple; instead a slow
	# sway, like cloaks and fur stirring in a forest breeze. Erynd's True
	# Form reuses his own profile (same node, swapped art).
	"erynd": {
		"breath_amount": 0.013, "breath_speed": 1.4,
		"sway_amount": 0.011, "sway_speed": 0.55,
		"ripple_amount": 0.0,
		"glow_color": Color(0.45, 1.0, 0.45),
		"edge_color": Color(0.55, 1.0, 0.4),
	},
	"spirit_bear": {
		"breath_amount": 0.022, "breath_speed": 1.15,
		"sway_amount": 0.005, "sway_speed": 0.5,
		"ripple_amount": 0.0,
		"glow_color": Color(0.9, 0.8, 0.35),
		"edge_color": Color(0.95, 0.85, 0.4),
	},
	"elderwild_melee": {
		"breath_amount": 0.02, "breath_speed": 2.0,
		"sway_amount": 0.009, "sway_speed": 0.9,
		"ripple_amount": 0.0,
		"glow_color": Color(0.8, 0.9, 0.3),
		"edge_color": Color(0.6, 0.9, 0.3),
	},
	"elderwild_range": {
		"breath_amount": 0.016, "breath_speed": 1.7,
		"sway_amount": 0.006, "sway_speed": 0.7,
		"ripple_amount": 0.0,
		"glow_color": Color(0.7, 0.85, 0.35),
		"edge_color": Color(0.65, 0.9, 0.35),
	},
	# Kingdom of Morvain - wraiths made half of mist, so a slow, low
	# ripple keeps them wavering like something seen through fog, and
	# they drift more than they breathe.
	"morvael": {
		"breath_amount": 0.012, "breath_speed": 1.1,
		"sway_amount": 0.012, "sway_speed": 0.45,
		"ripple_amount": 0.003, "ripple_freq": 6.0, "ripple_speed": 1.1,
		"glow_color": Color(0.35, 1.0, 0.9),
		"edge_color": Color(0.4, 1.0, 0.92),
	},
	"morvain_melee": {
		"breath_amount": 0.016, "breath_speed": 1.6,
		"sway_amount": 0.014, "sway_speed": 0.7,
		"ripple_amount": 0.0035, "ripple_freq": 7.0, "ripple_speed": 1.4,
		"glow_color": Color(0.3, 0.95, 0.9),
		"edge_color": Color(0.35, 1.0, 0.9),
	},
	"morvain_range": {
		"breath_amount": 0.012, "breath_speed": 1.2,
		"sway_amount": 0.016, "sway_speed": 0.5,
		"ripple_amount": 0.004, "ripple_freq": 6.0, "ripple_speed": 1.2,
		"glow_color": Color(0.35, 1.0, 0.95),
		"edge_color": Color(0.4, 1.0, 0.95),
	},
}

const HIT_FLASH_COLOR := Color(1.0, 0.35, 0.3)
const LUNGE_DISTANCE := 34.0
const MOVE_HOP_HEIGHT := 18.0
const MOVE_DURATION := 0.24
const DEATH_DURATION := 0.75
const DEATH_GHOST_GROUP := "creature_death_ghost"

var profile_id: String = ""
var _target: TextureRect
var _mat: ShaderMaterial
var _profile: Dictionary = {}
var _action_tween: Tween
var _move_tween: Tween
var _move_from_x: float = 0.0


## Attaches an animator to `node` using PROFILES[profile_id] and returns
## it. Speeds are jittered slightly and the phase randomized, so several
## copies of the same creep never breathe in lockstep.
static func attach(node: TextureRect, p_profile_id: String) -> CreatureAnimator:
	var existing := of(node)
	if existing != null:
		return existing
	var animator := CreatureAnimator.new()
	animator.name = "CreatureAnimator"
	animator.profile_id = p_profile_id
	animator._setup(node)
	node.add_child(animator)
	return animator


static func of(node: Variant) -> CreatureAnimator:
	if node == null or not is_instance_valid(node) or not (node is Node):
		return null
	return (node as Node).get_node_or_null("CreatureAnimator") as CreatureAnimator


func _setup(node: TextureRect) -> void:
	_target = node
	_profile = PROFILES.get(profile_id, {})
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_target.material = _mat

	_mat.set_shader_parameter("time_offset", randf() * 100.0)
	# Tweens can only target parameters that have been set at least once.
	_mat.set_shader_parameter("move_offset", Vector2.ZERO)
	_mat.set_shader_parameter("dissolve", 0.0)
	var jitter := randf_range(0.88, 1.12)
	for key in ["breath_amount", "sway_amount", "ripple_amount", "ripple_freq"]:
		if _profile.has(key):
			_mat.set_shader_parameter(key, _profile[key])
	for key in ["breath_speed", "sway_speed", "ripple_speed"]:
		if _profile.has(key):
			_mat.set_shader_parameter(key, float(_profile[key]) * jitter)
	_mat.set_shader_parameter("glow_color", _profile.get("glow_color", Color(0.4, 0.9, 1.0)))
	_mat.set_shader_parameter("dissolve_edge_color", _profile.get("edge_color", Color(0.3, 0.9, 1.0)))

	_sync_rect_size()
	_target.resized.connect(_sync_rect_size)


func _sync_rect_size() -> void:
	_mat.set_shader_parameter("rect_size", _target.size)


func _param(name: String) -> String:
	return "shader_parameter/" + name


## Kills whatever attack/hit/cast is still playing and returns a fresh
## tween for the next one, starting from a neutral pose so a new action
## never inherits a half-finished lean or squash.
func _new_action_tween() -> Tween:
	if _action_tween != null and _action_tween.is_valid():
		_action_tween.kill()
	_mat.set_shader_parameter("action_offset", Vector2.ZERO)
	_mat.set_shader_parameter("squash", Vector2.ONE)
	_mat.set_shader_parameter("lean", 0.0)
	_mat.set_shader_parameter("flash_amount", 0.0)
	_mat.set_shader_parameter("glow_amount", 0.0)
	_action_tween = create_tween()
	return _action_tween


## Wind-up, strike, recover. `direction` is +1 for right, -1 for left.
## `lunge` adds a forward dash - off for creeps, whose battle.gd
## attack already shifts the node itself (_play_enemy_attack_lunge()).
func play_attack(direction: float, lunge: bool = true) -> void:
	var t := _new_action_tween()
	var dash := Vector2(direction * (LUNGE_DISTANCE if lunge else 6.0), 0.0)
	# Wind-up: lean back and crouch.
	t.tween_property(_mat, _param("lean"), -direction * 0.05, 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_mat, _param("squash"), Vector2(1.06, 0.93), 0.1)
	t.parallel().tween_property(_mat, _param("action_offset"), -dash * 0.2, 0.1)
	# Strike: snap forward and stretch.
	t.tween_property(_mat, _param("lean"), direction * 0.07, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(_mat, _param("squash"), Vector2(0.94, 1.06), 0.07)
	t.parallel().tween_property(_mat, _param("action_offset"), dash, 0.07)
	# Recover.
	t.tween_property(_mat, _param("lean"), 0.0, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_mat, _param("squash"), Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_mat, _param("action_offset"), Vector2.ZERO, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## Flinch: red-white flash, a knockback away from `from_direction`
## (the side the hit came from; 0 = unknown, just shudder) and a squash.
func play_hit(from_direction: float = 0.0) -> void:
	var t := _new_action_tween()
	_mat.set_shader_parameter("flash_color", HIT_FLASH_COLOR)
	var knock := Vector2(-from_direction * 12.0, 0.0)
	_mat.set_shader_parameter("flash_amount", 0.7)
	_mat.set_shader_parameter("squash", Vector2(1.07, 0.92))
	_mat.set_shader_parameter("lean", -from_direction * 0.04)
	_mat.set_shader_parameter("action_offset", knock)
	t.tween_property(_mat, _param("flash_amount"), 0.0, 0.3)
	t.parallel().tween_property(_mat, _param("squash"), Vector2.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_mat, _param("lean"), 0.0, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	# A couple of shrinking shudders on the way back to center.
	var sub := create_tween()
	sub.tween_property(_mat, _param("action_offset"), Vector2(-knock.x * 0.4 + 4.0, 0.0), 0.05)
	sub.tween_property(_mat, _param("action_offset"), Vector2(knock.x * 0.2 - 2.0, 0.0), 0.05)
	sub.tween_property(_mat, _param("action_offset"), Vector2.ZERO, 0.08)
	t.parallel().tween_subtween(sub)


## Gathers power: rises and stretches while glowing in the profile's
## color, then settles back down.
func play_cast() -> void:
	var t := _new_action_tween()
	t.tween_property(_mat, _param("squash"), Vector2(0.95, 1.07), 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_mat, _param("action_offset"), Vector2(0.0, -10.0), 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_mat, _param("glow_amount"), 0.22, 0.18)
	t.tween_property(_mat, _param("squash"), Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_mat, _param("action_offset"), Vector2.ZERO, 0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_mat, _param("glow_amount"), 0.0, 0.45)


## battle.gd snaps nodes straight to their new column; this slides the
## art in from where it was (`from_delta_x` = old x - new x, in pixels)
## along a small hop arc, then lands with a squash.
func play_move(from_delta_x: float) -> void:
	if _move_tween != null and _move_tween.is_valid():
		_move_tween.kill()
	_move_from_x = from_delta_x
	_set_move_progress(0.0)
	_move_tween = create_tween()
	_move_tween.tween_method(_set_move_progress, 0.0, 1.0, MOVE_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Landing squash, only if nothing more important is playing.
	if _action_tween == null or not _action_tween.is_running():
		var t := _new_action_tween()
		t.tween_interval(MOVE_DURATION - 0.04)
		t.tween_property(_mat, _param("squash"), Vector2(1.08, 0.92), 0.05)
		t.tween_property(_mat, _param("squash"), Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _set_move_progress(p: float) -> void:
	var arc := 4.0 * p * (1.0 - p)
	_mat.set_shader_parameter("move_offset", Vector2(_move_from_x * (1.0 - p), -MOVE_HOP_HEIGHT * arc))


## Flash, then burn away from the top down. With `free_node` the target
## is freed at the end; the hero's own portrait passes false and just
## stays dissolved behind the defeat popup.
func play_death(free_node: bool = true) -> void:
	var t := _new_action_tween()
	_mat.set_shader_parameter("flash_color", Color(1.0, 1.0, 1.0))
	_mat.set_shader_parameter("flash_amount", 0.8)
	_mat.set_shader_parameter("squash", Vector2(1.08, 0.92))
	t.tween_property(_mat, _param("flash_amount"), 0.0, 0.25)
	t.parallel().tween_property(_mat, _param("squash"), Vector2.ONE, 0.25)
	t.parallel().tween_property(_mat, _param("dissolve"), 1.0, DEATH_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(_mat, _param("action_offset"), Vector2(0.0, -14.0), DEATH_DURATION)
	if free_node:
		t.finished.connect(_target.queue_free)


## Clears a death dissolve (e.g. the hero's portrait being reused).
func reset_pose() -> void:
	_new_action_tween().kill()
	_mat.set_shader_parameter("dissolve", 0.0)


## Enemies are freed the moment they die (battle.gd's _kill_enemy()),
## which would cut the death animation off. This leaves a purely
## cosmetic copy of `node` in its place to play it instead - no hitbox,
## no gameplay references - so the real node can be freed on schedule.
##
## `layer` is where the copy goes (default: next to `node`). Pass a node
## that outlives the enemy layer being cleared on a stage change, or the
## last kill of a stage is freed along with it before it can play.
## Ghosts join DEATH_GHOST_GROUP while they play, so a scene change can
## wait for them.
static func spawn_death_ghost(node: TextureRect, layer: Node = null) -> void:
	var source := of(node)
	if source == null or node.get_parent() == null:
		return
	if layer == null:
		layer = node.get_parent()
	var ghost := TextureRect.new()
	ghost.texture = node.texture
	ghost.expand_mode = node.expand_mode
	ghost.stretch_mode = node.stretch_mode
	ghost.flip_h = node.flip_h
	ghost.size = node.size
	ghost.scale = node.get_meta("base_scale", Vector2.ONE)
	ghost.pivot_offset = node.pivot_offset
	ghost.modulate = Color(1, 1, 1, node.modulate.a)
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.add_to_group(DEATH_GHOST_GROUP)
	layer.add_child(ghost)
	ghost.global_position = node.global_position
	var animator := attach(ghost, source.profile_id)
	animator._mat.set_shader_parameter("time_offset", source._mat.get_shader_parameter("time_offset"))
	animator.play_death(true)
