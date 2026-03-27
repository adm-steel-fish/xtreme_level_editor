extends Node
class_name XtremeAudioManager
## Central audio manager.  Handles music crossfading, a priority-based music
## stack, and a pooled SFX system with spatial and non-spatial playback.
## Add as an autoload singleton named "AudioManager".

#region Configuration
@export_group("Buses")
@export var music_bus: StringName = &"Music"
@export var sfx_bus: StringName = &"SFX"

@export_group("Music")
@export var music_crossfade_duration: float = 1.0
@export var music_volume_db: float = 0.0

@export_group("SFX Pool")
## Number of pooled AudioStreamPlayer nodes for non-spatial SFX.
@export var sfx_pool_size_2d: int = 8
## Number of pooled AudioStreamPlayer3D nodes for spatial SFX.
@export var sfx_pool_size_3d: int = 8
#endregion

#region Internal
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _current_music: AudioStreamPlayer
var _music_stack: Array[Dictionary] = []  # [{stream, volume}]

var _sfx_pool_2d: Array[AudioStreamPlayer] = []
var _sfx_pool_3d: Array[AudioStreamPlayer3D] = []
#endregion


func _ready() -> void:
	add_to_group("audio_manager")
	_setup_music_players()
	_setup_sfx_pools()


#region Setup
func _setup_music_players() -> void:
	_music_a = AudioStreamPlayer.new()
	_music_a.name = "MusicA"
	_music_a.bus = music_bus
	_music_a.volume_db = music_volume_db
	add_child(_music_a)

	_music_b = AudioStreamPlayer.new()
	_music_b.name = "MusicB"
	_music_b.bus = music_bus
	_music_b.volume_db = -80.0  # Start silent
	add_child(_music_b)

	_current_music = _music_a


func _setup_sfx_pools() -> void:
	for i in range(sfx_pool_size_2d):
		var player := AudioStreamPlayer.new()
		player.name = "SFX2D_%d" % i
		player.bus = sfx_bus
		add_child(player)
		_sfx_pool_2d.append(player)

	for i in range(sfx_pool_size_3d):
		var player := AudioStreamPlayer3D.new()
		player.name = "SFX3D_%d" % i
		player.bus = sfx_bus
		add_child(player)
		_sfx_pool_3d.append(player)
#endregion


#region Music
## Play a music track, crossfading from the current one.
func play_music(stream: AudioStream, crossfade: bool = true) -> void:
	if not stream:
		return

	# Skip if already playing this stream
	if _current_music.stream == stream and _current_music.playing:
		return

	var old_player := _current_music
	var new_player := _music_b if _current_music == _music_a else _music_a

	new_player.stream = stream
	new_player.volume_db = -80.0 if crossfade else music_volume_db
	new_player.play()

	if crossfade and music_crossfade_duration > 0.0:
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(new_player, "volume_db", music_volume_db, music_crossfade_duration)
		tween.tween_property(old_player, "volume_db", -80.0, music_crossfade_duration)
		tween.set_parallel(false)
		tween.tween_callback(func() -> void: old_player.stop())
	else:
		new_player.volume_db = music_volume_db
		old_player.stop()

	_current_music = new_player


## Stop all music.
func stop_music(fade_out: bool = true) -> void:
	if fade_out and music_crossfade_duration > 0.0:
		var tween := create_tween()
		tween.tween_property(_current_music, "volume_db", -80.0, music_crossfade_duration)
		tween.tween_callback(func() -> void: _current_music.stop())
	else:
		_current_music.stop()
		_music_a.stop()
		_music_b.stop()


## Push a temporary music override (e.g. invincibility, boss theme).
## Call pop_music() to return to the previous track.
func push_music(stream: AudioStream) -> void:
	if _current_music.stream and _current_music.playing:
		_music_stack.append({
			"stream": _current_music.stream,
			"position": _current_music.get_playback_position()
		})
	play_music(stream)


## Pop the music stack and resume the previous track.
func pop_music() -> void:
	if _music_stack.is_empty():
		return
	var prev: Dictionary = _music_stack.pop_back()
	var stream: AudioStream = prev.get("stream")
	var position: float = prev.get("position", 0.0)
	if stream:
		play_music(stream)
		# Try to resume from where we left off
		_current_music.seek(position)
#endregion


#region SFX
## Play a non-spatial sound effect.
func play_sfx(stream: AudioStream, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not stream:
		return
	var player := _get_free_2d_player()
	if not player:
		return
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.play()


## Play a spatial (3D) sound effect at a world position.
func play_sfx_3d(stream: AudioStream, position: Vector3, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not stream:
		return
	var player := _get_free_3d_player()
	if not player:
		return
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.global_position = position
	player.play()


func _get_free_2d_player() -> AudioStreamPlayer:
	for player in _sfx_pool_2d:
		if not player.playing:
			return player
	# All busy — steal the oldest
	return _sfx_pool_2d[0] if not _sfx_pool_2d.is_empty() else null


func _get_free_3d_player() -> AudioStreamPlayer3D:
	for player in _sfx_pool_3d:
		if not player.playing:
			return player
	return _sfx_pool_3d[0] if not _sfx_pool_3d.is_empty() else null
#endregion
