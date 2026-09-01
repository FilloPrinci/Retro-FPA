extends Camera3D
## Very light PS1-style head bob, driven by the Player's horizontal speed.
## Attach directly to the Player's Camera3D node (Head/Camera3D).

@export var enabled: bool = true
@export var bob_frequency: float = 2.0
@export var bob_amplitude: float = 0.04

@onready var _player: Player = get_owner() as Player

var _bob_time: float = 0.0
var _base_position: Vector3


func _ready() -> void:
	_base_position = position


func _process(delta: float) -> void:
	if not enabled or _player == null:
		return

	var horizontal_speed := Vector2(_player.velocity.x, _player.velocity.z).length()
	var is_moving := horizontal_speed > 0.1 and _player.is_on_floor()

	if is_moving:
		_bob_time += delta * bob_frequency * (horizontal_speed / max(_player.move_speed, 0.01))
	else:
		_bob_time = 0.0

	var bob_offset := sin(_bob_time * TAU) * bob_amplitude if is_moving else 0.0
	position.y = _base_position.y + bob_offset
