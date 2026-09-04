@tool
class_name VisualStylePreview
extends WorldEnvironment
## Drop this into any scene you're editing (a level, main.tscn, whatever) to
## preview the current Retro Style Project Settings live in the editor's 3D
## viewport, with no Play needed. See docs/visual_style.md.
##
## Inert outside the editor: frees itself the instant actual gameplay
## starts, since the *real* environment is owned by the persistent shell's
## own WorldEnvironment via SettingsManager (ui/main/main.tscn) — having a
## second WorldEnvironment active during Play would compete with it.
##
## Previews fog/ambient/background/color-grading/bloom (via its own
## Environment) and texture_filter_nearest (patched onto materials in the
## edited scene — BaseMaterial3D.texture_filter directly, or
## RetroSurfaceMaterial.apply_texture_filter() swapping in the matching
## compiled shader variant — both reversible and non-destructive, same
## mechanism SettingsManager uses at runtime). Deliberately does NOT
## preview texture downsampling: that mutates a texture's actual pixel
## data, which would only ever be discarded automatically at the end of a
## Play session — but an editor session can sit open for hours, and if you
## hit Ctrl+S while a downsampled copy is loaded in memory, Godot can bake
## that lossy resize into the saved resource, permanently degrading the
## source art. Press Play to check that one instead. Resolution forcing
## isn't previewable here either — it's a property of the actual game
## window (DisplayServer/Window), which has no equivalent in the editor's
## own viewport.

const VISUAL_STYLE_PROFILES := {
	0: preload("res://resources/visual_style/ps1.tres"),
	1: preload("res://resources/visual_style/n64.tres"),
	2: preload("res://resources/visual_style/gamecube.tres"),
}


func _ready() -> void:
	if not Engine.is_editor_hint():
		queue_free()
		return
	_refresh()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_refresh()


func _refresh() -> void:
	var style_index: int = ProjectSettings.get_setting("retro_style/visual_style", 0)
	var profile: VisualStyleProfile = VISUAL_STYLE_PROFILES.get(style_index)
	if profile == null:
		return

	if environment == null:
		environment = Environment.new()
	profile.apply_to_environment(environment)
	VisualStyleProfile.apply_glow(environment)

	var scene_root := get_tree().edited_scene_root
	if scene_root:
		_patch_texture_filter_recursive(scene_root, profile.resolve_texture_filter(), profile.texture_filter_nearest)


func _patch_texture_filter_recursive(node: Node, filter: BaseMaterial3D.TextureFilter, nearest: bool) -> void:
	var mesh_instance := node as MeshInstance3D
	if mesh_instance and mesh_instance.mesh:
		for i in mesh_instance.mesh.get_surface_count():
			var mat := mesh_instance.get_active_material(i)
			if mat is BaseMaterial3D:
				(mat as BaseMaterial3D).texture_filter = filter
			elif mat is RetroSurfaceMaterial:
				(mat as RetroSurfaceMaterial).apply_texture_filter(nearest)
	for child in node.get_children():
		_patch_texture_filter_recursive(child, filter, nearest)
