extends Node
# ------------------------------------------------------------------
# TutorialManager (autoload / singleton)
# Drives the scripted, forced-input walkthrough started from the
# "Tutorial" button on the How To Play screen (see HowToPlay.gd).
# Runs entirely against PlayerManager's tutorial sandbox (see
# PlayerManager.begin_tutorial_sandbox()) so recruiting a hero,
# spending gold, draining potions, etc. never touches the player's
# real save.
#
# Every scene that needs to force a specific action during the
# tutorial (Zone's skill buttons, Battle's move/attack/skill/item/flee
# buttons, Shop's buy buttons, ...) checks is_active and
# is_action_allowed() before acting on a click; TutorialManager itself
# doesn't know about any scene's buttons. Stage/step content lives in
# per-stage setup functions added in later tasks - this file currently
# only wires the framework and a placeholder stage 1 entry point.
# ------------------------------------------------------------------

var is_active: bool = false
var current_stage: int = 0
var current_step: int = 0

# When empty, every action is allowed (i.e. no forced-input gate is in
# effect). When non-empty, only these action ids may fire - scenes
# define their own id strings (e.g. "skill:torrent", "move:right",
# "flee", "buy:health_potion") and check is_action_allowed(id) before
# handling a click.
var _allowed_actions: Array = []

var _overlay: CanvasLayer = null

# GameManager.selected_zone isn't part of PlayerManager's sandboxed save
# data (see PlayerManager.begin_tutorial_sandbox()) - it's a separate
# autoload variable, so start_tutorial()/exit_tutorial() snapshot and
# restore it by hand instead.
var _pre_tutorial_selected_zone: String = ""


func _ready() -> void:
	var overlay_scene: PackedScene = load("res://scenes/TutorialOverlay.tscn")
	_overlay = overlay_scene.instantiate()
	add_child(_overlay)


## Entry point - called from the Tutorial button on HowToPlay.gd. Wipes
## any real recruited hero out of the SANDBOXED copy of the player's
## data (same wipe "New Game" uses) so Zone.tscn's hero picker actually
## shows Kunkka's recruitment screen instead of dropping straight into
## a real in-progress battle.
func start_tutorial() -> void:
	PlayerManager.begin_tutorial_sandbox()
	PlayerManager.clear_recruited_hero()

	_pre_tutorial_selected_zone = GameManager.selected_zone
	GameManager.select_zone("cladd_isles")

	is_active = true
	current_stage = 1
	current_step = 0
	_allowed_actions = []
	_overlay.set_exit_button_visible(true)

	show_popup(
		"Welcome to the tutorial!\n\nYou'll play through Kunkka's home zone, Cladd Isles, step by "
		+ "step - picking skills, using them in battle, and knowing when to flee and restock on "
		+ "potions.\n\nFirst up: recruit Kunkka and pick his starting skill.",
		func(): get_tree().change_scene_to_file("res://scenes/Zone.tscn")
	)


## Called when the player picks "Continue Tutorial" at stage 1's clear
## checkpoint (see battle.gd's "stage_cleared" case). Manufactures a
## fresh mid-run scenario - Kunkka at level 5, deep into Cladd Isles'
## hardest stage, critically low on HP/mana, no potions - rather than
## literally continuing stage 1's fight, since the point here is
## teaching when to retreat and restock, not more combat. Still runs
## entirely inside the same tutorial sandbox as stage 1.
const STAGE2_TARGET_LEVEL := 5
const STAGE2_LOW_HP_FRACTION := 0.1
const STAGE2_LOW_MANA_FRACTION := 0.05
# Exactly enough for one Health Potion (100 gold) and one Mana Potion
# (60 gold) - see GameManager.items - so the shop stage's gold alone
# already rules out affording anything else.
const STAGE2_GOLD := 160

func start_stage2() -> void:
	current_stage = 2
	current_step = 0

	var kunkka_static: Dictionary = GameManager.get_hero_by_id("kunkka")

	# Levels up for real through PlayerManager's own XP/growth curve
	# (rather than hand-picking level-5 stats) so this always matches
	# however leveling happens to be balanced - one level at a time, so
	# a partial level's worth of overflow XP already banked from stage 1
	# never over- or under-shoots the target level.
	while PlayerManager.get_level() < STAGE2_TARGET_LEVEL:
		var xp_needed: int = GameManager.get_xp_required_for_level(PlayerManager.get_level())
		PlayerManager.add_xp(xp_needed)
		PlayerManager.check_level_up(kunkka_static)

	_apply_low_hp_mana(STAGE2_LOW_HP_FRACTION, STAGE2_LOW_MANA_FRACTION)

	PlayerManager.add_gold(-PlayerManager.get_gold())
	PlayerManager.add_gold(STAGE2_GOLD)

	# recruit_hero() seeds every hero with one free Health Potion and one
	# Mana Potion (see PlayerManager.recruit_hero()) - strip those back
	# out so this scenario actually starts "without potions" as scripted,
	# rather than the shop stage secretly topping up an existing stack.
	# use_item() only removes the inventory entry; it doesn't apply the
	# heal/mana-restore effect, so this can't disturb the HP/mana values
	# just set above.
	PlayerManager.use_item("health")
	PlayerManager.use_item("mana")

	show_popup(
		"Second tutorial stage!\n\nThis time you're picking up mid-run: Kunkka's already level 5 and "
		+ "deep into Cladd Isles' toughest stage.",
		func(): get_tree().change_scene_to_file("res://scenes/Battle.tscn")
	)


## Shared by start_stage2()/start_stage3(): targets an exact HP/mana
## PERCENTAGE of the hero's current max rather than subtracting a fixed
## amount - current_hp/mana won't generally already be at 100% (prior
## combat chipped away at both), so a flat "subtract 90% of max" could
## easily overshoot past 0 instead of landing at the intended fraction.
func _apply_low_hp_mana(hp_fraction: float, mana_fraction: float) -> void:
	var recruited: Dictionary = PlayerManager.get_recruited_hero()
	var stats: Dictionary = recruited.get("stats", {})
	var max_hp: float = float(stats.get("hp", 0))
	var max_mana: float = float(stats.get("mana", 0))
	var current_hp: float = float(recruited.get("current_hp", 0))
	var current_mana: float = float(recruited.get("current_mana", 0))
	var target_hp: float = max_hp * hp_fraction
	var target_mana: float = max_mana * mana_fraction

	if current_hp > target_hp:
		PlayerManager.damage_hero(current_hp - target_hp)
	elif current_hp < target_hp:
		PlayerManager.heal_hero(target_hp - current_hp)

	if current_mana > target_mana:
		PlayerManager.use_mana(current_mana - target_mana)
	elif current_mana < target_mana:
		PlayerManager.restore_mana(target_mana - current_mana)


## Called when the player picks "Continue Tutorial" at stage 2's
## restock checkpoint (see Shop.gd's _tutorial_check_progress()). Same
## setup as stage 2 - level 5, critically low HP/mana, already in
## melee range on Cladd Isles' final stage - but this time the potions
## bought in stage 2 are still sitting in the sandboxed inventory, and
## XP is tuned so the very next melee kill lands exactly on level 6,
## unlocking Ghostship (see GameManager.ULTIMATE_SKILL_LEVEL_UNLOCKS).
## Stage 3's own script is longer than stage 2's (level up, a few more
## attacks, reinforcements, a failed then successful ultimate cast,
## mop-up) - a bit more starting HP than stage 2's razor-thin 10%
## keeps the whole sequence survivable against a real stage 3 enemy
## roster while still reading as "critically low" up front. Mana stays
## at stage 2's fraction - it's meant to run out again once Ghostship
## is learned, forcing the Mana Potion beat.
const STAGE3_LOW_HP_FRACTION := 0.4

func start_stage3() -> void:
	current_stage = 3
	current_step = 0

	_apply_low_hp_mana(STAGE3_LOW_HP_FRACTION, STAGE2_LOW_MANA_FRACTION)

	# Cladd Isles' melee creep's XP value, looked up rather than
	# hardcoded so this stays correct if the zone's numbers ever change.
	var zone_data: Dictionary = GameManager.get_zone("cladd_isles")
	var mele_xp: float = 0.0
	for enemy_def in zone_data.get("enemies", []):
		if enemy_def.get("type", "") != "range":
			mele_xp = float(enemy_def.get("XP", 0))
			break

	# Sets XP so it lands EXACTLY on level 5's own requirement once the
	# next melee kill's XP is added - one kill, one level up, as scripted.
	# Kunkka is already level 5 (set by start_stage2()), so this is
	# levels 5 -> 6's own requirement.
	var xp_required: int = GameManager.get_xp_required_for_level(STAGE2_TARGET_LEVEL)
	var current_xp: float = float(PlayerManager.get_recruited_hero().get("xp", 0))
	var target_xp_before_kill: float = float(xp_required) - mele_xp
	PlayerManager.add_xp(target_xp_before_kill - current_xp)

	show_popup(
		"Final tutorial stage!\n\nSame fight, same low resources - but this time you've got potions "
		+ "in reserve, and a level-up (with your ultimate right behind it) within easy reach.",
		func(): get_tree().change_scene_to_file("res://scenes/Battle.tscn")
	)


## Ends the tutorial from wherever it currently is (an explicit "Exit
## Tutorial" checkpoint, or finishing the last stage) and returns to
## How To Play. Always safe to call even if a stage left the player
## mid-battle/mid-shop - the sandbox restore means nothing there was
## ever real.
func exit_tutorial() -> void:
	PlayerManager.end_tutorial_sandbox()
	GameManager.selected_zone = _pre_tutorial_selected_zone

	is_active = false
	current_stage = 0
	current_step = 0
	_allowed_actions = []
	if _overlay:
		_overlay.hide_popup()
		_overlay.set_exit_button_visible(false)
	get_tree().change_scene_to_file("res://scenes/HowToPlay.tscn")


## Restricts input to exactly these action ids until the next call -
## pass [] to lift the restriction entirely.
func set_allowed_actions(actions: Array) -> void:
	_allowed_actions = actions


func is_action_allowed(action_id: String) -> bool:
	return not is_active or _allowed_actions.is_empty() or _allowed_actions.has(action_id)


## The current restriction list itself, for a caller that needs to know
## WHICH action(s) are forced right now rather than just checking one
## candidate at a time (see battle.gd's _tutorial_current_forced_
## button()). A copy, not the live array - callers can't accidentally
## mutate tutorial state through it.
func get_allowed_actions() -> Array:
	return _allowed_actions.duplicate()


## Single-button explanatory pop-up.
func show_popup(text: String, on_continue: Callable = Callable(), continue_label: String = "Continue") -> void:
	_overlay.show_message(text, continue_label, on_continue)


## Two-button "continue to the next stage, or stop here" checkpoint.
func show_checkpoint(text: String, on_continue: Callable) -> void:
	_overlay.show_choice(text, "Continue Tutorial", "Exit Tutorial", on_continue, exit_tutorial)


# ------------------------------------------------------------------
# Shared "glow" treatment for whichever button the tutorial currently
# wants the player to click - same warm pulsing look as How To Play's
# own Tutorial button (see HowToPlay.gd), reused everywhere else so a
# forced button is never just "the one that happens to be enabled."
# Callers own the style/tween they get back: apply the style via
# add_theme_stylebox_override("normal"/"hover", style), start the pulse
# with THEIR OWN node (so the tween's lifetime is tied to it, not this
# always-alive autoload), and when that button stops being forced,
# button.remove_theme_stylebox_override(...) + tween.kill().
# ------------------------------------------------------------------

func make_glow_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.35, 0.24, 0.05, 0.95)
	style.border_color = Color(1, 0.85, 0.3, 1)
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(1, 0.8, 0.2, 0.55)
	style.shadow_size = 10
	return style


## Starts the breathing pulse on `style`'s own shadow_size, forever,
## bound to `owner_node`'s tree lifetime (created via its own
## create_tween() - Godot kills a node-bound tween automatically once
## that node leaves the tree, so callers whose button lives and dies
## with a whole scene don't need to track and kill it by hand).
func start_glow_pulse(style: StyleBoxFlat, owner_node: Node) -> Tween:
	var tween := owner_node.create_tween()
	tween.set_loops()
	tween.tween_property(style, "shadow_size", 20, 1.1).set_trans(Tween.TRANS_SINE)
	tween.tween_property(style, "shadow_size", 8, 1.1).set_trans(Tween.TRANS_SINE)
	return tween
