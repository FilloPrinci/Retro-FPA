extends Node
## Plays footstep/landing sounds based on the Player's movement and the
## surface underfoot (tagged via SurfaceTag). Attach as a child of Player.

@export var surface_sounds: SurfaceSoundSet
@export var step_interval: float = 0.45
@export var min_speed_to_step: float = 0.5

@onready var _player: CharacterBody3D = get_owner() as CharacterBody3D

var _step_timer: float = 0.0
var _was_on_floor: bool = true


func _physics_process(delta: float) -> void:
	if _player == null or surface_sounds == null:
		return

	var horizontal_speed := Vector2(_player.velocity.x, _player.velocity.z).length()
	var on_floor := _player.is_on_floor()

	if on_floor and not _was_on_floor:
		_play_landing_sound()

	if on_floor and horizontal_speed >= min_speed_to_step:
		_step_timer -= delta
		if _step_timer <= 0.0:
			_play_footstep_sound()
			_step_timer = step_interval
	else:
		_step_timer = 0.0

	_was_on_floor = on_floor


func _play_footstep_sound() -> void:
	var entry := _get_current_surface_entry()
	if entry == null or entry.footstep_sounds.is_empty():
		return
	var stream: AudioStream = entry.footstep_sounds.pick_random()
	AudioManager.play_sfx_3d(stream, _player.global_position)


func _play_landing_sound() -> void:
	var entry := _get_current_surface_entry()
	if entry == null or entry.landing_sound == null:
		return
	AudioManager.play_sfx_3d(entry.landing_sound, _player.global_position)


func _get_current_surface_entry() -> SurfaceSoundEntry:
	return surface_sounds.get_entry(_detect_surface_type())


func _detect_surface_type() -> String:
	for i in _player.get_slide_collision_count():
		var collision := _player.get_slide_collision(i)
		var collider := collision.get_collider()
		if collider == null:
			continue
		for child in collider.get_children():
			if child is SurfaceTag:
				return child.surface_type
	return "default"
