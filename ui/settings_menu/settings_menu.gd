extends Control
## Shared settings screen (volumes, mouse sensitivity, language). Instanced
## from both MainMenu and PauseMenu — same scene, two entry points, no
## generic navigation stack needed for a screen this shallow.

signal closed

@onready var master_slider: HSlider = $Panel/VBox/MasterRow/Slider
@onready var music_slider: HSlider = $Panel/VBox/MusicRow/Slider
@onready var sfx_slider: HSlider = $Panel/VBox/SfxRow/Slider
@onready var ambient_slider: HSlider = $Panel/VBox/AmbientRow/Slider
@onready var sensitivity_slider: HSlider = $Panel/VBox/SensitivityRow/Slider
@onready var language_option: OptionButton = $Panel/VBox/LanguageRow/OptionButton
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
	_load_from_settings()

	master_slider.value_changed.connect(func(v): SettingsManager.master_volume = v; SettingsManager.apply_settings())
	music_slider.value_changed.connect(func(v): SettingsManager.music_volume = v; SettingsManager.apply_settings())
	sfx_slider.value_changed.connect(func(v): SettingsManager.sfx_volume = v; SettingsManager.apply_settings())
	ambient_slider.value_changed.connect(func(v): SettingsManager.ambient_volume = v; SettingsManager.apply_settings())
	sensitivity_slider.value_changed.connect(func(v): SettingsManager.mouse_sensitivity = v)
	language_option.item_selected.connect(_on_language_selected)
	back_button.pressed.connect(_on_back_pressed)


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


func _load_from_settings() -> void:
	master_slider.value = SettingsManager.master_volume
	music_slider.value = SettingsManager.music_volume
	sfx_slider.value = SettingsManager.sfx_volume
	ambient_slider.value = SettingsManager.ambient_volume
	sensitivity_slider.value = SettingsManager.mouse_sensitivity


func _on_language_selected(index: int) -> void:
	SettingsManager.locale = available_locales[index][0]
	SettingsManager.apply_settings()


func _on_back_pressed() -> void:
	SettingsManager.save_settings()
	closed.emit()
