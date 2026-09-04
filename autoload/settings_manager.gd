extends Node
## Persisted user preferences: audio volumes, mouse sensitivity, language,
## visual style. Autoload singleton, registered right after GameManager so
## volumes are correct before anything plays a sound.

signal settings_changed

const SETTINGS_PATH := "user://settings.cfg"
const SECTION := "settings"

const DEFAULT_MOUSE_SENSITIVITY := 0.15
const DEFAULT_LOCALE := "en"

## UI text size — a straight multiplier over Godot's own default Theme font
## size (16px), applied globally by swapping in a Theme on the game window
## (see _apply_text_scale()) rather than touching every individual Control:
## nothing in this project overrides its own theme, so a window-level Theme
## cascades to all of it, including anything a specific game adds later.
const DEFAULT_TEXT_SCALE := 1.0
const BASE_FONT_SIZE := 16
## Curated, like RESOLUTION_CHOICES — shown as-is (percentages) in the
## Settings menu, no translation needed for the values themselves.
const TEXT_SCALE_CHOICES := [0.5, 0.75, 1.0, 1.25, 1.5]
## Every Control type actually used anywhere under ui/ that has its own
## "font_size" theme property. default_font_size alone (the theme's
## general fallback) isn't consulted by Control.get_theme_font_size()'s
## per-type/per-property lookup unless nothing more specific is found
## anywhere in the whole theme chain, including the engine's own default
## project theme — setting it explicitly per type here is what actually
## reaches already-placed Labels/Buttons/etc. reliably.
const TEXT_SCALE_CONTROL_TYPES := ["Label", "Button", "CheckBox", "OptionButton"]

## Retro rendering look, applied via a VisualStyleProfile — see
## core/visual_style/visual_style_profile.gd and docs/visual_style.md.
## Always read live from the "Visual Style" Project Setting (Project >
## Project Settings > General > Retro Style, added by
## addons/retro_visual_style) — deliberately NOT persisted to
## user://settings.cfg like the fields below, unlike them it has no
## Settings-menu control yet, so there's no player action that should ever
## freeze it to a stale saved value that silently outlives a Project
## Settings change. Wiring up a menu control later means persisting it the
## same way the others are.
enum VisualStyle { PS1, N64, GAMECUBE }
const VISUAL_STYLE_SETTING := "retro_style/visual_style"
const VISUAL_STYLE_PROFILES := {
	VisualStyle.PS1: preload("res://resources/visual_style/ps1.tres"),
	VisualStyle.N64: preload("res://resources/visual_style/n64.tres"),
	VisualStyle.GAMECUBE: preload("res://resources/visual_style/gamecube.tres"),
}

## Window size when nothing forces an internal render resolution (see
## below). A curated list rather than free-form input, shown as-is in the
## Settings menu.
const RESOLUTION_CHOICES := [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
]
const DEFAULT_WINDOW_RESOLUTION := Vector2i(1280, 720)

## Resolution forcing, texture downsampling, and the fog override below:
## unlike Visual Style, these apply the same way regardless of which retro
## look is active — they're a blanket dev choice, not part of a specific
## console's "look" — so they're their own Project Settings (Retro Style
## category, added by addons/retro_visual_style) instead of
## VisualStyleProfile fields. Read directly via ProjectSettings.get_setting(),
## not cached as vars, since they're a fixed dev choice rather than
## something that changes at runtime. See docs/visual_style.md.
## Neither retro_style/force_resolution nor retro_style/forced_resolution
## is read here at all — only tools/setup_project.gd reads those two; see
## is_resolution_forced()'s doc comment for why.
const FORCE_TEXTURE_DOWNSAMPLE_SETTING := "retro_style/force_texture_downsample"
const MAX_TEXTURE_SIZE_SETTING := "retro_style/max_texture_size"
## The fog override settings (retro_style/override_fog and its 5 fog_*
## values) are read inside VisualStyleProfile.apply_to_environment()
## instead of here — that's the single copy shared with the editor
## preview script, which has no SettingsManager to read constants from.
## Same reasoning for bloom (retro_style/glow_*, always on regardless of
## Visual Style) — read inside VisualStyleProfile.apply_glow().

var master_volume: float = 1.0
var music_volume: float = 1.0
var sfx_volume: float = 1.0
var ambient_volume: float = 1.0
var mouse_sensitivity: float = DEFAULT_MOUSE_SENSITIVITY
var text_scale: float = DEFAULT_TEXT_SCALE
var locale: String = DEFAULT_LOCALE
var visual_style: VisualStyle = _get_project_default_visual_style()
var window_resolution: Vector2i = DEFAULT_WINDOW_RESOLUTION
var fullscreen: bool = false

## Set by main.gd once the persistent shell's WorldEnvironment exists —
## autoloads are ready before the main scene, so apply_settings() may run
## once with nothing registered yet; registering re-applies immediately.
var _world_environment: WorldEnvironment = null

## Lazily created the first time _apply_text_scale() runs — see its doc
## comment.
var _ui_theme: Theme = null


func _ready() -> void:
	load_settings()
	# BaseMaterial3D always has an explicit texture_filter (default: linear
	# with mipmaps) — it never "inherits" a project-wide default the way
	# CanvasItem/UI textures do. So the nearest-vs-linear half of the style
	# has to be patched onto materials directly whenever new 3D content
	# shows up, not just set once as a project setting.
	SceneManager.scene_change_finished.connect(func(_path): _apply_material_patches())
	GameManager.player_registered.connect(func(_player): _apply_material_patches())


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		master_volume = config.get_value(SECTION, "master_volume", master_volume)
		music_volume = config.get_value(SECTION, "music_volume", music_volume)
		sfx_volume = config.get_value(SECTION, "sfx_volume", sfx_volume)
		ambient_volume = config.get_value(SECTION, "ambient_volume", ambient_volume)
		mouse_sensitivity = config.get_value(SECTION, "mouse_sensitivity", mouse_sensitivity)
		text_scale = config.get_value(SECTION, "text_scale", text_scale)
		locale = config.get_value(SECTION, "locale", locale)
		window_resolution = config.get_value(SECTION, "window_resolution", window_resolution)
		fullscreen = config.get_value(SECTION, "fullscreen", fullscreen)
	# Not from config: see the doc comment on `visual_style` above. Always
	# re-read fresh, so load_settings() re-syncs it even if something else
	# already changed it this session.
	visual_style = _get_project_default_visual_style()
	apply_settings()
	_apply_window_size()  # once, at startup — see its doc comment


## The game's chosen style, read live from the "retro_style/visual_style"
## Project Setting (see addons/retro_visual_style) — falls back to PS1 if
## it was never set.
func _get_project_default_visual_style() -> VisualStyle:
	return ProjectSettings.get_setting(VISUAL_STYLE_SETTING, VisualStyle.PS1) as VisualStyle


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value(SECTION, "master_volume", master_volume)
	config.set_value(SECTION, "music_volume", music_volume)
	config.set_value(SECTION, "sfx_volume", sfx_volume)
	config.set_value(SECTION, "ambient_volume", ambient_volume)
	config.set_value(SECTION, "mouse_sensitivity", mouse_sensitivity)
	config.set_value(SECTION, "text_scale", text_scale)
	config.set_value(SECTION, "locale", locale)
	config.set_value(SECTION, "window_resolution", window_resolution)
	config.set_value(SECTION, "fullscreen", fullscreen)
	config.save(SETTINGS_PATH)
	apply_settings()


func apply_settings() -> void:
	_apply_bus_volume("Master", master_volume)
	_apply_bus_volume("Music", music_volume)
	_apply_bus_volume("SFX", sfx_volume)
	_apply_bus_volume("Ambient", ambient_volume)
	if TranslationServer.get_locale() != locale:
		TranslationServer.set_locale(locale)
	visual_style = _get_project_default_visual_style()
	_apply_visual_style()
	_apply_fullscreen()
	_apply_text_scale()
	settings_changed.emit()


## The Settings menu's Resolution dropdown — the only place a window
## resize should be forced. apply_settings() deliberately does NOT resize
## the window on every call: it used to, and that meant pressing Back (or
## changing any unrelated setting) silently reverted a manual window
## resize (dragging the border) back to whatever window_resolution was
## last set to. Persists immediately, like every other Settings menu
## control — every change is meant to survive a session regardless of how
## the player leaves the menu (Back, Quit, closing the window, ...), not
## only if they happen to press Back first.
func set_window_resolution(resolution: Vector2i) -> void:
	window_resolution = resolution
	_apply_window_size()
	save_settings()


## The Settings menu's Fullscreen checkbox.
func set_fullscreen(enabled: bool) -> void:
	fullscreen = enabled
	_apply_fullscreen()
	if not enabled:
		_apply_window_size()  # restore the known windowed size when leaving fullscreen
	save_settings()


## Resets every persisted setting to its default and saves immediately —
## the Settings menu's Reset button. Doesn't touch visual_style: that's
## not persisted here at all (see its doc comment above).
func reset_to_defaults() -> void:
	master_volume = 1.0
	music_volume = 1.0
	sfx_volume = 1.0
	ambient_volume = 1.0
	mouse_sensitivity = DEFAULT_MOUSE_SENSITIVITY
	text_scale = DEFAULT_TEXT_SCALE
	locale = DEFAULT_LOCALE
	window_resolution = DEFAULT_WINDOW_RESOLUTION
	fullscreen = false
	_apply_window_size()
	save_settings()


## Whether the game is *actually* running with a forced internal
## resolution right now. Deliberately checks the baked
## display/window/stretch/mode setting instead of the
## retro_style/force_resolution toggle: the toggle is only ever an
## *intent* — tools/setup_project.gd has to be re-run for it to actually
## take effect (see tools/setup_project.gd's doc comment on
## FORCE_RESOLUTION_SETTING) — so checking the toggle directly can tell
## the player "resolution is fixed"
## while the game is, in reality, still running unforced (stale bake).
## Checking the baked setting instead means the Settings menu can never
## lie about this, whatever state the toggle happens to be in.
func is_resolution_forced() -> bool:
	return ProjectSettings.get_setting("display/window/stretch/mode", "disabled") == "viewport"


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


## Sets fullscreen/windowed mode. Deliberately doesn't touch window.size —
## see set_window_resolution()'s doc comment.
func _apply_fullscreen() -> void:
	var window := get_window()
	if window == null:
		return  # No window in this context (e.g. a headless run).
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)


## Rescales every default-themed Control's text at once: assigns a Theme
## overriding default_font_size to the game window. Nothing in this
## project's ui/ sets its own local theme, so Godot's normal theme
## inheritance carries this down to every Label/Button/etc. everywhere,
## live — no per-scene work, and it keeps applying to anything a specific
## game adds later too. Lazily creates the Theme once, then just updates
## its font size on every call (settings_changed can fire often — no
## reason to allocate a new Theme resource every time).
func _apply_text_scale() -> void:
	var window := get_window()
	if window == null:
		return  # No window in this context (e.g. a headless run).
	if _ui_theme == null:
		_ui_theme = Theme.new()
		window.theme = _ui_theme
	var size := roundi(BASE_FONT_SIZE * text_scale)
	_ui_theme.default_font_size = size
	for control_type in TEXT_SCALE_CONTROL_TYPES:
		_ui_theme.set_font_size("font_size", control_type, size)


## Resizes the actual window to window_resolution. Only called at startup
## and from set_window_resolution()/set_fullscreen() — see
## set_window_resolution()'s doc comment for why this isn't part of the
## general apply_settings() path. The forced-resolution pixelation itself
## is separate — see is_resolution_forced()'s doc comment and
## tools/setup_project.gd::_setup_window_stretch().
##
## Skipped entirely when the resolution is forced: the outer window size
## in that case is already correctly established at window-creation time
## by display/window/size/window_width_override/window_height_override
## (baked by tools/setup_project.gd), and window_resolution isn't even
## player-facing then (the Settings menu hides the Resolution dropdown —
## see is_resolution_forced()). Re-touching window.size here was a
## suspected cause of the reported "Settings panel pinned to the
## top-left corner, not centered" bug in exported builds specifically: an
## explicit resize *after* the window/stretch system has already set up
## its centering, even to the same value, appears not to safely
## recompute it — the same class of problem already found with
## Window.content_scale_mode/content_scale_size (see 2ca4ae5).
func _apply_window_size() -> void:
	if is_resolution_forced():
		return
	var window := get_window()
	if window == null or fullscreen:
		return
	window.size = window_resolution


## Applies the runtime-safe half of the chosen VisualStyleProfile (fog,
## ambient light, background, color grading) to the registered
## WorldEnvironment, and (re-)patches the texture filter/downsample half
## onto whatever 3D content currently exists.
func _apply_visual_style() -> void:
	_apply_material_patches()

	if _world_environment == null:
		return
	var profile: VisualStyleProfile = VISUAL_STYLE_PROFILES.get(visual_style)
	if profile == null:
		return

	var env := _world_environment.environment
	if env == null:
		env = Environment.new()
		_world_environment.environment = env

	profile.apply_to_environment(env)
	VisualStyleProfile.apply_glow(env)


## Walks the live scene tree and, on every BaseMaterial3D it finds: sets
## texture_filter, and (if the style forces it) downsamples the albedo
## texture to max_texture_size. Mutates the shared Material/Texture
## Resources in place (not per-instance overrides), so a material used by
## many MeshInstance3Ds only needs to be touched once and stays consistent —
## this only affects the running session, never anything on disk.
## ShaderMaterials are left alone; they don't expose texture_filter this way
## and are out of scope (see docs/visual_style.md).
func _apply_material_patches() -> void:
	var profile: VisualStyleProfile = VISUAL_STYLE_PROFILES.get(visual_style)
	if profile == null or not is_inside_tree():
		return
	var filter := profile.resolve_texture_filter()

	var force_downsample: bool = ProjectSettings.get_setting(FORCE_TEXTURE_DOWNSAMPLE_SETTING, false)
	var max_texture_size: int = -1
	if force_downsample:
		max_texture_size = ProjectSettings.get_setting(MAX_TEXTURE_SIZE_SETTING, 256)
	_patch_material_recursive(get_tree().root, filter, max_texture_size)


func _patch_material_recursive(node: Node, filter: BaseMaterial3D.TextureFilter, max_texture_size: int) -> void:
	var mesh_instance := node as MeshInstance3D
	if mesh_instance and mesh_instance.mesh:
		for i in mesh_instance.mesh.get_surface_count():
			var mat := mesh_instance.get_active_material(i) as BaseMaterial3D
			if mat:
				mat.texture_filter = filter
				if max_texture_size > 0:
					_downsample_if_needed(mat, max_texture_size)
	for child in node.get_children():
		_patch_material_recursive(child, filter, max_texture_size)


## Shrinks mat.albedo_texture in place if either dimension exceeds
## max_size, preserving aspect ratio. Only albedo_texture — this project's
## art direction is single-albedo-texture, no PBR maps (see
## docs/blender_asset_guidelines.md), so that's the only slot that matters
## here. Already-small textures are left untouched (this only ever
## shrinks), so repeated calls across scene changes are cheap no-ops.
func _downsample_if_needed(mat: BaseMaterial3D, max_size: int) -> void:
	var texture := mat.albedo_texture
	if texture == null:
		return
	var size := texture.get_size()
	if size.x <= max_size and size.y <= max_size:
		return

	var image := texture.get_image()
	if image == null:
		return  # e.g. a texture format that can't be read back on this backend.
	if image.is_compressed():
		# Textures import as VRAM-compressed (S3TC/BPTC) by default — see
		# their .import files — so get_image() above hands back a still-
		# compressed Image. Image.resize() silently does nothing on a
		# compressed format, so without decompressing first this whole
		# function was a no-op regardless of max_size. The result becomes a
		# plain uncompressed ImageTexture below either way, which is fine
		# for this project's tiny retro texture budget.
		if image.decompress() != OK:
			return  # Can't decompress this format on this backend — leave as-is.

	var scale := float(max_size) / maxf(size.x, size.y)
	var new_size := Vector2i(maxi(1, roundi(size.x * scale)), maxi(1, roundi(size.y * scale)))
	image.resize(new_size.x, new_size.y, Image.INTERPOLATE_NEAREST)
	mat.albedo_texture = ImageTexture.create_from_image(image)
