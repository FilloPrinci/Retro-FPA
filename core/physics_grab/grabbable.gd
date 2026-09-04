@tool
class_name Grabbable
extends Node
## Marks a RigidBody3D as something the player's Grabber can pick up, carry,
## rotate and throw. Attach as a child of the RigidBody3D. Purely data — all
## the actual physics happens in Grabber, on the player.
##
## @tool: WorldItem (@tool) builds this via set_script() while still in the
## editor — same reasoning as InteractableComponent's own @tool doc
## comment. Purely two exported vars, no _ready()/_process() of its own.

## How far in front of the camera the object is held while carried.
@export var hold_distance: float = 1.5
## Impulse strength applied when the object is thrown.
@export var throw_force: float = 8.0
