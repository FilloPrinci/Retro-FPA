extends Node
## Lightweight branching dialogue runner. Autoload singleton.
##
## Drives GameManager.state = DIALOGUE (locking player control) for the
## duration of a conversation. Content is entirely data-driven via
## DialogueData/DialogueLine/DialogueChoice resources — this script only
## walks the id graph, it never contains story-specific logic.

signal line_changed(speaker_name_key: String, text_key: String)
signal choices_presented(choices: Array[DialogueChoice])
signal dialogue_ended

var _lines_by_id: Dictionary = {}
var _current_line: DialogueLine = null
var _is_active: bool = false


func start_dialogue(dialogue: DialogueData, start_id: String = "") -> void:
	if dialogue == null or dialogue.lines.is_empty():
		push_warning("DialogueManager.start_dialogue() called with an empty DialogueData.")
		return

	_lines_by_id = {}
	for line in dialogue.lines:
		_lines_by_id[line.id] = line

	_is_active = true
	GameManager.set_control_enabled(false)
	GameManager.state = GameManager.GameState.DIALOGUE

	var first_id := start_id
	if first_id.is_empty():
		first_id = dialogue.start_id if not dialogue.start_id.is_empty() else dialogue.lines[0].id
	_show_line(first_id)


## Moves to the current line's next_id. No-op while choices are on screen —
## choose() drives those instead.
func advance() -> void:
	if not _is_active or _current_line == null:
		return
	if not _available_choices(_current_line).is_empty():
		return
	_goto(_current_line.next_id)


## Picks choice `index` among the currently available (flag-gated) choices.
func choose(index: int) -> void:
	if not _is_active or _current_line == null:
		return
	var choices := _available_choices(_current_line)
	if index < 0 or index >= choices.size():
		return
	var choice := choices[index]
	_apply_flag(choice.set_flag_key, choice.set_flag_value)
	_goto(choice.next_id)


func end_dialogue() -> void:
	if not _is_active:
		return
	_is_active = false
	_current_line = null
	_lines_by_id = {}
	GameManager.set_control_enabled(true)
	GameManager.state = GameManager.GameState.PLAYING
	dialogue_ended.emit()


func is_active() -> bool:
	return _is_active


func _goto(next_id: String) -> void:
	if next_id.is_empty():
		end_dialogue()
	else:
		_show_line(next_id)


func _show_line(id: String) -> void:
	var line: DialogueLine = _lines_by_id.get(id)
	if line == null:
		push_warning("DialogueManager: unknown line id '%s', ending dialogue." % id)
		end_dialogue()
		return

	_current_line = line
	_apply_flag(line.set_flag_key, line.set_flag_value)
	line_changed.emit(line.speaker_name_key, line.text_key)

	var choices := _available_choices(line)
	if not choices.is_empty():
		choices_presented.emit(choices)


func _available_choices(line: DialogueLine) -> Array[DialogueChoice]:
	var result: Array[DialogueChoice] = []
	for choice in line.choices:
		if choice.required_flag_key.is_empty() or GameManager.get_flag(choice.required_flag_key, false) == choice.required_flag_value:
			result.append(choice)
	return result


func _apply_flag(key: String, value: bool) -> void:
	if not key.is_empty():
		GameManager.set_flag(key, value)
