extends Node
## Forwards "primary_action"/"secondary_action" to the currently equipped
## item's EquippableBehavior — the missing link between input and
## EquippableBehavior.on_primary_use()/on_secondary_use(), which nothing
## else in the template calls. Sibling component under Player, same style
## as Interactor/Grabber.
##
## No coordination needed with Grabber: picking up/dropping a physical
## prop uses "interact" (see grabber.gd), unified with every other
## interaction in the game, so it never competes with primary_action/
## secondary_action. While something's held, nothing's equipped (Grabber
## auto-unequips around a grab), so get_equipped_item() is null below and
## this naturally does nothing until the item is re-equipped on release.
##
## Also emits primary_used/secondary_used on every press, regardless of
## whether the behavior actually did anything (cooldown, out of ammo, ...) —
## EquippedItemView listens for these to always play a view-model
## animation on use, which is a feel/feedback concern independent of
## whether the underlying action was gated.

signal primary_used(item: ItemData)
signal secondary_used(item: ItemData)


func _unhandled_input(event: InputEvent) -> void:
	if not GameManager.control_enabled:
		return
	var item := InventoryManager.get_equipped_item()
	if item == null or item.equip_behavior == null:
		return

	if event.is_action_pressed("primary_action"):
		item.equip_behavior.on_primary_use(get_owner())
		primary_used.emit(item)
	elif event.is_action_pressed("secondary_action"):
		item.equip_behavior.on_secondary_use(get_owner())
		secondary_used.emit(item)
