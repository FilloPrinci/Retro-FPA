@tool
extends VBoxContainer
## Bottom-panel dock ("Dialoghi") — two buttons, no terminal needed:
## "Nuovo dialogo NPC..." asks the plugin to open the wizard for whatever
## node is selected in the scene, "Valida dialoghi" runs DialogueValidator
## and prints the results right here.

signal new_dialogue_requested

@onready var new_dialogue_button: Button = $Toolbar/NewDialogueButton
@onready var validate_button: Button = $Toolbar/ValidateButton
@onready var results_label: RichTextLabel = $ResultsLabel


func _ready() -> void:
	results_label.bbcode_enabled = true
	results_label.text = "Premi \"Valida dialoghi\" per controllare resources/dialogues/."
	new_dialogue_button.pressed.connect(func(): new_dialogue_requested.emit())
	validate_button.pressed.connect(_on_validate_pressed)


func _on_validate_pressed() -> void:
	var issues := DialogueValidator.validate_all()
	if issues.is_empty():
		results_label.text = "[color=lightgreen]✓ Tutti i dialoghi sono validi.[/color]"
		return

	var text := ""
	for issue in issues:
		var color := "salmon" if issue.severity == "error" else "khaki"
		var label := "Errore" if issue.severity == "error" else "Avviso"
		text += "[color=%s]● %s[/color] — [b]%s[/b]: %s\n" % [color, label, issue.file, issue.message]
	results_label.text = text
