@tool
class_name InteractableComponent
extends Node
## Reusable "this thing can be interacted with" marker. Add as a child of
## any StaticBody3D/RigidBody3D/CharacterBody3D collider (door, NPC, pickup,
## lever, ...) and connect to `interacted` to react. The Player's Interactor
## finds this by looking at the children of whatever its ray hits.
##
## @tool: SceneChangeTrigger/WorldItem (both @tool) build this via
## set_script() and — for SceneChangeTrigger specifically — connect to
## `interacted` while still in the editor. A non-tool script attached this
## way loads as a placeholder instance in the editor (properties readable,
## but signals/methods aren't there), which is exactly what "Invalid
## access to property or key 'interacted'" was. Purely a signal
## declaration + an exported var, no _ready()/_process() of its own, so
## there's no gameplay-code-running-in-editor risk to weigh here.

signal interacted(interactor: Node)

## Translation key shown in the HUD prompt while this is in view (e.g.
## "UI_INTERACT_TALK", "UI_INTERACT_OPEN").
@export var prompt_text_key: String = "UI_INTERACT_DEFAULT"
