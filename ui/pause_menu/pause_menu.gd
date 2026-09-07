extends Control
## Esc-triggered pause screen. Only reacts to the "pause" input while
## GameManager.state is PLAYING (to open) or PAUSED (to close), so it never
## fights dialogue or the main menu for the same key. Relies on UILayer
## having process_mode = PROCESS_MODE_ALWAYS so it (and its buttons) still
## work while the tree is paused.

@onready var panel: Control = $Panel
@onready var resume_button: Button = $Panel/VBox/ResumeButton
@onready var save_button: Button = $Panel/VBox/SaveButton
@onready var load_button: Button = $Panel/VBox/LoadButton
@onready var settings_button: Button = $Panel/VBox/SettingsButton
@onready var main_menu_button: Button = $Panel/VBox/MainMenuButton
@onready var quit_button: Button = $Panel/VBox/QuitButton
@onready var status_label: Label = $Panel/VBox/StatusLabel
@onready var status_timer: Timer = $StatusTimer
@onready var settings_menu: Control = $SettingsMenu


func _ready() -> void:
	visible = false
	status_label.visible = false

	resume_button.pressed.connect(_on_resume_pressed)
	save_button.pressed.connect(_on_save_pressed)
	load_button.pressed.connect(_on_load_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	settings_menu.closed.connect(_on_settings_closed)
	status_timer.timeout.connect(_on_status_timeout)


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
	status_label.visible = false
	load_button.disabled = not SaveManager.has_save(0)
	visible = true


func _close() -> void:
	get_tree().paused = false
	GameManager.state = GameManager.GameState.PLAYING
	visible = false


func _on_resume_pressed() -> void:
	_close()


func _on_save_pressed() -> void:
	var ok := SaveManager.save_game(0)
	_show_status("UI_GAME_SAVED" if ok else "UI_GAME_SAVE_FAILED")
	load_button.disabled = not SaveManager.has_save(0)


## Closes the whole pause overlay and unpauses first, same as
## _on_main_menu_pressed() below — SaveManager.load_game() swaps the
## level (fade transition included) through the same SceneManager path
## as any other scene change, which a still-paused tree would block.
func _on_load_pressed() -> void:
	visible = false
	get_tree().paused = false
	await SaveManager.load_game(0)


func _show_status(text_key: String) -> void:
	status_label.text = text_key
	status_label.visible = true
	status_timer.start()


func _on_status_timeout() -> void:
	status_label.visible = false


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
