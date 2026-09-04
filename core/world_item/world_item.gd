@tool
class_name WorldItem
extends Node3D
## Drop this into a scene like any other node (Create New Node >
## WorldItem) to get a ready-to-use world object — no wizard step for the
## body itself, same idea as NpcBody. Toggle `kind` between:
## - PHYSICAL: a grabbable physics prop (RigidBody3D + Grabbable), like
##   the demo Crate — no inventory involved at all.
## - PICKUPABLE: a static body the player can interact with to add `item`
##   to their inventory (StaticBody3D + InteractableComponent +
##   ItemPickup), then remove itself from the world.
## Either way it builds a boxed placeholder mesh + matching collision
## shape; swap in a real model via `model` and a material via `material`,
## same fields as NpcBody. Changing `kind` later fully rebuilds the body
## (a RigidBody3D can't turn into a StaticBody3D in place — they're
## different node classes) but keeps every other setting, since they're
## all re-applied from this node's own exports, never lost.
##
## The ItemData itself (name/description/icon/item_type/weapon behavior)
## isn't authored here — assign an existing one to `item`, or use the
## "Objects" dock's "New object..." wizard to create one (it assigns
## itself here automatically if a WorldItem is selected when you run it)
## without hand-writing .tres/CSV content, same idea as the "Dialogues"
## dock's NPC dialogue wizard.
##
## Editor note: the built Body/CollisionShape3D are real and correctly
## owned immediately — the box shows right away in the 3D viewport — but
## Godot's Scene dock tree list doesn't live-track children a script adds
## during _ready() the way it does nodes added through its own UI. It
## won't list them until the scene is reloaded (Scene > Reload Saved
## Scene, no need to reopen the whole project). Known Godot limitation of
## this pattern, same on NpcBody/SceneChangeTrigger — not a bug, and
## rarely matters since every knob that counts is an export here, not
## something you'd need to select the built children for.

enum Kind { PHYSICAL, PICKUPABLE }

@export var kind: Kind = Kind.PICKUPABLE:
	set(value):
		kind = value
		if has_node(_BODY_NAME):
			_rebuild_body()

@export var body_size: Vector3 = Vector3(0.3, 0.3, 0.3):
	set(value):
		body_size = value
		_apply_size()

@export var model: PackedScene:
	set(value):
		model = value
		_rebuild_visual()

@export var material: Material:
	set(value):
		material = value
		_apply_material()

## Only used when kind == PICKUPABLE.
@export var item: ItemData:
	set(value):
		item = value
		_apply_item()

@export var quantity: int = 1:
	set(value):
		quantity = value
		_apply_item()

@export_group("Pickup Glow")
## Pulses the fresnel rim (see core/shading/fresnel_flash.gd) in
## pickup_glow_color to catch the player's eye — the visual cue that this
## object can be picked up. Doesn't affect whether every surface under
## Body gets switched to a RetroSurfaceMaterial below — that always
## happens for kind == PICKUPABLE, since only that shader has a fresnel
## rim to drive; this toggle only controls whether it's actually pulsing.
## No-op for kind == PHYSICAL — grabbable props aren't inventory pickups.
@export var pickup_glow_enabled: bool = true:
	set(value):
		pickup_glow_enabled = value
		_apply_pickup_glow()
@export var pickup_glow_color: Color = Color.WHITE:
	set(value):
		pickup_glow_color = value
		_apply_pickup_glow()

const _BODY_NAME := "Body"
const _MESH_NAME := "MeshInstance3D"
const _MODEL_NAME := "Model"
const _COLLISION_NAME := "CollisionShape3D"

const _GRABBABLE_SCRIPT := "res://core/physics_grab/grabbable.gd"
const _INTERACTABLE_SCRIPT := "res://core/interaction/interactable_component.gd"
const _ITEM_PICKUP_SCRIPT := "res://core/inventory/item_pickup.gd"


func _ready() -> void:
	if not has_node(_BODY_NAME):
		_rebuild_body()
	else:
		# Loaded from a saved scene — the body already exists, but the
		# pulsing tween in _apply_pickup_glow() only starts once there's an
		# actual running SceneTree, so it has to be (re-)applied here too,
		# same reasoning as SceneChangeTrigger's own _ready() else-branch.
		_apply_pickup_glow()


## Tears down and rebuilds the whole Body subtree for the current `kind` —
## the one operation that has to fully replace the body. Re-derives
## everything from this node's own exports afterward, so nothing set via
## model/material/item/quantity is lost across a kind change.
func _rebuild_body() -> void:
	if has_node(_BODY_NAME):
		var existing := get_node(_BODY_NAME)
		remove_child(existing)
		existing.free()

	var body: PhysicsBody3D = RigidBody3D.new() if kind == Kind.PHYSICAL else StaticBody3D.new()
	body.name = _BODY_NAME
	add_child(body)
	body.owner = owner if owner else self

	var collision := CollisionShape3D.new()
	collision.name = _COLLISION_NAME
	collision.shape = BoxShape3D.new()
	body.add_child(collision)
	collision.owner = owner if owner else self

	if kind == Kind.PHYSICAL:
		# Grabber finds this the same way Interactor finds an NPC's or a
		# pickup's InteractableComponent — the HUD prompt (and the "press
		# interact to grab" behavior itself) work the same way everywhere.
		var interactable := Node.new()
		interactable.name = "InteractableComponent"
		interactable.set_script(load(_INTERACTABLE_SCRIPT))
		interactable.set("prompt_text_key", "UI_INTERACT_GRAB")
		body.add_child(interactable)
		interactable.owner = owner if owner else self

		var grabbable := Node.new()
		grabbable.name = "Grabbable"
		grabbable.set_script(load(_GRABBABLE_SCRIPT))
		body.add_child(grabbable)
		grabbable.owner = owner if owner else self
	else:
		var interactable := Node.new()
		interactable.name = "InteractableComponent"
		interactable.set_script(load(_INTERACTABLE_SCRIPT))
		interactable.set("prompt_text_key", "UI_INTERACT_TAKE")
		body.add_child(interactable)
		interactable.owner = owner if owner else self

		var pickup := Node.new()
		pickup.name = "ItemPickup"
		pickup.set_script(load(_ITEM_PICKUP_SCRIPT))
		body.add_child(pickup)
		pickup.owner = owner if owner else self

	_apply_size()
	_rebuild_visual()
	_apply_item()


func _apply_size() -> void:
	if not has_node(_BODY_NAME):
		return
	var body := get_node(_BODY_NAME)

	if body.has_node(_COLLISION_NAME):
		var collision := body.get_node(_COLLISION_NAME) as CollisionShape3D
		if collision.shape is BoxShape3D:
			(collision.shape as BoxShape3D).size = body_size

	if model == null and body.has_node(_MESH_NAME):
		var mesh_instance := body.get_node(_MESH_NAME) as MeshInstance3D
		if mesh_instance.mesh is BoxMesh:
			(mesh_instance.mesh as BoxMesh).size = body_size


func _rebuild_visual() -> void:
	if not has_node(_BODY_NAME):
		return
	var body := get_node(_BODY_NAME)

	for child_name in [_MESH_NAME, _MODEL_NAME]:
		if body.has_node(child_name):
			var existing := body.get_node(child_name)
			body.remove_child(existing)
			existing.free()

	if model:
		var instance := model.instantiate()
		instance.name = _MODEL_NAME
		body.add_child(instance)
		instance.owner = owner if owner else self
	else:
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = _MESH_NAME
		var box := BoxMesh.new()
		box.size = body_size
		mesh_instance.mesh = box
		mesh_instance.set_surface_override_material(0, material)
		body.add_child(mesh_instance)
		mesh_instance.owner = owner if owner else self

	_apply_pickup_glow()


func _apply_material() -> void:
	if model != null or not has_node(_BODY_NAME):
		return
	var body := get_node(_BODY_NAME)
	if body.has_node(_MESH_NAME):
		(body.get_node(_MESH_NAME) as MeshInstance3D).set_surface_override_material(0, material)
	_apply_pickup_glow()


## Pickupable items pulse a fresnel rim (pickup_glow_color, default white)
## to signal they're something the player can pick up — see
## core/shading/fresnel_flash.gd. Every MeshInstance3D under Body (the
## placeholder box, or every part of a custom model) gets its surface
## materials switched to a RetroSurfaceMaterial first if they aren't one
## already — only that shader has a fresnel rim to drive — then gets its
## own FresnelFlash pulsing in sync, so a multi-part model still reads as
## one glowing object. No-op for kind == PHYSICAL: grabbable props aren't
## inventory pickups and get no glow.
func _apply_pickup_glow() -> void:
	if kind != Kind.PICKUPABLE or not has_node(_BODY_NAME):
		return
	var body := get_node(_BODY_NAME)
	for mesh_instance in _find_mesh_instances(body):
		_ensure_retro_material(mesh_instance)
		var flash := mesh_instance.get_node_or_null("FresnelFlash") as FresnelFlash
		if pickup_glow_enabled:
			if flash == null:
				flash = FresnelFlash.new()
				flash.name = "FresnelFlash"
				flash.mesh_instance = mesh_instance
				mesh_instance.add_child(flash)
				flash.owner = owner if owner else self
			# Only actually pulse once there's a real running SceneTree —
			# the editor's own preview shouldn't sit there tweening forever.
			if not Engine.is_editor_hint():
				flash.pulse(pickup_glow_color, 1.2, 0.6)
		elif flash:
			flash.stop_pulse()


func _find_mesh_instances(node: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		found.append(node)
	for child in node.get_children():
		found.append_array(_find_mesh_instances(child))
	return found


## Converts every surface on mesh_instance that isn't already a
## RetroSurfaceMaterial to one, so _apply_pickup_glow() above has a
## fresnel rim to drive. Carries over albedo/metallic/roughness/emission
## from a plain BaseMaterial3D source (an imported model's own material,
## or this node's `material` export) so switching shaders doesn't change
## how the object looks at rest — it only adds the rim.
func _ensure_retro_material(mesh_instance: MeshInstance3D) -> void:
	if mesh_instance.mesh == null:
		return
	for i in mesh_instance.mesh.get_surface_count():
		var mat := mesh_instance.get_active_material(i)
		if mat is RetroSurfaceMaterial:
			continue
		var retro := RetroSurfaceMaterial.new()
		if mat is BaseMaterial3D:
			var base_mat := mat as BaseMaterial3D
			retro.albedo_color_1 = base_mat.albedo_color
			retro.albedo_texture_1 = base_mat.albedo_texture
			retro.metallic_1 = base_mat.metallic
			retro.smoothness_1 = 1.0 - base_mat.roughness
			if base_mat.emission_enabled:
				retro.emission_color_1 = base_mat.emission
		mesh_instance.set_surface_override_material(i, retro)


func _apply_item() -> void:
	if kind != Kind.PICKUPABLE or not has_node(_BODY_NAME):
		return
	var body := get_node(_BODY_NAME)
	if body.has_node("ItemPickup"):
		var pickup := body.get_node("ItemPickup")
		pickup.set("item", item)
		pickup.set("quantity", quantity)
