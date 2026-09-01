class_name AnimationSet
extends Resource
## Maps logical animation states to the actual clip names baked into a
## character's imported .glb. One .tres per character type under
## resources/animation_sets/ — a model with differently named clips only
## needs a new AnimationSet, never a code change. See
## docs/blender_workflow.md for the full authoring workflow.

## Base locomotion states every character is expected to have.
@export var idle: String = "idle"
@export var walk: String = "walk"

## Anything beyond idle/walk (attack, hello, run, ...): state name -> clip
## name. Left as a free-form map instead of dedicated fields since these are
## character/game-specific, not universal.
@export var custom_states: Dictionary = {}


## Resolves a logical state name to the actual AnimationPlayer clip name.
## Returns "" if the state isn't mapped.
func get_clip_name(state: String) -> String:
	match state:
		"idle":
			return idle
		"walk":
			return walk
		_:
			return custom_states.get(state, "")
