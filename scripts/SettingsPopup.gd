extends Control

@onready var music_toggle: CheckButton = $Panel/Margin/VBox/MusicRow/MusicToggle
@onready var music_slider: HSlider = $Panel/Margin/VBox/MusicVolumeRow/MusicVolumeSlider
@onready var sound_toggle: CheckButton = $Panel/Margin/VBox/SoundRow/SoundToggle
@onready var sound_slider: HSlider = $Panel/Margin/VBox/SoundVolumeRow/SoundVolumeSlider
@onready var close_button: Button = $Panel/Margin/VBox/CloseButton


func _ready() -> void:
	music_toggle.toggled.connect(_on_music_toggled)
	music_slider.value_changed.connect(_on_music_volume_changed)
	sound_toggle.toggled.connect(_on_sound_toggled)
	sound_slider.value_changed.connect(_on_sound_volume_changed)
	close_button.pressed.connect(close)


## Call this from the parent scene's settings button.
func open() -> void:
	music_toggle.button_pressed = SettingsManager.music_on
	music_slider.value = SettingsManager.music_volume
	sound_toggle.button_pressed = SettingsManager.sound_on
	sound_slider.value = SettingsManager.sound_volume
	visible = true


func close() -> void:
	visible = false


func _on_music_toggled(pressed: bool) -> void:
	SettingsManager.set_music_on(pressed)


func _on_music_volume_changed(value: float) -> void:
	SettingsManager.set_music_volume(value)


func _on_sound_toggled(pressed: bool) -> void:
	SettingsManager.set_sound_on(pressed)


func _on_sound_volume_changed(value: float) -> void:
	SettingsManager.set_sound_volume(value)
