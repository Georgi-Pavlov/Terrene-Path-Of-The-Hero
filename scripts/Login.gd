extends Control

@onready var name_edit: LineEdit = $Panel/VBoxContainer/NameEdit
@onready var pass_edit: LineEdit = $Panel/VBoxContainer/PasswordEdit
@onready var error_label: Label = $Panel/VBoxContainer/ErrorLabel

func _ready() -> void:
	$Panel/VBoxContainer/HBoxContainer/SubmitButton.pressed.connect(_on_submit_pressed)
	$Panel/VBoxContainer/HBoxContainer/BackButton.pressed.connect(_on_back_pressed)

func _on_submit_pressed() -> void:
	var username := name_edit.text.strip_edges()
	var password := pass_edit.text

	if username == "" or password == "":
		error_label.text = "Enter both name and password."
		return
	if not PlayerManager.player_exists(username):
		error_label.text = "No such player."
		return
	if not PlayerManager.validate_login(username, password):
		error_label.text = "Incorrect password."
		return

	PlayerManager.current_player = username
	get_tree().change_scene_to_file("res://scenes/PostLogin.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
