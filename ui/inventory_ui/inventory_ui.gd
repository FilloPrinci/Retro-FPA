extends Control
## TAB-triggered inventory screen (GameManager.state == INVENTORY). Shows the
## InventoryManager slots as a grid; clicking a slot selects it (shows name +
## description) and, for EQUIPPABLE items, equips it — clicking the already
## equipped slot unequips it. Reacts to GameManager.state and
## InventoryManager's signals, same pattern as PauseMenu/HUD.

const EQUIPPED_TINT := Color(1.0, 0.85, 0.4)
const DEFAULT_TINT := Color(1.0, 1.0, 1.0)

@onready var grid: GridContainer = $Panel/VBox/Grid
@onready var item_name_label: Label = $Panel/VBox/Details/ItemNameLabel
@onready var item_description_label: Label = $Panel/VBox/Details/ItemDescriptionLabel
@onready var close_button: Button = $Panel/VBox/CloseButton

var _slot_buttons: Array[Button] = []


func _ready() -> void:
	visible = false
	_build_slot_buttons()
	_clear_details()

	close_button.pressed.connect(_close)
	InventoryManager.inventory_changed.connect(_refresh)
	InventoryManager.item_equipped.connect(func(_item): _refresh())
	InventoryManager.item_unequipped.connect(_refresh)

	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory_toggle"):
		if GameManager.state == GameManager.GameState.PLAYING:
			_open()
		elif GameManager.state == GameManager.GameState.INVENTORY:
			_close()
	elif event.is_action_pressed("pause") and GameManager.state == GameManager.GameState.INVENTORY:
		_close()


func _build_slot_buttons() -> void:
	for i in InventoryManager.SLOT_COUNT:
		var button := Button.new()
		button.custom_minimum_size = Vector2(40, 40)
		button.expand_icon = true
		button.pressed.connect(_on_slot_pressed.bind(i))
		grid.add_child(button)
		_slot_buttons.append(button)


func _open() -> void:
	GameManager.state = GameManager.GameState.INVENTORY
	GameManager.set_control_enabled(false)
	_refresh()
	visible = true


func _close() -> void:
	GameManager.set_control_enabled(true)
	GameManager.state = GameManager.GameState.PLAYING
	visible = false


func _refresh() -> void:
	var slots := InventoryManager.get_slots()
	var equipped_index := InventoryManager.get_equipped_index()

	for i in slots.size():
		var slot := slots[i]
		var button := _slot_buttons[i]
		if slot.is_empty():
			button.icon = null
			button.text = ""
			button.disabled = true
			button.modulate = DEFAULT_TINT
			continue

		button.disabled = false
		button.icon = slot.item.icon
		button.text = str(slot.quantity) if slot.item.stackable and slot.quantity > 1 else ""
		button.modulate = EQUIPPED_TINT if i == equipped_index else DEFAULT_TINT


func _on_slot_pressed(index: int) -> void:
	var slot := InventoryManager.get_slots()[index]
	if slot.is_empty():
		return

	item_name_label.text = tr(slot.item.display_name_key)
	item_description_label.text = tr(slot.item.description_key)

	if slot.item.item_type != ItemData.ItemType.EQUIPPABLE:
		return
	if InventoryManager.get_equipped_index() == index:
		InventoryManager.unequip()
	else:
		InventoryManager.equip_slot(index)


func _clear_details() -> void:
	item_name_label.text = ""
	item_description_label.text = ""
