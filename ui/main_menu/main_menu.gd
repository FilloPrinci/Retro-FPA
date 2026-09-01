extends Control
## First screen shown at boot (GameManager.state == MAIN_MENU). "New Game"
## starts a fresh run at first_level_path — the one export a derived game
## is expected to point at its own first level; nothing else on this scene
## should need to change between games.

@export_file("*.tscn") var first_level_path: String

@onready var panel: Control = $Panel
@onready var new_game_button: Button = $Panel/VBox/NewGameButton
@onready var settings_button: Button = $Panel/VBox/SettingsButton
@onready var quit_button: Button = $Panel/VBox/QuitButton
@onready var settings_menu: Control = $SettingsMenu


func _ready() -> void:
	visible = GameManager.state == GameManager.GameState.MAIN_MENU
	GameManager.state_changed.connect(_on_state_changed)

	new_game_button.pressed.connect(_on_new_game_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	settings_menu.closed.connect(_on_settings_closed)


func _on_state_changed(new_state: GameManager.GameState) -> void:
	visible = new_state == GameManager.GameState.MAIN_MENU


func _on_new_game_pressed() -> void:
	if first_level_path.is_empty():
		push_warning("MainMenu.first_level_path is not set.")
		return
	SceneManager.start_new_game(first_level_path)


func _on_settings_pressed() -> void:
	panel.visible = false
	settings_menu.visible = true


func _on_settings_closed() -> void:
	settings_menu.visible = false
	panel.visible = true


func _on_quit_pressed() -> void:
	get_tree().quit()
