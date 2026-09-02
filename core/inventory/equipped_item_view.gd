extends Node3D
## Shows the equipped item's view_model as a child of this node (meant to be
## EquipAnchor, a Node3D under Head/Camera3D positioned bottom-right of the
## screen) and plays a small procedural animation whenever the item is used.
##
## Looks up EquippedItemInput via get_owner() (the Player root — this node
## is part of player.tscn, so its owner is set before _ready() runs, same
## technique EquippedItemInput itself uses to reach the player). Purely
## visual/feel: it never touches gameplay state.

var _current_view: Node3D = null
var _rest_transform := Transform3D.IDENTITY
var _tween: Tween = null


func _ready() -> void:
	InventoryManager.item_equipped.connect(_on_item_equipped)
	InventoryManager.item_unequipped.connect(_on_item_unequipped)

	var input := get_owner().get_node_or_null("EquippedItemInput") if get_owner() else null
	if input:
		input.primary_used.connect(_on_used)
		input.secondary_used.connect(_on_used)

	var equipped := InventoryManager.get_equipped_item()
	if equipped:
		_on_item_equipped(equipped)


func _on_item_equipped(item: ItemData) -> void:
	_clear_view()
	if item.view_model == null:
		return
	_current_view = item.view_model.instantiate()
	add_child(_current_view)
	_rest_transform = _current_view.transform


func _on_item_unequipped() -> void:
	_clear_view()


func _clear_view() -> void:
	if _tween:
		_tween.kill()
		_tween = null
	if _current_view:
		_current_view.queue_free()
		_current_view = null


func _on_used(item: ItemData) -> void:
	if _current_view == null:
		return
	var kind := item.equip_behavior.get_use_animation() if item.equip_behavior else "shake"
	match kind:
		"melee_attack":
			_play_melee_swing()
		"ranged_recoil":
			_play_recoil()
		_:
			_play_shake()


## Small side-to-side wiggle — generic "you used this item" feedback for
## anything without a more specific animation.
func _play_shake() -> void:
	_restart_tween()
	var rot := _rest_transform.basis.get_euler()
	_tween.tween_property(_current_view, "rotation:z", rot.z + deg_to_rad(8.0), 0.06)
	_tween.tween_property(_current_view, "rotation:z", rot.z - deg_to_rad(8.0), 0.09)
	_tween.tween_property(_current_view, "rotation:z", rot.z, 0.08)


## Diagonal slash: a short wind-up down-and-left, then a fast sweep up
## and to the right that carries *past* the rest pose before easing back.
## Rotating in place around the rest position read as a stab, not a
## swing — the blade needs to actually travel across the screen, i.e. the
## pivot itself has to move, not just the blade's orientation.
func _play_melee_swing() -> void:
	_restart_tween()
	var base_pos := _rest_transform.origin
	var base_rot := _rest_transform.basis.get_euler()

	var windup_pos := base_pos + Vector3(-0.09, -0.09, 0.04)
	var windup_rot := base_rot + Vector3(0.0, 0.0, deg_to_rad(20.0))

	var slash_pos := base_pos + Vector3(0.16, 0.14, -0.10)
	var slash_rot := base_rot + Vector3(0.0, 0.0, deg_to_rad(-40.0))

	_tween.tween_property(_current_view, "position", windup_pos, 0.05)
	_tween.parallel().tween_property(_current_view, "rotation", windup_rot, 0.05)
	_tween.tween_property(_current_view, "position", slash_pos, 0.09)
	_tween.parallel().tween_property(_current_view, "rotation", slash_rot, 0.09)
	_tween.tween_property(_current_view, "position", base_pos, 0.13)
	_tween.parallel().tween_property(_current_view, "rotation", base_rot, 0.13)


## Quick backward-up kick and return — firearm recoil.
func _play_recoil() -> void:
	_restart_tween()
	var base_pos := _rest_transform.origin
	var rot := _rest_transform.basis.get_euler()
	_tween.tween_property(_current_view, "position:z", base_pos.z + 0.08, 0.04)
	_tween.parallel().tween_property(_current_view, "rotation:x", rot.x + deg_to_rad(10.0), 0.04)
	_tween.tween_property(_current_view, "position:z", base_pos.z, 0.12)
	_tween.parallel().tween_property(_current_view, "rotation:x", rot.x, 0.12)


## Kills any in-flight animation, snaps back to rest, and starts a fresh
## tween — keeps rapid repeated uses (e.g. mashing a melee attack) from
## drifting away from the rest pose.
func _restart_tween() -> void:
	if _tween:
		_tween.kill()
	_current_view.transform = _rest_transform
	_tween = create_tween()
