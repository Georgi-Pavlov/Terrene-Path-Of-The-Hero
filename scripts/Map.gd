extends Control

# The player can only enter their own recruited hero's home zone until
# it's fully cleared (final stage beaten AND every hero in it defeated
# - see PlayerManager.is_home_zone_cleared()). Computed once here so
# _spawn_region_buttons() and _on_region_pressed() agree on the same
# snapshot for this Map visit.
var _home_zone_id: String = ""
var _home_zone_cleared: bool = true

var _lock_message_tween: Tween

const REGIONS := [
	{"name": "Azura", "pos": Vector2(0.460, 0.065)},
	{"name": "Dark Reef", "pos": Vector2(0.360, 0.110)},
	{"name": "Northern Pine", "pos": Vector2(0.420, 0.170)},
	{"name": "Avarice", "pos": Vector2(0.600, 0.150)},
	{"name": "Cladd Isles", "pos": Vector2(0.325, 0.270)},
	{"name": "White Spire", "pos": Vector2(0.485, 0.250)},
	{"name": "Frozen Realm", "pos": Vector2(0.550, 0.270)},
	{"name": "Kingdom of Olympus", "pos": Vector2(0.740, 0.290)},
	{"name": "Vale of Augury", "pos": Vector2(0.410, 0.330)},
	{"name": "Wailing Mountains", "pos": Vector2(0.540, 0.360)},
	{"name": "Sunken Cities", "pos": Vector2(0.300, 0.395)},
	{"name": "Nightsilver Woods", "pos": Vector2(0.410, 0.405)},
	{"name": "Hinterlands", "pos": Vector2(0.543, 0.422)},
	{"name": "Drakken Highlands", "pos": Vector2(0.735, 0.415)},
	{"name": "Bronze Empire", "pos": Vector2(0.500, 0.485)},
	{"name": "Ruelands", "pos": Vector2(0.600, 0.490)},
	{"name": "Jidi Islands", "pos": Vector2(0.225, 0.527)},
	{"name": "Ghastly Eyrie", "pos": Vector2(0.845, 0.518)},
	{"name": "Revtel", "pos": Vector2(0.510, 0.560)},
	{"name": "Emauracus", "pos": Vector2(0.700, 0.550)},
	{"name": "Nishai", "pos": Vector2(0.330, 0.622)},
	{"name": "Outlands", "pos": Vector2(0.435, 0.650)},
	{"name": "Fields of Carnage", "pos": Vector2(0.510, 0.665)},
	{"name": "Bleeding Hills", "pos": Vector2(0.600, 0.630)},
	{"name": "Arktura", "pos": Vector2(0.135, 0.678)},
	{"name": "Ivory Isles", "pos": Vector2(0.710, 0.763)},
	{"name": "Ashkavor", "pos": Vector2(0.800, 0.723)},
	{"name": "Fellstrath", "pos": Vector2(0.880, 0.681)},
	{"name": "Xhacatocail Mountains", "pos": Vector2(0.165, 0.765)},
	{"name": "Kalabor", "pos": Vector2(0.325, 0.783)},
	{"name": "Scintillant Waste", "pos": Vector2(0.410, 0.780)},
	{"name": "Druud", "pos": Vector2(0.555, 0.805)},
	{"name": "Hoven", "pos": Vector2(0.610, 0.722)},
	{"name": "Thousand Tarns", "pos": Vector2(0.630, 0.850)},
	{"name": "Drylands", "pos": Vector2(0.100, 0.861)},
	{"name": "Dezun", "pos": Vector2(0.225, 0.871)},
	{"name": "Hazhadal Barrens", "pos": Vector2(0.420, 0.870)},
	{"name": "Gun-Yu", "pos": Vector2(0.765, 0.855)},
	{"name": "New Frontiers", "pos": Vector2(0.875, 0.840)},
]

func _ready() -> void:
	$BackButton.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/PostLogin.tscn"))
	$ShopButton.pressed.connect(_on_shop_pressed)
	$WorldStatusButton.pressed.connect(_on_world_status_pressed)
	$EventsPopup/Margin/VBox/CloseButton.pressed.connect(_on_events_popup_closed)
	_home_zone_id = PlayerManager.get_home_zone_id()
	_home_zone_cleared = PlayerManager.is_home_zone_cleared()
	_style_legend_dots()
	_spawn_region_buttons()
	_style_stats_panel()
	_refresh_stats_panel()
	_maybe_show_queued_events()

func _style_legend_dots() -> void:
	var ready_style := StyleBoxFlat.new()
	ready_style.set_corner_radius_all(5)
	ready_style.set_border_width_all(1)
	ready_style.bg_color = Color(0.3, 0.9, 0.35, 0.95)
	ready_style.border_color = Color(0.1, 0.4, 0.15, 1)
	$Legend/ReadyRow/ReadyDot.add_theme_stylebox_override("panel", ready_style)

	var empty_style := StyleBoxFlat.new()
	empty_style.set_corner_radius_all(5)
	empty_style.set_border_width_all(1)
	empty_style.bg_color = Color(0.5, 0.5, 0.5, 0.5)
	empty_style.border_color = Color(0.2, 0.2, 0.2, 0.5)
	$Legend/EmptyRow/EmptyDot.add_theme_stylebox_override("panel", empty_style)

	var locked_style := StyleBoxFlat.new()
	locked_style.set_corner_radius_all(5)
	locked_style.set_border_width_all(1)
	locked_style.bg_color = Color(0.15, 0.15, 0.15, 0.95)
	locked_style.border_color = Color(0.7, 0.15, 0.15, 1)
	$Legend/LockedRow/LockedDot.add_theme_stylebox_override("panel", locked_style)

func _style_stats_panel() -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0, 0, 0, 0.55)
	panel_style.border_color = Color(1, 1, 1, 0.25)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(8)
	$StatsPanel.add_theme_stylebox_override("panel", panel_style)


## Fills the top-right stats table with the current player's hero,
## level, gold, health and mana. Call again whenever any of those
## change (e.g. after returning from a battle) to keep it in sync.
func _refresh_stats_panel() -> void:
	var hero := PlayerManager.get_recruited_hero()
	var hero_name: String = hero.get("name", "")
	$StatsPanel/Margin/VBox/HeroNameLabel.text = hero_name if hero_name != "" else "No hero yet"

	$StatsPanel/Margin/VBox/StatsGrid/LevelValue.text = str(PlayerManager.get_level())
	$StatsPanel/Margin/VBox/StatsGrid/GoldValue.text = str(PlayerManager.get_gold())

	var stats: Dictionary = hero.get("stats", {})
	var max_hp := int(float(stats.get("hp", 0)))
	var max_mana := int(float(stats.get("mana", 0)))
	var current_hp := int(float(hero.get("current_hp", 0)))
	var current_mana := int(float(hero.get("current_mana", 0)))

	$StatsPanel/Margin/VBox/StatsGrid/HealthValue.text = "%d / %d" % [current_hp, max_hp]
	$StatsPanel/Margin/VBox/StatsGrid/ManaValue.text = "%d / %d" % [current_mana, max_mana]


func _on_shop_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Shop.tscn")


func _on_world_status_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/WorldStatus.tscn")

func _spawn_region_buttons() -> void:
	var screen_size := get_viewport_rect().size
	for region in REGIONS:
		var btn := Button.new()
		btn.text = region["name"]
		btn.name = String(region["name"]).replace(" ", "_").replace("-", "_")
		btn.add_theme_color_override("font_color", Color(0, 0, 0, 0))
		btn.add_theme_color_override("font_hover_color", Color(0, 0, 0, 0))
		btn.add_theme_color_override("font_pressed_color", Color(0, 0, 0, 0))
		btn.add_theme_color_override("font_focus_color", Color(0, 0, 0, 0))
		btn.flat = true
		#btn.modulate = Color(1, 0, 0, 0.6)
		btn.add_theme_font_size_override("font_size", 12)

		var target := Vector2(region["pos"].x * screen_size.x, region["pos"].y * screen_size.y)
		btn.custom_minimum_size = Vector2(18, 18)
		btn.position = target - btn.custom_minimum_size / 2.0

		btn.pressed.connect(_on_region_pressed.bind(region["name"]))
		$RegionButtons.add_child(btn)

		var zone_id := GameManager.zone_id_from_name(region["name"])
		var zone_data := GameManager.get_zone(zone_id)
		var has_heroes: bool = not zone_data.get("heroes", []).is_empty()
		var is_locked: bool = not _home_zone_cleared and zone_id != _home_zone_id
		_add_status_marker(target, has_heroes, is_locked)


## Small colored dot above each region label: dark/red means it's
## locked until the home zone is fully cleared, green means at least
## one hero is set up there and it's playable, gray means it's empty.
func _add_status_marker(target: Vector2, has_heroes: bool, is_locked: bool) -> void:
	var size := 10.0
	var marker := Panel.new()
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.custom_minimum_size = Vector2(size, size)
	marker.position = target - Vector2(size / 2.0, size / 2.0 + 16.0)

	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(int(size / 2.0))
	style.set_border_width_all(1)
	if is_locked:
		style.bg_color = Color(0.15, 0.15, 0.15, 0.95)
		style.border_color = Color(0.7, 0.15, 0.15, 1)
	elif has_heroes:
		style.bg_color = Color(0.3, 0.9, 0.35, 0.95)
		style.border_color = Color(0.1, 0.4, 0.15, 1)
	else:
		style.bg_color = Color(0.5, 0.5, 0.5, 0.5)
		style.border_color = Color(0.2, 0.2, 0.2, 0.5)
	marker.add_theme_stylebox_override("panel", style)

	$RegionButtons.add_child(marker)

func _on_region_pressed(region_name: String) -> void:
	var zone_id := GameManager.zone_id_from_name(region_name)

	if not _home_zone_cleared and zone_id != _home_zone_id:
		var home_zone_name: String = GameManager.get_zone(_home_zone_id).get("name", "your home zone")
		_show_lock_message("Clear " + home_zone_name + " first!")
		return

	GameManager.select_zone_by_name(region_name)
	get_tree().change_scene_to_file("res://scenes/Zone.tscn")


## Brief fade-in/fade-out message shown when clicking a locked zone.
func _show_lock_message(text: String) -> void:
	if _lock_message_tween:
		_lock_message_tween.kill()

	$LockMessageLabel.text = text
	$LockMessageLabel.modulate.a = 1.0

	_lock_message_tween = create_tween()
	_lock_message_tween.tween_interval(1.4)
	_lock_message_tween.tween_property($LockMessageLabel, "modulate:a", 0.0, 0.6)


# ------------------------------------------------------------------
# "While you were away" popup: every rival-hero kill (and zone-wipe)
# that happened in the background gets queued as a one-line event by
# PlayerManager (see its "Event queue" section) - shown here, once,
# the next time the Map loads, then cleared so they never repeat.
# ------------------------------------------------------------------

## Shows the popup if there's anything queued - does nothing otherwise,
## so a Map visit with no news behind it stays silent.
func _maybe_show_queued_events() -> void:
	var events: Array = PlayerManager.get_queued_events()
	if events.is_empty():
		return

	$EventsPopup/Margin/VBox/EventsScroll/EventsLabel.text = "\n".join(events)
	$EventsPopup.popup_centered()


## The queue is only cleared once the player has actually dismissed
## the popup - closing the Map some other way (e.g. the Back button)
## leaves it queued so it shows again next visit instead of silently
## disappearing unseen.
func _on_events_popup_closed() -> void:
	PlayerManager.clear_queued_events()
	$EventsPopup.hide()
