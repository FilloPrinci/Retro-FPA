extends Node
## Reads the "equip_slot_1".."equip_slot_4" inputs and forwards them to
## InventoryManager. Pressing the key for the already-equipped slot unequips
## it instead. Sibling component under Player, same style as
## Interactor/Grabber — knows nothing about the inventory UI.

const HOTBAR_ACTIONS := [
	"equip_slot_1",
	"equip_slot_2",
	"equip_slot_3",
	"equip_slot_4",
]


func _unhandled_input(event: InputEvent) -> void:
	if not GameManager.control_enabled:
		return
	for i in HOTBAR_ACTIONS.size():
		if event.is_action_pressed(HOTBAR_ACTIONS[i]):
			_toggle_slot(i)
			return


func _toggle_slot(index: int) -> void:
	if InventoryManager.get_equipped_index() == index:
		InventoryManager.unequip()
	else:
		InventoryManager.equip_slot(index)
