class_name ItemPickup
extends Node
## Drop into a level as a sibling of an InteractableComponent (the same
## pattern as DialogueTrigger) to make that object a pickup: interacting
## with it adds `item` to the inventory and removes the pickup from the
## world.
##
## Remembers having been taken via a GameManager flag keyed by this
## pickup's own stable path within the level (SceneManager.
## get_path_in_level() — "pickup_taken:<path>"), so it removes itself
## again on _ready() instead of reappearing the next time the level is
## loaded fresh — which happens on *any* reload, not just a save/load:
## re-entering the same level via a SceneChangeTrigger re-instantiates it
## from scratch same as change_scene() always has. Without this, a
## player could pick something up, leave and come back (or save, quit,
## and reload) to find it sitting there again — free, unlimited copies
## of whatever it was. Since GameManager flags are exactly what
## SaveManager already persists, this needs nothing save-system-specific
## here at all.

@export var item: ItemData
@export var quantity: int = 1


func _ready() -> void:
	if _already_taken():
		get_parent().queue_free()
		return
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
		_mark_taken()
		get_parent().queue_free()


func _find_interactable() -> InteractableComponent:
	for sibling in get_parent().get_children():
		if sibling is InteractableComponent:
			return sibling
	return null


func _already_taken() -> bool:
	var key := _flag_key()
	return not key.is_empty() and GameManager.get_flag(key, false)


func _mark_taken() -> void:
	var key := _flag_key()
	if not key.is_empty():
		GameManager.set_flag(key, true)


## "" outside a real level (e.g. a standalone test scene) — _already_taken()
## then always reads false and _mark_taken() no-ops, same as if this
## whole mechanism didn't exist, rather than erroring.
func _flag_key() -> String:
	var path := SceneManager.get_path_in_level(get_parent())
	if path.is_empty():
		return ""
	return "pickup_taken:%s" % path
