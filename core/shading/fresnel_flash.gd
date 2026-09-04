class_name FresnelFlash
extends Node
## Drop as a sibling (or parent) of a MeshInstance3D — same pattern as
## DamageableComponent/InteractableComponent — to trigger fresnel flashes
## from anywhere else in the game: a white pulse on a pickupable item to
## draw the eye, a single red/yellow flash on something just hit, and so
## on, without the caller ever having to know or care whether the mesh's
## material happens to be shared with other instances.
##
## Why this exists instead of just animating
## RetroSurfaceMaterial.flash_strength directly: materials in this
## project are shared Resources on purpose (see
## SettingsManager._apply_material_patches()'s doc comment) — many
## MeshInstance3Ds can point at the exact same Material to keep memory
## and consistency cheap. Flashing a *shared* material's uniform would
## flash every other object using it too, which is never what "this one
## enemy got hit" means. The first time flash()/pulse() is actually
## called, this component makes its own MeshInstance3D's material(s)
## locally unique (a one-time duplicate, via set_surface_override_material)
## so the flash never leaks onto any sibling object — right up until that
## moment, everything about the material (albedo, tiling, ...) still
## matches the shared original exactly.
##
## A surface whose material isn't a RetroSurfaceMaterial (a plain
## BaseMaterial3D placeholder, for instance) is left alone — there's no
## flash uniform to drive, so it's silently skipped rather than erroring.
## Assign a RetroSurfaceMaterial to anything that should support this.

## Defaults to the parent if left unset, so the common case (this node
## added directly under the MeshInstance3D it should flash) needs no
## configuration at all.
@export var mesh_instance: MeshInstance3D

var _materials: Array[RetroSurfaceMaterial] = []
var _made_unique := false
var _pulse_tween: Tween = null


func _ready() -> void:
	if mesh_instance == null:
		mesh_instance = get_parent() as MeshInstance3D
	if mesh_instance == null:
		push_warning("FresnelFlash on '%s' has no MeshInstance3D — set mesh_instance, or add this node under one." % name)


## One-shot flash that fades back out over `duration` — e.g. a hit flash.
func flash(color: Color, duration: float = 0.15) -> void:
	_ensure_unique_materials()
	if _materials.is_empty():
		return
	for mat in _materials:
		mat.flash_color = color
	_set_all_flash_strength(1.0)
	var tween := (Engine.get_main_loop() as SceneTree).create_tween()
	tween.tween_method(_set_all_flash_strength, 1.0, 0.0, duration)


## Continuous pulsing flash (fade up, fade down, repeat) — e.g. a
## pickupable item's idle "notice me" white blink. Call stop_pulse() to
## end it; starting a new pulse()/flash() while one is already running
## replaces it cleanly.
func pulse(color: Color, period: float = 1.0, peak_strength: float = 1.0) -> void:
	_ensure_unique_materials()
	stop_pulse()
	if _materials.is_empty():
		return
	for mat in _materials:
		mat.flash_color = color
	_pulse_tween = (Engine.get_main_loop() as SceneTree).create_tween()
	_pulse_tween.set_loops()
	_pulse_tween.tween_method(_set_all_flash_strength, 0.0, peak_strength, period * 0.5)
	_pulse_tween.tween_method(_set_all_flash_strength, peak_strength, 0.0, period * 0.5)


func stop_pulse() -> void:
	if _pulse_tween:
		_pulse_tween.kill()
		_pulse_tween = null
	_set_all_flash_strength(0.0)


func _set_all_flash_strength(value: float) -> void:
	for mat in _materials:
		mat.flash_strength = value


## Duplicates (once) whichever of the mesh's active surface materials are
## RetroSurfaceMaterial, and installs the copies as surface overrides —
## from then on _materials holds only this instance's own copies, never
## the original shared Resource.
func _ensure_unique_materials() -> void:
	if _made_unique or mesh_instance == null or mesh_instance.mesh == null:
		return
	_made_unique = true
	for i in mesh_instance.mesh.get_surface_count():
		var mat := mesh_instance.get_active_material(i)
		if mat is RetroSurfaceMaterial:
			var unique_mat := mat.duplicate() as RetroSurfaceMaterial
			mesh_instance.set_surface_override_material(i, unique_mat)
			_materials.append(unique_mat)
