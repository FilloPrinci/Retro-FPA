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

## Always drives CollisionShape3D's size. Also drives the placeholder box
## mesh's size — but only while `mesh` below is empty; once a real mesh is
## assigned this only resizes the collider, since a real mesh manages its
## own dimensions.
@export var body_size: Vector3 = Vector3(0.6, 1.7, 0.6):
	set(value):
		body_size = value
		_apply_size()

## Optional: swap the placeholder box for a real mesh (e.g. an imported
## character model) straight from the Inspector — no need to select the
## child MeshInstance3D separately. Leave empty to keep the box.
@export var mesh: Mesh:
	set(value):
		mesh = value
		_apply_mesh()

## Optional: material for the mesh — the placeholder box or a custom one
## assigned above. Applied as a surface override (surface 0), same as
## every hand-authored mesh in this project's scenes.
@export var material: Material:
	set(value):
		material = value
		_apply_material()


func _ready() -> void:
	if not has_node("MeshInstance3D"):
		_build()


func _build() -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "MeshInstance3D"
	add_child(mesh_instance)
	mesh_instance.owner = owner if owner else self

	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	collision.shape = BoxShape3D.new()
	add_child(collision)
	collision.owner = owner if owner else self

	# Mesh/collision sit at local origin (no offset) — lifting the body
	# itself half the box height off the ground is what makes it rest on
	# the floor instead of being buried waist-deep in it.
	position.y = body_size.y * 0.5

	_apply_mesh()
	_apply_size()
	_apply_material()


func _apply_mesh() -> void:
	if not has_node("MeshInstance3D"):
		return
	var mesh_instance := get_node("MeshInstance3D") as MeshInstance3D
	if mesh:
		mesh_instance.mesh = mesh
	else:
		var box := BoxMesh.new()
		box.size = body_size
		mesh_instance.mesh = box


func _apply_size() -> void:
	if not has_node("CollisionShape3D"):
		return
	var collision := get_node("CollisionShape3D") as CollisionShape3D
	if collision.shape is BoxShape3D:
		(collision.shape as BoxShape3D).size = body_size

	if mesh == null and has_node("MeshInstance3D"):
		var mesh_instance := get_node("MeshInstance3D") as MeshInstance3D
		if mesh_instance.mesh is BoxMesh:
			(mesh_instance.mesh as BoxMesh).size = body_size


func _apply_material() -> void:
	if not has_node("MeshInstance3D"):
		return
	var mesh_instance := get_node("MeshInstance3D") as MeshInstance3D
	mesh_instance.set_surface_override_material(0, material)
