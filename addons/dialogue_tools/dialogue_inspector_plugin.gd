@tool
extends EditorInspectorPlugin
## Swaps the default text field for DialogueLine/DialogueChoice.next_id and
## the two flag fields with the dropdown widgets in
## dialogue_id_property.gd / dialogue_flag_property.gd. Every other
## property (id, text_key, speaker_name_key, ...) keeps its normal editor.
##
## _can_handle() is queried again for every nested sub-resource Godot's
## Inspector expands inline (a DialogueLine embedded in a DialogueData's
## `lines` array gets its own pass), so remembering the last DialogueData
## seen here is how the id dropdown knows which dialogue's ids to offer —
## it's always parsed just before the lines/choices nested under it are.

const ID_PROPERTY_SCRIPT := preload("res://addons/dialogue_tools/dialogue_id_property.gd")
const FLAG_PROPERTY_SCRIPT := preload("res://addons/dialogue_tools/dialogue_flag_property.gd")

var _current_dialogue_data: DialogueData = null


func _can_handle(object: Object) -> bool:
	if object is DialogueData:
		_current_dialogue_data = object
	return object is DialogueData or object is DialogueLine or object is DialogueChoice


func _parse_property(object: Object, type: Variant.Type, name: String, hint_type: PropertyHint, hint_string: String, usage_flags: int, wide: bool) -> bool:
	if not (object is DialogueLine or object is DialogueChoice):
		return false

	if name == "next_id":
		add_property_editor(name, ID_PROPERTY_SCRIPT.new(_current_dialogue_data))
		return true
	if name == "required_flag_key" or name == "set_flag_key":
		add_property_editor(name, FLAG_PROPERTY_SCRIPT.new())
		return true

	return false
