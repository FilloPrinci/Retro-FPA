@tool
extends VBoxContainer
## Bottom-panel dock ("Dialogues") — two buttons, no terminal needed:
## "New NPC dialogue..." asks the plugin to open the wizard for whatever
## node is selected in the scene, "Validate dialogues" runs DialogueValidator
## and prints the results right here.
##
## The NPC body itself doesn't need a wizard — that's an NpcBody node
## (core/npc/npc_body.gd), added the same way as any other node.

signal new_dialogue_requested

@onready var new_dialogue_button: Button = $Toolbar/NewDialogueButton
@onready var validate_button: Button = $Toolbar/ValidateButton
@onready var results_label: RichTextLabel = $ResultsLabel


func _ready() -> void:
	results_label.bbcode_enabled = true
	results_label.text = "Press \"Validate dialogues\" to check resources/dialogues/."
	new_dialogue_button.pressed.connect(func(): new_dialogue_requested.emit())
	validate_button.pressed.connect(_on_validate_pressed)


func _on_validate_pressed() -> void:
	var issues := DialogueValidator.validate_all()
	if issues.is_empty():
		results_label.text = "[color=lightgreen]✓ All dialogues are valid.[/color]"
		return

	var text := ""
	for issue in issues:
		var color := "salmon" if issue.severity == "error" else "khaki"
		var label := "Error" if issue.severity == "error" else "Warning"
		text += "[color=%s]● %s[/color] — [b]%s[/b]: %s\n" % [color, label, issue.file, issue.message]
	results_label.text = text
