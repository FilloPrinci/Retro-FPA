@tool
extends VBoxContainer
## Bottom-panel dock ("Objects") — two buttons, no terminal needed:
## "New object..." asks the plugin to open the wizard (targeting
## whatever WorldItem is selected, if any), "Validate objects" runs
## ItemValidator and prints the results right here.
##
## The world presence (physical prop or pickup body) doesn't need a
## wizard — that's a WorldItem node (core/world_item/world_item.gd),
## added the same way as any other node.

signal new_item_requested

@onready var new_item_button: Button = $Toolbar/NewItemButton
@onready var validate_button: Button = $Toolbar/ValidateButton
@onready var results_label: RichTextLabel = $ResultsLabel


func _ready() -> void:
	results_label.bbcode_enabled = true
	results_label.text = "Press \"Validate objects\" to check resources/items/."
	new_item_button.pressed.connect(func(): new_item_requested.emit())
	validate_button.pressed.connect(_on_validate_pressed)


func _on_validate_pressed() -> void:
	var issues := ItemValidator.validate_all()
	if issues.is_empty():
		results_label.text = "[color=lightgreen]✓ All objects are valid.[/color]"
		return

	var text := ""
	for issue in issues:
		var color := "salmon" if issue.severity == "error" else "khaki"
		var label := "Error" if issue.severity == "error" else "Warning"
		text += "[color=%s]● %s[/color] — [b]%s[/b]: %s\n" % [color, label, issue.file, issue.message]
	results_label.text = text
