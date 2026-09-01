class_name DamageableComponent
extends Node
## Reusable "this thing can take damage" marker. Add as a child of any
## StaticBody3D/RigidBody3D/CharacterBody3D collider (an enemy, a breakable
## prop, a test dummy) — WeaponBehavior finds this the same way Interactor
## finds InteractableComponent: by looking at the children of whatever its
## raycast hits.
##
## Deliberately minimal — no death animation, no loot, no AI reaction. That
## belongs to whatever specific game object this is attached to; connect to
## `damaged`/`died` for it. Health tracking itself is optional: leave
## max_health at 0 to opt out of it entirely (damaged still fires, just no
## health/death bookkeeping) for something a specific game wants to manage
## differently (e.g. a boss with phases).

signal damaged(amount: float, source: Node)
signal died

@export var max_health: float = 0.0

var health: float


func _ready() -> void:
	health = max_health


func take_damage(amount: float, source: Node = null) -> void:
	damaged.emit(amount, source)
	if max_health <= 0.0:
		return
	health = maxf(0.0, health - amount)
	if health <= 0.0:
		died.emit()
