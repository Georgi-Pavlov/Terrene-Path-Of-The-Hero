extends Control

@onready var background: TextureRect = $Background
@onready var hero_image: TextureRect = $HeroImage
@onready var enemies_layer: Control = $EnemiesLayer
@onready var hp_bar: ProgressBar = $BarsBox/HPRow/HPBar
@onready var hp_value_label: Label = $BarsBox/HPRow/HPBar/HPValueLabel
@onready var mana_bar: ProgressBar = $BarsBox/ManaRow/ManaBar
@onready var mana_value_label: Label = $BarsBox/ManaRow/ManaBar/ManaValueLabel
@onready var xp_bar: ProgressBar = $BarsBox/XPRow/XPBar
@onready var skill_buttons_container: HBoxContainer = $SkillsPanel/SkillsMargin/SkillButtons
@onready var items_grid: GridContainer = $ItemsPanel/ItemsMargin/ItemsVBox/ItemsGrid
@onready var gold_value_label: Label = $ItemsPanel/ItemsMargin/ItemsVBox/GoldRow/GoldValueLabel
@onready var move_left_button: Button = $ActionsPanel/MoveRow/MoveLeftButton
@onready var move_right_button: Button = $ActionsPanel/MoveRow/MoveRightButton
@onready var attack_button: Button = $ActionsPanel/AttackButton
@onready var end_turn_button: Button = $ActionsPanel/EndTurnButton
@onready var flee_button: Button = $FleeButton
@onready var defeat_popup: PanelContainer = $DefeatPopup
@onready var defeat_ok_button: Button = $DefeatPopup/DefeatMargin/DefeatVBox/DefeatOkButton
@onready var level_up_popup: PanelContainer = $LevelUpPopup
@onready var level_up_level_label: Label = $LevelUpPopup/LevelUpMargin/LevelUpVBox/LevelUpLevelLabel
@onready var level_up_ok_button: Button = $LevelUpPopup/LevelUpMargin/LevelUpVBox/LevelUpOkButton
@onready var level_up_strength_old: Label = $LevelUpPopup/LevelUpMargin/LevelUpVBox/StatsGrid/StrengthOld
@onready var level_up_strength_new: Label = $LevelUpPopup/LevelUpMargin/LevelUpVBox/StatsGrid/StrengthNew
@onready var level_up_agility_old: Label = $LevelUpPopup/LevelUpMargin/LevelUpVBox/StatsGrid/AgilityOld
@onready var level_up_agility_new: Label = $LevelUpPopup/LevelUpMargin/LevelUpVBox/StatsGrid/AgilityNew
@onready var level_up_intelligence_old: Label = $LevelUpPopup/LevelUpMargin/LevelUpVBox/StatsGrid/IntelligenceOld
@onready var level_up_intelligence_new: Label = $LevelUpPopup/LevelUpMargin/LevelUpVBox/StatsGrid/IntelligenceNew
@onready var level_up_hp_old: Label = $LevelUpPopup/LevelUpMargin/LevelUpVBox/StatsGrid/HPOld
@onready var level_up_hp_new: Label = $LevelUpPopup/LevelUpMargin/LevelUpVBox/StatsGrid/HPNew
@onready var level_up_mana_old: Label = $LevelUpPopup/LevelUpMargin/LevelUpVBox/StatsGrid/ManaOld
@onready var level_up_mana_new: Label = $LevelUpPopup/LevelUpMargin/LevelUpVBox/StatsGrid/ManaNew
@onready var level_up_damage_old: Label = $LevelUpPopup/LevelUpMargin/LevelUpVBox/StatsGrid/DamageOld
@onready var level_up_damage_new: Label = $LevelUpPopup/LevelUpMargin/LevelUpVBox/StatsGrid/DamageNew
@onready var skill_choice_popup: PanelContainer = $SkillChoicePopup
@onready var skill_choice_points_label: Label = $SkillChoicePopup/SkillChoiceMargin/SkillChoiceVBox/SkillChoicePointsLabel
@onready var skill_choice_options: VBoxContainer = $SkillChoicePopup/SkillChoiceMargin/SkillChoiceVBox/SkillChoiceOptions
@onready var stage_label: Label = $StagePanel/StageMargin/StageLabel

# The battlefield is divided into 10 columns. Movement shifts by one
# column (1/10 screen width); "same space" for attacks/melee means
# matching column index.
const GRID_COLUMNS := 10

var _hero_static: Dictionary = {}   # full definition from GameManager (stats, skills, image)
var _recruited: Dictionary = {}     # saved state from PlayerManager (current hp/mana/xp, chosen skill)

var _hero_pos_index: int = 1

# Each entry: {static, current_hp, pos_index, node}
var _enemies: Array = []

# Turn state: exactly one action - move, attack, skill, or item - per
# turn, then End Turn.
var _has_acted_this_turn: bool = false
var _battle_over: bool = false

# skill_id -> that skill's Button, for every LEARNED skill (level > 0).
# _update_action_buttons() toggles all of them with the turn; unlearned
# skills' buttons stay permanently disabled and aren't tracked here.
var _skill_buttons: Dictionary = {}

# skill_id -> turns remaining before it can be used again (0 = ready).
# Ticks down once per End Turn - see _tick_skill_cooldowns().
var _skill_cooldowns: Dictionary = {}
# skill_id -> the Label under that skill's button showing "Ready" or
# "N turns left".
var _skill_cooldown_labels: Dictionary = {}

# Ranged-hero target selection: when true, the enemies in
# _valid_targets are highlighted and clickable; clicking one resolves
# the attack.
var _targeting_mode: bool = false
var _valid_targets: Array = []

const RANGE_ENEMY_ATTACK_RANGE := 3
const RANGE_ENEMY_FLEE_DISTANCE := 1

# Reinforcements: if the hero hasn't cleared every enemy within this
# many End Turns, one melee and one ranged enemy (picked from the
# zone's own enemy roster) join the fight. Resets naturally every
# REINFORCEMENT_INTERVAL turns via the modulo check in
# _on_end_turn_pressed(), so it can trigger more than once in a long fight.
const REINFORCEMENT_INTERVAL := 20
var _turn_count: int = 0

# Which of the zone's up-to-GameManager.MAX_ZONE_STAGE waves this
# battle is currently on. Starts at whatever PlayerManager.
# get_zone_start_stage() says (1, unless this zone's already been
# fully cleared, in which case straight to the final stage every
# time). Clearing every enemy in a non-final stage reloads the next
# stage's enemies in this same scene instance - see _handle_victory()
# and _advance_to_next_stage() - rather than returning to the Map.
var _current_stage: int = 1

# True while fighting a post-stage-3 rival hero instead of the zone's
# regular creeps - see _try_start_hero_fight()/_start_hero_fight().
# _current_stage stays at MAX_ZONE_STAGE throughout, so code that
# needs to know "are we in the normal stage progression or a hero
# fight" should check this rather than _current_stage.
var _in_hero_fight: bool = false

# Which hero id is being fought, so _handle_victory() knows who to
# mark defeated via PlayerManager.mark_hero_defeated() when it's won.
var _hero_fight_target_id: String = ""

# Bumped every time _advance_to_next_stage() runs. Action handlers
# that might kill the last enemy of a stage (attack, Pounce, Dark
# Pact) capture this before acting and check it again after - if it
# changed, a stage transition already reset the turn state (fresh
# actions, only skill cooldowns carried over) and they must NOT then
# overwrite that by unconditionally marking the turn as used.
var _stage_generation: int = 0



func _ready() -> void:
	flee_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/Map.tscn"))
	defeat_ok_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/PostLogin.tscn"))
	move_left_button.pressed.connect(_on_move_left_pressed)
	move_right_button.pressed.connect(_on_move_right_pressed)
	attack_button.pressed.connect(_on_attack_pressed)
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	level_up_ok_button.pressed.connect(_on_level_up_continue_pressed)

	_recruited = PlayerManager.get_recruited_hero()
	if _recruited.is_empty():
		print("ERROR: No recruited hero found - accept a hero in a zone first.")
		return

	_hero_static = GameManager.get_hero_by_id(_recruited["id"])
	_current_stage = PlayerManager.get_zone_start_stage(GameManager.selected_zone)

	# Every player battle attempt (not just full zone clears - fleeing
	# after a partial clear still counts) also ticks the background
	# simulation for every other hero in the game, so their world
	# keeps progressing whether or not the player's own runs finish.
	# See EnemyHeroManager.tick_all_npc_heroes().
	EnemyHeroManager.tick_all_npc_heroes(_recruited["id"])

	_load_battle_background()
	_load_hero_image()
	_build_bar_styles()
	_refresh_bars()
	_populate_skill_buttons()
	_populate_item_grid()
	_refresh_gold_label()
	_load_enemies()
	_update_stage_label()
	_update_action_buttons()


func _load_battle_background() -> void:
	var zone_data: Dictionary = GameManager.get_selected_zone()
	var battle_bg_path: String = zone_data.get("battle_background", "")
	if battle_bg_path != "" and ResourceLoader.exists(battle_bg_path):
		background.texture = load(battle_bg_path)
	else:
		print("No battle_background set for the current zone - using fallback color.")


func _grid_unit() -> float:
	return get_viewport_rect().size.x / float(GRID_COLUMNS)


func _index_to_x(index: int) -> float:
	return index * _grid_unit()


func _creature_y() -> float:
	var target_height: float = get_viewport_rect().size.y / 4.0
	return (get_viewport_rect().size.y - target_height) / 2.0


## Shortest distance between two columns, accounting for the fact
## that moving off one edge wraps to the other.
func _distance(a: int, b: int) -> int:
	return absi(a - b)


## Fraction of incoming damage an armor value blocks, on a 0-1 scale
## (e.g. armor 5 -> ~0.23, meaning 23% reduced). Approaches but never
## reaches 1, so damage can be mitigated heavily but never nullified.
func _damage_reduction(armor: float) -> float:
	return (0.06 * armor) / (1.0 + 0.06 * armor)


## Applies an armor value's damage reduction to a raw damage amount.
## Negative armor increases damage taken instead of reducing it.
## Result is clamped to 0 so negative armor can't flip a hit into a heal.
func _apply_armor_reduction(raw_damage: float, armor: float) -> float:
	var reduction: float = _damage_reduction(armor)
	return maxf(0.0, raw_damage * (1.0 - reduction))


## Hero's total armor: base stat from GameManager plus any permanent
## bonus picked up from items (mirrors how damage bonus is combined
## in _roll_hero_damage).
func _hero_armor() -> float:
	var stats: Dictionary = _recruited.get("stats", {})
	return float(stats.get("armor", 0))


## Which direction (+1 or -1) is the shorter path from `from` to `to`,
## going around the wraparound board rather than always picking the
## raw lower/higher index.
func _step_toward(from: int, to: int) -> int:
	if from < to:
		return 1
	elif from > to:
		return -1

	return 0


func _load_hero_image() -> void:
	var image_path: String = _hero_static.get("image", "")
	if image_path == "" or not ResourceLoader.exists(image_path):
		print("No hero image found at: ", image_path)
		return

	var texture: Texture2D = load(image_path)
	hero_image.texture = texture

	# Scale so the hero's height is exactly 1/4 of the screen, keeping
	# the image's original aspect ratio for the width.
	var target_height: float = get_viewport_rect().size.y / 4.0
	var tex_size: Vector2 = texture.get_size()
	var scale_factor: float = target_height / tex_size.y
	var target_width: float = tex_size.x * scale_factor

	hero_image.size = Vector2(target_width, target_height)
	_update_hero_position()


func _update_hero_position() -> void:
	hero_image.position = Vector2(_index_to_x(_hero_pos_index), _creature_y())
	

## Spawns the current stage's enemies: GameManager.STAGE_ENEMY_COUNTS
## says how many melee/ranged enemies this stage has, cycling through
## the zone's own melee/ranged templates if it needs more than the
## zone defines (e.g. 5 melee out of only 2 distinct templates just
## repeats them). Each spawned enemy gets its own stage-adjusted stats
## via _build_stage_enemy_def() - the zone's template dictionaries
## themselves are never modified.
func _load_enemies() -> void:
	for child in enemies_layer.get_children():
		child.queue_free()
	_enemies.clear()

	var zone_data: Dictionary = GameManager.get_selected_zone()
	var enemy_defs: Array = zone_data.get("enemies", [])

	var mele_templates: Array = []
	var range_templates: Array = []
	for enemy_def in enemy_defs:
		if enemy_def.get("type", "") == "range":
			range_templates.append(enemy_def)
		else:
			mele_templates.append(enemy_def)

	var counts: Dictionary = GameManager.get_stage_enemy_counts(_current_stage)
	_spawn_stage_enemies(mele_templates, int(counts.get("mele", 0)))
	_spawn_stage_enemies(range_templates, int(counts.get("range", 0)))


func _spawn_stage_enemies(templates: Array, count: int) -> void:
	if templates.is_empty():
		return
	for i in range(count):
		var template: Dictionary = templates[i % templates.size()]
		_spawn_enemy(_build_stage_enemy_def(template, _current_stage))


## Returns a copy of `base_def` with this stage's hp/damage/gold
## bonuses baked in - both are cumulative across stages (see
## GameManager.get_stage_stat_bonus / get_stage_cumulative_gold_bonus),
## each stage adding its own increment on top of whatever the
## previous stage already added, not a flat total over the base value.
func _build_stage_enemy_def(base_def: Dictionary, stage: int) -> Dictionary:
	if stage <= 1:
		return base_def

	var staged: Dictionary = base_def.duplicate()
	var stat_bonus: Dictionary = GameManager.get_stage_stat_bonus(stage)
	staged["hp"] = float(base_def.get("hp", 0)) + float(stat_bonus.get("hp", 0))
	staged["damage"] = float(base_def.get("damage", 0)) + float(stat_bonus.get("damage", 0))

	var gold_bonus: int = GameManager.get_stage_cumulative_gold_bonus(stage)
	if gold_bonus != 0:
		var gold_parts: PackedStringArray = str(base_def.get("gold", "0-0")).split("-")
		var gold_min: float = float(gold_parts[0]) if gold_parts.size() > 0 else 0.0
		var gold_max: float = float(gold_parts[1]) if gold_parts.size() > 1 else gold_min
		staged["gold"] = "%d-%d" % [int(gold_min + gold_bonus), int(gold_max + gold_bonus)]

	return staged


## Creates one enemy (image, position, hitbox) from a definition and
## adds it to `_enemies`. Used both for the zone's starting roster and
## for reinforcements later. Melee enemies stack at column 7, ranged
## at column 8, offset visually so same-column enemies don't render
## exactly on top of each other - the offset is based on how many
## enemies of that type are already on the field, so this works
## whether it's the initial load or a reinforcement arriving mid-fight.
func _spawn_enemy(enemy_def: Dictionary) -> void:
	var image_path: String = enemy_def.get("image", "")
	if image_path == "" or not ResourceLoader.exists(image_path):
		print("No enemy image found at: ", image_path)
		return

	var target_height: float = get_viewport_rect().size.y / 4.0
	var y_pos: float = _creature_y()

	var texture: Texture2D = load(image_path)
	var tex_size: Vector2 = texture.get_size()
	var scale_factor: float = target_height / tex_size.y
	var target_width: float = tex_size.x * scale_factor

	var tex_rect := TextureRect.new()
	tex_rect.texture = texture
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	tex_rect.size = Vector2(target_width, target_height)
	tex_rect.mouse_filter = Control.MOUSE_FILTER_STOP

	# Hero art is drawn facing right (toward the enemy side, where the
	# player's own hero always stands) - a hero fight puts that same
	# art on the enemy side instead, facing the player's hero, so it
	# needs to be mirrored to face left. Regular creep art is already
	# drawn facing left and is untouched.
	tex_rect.flip_h = enemy_def.get("is_hero_fight", false)

	var enemy_type: String = enemy_def.get("type", "")
	var pos_index: int
	var visual_offset: float

	if enemy_type == "range":
		pos_index = 8
		visual_offset = _enemy_count_of_type("range") * 16.0
	else:
		pos_index = 7
		visual_offset = _enemy_count_of_type("mele") * 16.0

	tex_rect.position = Vector2(_index_to_x(pos_index) + visual_offset, y_pos)

	enemies_layer.add_child(tex_rect)

	var enemy_data := {
		"static": enemy_def,
		"current_hp": float(enemy_def.get("hp", 1)),
		"pos_index": pos_index,
		"node": tex_rect,
	}
	_enemies.append(enemy_data)

	tex_rect.gui_input.connect(_on_enemy_gui_input.bind(enemy_data))


func _enemy_count_of_type(type: String) -> int:
	var count := 0
	for enemy in _enemies:
		if enemy["static"].get("type", "") == type:
			count += 1
	return count


## Called every REINFORCEMENT_INTERVAL turns the fight is still going.
## Picks one random "mele" and one random "range" definition from the
## current zone's own enemy roster (whatever's missing is just
## skipped) and spawns them.
func _spawn_reinforcements() -> void:
	var zone_data: Dictionary = GameManager.get_selected_zone()
	var enemy_defs: Array = zone_data.get("enemies", [])

	var mele_def: Dictionary = _pick_random_enemy_def(enemy_defs, "mele")
	var range_def: Dictionary = _pick_random_enemy_def(enemy_defs, "range")

	if not mele_def.is_empty():
		_spawn_enemy(mele_def)
	if not range_def.is_empty():
		_spawn_enemy(range_def)

	if not mele_def.is_empty() or not range_def.is_empty():
		_show_message_over_hero("Reinforcements arrived!")


func _pick_random_enemy_def(enemy_defs: Array, type: String) -> Dictionary:
	var matches: Array = []
	for enemy_def in enemy_defs:
		if enemy_def.get("type", "") == type:
			matches.append(enemy_def)
	if matches.is_empty():
		return {}
	return matches[randi() % matches.size()]


## Only items that are actually consumed by use (heal/mana potions)
## show up as clickable battle actions - equipment-type items ("stat"
## effect, like Blades of Attack or Gauntlets of Strength) apply their
## bonus passively just by being in the inventory (see PlayerManager.
## get_inventory_stat_bonus) and are managed from the Shop instead.
## Shows every occupied inventory slot (PlayerManager caps this at 6,
## matching the panel's 3x2 grid, so nothing is ever hidden). Only
## consumables (heal/mana effect) are clickable battle actions -
## equipment ("stat" effect, like Blades of Attack) is shown so it's
## visible in the inventory, but stays disabled since it applies its
## bonus passively just by being held (see PlayerManager.
## get_inventory_stat_bonus) rather than being "used".
func _populate_item_grid() -> void:
	var slots: Array = PlayerManager.get_inventory_slots()
	var buttons: Array = items_grid.get_children()

	for i in buttons.size():
		var btn: Button = buttons[i]

		# Clear any previous connection before rebinding - otherwise
		# repeated refreshes stack up multiple connections on the
		# same button, each bound to a stale item_id.
		for connection in btn.pressed.get_connections():
			btn.pressed.disconnect(connection["callable"])

		if i < slots.size():
			var slot: Dictionary = slots[i]
			var item_id: String = slot["item_id"]
			var count: int = slot["count"]
			var item_data: Dictionary = GameManager.get_item(item_id)
			var image_path: String = item_data.get("image", "")
			var effect: String = item_data.get("effect", "")
			var is_consumable: bool = effect == "heal" or effect == "mana"

			btn.icon = load(image_path) if (image_path != "" and ResourceLoader.exists(image_path)) else null
			btn.text = "x" + str(count) if count > 1 else ""

			if is_consumable:
				btn.mouse_filter = Control.MOUSE_FILTER_STOP
				btn.disabled = _battle_over or _has_acted_this_turn
				btn.pressed.connect(_on_item_pressed.bind(item_id))
			else:
				# Equipment is passive, not clickable - but `disabled`
				# also dims the icon in Godot's default theme, which
				# would make owned gear look faded/less visible than a
				# potion. Blocking input via mouse_filter instead keeps
				# it fully bright while still being unclickable.
				btn.disabled = false
				btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		else:
			btn.icon = null
			btn.text = ""
			btn.disabled = true
			btn.mouse_filter = Control.MOUSE_FILTER_STOP


func _refresh_gold_label() -> void:
	gold_value_label.text = str(PlayerManager.get_gold())


func _on_item_pressed(item_id: String) -> void:
	if _battle_over or _has_acted_this_turn:
		return
	if not PlayerManager.use_item(item_id):
		return

	var item_data: Dictionary = GameManager.get_item(item_id)
	var effect: String = item_data.get("effect", "")
	var value: float = float(item_data.get("value", 0))

	match effect:
		"heal":
			heal(value)
		"mana":
			restore_mana(value)

	_has_acted_this_turn = true
	_update_action_buttons()


func _build_bar_styles() -> void:
	var hp_fill := StyleBoxFlat.new()
	hp_fill.bg_color = Color(0.8, 0.15, 0.15, 1)
	hp_fill.set_corner_radius_all(4)
	hp_bar.add_theme_stylebox_override("fill", hp_fill)

	var mana_fill := StyleBoxFlat.new()
	mana_fill.bg_color = Color(0.2, 0.4, 0.9, 1)
	mana_fill.set_corner_radius_all(4)
	mana_bar.add_theme_stylebox_override("fill", mana_fill)

	var xp_fill := StyleBoxFlat.new()
	xp_fill.bg_color = Color(0.95, 0.65, 0.1, 1)
	xp_fill.set_corner_radius_all(4)
	xp_bar.add_theme_stylebox_override("fill", xp_fill)

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.1, 0.1, 0.1, 0.7)
	bg_style.set_corner_radius_all(4)
	hp_bar.add_theme_stylebox_override("background", bg_style)
	mana_bar.add_theme_stylebox_override("background", bg_style)
	xp_bar.add_theme_stylebox_override("background", bg_style)


func _refresh_bars() -> void:
	# Re-read from PlayerManager each time so bars always reflect the
	# saved values, even if damage/xp were applied elsewhere.
	_recruited = PlayerManager.get_recruited_hero()
	var stats: Dictionary = _recruited.get("stats", {})

	hp_bar.max_value = float(stats.get("hp", 1))
	hp_bar.value = _recruited.get("current_hp", 0)
	hp_value_label.text = str(int(hp_bar.value)) + "/" + str(int(hp_bar.max_value))

	mana_bar.max_value = float(stats.get("mana", 1))
	mana_bar.value = _recruited.get("current_mana", 0)
	mana_value_label.text = str(int(mana_bar.value)) + "/" + str(int(mana_bar.max_value))

	# hero_xp tracks progress within the current level (see
	# PlayerManager.check_level_up), so the bar always fills from 0 up
	# to whatever the current level requires - no lifetime-total math.
	var xp_required: int = GameManager.get_xp_required_for_level(PlayerManager.get_level())
	if xp_required <= 0:
		# Max level - nothing further to progress toward, show a full bar.
		xp_bar.max_value = 1.0
		xp_bar.value = 1.0
	else:
		xp_bar.max_value = float(xp_required)
		xp_bar.value = clamp(_recruited.get("xp", 0), 0.0, float(xp_required))


func _populate_skill_buttons() -> void:
	for child in skill_buttons_container.get_children():
		child.queue_free()
	_skill_buttons.clear()
	_skill_cooldown_labels.clear()

	var skills: Array = _hero_static.get("skills", [])
	var learned_skills: Dictionary = _recruited.get("learned_skills", {})

	for skill in skills:
		var skill_id: String = skill.get("id", "")
		var learned_level: int = learned_skills.get(skill_id, 0)

		var slot := VBoxContainer.new()
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.add_theme_constant_override("separation", 2)

		var btn := Button.new()
		btn.text = skill.get("name", "Skill") + (" (Lv%d)" % learned_level if learned_level > 0 else " (Locked)")
		btn.custom_minimum_size = Vector2(0, 40)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.disabled = learned_level <= 0
		btn.pressed.connect(_on_skill_pressed.bind(skill))

		var cooldown_label := Label.new()
		cooldown_label.text = "Ready"
		cooldown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cooldown_label.add_theme_color_override("font_color", Color(0.5, 1, 0.5, 1))
		cooldown_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		cooldown_label.add_theme_constant_override("outline_size", 2)
		cooldown_label.add_theme_font_size_override("font_size", 12)

		slot.add_child(btn)
		slot.add_child(cooldown_label)
		skill_buttons_container.add_child(slot)

		_skill_cooldown_labels[skill_id] = cooldown_label
		# Cooldowns persist across battles (see PlayerManager.
		# get_skill_cooldown/set_skill_cooldown), so a skill used near
		# the end of one fight stays locked into the next.
		_skill_cooldowns[skill_id] = PlayerManager.get_skill_cooldown(skill_id)

		if learned_level > 0:
			_skill_buttons[skill_id] = btn

	_refresh_skill_cooldown_labels()


func _on_skill_pressed(skill: Dictionary) -> void:
	if _battle_over or _has_acted_this_turn:
		return

	var skill_id: String = skill.get("id", "")
	if _skill_cooldowns.get(skill_id, 0) > 0:
		return

	var skill_level: int = PlayerManager.get_skill_level(skill_id)
	if skill_level <= 0:
		return

	var level_data: Dictionary = GameManager.get_skill_level_data(skill, skill_level)

	var mana_cost: float = float(skill.get("mana_cost", 0))
	if _recruited.get("current_mana", 0) < mana_cost:
		_show_message_over_hero("Not enough mana")
		return

	var generation_before: int = _stage_generation

	match skill_id:
		"pounce":
			if not _cast_pounce(level_data):
				# No target found - nothing happened, so don't spend
				# mana, the turn, or start the cooldown.
				return
		"dark_pact":
			if not _cast_dark_pact(level_data):
				# No enemies in range - same as above, no-op.
				return
		_:
			# No effect implemented yet for other skills - this is the
			# hook point for when they're added. For now it just
			# confirms the wiring works end to end.
			print("Used skill: ", skill.get("name", ""))

	spend_mana(mana_cost)
	_skill_cooldowns[skill_id] = int(level_data.get("cooldown", 0))
	PlayerManager.set_skill_cooldown(skill_id, _skill_cooldowns[skill_id])
	_refresh_skill_cooldown_labels()

	# If that cast cleared the stage (or won a hero fight) and a fresh
	# encounter started, the turn lock has already been reset for it -
	# re-locking it here would carry the old turn's "used" state into
	# an encounter that hasn't had a turn yet. The cooldown/mana spend
	# above still applies regardless.
	if _battle_over or _stage_generation != generation_before:
		return

	_has_acted_this_turn = true
	_update_action_buttons()


## Slark's Pounce: leaps `level_data.distance` columns toward the
## nearest enemy - overriding the hero's normal speed-based move
## distance - and stops early if it lands on an enemy's column along
## the way. That enemy takes a standard attack and gets stunned for
## `level_data.stun_turns` of its own turns (see the "stun_turns_left"
## counter checked at the top of each enemy's turn in _enemy_turn()).
## Returns false (leaving position/turn untouched) if there's no
## enemy anywhere to leap toward.
func _cast_pounce(level_data: Dictionary) -> bool:
	if _enemies.is_empty():
		_show_message_over_hero("No target for Pounce")
		return false

	var nearest: Dictionary = {}
	var nearest_distance: int = GRID_COLUMNS + 1
	for enemy in _enemies:
		var d: int = _distance(enemy["pos_index"], _hero_pos_index)
		if d < nearest_distance:
			nearest_distance = d
			nearest = enemy

	var direction: int = _step_toward(_hero_pos_index, nearest["pos_index"])
	if direction == 0:
		# Already sharing the enemy's column - still leap somewhere
		# rather than doing nothing.
		direction = 1

	var move_distance: int = int(level_data.get("distance", 2))
	var pos: int = _hero_pos_index
	var hit_enemy: Dictionary = {}

	for i in range(move_distance):
		var next_pos: int = pos + direction
		if next_pos < 0 or next_pos >= GRID_COLUMNS:
			break
		pos = next_pos

		var enemy_here: Dictionary = _get_enemy_at(pos)
		if not enemy_here.is_empty():
			hit_enemy = enemy_here
			break

	_hero_pos_index = pos
	_update_hero_position()

	if not hit_enemy.is_empty():
		_deal_damage_to_enemy(hit_enemy)
		# Only stun if it survived the hit - a dead enemy has already
		# been removed from _enemies by _deal_damage_to_enemy's kill check.
		if hit_enemy.get("current_hp", 0) > 0:
			hit_enemy["stun_turns_left"] = int(level_data.get("stun_turns", 1))

	return true


## Slark's Dark Pact: deals `level_data.damage_multiplier` of one
## rolled hero-damage hit to every enemy within `level_data.radius`
## columns of Slark (0 = only Slark's own column), each still
## mitigated by that enemy's own armor. All hits share the same
## rolled amount - it's one burst around Slark, not a separate attack
## roll per enemy. (Silencing enemies caught in it isn't implemented yet.)
## Returns false (no mana/turn/cooldown spent) if nothing is in range.
func _cast_dark_pact(level_data: Dictionary) -> bool:
	var radius: int = int(level_data.get("radius", 0))
	var targets: Array = []
	for enemy in _enemies:
		if _distance(enemy["pos_index"], _hero_pos_index) <= radius:
			targets.append(enemy)

	if targets.is_empty():
		_show_message_over_hero("No enemies in range")
		return false

	var multiplier: float = float(level_data.get("damage_multiplier", 0.75))
	var pact_damage: float = _roll_hero_damage() * multiplier
	for enemy in targets:
		_deal_fixed_damage_to_enemy(enemy, pact_damage)

	return true


## Updates every skill's cooldown label - "Ready" or "N turns left" -
## to match _skill_cooldowns. Called after a skill is used and after
## cooldowns tick down at End Turn.
func _refresh_skill_cooldown_labels() -> void:
	for skill_id in _skill_cooldown_labels.keys():
		var label: Label = _skill_cooldown_labels[skill_id]
		var remaining: int = _skill_cooldowns.get(skill_id, 0)
		if remaining <= 0:
			label.text = "Ready"
			label.add_theme_color_override("font_color", Color(0.5, 1, 0.5, 1))
		else:
			var noun: String = "turn" if remaining == 1 else "turns"
			label.text = "%d %s left" % [remaining, noun]
			label.add_theme_color_override("font_color", Color(1, 0.6, 0.4, 1))


## Ticks every tracked skill cooldown down by one turn, clamped at 0.
## Called once per End Turn.
func _tick_skill_cooldowns() -> void:
	for skill_id in _skill_cooldowns.keys():
		var new_value: int = maxi(0, _skill_cooldowns[skill_id] - 1)
		_skill_cooldowns[skill_id] = new_value
		PlayerManager.set_skill_cooldown(skill_id, new_value)


# ------------------------------------------------------------------
# Public API for future combat/enemy scripts to call into.
# Each one persists through PlayerManager and refreshes the bars.
# ------------------------------------------------------------------

func apply_damage(amount: float) -> void:
	var reduced: float = _apply_armor_reduction(amount, _hero_armor())
	PlayerManager.damage_hero(reduced)
	_refresh_bars()


func spend_mana(amount: float) -> void:
	PlayerManager.use_mana(amount)
	_refresh_bars()


func heal(amount: float) -> void:
	PlayerManager.heal_hero(amount)
	_refresh_bars()


func restore_mana(amount: float) -> void:
	PlayerManager.restore_mana(amount)
	_refresh_bars()


func gain_xp(amount: float) -> void:
	PlayerManager.add_xp(amount)
	var level_ups: Array = PlayerManager.check_level_up(_hero_static)
	_refresh_bars()
	if not level_ups.is_empty():
		_show_level_up_popup(level_ups)


## Displays the LEVEL UP popup for one or more levels gained from a
## single XP gain. Shows the level reached and, for each of the six
## tracked stats, the value from just before the first level-up next
## to the value after the last one - so a multi-level jump reads as
## one clean before/after instead of a stack of popups.
func _show_level_up_popup(level_ups: Array) -> void:
	var first: Dictionary = level_ups[0]
	var last: Dictionary = level_ups[level_ups.size() - 1]
	var old_stats: Dictionary = first["old_stats"]
	var new_stats: Dictionary = last["new_stats"]

	level_up_level_label.text = "Level " + str(last["new_level"])

	_set_stat_row(level_up_strength_old, level_up_strength_new, old_stats["strength"], new_stats["strength"])
	_set_stat_row(level_up_agility_old, level_up_agility_new, old_stats["agility"], new_stats["agility"])
	_set_stat_row(level_up_intelligence_old, level_up_intelligence_new, old_stats["intelligence"], new_stats["intelligence"])
	_set_stat_row(level_up_hp_old, level_up_hp_new, old_stats["hp"], new_stats["hp"])
	_set_stat_row(level_up_mana_old, level_up_mana_new, old_stats["mana"], new_stats["mana"])
	# Damage has no level-up growth yet, so old/new will read the same -
	# still shown for completeness and consistency with the other stats.
	_set_stat_row(level_up_damage_old, level_up_damage_new, old_stats["damage"], new_stats["damage"])

	level_up_popup.visible = true


func _set_stat_row(old_label: Label, new_label: Label, old_value, new_value) -> void:
	old_label.text = _format_stat_value(old_value)
	new_label.text = _format_stat_value(new_value)


## Numeric stats (strength, agility, intelligence, hp, mana) print
## with one decimal place; damage is stored as a "min-max" string and
## just passes through unchanged.
func _format_stat_value(value) -> String:
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		return "%.1f" % float(value)
	return str(value)


func _on_level_up_continue_pressed() -> void:
	level_up_popup.visible = false
	_maybe_show_skill_choice_popup()


## Opens the skill-choice popup if the player has any banked skill
## points AND at least one skill they could currently learn or
## upgrade with one - otherwise there's nothing to do (points with no
## legal use yet just stay banked for a later level).
func _maybe_show_skill_choice_popup() -> void:
	if not PlayerManager.has_spendable_skill_action(_hero_static):
		return
	_refresh_skill_choice_popup()
	skill_choice_popup.visible = true


## Rebuilds the skill-choice popup's option buttons from scratch:
## one per skill the player could currently learn (unlearned, level-1
## requirement met) or upgrade (learned, next-level requirement met).
func _refresh_skill_choice_popup() -> void:
	for child in skill_choice_options.get_children():
		child.queue_free()

	var points: int = PlayerManager.get_skill_points()
	var noun: String = "point" if points == 1 else "points"
	skill_choice_points_label.text = "You have %d skill %s to spend" % [points, noun]

	for skill in _hero_static.get("skills", []):
		var skill_id: String = skill.get("id", "")
		if not PlayerManager.can_spend_skill_point_on(skill_id, _hero_static):
			continue

		var current_level: int = PlayerManager.get_skill_level(skill_id)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 40)
		if current_level <= 0:
			btn.text = "Learn " + skill.get("name", skill_id)
		else:
			btn.text = "Upgrade " + skill.get("name", skill_id) + " to Lv " + str(current_level + 1)
		btn.pressed.connect(_on_skill_choice_selected.bind(skill_id))
		skill_choice_options.add_child(btn)


## Spends the point, refreshes the skill buttons (a newly learned
## skill needs its button re-enabled), then either loops back to the
## popup for another point/option, or closes it once there's nothing
## left to spend.
func _on_skill_choice_selected(skill_id: String) -> void:
	if PlayerManager.spend_skill_point(skill_id, _hero_static):
		_recruited = PlayerManager.get_recruited_hero()
		_populate_skill_buttons()
		_update_action_buttons()

	if PlayerManager.has_spendable_skill_action(_hero_static):
		_refresh_skill_choice_popup()
	else:
		skill_choice_popup.visible = false


# ------------------------------------------------------------------
# Turn actions: at most one move and one attack per turn.
# ------------------------------------------------------------------

## Heroes move faster than enemies as part of their stats - a speed
## of 1.5-2.7 rounds to 2-3 columns per move, while every enemy
## always takes exactly one column per turn (see _enemy_turn()).
func _hero_move_distance() -> int:
	var speed: float = float(_recruited.get("stats", {}).get("speed", 1.0))
	return maxi(1, roundi(speed))


func _is_ranged_hero() -> bool:
	return _hero_static.get("range_type", "Mele") == "Range"


## Melee heroes only fight by standing exactly on an enemy's column,
## so a multi-column move that would otherwise carry them past one
## stops right on top of it instead - covering less distance than
## their full speed, but landing somewhere they can actually attack.
func _melee_move_target(start: int, direction: int, distance: int) -> int:
	var pos: int = start

	for i in range(distance):
		var next_pos := pos + direction
		if next_pos < 0 or next_pos >= GRID_COLUMNS:
			break
		pos = next_pos

		if not _get_enemy_at(pos).is_empty():
			return pos

	return pos


func _hero_move(direction: int) -> void:
	if _battle_over or _has_acted_this_turn:
		return

	_cancel_targeting()

	var distance: int = _hero_move_distance()

	if _is_ranged_hero():
		_hero_pos_index = clampi(_hero_pos_index + direction * distance, 0, GRID_COLUMNS - 1)
	else:
		_hero_pos_index = _melee_move_target(_hero_pos_index, direction, distance)

	_update_hero_position()
	_has_acted_this_turn = true
	_update_action_buttons()


func _on_move_left_pressed() -> void:
	_hero_move(-1)


func _on_move_right_pressed() -> void:
	_hero_move(1)


func _on_attack_pressed() -> void:
	if _battle_over or _has_acted_this_turn:
		return

	if _is_ranged_hero():
		_start_ranged_targeting()
	else:
		_resolve_melee_attack()


func _resolve_melee_attack() -> void:
	var target: Dictionary = _get_enemy_at(_hero_pos_index)
	if target.is_empty():
		_show_message_over_hero("No enemy in range")
		return
	_apply_hero_attack(target)


## How many columns away a ranged hero can hit, from their Range
## stat: 200-300 -> 1 column, 300-400 -> 2 columns, and so on
## (+100 range per extra column).
func _hero_attack_column_range() -> int:
	var range_stat: float = float(_recruited.get("stats", {}).get("range", 200))
	return maxi(1, floori((range_stat - 200.0) / 100.0) + 1)


func _start_ranged_targeting() -> void:
	_cancel_targeting()

	var col_range: int = _hero_attack_column_range()
	for enemy in _enemies:
		if _distance(enemy["pos_index"], _hero_pos_index) <= col_range:
			_valid_targets.append(enemy)

	if _valid_targets.is_empty():
		_show_message_over_hero("No enemy in range")
		return

	_targeting_mode = true
	for enemy in _valid_targets:
		enemy["node"].modulate = Color(1, 1, 0.4)


func _cancel_targeting() -> void:
	for enemy in _valid_targets:
		if is_instance_valid(enemy["node"]):
			enemy["node"].modulate = Color(1, 1, 1)
	_valid_targets.clear()
	_targeting_mode = false


func _on_enemy_gui_input(event: InputEvent, enemy: Dictionary) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_enemy_clicked(enemy)


func _on_enemy_clicked(enemy: Dictionary) -> void:
	if not _targeting_mode or _battle_over or _has_acted_this_turn:
		return
	if not _valid_targets.has(enemy):
		return

	_cancel_targeting()
	_apply_hero_attack(enemy)


func _apply_hero_attack(target: Dictionary) -> void:
	var generation_before: int = _stage_generation
	_deal_damage_to_enemy(target)

	# If that kill cleared the stage (or won a hero fight) and a fresh
	# encounter started, the turn lock has already been reset for it -
	# re-locking it here would carry the old turn's "used" state into
	# an encounter that hasn't had a turn yet.
	if _battle_over or _stage_generation != generation_before:
		return

	_has_acted_this_turn = true
	_update_action_buttons()


## Rolls hero damage, applies the target's armor mitigation, subtracts
## it from the target's HP, and kills it if that brings it to 0.
## Shared by the Attack button (_apply_hero_attack) and skills like
## Pounce that deal a standard attack as part of their effect but
## shouldn't duplicate the turn-flag/button-update bookkeeping.
## Rolls hero damage and applies it to a single target via
## _deal_fixed_damage_to_enemy. Used by the plain Attack button and by
## skills (like Pounce) that deal exactly one standard attack.
func _deal_damage_to_enemy(target: Dictionary) -> void:
	_deal_fixed_damage_to_enemy(target, _roll_hero_damage())


## Applies an already-determined damage amount to one target (still
## mitigated by that target's own armor) and kills it if that brings
## it to 0. Shared by _deal_damage_to_enemy (single rolled hit) and
## Dark Pact (one rolled amount split across every enemy in range).
func _deal_fixed_damage_to_enemy(target: Dictionary, amount: float) -> void:
	var enemy_armor: float = float(target["static"].get("armor", 0))
	var mitigated: float = _apply_armor_reduction(amount, enemy_armor)
	target["current_hp"] -= mitigated
	_show_damage_number(target["node"], mitigated)

	if target["current_hp"] <= 0:
		_kill_enemy(target)


func _get_enemy_at(pos_index: int) -> Dictionary:
	for enemy in _enemies:
		if enemy["pos_index"] == pos_index:
			return enemy
	return {}


func _roll_hero_damage() -> float:
	var stats: Dictionary = _recruited.get("stats", {})
	var damage_str: String = str(stats.get("damage", "0-0"))
	var parts: PackedStringArray = damage_str.split("-")
	var min_dmg: float = float(parts[0]) if parts.size() > 0 else 0.0
	var max_dmg: float = float(parts[1]) if parts.size() > 1 else min_dmg
	return randi_range(int(min_dmg), int(max_dmg))


func _show_damage_number(target_node: Control, amount: float) -> void:
	var label := Label.new()
	label.text = str(int(amount))
	label.add_theme_color_override("font_color", Color(1, 0.15, 0.15, 1))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_font_size_override("font_size", 24)
	label.position = target_node.position + Vector2(target_node.size.x / 2.0 - 15, -10)
	enemies_layer.add_child(label)

	var tween := create_tween()
	tween.tween_property(label, "position:y", label.position.y - 40, 0.8)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.8)
	tween.finished.connect(label.queue_free)


## Same floating/fading style as _show_damage_number, but for text
## (e.g. "No enemy in range") shown over the hero instead of a number
## over an enemy.
func _show_message_over_hero(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(1, 0.15, 0.15, 1))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_font_size_override("font_size", 18)
	label.position = hero_image.position + Vector2(hero_image.size.x / 2.0 - 70, -10)
	add_child(label)

	var tween := create_tween()
	tween.tween_property(label, "position:y", label.position.y - 40, 0.8)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.8)
	tween.finished.connect(label.queue_free)


func _kill_enemy(enemy: Dictionary) -> void:
	var xp_gain: float = float(enemy["static"].get("XP", 0))
	gain_xp(xp_gain)

	var gold_gain: int = _roll_enemy_gold(enemy["static"])
	PlayerManager.add_gold(gold_gain)
	_refresh_gold_label()
	_show_gold_gain(enemy["node"], gold_gain)

	enemy["node"].queue_free()
	_enemies.erase(enemy)

	if _enemies.is_empty():
		_handle_victory()


## Parses an enemy's "gold" field ("34-39") the same way hero damage
## is rolled from a "min-max" string, returning a random amount in
## that range. Missing/malformed fields just yield 0.
func _roll_enemy_gold(enemy_static: Dictionary) -> int:
	var gold_str: String = str(enemy_static.get("gold", "0"))
	var parts: PackedStringArray = gold_str.split("-")
	var min_gold: int = int(parts[0]) if parts.size() > 0 else 0
	var max_gold: int = int(parts[1]) if parts.size() > 1 else min_gold
	return randi_range(min_gold, max_gold)


## Same floating/fading style as _show_damage_number, but in gold for
## the amount of gold just earned from a kill.
func _show_gold_gain(target_node: Control, amount: int) -> void:
	var label := Label.new()
	label.text = "+%d gold" % amount
	label.add_theme_color_override("font_color", Color(1, 0.85, 0.2, 1))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_font_size_override("font_size", 18)
	label.position = target_node.position + Vector2(target_node.size.x / 2.0 - 30, 10)
	enemies_layer.add_child(label)

	var tween := create_tween()
	tween.tween_property(label, "position:y", label.position.y - 40, 0.9)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.9)
	tween.finished.connect(label.queue_free)


## Clearing a non-final stage reloads the next stage's enemies in this
## same Battle scene instance rather than returning to the Map. Only
## clearing the final stage counts as actually winning the zone - and
## if that's reached without ever fleeing in between (nothing resets
## _current_stage except leaving the scene), the zone is marked fully
## cleared so it always reopens on the final stage from now on.
## Clearing a non-final stage reloads the next stage's enemies in this
## same Battle scene instance rather than returning to the Map.
## Clearing the final stage tries to start a hero fight (see
## _try_start_hero_fight()) before actually finishing the zone;
## winning that hero fight (_in_hero_fight was true when the last
## enemy died) marks it defeated and then finishes for real.
func _handle_victory() -> void:
	if _in_hero_fight:
		PlayerManager.mark_hero_defeated(_hero_fight_target_id)
		_in_hero_fight = false
		_finish_zone_victory()
		return

	if _current_stage < GameManager.MAX_ZONE_STAGE:
		_advance_to_next_stage()
		return

	if _try_start_hero_fight():
		return

	_finish_zone_victory()


func _finish_zone_victory() -> void:
	PlayerManager.set_zone_cleared(GameManager.selected_zone)

	_battle_over = true
	_update_action_buttons()
	PlayerManager.record_high_score()
	get_tree().change_scene_to_file("res://scenes/Map.tscn")


## Moves on to the next wave without leaving the Battle scene: hero
## HP/mana/skill cooldowns carry over as-is (no free heal between
## stages), but position, turn count, and the per-turn action lock
## reset like a fresh encounter.
func _advance_to_next_stage() -> void:
	_current_stage += 1
	_stage_generation += 1
	_update_stage_label()
	_show_message_over_hero("Stage %d!" % _current_stage)

	_cancel_targeting()
	_hero_pos_index = 1
	_update_hero_position()

	_turn_count = 0
	_has_acted_this_turn = false

	_load_enemies()
	_update_action_buttons()


## If this zone still has an undefeated rival hero available, starts a
## fight against a random one of them and returns true. Otherwise
## returns false and leaves the battle unaffected, so the caller can
## fall through to actually finishing the zone.
func _try_start_hero_fight() -> bool:
	var eligible: Array = _get_eligible_hero_fight_heroes()
	if eligible.is_empty():
		return false

	_start_hero_fight(eligible[randi() % eligible.size()])
	return true


## Every hero in this zone that's fair game for a hero fight right
## now: if this is the player's own recruited hero's home zone, their
## own hero is excluded (fighting themselves makes no sense) but any
## OTHER hero recruited from that same zone still counts; in a zone
## that isn't their own, every hero in it is eligible. Either way,
## anyone already marked defeated (PlayerManager.mark_hero_defeated)
## is excluded, so the same hero is never offered for a rematch.
func _get_eligible_hero_fight_heroes() -> Array:
	var heroes: Array = GameManager.get_selected_zone().get("heroes", [])
	if heroes.is_empty():
		return []

	var own_hero_id: String = _recruited.get("id", "")
	var is_own_zone: bool = GameManager.selected_zone == GameManager.get_zone_id_for_hero(own_hero_id)

	var eligible: Array = []
	for hero in heroes:
		var hero_id: String = hero.get("id", "")
		if is_own_zone and hero_id == own_hero_id:
			continue
		if PlayerManager.is_hero_defeated(hero_id):
			continue
		eligible.append(hero)

	return eligible


## Starts a one-enemy fight against a rival hero: same fresh-encounter
## reset as advancing a stage (position, turn count, action lock), but
## _current_stage itself doesn't change - see _in_hero_fight.
func _start_hero_fight(hero_static: Dictionary) -> void:
	_in_hero_fight = true
	_hero_fight_target_id = hero_static.get("id", "")
	_stage_generation += 1

	_update_stage_label()
	_show_message_over_hero("%s challenges you!" % hero_static.get("name", "A rival hero"))

	_cancel_targeting()
	_hero_pos_index = 1
	_update_hero_position()

	_turn_count = 0
	_has_acted_this_turn = false

	for child in enemies_layer.get_children():
		child.queue_free()
	_enemies.clear()
	_spawn_enemy(GameManager.build_hero_fight_enemy_def(hero_static))

	_update_action_buttons()


func _update_stage_label() -> void:
	if _in_hero_fight:
		stage_label.text = "Hero Fight!"
	else:
		stage_label.text = "Stage %d/%d" % [_current_stage, GameManager.MAX_ZONE_STAGE]


# ------------------------------------------------------------------
# End Turn: range enemies attack every turn; melee enemies attack
# only if sharing the hero's column, otherwise take one step toward
# the hero. Then the turn's move/attack allowance resets.
# ------------------------------------------------------------------

func _on_end_turn_pressed() -> void:
	if _battle_over:
		return

	_cancel_targeting()
	_enemy_turn()

	if _recruited.get("current_hp", 0) <= 0:
		_handle_defeat()
		return

	_turn_count += 1
	if _turn_count % REINFORCEMENT_INTERVAL == 0 and not _enemies.is_empty():
		_spawn_reinforcements()

	_tick_skill_cooldowns()
	_has_acted_this_turn = false
	_update_action_buttons()
	_refresh_skill_cooldown_labels()


## Ranged enemies get exactly one action per turn too - flee, attack,
## or approach - never a flee-then-attack combo in the same turn:
##
##        too close
##            |
##          FLEE
##            |
##        safe range
##            |
##         ATTACK
##            ^
##            |
##        too far
##            |
##          MOVE
func _enemy_turn() -> void:
	for enemy in _enemies.duplicate():
		var stun_turns_left: int = enemy.get("stun_turns_left", 0)
		if stun_turns_left > 0:
			# Loses this turn entirely - no move, no attack - then the
			# counter ticks down toward wearing off.
			enemy["stun_turns_left"] = stun_turns_left - 1
			continue

		var enemy_static: Dictionary = enemy["static"]
		var enemy_type: String = enemy_static.get("type", "")
		var enemy_damage: float = float(enemy_static.get("damage", 0))

		if enemy_type == "range":
			var distance: int = _distance(enemy["pos_index"], _hero_pos_index)

			if distance <= RANGE_ENEMY_FLEE_DISTANCE:
				# TOO CLOSE: move away. Attacking is next turn's business,
				# even if the flee step happens to land back in range.
				_move_enemy(enemy, _get_flee_position(enemy))

			elif distance <= RANGE_ENEMY_ATTACK_RANGE:
				# SAFE RANGE: attack, stay put.
				apply_damage(enemy_damage)

			else:
				# TOO FAR: close the distance.
				var step: int = _step_toward(enemy["pos_index"], _hero_pos_index)
				_move_enemy(enemy, enemy["pos_index"] + step)

		elif enemy_type == "mele":
			if enemy["pos_index"] == _hero_pos_index:
				apply_damage(enemy_damage)
			else:
				var step: int = _step_toward(enemy["pos_index"], _hero_pos_index)
				_move_enemy(enemy, enemy["pos_index"] + step)


## Moves an enemy to `new_pos` (clamped on-board) and syncs its node's
## screen position to match.
func _move_enemy(enemy: Dictionary, new_pos: int) -> void:
	enemy["pos_index"] = clampi(new_pos, 0, GRID_COLUMNS - 1)
	enemy["node"].position = Vector2(_index_to_x(enemy["pos_index"]), _creature_y())


## Picks a flee direction once and sticks with it - only flipping to
## the opposite direction when it actually hits a wall. Recalculating
## "away from hero" fresh every turn is what caused the back-and-forth
## pacing at the edge before: the enemy would re-decide "flee left" as
## soon as it was possible again, then immediately get blocked again.
func _get_flee_position(enemy: Dictionary) -> int:
	var enemy_pos: int = enemy["pos_index"]

	if not enemy.has("flee_direction"):
		enemy["flee_direction"] = -1 if enemy_pos < _hero_pos_index else 1

	var direction: int = enemy["flee_direction"]
	var next_pos: int = enemy_pos + direction

	if next_pos < 0 or next_pos >= GRID_COLUMNS:
		# Hit the wall - commit to the other direction from now on,
		# not just for this one turn.
		direction = -direction
		enemy["flee_direction"] = direction
		next_pos = clampi(enemy_pos + direction, 0, GRID_COLUMNS - 1)

	return next_pos


## The hero gets exactly one action per turn - move, attack, skill, or
## item. Once any of them is used, all four lock until End Turn.
func _update_action_buttons() -> void:
	var locked: bool = _battle_over or _has_acted_this_turn
	move_left_button.disabled = locked
	move_right_button.disabled = locked
	attack_button.disabled = locked
	end_turn_button.disabled = _battle_over

	for skill_id in _skill_buttons.keys():
		var on_cooldown: bool = _skill_cooldowns.get(skill_id, 0) > 0
		_skill_buttons[skill_id].disabled = locked or on_cooldown

	# Item buttons are rebuilt (not just toggled) since their count/
	# icon can also change from item use - _populate_item_grid() reads
	# _has_acted_this_turn itself to decide their disabled state.
	_populate_item_grid()


func _handle_defeat() -> void:
	_battle_over = true
	_update_action_buttons()
	PlayerManager.record_high_score()
	defeat_popup.visible = true
	print("Hero defeated.")
