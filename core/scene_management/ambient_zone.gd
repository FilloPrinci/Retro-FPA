class_name AmbientZone
extends Area3D
## Plays a looping ambient sound while the player is inside this Area3D, and
## fades it out when they leave. Drop into a level, set `ambient_sound`, and
## size its CollisionShape3D to cover the intended area.

@export var ambient_sound: AudioStream
@export var fade_time: float = 1.0

var _playing_instance: AudioStreamPlayer3D = null


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if ambient_sound == null or not body.is_in_group("player"):
		return
	_playing_instance = AudioManager.play_ambient(ambient_sound, global_position)


func _on_body_exited(body: Node3D) -> void:
	if _playing_instance == null or not body.is_in_group("player"):
		return
	var instance := _playing_instance
	_playing_instance = null
	var tween := create_tween()
	tween.tween_property(instance, "volume_db", -80.0, fade_time)
	tween.tween_callback(instance.queue_free)
