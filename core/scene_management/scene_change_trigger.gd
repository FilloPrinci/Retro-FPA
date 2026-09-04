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
##
## Editor note: the Detector is real and correctly built/owned the moment
## you add this node — its CollisionShape3D box shows immediately in the
## 3D viewport — but Godot's Scene dock tree list itself doesn't live-track
## children a script adds during _ready() the way it does nodes you add
## through its own UI. It won't list Detector/CollisionShape3D until the
## scene is reloaded (Scene > Reload Saved Scene is enough, no need to
## reopen the whole project). Same known Godot limitation on NpcBody/
## WorldItem — not a bug, and nothing to do unless you actually need to
## select those built children directly (you normally don't: every knob
## that matters is an export on this node).
##
## core/scene_management/scene_change_trigger.tscn is a prefab shortcut for
## dragging this in instead of using Create New Node — but, unlike
## NpcBody's/WorldItem's own prefab shortcuts, it deliberately does NOT
## bake a pre-built Detector into the saved file: it's a bare script-only
## root, built fresh in _ready() exactly like the Create New Node case (so
## dragging it in hits the same one-reload Scene dock lag described above,
## instead of avoiding it). This is required, not just simpler: AREA and
## INTERACT need genuinely different node classes for Detector (Area3D vs
## StaticBody3D), and Godot has no way to record "delete a node baked into
## an instanced sub-scene" from a plain script — a baked default Detector
## plus a trigger_mode override on the instance produces two independent,
## same-named "Detector" nodes once saved (the packed one, still supplied
## by the instance reference, and this node's own local override), which
## Godot's loader detects as a name collision on the next load and
## silently renames one. Confirmed by reproducing the full save-reload
## cycle with PackedScene.pack() + ResourceSaver.save() (the same calls
## the editor's own Save Scene uses) — see _rebuild_detector()'s own doc
## comment for the defenses kept in the script regardless (retiring rather
## than freeing an inherited node, and only reacting to trigger_mode once
## the node is actually ready) as extra insurance for any equivalent
## situation this reasoning didn't anticipate.

enum TriggerMode { AREA, INTERACT }
enum LoadMode { EXCLUSIVE, ADDITIVE }

@export var trigger_mode: TriggerMode = TriggerMode.AREA:
	set(value):
		trigger_mode = value
		# Skip while the node isn't ready yet — see _ready()'s own
		# reconciliation pass, which is what actually handles a saved
		# scene being loaded. Reacting here too during that window is not
		# just redundant: while loading, this setter can fire more than
		# once with a transient/stale detector state (once for the
		# exported property's own *declared default*, before whatever the
		# saved scene's node list actually provides has finished being
		# applied on top) — and the node list can *already* be
		# independently instantiating the correct Detector regardless of
		# this setter, since it's an ordinary override node recorded in
		# the file, not something only this script knows how to create.
		# Rebuilding (and, worse, retiring — see _rebuild_detector()) in
		# response to every one of those calls raced a second, unrelated,
		# already-correct Detector into existence in practice — confirmed
		# by instrumenting this setter and reproducing a full save+reload
		# cycle. Once the node is ready, this reacts normally: a genuine
		# Inspector edit or runtime change to trigger_mode still rebuilds
		# immediately, same as before.
		if is_node_ready() and has_node(_DETECTOR_NAME) and not _detector_matches_mode():
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
	elif not _detector_matches_mode():
		# Reconcile once, now that the whole node is stable — see the
		# trigger_mode setter's doc comment for why this, rather than
		# reacting to every individual setter call during loading, is
		# what actually handles a saved scene whose Detector doesn't
		# match trigger_mode (an instanced prefab with trigger_mode
		# overridden away from its baked default).
		_rebuild_detector()
	else:
		# A trigger loaded from a saved scene already has its Detector —
		# _rebuild_detector() (and the signal connection it makes) never
		# runs for it. Signal.connect() calls made in code like that
		# don't reliably survive being saved to a scene and reloaded, so
		# without this the trigger silently never fires again once
		# placed, saved and reopened (or just played for real — the
		# normal case for anything actually shipped in a level). Re-run
		# the connection every time, idempotently, so a loaded trigger is
		# exactly as reliable as a freshly-built one.
		_connect_detector_signals()


## Tears down and rebuilds the detector subtree for the current
## trigger_mode — a walk-in Area3D and an interactable door are different
## node structures, so switching modes has to fully replace it. Re-applies
## detector_size afterward, so that setting isn't lost across a switch.
func _rebuild_detector() -> void:
	if has_node(_DETECTOR_NAME):
		var existing := get_node(_DETECTOR_NAME)
		if existing.owner == self:
			# This Detector came baked into a packed scene this node is an
			# *instance* of (scene_change_trigger.tscn — see its own doc
			# comment), and trigger_mode was changed on this specific
			# instance to something that needs a different node class.
			# Freeing it here and adding a same-named replacement would
			# leave two "Detector" nodes at the same path once saved — the
			# packed one (still referenced via the instance) and this
			# node's own local override — which Godot's loader detects as
			# a name collision on the next load and silently renames one
			# (confirmed by reproducing it with PackedScene.pack() +
			# ResourceSaver.save(), the same calls the editor's own Save
			# Scene uses). Renaming it out of the way instead — rather
			# than freeing it — makes Godot's own scene-diffing correctly
			# drop it from what actually gets saved, verified the same
			# way. Only disable its collision/monitoring here as a safety
			# net for the remainder of *this* editor session, since the
			# live tree still holds it until the scene is next saved.
			_retire_inherited_node(existing)
		else:
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
	_connect_detector_signals()


## Connects the detector's fire signal — Area3D.body_entered for AREA,
## InteractableComponent.interacted for INTERACT. Called both right after
## a fresh build (here) and from _ready() when the detector already
## existed (loaded from a saved scene) — see _ready()'s doc comment for
## why the latter is necessary. is_connected() guards make it safe to
## call from both places without ever double-connecting.
func _connect_detector_signals() -> void:
	if not has_node(_DETECTOR_NAME):
		return
	var detector := get_node(_DETECTOR_NAME)

	if trigger_mode == TriggerMode.AREA:
		var area := detector as Area3D
		if area and not area.body_entered.is_connected(_on_area_body_entered):
			area.body_entered.connect(_on_area_body_entered)
	else:
		if detector.has_node("InteractableComponent"):
			var interactable := detector.get_node("InteractableComponent")
			if not interactable.interacted.is_connected(_on_interacted):
				interactable.interacted.connect(_on_interacted)


## Renames a Detector inherited from the packed scene out of the way (see
## _rebuild_detector()'s comment for why this is renamed rather than
## freed) and disables whatever makes it active, so it sits as harmless,
## invisible dead weight for the rest of this editor session instead of
## blocking movement or double-firing this trigger.
func _retire_inherited_node(node: Node) -> void:
	node.name = "%s_Inherited_Unused" % _DETECTOR_NAME
	if node is Node3D:
		(node as Node3D).visible = false
	for child in node.get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).set_deferred("disabled", true)
	if node is Area3D:
		(node as Area3D).set_deferred("monitoring", false)
		(node as Area3D).set_deferred("monitorable", false)


## Whether the current Detector node's class already matches what
## trigger_mode needs — see the trigger_mode setter's doc comment for why
## this check exists (guards against rebuilding, and worse retiring, a
## Detector that's already correct).
func _detector_matches_mode() -> bool:
	var existing := get_node(_DETECTOR_NAME)
	if trigger_mode == TriggerMode.AREA:
		return existing is Area3D
	return existing is StaticBody3D


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


## Async: EXCLUSIVE awaits SceneManager.change_scene() so _triggered is
## only set once the load actually went through — see its doc comment on
## why that matters. ADDITIVE has no equivalent busy-guard on the
## SceneManager side, so it stays fire-and-forget.
func _fire() -> void:
	if _triggered:
		return
	if target_scene.is_empty():
		push_warning("SceneChangeTrigger '%s' fired with no target_scene assigned." % name)
		return

	if mode == LoadMode.EXCLUSIVE:
		if not await SceneManager.change_scene(target_scene, target_spawn_id, show_transition):
			return  # SceneManager was already mid-transition — try again later.
		_triggered = true
	else:
		_triggered = true
		SceneManager.add_scene(target_scene, show_transition)
