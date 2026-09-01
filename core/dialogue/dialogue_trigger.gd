class_name DialogueTrigger
extends Node
## Drop into a level as a sibling of an InteractableComponent (NPC, sign,
## ...) and assign a DialogueData. Connects itself to the
## InteractableComponent's `interacted` signal and starts the dialogue when
## interacted with — knows nothing about how the player found it.

@export var dialogue: DialogueData


func _ready() -> void:
	var interactable := _find_interactable()
	if interactable:
		interactable.interacted.connect(_on_interacted)
	else:
		push_warning("DialogueTrigger on '%s' has no sibling InteractableComponent." % get_parent().name)


func _on_interacted(_interactor: Node) -> void:
	if dialogue:
		DialogueManager.start_dialogue(dialogue)


func _find_interactable() -> InteractableComponent:
	for sibling in get_parent().get_children():
		if sibling is InteractableComponent:
			return sibling
	return null
