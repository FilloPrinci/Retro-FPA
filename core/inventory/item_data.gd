class_name ItemData
extends Resource
## Data-driven definition of a pickup-able item. Create one .tres per item
## under resources/items/ and reference it from pickups, NPC drops, etc.
## Content design should never require touching InventoryManager's code.

enum ItemType {
	GENERIC,
	EQUIPPABLE,
	KEY,
	CONSUMABLE,
}

@export var id: String = ""
@export var display_name_key: String = ""
@export var description_key: String = ""
@export var icon: Texture2D
## Optional scene used when this item exists as a physical pickup in the
## world (e.g. a Grabbable variant with an InteractableComponent).
@export var world_model: PackedScene
## Optional scene shown in first-person view (under Player's EquipAnchor)
## whenever this item is equipped — just the visual mesh, no collision or
## pickup logic. Any item can be equipped (InventoryManager.equip_slot()
## doesn't gate on item_type — even a KEY can be held up to look at), so
## this isn't EQUIPPABLE-only; it's simply unused for items nobody ever
## equips. Kept distinct from world_model: that one is (or will be) the
## in-world pickup appearance, which itself references this ItemData back
## — reusing it here would create a resource loading cycle.
@export var view_model: PackedScene
@export var item_type: ItemType = ItemType.GENERIC
@export var stackable: bool = true
@export var max_stack: int = 99
## Optional equip-time behavior (attack on use, etc.) — most non-weapon
## items leave this null and just show their view_model when equipped.
@export var equip_behavior: EquippableBehavior
