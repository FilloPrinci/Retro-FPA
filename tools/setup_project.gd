extends SceneTree
## One-off bootstrap script for the Retro FPA template.
##
## Configures the Input Map and the Audio Bus Layout using the engine's own
## APIs instead of hand-written project.godot / .tres text, so the generated
## data is guaranteed to be in a format the editor understands.
##
## Usage (run once from the project root, or again any time these lists change):
##   godot --headless -s res://tools/setup_project.gd

const AUDIO_BUS_LAYOUT_PATH := "res://resources/audio/default_bus_layout.tres"
const ADDITIONAL_BUSES := ["Music", "SFX", "Ambient", "UI"]

## The chosen style — Project Settings > General > Retro Style > Visual
## Style (added by addons/retro_visual_style), 0/1/2 = PS1/N64/GameCube —
## picks which VisualStyleProfile's texture-filter fields get baked into
## project.godot as the default sampler settings (see docs/visual_style.md).
## This is a renderer-startup-time default, not something safe to flip at
## runtime; re-run this script after changing it. The rest of the profile
## (fog, color grading, and the actual nearest/linear material filter) is
## applied at runtime instead, via SettingsManager, which reads the same
## Project Setting.
const VISUAL_STYLE_SETTING := "retro_style/visual_style"
const VISUAL_STYLE_PROFILE_PATHS := [
	"res://resources/visual_style/ps1.tres",
	"res://resources/visual_style/n64.tres",
	"res://resources/visual_style/gamecube.tres",
]

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


func _initialize() -> void:
	ProjectSettings.set_setting("application/config/name", "Retro FPA")

	_setup_input_map()
	_setup_audio_buses()
	_setup_rendering_defaults()

	ProjectSettings.save()
	print("[setup_project] Project settings written.")
	quit()


func _setup_input_map() -> void:
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


func _setup_audio_buses() -> void:
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


func _setup_rendering_defaults() -> void:
	# No MSAA, in line with the retro low-fi look; GL Compatibility already
	# disables most modern post-processing by default.
	ProjectSettings.set_setting("rendering/anti_aliasing/quality/msaa_3d", 0)

	var style_index: int = ProjectSettings.get_setting(VISUAL_STYLE_SETTING, 0)
	if style_index < 0 or style_index >= VISUAL_STYLE_PROFILE_PATHS.size():
		push_warning("[setup_project] '%s' is out of range (%d); defaulting to PS1." % [VISUAL_STYLE_SETTING, style_index])
		style_index = 0
	var profile: VisualStyleProfile = load(VISUAL_STYLE_PROFILE_PATHS[style_index])
	if profile == null:
		push_warning("[setup_project] Visual style profile did not load; texture filter defaults left untouched.")
		return

	var filter := 0 if profile.texture_filter_nearest else 1  # 0 = Nearest, 1 = Linear
	ProjectSettings.set_setting("rendering/textures/canvas_textures/default_texture_filter", filter)
	ProjectSettings.set_setting("rendering/textures/default_filters/use_nearest_mipmap_filter", profile.texture_filter_nearest)
	ProjectSettings.set_setting("rendering/textures/default_filters/anisotropic_filtering_level", profile.anisotropic_filtering_level)
	ProjectSettings.set_setting("rendering/textures/default_filters/texture_mipmap_bias", profile.mipmap_bias)
