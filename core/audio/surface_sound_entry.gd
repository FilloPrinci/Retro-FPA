class_name SurfaceSoundEntry
extends Resource
## One row of a SurfaceSoundSet: which sounds play for a given surface type.

@export var surface_type: String = "default"
@export var footstep_sounds: Array[AudioStream] = []
@export var landing_sound: AudioStream
