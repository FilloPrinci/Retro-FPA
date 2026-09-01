class_name EquippableBehavior
extends Resource
## Base class for the equip-time behavior of an EQUIPPABLE item (flashlight,
## weapon, tool, ...). Subclass this in its own .gd file with its own
## class_name, override only the hooks you need, and assign an instance to
## ItemData.equip_behavior. Example subclasses live in
## resources/items/behaviors/.

## Called once when this item becomes the equipped slot.
func on_equip(_player: Node) -> void:
	pass


## Called once when this item stops being the equipped slot.
func on_unequip(_player: Node) -> void:
	pass


## Called on the "primary_action" input while this item is equipped.
func on_primary_use(_player: Node) -> void:
	pass


## Called on the "secondary_action" input while this item is equipped.
func on_secondary_use(_player: Node) -> void:
	pass
