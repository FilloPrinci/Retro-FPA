extends Node
## Demo-only: cycles the sibling AnimationController between "idle" and
## "walk" every few seconds, so the animation system is visible in the demo
## level without needing a real animated model yet. Not part of the
## reusable template — delete along with the rest of the demo content when
## starting a real game.

@export var state_duration: float = 2.5

var _states := ["idle", "walk"]
var _state_index := 0
var _timer := 0.0

@onready var _controller: AnimationController = _find_controller()


func _ready() -> void:
	if _controller:
		_controller.play_state(_states[_state_index])


func _process(delta: float) -> void:
	if _controller == null:
		return
	_timer += delta
	if _timer >= state_duration:
		_timer = 0.0
		_state_index = (_state_index + 1) % _states.size()
		_controller.play_state(_states[_state_index])


func _find_controller() -> AnimationController:
	for sibling in get_parent().get_children():
		if sibling is AnimationController:
			return sibling
	return null
