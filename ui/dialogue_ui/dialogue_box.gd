extends Control
## Dialogue box shown while GameManager.state == DIALOGUE. Purely reactive to
## DialogueManager's signals — same pattern as HUD/PauseMenu, never touches
## the dialogue graph itself.
##
## Choices can be picked with the mouse (click a button) or the keyboard:
## move_forward/move_back (already bound to the arrow keys alongside W/S,
## see project.godot) move the highlighted choice, "interact" confirms
## it — the same keys already used to move around and interact with the
## world, nothing dialogue-specific to learn.

@onready var speaker_label: Label = $Panel/VBox/SpeakerLabel
@onready var text_scroll: ScrollContainer = $Panel/VBox/TextScroll
@onready var text_label: Label = $Panel/VBox/TextScroll/TextLabel
@onready var choices_box: VBoxContainer = $Panel/VBox/Choices
@onready var continue_prompt: Button = $Panel/VBox/ContinuePrompt

var _has_choices: bool = false
var _selected_choice: int = 0


func _ready() -> void:
	visible = GameManager.state == GameManager.GameState.DIALOGUE
	GameManager.state_changed.connect(_on_state_changed)
	DialogueManager.line_changed.connect(_on_line_changed)
	DialogueManager.choices_presented.connect(_on_choices_presented)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)
	continue_prompt.pressed.connect(DialogueManager.advance)


func _unhandled_input(event: InputEvent) -> void:
	if GameManager.state != GameManager.GameState.DIALOGUE:
		return

	if _has_choices:
		if event.is_action_pressed("move_back"):
			_move_selection(1)
		elif event.is_action_pressed("move_forward"):
			_move_selection(-1)
		elif event.is_action_pressed("interact"):
			DialogueManager.choose(_selected_choice)
		return

	if event.is_action_pressed("interact"):
		DialogueManager.advance()


func _on_state_changed(new_state: GameManager.GameState) -> void:
	visible = new_state == GameManager.GameState.DIALOGUE


func _on_line_changed(speaker_name_key: String, text_key: String) -> void:
	speaker_label.text = tr(speaker_name_key)
	speaker_label.visible = not speaker_name_key.is_empty()
	text_label.text = tr(text_key)
	# A long line that doesn't fit shows a scrollbar (see TextScroll in the
	# scene) rather than silently overflowing the panel — always start a
	# new line scrolled to the top, not wherever the previous one left it.
	text_scroll.scroll_vertical = 0
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
	_selected_choice = 0

	for i in choices.size():
		var button := Button.new()
		button.text = tr(choices[i].text_key)
		# Built fresh every time a line with choices is shown, so it never
		# got SettingsManager's usual tree-wide font/text-scale pass — apply
		# the current ones directly instead of waiting for the next
		# settings change to catch it.
		button.add_theme_font_override("font", SettingsManager.UI_FONT)
		button.add_theme_font_size_override("font_size", SettingsManager.get_font_size())
		button.pressed.connect(DialogueManager.choose.bind(i))
		# Keeps mouse and keyboard selection in sync — hovering a choice
		# with the mouse also moves the keyboard-driven highlight to it.
		button.mouse_entered.connect(_select_choice.bind(i))
		choices_box.add_child(button)

	if _has_choices:
		_highlight_selected()


## delta: +1 moves to the next choice, -1 to the previous — wraps around
## at either end (there are usually only 2-3 choices, so wrapping is more
## convenient than getting stuck at an edge).
func _move_selection(delta: int) -> void:
	if choices_box.get_child_count() == 0:
		return
	_select_choice(wrapi(_selected_choice + delta, 0, choices_box.get_child_count()))


func _select_choice(index: int) -> void:
	_selected_choice = index
	_highlight_selected()


func _highlight_selected() -> void:
	var button := choices_box.get_child(_selected_choice) as Button
	if button:
		button.grab_focus()
