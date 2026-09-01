class_name DialogueChoice
extends Resource
## One selectable option on a DialogueLine. Content design should never
## require touching DialogueManager's code.

@export var text_key: String = ""
## Id of the DialogueLine this choice jumps to. Empty ends the dialogue.
@export var next_id: String = ""

## Optional gating: this choice is only offered when
## GameManager.get_flag(required_flag_key) == required_flag_value. Leave
## required_flag_key empty for a choice that is always available.
@export var required_flag_key: String = ""
@export var required_flag_value: bool = true

## Optional: set on GameManager the moment this choice is picked. Leave
## set_flag_key empty to set nothing.
@export var set_flag_key: String = ""
@export var set_flag_value: bool = true
