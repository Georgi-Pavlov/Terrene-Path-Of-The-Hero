extends Control

@onready var confirm_popup: PanelContainer = $ConfirmNewGamePopup
@onready var confirm_ok_button: Button = $ConfirmNewGamePopup/ConfirmMargin/ConfirmVBox/ConfirmButtons/ConfirmOkButton
@onready var confirm_cancel_button: Button = $ConfirmNewGamePopup/ConfirmMargin/ConfirmVBox/ConfirmButtons/ConfirmCancelButton

func _ready() -> void:
	$WelcomeLabel.text = "Welcome, " + PlayerManager.current_player
	$ButtonsContainer/NewGameButton.pressed.connect(_on_new_game_pressed)
	$ButtonsContainer/ContinueButton.pressed.connect(_on_continue_pressed)
	$ButtonsContainer/HighScoresButton.pressed.connect(_on_high_scores_pressed)
	$ButtonsContainer/HowToPlayButton.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/HowToPlay.tscn"))
	confirm_ok_button.pressed.connect(_on_confirm_new_game_ok)
	confirm_cancel_button.pressed.connect(_on_confirm_new_game_cancel)
	$SettingsButton.pressed.connect(func(): $SettingsPopup.open())

	# Nothing to continue if no hero has been recruited yet, or the
	# current one has died - in both cases only New Game makes sense.
	var recruited: Dictionary = PlayerManager.get_recruited_hero()
	$ButtonsContainer/ContinueButton.disabled = recruited.is_empty() or recruited.get("current_hp", 0) <= 0

func _on_new_game_pressed() -> void:
	var recruited: Dictionary = PlayerManager.get_recruited_hero()

	# Only warn if there's an actual hero with progress to lose. If no
	# hero has been recruited yet, or the current one has already
	# died, there's nothing at stake - just start fresh directly.
	if not recruited.is_empty() and recruited.get("current_hp", 0) > 0:
		confirm_popup.visible = true
		return

	_start_new_game()

func _on_confirm_new_game_ok() -> void:
	confirm_popup.visible = false
	_start_new_game()

func _on_confirm_new_game_cancel() -> void:
	confirm_popup.visible = false

func _start_new_game() -> void:
	PlayerManager.clear_recruited_hero()
	get_tree().change_scene_to_file("res://scenes/Map.tscn")

func _on_continue_pressed() -> void:
	# The current hero and all their stats live in the player's save
	# file already (PlayerManager persists everything as it happens),
	# so continuing just means going back to the map - Zone.tscn's
	# existing hero-lock check picks the rest up automatically.
	get_tree().change_scene_to_file("res://scenes/Map.tscn")

func _on_high_scores_pressed() -> void:
	# TODO: high score screen goes here - PlayerManager.get_high_score()
	# already has the data ready for it.
	print("High Scores - coming soon")
