class_name SceneChangeTrigger
extends Area3D
## Drop into a level as a doorway/exit trigger. When the player enters it,
## asks SceneManager to load the target scene at the matching SpawnPoint.

@export_file("*.tscn") var target_scene: String
@export var target_spawn_id: String = "default"


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player") or target_scene.is_empty():
		return
	SceneManager.change_scene(target_scene, target_spawn_id)
