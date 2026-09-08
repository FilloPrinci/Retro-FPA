extends SceneTree
## Headless smoke test for the persistent shell's boot path. Dev tool, not
## gameplay code — run it after touching the autoloads or the Main/Player
## scenes.
## Run: godot --headless -s res://tools/smoke_test.gd
##
## A bare template has no first level yet (MainMenu.first_level_path is
## empty until a new game sets it — see docs/getting_started.md step 0),
## so this only checks that Main boots cleanly and settles into
## GameManager.state == MAIN_MENU with no player spawned yet. Once your
## game has a real first level, prefer just playing it — this stays a
## quick "did I break the boot path" check, not a substitute.
##
## Autoload singletons are fetched via get_node() instead of their global
## identifiers: this script runs as the custom MainLoop itself, compiled
## before the engine injects autoload globals into the script language's
## identifier table (unlike ordinary scene scripts, which compile later).

func _initialize() -> void:
	var game_manager := root.get_node("GameManager")

	var main_scene: PackedScene = load("res://ui/main/main.tscn")
	var main := main_scene.instantiate()
	root.add_child(main)

	for i in 5:
		await process_frame

	var player = game_manager.get_player()
	print("[smoke_test] state: ", game_manager.state)
	print("[smoke_test] player (should be null — nothing spawns one before a game starts): ", player)

	if player == null and game_manager.state == 0:  # GameState.MAIN_MENU
		print("[smoke_test] PASS")
	else:
		print("[smoke_test] FAIL")

	quit()
