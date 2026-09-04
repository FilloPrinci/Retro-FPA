extends Node
## Level loading/unloading and the overall game lifecycle (new game, return
## to main menu). Autoload singleton.
##
## Levels are instanced under Main's "CurrentLevel" node. The Player is
## instanced once, as a direct child of Main, the first time gameplay
## starts — it is never part of a level scene, so it survives scene changes.

signal scene_change_started(scene_path: String)
signal scene_change_finished(scene_path: String)

const PLAYER_SCENE_PATH := "res://core/player/player.tscn"

var _main: Node = null
var _current_level: Node = null
var _fade_overlay: ColorRect = null
var _spawn_id: String = "default"
var _is_changing_scene: bool = false


## Called by main.gd on _ready(). Wires this manager to the persistent shell.
func register_main(main_node: Node) -> void:
	_main = main_node
	_current_level = main_node.get_node("CurrentLevel")
	_fade_overlay = main_node.get_node_or_null("UILayer/Transition/FadeOverlay") as ColorRect


## Resets session state, spawns the Player and loads the first level.
func start_new_game(first_level_path: String, spawn_id: String = "default") -> void:
	GameManager.clear_flags()
	InventoryManager.clear()
	await change_scene(first_level_path, spawn_id)


## Tears down the current run and shows the main menu again.
func return_to_main_menu() -> void:
	get_tree().paused = false
	_clear_level()
	_clear_player()
	GameManager.state = GameManager.GameState.MAIN_MENU


func reload_current_scene() -> void:
	if _current_level.get_child_count() == 0:
		return
	var level_path: String = _current_level.get_child(0).scene_file_path
	await change_scene(level_path, _spawn_id)


## Fades out (unless show_transition is false), swaps the level under
## CurrentLevel, places the Player on the matching SpawnPoint, then fades
## back in. This is the EXCLUSIVE load — see add_scene() for ADDITIVE.
##
## Returns false without doing anything if a change is already in
## progress, true once this one has fully completed — SceneChangeTrigger
## relies on this to know whether its one-shot actually fired, rather
## than burning it on a call that got silently dropped (e.g. two
## triggers reachable close enough together that the second fires while
## the first's transition is still playing out).
func change_scene(scene_path: String, spawn_id: String = "default", show_transition: bool = true) -> bool:
	if _is_changing_scene:
		return false
	_is_changing_scene = true
	_spawn_id = spawn_id
	scene_change_started.emit(scene_path)

	if show_transition and _fade_overlay:
		await _fade_overlay.fade_out()

	_clear_level()
	_ensure_player_exists()

	var packed_scene: PackedScene = load(scene_path)
	var level := packed_scene.instantiate()
	_current_level.add_child(level)
	_place_player_at_spawn(level, spawn_id)

	# Flip to PLAYING while the screen is still fully black, so menu/HUD
	# visibility (driven by GameManager.state) has already caught up before
	# fade_in starts revealing the level — otherwise the old menu flashes
	# on screen for the first moment of the reveal.
	GameManager.state = GameManager.GameState.PLAYING

	if show_transition and _fade_overlay:
		await _fade_overlay.fade_in()

	_is_changing_scene = false
	scene_change_finished.emit(scene_path)
	return true


## ADDITIVE load: instantiates scene_path as an extra child of
## CurrentLevel, alongside whatever's already there — for streaming in a
## sub-area, a bonus room, etc. Unlike change_scene(), this never touches
## the player or clears anything, and show_transition defaults to off:
## covering the whole screen just to quietly add something in the
## background usually defeats the point. Returns the instantiated node.
func add_scene(scene_path: String, show_transition: bool = false) -> Node:
	if show_transition and _fade_overlay:
		await _fade_overlay.fade_out()

	var packed_scene: PackedScene = load(scene_path)
	var instance := packed_scene.instantiate()
	_current_level.add_child(instance)

	if show_transition and _fade_overlay:
		await _fade_overlay.fade_in()

	return instance


func _ensure_player_exists() -> void:
	if GameManager.get_player() != null:
		return
	var player_scene: PackedScene = load(PLAYER_SCENE_PATH)
	var player := player_scene.instantiate()
	_main.add_child(player)
	GameManager.register_player(player)


func _place_player_at_spawn(level: Node, spawn_id: String) -> void:
	var player := GameManager.get_player()
	if player == null:
		return
	var spawn_point := _find_spawn_point(level, spawn_id)
	if spawn_point:
		player.global_transform = spawn_point.global_transform


func _find_spawn_point(level: Node, spawn_id: String) -> Node3D:
	var spawn_points := level.find_children("*", "SpawnPoint", true, false)
	for spawn_point in spawn_points:
		if spawn_point.spawn_id == spawn_id:
			return spawn_point
	# Fall back to the first spawn point, so a missing/typo'd id doesn't hard-fail.
	return spawn_points[0] if not spawn_points.is_empty() else null


func _clear_level() -> void:
	for child in _current_level.get_children():
		_current_level.remove_child(child)
		child.queue_free()


func _clear_player() -> void:
	var player := GameManager.get_player()
	if player:
		_main.remove_child(player)
		player.queue_free()
	GameManager.clear_player()
