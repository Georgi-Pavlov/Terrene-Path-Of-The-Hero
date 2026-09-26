extends Control

## Self-playing trailer/cutscene sequencer: title card -> a showcase card for
## a handful of curated heroes (pulled live from GameManager.zones by name,
## so their art/stats/skills never drift out of sync with the real data) ->
## a montage of the game's other screens (map, battles, shop) -> an outro
## card, then quits. Built to be captured with Godot's Movie Maker mode
## rather than screen-recorded, so playback speed and frame timing don't
## matter:
##   godot4 --path . res://scenes/Trailer.tscn --write-movie trailer.avi
## The scene quitting itself (see _run_trailer) is what closes the movie
## file once the sequence finishes - no need to time a manual stop.

const FALLBACK_BACKDROP := "res://assets/menu_bg.jpg"

const HERO_HOLD_TIME := 2.4
const HERO_TRANSITION_TIME := 0.7
const MONTAGE_HOLD_TIME := 2.6
const MONTAGE_TRANSITION_TIME := 0.5
const TITLE_HOLD_TIME := 3.0
const OUTRO_HOLD_TIME := 4.0
const CROSSFADE_TIME := 0.8
const KEN_BURNS_ZOOM := 1.08

## Only these heroes get a full portrait showcase card - keeps the trailer
## short instead of running through the entire roster. Matched against
## each hero's "name" field in GameManager.zones. Swap freely.
const FEATURED_HERO_NAMES: Array[String] = [
	"Veyrik",
	"Crystal Maiden",
	"Lone Druid",
]

## The battle mockup shows this hero (must also be a valid key into
## GameManager.zones' per-zone "heroes"/"enemies" lists) fighting their
## home zone's creeps, built from the same data battle.gd itself reads -
## real portrait, real skill names, real hp/mana - rather than a plain
## screenshot, since a static image of the battle background alone
## doesn't communicate "this is a turn-based battle" the way seeing the
## hero, the enemies, the skill bar and the hp/mana/xp bars together does.
const BATTLE_MOCKUP_HERO_NAME := "Veyrik"
const BATTLE_MOCKUP_ZONE_ID := "the_iron_abyss"
const BATTLE_MOCKUP_BACKDROP := "res://assets/battle_areas/Dark_Reef_area.png"
const BATTLE_MOCKUP_CAPTION := "Command Heroes in Turn-Based Tactical Battles"

const SHOP_MOCKUP_BACKDROP := "res://assets/shop_menu.jpg"
const SHOP_MOCKUP_CAPTION := "Gear Up and Grow Stronger"

## Simple screens to show between the hero cards and the mockup beats -
## just a crossfade to that screen's own background art plus a caption.
const MONTAGE_CARDS: Array[Array] = [
	["res://assets/map_bg.jpg", "Explore Every Corner of the World"],
]

# Colors lifted straight from battle.gd's _build_bar_styles()/skill+item
# panel StyleBoxFlats (see Battle.tscn) so the mockup reads as the real
# battle/shop UI rather than a reinterpretation of it.
const HP_FILL_COLOR := Color(0.8, 0.15, 0.15, 1)
const MANA_FILL_COLOR := Color(0.2, 0.4, 0.9, 1)
const XP_FILL_COLOR := Color(0.95, 0.65, 0.1, 1)
const BAR_BG_COLOR := Color(0.1, 0.1, 0.1, 0.7)
const SKILLS_PANEL_BG := Color(0.14, 0.09, 0.02, 0.85)
const SKILLS_PANEL_BORDER := Color(0.85, 0.65, 0.2, 0.85)
const ITEMS_PANEL_BG := Color(0.08, 0.1, 0.09, 0.85)
const ITEMS_PANEL_BORDER := Color(0.3, 0.55, 0.5, 0.8)

@onready var _backdrop_a: TextureRect = $BackdropA
@onready var _backdrop_b: TextureRect = $BackdropB
@onready var _portrait: TextureRect = $HeroPortrait
@onready var _hero_name_label: Label = $HeroName
@onready var _hero_role_label: Label = $HeroRole
@onready var _title_card: Control = $TitleCard
@onready var _feature_card: Control = $FeatureCard
@onready var _feature_label: Label = $FeatureCard/FeatureLabel
@onready var _outro_card: Control = $OutroCard
@onready var _mockup_layer: Control = $MockupLayer

var _front_backdrop: TextureRect
var _back_backdrop: TextureRect
var _skip_requested := false


func _ready() -> void:
	_front_backdrop = _backdrop_a
	_back_backdrop = _backdrop_b
	_hide_all_instant()
	_run_trailer()


func _unhandled_input(event: InputEvent) -> void:
	# Convenience for previewing in the editor - has no effect while the
	# scene is being captured headlessly with --write-movie, since there's
	# no real input during a movie render.
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept"):
		_skip_requested = true


func _hide_all_instant() -> void:
	_backdrop_a.modulate.a = 0.0
	_backdrop_b.modulate.a = 0.0
	_portrait.modulate.a = 0.0
	_hero_name_label.modulate.a = 0.0
	_hero_role_label.modulate.a = 0.0
	_title_card.modulate.a = 0.0
	_feature_card.modulate.a = 0.0
	_outro_card.modulate.a = 0.0
	_mockup_layer.modulate.a = 0.0


func _run_trailer() -> void:
	await get_tree().process_frame

	await _play_title_card()
	for hero in _collect_featured_heroes():
		if _skip_requested:
			break
		await _play_hero_card(hero)

	if not _skip_requested:
		await _play_battle_mockup_card()

	for card in MONTAGE_CARDS:
		if _skip_requested:
			break
		await _play_montage_card(card[0], card[1])

	if not _skip_requested:
		await _play_shop_mockup_card()

	await _play_outro_card()
	get_tree().quit()


## Every hero dictionary straight out of GameManager.zones, keyed by name -
## shared by the hero showcase cards and the battle mockup so both pull
## from the exact same live data instead of two separate lookups drifting
## apart from each other.
func _heroes_by_name() -> Dictionary:
	var by_name: Dictionary = {}
	for zone_id in GameManager.zones.keys():
		var zone: Dictionary = GameManager.zones[zone_id]
		for hero in zone.get("heroes", []):
			by_name[hero.get("name", "")] = hero
	return by_name


## Looks up each name in FEATURED_HERO_NAMES against the live hero data in
## GameManager.zones (portrait, home backdrop, role, headline skill)
## instead of hardcoding their stats here, so the showcase card always
## matches whatever's actually in the game. Keeps FEATURED_HERO_NAMES'
## order, and silently skips a name that no longer matches any hero.
func _collect_featured_heroes() -> Array[Dictionary]:
	var by_name: Dictionary = _heroes_by_name()

	var heroes: Array[Dictionary] = []
	for wanted_name in FEATURED_HERO_NAMES:
		var hero: Dictionary = by_name.get(wanted_name, {})
		if hero.is_empty():
			continue
		heroes.append({
			"name": hero.get("name", "Hero"),
			"image": hero.get("image", ""),
			"background": hero.get("background", ""),
			"range_type": hero.get("range_type", ""),
			"main_stat": hero.get("main_stat", ""),
			"headline_skill": _headline_skill_name(hero.get("skills", [])),
		})
	return heroes


## Prefers the hero's ultimate for the subtitle line since it's the most
## trailer-worthy thing about them; falls back to their first skill.
func _headline_skill_name(skills: Array) -> String:
	for skill in skills:
		if skill.get("type", "") == "ultimate":
			return skill.get("name", "")
	if skills.size() > 0:
		return skills[0].get("name", "")
	return ""


func _play_title_card() -> void:
	await _crossfade_backdrop(FALLBACK_BACKDROP)
	await _fade_in(_title_card, CROSSFADE_TIME)
	await _hold(TITLE_HOLD_TIME)
	await _fade_out(_title_card, CROSSFADE_TIME)


func _play_hero_card(hero: Dictionary) -> void:
	var backdrop_path: String = hero.get("background", "")
	if backdrop_path == "":
		backdrop_path = FALLBACK_BACKDROP
	await _crossfade_backdrop(backdrop_path)

	var portrait_texture: Texture2D = _load_texture(hero.get("image", ""))
	_portrait.texture = portrait_texture
	_portrait.pivot_offset = _portrait.size / 2.0
	_portrait.modulate.a = 0.0
	_portrait.position.x += 60.0

	_hero_name_label.text = hero.get("name", "")
	var role_bits: PackedStringArray = []
	if hero.get("range_type", "") != "":
		role_bits.append(String(hero["range_type"]))
	if hero.get("main_stat", "") != "":
		role_bits.append(String(hero["main_stat"]) + " Hero")
	if hero.get("headline_skill", "") != "":
		role_bits.append("Ultimate: " + String(hero["headline_skill"]))
	_hero_role_label.text = " | ".join(role_bits)

	var in_tween := create_tween().set_parallel(true)
	in_tween.tween_property(_portrait, "modulate:a", 1.0, HERO_TRANSITION_TIME)
	in_tween.tween_property(_portrait, "position:x", _portrait.position.x - 60.0, HERO_TRANSITION_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	in_tween.tween_property(_hero_name_label, "modulate:a", 1.0, HERO_TRANSITION_TIME).set_delay(0.15)
	in_tween.tween_property(_hero_role_label, "modulate:a", 1.0, HERO_TRANSITION_TIME).set_delay(0.3)
	await in_tween.finished

	await _hold(HERO_HOLD_TIME)

	var out_tween := create_tween().set_parallel(true)
	out_tween.tween_property(_portrait, "modulate:a", 0.0, HERO_TRANSITION_TIME)
	out_tween.tween_property(_hero_name_label, "modulate:a", 0.0, HERO_TRANSITION_TIME)
	out_tween.tween_property(_hero_role_label, "modulate:a", 0.0, HERO_TRANSITION_TIME)
	await out_tween.finished


## Crossfades the backdrop to another screen's own art (map/shop/battle)
## and overlays a short caption - same beat as a hero card but without a
## portrait, so it reads as "here's another part of the game" rather than
## a repeat of the hero showcase.
func _play_montage_card(backdrop_path: String, caption: String) -> void:
	await _crossfade_backdrop(backdrop_path)
	_feature_label.text = caption
	await _fade_in(_feature_card, MONTAGE_TRANSITION_TIME)
	await _hold(MONTAGE_HOLD_TIME)
	await _fade_out(_feature_card, MONTAGE_TRANSITION_TIME)


## Builds a mock battle screen straight from the same data battle.gd
## reads - BATTLE_MOCKUP_HERO_NAME's real portrait/stats/skill names, and
## BATTLE_MOCKUP_ZONE_ID's real enemy portraits - instead of instancing
## Battle.tscn itself (which expects a real in-progress run: a recruited
## hero, a selected zone, saved hp/mana on disk). Freed by
## _clear_mockup_layer() once the beat ends.
func _play_battle_mockup_card() -> void:
	await _crossfade_backdrop(BATTLE_MOCKUP_BACKDROP)
	_build_battle_mockup()
	await _fade_in(_mockup_layer, MONTAGE_TRANSITION_TIME)
	await _hold(MONTAGE_HOLD_TIME + 1.5)
	await _fade_out(_mockup_layer, MONTAGE_TRANSITION_TIME)
	_clear_mockup_layer()


## Every pixel position/size below is a fraction of the actual render
## resolution (read at build time via _vp()), not a fixed 1280x720
## assumption - lets the exact same scene render a 16:9 landscape cut or
## a 9:16 vertical cut (e.g. for a Facebook/Instagram Story) just by
## passing a different --resolution on the command line.
func _build_battle_mockup() -> void:
	var vp := _vp()
	var hero: Dictionary = _heroes_by_name().get(BATTLE_MOCKUP_HERO_NAME, {})
	var stats: Dictionary = hero.get("stats", {})
	var zone: Dictionary = GameManager.get_zone(BATTLE_MOCKUP_ZONE_ID)
	var enemies: Array = zone.get("enemies", [])
	var portrait_mode: bool = vp.y > vp.x

	_mockup_layer.add_child(_build_caption_banner(BATTLE_MOCKUP_CAPTION))

	# Hero portrait, left side, facing right same as its normal art.
	var hero_size: float = vp.x * (0.5 if portrait_mode else 0.24)
	var hero_texture: Texture2D = _load_texture(hero.get("image", ""))
	if hero_texture != null:
		var hero_rect := TextureRect.new()
		hero_rect.texture = hero_texture
		hero_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		hero_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hero_rect.position = Vector2(vp.x * 0.06, vp.y * (0.36 if portrait_mode else 0.3))
		hero_rect.size = Vector2(hero_size, hero_size)
		_mockup_layer.add_child(hero_rect)

	# Up to two of the zone's creeps, right side, mirrored to face the
	# hero (battle.gd flips enemy art the same way when it spawns them).
	var shown_images: Dictionary = {}
	var creep_slot := 0
	var creep_size: float = vp.x * (0.32 if portrait_mode else 0.15)
	var creep_positions: Array[Vector2] = [
		Vector2(vp.x * (0.55 if portrait_mode else 0.59), vp.y * (0.2 if portrait_mode else 0.21)),
		Vector2(vp.x * (0.62 if portrait_mode else 0.73), vp.y * (0.36 if portrait_mode else 0.44)),
	]
	for enemy in enemies:
		var image_path: String = enemy.get("image", "")
		if image_path == "" or shown_images.has(image_path):
			continue
		shown_images[image_path] = true

		var creep_texture: Texture2D = _load_texture(image_path)
		if creep_texture == null:
			continue
		var creep_rect := TextureRect.new()
		creep_rect.texture = creep_texture
		creep_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		creep_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		creep_rect.flip_h = true
		creep_rect.position = creep_positions[creep_slot]
		creep_rect.size = Vector2(creep_size, creep_size)
		_mockup_layer.add_child(creep_rect)

		creep_slot += 1
		if creep_slot >= creep_positions.size():
			break

	_mockup_layer.add_child(_build_bars_box(stats, vp))
	_mockup_layer.add_child(_build_skills_row(hero.get("skills", []), vp))


## Top-left hp/mana/xp bars, same fill colors as battle.gd's own
## _build_bar_styles(). Values are just an illustrative mid-fight snapshot
## (roughly 70%/55%/40% full) since this isn't a real running battle.
func _build_bars_box(stats: Dictionary, vp: Vector2) -> Control:
	var bar_size := Vector2(vp.x * 0.62, vp.y * 0.026)

	var box := VBoxContainer.new()
	box.position = Vector2(vp.x * 0.05, vp.y * 0.12)
	box.custom_minimum_size = Vector2(bar_size.x, 0)
	box.add_theme_constant_override("separation", vp.y * 0.008)

	var max_hp: float = float(stats.get("hp", 100))
	var max_mana: float = float(stats.get("mana", 100))
	box.add_child(_build_stat_bar(max_hp, max_hp * 0.72, HP_FILL_COLOR, bar_size))
	box.add_child(_build_stat_bar(max_mana, max_mana * 0.55, MANA_FILL_COLOR, bar_size))
	box.add_child(_build_stat_bar(100.0, 40.0, XP_FILL_COLOR, bar_size))
	return box


func _build_stat_bar(max_value: float, value: float, fill_color: Color, bar_size: Vector2) -> Control:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = bar_size
	bar.max_value = max_value
	bar.value = value
	bar.show_percentage = false

	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", fill)

	var bg := StyleBoxFlat.new()
	bg.bg_color = BAR_BG_COLOR
	bg.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", bg)

	var value_label := Label.new()
	value_label.text = "%d / %d" % [int(value), int(max_value)]
	value_label.add_theme_font_size_override("font_size", max(12, int(bar_size.y * 0.6)))
	value_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	value_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(value_label)

	return bar


## Bottom skill bar - plain text buttons, same as battle.gd's own
## _populate_skill_buttons() (skills have no per-icon art in this project).
func _build_skills_row(skills: Array, vp: Vector2) -> Control:
	var panel_size := Vector2(vp.x * 0.88, vp.y * 0.075)

	var panel := PanelContainer.new()
	panel.position = Vector2((vp.x - panel_size.x) / 2.0, vp.y * 0.84)
	panel.size = panel_size

	var style := StyleBoxFlat.new()
	style.bg_color = SKILLS_PANEL_BG
	style.border_color = SKILLS_PANEL_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", vp.x * 0.015)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(row)

	var button_count: int = max(1, skills.size())
	var button_width: float = (panel_size.x - vp.x * 0.015 * (button_count - 1) - vp.x * 0.04) / button_count
	for skill in skills:
		var btn := Button.new()
		btn.text = String(skill.get("name", "Skill"))
		btn.custom_minimum_size = Vector2(button_width, panel_size.y * 0.62)
		btn.add_theme_font_size_override("font_size", max(11, int(vp.x * 0.016)))
		btn.disabled = true
		row.add_child(btn)

	return panel


## Builds a mock shop screen showing every real item from
## GameManager.items (icon, name, cost) laid out in a grid, the way
## Shop.gd itself builds item cards - the earlier cut only showed the
## empty shop background with no items on it.
func _play_shop_mockup_card() -> void:
	await _crossfade_backdrop(SHOP_MOCKUP_BACKDROP)
	_build_shop_mockup()
	await _fade_in(_mockup_layer, MONTAGE_TRANSITION_TIME)
	await _hold(MONTAGE_HOLD_TIME + 1.0)
	await _fade_out(_mockup_layer, MONTAGE_TRANSITION_TIME)
	_clear_mockup_layer()


func _build_shop_mockup() -> void:
	var vp := _vp()
	var portrait_mode: bool = vp.y > vp.x

	_mockup_layer.add_child(_build_caption_banner(SHOP_MOCKUP_CAPTION))

	var panel_pos := Vector2(vp.x * 0.06, vp.y * 0.12)
	var panel_size := Vector2(vp.x * 0.88, vp.y * 0.74)

	var panel := PanelContainer.new()
	panel.position = panel_pos
	panel.size = panel_size

	var style := StyleBoxFlat.new()
	style.bg_color = ITEMS_PANEL_BG
	style.border_color = ITEMS_PANEL_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)
	_mockup_layer.add_child(panel)

	var margin := MarginContainer.new()
	var margin_px: int = int(vp.x * 0.02)
	margin.add_theme_constant_override("margin_left", margin_px)
	margin.add_theme_constant_override("margin_top", margin_px)
	margin.add_theme_constant_override("margin_right", margin_px)
	margin.add_theme_constant_override("margin_bottom", margin_px)
	panel.add_child(margin)

	var grid := GridContainer.new()
	grid.columns = 2 if portrait_mode else 4
	grid.add_theme_constant_override("h_separation", int(vp.x * 0.018))
	grid.add_theme_constant_override("v_separation", int(vp.y * 0.02))
	margin.add_child(grid)

	var card_width: float = (panel_size.x - margin_px * 2.0) / grid.columns - vp.x * 0.018
	for item in GameManager.items.values():
		grid.add_child(_build_item_card(item, card_width))


func _build_item_card(item: Dictionary, card_width: float) -> Control:
	var card := VBoxContainer.new()
	card.custom_minimum_size = Vector2(card_width, card_width * 0.85)
	card.alignment = BoxContainer.ALIGNMENT_CENTER

	var icon_size: float = card_width * 0.4
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(icon_size, icon_size)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var icon_texture: Texture2D = _load_texture(item.get("image", ""))
	if icon_texture != null:
		icon.texture = icon_texture
	card.add_child(icon)

	var name_label := Label.new()
	name_label.text = String(item.get("name", ""))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_label.add_theme_font_size_override("font_size", max(13, int(card_width * 0.075)))
	name_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	card.add_child(name_label)

	var cost_label := Label.new()
	cost_label.text = "%d Gold" % int(item.get("cost", 0))
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.add_theme_font_size_override("font_size", max(12, int(card_width * 0.07)))
	cost_label.add_theme_color_override("font_color", Color(0.95, 0.8, 0.3, 1))
	card.add_child(cost_label)

	return card


## Full-width translucent strip across the top of the mockup beats,
## holding their caption - kept separate from the hero-card / plain
## montage-card captions since those two beats fill the rest of the
## screen with real UI and need the text out of the way at the top.
func _build_caption_banner(text: String) -> Control:
	var vp := _vp()

	var panel := PanelContainer.new()
	panel.position = Vector2(0, 0)
	panel.size = Vector2(vp.x, vp.y * 0.065)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.55)
	panel.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.add_theme_font_size_override("font_size", max(18, int(vp.x * 0.026)))
	label.add_theme_color_override("font_color", Color(1, 0.92, 0.75, 1))
	panel.add_child(label)

	return panel


func _clear_mockup_layer() -> void:
	for child in _mockup_layer.get_children():
		child.queue_free()


func _vp() -> Vector2:
	return get_viewport_rect().size


func _play_outro_card() -> void:
	await _crossfade_backdrop(FALLBACK_BACKDROP)
	await _fade_in(_outro_card, CROSSFADE_TIME)
	await _hold(OUTRO_HOLD_TIME)


func _crossfade_backdrop(texture_path: String) -> void:
	_back_backdrop.texture = _load_texture(texture_path)
	_back_backdrop.modulate.a = 0.0
	_back_backdrop.scale = Vector2.ONE
	_back_backdrop.pivot_offset = _back_backdrop.size / 2.0

	var tween := create_tween().set_parallel(true)
	tween.tween_property(_back_backdrop, "modulate:a", 1.0, CROSSFADE_TIME)
	tween.tween_property(_front_backdrop, "modulate:a", 0.0, CROSSFADE_TIME)
	tween.tween_property(_back_backdrop, "scale", Vector2.ONE * KEN_BURNS_ZOOM, HERO_HOLD_TIME + CROSSFADE_TIME)
	await tween.finished

	var swap := _front_backdrop
	_front_backdrop = _back_backdrop
	_back_backdrop = swap


func _fade_in(node: CanvasItem, duration: float) -> void:
	var tween := create_tween()
	tween.tween_property(node, "modulate:a", 1.0, duration)
	await tween.finished


func _fade_out(node: CanvasItem, duration: float) -> void:
	var tween := create_tween()
	tween.tween_property(node, "modulate:a", 0.0, duration)
	await tween.finished


func _hold(seconds: float) -> void:
	if _skip_requested:
		return
	await get_tree().create_timer(seconds).timeout


func _load_texture(path: String) -> Texture2D:
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path)
