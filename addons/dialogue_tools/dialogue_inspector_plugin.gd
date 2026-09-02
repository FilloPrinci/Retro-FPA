@tool
extends EditorInspectorPlugin
## Swaps the default text field for several DialogueLine/DialogueChoice
## properties with purpose-built widgets:
## - next_id -> dropdown of ids that exist in the dialogue (dialogue_id_property.gd)
## - required_flag_key / set_flag_key -> text + "pick existing" (dialogue_flag_property.gd)
## - text_key / speaker_name_key -> key field + inline EN/IT text, read
##   from and written straight to translations/dialogue.csv
##   (dialogue_text_key_property.gd) — no more leaving the Inspector to
##   hand-edit the CSV.
## Every other property (id, ...) keeps its normal editor.
##
## _can_handle() is queried again for every nested sub-resource Godot's
## Inspector expands inline (a DialogueLine embedded in a DialogueData's
## `lines` array gets its own pass), so remembering the last DialogueData
## seen here is how the id dropdown knows which dialogue's ids to offer —
## it's always parsed just before the lines/choices nested under it are.

const ID_PROPERTY_SCRIPT := preload("res://addons/dialogue_tools/dialogue_id_property.gd")
const FLAG_PROPERTY_SCRIPT := preload("res://addons/dialogue_tools/dialogue_flag_property.gd")
const TEXT_KEY_PROPERTY_SCRIPT := preload("res://addons/dialogue_tools/dialogue_text_key_property.gd")

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
	if name == "text_key" or (name == "speaker_name_key" and object is DialogueLine):
		add_property_editor(name, TEXT_KEY_PROPERTY_SCRIPT.new())
		return true

	return false
