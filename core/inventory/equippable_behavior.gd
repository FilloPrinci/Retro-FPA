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


## Which procedural view-model animation EquippedItemView should play when
## this item is used (see EquippedItemView._play_use_animation for the
## actual motions). Override in a subclass to change the kind — "shake" is
## the sensible default for a plain equippable with no specific verb.
func get_use_animation() -> String:
	return "shake"
