extends Node
## Dev-only launcher to try the showcase demo without touching
## MainMenu.first_level_path (which points at whatever level you're
## actually working on). Open this scene and press F6 ("Run Current
## Scene") instead of the project's global Play button — F6 always runs
## whichever scene is open in the editor, regardless of project.godot's
## main scene or the main menu's own first_level_path.
##
## Builds the persistent shell (ui/main/main.tscn) itself, exactly like a
## real boot would, then starts a new game straight into the showcase —
## skipping the main menu entirely. Safe to delete once you're done
## trying the demo; nothing else depends on this file.

const MAIN_SCENE := "res://ui/main/main.tscn"
const SHOWCASE_LEVEL := "res://levels/showcase/showcase_hall.tscn"


func _ready() -> void:
	var main: Node = (load(MAIN_SCENE) as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	await SceneManager.start_new_game(SHOWCASE_LEVEL)
