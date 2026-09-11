extends Control

## Which scene to load once the bar finishes filling. Set this in the
## Inspector per-instance if this loading screen is reused before
## different destinations (e.g. Login vs. Map).
@export_file("*.tscn") var next_scene_path: String = "res://scenes/MainMenu.tscn"

## How long the bar takes to fill, in seconds. The game itself is
## ready almost instantly - this is purely a deliberate, fixed-length
## loading experience (branding/polish) rather than a reflection of
## real load time.
@export var loading_duration: float = 2.5

@onready var progress_bar: ProgressBar = $ProgressBar
@onready var status_label: Label = $StatusLabel


func _ready() -> void:
	progress_bar.min_value = 0.0
	progress_bar.max_value = 100.0
	progress_bar.value = 0.0

	var tween := create_tween()
	tween.tween_method(_on_progress_updated, 0.0, 100.0, loading_duration)
	tween.finished.connect(_on_loading_finished)


func _on_progress_updated(value: float) -> void:
	progress_bar.value = value
	status_label.text = "Loading... %d%%" % int(value)


func _on_loading_finished() -> void:
	if next_scene_path != "":
		get_tree().change_scene_to_file(next_scene_path)
