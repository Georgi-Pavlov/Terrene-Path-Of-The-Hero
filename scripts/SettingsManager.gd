extends Node
# ------------------------------------------------------------------
# SettingsManager (autoload / singleton)
# Device-level audio settings - deliberately separate from
# PlayerManager, since these should persist across logins rather
# than being tied to one player account.
#
# Applies to the "Music" and "SFX" audio buses that AudioManager.gd
# already routes its players through (AudioServer.set_bus_mute /
# set_bus_volume_db work on the bus itself, so this affects every
# sound that plays through those buses without AudioManager needing
# any changes).
# ------------------------------------------------------------------

const SETTINGS_FILE := "user://settings.cfg"
const DEFAULT_VOLUME := 0.5

var music_on: bool = true
var sound_on: bool = true
var music_volume: float = DEFAULT_VOLUME
var sound_volume: float = DEFAULT_VOLUME


func _ready() -> void:
	load_settings()
	apply_settings()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(SETTINGS_FILE)
	if err == OK:
		music_on = cfg.get_value("audio", "music_on", true)
		sound_on = cfg.get_value("audio", "sound_on", true)
		music_volume = cfg.get_value("audio", "music_volume", DEFAULT_VOLUME)
		sound_volume = cfg.get_value("audio", "sound_volume", DEFAULT_VOLUME)
	# If the file doesn't exist yet (first run), the defaults above
	# already give 50% volume with both music and sound on.


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music_on", music_on)
	cfg.set_value("audio", "sound_on", sound_on)
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("audio", "sound_volume", sound_volume)
	cfg.save(SETTINGS_FILE)


func apply_settings() -> void:
	_apply_bus("Music", music_on, music_volume)
	_apply_bus("SFX", sound_on, sound_volume)


func _apply_bus(bus_name: String, on: bool, volume: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index == -1:
		print("Audio bus not found: ", bus_name, " - check Audio Bus Layout.")
		return
	AudioServer.set_bus_mute(bus_index, not on)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(max(volume, 0.0001)))


func set_music_on(value: bool) -> void:
	music_on = value
	apply_settings()
	save_settings()


func set_sound_on(value: bool) -> void:
	sound_on = value
	apply_settings()
	save_settings()


func set_music_volume(value: float) -> void:
	music_volume = value
	apply_settings()
	save_settings()


func set_sound_volume(value: float) -> void:
	sound_volume = value
	apply_settings()
	save_settings()
