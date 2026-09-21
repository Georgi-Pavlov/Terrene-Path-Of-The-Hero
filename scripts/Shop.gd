extends Control

@onready var gold_value_label: Label = $GoldPanel/GoldMargin/GoldRow/GoldValueLabel
@onready var items_grid: GridContainer = $ShopItemsPanel/ItemsMargin/ItemsVBox/ItemsGrid
@onready var title_label: Label = $ShopItemsPanel/ItemsMargin/ItemsVBox/TitleRow/TitleLabel
@onready var prev_page_button: Button = $ShopItemsPanel/ItemsMargin/ItemsVBox/TitleRow/PrevPageButton
@onready var next_page_button: Button = $ShopItemsPanel/ItemsMargin/ItemsVBox/TitleRow/NextPageButton
@onready var message_label: Label = $MessageLabel
@onready var back_button: Button = $BackButton

@onready var details_name_label: Label = $ItemDetailsPanel/DetailsMargin/DetailsVBox/DetailsNameLabel
@onready var details_description_label: Label = $ItemDetailsPanel/DetailsMargin/DetailsVBox/DetailsDescriptionLabel
@onready var details_cost_label: Label = $ItemDetailsPanel/DetailsMargin/DetailsVBox/DetailsCostLabel
@onready var details_buy_button: Button = $ItemDetailsPanel/DetailsMargin/DetailsVBox/DetailsBuyButton

@onready var sell_button: Button = $SellButton
@onready var sell_popup: PanelContainer = $SellPopup
@onready var sell_items_list: VBoxContainer = $SellPopup/SellMargin/SellVBox/SellItemsList
@onready var sell_close_button: Button = $SellPopup/SellMargin/SellVBox/SellCloseButton

# 3 items per row, 2 rows per page (matches ItemsGrid's column count).
const ITEMS_PER_PAGE := 6

# Which page of GameManager.SHOP_ITEM_IDS is currently shown - page 0
# is items [0:6), page 1 is [6:12), etc.
var _current_page: int = 0

# item_id -> how many are left this visit, for EVERY shop item (not
# just the current page) so stock survives flipping pages. Intentionally
# not saved anywhere - stock refills whenever the player re-enters the shop.
var _stock: Dictionary = {}

# item_id -> {button, cost_label, stock_label}, so a purchase can
# update just that one card instead of rebuilding the whole page.
var _cards: Dictionary = {}

# Which item's details are currently shown in the panel below the
# merchant - "" means nothing selected yet.
var _selected_item_id: String = ""

var _message_tween: Tween

# Health and Mana are forced SIMULTANEOUSLY here (unlike battle.gd's
# steps, which only ever force one action at a time) - both glow at
# once, so this tracks both tweens for _tutorial_clear_glow() to kill.
var _tutorial_glow_tweens: Array = []


func _ready() -> void:
	back_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/Map.tscn"))
	message_label.text = ""
	message_label.modulate.a = 0.0

	details_buy_button.pressed.connect(_on_buy_pressed)
	prev_page_button.pressed.connect(_on_prev_page_pressed)
	next_page_button.pressed.connect(_on_next_page_pressed)
	sell_button.pressed.connect(_on_sell_button_pressed)
	sell_close_button.pressed.connect(func(): sell_popup.visible = false)

	# The allowed-actions gate is set BEFORE _refresh_page() builds the
	# item cards - _refresh_item_card() reads TutorialManager.
	# is_action_allowed() to decide each card's disabled state, so the
	# restriction has to already be in place or every card (including
	# Health/Mana) builds as disabled, using whatever _allowed_actions
	# was left over from wherever the player was before this scene.
	if TutorialManager.is_active and TutorialManager.current_stage == 2:
		TutorialManager.set_allowed_actions(["buy:health", "buy:mana"])

	_initialize_stock()
	_refresh_page()
	_refresh_gold_label()
	_refresh_details_panel()

	# Back/sell/paging are disabled AFTER _refresh_page() runs, since
	# _refresh_page() unconditionally recomputes both page buttons'
	# disabled state itself (based on _current_page/_total_pages()) -
	# setting these first would just get overwritten by that call.
	if TutorialManager.is_active and TutorialManager.current_stage == 2:
		back_button.disabled = true
		sell_button.disabled = true
		prev_page_button.disabled = true
		next_page_button.disabled = true
		_tutorial_glow_forced_items()
		TutorialManager.show_popup(
			"You've got exactly enough gold for one Health Potion and one Mana Potion - buy both "
			+ "before heading back out."
		)


## Gives both the Health and Mana Potion cards - and the details panel's
## own Buy button - the same glowing treatment every other forced button
## during the tutorial uses (see TutorialManager.make_glow_style()). All
## three glow at once, since either potion can be bought first here, and
## the actual purchase only happens once the player clicks Buy AFTER
## selecting one - without its own glow, a player who'd only ever seen
## the icon glow before this point had nothing marking the button that
## actually completes the purchase. details_buy_button stays glowing
## across selection changes since _refresh_details_panel() never touches
## its stylebox overrides, only its text/visible/disabled state, and
## starts glowing even while it's still hidden (nothing selected yet) -
## harmless, since it just shows once the player picks an item. Called
## once _cards is actually populated (_refresh_page() has to have run
## already - see its own call site).
func _tutorial_glow_forced_items() -> void:
	for item_id in ["health", "mana"]:
		if not _cards.has(item_id):
			continue
		var button: Button = _cards[item_id]["button"]
		var glow_style: StyleBoxFlat = TutorialManager.make_glow_style()
		button.add_theme_stylebox_override("normal", glow_style)
		button.add_theme_stylebox_override("hover", glow_style)
		_tutorial_glow_tweens.append(TutorialManager.start_glow_pulse(glow_style, self))

	var buy_glow_style: StyleBoxFlat = TutorialManager.make_glow_style()
	details_buy_button.add_theme_stylebox_override("normal", buy_glow_style)
	details_buy_button.add_theme_stylebox_override("hover", buy_glow_style)
	details_buy_button.add_theme_stylebox_override("disabled", buy_glow_style)
	_tutorial_glow_tweens.append(TutorialManager.start_glow_pulse(buy_glow_style, self))


## Undoes _tutorial_glow_forced_items() once both potions are bought -
## called from _tutorial_check_progress() right before it opens the
## checkpoint.
func _tutorial_clear_glow() -> void:
	for item_id in ["health", "mana"]:
		if _cards.has(item_id):
			var button: Button = _cards[item_id]["button"]
			button.remove_theme_stylebox_override("normal")
			button.remove_theme_stylebox_override("hover")
	details_buy_button.remove_theme_stylebox_override("normal")
	details_buy_button.remove_theme_stylebox_override("hover")
	details_buy_button.remove_theme_stylebox_override("disabled")
	for tween in _tutorial_glow_tweens:
		if tween:
			tween.kill()
	_tutorial_glow_tweens.clear()


## Polled after every successful purchase - once both potions are in
## the inventory, opens the "continue to the final tutorial stage, or
## stop here" checkpoint and lifts every restriction _apply_tutorial_
## restrictions() put in place.
func _tutorial_check_progress() -> void:
	if not TutorialManager.is_active or TutorialManager.current_stage != 2:
		return

	var inventory: Dictionary = PlayerManager.get_inventory()
	if inventory.get("health", 0) <= 0 or inventory.get("mana", 0) <= 0:
		return

	back_button.disabled = false
	sell_button.disabled = false
	prev_page_button.disabled = _current_page <= 0
	next_page_button.disabled = _current_page >= _total_pages() - 1
	TutorialManager.set_allowed_actions([])
	_tutorial_clear_glow()

	TutorialManager.show_checkpoint(
		"Stocked up! That's the other half of surviving a run: knowing when to cut your losses, "
		+ "and having potions ready for when you do.\n\nContinue with the final tutorial stage, or "
		+ "stop here?",
		TutorialManager.start_stage3
	)


func _refresh_gold_label() -> void:
	gold_value_label.text = str(PlayerManager.get_gold())


## Stocks every shop item once, up front - not just the current page's
## items - so switching pages never resets what's already been bought.
func _initialize_stock() -> void:
	_stock.clear()
	for item_id in GameManager.SHOP_ITEM_IDS:
		_stock[item_id] = GameManager.SHOP_STOCK_PER_ITEM


func _total_pages() -> int:
	return maxi(1, ceili(GameManager.SHOP_ITEM_IDS.size() / float(ITEMS_PER_PAGE)))


func _on_prev_page_pressed() -> void:
	if _current_page > 0:
		_current_page -= 1
		_refresh_page()


func _on_next_page_pressed() -> void:
	if _current_page < _total_pages() - 1:
		_current_page += 1
		_refresh_page()


## Rebuilds the current page's item cards and updates the title/page
## arrows to match.
func _refresh_page() -> void:
	_build_shop_items()

	var total_pages: int = _total_pages()
	prev_page_button.disabled = _current_page <= 0
	next_page_button.disabled = _current_page >= total_pages - 1
	title_label.text = "For Sale (%d/%d)" % [_current_page + 1, total_pages] if total_pages > 1 else "For Sale"


## Builds one card per item id on the current page (first 6 ids -> page
## 1, next 6 -> page 2, etc.), each reflecting whatever's already in
## _stock for it.
func _build_shop_items() -> void:
	for child in items_grid.get_children():
		child.queue_free()
	_cards.clear()

	var start: int = _current_page * ITEMS_PER_PAGE
	var end: int = mini(start + ITEMS_PER_PAGE, GameManager.SHOP_ITEM_IDS.size())

	for i in range(start, end):
		var item_id: String = GameManager.SHOP_ITEM_IDS[i]
		var item_data: Dictionary = GameManager.get_item(item_id)
		if item_data.is_empty():
			print("ERROR: Shop item id not found in GameManager.items: ", item_id)
			continue

		items_grid.add_child(_build_item_card(item_id, item_data))


func _build_item_card(item_id: String, item_data: Dictionary) -> Control:
	var card := VBoxContainer.new()
	card.custom_minimum_size = Vector2(100, 0)
	card.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_theme_constant_override("separation", 6)

	var icon_button := Button.new()
	icon_button.custom_minimum_size = Vector2(96, 96)
	icon_button.expand_icon = true
	icon_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var image_path: String = item_data.get("image", "")
	if image_path != "" and ResourceLoader.exists(image_path):
		icon_button.icon = load(image_path)
	icon_button.pressed.connect(_on_item_selected.bind(item_id))

	var name_label := Label.new()
	name_label.text = item_data.get("name", "")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	name_label.add_theme_constant_override("outline_size", 3)
	name_label.add_theme_font_size_override("font_size", 15)

	var cost_label := Label.new()
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.add_theme_color_override("font_color", Color(1, 0.85, 0.2, 1))
	cost_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	cost_label.add_theme_constant_override("outline_size", 3)
	cost_label.add_theme_font_size_override("font_size", 14)

	var stock_label := Label.new()
	stock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stock_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1))
	stock_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	stock_label.add_theme_constant_override("outline_size", 2)
	stock_label.add_theme_font_size_override("font_size", 12)

	card.add_child(icon_button)
	card.add_child(name_label)
	card.add_child(cost_label)
	card.add_child(stock_label)

	_cards[item_id] = {
		"button": icon_button,
		"cost_label": cost_label,
		"stock_label": stock_label,
	}
	_refresh_item_card(item_id)

	return card


func _refresh_item_card(item_id: String) -> void:
	if not _cards.has(item_id):
		return

	var item_data: Dictionary = GameManager.get_item(item_id)
	var cost: int = int(item_data.get("cost", 0))
	var stock: int = _stock.get(item_id, 0)

	var card: Dictionary = _cards[item_id]
	var button: Button = card["button"]
	var cost_label: Label = card["cost_label"]
	var stock_label: Label = card["stock_label"]

	if stock <= 0:
		button.disabled = true
		cost_label.text = "Sold out"
		stock_label.text = ""
	else:
		button.disabled = not TutorialManager.is_action_allowed("buy:" + item_id)
		cost_label.text = str(cost) + " Gold"
		stock_label.text = "x%d in stock" % stock


## Clicking an item's icon no longer buys it directly - it just shows
## that item's details (description + cost + a Buy button) in the
## panel under the merchant portrait. Buying happens from there.
func _on_item_selected(item_id: String) -> void:
	_selected_item_id = item_id
	_refresh_details_panel()


## Fills the details panel for whichever item is selected, or shows a
## prompt if nothing's been clicked yet.
func _refresh_details_panel() -> void:
	if _selected_item_id == "":
		details_name_label.text = "Select an item to see its details"
		details_description_label.text = ""
		details_cost_label.text = ""
		details_buy_button.visible = false
		return

	var item_data: Dictionary = GameManager.get_item(_selected_item_id)
	var stock: int = _stock.get(_selected_item_id, 0)
	var cost: int = int(item_data.get("cost", 0))

	details_name_label.text = item_data.get("name", "")
	details_description_label.text = item_data.get("description", "")
	details_buy_button.visible = true
	# Default to the normal price - only the `stock <= 0` branch below
	# overrides it to "Sold out". Previously only that branch ever set
	# this label at all, so once you'd viewed one sold-out item, its
	# "Sold out" text stuck around forever: the elif/else branches below
	# only ever touched details_buy_button, never this label, so a fully
	# in-stock item selected afterward still showed a stale "Sold out"
	# price even though its own Buy button correctly re-enabled.
	details_cost_label.text = str(cost) + " Gold"

	if stock <= 0:
		details_cost_label.text = "Sold out"
		details_buy_button.disabled = true
		details_buy_button.text = "Sold Out"
	elif not PlayerManager.can_add_item(_selected_item_id):
		details_buy_button.disabled = true
		details_buy_button.text = "Inventory Full"
	else:
		details_buy_button.disabled = false
		details_buy_button.text = "Buy"


func _on_buy_pressed() -> void:
	var item_id: String = _selected_item_id
	if item_id == "":
		return

	if not TutorialManager.is_action_allowed("buy:" + item_id):
		return

	var stock: int = _stock.get(item_id, 0)
	if stock <= 0:
		_show_message("Sold out")
		return

	var item_data: Dictionary = GameManager.get_item(item_id)
	var cost: int = int(item_data.get("cost", 0))

	if PlayerManager.get_gold() < cost:
		_show_message("Not enough gold")
		return

	if not PlayerManager.can_add_item(item_id):
		_show_message("Inventory full")
		return

	PlayerManager.add_gold(-cost)
	PlayerManager.add_item(item_id, 1)
	_stock[item_id] = stock - 1

	_refresh_gold_label()
	_refresh_item_card(item_id)
	_refresh_details_panel()
	_show_message(item_data.get("name", "Item") + " purchased!")
	_tutorial_check_progress()


## Brief fade-in/fade-out status message (purchase confirmation,
## "not enough gold", "sold out") shown under the shop panel.
func _show_message(text: String) -> void:
	if _message_tween:
		_message_tween.kill()

	message_label.text = text
	message_label.modulate.a = 1.0

	_message_tween = create_tween()
	_message_tween.tween_interval(1.0)
	_message_tween.tween_property(message_label, "modulate:a", 0.0, 0.6)


func _on_sell_button_pressed() -> void:
	_refresh_sell_popup()
	sell_popup.visible = true


## Rebuilds the sell popup's item rows from the hero's current
## inventory. Called on open and after every sale so quantities (and
## the "nothing left to sell" state) stay accurate.
func _refresh_sell_popup() -> void:
	for child in sell_items_list.get_children():
		child.queue_free()

	var inventory: Dictionary = PlayerManager.get_inventory()
	if inventory.is_empty():
		var empty_label := Label.new()
		empty_label.text = "You have no items to sell."
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1))
		empty_label.add_theme_font_size_override("font_size", 14)
		sell_items_list.add_child(empty_label)
		return

	for item_id in inventory.keys():
		var item_data: Dictionary = GameManager.get_item(item_id)
		if item_data.is_empty():
			continue
		sell_items_list.add_child(_build_sell_row(item_id, item_data, inventory[item_id]))


func _build_sell_row(item_id: String, item_data: Dictionary, count: int) -> Control:
	var row := PanelContainer.new()
	var row_style := StyleBoxFlat.new()
	row_style.bg_color = Color(1, 1, 1, 0.06)
	row_style.set_corner_radius_all(6)
	row.add_theme_stylebox_override("panel", row_style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 6)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)

	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(40, 40)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var image_path: String = item_data.get("image", "")
	if image_path != "" and ResourceLoader.exists(image_path):
		icon_rect.texture = load(image_path)

	var name_label := Label.new()
	name_label.text = "%s  x%d" % [item_data.get("name", ""), count]
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	name_label.add_theme_constant_override("outline_size", 2)
	name_label.add_theme_font_size_override("font_size", 15)

	var sell_price: int = _sell_price_for(item_id)

	var sell_button := Button.new()
	sell_button.text = "Sell for %d Gold" % sell_price
	sell_button.custom_minimum_size = Vector2(150, 36)
	sell_button.pressed.connect(_on_sell_item_pressed.bind(item_id))

	hbox.add_child(icon_rect)
	hbox.add_child(name_label)
	hbox.add_child(sell_button)
	margin.add_child(hbox)
	row.add_child(margin)

	return row


## Sell price is always 50% of that item's shop buy cost, rounded down.
func _sell_price_for(item_id: String) -> int:
	var item_data: Dictionary = GameManager.get_item(item_id)
	var cost: int = int(item_data.get("cost", 0))
	return int(cost * 0.5)


func _on_sell_item_pressed(item_id: String) -> void:
	if not PlayerManager.use_item(item_id):
		return

	var sell_price: int = _sell_price_for(item_id)
	PlayerManager.add_gold(sell_price)

	_refresh_gold_label()
	_refresh_sell_popup()
	_refresh_details_panel()

	var item_data: Dictionary = GameManager.get_item(item_id)
	_show_message("Sold %s for %d Gold" % [item_data.get("name", "item"), sell_price])
