extends Node
## Persisted user preferences: audio volumes, mouse sensitivity, language,
## visual style. Autoload singleton, registered right after GameManager so
## volumes are correct before anything plays a sound.

signal settings_changed

const SETTINGS_PATH := "user://settings.cfg"
const SECTION := "settings"

const DEFAULT_MOUSE_SENSITIVITY := 0.15
const DEFAULT_LOCALE := "en"

## Retro rendering look, applied via a VisualStyleProfile — see
## core/visual_style/visual_style_profile.gd and docs/visual_style.md.
## Always read live from the "Visual Style" Project Setting (Project >
## Project Settings > General > Retro Style, added by
## addons/retro_visual_style) — deliberately NOT persisted to
## user://settings.cfg like the fields below, unlike them it has no
## Settings-menu control yet, so there's no player action that should ever
## freeze it to a stale saved value that silently outlives a Project
## Settings change. Wiring up a menu control later means persisting it the
## same way the others are.
enum VisualStyle { PS1, N64, GAMECUBE }
const VISUAL_STYLE_SETTING := "retro_style/visual_style"
const VISUAL_STYLE_PROFILES := {
	VisualStyle.PS1: preload("res://resources/visual_style/ps1.tres"),
	VisualStyle.N64: preload("res://resources/visual_style/n64.tres"),
	VisualStyle.GAMECUBE: preload("res://resources/visual_style/gamecube.tres"),
}

## Window size when nothing forces an internal render resolution (see
## below). A curated list rather than free-form input, shown as-is in the
## Settings menu.
const RESOLUTION_CHOICES := [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
]
const DEFAULT_WINDOW_RESOLUTION := Vector2i(1280, 720)

## Resolution forcing, texture downsampling, and the fog override below:
## unlike Visual Style, these apply the same way regardless of which retro
## look is active — they're a blanket dev choice, not part of a specific
## console's "look" — so they're their own Project Settings (Retro Style
## category, added by addons/retro_visual_style) instead of
## VisualStyleProfile fields. Read directly via ProjectSettings.get_setting(),
## not cached as vars, since they're a fixed dev choice rather than
## something that changes at runtime. See docs/visual_style.md.
const FORCE_RESOLUTION_SETTING := "retro_style/force_resolution"
const FORCED_RESOLUTION_SETTING := "retro_style/forced_resolution"
const FORCE_TEXTURE_DOWNSAMPLE_SETTING := "retro_style/force_texture_downsample"
const MAX_TEXTURE_SIZE_SETTING := "retro_style/max_texture_size"

## Fog override: same idea as above — when on, these replace the active
## VisualStyleProfile's fog_* fields entirely (including turning fog off
## regardless of what the style normally does). See docs/visual_style.md.
const OVERRIDE_FOG_SETTING := "retro_style/override_fog"
const FOG_ENABLED_SETTING := "retro_style/fog_enabled"
const FOG_COLOR_SETTING := "retro_style/fog_color"
const FOG_DENSITY_SETTING := "retro_style/fog_density"
const FOG_DEPTH_BEGIN_SETTING := "retro_style/fog_depth_begin"
const FOG_DEPTH_END_SETTING := "retro_style/fog_depth_end"

var master_volume: float = 1.0
var music_volume: float = 1.0
var sfx_volume: float = 1.0
var ambient_volume: float = 1.0
var mouse_sensitivity: float = DEFAULT_MOUSE_SENSITIVITY
var locale: String = DEFAULT_LOCALE
var visual_style: VisualStyle = _get_project_default_visual_style()
var window_resolution: Vector2i = DEFAULT_WINDOW_RESOLUTION
var fullscreen: bool = false

## Set by main.gd once the persistent shell's WorldEnvironment exists —
## autoloads are ready before the main scene, so apply_settings() may run
## once with nothing registered yet; registering re-applies immediately.
var _world_environment: WorldEnvironment = null


func _ready() -> void:
	load_settings()
	# BaseMaterial3D always has an explicit texture_filter (default: linear
	# with mipmaps) — it never "inherits" a project-wide default the way
	# CanvasItem/UI textures do. So the nearest-vs-linear half of the style
	# has to be patched onto materials directly whenever new 3D content
	# shows up, not just set once as a project setting.
	SceneManager.scene_change_finished.connect(func(_path): _apply_material_patches())
	GameManager.player_registered.connect(func(_player): _apply_material_patches())


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		master_volume = config.get_value(SECTION, "master_volume", master_volume)
		music_volume = config.get_value(SECTION, "music_volume", music_volume)
		sfx_volume = config.get_value(SECTION, "sfx_volume", sfx_volume)
		ambient_volume = config.get_value(SECTION, "ambient_volume", ambient_volume)
		mouse_sensitivity = config.get_value(SECTION, "mouse_sensitivity", mouse_sensitivity)
		locale = config.get_value(SECTION, "locale", locale)
		window_resolution = config.get_value(SECTION, "window_resolution", window_resolution)
		fullscreen = config.get_value(SECTION, "fullscreen", fullscreen)
	# Not from config: see the doc comment on `visual_style` above. Always
	# re-read fresh, so load_settings() re-syncs it even if something else
	# already changed it this session.
	visual_style = _get_project_default_visual_style()
	apply_settings()


## The game's chosen style, read live from the "retro_style/visual_style"
## Project Setting (see addons/retro_visual_style) — falls back to PS1 if
## it was never set.
func _get_project_default_visual_style() -> VisualStyle:
	return ProjectSettings.get_setting(VISUAL_STYLE_SETTING, VisualStyle.PS1) as VisualStyle


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value(SECTION, "master_volume", master_volume)
	config.set_value(SECTION, "music_volume", music_volume)
	config.set_value(SECTION, "sfx_volume", sfx_volume)
	config.set_value(SECTION, "ambient_volume", ambient_volume)
	config.set_value(SECTION, "mouse_sensitivity", mouse_sensitivity)
	config.set_value(SECTION, "locale", locale)
	config.set_value(SECTION, "window_resolution", window_resolution)
	config.set_value(SECTION, "fullscreen", fullscreen)
	config.save(SETTINGS_PATH)
	apply_settings()


func apply_settings() -> void:
	_apply_bus_volume("Master", master_volume)
	_apply_bus_volume("Music", music_volume)
	_apply_bus_volume("SFX", sfx_volume)
	_apply_bus_volume("Ambient", ambient_volume)
	if TranslationServer.get_locale() != locale:
		TranslationServer.set_locale(locale)
	visual_style = _get_project_default_visual_style()
	_apply_visual_style()
	_apply_resolution()
	settings_changed.emit()


## Whether Project Settings > Retro Style > Force Resolution is on — the
## Settings menu hides its Resolution control in that case, since
## window_resolution wouldn't do anything visible.
func is_resolution_forced() -> bool:
	return ProjectSettings.get_setting(FORCE_RESOLUTION_SETTING, false)


## Called by main.gd once the persistent shell's WorldEnvironment node
## exists. Re-applies immediately since apply_settings() may already have
## run once before this was available (autoloads init before the main
## scene).
func register_world_environment(world_environment: WorldEnvironment) -> void:
	_world_environment = world_environment
	_apply_visual_style()


func _apply_bus_volume(bus_name: String, linear_volume: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index == -1:
		return
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(clampf(linear_volume, 0.0, 1.0)))


## Applies fullscreen/windowed mode, the window size (when the style isn't
## forcing its own internal resolution), and the forced-resolution
## pixelation itself (Window.content_scale_size stretched up to fill
## whatever the window ends up being — the classic blocky retro look,
## independent of the actual window/monitor size).
func _apply_resolution() -> void:
	var window := get_window()
	if window == null:
		return  # No window in this context (e.g. a headless run).

	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	if not fullscreen:
		window.size = window_resolution

	if is_resolution_forced():
		window.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		window.content_scale_size = ProjectSettings.get_setting(FORCED_RESOLUTION_SETTING, Vector2i(320, 240))
	else:
		window.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED


## Applies the runtime-safe half of the chosen VisualStyleProfile (fog,
## ambient light, background, color grading) to the registered
## WorldEnvironment, and (re-)patches the texture filter/downsample half
## onto whatever 3D content currently exists.
func _apply_visual_style() -> void:
	_apply_material_patches()

	if _world_environment == null:
		return
	var profile: VisualStyleProfile = VISUAL_STYLE_PROFILES.get(visual_style)
	if profile == null:
		return

	var env := _world_environment.environment
	if env == null:
		env = Environment.new()
		_world_environment.environment = env

	env.background_mode = Environment.BG_COLOR
	env.background_color = profile.background_color

	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = profile.ambient_light_color
	env.ambient_light_energy = profile.ambient_light_energy

	if ProjectSettings.get_setting(OVERRIDE_FOG_SETTING, false):
		env.fog_enabled = ProjectSettings.get_setting(FOG_ENABLED_SETTING, true)
		env.fog_light_color = ProjectSettings.get_setting(FOG_COLOR_SETTING, Color(0.5, 0.5, 0.55))
		env.fog_density = ProjectSettings.get_setting(FOG_DENSITY_SETTING, 0.02)
		env.fog_depth_begin = ProjectSettings.get_setting(FOG_DEPTH_BEGIN_SETTING, 10.0)
		env.fog_depth_end = ProjectSettings.get_setting(FOG_DEPTH_END_SETTING, 60.0)
	else:
		env.fog_enabled = profile.fog_enabled
		env.fog_light_color = profile.fog_color
		env.fog_density = profile.fog_density
		env.fog_depth_begin = profile.fog_depth_begin
		env.fog_depth_end = profile.fog_depth_end

	env.tonemap_mode = profile.tonemap_mode
	env.tonemap_exposure = profile.tonemap_exposure

	env.adjustment_enabled = profile.adjustment_enabled
	env.adjustment_brightness = profile.adjustment_brightness
	env.adjustment_contrast = profile.adjustment_contrast
	env.adjustment_saturation = profile.adjustment_saturation


## Walks the live scene tree and, on every BaseMaterial3D it finds: sets
## texture_filter, and (if the style forces it) downsamples the albedo
## texture to max_texture_size. Mutates the shared Material/Texture
## Resources in place (not per-instance overrides), so a material used by
## many MeshInstance3Ds only needs to be touched once and stays consistent —
## this only affects the running session, never anything on disk.
## ShaderMaterials are left alone; they don't expose texture_filter this way
## and are out of scope (see docs/visual_style.md).
func _apply_material_patches() -> void:
	var profile: VisualStyleProfile = VISUAL_STYLE_PROFILES.get(visual_style)
	if profile == null or not is_inside_tree():
		return
	# anisotropic_filtering_level only has an effect on a material using an
	# "Anisotropic" filter mode — the global project setting alone (set by
	# tools/setup_project.gd) doesn't apply it to materials that don't.
	var use_aniso := profile.anisotropic_filtering_level > 0
	var filter: BaseMaterial3D.TextureFilter
	if profile.texture_filter_nearest:
		filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS_ANISOTROPIC if use_aniso else BaseMaterial3D.TEXTURE_FILTER_NEAREST
	else:
		filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC if use_aniso else BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	var force_downsample: bool = ProjectSettings.get_setting(FORCE_TEXTURE_DOWNSAMPLE_SETTING, false)
	var max_texture_size: int = -1
	if force_downsample:
		max_texture_size = ProjectSettings.get_setting(MAX_TEXTURE_SIZE_SETTING, 256)
	_patch_material_recursive(get_tree().root, filter, max_texture_size)


func _patch_material_recursive(node: Node, filter: BaseMaterial3D.TextureFilter, max_texture_size: int) -> void:
	var mesh_instance := node as MeshInstance3D
	if mesh_instance and mesh_instance.mesh:
		for i in mesh_instance.mesh.get_surface_count():
			var mat := mesh_instance.get_active_material(i) as BaseMaterial3D
			if mat:
				mat.texture_filter = filter
				if max_texture_size > 0:
					_downsample_if_needed(mat, max_texture_size)
	for child in node.get_children():
		_patch_material_recursive(child, filter, max_texture_size)


## Shrinks mat.albedo_texture in place if either dimension exceeds
## max_size, preserving aspect ratio. Only albedo_texture — this project's
## art direction is single-albedo-texture, no PBR maps (see
## docs/blender_asset_guidelines.md), so that's the only slot that matters
## here. Already-small textures are left untouched (this only ever
## shrinks), so repeated calls across scene changes are cheap no-ops.
func _downsample_if_needed(mat: BaseMaterial3D, max_size: int) -> void:
	var texture := mat.albedo_texture
	if texture == null:
		return
	var size := texture.get_size()
	if size.x <= max_size and size.y <= max_size:
		return

	var image := texture.get_image()
	if image == null:
		return  # e.g. a texture format that can't be read back on this backend.

	var scale := float(max_size) / maxf(size.x, size.y)
	var new_size := Vector2i(maxi(1, roundi(size.x * scale)), maxi(1, roundi(size.y * scale)))
	image.resize(new_size.x, new_size.y, Image.INTERPOLATE_NEAREST)
	mat.albedo_texture = ImageTexture.create_from_image(image)
