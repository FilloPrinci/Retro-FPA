extends Control
## Dialogue box shown while GameManager.state == DIALOGUE. Purely reactive to
## DialogueManager's signals — same pattern as HUD/PauseMenu, never touches
## the dialogue graph itself.

@onready var speaker_label: Label = $Panel/VBox/SpeakerLabel
@onready var text_label: Label = $Panel/VBox/TextLabel
@onready var choices_box: VBoxContainer = $Panel/VBox/Choices
@onready var continue_prompt: Button = $Panel/VBox/ContinuePrompt

var _has_choices: bool = false


func _ready() -> void:
	visible = GameManager.state == GameManager.GameState.DIALOGUE
	GameManager.state_changed.connect(_on_state_changed)
	DialogueManager.line_changed.connect(_on_line_changed)
	DialogueManager.choices_presented.connect(_on_choices_presented)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)
	continue_prompt.pressed.connect(DialogueManager.advance)


func _unhandled_input(event: InputEvent) -> void:
	if GameManager.state != GameManager.GameState.DIALOGUE or _has_choices:
		return
	if event.is_action_pressed("interact"):
		DialogueManager.advance()


func _on_state_changed(new_state: GameManager.GameState) -> void:
	visible = new_state == GameManager.GameState.DIALOGUE


func _on_line_changed(speaker_name_key: String, text_key: String) -> void:
	speaker_label.text = tr(speaker_name_key)
	speaker_label.visible = not speaker_name_key.is_empty()
	text_label.text = tr(text_key)
	_set_choices([])


func _on_choices_presented(choices: Array[DialogueChoice]) -> void:
	_set_choices(choices)


func _on_dialogue_ended() -> void:
	_set_choices([])
	speaker_label.text = ""
	text_label.text = ""


func _set_choices(choices: Array[DialogueChoice]) -> void:
	for child in choices_box.get_children():
		child.queue_free()

	_has_choices = not choices.is_empty()
	choices_box.visible = _has_choices
	continue_prompt.visible = not _has_choices

	for i in choices.size():
		var button := Button.new()
		button.text = tr(choices[i].text_key)
		button.pressed.connect(DialogueManager.choose.bind(i))
		choices_box.add_child(button)
