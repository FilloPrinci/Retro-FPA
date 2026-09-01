class_name Player
extends CharacterBody3D
## First-person controller: movement, mouse look, sprint, crouch, jump.
## Reads GameManager.control_enabled so dialogue/menus/pause can freeze it
## without every other system needing to know why. Physics grab (Grabber),
## interaction (Interactor) and footsteps (FootstepComponent) are separate
## sibling components under this node — this script only moves the body.

const GRAVITY := 9.8

@export_group("Movement")
@export var move_speed: float = 4.0
@export var sprint_multiplier: float = 1.6
@export var crouch_multiplier: float = 0.5
@export var jump_velocity: float = 4.5

@export_group("Crouch")
@export var standing_eye_height: float = 1.6
@export var crouch_eye_height: float = 1.0
@export var crouch_transition_speed: float = 8.0

@onready var head: Node3D = $Head
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var _is_crouching: bool = false


func _ready() -> void:
	add_to_group("player")
	head.position.y = standing_eye_height
	_update_collision_shape(standing_eye_height)


func _unhandled_input(event: InputEvent) -> void:
	if not GameManager.control_enabled:
		return
	if event is InputEventMouseMotion:
		_handle_mouse_look(event)


func _handle_mouse_look(event: InputEventMouseMotion) -> void:
	var sensitivity := SettingsManager.mouse_sensitivity * 0.01
	rotate_y(-event.relative.x * sensitivity)
	head.rotate_x(-event.relative.y * sensitivity)
	head.rotation.x = clampf(head.rotation.x, deg_to_rad(-85), deg_to_rad(85))


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	if not GameManager.control_enabled:
		velocity.x = move_toward(velocity.x, 0.0, move_speed)
		velocity.z = move_toward(velocity.z, 0.0, move_speed)
		move_and_slide()
		return

	_handle_crouch(delta)

	if is_on_floor() and not _is_crouching and Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	var speed := move_speed
	if _is_crouching:
		speed *= crouch_multiplier
	elif Input.is_action_pressed("sprint"):
		speed *= sprint_multiplier

	if direction != Vector3.ZERO:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)

	move_and_slide()


func _handle_crouch(delta: float) -> void:
	_is_crouching = Input.is_action_pressed("crouch")
	var target_eye_height := crouch_eye_height if _is_crouching else standing_eye_height
	head.position.y = move_toward(head.position.y, target_eye_height, crouch_transition_speed * delta)
	_update_collision_shape(head.position.y)


func _update_collision_shape(eye_height: float) -> void:
	var shape := collision_shape.shape as CapsuleShape3D
	if shape == null:
		return
	var height := eye_height + 0.2
	shape.height = height
	collision_shape.position.y = height * 0.5
