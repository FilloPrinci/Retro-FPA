extends Control
## Shared settings screen (volumes, mouse sensitivity, language, window
## resolution/fullscreen). Instanced from both MainMenu and PauseMenu — same
## scene, two entry points, no generic navigation stack needed for a screen
## this shallow.

signal closed

@onready var master_slider: HSlider = $Panel/VBox/ScrollContainer/Rows/MasterRow/Slider
@onready var music_slider: HSlider = $Panel/VBox/ScrollContainer/Rows/MusicRow/Slider
@onready var sfx_slider: HSlider = $Panel/VBox/ScrollContainer/Rows/SfxRow/Slider
@onready var ambient_slider: HSlider = $Panel/VBox/ScrollContainer/Rows/AmbientRow/Slider
@onready var sensitivity_slider: HSlider = $Panel/VBox/ScrollContainer/Rows/SensitivityRow/Slider
@onready var language_option: OptionButton = $Panel/VBox/ScrollContainer/Rows/LanguageRow/OptionButton
@onready var resolution_row: HBoxContainer = $Panel/VBox/ScrollContainer/Rows/ResolutionRow
@onready var resolution_option: OptionButton = $Panel/VBox/ScrollContainer/Rows/ResolutionRow/OptionButton
@onready var resolution_forced_label: Label = $Panel/VBox/ScrollContainer/Rows/ResolutionForcedLabel
@onready var fullscreen_check: CheckBox = $Panel/VBox/ScrollContainer/Rows/FullscreenRow/CheckBox
@onready var back_button: Button = $Panel/VBox/BackButton

## (locale_code, display_name) pairs. A specific game can call
## set_available_locales() before this menu is first shown to extend this
## list instead of editing this script.
var available_locales: Array[Array] = [
	["en", "English"],
	["it", "Italiano"],
]


func _ready() -> void:
	_populate_language_options()
	_populate_resolution_options()
	_load_from_settings()

	master_slider.value_changed.connect(func(v): SettingsManager.master_volume = v; SettingsManager.apply_settings())
	music_slider.value_changed.connect(func(v): SettingsManager.music_volume = v; SettingsManager.apply_settings())
	sfx_slider.value_changed.connect(func(v): SettingsManager.sfx_volume = v; SettingsManager.apply_settings())
	ambient_slider.value_changed.connect(func(v): SettingsManager.ambient_volume = v; SettingsManager.apply_settings())
	sensitivity_slider.value_changed.connect(func(v): SettingsManager.mouse_sensitivity = v)
	language_option.item_selected.connect(_on_language_selected)
	resolution_option.item_selected.connect(_on_resolution_selected)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
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
func _on_visibility_changed() -> void:
	if visible:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


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
	SettingsManager.apply_settings()


func _on_resolution_selected(index: int) -> void:
	SettingsManager.set_window_resolution(SettingsManager.RESOLUTION_CHOICES[index])


func _on_fullscreen_toggled(enabled: bool) -> void:
	SettingsManager.set_fullscreen(enabled)


func _on_back_pressed() -> void:
	SettingsManager.save_settings()
	closed.emit()
