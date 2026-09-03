@tool
class_name SceneChangeTrigger
extends Node3D
## Drop into a level like any other node (Create New Node >
## SceneChangeTrigger) to load another scene — no manual sibling assembly
## needed for either trigger mode; it builds whatever detector
## `trigger_mode` needs itself, the moment it has none yet (and rebuilds
## it if `trigger_mode` changes afterward), same self-building idea as
## NpcBody/WorldItem:
## - AREA: builds an Area3D + CollisionShape3D — the player walking into
##   it fires the load. No solid collision, so it doesn't block movement —
##   for an exit/doorway you just walk through.
## - INTERACT: builds a StaticBody3D + CollisionShape3D +
##   InteractableComponent — pressing "interact" fires the load, the same
##   key (and the same HUD prompt) as every other interaction in the
##   game. Solid, like a real door you walk up to.
##
## Loads target_scene EXCLUSIVE (replace the current level entirely,
## placing the player on the matching SpawnPoint) or ADDITIVE (instantiate
## alongside whatever's already loaded, e.g. to stream in a sub-area,
## without moving the player or clearing anything). One-shot: fires once,
## then stays inert — for EXCLUSIVE this doesn't matter (the trigger
## itself gets torn down with the rest of the old level), but it keeps
## ADDITIVE from adding the same scene again every time it fires.

enum TriggerMode { AREA, INTERACT }
enum LoadMode { EXCLUSIVE, ADDITIVE }

@export var trigger_mode: TriggerMode = TriggerMode.AREA:
	set(value):
		trigger_mode = value
		if has_node(_DETECTOR_NAME):
			_rebuild_detector()

## Size of the detector's box collider (the Area3D's or the door's).
@export var detector_size: Vector3 = Vector3(1.0, 2.0, 1.0):
	set(value):
		detector_size = value
		_apply_size()

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

const _DETECTOR_NAME := "Detector"
const _COLLISION_NAME := "CollisionShape3D"
const _INTERACTABLE_SCRIPT := "res://core/interaction/interactable_component.gd"

var _triggered := false


func _ready() -> void:
	if not has_node(_DETECTOR_NAME):
		_rebuild_detector()


## Tears down and rebuilds the detector subtree for the current
## trigger_mode — a walk-in Area3D and an interactable door are different
## node structures, so switching modes has to fully replace it. Re-applies
## detector_size afterward, so that setting isn't lost across a switch.
func _rebuild_detector() -> void:
	if has_node(_DETECTOR_NAME):
		var existing := get_node(_DETECTOR_NAME)
		remove_child(existing)
		existing.free()

	var detector: Node3D
	if trigger_mode == TriggerMode.AREA:
		detector = _build_area_detector()
	else:
		detector = _build_interact_detector()

	detector.name = _DETECTOR_NAME
	# Build the whole subtree detached, THEN attach it to self in one
	# step, THEN assign owners — owner must be an actual ancestor, which
	# none of these nodes are until add_child() below connects the chain
	# up to self (assigning owner any earlier, while they only know about
	# each other and not yet about self, fails).
	add_child(detector)
	# Assign synchronously, same as NpcBody/WorldItem — this is what makes
	# the Scene dock and the CollisionShape3D gizmo show the freshly built
	# subtree immediately when the node is added live in the editor
	# (Create New Node): the dock snapshots ownership right as node
	# creation finishes, so a *deferred* assignment used to land one frame
	# too late for it to notice, silently requiring a scene reload to show
	# up (still structurally correct meanwhile, just invisible in the
	# dock/viewport until then).
	_own_recursive(detector)
	# Also deferred, as a safety net: whoever placed *this* node assigns
	# *its own* owner right after adding it to the tree, same as we just
	# did above for detector — but there's no guarantee that's already
	# landed by the time our own _ready() runs (observed to race in at
	# least one boot path). The synchronous pass above already got the
	# common editor/save-file case right; this corrects the rare case
	# where self.owner was still unset a moment ago (which the synchronous
	# pass would have fallen back to `self` for).
	call_deferred("_own_recursive", detector)

	_apply_size()


func _own_recursive(node: Node) -> void:
	node.owner = owner if owner else self
	for child in node.get_children():
		_own_recursive(child)


func _build_area_detector() -> Area3D:
	var area := Area3D.new()

	var collision := CollisionShape3D.new()
	collision.name = _COLLISION_NAME
	collision.shape = BoxShape3D.new()
	area.add_child(collision)

	area.body_entered.connect(_on_area_body_entered)
	return area


func _build_interact_detector() -> StaticBody3D:
	var body := StaticBody3D.new()

	var collision := CollisionShape3D.new()
	collision.name = _COLLISION_NAME
	collision.shape = BoxShape3D.new()
	body.add_child(collision)

	var interactable := Node.new()
	interactable.name = "InteractableComponent"
	interactable.set_script(load(_INTERACTABLE_SCRIPT))
	interactable.set("prompt_text_key", "UI_INTERACT_OPEN")
	body.add_child(interactable)
	interactable.interacted.connect(_on_interacted)

	return body


func _apply_size() -> void:
	if not has_node(_DETECTOR_NAME):
		return
	var detector := get_node(_DETECTOR_NAME)
	if not detector.has_node(_COLLISION_NAME):
		return
	var collision := detector.get_node(_COLLISION_NAME) as CollisionShape3D
	if collision.shape is BoxShape3D:
		(collision.shape as BoxShape3D).size = detector_size


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
		push_warning("SceneChangeTrigger '%s' fired with no target_scene assigned." % name)
		return
	_triggered = true

	if mode == LoadMode.EXCLUSIVE:
		SceneManager.change_scene(target_scene, target_spawn_id, show_transition)
	else:
		SceneManager.add_scene(target_scene, show_transition)
