class_name InteractableComponent
extends Node
## Reusable "this thing can be interacted with" marker. Add as a child of
## any StaticBody3D/RigidBody3D/CharacterBody3D collider (door, NPC, pickup,
## lever, ...) and connect to `interacted` to react. The Player's Interactor
## finds this by looking at the children of whatever its ray hits.

signal interacted(interactor: Node)

## Translation key shown in the HUD prompt while this is in view (e.g.
## "UI_INTERACT_TALK", "UI_INTERACT_OPEN").
@export var prompt_text_key: String = "UI_INTERACT_DEFAULT"
