@tool
extends EditorPlugin
## Registers "retro_style/visual_style" as a real Project Setting — Project
## > Project Settings > General > Retro Style — with a PS1/N64/GameCube
## dropdown, instead of requiring editing DEFAULT_VISUAL_STYLE constants in
## settings_manager.gd and tools/setup_project.gd. Both now read this same
## setting; see docs/visual_style.md.
##
## Property hints registered here (add_property_info) aren't persisted —
## they have to be re-registered every editor session, hence this plugin.
## The setting's *value*, once saved, is plain project data in
## project.godot and is read at runtime with an ordinary
## ProjectSettings.get_setting() call — no plugin/editor needed for that.

const SETTING_NAME := "retro_style/visual_style"
## Order matters: index 0/1/2 must match SettingsManager.VisualStyle.
const SETTING_HINT := "PS1,N64,GameCube"


func _enter_tree() -> void:
	if not ProjectSettings.has_setting(SETTING_NAME):
		ProjectSettings.set_setting(SETTING_NAME, 0)
		ProjectSettings.save()
	ProjectSettings.set_initial_value(SETTING_NAME, 0)
	ProjectSettings.set_as_basic(SETTING_NAME, true)
	ProjectSettings.add_property_info({
		"name": SETTING_NAME,
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": SETTING_HINT,
	})
