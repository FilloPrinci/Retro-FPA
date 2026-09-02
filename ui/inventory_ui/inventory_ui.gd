extends Control
## TAB-triggered inventory screen (GameManager.state == INVENTORY). Shows the
## InventoryManager slots as a grid; hovering a slot shows its name +
## description, clicking it equips it (any item can be equipped, not just
## weapons — see InventoryManager.equip_slot) — clicking the already
## equipped slot unequips it. Reacts to GameManager.state and
## InventoryManager's signals, same pattern as PauseMenu/HUD.

@onready var grid: GridContainer = $Panel/VBox/Grid
@onready var item_name_label: Label = $Panel/VBox/Details/ItemNameLabel
@onready var item_description_label: Label = $Panel/VBox/Details/ItemDescriptionLabel
@onready var close_button: Button = $Panel/VBox/CloseButton

var _slot_buttons: Array[Button] = []
var _equipped_stylebox: StyleBoxFlat


func _ready() -> void:
	visible = false
	_build_equipped_stylebox()
	_build_slot_buttons()
	_clear_details()

	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(_close)
	InventoryManager.inventory_changed.connect(_refresh)
	InventoryManager.item_equipped.connect(func(_item): _refresh())
	InventoryManager.item_unequipped.connect(_refresh)

	_refresh()


## Uses _input (fires before Control's own GUI dispatch) and consumes the
## event on toggle, so Tab doesn't also reach the focused slot button's
## built-in ui_focus_next handling — otherwise a second Tab press while the
## inventory is open selects the next slot instead of closing the panel.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory_toggle"):
		if GameManager.state == GameManager.GameState.PLAYING:
			_open()
			get_viewport().set_input_as_handled()
		elif GameManager.state == GameManager.GameState.INVENTORY:
			_close()
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause") and GameManager.state == GameManager.GameState.INVENTORY:
		_close()
		get_viewport().set_input_as_handled()


func _build_equipped_stylebox() -> void:
	_equipped_stylebox = StyleBoxFlat.new()
	_equipped_stylebox.bg_color = Color(1.0, 0.85, 0.2, 0.25)
	_equipped_stylebox.border_color = Color(1.0, 0.85, 0.2)
	_equipped_stylebox.set_border_width_all(3)
	_equipped_stylebox.set_corner_radius_all(3)


func _build_slot_buttons() -> void:
	for i in InventoryManager.SLOT_COUNT:
		var button := Button.new()
		button.custom_minimum_size = Vector2(40, 40)
		button.expand_icon = true
		# Mouse-driven UI — no keyboard/gamepad focus navigation needed,
		# and leaving it on would let Tab (also inventory_toggle) cycle
		# focus between slots via the engine's built-in ui_focus_next.
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_on_slot_pressed.bind(i))
		button.mouse_entered.connect(_on_slot_hovered.bind(i))
		button.mouse_exited.connect(_clear_details)
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
			button.remove_theme_stylebox_override("normal")
			continue

		button.disabled = false
		button.icon = slot.item.icon
		button.text = str(slot.quantity) if slot.item.stackable and slot.quantity > 1 else ""
		if i == equipped_index:
			button.add_theme_stylebox_override("normal", _equipped_stylebox)
		else:
			button.remove_theme_stylebox_override("normal")


## Hover shows the item's name/description — no click needed.
func _on_slot_hovered(index: int) -> void:
	var slot := InventoryManager.get_slots()[index]
	if slot.is_empty():
		_clear_details()
		return
	item_name_label.text = tr(slot.item.display_name_key)
	item_description_label.text = tr(slot.item.description_key)


## Click only equips/unequips — the equipped slot gets _equipped_stylebox
## in _refresh() so it's clearly highlighted.
func _on_slot_pressed(index: int) -> void:
	var slot := InventoryManager.get_slots()[index]
	if slot.is_empty():
		return

	if InventoryManager.get_equipped_index() == index:
		InventoryManager.unequip()
	else:
		InventoryManager.equip_slot(index)


func _clear_details() -> void:
	item_name_label.text = ""
	item_description_label.text = ""
