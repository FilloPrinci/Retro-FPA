class_name SpawnPoint
extends Node3D
## Marks a position/orientation in a level scene where the player can be
## placed. Looked up by id from SceneManager.change_scene()'s spawn_id
## parameter — a level can have several, e.g. one per door it can be
## entered from.

@export var spawn_id: String = "default"
