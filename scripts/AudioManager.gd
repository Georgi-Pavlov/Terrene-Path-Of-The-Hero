extends Node

var music_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []

const SFX_PLAYER_COUNT := 8


func _ready() -> void:

	# Music player
	music_player = AudioStreamPlayer.new()
	music_player.name = "MusicPlayer"
	music_player.bus = "Music"
	add_child(music_player)

	# SFX players
	for i in range(SFX_PLAYER_COUNT):

		var player := AudioStreamPlayer.new()
		player.name = "SFXPlayer" + str(i)
		player.bus = "SFX"

		add_child(player)
		sfx_players.append(player)


func play_music(stream: AudioStream) -> void:

	if music_player.stream == stream and music_player.playing:
		return

	music_player.stream = stream
	music_player.play()


func stop_music() -> void:
	music_player.stop()


func play_sfx(stream: AudioStream) -> void:

	for player in sfx_players:

		if not player.playing:
			player.stream = stream
			player.play()
			return
