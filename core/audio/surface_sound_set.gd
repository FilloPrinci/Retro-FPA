class_name SurfaceSoundSet
extends Resource
## A lookup table from surface type name to its footstep/landing sounds.
## Create one shared .tres under resources/audio/ and assign it to every
## FootstepComponent — per-level variety comes from tagging floor pieces
## with different SurfaceTag.surface_type values, not from swapping sets.

@export var entries: Array[SurfaceSoundEntry] = []


func get_entry(surface_type: String) -> SurfaceSoundEntry:
	for entry in entries:
		if entry.surface_type == surface_type:
			return entry
	return null
