class_name WeaponBehavior
extends EquippableBehavior
## Base for melee/ranged weapons — see MeleeWeaponBehavior and
## RangedWeaponBehavior, the two concrete subclasses. Handles the part
## that's identical for both: a forward hitscan from the player's camera,
## gated by a cooldown. Subclasses decide *when* an attack is allowed
## (ranged additionally needs ammo) by calling _try_attack() from their own
## on_primary_use().

@export var damage: float = 10.0
@export var range: float = 2.5
## Seconds between attacks. Timestamp-based rather than a per-frame
## countdown: this is a Resource, not a Node, so it has no _process() to
## tick one down with.
@export var attack_cooldown: float = 0.5

var _last_attack_time_ms: int = -1000000000


func on_equip(_player: Node) -> void:
	_last_attack_time_ms = -1000000000


## Returns true if the attack actually happened (not on cooldown) — the
## subclass uses this to know whether to spend ammo, play a sound, etc.
func _try_attack(player: Node) -> bool:
	var now := Time.get_ticks_msec()
	if now - _last_attack_time_ms < attack_cooldown * 1000.0:
		return false
	_last_attack_time_ms = now
	_perform_hitscan(player)
	return true


func _perform_hitscan(player: Node) -> void:
	var camera := player.get_node_or_null("Head/Camera3D") as Camera3D
	if camera == null:
		return

	var player_3d := player as Node3D
	if player_3d == null:
		return
	var space_state := player_3d.get_world_3d().direct_space_state
	var from := camera.global_position
	var to := from - camera.global_transform.basis.z * range
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_bodies = true
	var result := space_state.intersect_ray(query)
	if result.is_empty():
		return

	var target := _find_damageable(result.get("collider") as Node)
	if target:
		target.take_damage(damage, player)


func _find_damageable(collider: Node) -> DamageableComponent:
	if collider == null:
		return null
	for child in collider.get_children():
		if child is DamageableComponent:
			return child
	return null
