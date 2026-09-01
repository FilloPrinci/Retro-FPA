class_name MeleeWeaponBehavior
extends WeaponBehavior
## A melee weapon (knife, pipe, ...) — infinite uses, no ammo. Every
## on_primary_use() attempts an attack, gated only by
## WeaponBehavior.attack_cooldown.

func on_primary_use(player: Node) -> void:
	_try_attack(player)


func get_use_animation() -> String:
	return "melee_attack"
