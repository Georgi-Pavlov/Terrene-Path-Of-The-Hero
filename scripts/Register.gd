extends Control

@onready var name_edit: LineEdit = $Panel/VBoxContainer/NameEdit
@onready var pass_edit: LineEdit = $Panel/VBoxContainer/PasswordEdit
@onready var repeat_edit: LineEdit = $Panel/VBoxContainer/RepeatPasswordEdit
@onready var error_label: Label = $Panel/VBoxContainer/ErrorLabel

func _ready() -> void:
	$Panel/VBoxContainer/HBoxContainer/SubmitButton.pressed.connect(_on_submit_pressed)
	$Panel/VBoxContainer/HBoxContainer/BackButton.pressed.connect(_on_back_pressed)

func _on_submit_pressed() -> void:
	var username := name_edit.text.strip_edges()
	var password := pass_edit.text
	var repeat := repeat_edit.text

	if username == "":
		error_label.text = "Name cannot be empty."
		return
	if PlayerManager.player_exists(username):
		error_label.text = "That name is already registered."
		return
	if password == "":
		error_label.text = "Password cannot be empty."
		return
	if password.length() <= 3:
		error_label.text = "Password must be more than 3 characters."
		return
	if password.find(" ") != -1 or password.find("\t") != -1:
		error_label.text = "Password cannot contain spaces."
		return
	if password != repeat:
		error_label.text = "Passwords do not match."
		return

	PlayerManager.register_player(username, password)
	PlayerManager.current_player = username
	get_tree().change_scene_to_file("res://scenes/PostLogin.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
