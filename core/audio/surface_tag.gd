class_name SurfaceTag
extends Node
## Tags the collider it's attached to with a surface type string, so
## FootstepComponent can pick the right sounds. Add as a child of any
## StaticBody3D floor piece; the default "default" type is used wherever
## no tag is present, so tagging is opt-in, not required everywhere.

@export var surface_type: String = "default"
