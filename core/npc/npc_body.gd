@tool
class_name NpcBody
extends StaticBody3D
## Drop this into a scene like any other node (Create New Node > NpcBody,
## same "+" dialog as everything else) to get a ready-to-use placeholder
## NPC body — no dock/wizard step needed. The moment it has no
## CollisionShape3D yet, it builds itself: a boxed placeholder mesh +
## matching collision shape, positioned to rest on the floor. @tool so
## this also happens live in the editor, not just at Play.
##
## The initial build only ever runs once per node — after it, the
## children are saved with the scene like anything else, so reloading it
## (or duplicating the node) never re-triggers or resets a manual
## reposition. Purely a shortcut for the boilerplate; nothing here is
## required at runtime, and there's no equip_behavior/DialogueTrigger-like
## logic attached — add InteractableComponent/DialogueTrigger the usual
## way (or via the "Dialoghi" dock's "Nuovo dialogo NPC..." wizard) for a
## talking NPC.
##
## Editor note: the built CollisionShape3D/MeshInstance3D are real and
## correctly owned immediately — the box shows right away in the 3D
## viewport — but Godot's Scene dock tree list doesn't live-track children
## a script adds during _ready() the way it does nodes added through its
## own UI. It won't list them until the scene is reloaded (Scene > Reload
## Saved Scene, no need to reopen the whole project). Known Godot
## limitation of this pattern, same on WorldItem/SceneChangeTrigger — not
## a bug, and rarely matters since every knob that counts is an export
## here, not something you'd need to select the built children for.

## Always drives CollisionShape3D's size. Also drives the placeholder box
## mesh's size while `model` below is empty.
@export var body_size: Vector3 = Vector3(0.6, 1.7, 0.6):
	set(value):
		body_size = value
		_apply_size()

## Optional: an imported model — e.g. a Blender .glb, imported as a Scene
## (Godot's default) — to show instead of the placeholder box. Assign the
## imported *scene* here, not a raw Mesh: a glTF/Blender import comes in
## as a whole PackedScene (node, materials, possibly a skeleton), never a
## bare Mesh resource, which is why a Mesh-typed field refuses it. Leave
## empty to keep the box.
@export var model: PackedScene:
	set(value):
		model = value
		_rebuild_visual()

## Optional: material for the placeholder box. Has no effect once `model`
## is assigned — an imported model brings its own materials/textures.
@export var material: Material:
	set(value):
		material = value
		_apply_material()

const _MESH_NAME := "MeshInstance3D"
const _MODEL_NAME := "Model"


func _ready() -> void:
	if not has_node("CollisionShape3D"):
		_build()


func _build() -> void:
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	collision.shape = BoxShape3D.new()
	add_child(collision)
	collision.owner = owner if owner else self

	# Sits at local origin (no offset) — lifting the body itself half the
	# box height off the ground is what makes it rest on the floor instead
	# of being buried waist-deep in it.
	position.y = body_size.y * 0.5

	_apply_size()
	_rebuild_visual()


## Tears down whichever visual currently exists (placeholder box or an
## instanced model) and builds the one that should be showing now.
func _rebuild_visual() -> void:
	if not has_node("CollisionShape3D"):
		return  # not built yet — _build() will call this itself.

	for child_name in [_MESH_NAME, _MODEL_NAME]:
		if has_node(child_name):
			var existing := get_node(child_name)
			remove_child(existing)
			existing.free()

	if model:
		var instance := model.instantiate()
		instance.name = _MODEL_NAME
		add_child(instance)
		instance.owner = owner if owner else self
	else:
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = _MESH_NAME
		var box := BoxMesh.new()
		box.size = body_size
		mesh_instance.mesh = box
		mesh_instance.set_surface_override_material(0, material)
		add_child(mesh_instance)
		mesh_instance.owner = owner if owner else self


func _apply_size() -> void:
	if not has_node("CollisionShape3D"):
		return
	var collision := get_node("CollisionShape3D") as CollisionShape3D
	if collision.shape is BoxShape3D:
		(collision.shape as BoxShape3D).size = body_size

	if model == null and has_node(_MESH_NAME):
		var mesh_instance := get_node(_MESH_NAME) as MeshInstance3D
		if mesh_instance.mesh is BoxMesh:
			(mesh_instance.mesh as BoxMesh).size = body_size


func _apply_material() -> void:
	if model != null or not has_node(_MESH_NAME):
		return
	(get_node(_MESH_NAME) as MeshInstance3D).set_surface_override_material(0, material)
