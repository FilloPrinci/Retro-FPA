@tool
extends EditorProperty
## Inspector widget for DialogueLine.next_id / DialogueChoice.next_id — an
## OptionButton listing every id already present in the DialogueData
## currently open in the Inspector, instead of a free-text field where a
## typo silently breaks the link (DialogueManager only warns about it at
## runtime, mid-playtest). First entry is always the empty string, which
## means "ends the dialogue" — same as leaving the text field blank did.

var _option: OptionButton
var _dialogue_data: WeakRef
var _updating := false


func _init(dialogue_data: DialogueData) -> void:
	# dialogue_data can legitimately be null (e.g. this line's parent
	# DialogueData was never itself parsed by the Inspector in this
	# session) — weakref(null) is fine, _refresh_items() just shows only
	# the "ends the dialogue" entry in that case.
	_dialogue_data = weakref(dialogue_data)
	_option = OptionButton.new()
	_option.size_flags_horizontal = SIZE_EXPAND_FILL
	_option.item_selected.connect(_on_item_selected)
	# _update_property() alone misses ids added to a *sibling* line
	# elsewhere in the Inspector after this dropdown was built (adding an
	# element to `lines` doesn't retroactively refresh an already-open
	# choice's next_id dropdown). about_to_popup turned out to fire too
	# late/unreliably to actually repopulate before the user sees the
	# list, so refresh earlier instead — on hover and on focus, both well
	# before any click reaches OptionButton's own popup-building logic.
	_option.mouse_entered.connect(_refresh_and_reselect)
	_option.focus_entered.connect(_refresh_and_reselect)
	add_child(_option)
	add_focusable(_option)


func _refresh_items() -> void:
	_option.clear()
	_option.add_item("(vuoto) — termina il dialogo")
	_option.set_item_metadata(0, "")

	var data: DialogueData = _dialogue_data.get_ref() if _dialogue_data else null
	if data == null:
		return
	for line in data.lines:
		if line.id.is_empty():
			continue
		_option.add_item(line.id)
		_option.set_item_metadata(_option.item_count - 1, line.id)


func _refresh_and_reselect() -> void:
	_refresh_items()
	var current: String = get_edited_object().get(get_edited_property())

	_updating = true
	for i in _option.item_count:
		if _option.get_item_metadata(i) == current:
			_option.selected = i
			_updating = false
			return

	# The stored value isn't a known id in this dialogue (a stale/broken
	# reference, or one to a line that got renamed/removed) — show it
	# anyway as its own entry instead of silently snapping the field to
	# something else, so it stays visible and DialogueValidator can catch it.
	if not current.is_empty():
		_option.add_item("%s (non trovato)" % current)
		_option.set_item_metadata(_option.item_count - 1, current)
		_option.selected = _option.item_count - 1
	_updating = false


func _update_property() -> void:
	_refresh_and_reselect()


func _on_item_selected(index: int) -> void:
	if _updating:
		return
	var value = _option.get_item_metadata(index)
	emit_changed(get_edited_property(), value)
