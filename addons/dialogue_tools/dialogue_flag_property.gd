@tool
extends EditorProperty
## Inspector widget for DialogueLine/DialogueChoice's flag fields
## (set_flag_key, required_flag_key) — a text field (so a brand-new flag
## can still be typed) plus a small "▾" button listing every flag already
## used anywhere under resources/dialogues/, so reusing one across
## dialogues is a click instead of retyping it exactly right.

var _line_edit: LineEdit
var _pick_button: MenuButton
var _updating := false


func _init() -> void:
	var hbox := HBoxContainer.new()

	_line_edit = LineEdit.new()
	_line_edit.size_flags_horizontal = SIZE_EXPAND_FILL
	_line_edit.text_changed.connect(_on_text_changed)
	hbox.add_child(_line_edit)

	_pick_button = MenuButton.new()
	_pick_button.text = "▾"
	_pick_button.tooltip_text = "Scegli un flag già usato altrove"
	_pick_button.about_to_popup.connect(_populate_menu)
	_pick_button.get_popup().id_pressed.connect(_on_flag_picked)
	hbox.add_child(_pick_button)

	add_child(hbox)
	add_focusable(_line_edit)


func _populate_menu() -> void:
	var popup := _pick_button.get_popup()
	popup.clear()
	var flags := _collect_known_flags()
	if flags.is_empty():
		popup.add_item("(nessun flag esistente)")
		popup.set_item_disabled(0, true)
		return
	for i in flags.size():
		popup.add_item(flags[i], i)


func _on_flag_picked(id: int) -> void:
	var flags := _collect_known_flags()
	if id < 0 or id >= flags.size():
		return
	_line_edit.text = flags[id]
	_on_text_changed(flags[id])


func _collect_known_flags() -> Array:
	var flags := {}
	var dir := DirAccess.open("res://resources/dialogues")
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var data: DialogueData = load("res://resources/dialogues/%s" % file_name)
				if data:
					_collect_flags_from(data, flags)
			file_name = dir.get_next()
		dir.list_dir_end()
	var result := flags.keys()
	result.sort()
	return result


func _collect_flags_from(data: DialogueData, flags: Dictionary) -> void:
	for line in data.lines:
		if not line.set_flag_key.is_empty():
			flags[line.set_flag_key] = true
		for choice in line.choices:
			if not choice.required_flag_key.is_empty():
				flags[choice.required_flag_key] = true
			if not choice.set_flag_key.is_empty():
				flags[choice.set_flag_key] = true


func _update_property() -> void:
	var current: String = get_edited_object().get(get_edited_property())
	_updating = true
	_line_edit.text = current
	_updating = false


func _on_text_changed(new_text: String) -> void:
	if _updating:
		return
	emit_changed(get_edited_property(), new_text)
