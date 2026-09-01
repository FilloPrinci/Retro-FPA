extends Node
## Forwards "primary_action"/"secondary_action" to the currently equipped
## item's EquippableBehavior — the missing link between input and
## EquippableBehavior.on_primary_use()/on_secondary_use(), which nothing
## else in the template calls. Sibling component under Player, same style
## as Interactor/Grabber.
##
## Takes priority over Grabber: Grabber checks
## InventoryManager.get_equipped_item() and skips its own grab/throw
## handling while something is equipped, so you can't grab world props
## while holding a weapon.

func _unhandled_input(event: InputEvent) -> void:
	if not GameManager.control_enabled:
		return
	var item := InventoryManager.get_equipped_item()
	if item == null or item.equip_behavior == null:
		return

	if event.is_action_pressed("primary_action"):
		item.equip_behavior.on_primary_use(get_owner())
	elif event.is_action_pressed("secondary_action"):
		item.equip_behavior.on_secondary_use(get_owner())
