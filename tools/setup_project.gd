extends SceneTree
## One-off bootstrap script for the Retro FPA template — a thin CLI
## wrapper around ProjectSetup.apply() (tools/project_setup.gd), which also
## backs the "Retro Style" plugin's "Apply Retro Style Settings..."
## menu item (Project > Tools), so both paths share one canonical
## implementation instead of two copies that can drift apart.
##
## Usage (run once from the project root, or again any time these lists
## change and you don't want to use the in-editor menu item):
##   godot --headless -s res://tools/setup_project.gd

func _initialize() -> void:
	ProjectSetup.apply()
	ProjectSettings.save()
	print("[setup_project] Project settings written.")
	quit()
