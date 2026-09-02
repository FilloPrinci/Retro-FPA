class_name NpcScaffolder
extends RefCounted
## Creates a placeholder NPC body in one step: StaticBody3D +
## MeshInstance3D (BoxMesh) + CollisionShape3D (BoxShape3D), boxed to
## roughly a standing person's footprint — a blockout to texture/model
## over later, not a final asset. Parented under whichever node is
## selected in the scene (or the edited scene's root if nothing is
## selected). Used by the "Nuovo NPC" dock button — see
## dialogue_dock.gd/plugin.gd. Doesn't add InteractableComponent/
## DialogueTrigger itself; run "Nuovo dialogo NPC..." on the result for
## that, same as any other NPC.

const BODY_SIZE := Vector3(0.6, 1.7, 0.6)


## Returns {"ok": bool, "message": String, "node": Node}.
static func create(parent_node: Node, base_name: String = "NPC") -> Dictionary:
	if parent_node == null:
		return {"ok": false, "message": "Nessuna scena aperta o nodo selezionato.", "node": null}

	var body := StaticBody3D.new()
	body.name = _unique_name(parent_node, base_name)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "MeshInstance3D"
	var mesh := BoxMesh.new()
	mesh.size = BODY_SIZE
	mesh_instance.mesh = mesh

	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = BODY_SIZE
	collision.shape = shape

	_add_child(parent_node, body)
	_add_child(body, mesh_instance)
	_add_child(body, collision)

	# Mesh/collision sit at the body's local origin (no offset, matching
	# every other NPC/prop in this project) — so lifting the body itself
	# half the box height off the ground is what makes it rest on the
	# floor instead of being buried waist-deep in it.
	body.position = Vector3(0, BODY_SIZE.y * 0.5, 0)

	return {"ok": true, "message": "NPC '%s' creato." % body.name, "node": body}


static func _unique_name(parent: Node, base_name: String) -> String:
	if not parent.has_node(base_name):
		return base_name
	var i := 2
	while parent.has_node("%s%d" % [base_name, i]):
		i += 1
	return "%s%d" % [base_name, i]


static func _add_child(parent: Node, child: Node) -> void:
	parent.add_child(child)
	# The scene root has owner == null (Godot convention); every other
	# node's owner is that root. Falls back to `parent` itself when parent
	# IS the root — same technique as DialogueScaffolder._add_child.
	child.owner = parent.owner if parent.owner else parent
