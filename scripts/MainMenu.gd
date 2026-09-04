extends Control

func _ready() -> void:
	$ButtonsContainer/NewPlayerButton.pressed.connect(_on_new_player_pressed)
	$ButtonsContainer/LogInButton.pressed.connect(_on_log_in_pressed)
	$ButtonsContainer/HighScoresButton.pressed.connect(_on_high_scores_pressed)
	$SettingsButton.pressed.connect(func(): $SettingsPopup.open())

func _on_new_player_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Register.tscn")

func _on_log_in_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Login.tscn")

func _on_high_scores_pressed() -> void:
	# TODO: high score screen goes here
	print("High Scores - coming soon")
