class_name DialogueData
extends Resource
## Data-driven definition of a branching dialogue tree. Create one .tres per
## conversation under resources/dialogues/ and hand it to
## DialogueManager.start_dialogue(). Never referenced by id from code —
## DialogueTrigger just holds one and plays it back.

@export var lines: Array[DialogueLine] = []
## Id of the line start_dialogue() begins at when it isn't given one
## explicitly. Defaults to the first entry in `lines` when left empty.
@export var start_id: String = ""
