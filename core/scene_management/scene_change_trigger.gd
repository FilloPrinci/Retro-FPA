class_name SceneChangeTrigger
extends Node
## Loads another scene when triggered. Drop as a sibling of whichever
## detector matches `trigger_mode` — same "find the right sibling" pattern
## as DialogueTrigger/ItemPickup:
## - AREA: a sibling Area3D (with its own CollisionShape3D, sized to the
##   doorway) — the player walking into it fires the load. For an
##   exit/doorway you just walk through.
## - INTERACT: a sibling InteractableComponent (itself a child of a
##   StaticBody3D/RigidBody3D door, portal, ...) — pressing "interact"
##   fires the load, the same key as every other interaction in the game.
##
## Either way, loads target_scene EXCLUSIVE (replace the current level
## entirely, placing the player on the matching SpawnPoint) or ADDITIVE
## (instantiate alongside whatever's already loaded, e.g. to stream in a
## sub-area, without moving the player or clearing anything). One-shot:
## fires once, then stays inert — for EXCLUSIVE this doesn't matter (the
## trigger itself gets torn down with the rest of the old level), but it
## keeps ADDITIVE from adding the same scene again every time it fires.

enum TriggerMode { AREA, INTERACT }
enum LoadMode { EXCLUSIVE, ADDITIVE }

@export var trigger_mode: TriggerMode = TriggerMode.AREA
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
	match trigger_mode:
		TriggerMode.AREA:
			var area := _find_sibling_area()
			if area:
				area.body_entered.connect(_on_area_body_entered)
			else:
				push_warning("SceneChangeTrigger on '%s' is in AREA mode but has no sibling Area3D." % get_parent().name)
		TriggerMode.INTERACT:
			var interactable := _find_sibling_interactable()
			if interactable:
				interactable.interacted.connect(_on_interacted)
			else:
				push_warning("SceneChangeTrigger on '%s' is in INTERACT mode but has no sibling InteractableComponent." % get_parent().name)


func _on_area_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	_fire()


func _on_interacted(_interactor: Node) -> void:
	_fire()


func _fire() -> void:
	if _triggered:
		return
	if target_scene.is_empty():
		push_warning("SceneChangeTrigger on '%s' fired with no target_scene assigned." % get_parent().name)
		return
	_triggered = true

	if mode == LoadMode.EXCLUSIVE:
		SceneManager.change_scene(target_scene, target_spawn_id, show_transition)
	else:
		SceneManager.add_scene(target_scene, show_transition)


func _find_sibling_area() -> Area3D:
	for sibling in get_parent().get_children():
		if sibling is Area3D:
			return sibling
	return null


func _find_sibling_interactable() -> InteractableComponent:
	for sibling in get_parent().get_children():
		if sibling is InteractableComponent:
			return sibling
	return null
