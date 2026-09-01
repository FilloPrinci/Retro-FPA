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
@export var item_type: ItemType = ItemType.GENERIC
@export var stackable: bool = true
@export var max_stack: int = 99
## Only used when item_type == EQUIPPABLE. See EquippableBehavior.
@export var equip_behavior: EquippableBehavior
