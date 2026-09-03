class_name SceneChangeTrigger
extends Area3D
## Drop into a level as a doorway/exit trigger. When the player enters it,
## asks SceneManager to load the target scene — EXCLUSIVE (replace the
## current level entirely, placing the player on the matching SpawnPoint)
## or ADDITIVE (instantiate the target alongside whatever's already
## loaded, e.g. to stream in a sub-area, without moving the player or
## clearing anything). One-shot: fires once, then stays inert — for
## EXCLUSIVE this doesn't matter (the trigger itself gets torn down with
## the rest of the old level), but it keeps ADDITIVE from adding the same
## scene again every time the player walks back through the doorway.

enum LoadMode { EXCLUSIVE, ADDITIVE }

@export_file("*.tscn") var target_scene: String
## EXCLUSIVE replaces the current level entirely (SceneManager.change_scene
## — fades out, clears CurrentLevel, loads target_scene, places the player
## on its matching SpawnPoint, fades in). ADDITIVE instantiates
## target_scene alongside whatever's already loaded (SceneManager.add_scene).
@export var mode: LoadMode = LoadMode.EXCLUSIVE
## Only used by EXCLUSIVE — which SpawnPoint in target_scene to place the
## player at.
@export var target_spawn_id: String = "default"
## Whether to fade through SceneManager's transition overlay while
## loading. There's no progress bar in this template — the fade-to-black
## covers the (synchronous) load, so this is effectively "show a loading
## screen or not". Worth turning off for an ADDITIVE trigger: covering the
## whole screen just to quietly add something in the background usually
## defeats the point.
@export var show_transition: bool = true

var _triggered := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if _triggered or not body.is_in_group("player") or target_scene.is_empty():
		return
	_triggered = true

	if mode == LoadMode.EXCLUSIVE:
		SceneManager.change_scene(target_scene, target_spawn_id, show_transition)
	else:
		SceneManager.add_scene(target_scene, show_transition)
