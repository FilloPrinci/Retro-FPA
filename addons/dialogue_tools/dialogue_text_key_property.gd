@tool
extends EditorProperty
## Inspector widget for DialogueLine.text_key / speaker_name_key and
## DialogueChoice.text_key. The key itself stays an editable text field
## (it can still be renamed, or a new one typed for a brand-new line/
## choice), but right below it are the EN/IT translation text fields —
## read from and, on commit, written straight to translations/dialogue.csv
## via DialogueTranslationIO. No more leaving the Inspector to hand-edit
## the CSV for every line.
##
## Writes commit on focus-lost/Enter, not on every keystroke, to avoid
## rewriting the CSV (and triggering a filesystem rescan) on every
## character typed.

var _key_edit: LineEdit
var _en_edit: LineEdit
var _it_edit: LineEdit
var _updating := false


func _init() -> void:
	var vbox := VBoxContainer.new()

	_key_edit = LineEdit.new()
	_key_edit.placeholder_text = "chiave di traduzione"
	_key_edit.text_changed.connect(_on_key_changed)
	vbox.add_child(_key_edit)

	_en_edit = _make_translation_row(vbox, "EN:")
	_it_edit = _make_translation_row(vbox, "IT:")

	add_child(vbox)
	add_focusable(_key_edit)


func _make_translation_row(parent: VBoxContainer, prefix: String) -> LineEdit:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = prefix
	label.custom_minimum_size = Vector2(24, 0)
	row.add_child(label)

	var edit := LineEdit.new()
	edit.size_flags_horizontal = SIZE_EXPAND_FILL
	edit.focus_exited.connect(_commit_translation)
	edit.text_submitted.connect(func(_text): _commit_translation())
	row.add_child(edit)

	parent.add_child(row)
	return edit


func _update_property() -> void:
	var current: String = get_edited_object().get(get_edited_property())
	_updating = true
	_key_edit.text = current
	_load_translation(current)
	_updating = false


func _load_translation(key: String) -> void:
	var row := DialogueTranslationIO.get_row(key) if not key.is_empty() else {"en": "", "it": ""}
	_en_edit.text = row.en
	_it_edit.text = row.it


func _on_key_changed(new_key: String) -> void:
	if _updating:
		return
	_updating = true
	_load_translation(new_key)
	_updating = false
	emit_changed(get_edited_property(), new_key)


func _commit_translation() -> void:
	if _updating:
		return
	var key: String = get_edited_object().get(get_edited_property())
	if key.is_empty():
		return
	DialogueTranslationIO.set_row(key, _en_edit.text, _it_edit.text)
	EditorInterface.get_resource_filesystem().scan()
