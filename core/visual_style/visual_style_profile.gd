class_name VisualStyleProfile
extends Resource
## Data-driven definition of a retro rendering look (PS1 / N64 / GameCube).
## One .tres per style under resources/visual_style/. Two different places
## read this, at two different times:
## - tools/setup_project.gd bakes the texture-filter fields into
##   project.godot when a game is set up — these are default sampler
##   settings, meaningful at renderer-startup time, not something safe to
##   flip at runtime.
## - SettingsManager applies the fog/color/ambient fields to a
##   WorldEnvironment at runtime via apply_settings() — Environment
##   properties are safe to change at any time.
## See docs/visual_style.md for the reasoning behind each field.

@export_group("Texture filtering")
## Global default sampler filter: true = nearest (crisp, blocky — PS1),
## false = linear with mipmaps (soft — N64/GameCube). A material's own
## texture_filter override still wins over this project-wide default.
@export var texture_filter_nearest: bool = true
@export var mipmap_bias: float = 0.0
## 0 disables anisotropic filtering entirely — sharp filtering at grazing
## angles reads as distinctly "not retro", so PS1/N64 want this at 0.
@export var anisotropic_filtering_level: int = 0

@export_group("Fog")
@export var fog_enabled: bool = false
@export var fog_color: Color = Color(0.5, 0.5, 0.5)
@export var fog_density: float = 0.01
@export var fog_depth_begin: float = 10.0
@export var fog_depth_end: float = 60.0

@export_group("Ambient light")
@export var ambient_light_color: Color = Color.WHITE
@export var ambient_light_energy: float = 1.0

@export_group("Background")
@export var background_color: Color = Color(0.0, 0.0, 0.0)

@export_group("Color grading")
@export var tonemap_mode: Environment.ToneMapper = Environment.TONE_MAPPER_LINEAR
@export var tonemap_exposure: float = 1.0
@export var adjustment_enabled: bool = false
@export var adjustment_brightness: float = 1.0
@export var adjustment_contrast: float = 1.0
@export var adjustment_saturation: float = 1.0

# Resolution forcing and texture downsampling are NOT here: unlike fog or
# texture filtering, they aren't really part of a specific console's
# "look" — they're a blanket dev choice on top of whichever style is
# active. They live as their own Project Settings (Retro Style category,
# added by addons/retro_visual_style, same as Visual Style itself) and are
# read directly by SettingsManager — see docs/visual_style.md.


## Applies this profile's fog/ambient/background/color-grading fields to
## `env` — honoring the Fog Override Project Settings if Override Fog is
## on (see docs/visual_style.md), same as a runtime apply would. Shared by
## SettingsManager (at runtime) and core/visual_style/visual_style_preview.gd
## (in the editor), so both apply identically with no duplicated logic.
func apply_to_environment(env: Environment) -> void:
	env.background_mode = Environment.BG_COLOR
	env.background_color = background_color

	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ambient_light_color
	env.ambient_light_energy = ambient_light_energy

	if ProjectSettings.get_setting("retro_style/override_fog", false):
		env.fog_enabled = ProjectSettings.get_setting("retro_style/fog_enabled", true)
		env.fog_light_color = ProjectSettings.get_setting("retro_style/fog_color", Color(0.5, 0.5, 0.55))
		env.fog_density = ProjectSettings.get_setting("retro_style/fog_density", 0.02)
		env.fog_depth_begin = ProjectSettings.get_setting("retro_style/fog_depth_begin", 10.0)
		env.fog_depth_end = ProjectSettings.get_setting("retro_style/fog_depth_end", 60.0)
	else:
		env.fog_enabled = fog_enabled
		env.fog_light_color = fog_color
		env.fog_density = fog_density
		env.fog_depth_begin = fog_depth_begin
		env.fog_depth_end = fog_depth_end

	env.tonemap_mode = tonemap_mode
	env.tonemap_exposure = tonemap_exposure

	env.adjustment_enabled = adjustment_enabled
	env.adjustment_brightness = adjustment_brightness
	env.adjustment_contrast = adjustment_contrast
	env.adjustment_saturation = adjustment_saturation


## Applies the Bloom Retro Style Project Settings (retro_style/glow_*) to
## `env`. Static, and deliberately NOT one of this Resource's own @export
## fields: unlike fog/color grading, bloom isn't part of any one console's
## "look" — it's a blanket post-process choice independent of Visual Style,
## same reasoning as Force Texture Downsample/Force Resolution (see
## docs/visual_style.md) — so every VisualStyleProfile gets the same glow
## regardless of which one is active. Applies automatically to whatever's
## bright enough in the scene (anything over glow_hdr_threshold, most
## commonly emissive materials) — nothing per-object to wire up. Shared by
## SettingsManager (at runtime) and core/visual_style/visual_style_preview.gd
## (in the editor), so both apply identically with no duplicated logic.
static func apply_glow(env: Environment) -> void:
	env.glow_enabled = ProjectSettings.get_setting("retro_style/glow_enabled", true)
	env.glow_intensity = ProjectSettings.get_setting("retro_style/glow_intensity", 0.6)
	env.glow_strength = ProjectSettings.get_setting("retro_style/glow_strength", 1.0)
	env.glow_bloom = ProjectSettings.get_setting("retro_style/glow_bloom", 0.0)
	env.glow_hdr_threshold = ProjectSettings.get_setting("retro_style/glow_hdr_threshold", 1.0)
	env.glow_blend_mode = ProjectSettings.get_setting("retro_style/glow_blend_mode", Environment.GLOW_BLEND_MODE_SOFTLIGHT) as Environment.GlowBlendMode


## Resolves this profile's texture_filter_nearest/anisotropic_filtering_level
## into the matching BaseMaterial3D.TextureFilter enum value. Shared by
## SettingsManager and the editor preview script.
func resolve_texture_filter() -> BaseMaterial3D.TextureFilter:
	var use_aniso := anisotropic_filtering_level > 0
	if texture_filter_nearest:
		return BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS_ANISOTROPIC if use_aniso else BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC if use_aniso else BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
