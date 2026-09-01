extends Control
## Esc-triggered pause screen. Only reacts to the "pause" input while
## GameManager.state is PLAYING (to open) or PAUSED (to close), so it never
## fights dialogue or the main menu for the same key. Relies on UILayer
## having process_mode = PROCESS_MODE_ALWAYS so it (and its buttons) still
## work while the tree is paused.

@onready var panel: Control = $Panel
@onready var resume_button: Button = $Panel/VBox/ResumeButton
@onready var settings_button: Button = $Panel/VBox/SettingsButton
@onready var main_menu_button: Button = $Panel/VBox/MainMenuButton
@onready var quit_button: Button = $Panel/VBox/QuitButton
@onready var settings_menu: Control = $SettingsMenu


func _ready() -> void:
	visible = false

	resume_button.pressed.connect(_on_resume_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	settings_menu.closed.connect(_on_settings_closed)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	if GameManager.state == GameManager.GameState.PLAYING:
		_open()
	elif GameManager.state == GameManager.GameState.PAUSED:
		_close()


func _open() -> void:
	get_tree().paused = true
	GameManager.state = GameManager.GameState.PAUSED
	panel.visible = true
	settings_menu.visible = false
	visible = true


func _close() -> void:
	get_tree().paused = false
	GameManager.state = GameManager.GameState.PLAYING
	visible = false


func _on_resume_pressed() -> void:
	_close()


func _on_settings_pressed() -> void:
	panel.visible = false
	settings_menu.visible = true


func _on_settings_closed() -> void:
	settings_menu.visible = false
	panel.visible = true


func _on_main_menu_pressed() -> void:
	visible = false
	SceneManager.return_to_main_menu()


func _on_quit_pressed() -> void:
	get_tree().quit()
