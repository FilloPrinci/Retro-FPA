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
	# Crisp, non-blurred 2D UI (PS1/N64-style pixel art). 0 = Nearest.
	ProjectSettings.set_setting("rendering/textures/canvas_textures/default_texture_filter", 0)
	# No MSAA, in line with the retro low-fi look; GL Compatibility already
	# disables most modern post-processing by default.
	ProjectSettings.set_setting("rendering/anti_aliasing/quality/msaa_3d", 0)
