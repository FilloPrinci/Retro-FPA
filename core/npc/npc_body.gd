@tool
class_name NpcBody
extends StaticBody3D
## Drop this into a scene like any other node (Create New Node > NpcBody,
## same "+" dialog as everything else) to get a ready-to-use placeholder
## NPC body — no dock/wizard step needed. The moment it has no
## MeshInstance3D/CollisionShape3D children yet, it builds them itself: a
## boxed mesh + matching collision shape sized like a standing person,
## positioned to rest on the floor. @tool so this also happens live in
## the editor, not just at Play.
##
## This only ever runs once per node — after the first build, the
## children are saved with the scene like anything else, so reloading it
## (or duplicating the node) never re-triggers or resets a manual
## reposition. Purely a shortcut for the boilerplate; nothing here is
## required at runtime, and there's no equip_behavior/DialogueTrigger-like
## logic attached — add InteractableComponent/DialogueTrigger the usual
## way (or via the "Dialoghi" dock's "Nuovo dialogo NPC..." wizard) for a
## talking NPC.

@export var body_size: Vector3 = Vector3(0.6, 1.7, 0.6):
	set(value):
		body_size = value
		_resize()


func _ready() -> void:
	if not has_node("MeshInstance3D"):
		_build()


func _build() -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "MeshInstance3D"
	var mesh := BoxMesh.new()
	mesh.size = body_size
	mesh_instance.mesh = mesh
	add_child(mesh_instance)
	mesh_instance.owner = owner if owner else self

	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = body_size
	collision.shape = shape
	add_child(collision)
	collision.owner = owner if owner else self

	# Mesh/collision sit at local origin (no offset) — lifting the body
	# itself half the box height off the ground is what makes it rest on
	# the floor instead of being buried waist-deep in it.
	position.y = body_size.y * 0.5


func _resize() -> void:
	if not has_node("MeshInstance3D"):
		return
	var mesh_instance := get_node("MeshInstance3D") as MeshInstance3D
	var collision := get_node("CollisionShape3D") as CollisionShape3D
	if mesh_instance and mesh_instance.mesh is BoxMesh:
		(mesh_instance.mesh as BoxMesh).size = body_size
	if collision and collision.shape is BoxShape3D:
		(collision.shape as BoxShape3D).size = body_size
