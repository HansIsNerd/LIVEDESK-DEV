# Pooled one-shot SFX playback.
extends Node

const POOL_SIZE: int = 8
const SFX_BUS: StringName = &"Master"

var _pool: Array[AudioStreamPlayer] = []
var _next_steal: int = 0


func _ready() -> void:
	for i: int in POOL_SIZE:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.bus = SFX_BUS
		add_child(player)
		_pool.append(player)


func play(sfx: AudioStream, volume_db: float = 0.0) -> void:
	if sfx == null:
		return
	var player: AudioStreamPlayer = _acquire()
	player.stream = sfx
	player.volume_db = volume_db
	player.play()


func _acquire() -> AudioStreamPlayer:
	for player: AudioStreamPlayer in _pool:
		if not player.playing:
			return player
	var stolen: AudioStreamPlayer = _pool[_next_steal]
	_next_steal = (_next_steal + 1) % POOL_SIZE
	return stolen