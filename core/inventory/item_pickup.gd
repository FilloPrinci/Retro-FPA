class_name ItemPickup
extends Node
## Drop into a level as a sibling of an InteractableComponent (the same
## pattern as DialogueTrigger) to make that object a pickup: interacting
## with it adds `item` to the inventory and removes the pickup from the
## world.

@export var item: ItemData
@export var quantity: int = 1


func _ready() -> void:
	var interactable := _find_interactable()
	if interactable:
		interactable.interacted.connect(_on_interacted)
	else:
		push_warning("ItemPickup on '%s' has no sibling InteractableComponent." % get_parent().name)


func _on_interacted(_interactor: Node) -> void:
	if item == null:
		return
	# If the inventory is full, add_item() adds as much as it can and
	# returns false — leave the pickup in the world rather than silently
	# discarding whatever didn't fit.
	if InventoryManager.add_item(item, quantity):
		get_parent().queue_free()


func _find_interactable() -> InteractableComponent:
	for sibling in get_parent().get_children():
		if sibling is InteractableComponent:
			return sibling
	return null
