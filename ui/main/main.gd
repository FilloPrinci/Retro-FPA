extends Node
## Persistent run-scene root (the project's fixed Main Scene).
##
## Owns CurrentLevel (where level scenes are swapped in and out by
## SceneManager), UILayer (menus/HUD, always present) and WorldEnvironment
## (the project-wide fog/color-grading look driven by SettingsManager's
## visual_style — see docs/visual_style.md). This node itself is never
## reinstantiated during play.

func _ready() -> void:
	SceneManager.register_main(self)
	SettingsManager.register_world_environment($WorldEnvironment)
