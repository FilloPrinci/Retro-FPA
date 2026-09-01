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
## core/visual_style/visual_style_profile.gd and docs/visual_style.md. The
## default comes from the "Visual Style" Project Setting (Project >
## Project Settings > General > Retro Style, added by
## addons/retro_visual_style) rather than a constant here, so picking a
## style doesn't mean editing scripts. Not currently exposed in the
## Settings menu: this is meant as a per-game art-direction choice, not a
## player-facing option yet — the plumbing (persistence, runtime apply) is
## already here so exposing it later is just adding a menu control.
enum VisualStyle { PS1, N64, GAMECUBE }
const VISUAL_STYLE_SETTING := "retro_style/visual_style"
const VISUAL_STYLE_PROFILES := {
	VisualStyle.PS1: preload("res://resources/visual_style/ps1.tres"),
	VisualStyle.N64: preload("res://resources/visual_style/n64.tres"),
	VisualStyle.GAMECUBE: preload("res://resources/visual_style/gamecube.tres"),
}

var master_volume: float = 1.0
var music_volume: float = 1.0
var sfx_volume: float = 1.0
var ambient_volume: float = 1.0
var mouse_sensitivity: float = DEFAULT_MOUSE_SENSITIVITY
var locale: String = DEFAULT_LOCALE
var visual_style: VisualStyle = _get_project_default_visual_style()

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
	SceneManager.scene_change_finished.connect(func(_path): _apply_texture_filter_to_active_content())
	GameManager.player_registered.connect(func(_player): _apply_texture_filter_to_active_content())


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		master_volume = config.get_value(SECTION, "master_volume", master_volume)
		music_volume = config.get_value(SECTION, "music_volume", music_volume)
		sfx_volume = config.get_value(SECTION, "sfx_volume", sfx_volume)
		ambient_volume = config.get_value(SECTION, "ambient_volume", ambient_volume)
		mouse_sensitivity = config.get_value(SECTION, "mouse_sensitivity", mouse_sensitivity)
		locale = config.get_value(SECTION, "locale", locale)
		visual_style = config.get_value(SECTION, "visual_style", visual_style) as VisualStyle
	apply_settings()


## The game's chosen style, read from the "retro_style/visual_style"
## Project Setting (see addons/retro_visual_style) — falls back to PS1 if
## it was never set. Only used as visual_style's initial value; once
## user://settings.cfg has a saved value, that wins instead.
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
	config.set_value(SECTION, "visual_style", visual_style)
	config.save(SETTINGS_PATH)
	apply_settings()


func apply_settings() -> void:
	_apply_bus_volume("Master", master_volume)
	_apply_bus_volume("Music", music_volume)
	_apply_bus_volume("SFX", sfx_volume)
	_apply_bus_volume("Ambient", ambient_volume)
	if TranslationServer.get_locale() != locale:
		TranslationServer.set_locale(locale)
	_apply_visual_style()
	settings_changed.emit()


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


## Applies the runtime-safe half of the chosen VisualStyleProfile (fog,
## ambient light, background, color grading) to the registered
## WorldEnvironment, and (re-)patches the texture-filter half onto whatever
## 3D content currently exists.
func _apply_visual_style() -> void:
	_apply_texture_filter_to_active_content()

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


## Walks the live scene tree and sets texture_filter on every BaseMaterial3D
## it finds, matching the chosen style. Mutates the shared Material
## Resources in place (not per-instance overrides), so a material used by
## many MeshInstance3Ds only needs to be touched once and stays consistent —
## this only affects the running session, never anything on disk.
## ShaderMaterials are left alone; they don't expose texture_filter this way
## and are out of scope (see docs/visual_style.md).
func _apply_texture_filter_to_active_content() -> void:
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
	_patch_texture_filter_recursive(get_tree().root, filter)


func _patch_texture_filter_recursive(node: Node, filter: BaseMaterial3D.TextureFilter) -> void:
	var mesh_instance := node as MeshInstance3D
	if mesh_instance and mesh_instance.mesh:
		for i in mesh_instance.mesh.get_surface_count():
			var mat := mesh_instance.get_active_material(i)
			if mat is BaseMaterial3D:
				(mat as BaseMaterial3D).texture_filter = filter
	for child in node.get_children():
		_patch_texture_filter_recursive(child, filter)
