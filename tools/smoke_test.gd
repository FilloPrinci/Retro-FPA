extends SceneTree
## Headless smoke test for the persistent shell + new-game flow. Dev tool,
## not gameplay code — run it after touching the autoloads or the Main/
## Player scenes.
## Run: godot --headless -s res://tools/smoke_test.gd
##
## Autoload singletons are fetched via get_node() instead of their global
## identifiers: this script runs as the custom MainLoop itself, compiled
## before the engine injects autoload globals into the script language's
## identifier table (unlike ordinary scene scripts, which compile later).

func _initialize() -> void:
	var scene_manager := root.get_node("SceneManager")
	var game_manager := root.get_node("GameManager")
	var inventory_manager := root.get_node("InventoryManager")

	var main_scene: PackedScene = load("res://ui/main/main.tscn")
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	print("[smoke_test] triggering start_new_game...")
	await scene_manager.start_new_game("res://levels/demo/demo_level_1.tscn")

	for i in 5:
		await process_frame

	var player = game_manager.get_player()
	print("[smoke_test] player: ", player)
	print("[smoke_test] state: ", game_manager.state)
	print("[smoke_test] level children: ", main.get_node("CurrentLevel").get_children())
	print("[smoke_test] inventory slots: ", inventory_manager.get_slots().size())

	if player and game_manager.state == 1:  # GameState.PLAYING
		print("[smoke_test] PASS")
	else:
		print("[smoke_test] FAIL")

	quit()
