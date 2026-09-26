extends Control

# The player can only enter their own recruited hero's home zone until
# it's fully cleared (final stage beaten AND every hero in it defeated
# - see PlayerManager.is_home_zone_cleared()). Computed once here so
# _spawn_region_buttons() and _on_region_pressed() agree on the same
# snapshot for this Map visit.
var _home_zone_id: String = ""
var _home_zone_cleared: bool = true

var _lock_message_tween: Tween

# Each map label, by zone id (a key of GameManager.zones) - its text is
# that zone's own "name", so renaming a zone there never breaks the map.
# "pos" is the top-centre of the zone's name plate painted on map_bg.jpg
# and "size" the plate's size, both as fractions of the screen - the
# whole plate is the zone's button, and its status gem sits in the
# socket painted at the plate's left end.
# Centre of that socket, from the plate's left edge, as a fraction of
# the screen width (12 px of the 1636 px wide map_bg.jpg).
const PLATE_GEM_X := 12.0 / 1636.0

const REGIONS := [
	{"id": "the_veiled_reach", "pos": Vector2(0.500, 0.074), "size": Vector2(0.109, 0.034)},
	{"id": "the_iron_abyss", "pos": Vector2(0.292, 0.114), "size": Vector2(0.097, 0.035)},
	{"id": "the_elderwild", "pos": Vector2(0.430, 0.150), "size": Vector2(0.097, 0.034)},
	{"id": "kingdom_of_morvain", "pos": Vector2(0.644, 0.131), "size": Vector2(0.080, 0.043)},
	{"id": "the_ironbound_isles", "pos": Vector2(0.321, 0.221), "size": Vector2(0.097, 0.043)},
	{"id": "frostspire", "pos": Vector2(0.523, 0.210), "size": Vector2(0.076, 0.055)},
	{"id": "the_everfrost", "pos": Vector2(0.617, 0.228), "size": Vector2(0.095, 0.050)},
	{"id": "the_fall_of_empyrean", "pos": Vector2(0.814, 0.239), "size": Vector2(0.079, 0.048)},
	{"id": "the_verdant_scar", "pos": Vector2(0.403, 0.299), "size": Vector2(0.111, 0.047)},
	{"id": "the_sundered_peaks", "pos": Vector2(0.598, 0.305), "size": Vector2(0.092, 0.047)},
	{"id": "drowned_empire", "pos": Vector2(0.283, 0.325), "size": Vector2(0.106, 0.047)},
	{"id": "the_blackbloom", "pos": Vector2(0.450, 0.376), "size": Vector2(0.104, 0.048)},
	{"id": "the_wildreach", "pos": Vector2(0.583, 0.371), "size": Vector2(0.099, 0.034)},
	{"id": "wyrmfall", "pos": Vector2(0.798, 0.342), "size": Vector2(0.076, 0.048)},
	{"id": "the_bronze_dominion", "pos": Vector2(0.522, 0.450), "size": Vector2(0.087, 0.048)},
	{"id": "the_hollowlands", "pos": Vector2(0.642, 0.459), "size": Vector2(0.112, 0.034)},
	{"id": "the_rotbloom", "pos": Vector2(0.229, 0.469), "size": Vector2(0.094, 0.034)},
	{"id": "vaelith", "pos": Vector2(0.914, 0.481), "size": Vector2(0.083, 0.035)},
	{"id": "carthane", "pos": Vector2(0.500, 0.537), "size": Vector2(0.071, 0.034)},
	{"id": "aureth", "pos": Vector2(0.737, 0.523), "size": Vector2(0.076, 0.035)},
	{"id": "the_stonewake", "pos": Vector2(0.312, 0.563), "size": Vector2(0.099, 0.032)},
	{"id": "scorchlands", "pos": Vector2(0.433, 0.630), "size": Vector2(0.087, 0.034)},
	{"id": "the_wargrave", "pos": Vector2(0.535, 0.639), "size": Vector2(0.095, 0.048)},
	{"id": "the_blackveins", "pos": Vector2(0.641, 0.599), "size": Vector2(0.099, 0.046)},
	{"id": "kharuun", "pos": Vector2(0.101, 0.610), "size": Vector2(0.070, 0.033)},
	{"id": "veyraku", "pos": Vector2(0.756, 0.700), "size": Vector2(0.079, 0.033)},
	{"id": "velashan", "pos": Vector2(0.866, 0.687), "size": Vector2(0.079, 0.033)},
	{"id": "the_stonewild", "pos": Vector2(0.932, 0.635), "size": Vector2(0.097, 0.033)},
	{"id": "kharazhul", "pos": Vector2(0.166, 0.686), "size": Vector2(0.081, 0.049)},
	{"id": "the_sandgrave", "pos": Vector2(0.301, 0.727), "size": Vector2(0.097, 0.034)},
	{"id": "qadaris", "pos": Vector2(0.401, 0.729), "size": Vector2(0.078, 0.052)},
	{"id": "thundersteppe", "pos": Vector2(0.559, 0.767), "size": Vector2(0.097, 0.032)},
	{"id": "gloamwood", "pos": Vector2(0.641, 0.691), "size": Vector2(0.083, 0.042)},
	{"id": "the_drowned_marches", "pos": Vector2(0.668, 0.850), "size": Vector2(0.091, 0.049)},
	{"id": "the_sunscar", "pos": Vector2(0.086, 0.835), "size": Vector2(0.086, 0.033)},
	{"id": "the_veilbound", "pos": Vector2(0.235, 0.864), "size": Vector2(0.095, 0.033)},
	{"id": "glasslands", "pos": Vector2(0.455, 0.844), "size": Vector2(0.079, 0.052)},
	{"id": "yun_shai", "pos": Vector2(0.821, 0.814), "size": Vector2(0.072, 0.034)},
	{"id": "the_last_horizon", "pos": Vector2(0.906, 0.864), "size": Vector2(0.110, 0.033)},
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

	if TutorialManager.is_active and TutorialManager.current_stage == 2:
		TutorialManager.show_popup(
			"Head to the Shop and restock before going anywhere else.",
			func(): get_tree().change_scene_to_file("res://scenes/Shop.tscn")
		)

func _style_legend_dots() -> void:
	for pair in [[$Legend/ReadyRow/ReadyDot, "ready"], [$Legend/EmptyRow/EmptyDot, "empty"], [$Legend/LockedRow/LockedDot, "locked"]]:
		var dot: Panel = pair[0]
		dot.custom_minimum_size = Vector2(14, 14)
		dot.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		dot.add_child(_make_gem(pair[1], 14.0))

	# Dark wood and bronze frame behind the legend, drawn by the legend
	# itself so it always fits whatever size the rows lay out to.
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0.055, 0.035, 0.028, 0.88)
	frame.border_color = Color(0.55, 0.4, 0.22, 1)
	frame.set_border_width_all(2)
	frame.set_corner_radius_all(3)
	frame.shadow_color = Color(0, 0, 0, 0.6)
	frame.shadow_size = 8
	var legend: Control = $Legend
	legend.draw.connect(func(): legend.draw_style_box(frame, Rect2(Vector2(-12, -9), legend.size + Vector2(24, 18))))
	legend.queue_redraw()


## Round "gem" used for a zone's status, both on its map plate and in
## the legend: "ready" = at least one hero there (emerald, glowing and
## pulsing), "empty" = no heroes yet (dull stone), "locked" = locked
## until the home zone is cleared (dark, blood-red rim). Drawn by hand
## rather than with a rounded StyleBoxFlat, which renders a dark ring
## artefact at this tiny size.
const GEM_COLORS := {
	# fill, setting (rim), glow (alpha 0 = none)
	"ready": [Color(0.3, 0.95, 0.45), Color(0.22, 0.15, 0.07), Color(0.3, 1.0, 0.45, 1.0)],
	"empty": [Color(0.58, 0.55, 0.5), Color(0.22, 0.15, 0.07), Color(0, 0, 0, 0)],
	"locked": [Color(0.14, 0.05, 0.05), Color(0.8, 0.15, 0.12), Color(0.8, 0.1, 0.05, 0.6)],
}

var _ready_gems: Array[Control] = []
var _gem_time := 0.0


func _process(delta: float) -> void:
	if _ready_gems.is_empty():
		return
	_gem_time += delta
	for gem in _ready_gems:
		gem.queue_redraw()


func _make_gem(state: String, diameter: float) -> Control:
	var gem := Control.new()
	gem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gem.custom_minimum_size = Vector2.ONE * diameter
	gem.size = gem.custom_minimum_size
	gem.draw.connect(_draw_gem.bind(gem, state))
	if state == "ready":
		_ready_gems.append(gem)
	return gem


func _draw_gem(gem: Control, state: String) -> void:
	var cols: Array = GEM_COLORS[state]
	var c := gem.size / 2.0
	var r: float = min(gem.size.x, gem.size.y) / 2.0
	var glow: Color = cols[2]
	if glow.a > 0.0:
		var pulse := 1.0
		if state == "ready":
			pulse = 0.6 + 0.4 * sin(_gem_time * 2.8)
		for i in 3:
			var g := glow
			g.a = glow.a * 0.22 * (1.0 - i / 3.0) * pulse
			gem.draw_circle(c, r + 1.5 + i * 1.6, g)
	gem.draw_circle(c, r, cols[1])
	gem.draw_circle(c, r - 2.0, cols[0])
	# small glint so it reads as a cut stone
	gem.draw_circle(c + Vector2(-r, -r) * 0.28, r * 0.25, Color(1, 1, 1, 0.5))


func _style_stats_panel() -> void:
	# Dark wood and tarnished bronze, matching the Shop's panels.
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.055, 0.035, 0.028, 0.9)
	panel_style.border_color = Color(0.55, 0.4, 0.22, 1)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(3)
	panel_style.shadow_color = Color(0, 0, 0, 0.6)
	panel_style.shadow_size = 10
	$StatsPanel.add_theme_stylebox_override("panel", panel_style)

	var divider := StyleBoxLine.new()
	divider.color = Color(0.55, 0.4, 0.22, 0.7)
	divider.thickness = 1
	$StatsPanel/Margin/VBox/Separator.add_theme_stylebox_override("separator", divider)


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
		btn.text = str(GameManager.get_zone(region["id"]).get("name", region["id"]))
		btn.name = String(region["id"])
		btn.add_theme_color_override("font_color", Color(0, 0, 0, 0))
		btn.add_theme_color_override("font_hover_color", Color(0, 0, 0, 0))
		btn.add_theme_color_override("font_pressed_color", Color(0, 0, 0, 0))
		btn.add_theme_color_override("font_focus_color", Color(0, 0, 0, 0))
		btn.flat = true
		#btn.modulate = Color(1, 0, 0, 0.6)
		btn.add_theme_font_size_override("font_size", 12)

		var target := Vector2(region["pos"].x * screen_size.x, region["pos"].y * screen_size.y)
		var plate_size := Vector2(region["size"].x * screen_size.x, region["size"].y * screen_size.y)
		btn.clip_text = true  # the (invisible) text must not widen the button past its plate
		btn.custom_minimum_size = plate_size
		btn.size = plate_size
		btn.position = Vector2(target.x - plate_size.x / 2.0, target.y - 2.0)

		btn.pressed.connect(_on_region_pressed.bind(region["id"]))
		$RegionButtons.add_child(btn)

		var zone_id: String = region["id"]
		var zone_data := GameManager.get_zone(zone_id)
		var has_heroes: bool = not zone_data.get("heroes", []).is_empty()
		var is_locked: bool = not _home_zone_cleared and zone_id != _home_zone_id
		_plate_rects[zone_id] = Rect2(btn.position, plate_size)
		_gems[zone_id] = _add_status_marker(btn.position + Vector2(PLATE_GEM_X * screen_size.x, plate_size.y / 2.0), has_heroes, is_locked)

	if _plate_rects.has(_home_zone_id):
		_add_home_aura(_plate_rects[_home_zone_id])
	$MapFX.set_clear_rects(_plate_rects.values())


## Status gem set into the socket at the left end of each zone's name
## plate (see _make_gem). `socket` is the socket's centre.
func _add_status_marker(socket: Vector2, has_heroes: bool, is_locked: bool) -> Control:
	var state := "locked" if is_locked else ("ready" if has_heroes else "empty")
	var gem := _make_gem(state, 12.0)
	gem.position = socket - gem.size / 2.0
	$RegionButtons.add_child(gem)
	return gem


# Each zone's plate rect and status gem, by zone id, for the effects below.
var _plate_rects: Dictionary = {}
var _gems: Dictionary = {}
var _locked_flash_tweens: Dictionary = {}


## Ember aura pulsing around the player's own hero's home zone plate.
func _add_home_aura(rect: Rect2) -> void:
	var style := StyleBoxFlat.new()
	style.draw_center = false
	style.set_border_width_all(2)
	style.border_color = Color(1.0, 0.6, 0.25, 0.95)
	style.set_corner_radius_all(4)
	style.shadow_color = Color(1.0, 0.45, 0.1, 0.55)
	style.shadow_size = 5
	var aura := Panel.new()
	aura.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aura.add_theme_stylebox_override("panel", style)
	aura.position = rect.position - Vector2(3, 3)
	aura.size = rect.size + Vector2(6, 6)
	$RegionButtons.add_child(aura)
	$RegionButtons.move_child(aura, 0)
	var tw := create_tween().set_loops()
	tw.tween_property(style, "shadow_size", 12, 1.3).set_trans(Tween.TRANS_SINE)
	tw.tween_property(style, "shadow_size", 4, 1.3).set_trans(Tween.TRANS_SINE)


## Tapping a locked zone: a blood-red outline flashes around its plate
## and its gem shakes, next to the "Clear ... first!" message.
func _flash_locked_zone(zone_id: String) -> void:
	if not _plate_rects.has(zone_id):
		return
	if _locked_flash_tweens.has(zone_id):
		var old: Array = _locked_flash_tweens[zone_id]
		old[0].kill()
		old[1].queue_free()
		old[2].position = old[3]
	var rect: Rect2 = _plate_rects[zone_id]
	var gem: Control = _gems[zone_id]
	var gem_home := gem.position

	var style := StyleBoxFlat.new()
	style.draw_center = false
	style.set_border_width_all(2)
	style.border_color = Color(0.9, 0.12, 0.08, 1)
	style.set_corner_radius_all(4)
	style.shadow_color = Color(0.9, 0.1, 0.05, 0.5)
	style.shadow_size = 6
	var flash := Panel.new()
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.add_theme_stylebox_override("panel", style)
	flash.position = rect.position - Vector2(3, 3)
	flash.size = rect.size + Vector2(6, 6)
	$RegionButtons.add_child(flash)

	var tw := create_tween()
	for dx in [5.0, -5.0, 4.0, -3.0, 2.0, 0.0]:
		tw.tween_property(gem, "position:x", gem_home.x + dx, 0.04)
		tw.parallel().tween_property(flash, "position:x", rect.position.x - 3 + dx, 0.04)
	tw.tween_property(flash, "modulate:a", 0.0, 0.45)
	tw.tween_callback(func():
		flash.queue_free()
		_locked_flash_tweens.erase(zone_id))
	_locked_flash_tweens[zone_id] = [tw, flash, gem, gem_home]

func _on_region_pressed(zone_id: String) -> void:

	if not _home_zone_cleared and zone_id != _home_zone_id:
		var home_zone_name: String = GameManager.get_zone(_home_zone_id).get("name", "your home zone")
		_show_lock_message("Clear " + home_zone_name + " first!")
		_flash_locked_zone(zone_id)
		return

	GameManager.select_zone(zone_id)
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

	var list: VBoxContainer = $EventsPopup/Margin/VBox/EventsScroll/EventsList
	for event in events:
		list.add_child(_build_event_row(str(event)))
	$EventsPopup.popup_centered()


## One line of the "While you were away..." list: a bronze bullet, then
## the event text, which wraps with a hanging indent under itself.
func _build_event_row(text: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var bullet := Label.new()
	bullet.text = "•"
	bullet.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	bullet.add_theme_color_override("font_color", Color(0.72, 0.52, 0.28, 1))
	bullet.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	bullet.add_theme_constant_override("outline_size", 2)
	bullet.add_theme_font_size_override("font_size", 15)

	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color(0.86, 0.8, 0.7, 1))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 2)
	label.add_theme_font_size_override("font_size", 15)

	row.add_child(bullet)
	row.add_child(label)
	return row


## The queue is only cleared once the player has actually dismissed
## the popup - closing the Map some other way (e.g. the Back button)
## leaves it queued so it shows again next visit instead of silently
## disappearing unseen.
func _on_events_popup_closed() -> void:
	PlayerManager.clear_queued_events()
	$EventsPopup.hide()
