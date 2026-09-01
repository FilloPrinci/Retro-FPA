extends Node
## Bus-based sound playback: pooled one-shot SFX (2D/3D), crossfading music,
## and simple looping ambient sources. Autoload singleton.

const SFX_2D_POOL_SIZE := 8
const SFX_3D_POOL_SIZE := 8
const MUSIC_SILENT_DB := -80.0

var _sfx_2d_pool: Array[AudioStreamPlayer] = []
var _sfx_3d_pool: Array[AudioStreamPlayer3D] = []
var _music_player_a: AudioStreamPlayer
var _music_player_b: AudioStreamPlayer
var _active_music_player: AudioStreamPlayer


func _ready() -> void:
	for i in SFX_2D_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_sfx_2d_pool.append(player)

	for i in SFX_3D_POOL_SIZE:
		var player_3d := AudioStreamPlayer3D.new()
		player_3d.bus = "SFX"
		add_child(player_3d)
		_sfx_3d_pool.append(player_3d)

	_music_player_a = AudioStreamPlayer.new()
	_music_player_a.bus = "Music"
	add_child(_music_player_a)
	_music_player_b = AudioStreamPlayer.new()
	_music_player_b.bus = "Music"
	add_child(_music_player_b)
	_active_music_player = _music_player_a


func play_sfx_2d(stream: AudioStream, bus: String = "SFX", volume_db: float = 0.0) -> void:
	if stream == null:
		return
	var player := _find_free_2d_player()
	if player == null:
		return
	player.stream = stream
	player.bus = bus
	player.volume_db = volume_db
	player.play()


func play_sfx_3d(stream: AudioStream, world_position: Vector3, bus: String = "SFX", volume_db: float = 0.0) -> void:
	if stream == null:
		return
	var player := _find_free_3d_player()
	if player == null:
		return
	player.stream = stream
	player.bus = bus
	player.volume_db = volume_db
	player.global_position = world_position
	player.play()


func play_music(stream: AudioStream, fade_time: float = 1.0) -> void:
	var outgoing := _active_music_player
	var incoming := _music_player_b if outgoing == _music_player_a else _music_player_a
	_active_music_player = incoming

	incoming.stream = stream
	incoming.volume_db = MUSIC_SILENT_DB
	incoming.play()

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(incoming, "volume_db", 0.0, fade_time)
	if outgoing.playing:
		tween.tween_property(outgoing, "volume_db", MUSIC_SILENT_DB, fade_time)
		tween.chain().tween_callback(outgoing.stop)


func stop_music(fade_time: float = 1.0) -> void:
	var outgoing := _active_music_player
	if not outgoing.playing:
		return
	var tween := create_tween()
	tween.tween_property(outgoing, "volume_db", MUSIC_SILENT_DB, fade_time)
	tween.tween_callback(outgoing.stop)


## Starts a looping 3D ambient source and returns it so the caller (e.g. an
## AmbientZone) can stop/free it later. Loops via the `finished` signal so it
## works regardless of the underlying AudioStream type.
func play_ambient(stream: AudioStream, world_position: Vector3 = Vector3.ZERO) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.bus = "Ambient"
	player.stream = stream
	player.global_position = world_position
	player.finished.connect(player.play.bind(0.0))
	add_child(player)
	player.play()
	return player


func _find_free_2d_player() -> AudioStreamPlayer:
	for player in _sfx_2d_pool:
		if not player.playing:
			return player
	return _sfx_2d_pool[0] if not _sfx_2d_pool.is_empty() else null


func _find_free_3d_player() -> AudioStreamPlayer3D:
	for player in _sfx_3d_pool:
		if not player.playing:
			return player
	return _sfx_3d_pool[0] if not _sfx_3d_pool.is_empty() else null
