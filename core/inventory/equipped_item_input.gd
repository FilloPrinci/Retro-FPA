extends Node
## Forwards "primary_action"/"secondary_action" to the currently equipped
## item's EquippableBehavior — the missing link between input and
## EquippableBehavior.on_primary_use()/on_secondary_use(), which nothing
## else in the template calls. Sibling component under Player, same style
## as Interactor/Grabber.
##
## Yields to Grabber on "primary_action": if there's a Grabbable under the
## crosshair (or one is already held), that press grabs/throws it instead
## of firing the equipped item — Grabber itself unequips/re-equips around
## the grab (see grabber.gd), so this only needs to skip its own action for
## that one press, not care about the equip state changing around it.
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
		if _grabber_wants_primary():
			return
		item.equip_behavior.on_primary_use(get_owner())
		primary_used.emit(item)
	elif event.is_action_pressed("secondary_action"):
		item.equip_behavior.on_secondary_use(get_owner())
		secondary_used.emit(item)


func _grabber_wants_primary() -> bool:
	var grabber := get_owner().get_node_or_null("Grabber") if get_owner() else null
	if grabber == null:
		return false
	return grabber.is_holding() or grabber.has_grab_target()
