extends Node
## Global game state and small in-memory flags. Autoload singleton.
##
## This is intentionally not a save system — flags only live for the current
## play session. A specific game can add real persistence on top of
## get_flag/set_flag without changing anything that reads them.

signal control_enabled_changed(enabled: bool)
signal state_changed(new_state: GameState)
## Emitted whenever a Player is (re)spawned, so persistent UI (HUD, ...) can
## wire itself up without depending on instancing order.
signal player_registered(player: Node3D)

enum GameState {
	MAIN_MENU,
	PLAYING,
	PAUSED,
	DIALOGUE,
	INVENTORY,
}

## Also owns the mouse cursor mode: captured while PLAYING, visible for every
## menu/overlay state, so no menu needs to remember to release it itself.
var state: GameState = GameState.MAIN_MENU:
	set(value):
		if state == value:
			return
		state = value
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if state == GameState.PLAYING else Input.MOUSE_MODE_VISIBLE
		state_changed.emit(state)

## Whether the player controller should react to input. Dialogue, cutscenes
## and menus turn this off so the player doesn't move/look around underneath
## them.
var control_enabled: bool = true:
	set(value):
		if control_enabled == value:
			return
		control_enabled = value
		control_enabled_changed.emit(control_enabled)

var _player: Node3D = null
var _flags: Dictionary = {}


func register_player(player: Node3D) -> void:
	_player = player
	player_registered.emit(player)


func get_player() -> Node3D:
	return _player


func clear_player() -> void:
	_player = null


func set_control_enabled(enabled: bool) -> void:
	control_enabled = enabled


func set_flag(key: String, value: Variant) -> void:
	_flags[key] = value


func get_flag(key: String, default_value: Variant = null) -> Variant:
	return _flags.get(key, default_value)


func has_flag(key: String) -> bool:
	return _flags.has(key)


func clear_flags() -> void:
	_flags.clear()
