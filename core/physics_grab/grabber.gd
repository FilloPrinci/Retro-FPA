extends Node3D
## Physics "grab" system (Half-Life / Amnesia style): point at a Grabbable
## RigidBody3D, hold it in front of the camera, optionally rotate it with
## the mouse, then throw it or just drop it. General-purpose — works on any
## RigidBody3D that has a Grabbable child, nothing scene-specific here.
##
## Grabbing while an item is equipped unequips it first (kept in the
## inventory, just no longer held) so both hands are free for the physical
## object; the previous equip is restored automatically once the object is
## thrown, dropped, or otherwise released. EquippedItemInput checks
## has_grab_target()/is_holding() before firing on "primary_action", so a
## grab always takes priority over an attack when something grabbable is
## under the crosshair.

@export var grab_range: float = 3.0
@export var hold_stiffness: float = 20.0
@export var max_hold_speed: float = 12.0
@export var rotate_sensitivity: float = 0.01

@onready var _camera: Camera3D = get_owner().get_node("Head/Camera3D") as Camera3D

var _held_body: RigidBody3D = null
var _held_grabbable: Grabbable = null
var _held_original_gravity_scale: float = 1.0
var _held_original_angular_damp: float = 0.0
var _is_rotating: bool = false
var _saved_equip_index: int = -1


func _ready() -> void:
	# Equipping something else (hotbar, inventory screen) while holding an
	# object drops it — holding a physical prop and having a weapon out at
	# the same time isn't a state this system supports. The newly-equipped
	# item should stick, not be immediately clobbered by the old one
	# restoring itself, so forget the saved slot first.
	InventoryManager.item_equipped.connect(_on_item_equipped)


func _unhandled_input(event: InputEvent) -> void:
	if not GameManager.control_enabled:
		return
	if _held_body and _is_rotating and event is InputEventMouseMotion:
		_rotate_held_body(event.relative)


func _physics_process(_delta: float) -> void:
	if not GameManager.control_enabled:
		if _held_body:
			_release()
		return

	_is_rotating = _held_body != null and Input.is_action_pressed("secondary_action")

	if Input.is_action_just_pressed("primary_action"):
		if _held_body:
			_throw()
		else:
			_try_grab()
	elif Input.is_action_just_pressed("interact") and _held_body:
		_release()

	if _held_body:
		_update_hold_position()


func is_holding() -> bool:
	return _held_body != null


## Whether a fresh grab attempt would find something right now — used by
## EquippedItemInput to decide whether "primary_action" should grab
## instead of attacking. Read-only: doesn't touch equip state.
func has_grab_target() -> bool:
	return not is_holding() and _find_grab_target() != null


func _find_grab_target() -> RigidBody3D:
	var space_state := get_world_3d().direct_space_state
	var from := _camera.global_position
	var to := from - _camera.global_transform.basis.z * grab_range
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_bodies = true
	var result := space_state.intersect_ray(query)
	if result.is_empty():
		return null
	var body := result.get("collider") as RigidBody3D
	if body == null or _find_grabbable(body) == null:
		return null
	return body


func _try_grab() -> void:
	var body := _find_grab_target()
	if body == null:
		return

	_saved_equip_index = InventoryManager.get_equipped_index()
	if _saved_equip_index != -1:
		InventoryManager.unequip()

	_held_body = body
	_held_grabbable = _find_grabbable(body)
	_held_original_gravity_scale = body.gravity_scale
	_held_original_angular_damp = body.angular_damp
	body.gravity_scale = 0.0
	body.angular_damp = 8.0


func _on_item_equipped(_item: ItemData) -> void:
	if _held_body:
		_saved_equip_index = -1
		_release()


func _update_hold_position() -> void:
	var target := _camera.global_position - _camera.global_transform.basis.z * _held_grabbable.hold_distance
	var to_target := target - _held_body.global_position
	var hold_velocity := to_target * hold_stiffness
	if hold_velocity.length() > max_hold_speed:
		hold_velocity = hold_velocity.normalized() * max_hold_speed
	_held_body.linear_velocity = hold_velocity


func _rotate_held_body(mouse_delta: Vector2) -> void:
	_held_body.angular_velocity = Vector3(
		mouse_delta.y * rotate_sensitivity,
		mouse_delta.x * rotate_sensitivity,
		0.0
	) * 20.0


func _throw() -> void:
	var body := _held_body
	var throw_force := _held_grabbable.throw_force
	var direction := -_camera.global_transform.basis.z
	_release()
	body.apply_central_impulse(direction * throw_force)


## Drops whatever's held (no impulse) and re-equips whatever was equipped
## before the grab started, if anything.
func _release() -> void:
	if _held_body:
		_held_body.gravity_scale = _held_original_gravity_scale
		_held_body.angular_damp = _held_original_angular_damp
		_held_body.angular_velocity = Vector3.ZERO
	_held_body = null
	_held_grabbable = null
	_is_rotating = false

	if _saved_equip_index != -1:
		InventoryManager.equip_slot(_saved_equip_index)
	_saved_equip_index = -1


func _find_grabbable(body: RigidBody3D) -> Grabbable:
	for child in body.get_children():
		if child is Grabbable:
			return child
	return null
