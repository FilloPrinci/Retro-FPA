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
## Not currently exposed in the Settings menu: this is meant as a per-game
## art-direction choice (change DEFAULT_VISUAL_STYLE for your game), not a
## player-facing option yet. The plumbing (persistence, runtime apply) is
## already here so exposing it later is just adding a menu control.
enum VisualStyle { PS1, N64, GAMECUBE }
const DEFAULT_VISUAL_STYLE := VisualStyle.PS1
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
var visual_style: VisualStyle = DEFAULT_VISUAL_STYLE

## Set by main.gd once the persistent shell's WorldEnvironment exists —
## autoloads are ready before the main scene, so apply_settings() may run
## once with nothing registered yet; registering re-applies immediately.
var _world_environment: WorldEnvironment = null


func _ready() -> void:
	load_settings()


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
## WorldEnvironment. The texture-filter half of the profile is applied at
## setup time instead — see tools/setup_project.gd.
func _apply_visual_style() -> void:
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
