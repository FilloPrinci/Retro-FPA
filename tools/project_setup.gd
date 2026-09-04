class_name ProjectSetup
extends RefCounted
## Shared logic for (re)generating the Input Map, Audio Bus Layout, visual
## style texture-filter/window-stretch defaults, and the registered
## translations list — used by both tools/setup_project.gd (headless,
## `godot --headless -s res://tools/setup_project.gd`) and the "Retro
## Style" plugin's "Apply Retro Style Settings..." menu item
## (Project > Tools), so there's one canonical implementation instead of
## two copies that can drift apart.
##
## apply() only stages changes via ProjectSettings.set_setting() —
## ProjectSettings.save() is the caller's responsibility, same
## one-save-at-the-end reasoning as the plugin's own settings
## registration (saving mid-way marks not-yet-fully-set fields as
## "non-default" and writes them out even when they're actually default).

const AUDIO_BUS_LAYOUT_PATH := "res://resources/audio/default_bus_layout.tres"
const ADDITIONAL_BUSES := ["Music", "SFX", "Ambient", "UI"]

## The chosen style — Project Settings > General > Retro Style > Visual
## Style (added by addons/retro_visual_style), 0/1/2 = PS1/N64/GameCube —
## picks which VisualStyleProfile's texture-filter fields get baked into
## project.godot as the default sampler settings (see docs/visual_style.md).
## This is a renderer-startup-time default, not something safe to flip at
## runtime; re-apply after changing it. The rest of the profile (fog,
## color grading, and the actual nearest/linear material filter) is
## applied at runtime instead, via SettingsManager, which reads the same
## Project Setting.
const VISUAL_STYLE_SETTING := "retro_style/visual_style"
const VISUAL_STYLE_PROFILE_PATHS := [
	"res://resources/visual_style/ps1.tres",
	"res://resources/visual_style/n64.tres",
	"res://resources/visual_style/gamecube.tres",
]

## Force Resolution/Forced Resolution (Project Settings > Retro Style) are
## baked here too, not applied live by SettingsManager — changing
## Window.content_scale_mode/content_scale_size at runtime, after the
## window and its CanvasLayers already rendered a frame, was found to
## produce a wrongly-positioned (not just wrongly-scaled) UI in an actual
## exported build: the classic "small panel stuck in a corner" symptom,
## even though the same anchor math checked out fine in isolation. Baking
## display/window/stretch/* into project.godot before the window is ever
## created avoids that class of problem entirely — same reasoning as the
## texture-filter fields above. Re-apply after changing Force
## Resolution/Forced Resolution.
const FORCE_RESOLUTION_SETTING := "retro_style/force_resolution"
const FORCED_RESOLUTION_SETTING := "retro_style/forced_resolution"
## Curated Forced Resolution choices — Project Settings > Retro Style >
## Forced Resolution Preset (a dropdown; the hint string that builds it
## lives in addons/retro_visual_style/plugin.gd's SETTINGS, hand-kept in
## the same order as this array, same as VISUAL_STYLE_HINT already is for
## VisualStyle). Each retro entry keeps its era's actual vertical
## resolution and pairs it with a 16:9-widened companion — same height,
## width recomputed for 16:9 — rather than that era's real (often
## non-4:3, since CRT consoles used non-square pixels) horizontal
## resolution. HD's two entries are already 16:9, so they don't get a
## separate widened pair. "Custom..." (size = null) is the escape hatch:
## _resolve_forced_resolution_preset() leaves `forced_resolution` alone
## when it's selected, exactly the free-typed Vector2i field this used to
## be the only option — see docs/visual_style.md.
const FORCED_RESOLUTION_PRESET_SETTING := "retro_style/forced_resolution_preset"
const FORCED_RESOLUTION_PRESETS := [
	{"label": "PS1 (320x240)", "size": Vector2i(320, 240)},
	{"label": "PS1 16:9 (427x240)", "size": Vector2i(427, 240)},
	{"label": "N64 (256x224)", "size": Vector2i(256, 224)},
	{"label": "N64 16:9 (398x224)", "size": Vector2i(398, 224)},
	{"label": "GameCube (640x480)", "size": Vector2i(640, 480)},
	{"label": "GameCube 16:9 (853x480)", "size": Vector2i(853, 480)},
	{"label": "HD 720p (1280x720)", "size": Vector2i(1280, 720)},
	{"label": "HD 1080p (1920x1080)", "size": Vector2i(1920, 1080)},
	{"label": "Custom...", "size": null},
]
## Real starting window size when Force Resolution is on — otherwise the
## window would start as a literal 320x240 (or whatever's forced) box
## before SettingsManager resizes it on the first frame. Keep in sync with
## SettingsManager.DEFAULT_WINDOW_RESOLUTION.
const STARTUP_WINDOW_SIZE := Vector2i(1280, 720)

# action_name -> list of physical keycodes bound to it.
const KEY_ACTIONS := {
	"move_forward": [KEY_W, KEY_UP],
	"move_back": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"jump": [KEY_SPACE],
	"sprint": [KEY_SHIFT],
	"crouch": [KEY_CTRL],
	"interact": [KEY_E],
	"pause": [KEY_ESCAPE],
	"inventory_toggle": [KEY_TAB],
	"equip_slot_1": [KEY_1],
	"equip_slot_2": [KEY_2],
	"equip_slot_3": [KEY_3],
	"equip_slot_4": [KEY_4],
}

# action_name -> mouse button index.
const MOUSE_ACTIONS := {
	"primary_action": MOUSE_BUTTON_LEFT,
	"secondary_action": MOUSE_BUTTON_RIGHT,
}

const TRANSLATIONS_DIR := "res://translations"
const DEFAULT_LOCALE := "en"


static func apply() -> void:
	ProjectSettings.set_setting("application/config/name", "Retro FPA")

	_setup_input_map()
	_setup_audio_buses()
	_setup_rendering_defaults()
	_setup_window_stretch()
	_setup_translations()


static func _setup_input_map() -> void:
	for action_name in KEY_ACTIONS:
		var events: Array = []
		for keycode in KEY_ACTIONS[action_name]:
			var event := InputEventKey.new()
			event.physical_keycode = keycode
			events.append(event)
		ProjectSettings.set_setting("input/%s" % action_name, {
			"deadzone": 0.5,
			"events": events,
		})

	for action_name in MOUSE_ACTIONS:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_ACTIONS[action_name]
		ProjectSettings.set_setting("input/%s" % action_name, {
			"deadzone": 0.5,
			"events": [event],
		})


static func _setup_audio_buses() -> void:
	for bus_name in ADDITIONAL_BUSES:
		if AudioServer.get_bus_index(bus_name) == -1:
			var idx := AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")

	var layout := AudioServer.generate_bus_layout()
	var dir_path := AUDIO_BUS_LAYOUT_PATH.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
	ResourceSaver.save(layout, AUDIO_BUS_LAYOUT_PATH)
	ProjectSettings.set_setting("audio/buses/default_bus_layout", AUDIO_BUS_LAYOUT_PATH)


static func _setup_rendering_defaults() -> void:
	# No MSAA, in line with the retro low-fi look; GL Compatibility already
	# disables most modern post-processing by default.
	ProjectSettings.set_setting("rendering/anti_aliasing/quality/msaa_3d", 0)

	var style_index: int = ProjectSettings.get_setting(VISUAL_STYLE_SETTING, 0)
	if style_index < 0 or style_index >= VISUAL_STYLE_PROFILE_PATHS.size():
		push_warning("[ProjectSetup] '%s' is out of range (%d); defaulting to PS1." % [VISUAL_STYLE_SETTING, style_index])
		style_index = 0
	var profile: VisualStyleProfile = load(VISUAL_STYLE_PROFILE_PATHS[style_index])
	if profile == null:
		push_warning("[ProjectSetup] Visual style profile did not load; texture filter defaults left untouched.")
		return

	var filter := 0 if profile.texture_filter_nearest else 1  # 0 = Nearest, 1 = Linear
	ProjectSettings.set_setting("rendering/textures/canvas_textures/default_texture_filter", filter)
	ProjectSettings.set_setting("rendering/textures/default_filters/use_nearest_mipmap_filter", profile.texture_filter_nearest)
	ProjectSettings.set_setting("rendering/textures/default_filters/anisotropic_filtering_level", profile.anisotropic_filtering_level)
	ProjectSettings.set_setting("rendering/textures/default_filters/texture_mipmap_bias", profile.mipmap_bias)


## If a curated preset (anything but "Custom...") is selected, writes its
## size into retro_style/forced_resolution — so that field always reflects
## the chosen preset once applied. Leaves it untouched on "Custom...",
## which is the whole point of that entry: pick it to go back to typing a
## resolution into forced_resolution by hand.
static func _resolve_forced_resolution_preset() -> void:
	var preset_index: int = ProjectSettings.get_setting(FORCED_RESOLUTION_PRESET_SETTING, 0)
	if preset_index < 0 or preset_index >= FORCED_RESOLUTION_PRESETS.size():
		push_warning("[ProjectSetup] '%s' is out of range (%d); leaving forced_resolution as-is." % [FORCED_RESOLUTION_PRESET_SETTING, preset_index])
		return
	var size = FORCED_RESOLUTION_PRESETS[preset_index]["size"]
	if size != null:
		ProjectSettings.set_setting(FORCED_RESOLUTION_SETTING, size)


## Bakes Force Resolution into project.godot's display/window/stretch/*
## settings — see the doc comment on FORCE_RESOLUTION_SETTING above.
static func _setup_window_stretch() -> void:
	_resolve_forced_resolution_preset()
	var force_resolution: bool = ProjectSettings.get_setting(FORCE_RESOLUTION_SETTING, false)
	if force_resolution:
		var forced: Vector2i = ProjectSettings.get_setting(FORCED_RESOLUTION_SETTING, Vector2i(320, 240))
		ProjectSettings.set_setting("display/window/size/viewport_width", forced.x)
		ProjectSettings.set_setting("display/window/size/viewport_height", forced.y)
		ProjectSettings.set_setting("display/window/size/window_width_override", STARTUP_WINDOW_SIZE.x)
		ProjectSettings.set_setting("display/window/size/window_height_override", STARTUP_WINDOW_SIZE.y)
		ProjectSettings.set_setting("display/window/stretch/mode", "viewport")
		ProjectSettings.set_setting("display/window/stretch/aspect", "keep")
	else:
		ProjectSettings.set_setting("display/window/size/viewport_width", STARTUP_WINDOW_SIZE.x)
		ProjectSettings.set_setting("display/window/size/viewport_height", STARTUP_WINDOW_SIZE.y)
		ProjectSettings.set_setting("display/window/size/window_width_override", 0)
		ProjectSettings.set_setting("display/window/size/window_height_override", 0)
		ProjectSettings.set_setting("display/window/stretch/mode", "disabled")


## Registers every generated translations/*.translation resource with
## TranslationServer via a project setting — Godot doesn't auto-load
## .translation files just because they exist on disk. Re-apply after
## adding/renaming a translations/*.csv file, so newly imported
## .translation resources get picked up.
static func _setup_translations() -> void:
	var translation_paths: Array = []
	var dir := DirAccess.open(TRANSLATIONS_DIR)
	if dir == null:
		push_warning("[ProjectSetup] '%s' does not exist; no translations registered." % TRANSLATIONS_DIR)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".translation"):
			translation_paths.append("%s/%s" % [TRANSLATIONS_DIR, file_name])
		file_name = dir.get_next()
	dir.list_dir_end()

	translation_paths.sort()
	ProjectSettings.set_setting("internationalization/locale/translations", PackedStringArray(translation_paths))
	ProjectSettings.set_setting("internationalization/locale/fallback", DEFAULT_LOCALE)
