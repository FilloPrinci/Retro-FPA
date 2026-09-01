@tool
extends EditorPlugin
## Registers the "Retro Style" Project Settings — Project > Project
## Settings > General > Retro Style — instead of requiring script edits
## for these choices. Every field here is read at runtime by
## SettingsManager (and, for the texture-filter fields, baked into
## project.godot by tools/setup_project.gd); see docs/visual_style.md.
##
## Property hints registered here (add_property_info) aren't persisted —
## they have to be re-registered every editor session, hence this plugin.
## Each setting's *value*, once saved, is plain project data in
## project.godot and is read at runtime with an ordinary
## ProjectSettings.get_setting() call — no plugin/editor needed for that.

## Order matters: index 0/1/2 must match SettingsManager.VisualStyle.
const VISUAL_STYLE_HINT := "PS1,N64,GameCube"

## One entry per registered setting: name, default value, and an optional
## hint (enum or range — Godot infers type/widget from the default
## value's type otherwise: bool becomes a checkbox, Vector2i becomes an
## x/y field, Color becomes a color picker, etc.).
const SETTINGS := [
	{"name": "retro_style/visual_style", "default": 0, "hint": PROPERTY_HINT_ENUM, "hint_string": VISUAL_STYLE_HINT},
	{"name": "retro_style/force_resolution", "default": false},
	{"name": "retro_style/forced_resolution", "default": Vector2i(320, 240)},
	{"name": "retro_style/force_texture_downsample", "default": false},
	{"name": "retro_style/max_texture_size", "default": 256, "hint": PROPERTY_HINT_ENUM, "hint_string": "128:128,256:256,512:512"},
	# Overrides the active VisualStyleProfile's fog fields when on — see
	# docs/visual_style.md.
	{"name": "retro_style/override_fog", "default": false},
	{"name": "retro_style/fog_enabled", "default": true},
	{"name": "retro_style/fog_color", "default": Color(0.5, 0.5, 0.55)},
	{"name": "retro_style/fog_density", "default": 0.02, "hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,0.2,0.001"},
	{"name": "retro_style/fog_depth_begin", "default": 10.0, "hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,200.0,0.5"},
	{"name": "retro_style/fog_depth_end", "default": 60.0, "hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,300.0,0.5"},
]


func _enter_tree() -> void:
	var needs_save := false
	for entry in SETTINGS:
		var setting_name: String = entry["name"]
		var default_value = entry["default"]

		if not ProjectSettings.has_setting(setting_name):
			ProjectSettings.set_setting(setting_name, default_value)
			needs_save = true
		ProjectSettings.set_initial_value(setting_name, default_value)
		ProjectSettings.set_as_basic(setting_name, true)

		if entry.has("hint"):
			ProjectSettings.add_property_info({
				"name": setting_name,
				"type": typeof(default_value),
				"hint": entry["hint"],
				"hint_string": entry["hint_string"],
			})

	# One save() at the end, after every setting has its initial value
	# registered — otherwise a setting saved before set_initial_value() ran
	# for it looks "non-default" and gets written even though it's the
	# default, while the same setting looks properly default (and gets
	# omitted, as intended) on any later save().
	if needs_save:
		ProjectSettings.save()
