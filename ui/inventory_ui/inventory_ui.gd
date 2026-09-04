extends Control
## TAB-triggered inventory screen (GameManager.state == INVENTORY). Shows the
## InventoryManager slots as a grid. Clicking a slot *selects* it — shows its
## name/description and, if it holds an item, enables the Equip/Unequip
## button (any item can be equipped, not just weapons — see
## InventoryManager.equip_slot) — separately from equipping itself, so a
## long description can be read (and its scrollbar used) without losing the
## selection the way hover-to-preview did. Reacts to GameManager.state and
## InventoryManager's signals, same pattern as PauseMenu/HUD.

@onready var grid: GridContainer = $Panel/VBox/Grid
@onready var item_name_label: Label = $Panel/VBox/Details/ItemNameLabel
@onready var item_description_label: Label = $Panel/VBox/Details/DescriptionScroll/ItemDescriptionLabel
@onready var equip_button: Button = $Panel/VBox/ButtonRow/EquipButton
@onready var close_button: Button = $Panel/VBox/ButtonRow/CloseButton

var _slot_buttons: Array[Button] = []
var _equipped_stylebox: StyleBoxFlat
var _selected_stylebox: StyleBoxFlat
var _equipped_selected_stylebox: StyleBoxFlat
var _selected_index: int = -1


func _ready() -> void:
	visible = false
	_build_styleboxes()
	_build_slot_buttons()
	_clear_selection()

	close_button.focus_mode = Control.FOCUS_NONE
	equip_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(_close)
	equip_button.pressed.connect(_on_equip_button_pressed)
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


func _build_styleboxes() -> void:
	_equipped_stylebox = StyleBoxFlat.new()
	_equipped_stylebox.bg_color = Color(1.0, 0.85, 0.2, 0.25)
	_equipped_stylebox.border_color = Color(1.0, 0.85, 0.2)
	_equipped_stylebox.set_border_width_all(3)
	_equipped_stylebox.set_corner_radius_all(3)

	_selected_stylebox = StyleBoxFlat.new()
	_selected_stylebox.bg_color = Color(1, 1, 1, 0.12)
	_selected_stylebox.border_color = Color(1, 1, 1, 0.9)
	_selected_stylebox.set_border_width_all(2)
	_selected_stylebox.set_corner_radius_all(3)

	# Equipped AND selected at once: the gold fill (equipped) plus the
	# white border (selected), so neither cue gets silently dropped.
	_equipped_selected_stylebox = StyleBoxFlat.new()
	_equipped_selected_stylebox.bg_color = _equipped_stylebox.bg_color
	_equipped_selected_stylebox.border_color = _selected_stylebox.border_color
	_equipped_selected_stylebox.set_border_width_all(3)
	_equipped_selected_stylebox.set_corner_radius_all(3)


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
		grid.add_child(button)
		_slot_buttons.append(button)


func _open() -> void:
	GameManager.state = GameManager.GameState.INVENTORY
	GameManager.set_control_enabled(false)
	_clear_selection()
	_refresh()
	visible = true


func _close() -> void:
	GameManager.set_control_enabled(true)
	GameManager.state = GameManager.GameState.PLAYING
	visible = false


func _refresh() -> void:
	var slots := InventoryManager.get_slots()
	var equipped_index := InventoryManager.get_equipped_index()

	# A slot that emptied out from under the current selection (e.g. its
	# last stack was consumed) can't stay selected — nothing to show or
	# equip anymore.
	if _selected_index != -1 and slots[_selected_index].is_empty():
		_selected_index = -1

	for i in slots.size():
		var slot := slots[i]
		var button := _slot_buttons[i]
		if slot.is_empty():
			button.icon = null
			button.text = ""
			button.disabled = false
			button.remove_theme_stylebox_override("normal")
			continue

		button.disabled = false
		button.icon = slot.item.icon
		button.text = str(slot.quantity) if slot.item.stackable and slot.quantity > 1 else ""
		_apply_slot_style(button, i == equipped_index, i == _selected_index)

	_refresh_details()


func _apply_slot_style(button: Button, is_equipped: bool, is_selected: bool) -> void:
	if is_equipped and is_selected:
		button.add_theme_stylebox_override("normal", _equipped_selected_stylebox)
	elif is_equipped:
		button.add_theme_stylebox_override("normal", _equipped_stylebox)
	elif is_selected:
		button.add_theme_stylebox_override("normal", _selected_stylebox)
	else:
		button.remove_theme_stylebox_override("normal")


## Click selects the slot (shows its details, and enables the Equip/
## Unequip button below) — it no longer equips by itself. Clicking an
## already-selected slot, or an empty one, just clears the selection.
func _on_slot_pressed(index: int) -> void:
	var slot := InventoryManager.get_slots()[index]
	if slot.is_empty() or _selected_index == index:
		_selected_index = -1
	else:
		_selected_index = index
	_refresh()


func _on_equip_button_pressed() -> void:
	if _selected_index == -1:
		return
	if InventoryManager.get_equipped_index() == _selected_index:
		InventoryManager.unequip()
	else:
		InventoryManager.equip_slot(_selected_index)


func _clear_selection() -> void:
	_selected_index = -1
	_refresh_details()


func _refresh_details() -> void:
	if _selected_index == -1:
		item_name_label.text = ""
		item_description_label.text = ""
		equip_button.disabled = true
		equip_button.text = tr("UI_EQUIP")
		return

	var slot := InventoryManager.get_slots()[_selected_index]
	item_name_label.text = tr(slot.item.display_name_key)
	item_description_label.text = tr(slot.item.description_key)
	equip_button.disabled = false
	var is_equipped := InventoryManager.get_equipped_index() == _selected_index
	equip_button.text = tr("UI_UNEQUIP" if is_equipped else "UI_EQUIP")
