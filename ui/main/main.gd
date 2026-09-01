extends Node
## Persistent run-scene root (the project's fixed Main Scene).
##
## Owns CurrentLevel (where level scenes are swapped in and out by
## SceneManager) and UILayer (menus/HUD, always present). This node itself
## is never reinstantiated during play.

func _ready() -> void:
	SceneManager.register_main(self)
