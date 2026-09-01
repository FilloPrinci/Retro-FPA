class_name DialogueLine
extends Resource
## One line of a DialogueData tree, addressed by `id` rather than by its
## position in the array — branches and loops don't need to be listed in
## visiting order. Create these as sub-resources of a DialogueData .tres.

@export var id: String = ""
## Empty for a narrator/unattributed line.
@export var speaker_name_key: String = ""
@export var text_key: String = ""

## Optional: set on GameManager the moment this line is shown. Leave
## set_flag_key empty to set nothing.
@export var set_flag_key: String = ""
@export var set_flag_value: bool = true

## Id of the line DialogueManager.advance() jumps to. Only used when
## `choices` is empty — with choices present, choose() drives navigation
## instead. Empty ends the dialogue.
@export var next_id: String = ""
@export var choices: Array[DialogueChoice] = []
