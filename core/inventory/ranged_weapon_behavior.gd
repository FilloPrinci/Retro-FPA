class_name RangedWeaponBehavior
extends WeaponBehavior
## A firearm — consumes ammo_item from the inventory on every shot.
## on_primary_use() does nothing at all (doesn't even start the cooldown)
## if there isn't enough ammo; a specific game can listen for that (e.g. by
## checking InventoryManager.has_item(ammo_item.id, ammo_per_shot) itself)
## to play a "click, empty" sound.

## The ammo this weapon consumes. Two guns can share the same ammo_item
## (e.g. two pistols both using "pistol_ammo") or each have their own.
@export var ammo_item: ItemData
@export var ammo_per_shot: int = 1


func on_primary_use(player: Node) -> void:
	if ammo_item == null or not InventoryManager.has_item(ammo_item.id, ammo_per_shot):
		return
	if _try_attack(player):
		InventoryManager.remove_item(ammo_item.id, ammo_per_shot)
