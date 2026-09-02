extends Node
## Slot-based inventory with a single "equipped" slot. Autoload singleton.
##
## N generic/stackable slots (SLOT_COUNT). Equipping a slot only makes sense
## for ItemData.ItemType.EQUIPPABLE items; its EquippableBehavior drives what
## happens on equip/unequip/use — this manager never has game-specific logic
## in it.

signal inventory_changed
signal item_equipped(item: ItemData)
signal item_unequipped

const SLOT_COUNT := 8

var _slots: Array[InventorySlot] = []
var _equipped_index: int = -1


func _ready() -> void:
	for i in SLOT_COUNT:
		_slots.append(InventorySlot.new())


func get_slots() -> Array[InventorySlot]:
	return _slots


func get_equipped_item() -> ItemData:
	if _equipped_index == -1:
		return null
	return _slots[_equipped_index].item


func get_equipped_index() -> int:
	return _equipped_index


func add_item(item: ItemData, quantity: int = 1) -> bool:
	if item == null or quantity <= 0:
		return false

	var remaining := quantity

	if item.stackable:
		for slot in _slots:
			if remaining <= 0:
				break
			if slot.item == item and slot.quantity < item.max_stack:
				var space: int = item.max_stack - slot.quantity
				var added: int = mini(space, remaining)
				slot.quantity += added
				remaining -= added

	while remaining > 0:
		var free_slot := _find_empty_slot()
		if free_slot == null:
			break
		var added: int = mini(remaining, item.max_stack) if item.stackable else 1
		free_slot.item = item
		free_slot.quantity = added
		remaining -= added

	var added_any := remaining < quantity
	if added_any:
		inventory_changed.emit()
	return remaining == 0


func remove_item(item_id: String, quantity: int = 1) -> bool:
	if quantity <= 0:
		return false
	if not has_item(item_id, quantity):
		return false

	var remaining := quantity
	for i in _slots.size():
		if remaining <= 0:
			break
		var slot := _slots[i]
		if slot.is_empty() or slot.item.id != item_id:
			continue
		var removed: int = mini(slot.quantity, remaining)
		slot.quantity -= removed
		remaining -= removed
		if slot.quantity <= 0:
			if i == _equipped_index:
				unequip()
			slot.item = null
			slot.quantity = 0

	inventory_changed.emit()
	return true


func has_item(item_id: String, quantity: int = 1) -> bool:
	return get_item_count(item_id) >= quantity


## Total quantity held across every slot (a stackable item can be split
## across more than one slot once max_stack is reached).
func get_item_count(item_id: String) -> int:
	var total := 0
	for slot in _slots:
		if not slot.is_empty() and slot.item.id == item_id:
			total += slot.quantity
	return total


## Any item can be equipped/held (even a KEY or a plain GENERIC item, just
## to look at it in first-person view) — item_type doesn't gate this.
## EquippableBehavior is what makes an equipped item actually *do*
## something on use; an item with none just sits in EquippedItemView.
func equip_slot(index: int) -> void:
	if index < 0 or index >= _slots.size():
		return
	if _slots[index].is_empty():
		return

	unequip()
	_equipped_index = index
	var item := _slots[index].item
	if item.equip_behavior:
		item.equip_behavior.on_equip(GameManager.get_player())
	item_equipped.emit(item)


func unequip() -> void:
	if _equipped_index == -1:
		return
	var item := _slots[_equipped_index].item
	_equipped_index = -1
	if item and item.equip_behavior:
		item.equip_behavior.on_unequip(GameManager.get_player())
	item_unequipped.emit()


## Clears every slot. Called by SceneManager.start_new_game() so a fresh run
## never inherits a previous one's items.
func clear() -> void:
	unequip()
	for slot in _slots:
		slot.item = null
		slot.quantity = 0
	inventory_changed.emit()


func _find_empty_slot() -> InventorySlot:
	for slot in _slots:
		if slot.is_empty():
			return slot
	return null
