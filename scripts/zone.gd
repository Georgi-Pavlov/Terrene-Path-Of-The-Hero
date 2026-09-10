extends Control

@onready var background: TextureRect = $Background
@onready var hero_name_label: Label = $HeroNameLabel
@onready var hero_range_type: Label = $HeroRangeType
@onready var hero_main_stat: Label = $HeroMainStat
@onready var title_label: Label = $Title
@onready var description_label: Label = $Description
@onready var back_button: Button = $BackButton
@onready var accept_button: Button = $AcceptButton
@onready var prev_hero_button: Button = $PrevHeroButton
@onready var next_hero_button: Button = $NextHeroButton

@onready var stats_grid: GridContainer = $StatsPanel/StatsMargin/StatsGrid
@onready var skill_buttons_container: HBoxContainer = $SkillsPanel/SkillsMargin/SkillButtons
@onready var skill_error_label: Label = $SkillErrorLabel

@onready var skill_desc_panel: PanelContainer = $SkillDescriptionPanel
@onready var skill_name_label: Label = $SkillDescriptionPanel/SkillDescMargin/SkillDescVBox/SkillNameLabel
@onready var skill_desc_label: Label = $SkillDescriptionPanel/SkillDescMargin/SkillDescVBox/SkillDescLabel
@onready var skill_ok_button: Button = $SkillDescriptionPanel/SkillDescMargin/SkillDescVBox/SkillDescButtons/OkButton
@onready var skill_close_button: Button = $SkillDescriptionPanel/SkillDescMargin/SkillDescVBox/SkillDescButtons/CloseButton

# Every skill button on this screen is clickable so the player can
# read any skill's description (including the ultimate) before
# recruiting - but the ultimate itself can't be chosen as the
# starting skill (see _on_skill_ok_pressed()).
const ULTIMATE_FIRST_SKILL_ERROR := "You can't start with your ultimate - pick it after recruiting, once you've earned skill points."

# Friendly labels for the stat dictionary keys, in the order they're shown.
const STAT_ORDER := ["strength", "agility", "intelligence", "range", "hp", "mana", "armor", "damage", "speed"]
const STAT_LABELS := {
	"strength": "Strength",
	"agility": "Agility",
	"intelligence": "Intelligence",
	"range": "Range",
	"hp": "HP",
	"mana": "Mana",
	"armor": "Armor",
	"damage": "Damage",
	"speed": "Speed",
}

# Shared skill button styling, built once in _ready() and reused across
# every generated button so all 5 look identical.
var _skill_style_normal: StyleBoxFlat
var _skill_style_hover: StyleBoxFlat
var _skill_style_pressed: StyleBoxFlat
var _skill_style_disabled: StyleBoxFlat
var _skill_style_selected: StyleBoxFlat

var _zone_data: Dictionary = {}
var _heroes: Array = []
var _current_hero_index: int = 0
var _current_hero: Dictionary = {}

# The skill shown in the description popup, not yet confirmed with OK.
var _pending_skill: Dictionary = {}
# The one skill actually chosen for this hero (empty until OK is pressed).
var _selected_skill: Dictionary = {}
# skill id -> Button, so the OK handler can restyle the chosen one.
var _skill_buttons_by_id: Dictionary = {}
# skill_error_label's original text ("Choose a skill..."), restored
# whenever it's been overwritten with the ultimate-specific message.
var _default_skill_error_text: String = ""


func _ready() -> void:
	back_button.pressed.connect(_on_back_button_pressed)
	accept_button.pressed.connect(_on_accept_button_pressed)
	prev_hero_button.pressed.connect(_on_prev_hero_pressed)
	next_hero_button.pressed.connect(_on_next_hero_pressed)
	skill_ok_button.pressed.connect(_on_skill_ok_pressed)
	skill_close_button.pressed.connect(_on_skill_close_pressed)

	_default_skill_error_text = skill_error_label.text

	_build_skill_button_styles()

	_zone_data = GameManager.get_selected_zone()

	if _zone_data.is_empty():
		title_label.text = "Unknown Zone"
		description_label.text = ""
		hero_name_label.text = ""
		print("ERROR: No zone selected.")
		return

	title_label.text = _zone_data["name"]
	description_label.text = _zone_data["description"]
	play_zone_music(_zone_data["music"])

	# Once a hero has been accepted, it's locked in for the rest of
	# this playthrough - clicking any zone on the map should drop
	# straight into battle there with that same hero, not reopen the
	# picker. The only way to choose a different hero is starting a
	# fresh playthrough via "New Game" (which clears the recruited
	# hero - see PlayerManager.clear_recruited_hero()).
	var recruited: Dictionary = PlayerManager.get_recruited_hero()
	if not recruited.is_empty():
		if recruited.get("current_hp", 0) > 0:
			get_tree().change_scene_to_file("res://scenes/Battle.tscn")
		else:
			# Hero died and hasn't been cleared yet (that only happens
			# via "New Game"). Don't drop them into a battle they've
			# already lost - just make it clear what to do instead.
			hero_name_label.text = ""
			hero_range_type.text = ""
			hero_main_stat.text = ""
			prev_hero_button.visible = false
			next_hero_button.visible = false
			description_label.text = "Your hero has fallen. Choose \"New Game\" from the main menu to start again."
		return

	_heroes = _zone_data.get("heroes", [])
	if _heroes.is_empty():
		hero_name_label.text = ""
		hero_range_type.text = ""
		hero_main_stat.text = ""
		prev_hero_button.visible = false
		next_hero_button.visible = false
		print("No hero defined for zone: ", _zone_data["name"])
		return

	# No point showing arrows when there's only one hero to look at.
	var multiple_heroes: bool = _heroes.size() > 1
	prev_hero_button.visible = multiple_heroes
	next_hero_button.visible = multiple_heroes

	_show_hero(0)


func _show_hero(index: int) -> void:
	_current_hero_index = wrapi(index, 0, _heroes.size())
	_current_hero = _heroes[_current_hero_index]

	hero_name_label.text = _current_hero.get("name", "")
	hero_name_label.add_theme_font_size_override("font_size", 36)
	hero_range_type.text = _current_hero.get("range_type", "")
	hero_range_type.add_theme_font_size_override("font_size", 18)
	hero_range_type.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hero_main_stat.text = _current_hero.get("main_stat", "")
	hero_main_stat.add_theme_font_size_override("font_size", 18)
	hero_main_stat.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

	# Background now comes from the hero first (so heroes sharing a zone,
	# like Naga Siren and Slardar, can each show their own art), falling
	# back to the zone's own background only if the hero has none set.
	var background_path: String = _current_hero.get("background", "")
	if background_path == "":
		background_path = _zone_data.get("background", "")
	if background_path != "" and ResourceLoader.exists(background_path):
		background.texture = load(background_path)

	# Switching hero clears any in-progress skill choice - it belonged
	# to the previous hero's skill list, not this one's.
	_pending_skill = {}
	_selected_skill = {}
	_skill_buttons_by_id.clear()
	skill_error_label.visible = false
	skill_desc_panel.visible = false

	_populate_stats()
	_populate_skill_buttons()


func _on_prev_hero_pressed() -> void:
	_show_hero(_current_hero_index - 1)


func _on_next_hero_pressed() -> void:
	_show_hero(_current_hero_index + 1)


func _build_skill_button_styles() -> void:
	_skill_style_normal = StyleBoxFlat.new()
	_skill_style_normal.bg_color = Color(0.35, 0.24, 0.05, 0.9)
	_skill_style_normal.border_color = Color(0.85, 0.65, 0.2, 0.9)
	_skill_style_normal.set_border_width_all(2)
	_skill_style_normal.set_corner_radius_all(6)

	_skill_style_hover = _skill_style_normal.duplicate()
	_skill_style_hover.bg_color = Color(0.5, 0.35, 0.08, 1.0)

	_skill_style_pressed = _skill_style_normal.duplicate()
	_skill_style_pressed.bg_color = Color(0.22, 0.14, 0.03, 1.0)

	_skill_style_disabled = StyleBoxFlat.new()
	_skill_style_disabled.bg_color = Color(0.15, 0.15, 0.15, 0.4)
	_skill_style_disabled.border_color = Color(0.4, 0.4, 0.4, 0.4)
	_skill_style_disabled.set_border_width_all(2)
	_skill_style_disabled.set_corner_radius_all(6)

	# The one skill the player has actually chosen - green, to stand
	# out clearly from the unselected gold skill buttons.
	_skill_style_selected = StyleBoxFlat.new()
	_skill_style_selected.bg_color = Color(0.1, 0.35, 0.14, 0.95)
	_skill_style_selected.border_color = Color(0.35, 0.9, 0.4, 1)
	_skill_style_selected.set_border_width_all(3)
	_skill_style_selected.set_corner_radius_all(6)


func _populate_stats() -> void:
	for child in stats_grid.get_children():
		child.queue_free()

	var stats: Dictionary = _current_hero.get("stats", {})

	for stat_key in STAT_ORDER:
		if not stats.has(stat_key):
			continue

		var cell := VBoxContainer.new()
		cell.alignment = BoxContainer.ALIGNMENT_CENTER
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var name_label := Label.new()
		name_label.text = STAT_LABELS.get(stat_key, stat_key.capitalize())
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 18)
		cell.add_child(name_label)

		var value_label := Label.new()
		value_label.text = str(stats[stat_key])
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value_label.add_theme_font_size_override("font_size", 16)
		cell.add_child(value_label)

		stats_grid.add_child(cell)


func _populate_skill_buttons() -> void:
	for child in skill_buttons_container.get_children():
		child.queue_free()
	_skill_buttons_by_id.clear()

	var skills: Array = _current_hero.get("skills", [])

	for i in skills.size():
		var skill: Dictionary = skills[i]

		var btn := Button.new()
		btn.text = skill.get("name", "Skill")
		btn.custom_minimum_size = Vector2(0, 40)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Every skill is clickable here so the player can read its
		# description (including the ultimate) - whether it can
		# actually be SELECTED as the starting skill is enforced
		# separately, in _on_skill_ok_pressed().

		btn.add_theme_stylebox_override("normal", _skill_style_normal)
		btn.add_theme_stylebox_override("hover", _skill_style_hover)
		btn.add_theme_stylebox_override("pressed", _skill_style_pressed)
		btn.add_theme_stylebox_override("disabled", _skill_style_disabled)
		btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		btn.add_theme_color_override("font_disabled_color", Color(0.65, 0.65, 0.65, 0.7))

		btn.pressed.connect(_on_skill_button_pressed.bind(skill))
		skill_buttons_container.add_child(btn)

		var skill_id: String = skill.get("id", "")
		if skill_id != "":
			_skill_buttons_by_id[skill_id] = btn


func _on_skill_button_pressed(skill: Dictionary) -> void:
	_pending_skill = skill
	skill_name_label.text = skill.get("name", "")
	skill_desc_label.text = skill.get("description", "")
	skill_desc_panel.visible = true


func _on_skill_ok_pressed() -> void:
	if not _pending_skill.is_empty():
		if str(_pending_skill.get("type", "")).to_lower() == "ultimate":
			# Can look at it, can't start with it - ultimates only
			# become choosable later, once skill points are earned.
			skill_error_label.text = ULTIMATE_FIRST_SKILL_ERROR
			skill_error_label.visible = true
			skill_desc_panel.visible = false
			return
		_select_skill(_pending_skill)
	skill_desc_panel.visible = false


func _select_skill(skill: Dictionary) -> void:
	# Un-highlight whatever was previously chosen (only one allowed).
	var old_id: String = _selected_skill.get("id", "")
	if old_id != "" and _skill_buttons_by_id.has(old_id):
		var old_btn: Button = _skill_buttons_by_id[old_id]
		old_btn.add_theme_stylebox_override("normal", _skill_style_normal)
		old_btn.add_theme_stylebox_override("hover", _skill_style_hover)
		old_btn.add_theme_stylebox_override("pressed", _skill_style_pressed)

	_selected_skill = skill

	var new_id: String = skill.get("id", "")
	if new_id != "" and _skill_buttons_by_id.has(new_id):
		var new_btn: Button = _skill_buttons_by_id[new_id]
		new_btn.add_theme_stylebox_override("normal", _skill_style_selected)
		new_btn.add_theme_stylebox_override("hover", _skill_style_selected)
		new_btn.add_theme_stylebox_override("pressed", _skill_style_selected)

	skill_error_label.visible = false


func _on_skill_close_pressed() -> void:
	skill_desc_panel.visible = false


func _on_accept_button_pressed() -> void:
	if _selected_skill.is_empty():
		skill_error_label.text = _default_skill_error_text
		skill_error_label.visible = true
		return

	PlayerManager.recruit_hero(_current_hero, _selected_skill)
	print("Recruited: ", _current_hero.get("name", ""), " with ", _selected_skill.get("name", ""))
	get_tree().change_scene_to_file("res://scenes/Battle.tscn")


func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Map.tscn")


func play_zone_music(music_name: String) -> void:
	var music_path := "res://assets/music/" + music_name + ".ogg"
	var music = load(music_path)

	if music:
		AudioManager.play_music(music)
