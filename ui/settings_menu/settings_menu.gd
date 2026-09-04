extends Control
## Shared settings screen (volumes, mouse sensitivity, language, window
## resolution/fullscreen), organized into Audio/Video/General tabs. Instanced
## from both MainMenu and PauseMenu — same scene, two entry points, no
## generic navigation stack needed for a screen this shallow.
##
## Every control persists immediately on change (SettingsManager.save_settings(),
## not just apply_settings()) — settings are meant to survive a session
## regardless of how the player leaves the menu (Back, Quit, closing the
## window, ...), not only if they happen to press Back first.

signal closed

@onready var tabs: TabContainer = $Panel/VBox/Tabs
@onready var master_slider: HSlider = $Panel/VBox/Tabs/Audio/MasterRow/Slider
@onready var music_slider: HSlider = $Panel/VBox/Tabs/Audio/MusicRow/Slider
@onready var sfx_slider: HSlider = $Panel/VBox/Tabs/Audio/SfxRow/Slider
@onready var ambient_slider: HSlider = $Panel/VBox/Tabs/Audio/AmbientRow/Slider
@onready var resolution_row: HBoxContainer = $Panel/VBox/Tabs/Video/ResolutionRow
@onready var resolution_option: OptionButton = $Panel/VBox/Tabs/Video/ResolutionRow/OptionButton
@onready var resolution_forced_label: Label = $Panel/VBox/Tabs/Video/ResolutionForcedLabel
@onready var fullscreen_check: CheckBox = $Panel/VBox/Tabs/Video/FullscreenRow/CheckBox
@onready var sensitivity_slider: HSlider = $Panel/VBox/Tabs/General/SensitivityRow/Slider
@onready var text_size_option: OptionButton = $Panel/VBox/Tabs/General/TextSizeRow/OptionButton
@onready var language_option: OptionButton = $Panel/VBox/Tabs/General/LanguageRow/OptionButton
@onready var reset_button: Button = $Panel/VBox/ButtonRow/ResetButton
@onready var back_button: Button = $Panel/VBox/ButtonRow/BackButton

## (locale_code, display_name) pairs. A specific game can call
## set_available_locales() before this menu is first shown to extend this
## list instead of editing this script.
var available_locales: Array[Array] = [
	["en", "English"],
	["it", "Italiano"],
]


func _ready() -> void:
	tabs.set_tab_title(0, tr("UI_SETTINGS_TAB_AUDIO"))
	tabs.set_tab_title(1, tr("UI_SETTINGS_TAB_VIDEO"))
	tabs.set_tab_title(2, tr("UI_SETTINGS_TAB_GENERAL"))

	_populate_language_options()
	_populate_resolution_options()
	_populate_text_size_options()
	_load_from_settings()

	master_slider.value_changed.connect(func(v): SettingsManager.master_volume = v; SettingsManager.save_settings())
	music_slider.value_changed.connect(func(v): SettingsManager.music_volume = v; SettingsManager.save_settings())
	sfx_slider.value_changed.connect(func(v): SettingsManager.sfx_volume = v; SettingsManager.save_settings())
	ambient_slider.value_changed.connect(func(v): SettingsManager.ambient_volume = v; SettingsManager.save_settings())
	sensitivity_slider.value_changed.connect(func(v): SettingsManager.mouse_sensitivity = v; SettingsManager.save_settings())
	text_size_option.item_selected.connect(_on_text_size_selected)
	language_option.item_selected.connect(_on_language_selected)
	resolution_option.item_selected.connect(_on_resolution_selected)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	reset_button.pressed.connect(_on_reset_pressed)
	back_button.pressed.connect(_on_back_pressed)
	visibility_changed.connect(_on_visibility_changed)


## Unlike MainMenu/PauseMenu/etc. (visible from frame 0, visibility only
## ever toggled by GameManager.state), this Control starts hidden
## (visible = false, baked in settings_menu.tscn) and is only ever shown
## on demand by MainMenu/PauseMenu setting .visible directly — it's also
## nested one level deeper (a child of whichever menu opened it, not a
## direct UILayer child). In an exported build specifically (not editor
## Play), a Control that's never been visible since scene creation
## appears able to keep a full-rect anchor resolution cached from
## whatever moment its parent chain last resolved one — which, before the
## window/stretch setup has settled, can be stale — and never
## recomputes it just from being toggled visible later. Force a fresh
## recompute against the actual current viewport every time this becomes
## visible, rather than trusting whatever anchors resolved to earlier.
##
## Also re-syncs every control from SettingsManager's current values: this
## scene is instanced twice (once inside MainMenu, once inside PauseMenu),
## so a setting changed through the *other* instance (e.g. fullscreen
## toggled from the main menu, then checked again from the pause menu
## mid-game) needs to show correctly here too, not whatever this
## instance's controls happened to show at its own _ready().
func _on_visibility_changed() -> void:
	if not visible:
		return
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_load_from_settings()
	_select_current_locale()
	_select_current_resolution()
	_select_current_text_size()


func set_available_locales(locales: Array[Array]) -> void:
	available_locales = locales
	if is_inside_tree():
		_populate_language_options()


func _populate_language_options() -> void:
	language_option.clear()
	for entry in available_locales:
		language_option.add_item(entry[1])
	_select_current_locale()


func _select_current_locale() -> void:
	for i in available_locales.size():
		if available_locales[i][0] == SettingsManager.locale:
			language_option.select(i)
			return


func _populate_resolution_options() -> void:
	resolution_option.clear()
	for resolution in SettingsManager.RESOLUTION_CHOICES:
		resolution_option.add_item("%dx%d" % [resolution.x, resolution.y])
	_select_current_resolution()


func _select_current_resolution() -> void:
	var choices := SettingsManager.RESOLUTION_CHOICES
	for i in choices.size():
		if choices[i] == SettingsManager.window_resolution:
			resolution_option.select(i)
			return


func _populate_text_size_options() -> void:
	text_size_option.clear()
	for text_scale in SettingsManager.TEXT_SCALE_CHOICES:
		text_size_option.add_item("%d%%" % roundi(text_scale * 100.0))
	_select_current_text_size()


func _select_current_text_size() -> void:
	var choices := SettingsManager.TEXT_SCALE_CHOICES
	for i in choices.size():
		if is_equal_approx(choices[i], SettingsManager.text_scale):
			text_size_option.select(i)
			return


func _load_from_settings() -> void:
	master_slider.value = SettingsManager.master_volume
	music_slider.value = SettingsManager.music_volume
	sfx_slider.value = SettingsManager.sfx_volume
	ambient_slider.value = SettingsManager.ambient_volume
	sensitivity_slider.value = SettingsManager.mouse_sensitivity
	fullscreen_check.button_pressed = SettingsManager.fullscreen

	# Project Settings > Retro Style > Force Resolution may force its own
	# internal render resolution (see docs/visual_style.md) — the player's
	# window-resolution choice wouldn't visibly do anything in that case,
	# so swap the dropdown for an explanatory label instead of showing a
	# control that silently does nothing.
	var forced := SettingsManager.is_resolution_forced()
	resolution_row.visible = not forced
	resolution_forced_label.visible = forced


func _on_language_selected(index: int) -> void:
	SettingsManager.locale = available_locales[index][0]
	SettingsManager.save_settings()


func _on_resolution_selected(index: int) -> void:
	SettingsManager.set_window_resolution(SettingsManager.RESOLUTION_CHOICES[index])


func _on_text_size_selected(index: int) -> void:
	SettingsManager.text_scale = SettingsManager.TEXT_SCALE_CHOICES[index]
	SettingsManager.save_settings()


func _on_fullscreen_toggled(enabled: bool) -> void:
	SettingsManager.set_fullscreen(enabled)


func _on_reset_pressed() -> void:
	SettingsManager.reset_to_defaults()
	_load_from_settings()
	_select_current_locale()
	_select_current_resolution()
	_select_current_text_size()


func _on_back_pressed() -> void:
	closed.emit()
