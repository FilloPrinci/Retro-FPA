class_name AnimationController
extends Node
## Drives an AnimationPlayer from logical state names via an AnimationSet.
## Identical component for the player and every NPC — only the AnimationSet
## (and the model) differ per character. See docs/blender_workflow.md for
## the full authoring workflow.

## Assign explicitly, or leave empty to auto-find the first AnimationPlayer
## under this node's parent (e.g. nested inside an imported model scene).
@export var animation_player: AnimationPlayer
@export var animation_set: AnimationSet
## Crossfade time in seconds when switching states.
@export var blend_time: float = 0.15

var _current_state: String = ""


func _ready() -> void:
	if animation_player == null:
		animation_player = _find_animation_player()


## Plays the clip mapped to `state` via the assigned AnimationSet. No-op if
## already in that state, unless `force` is set (e.g. to restart a one-shot
## like "hello"). Silently does nothing if there's no AnimationPlayer/
## AnimationSet yet (e.g. a placeholder character with no model) or the
## state isn't mapped to an existing clip.
func play_state(state: String, force: bool = false) -> void:
	if animation_player == null or animation_set == null:
		return
	if state == _current_state and not force:
		return

	var clip_name := animation_set.get_clip_name(state)
	if clip_name.is_empty() or not animation_player.has_animation(clip_name):
		push_warning("AnimationController: state '%s' has no matching clip on %s." % [state, animation_player.name])
		return

	_current_state = state
	animation_player.play(clip_name, blend_time)


func get_current_state() -> String:
	return _current_state


func _find_animation_player() -> AnimationPlayer:
	var parent := get_parent()
	if parent == null:
		return null
	var found := parent.find_children("*", "AnimationPlayer", true, false)
	return found[0] as AnimationPlayer if not found.is_empty() else null
