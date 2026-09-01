class_name InventorySlot
extends RefCounted
## Runtime (non-persisted) state of a single inventory slot. Not a Resource:
## this only exists in memory, ItemData is the data-driven part.

var item: ItemData = null
var quantity: int = 0


func is_empty() -> bool:
	return item == null
