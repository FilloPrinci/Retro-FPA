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
