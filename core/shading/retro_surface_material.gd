@tool
class_name RetroSurfaceMaterial
extends ShaderMaterial
## Data-driven, Inspector-editable material for real (non-placeholder) 3D
## art: two independently configurable texture layers — albedo (color +
## texture), tiling & offset, scroll speed (tiles/second on each axis,
## for a scrolling texture), emission (color + mask texture), normal map,
## smoothness (+ mask) and metallic (+ mask) — blended by layer_blend,
## plus an always-available fresnel rim light with a separate
## code-triggered flash on top of it. The actual shader logic lives in
## core/shading/retro_surface.gdshaderinc, shared by the two compiled
## variants this toggles between — see per_pixel_lighting below and that
## file's own doc comment.
##
## Don't animate flash_color/flash_strength directly on a material that
## might be shared by more than one MeshInstance3D (materials in this
## project are shared Resources on purpose — see
## SettingsManager._apply_material_patches()'s doc comment) — use
## core/shading/fresnel_flash.gd instead, a small component that makes a
## specific MeshInstance3D's material locally unique before animating it,
## so a flash never leaks onto every other object sharing the original.
##
## Texture downsample forcing (Project Settings > Retro Style > Force
## Texture Downsample) reaches every texture slot here exactly like it
## does BaseMaterial3D.albedo_texture — see
## SettingsManager._patch_material_recursive(), which calls this class's
## own apply_texture_downsample(). Same for the active VisualStyleProfile's
## nearest/linear texture filter, via apply_texture_filter() — see that
## method.

const _SHADER_PIXEL_NEAREST := preload("res://core/shading/retro_surface_pixel_nearest.gdshader")
const _SHADER_PIXEL_LINEAR := preload("res://core/shading/retro_surface_pixel_linear.gdshader")
const _SHADER_VERTEX_NEAREST := preload("res://core/shading/retro_surface_vertex_nearest.gdshader")
const _SHADER_VERTEX_LINEAR := preload("res://core/shading/retro_surface_vertex_linear.gdshader")

## Order matters — must match layer_blend_mode's hint_enum in
## retro_surface.gdshaderinc (int uniform, no shared source of truth to
## generate it from, same reasoning as this project's other hand-kept-
## in-sync shader/hint pairs).
enum LayerBlendMode { ALPHA_OVER, MULTIPLY, ADDITIVE, SUBTRACT, DIVIDE }

## Godot decides per-pixel vs per-vertex lighting, and a sampler's
## nearest/linear filter, at shader-compile time (render_mode
## vertex_lighting; the RETRO_FILTER_NEAREST #ifdef in
## retro_surface.gdshaderinc) — not via a uniform either way. So both
## "toggles" (this one, and apply_texture_filter() below) really just
## pick which of the four compiled Shader resources is assigned to
## `shader`. All four #include the same retro_surface.gdshaderinc, so
## every other field on this class behaves identically regardless of
## which is active.
@export var per_pixel_lighting: bool = true:
	set(value):
		per_pixel_lighting = value
		_update_shader()

## Not @export: this tracks the active VisualStyleProfile's
## texture_filter_nearest, the same way BaseMaterial3D.texture_filter
## does — set automatically by SettingsManager._patch_material_recursive(),
## not hand-authored per-material, so it never falls out of sync with
## every other material's filter in the same scene. Call
## apply_texture_filter() rather than assigning this directly.
var _nearest_filter: bool = true


## Matches BaseMaterial3D.texture_filter's live patching for
## RetroSurfaceMaterial — called by SettingsManager whenever the active
## VisualStyleProfile's texture_filter_nearest is (re-)applied.
func apply_texture_filter(nearest: bool) -> void:
	_nearest_filter = nearest
	_update_shader()


func _update_shader() -> void:
	if per_pixel_lighting:
		shader = _SHADER_PIXEL_NEAREST if _nearest_filter else _SHADER_PIXEL_LINEAR
	else:
		shader = _SHADER_VERTEX_NEAREST if _nearest_filter else _SHADER_VERTEX_LINEAR


## A property setter isn't guaranteed to run just for its own declared
## default value at construction (GDScript initializes the backing field
## directly in that case) — so `shader` would stay null on a bare
## RetroSurfaceMaterial.new() without this, even though per_pixel_lighting
## itself correctly reads back as true.
func _init() -> void:
	if shader == null:
		_update_shader()

@export_group("Layer 1")
@export var albedo_color_1: Color = Color.WHITE:
	set(value): albedo_color_1 = value; set_shader_parameter("albedo_color_1", value)
@export var albedo_texture_1: Texture2D:
	set(value): albedo_texture_1 = value; set_shader_parameter("albedo_texture_1", value)
@export var tiling_1: Vector2 = Vector2.ONE:
	set(value): tiling_1 = value; set_shader_parameter("tiling_1", value)
@export var offset_1: Vector2 = Vector2.ZERO:
	set(value): offset_1 = value; set_shader_parameter("offset_1", value)
@export var scroll_speed_1: Vector2 = Vector2.ZERO:
	set(value): scroll_speed_1 = value; set_shader_parameter("scroll_speed_1", value)
@export var emission_color_1: Color = Color.BLACK:
	set(value): emission_color_1 = value; set_shader_parameter("emission_color_1", value)
@export var emission_texture_1: Texture2D:
	set(value): emission_texture_1 = value; set_shader_parameter("emission_texture_1", value)
@export var normal_texture_1: Texture2D:
	set(value): normal_texture_1 = value; set_shader_parameter("normal_texture_1", value)
@export_range(0.0, 2.0) var normal_strength_1: float = 1.0:
	set(value): normal_strength_1 = value; set_shader_parameter("normal_strength_1", value)
@export_range(0.0, 1.0) var smoothness_1: float = 0.5:
	set(value): smoothness_1 = value; set_shader_parameter("smoothness_1", value)
@export var smoothness_texture_1: Texture2D:
	set(value): smoothness_texture_1 = value; set_shader_parameter("smoothness_texture_1", value)
@export_range(0.0, 1.0) var metallic_1: float = 0.0:
	set(value): metallic_1 = value; set_shader_parameter("metallic_1", value)
@export var metallic_texture_1: Texture2D:
	set(value): metallic_texture_1 = value; set_shader_parameter("metallic_texture_1", value)

@export_group("Layer 2")
@export var albedo_color_2: Color = Color.WHITE:
	set(value): albedo_color_2 = value; set_shader_parameter("albedo_color_2", value)
@export var albedo_texture_2: Texture2D:
	set(value): albedo_texture_2 = value; set_shader_parameter("albedo_texture_2", value)
@export var tiling_2: Vector2 = Vector2.ONE:
	set(value): tiling_2 = value; set_shader_parameter("tiling_2", value)
@export var offset_2: Vector2 = Vector2.ZERO:
	set(value): offset_2 = value; set_shader_parameter("offset_2", value)
@export var scroll_speed_2: Vector2 = Vector2.ZERO:
	set(value): scroll_speed_2 = value; set_shader_parameter("scroll_speed_2", value)
@export var emission_color_2: Color = Color.BLACK:
	set(value): emission_color_2 = value; set_shader_parameter("emission_color_2", value)
@export var emission_texture_2: Texture2D:
	set(value): emission_texture_2 = value; set_shader_parameter("emission_texture_2", value)
@export var normal_texture_2: Texture2D:
	set(value): normal_texture_2 = value; set_shader_parameter("normal_texture_2", value)
@export_range(0.0, 2.0) var normal_strength_2: float = 1.0:
	set(value): normal_strength_2 = value; set_shader_parameter("normal_strength_2", value)
@export_range(0.0, 1.0) var smoothness_2: float = 0.5:
	set(value): smoothness_2 = value; set_shader_parameter("smoothness_2", value)
@export var smoothness_texture_2: Texture2D:
	set(value): smoothness_texture_2 = value; set_shader_parameter("smoothness_texture_2", value)
@export_range(0.0, 1.0) var metallic_2: float = 0.0:
	set(value): metallic_2 = value; set_shader_parameter("metallic_2", value)
@export var metallic_texture_2: Texture2D:
	set(value): metallic_texture_2 = value; set_shader_parameter("metallic_texture_2", value)

@export_group("Layer Blend")
## How layer 2 combines onto layer 1 — the same operation applies
## uniformly to every channel (albedo/emission/normal/smoothness/
## metallic). Alpha Over also folds layer 2's own texture alpha into how
## much shows through, same as compositing a transparent decal on top;
## every other mode ignores alpha and just uses layer_blend below as a
## plain opacity control over the operation's full-strength result.
@export var layer_blend_mode: LayerBlendMode = LayerBlendMode.ALPHA_OVER:
	set(value): layer_blend_mode = value; set_shader_parameter("layer_blend_mode", value)
## 0 = layer 1 only, 1 = full strength of layer_blend_mode's operation.
@export_range(0.0, 1.0) var layer_blend: float = 0.0:
	set(value): layer_blend = value; set_shader_parameter("layer_blend", value)

@export_group("Fresnel")
## The permanent rim-light look, always available regardless of anything
## flash-related below — authored per-object from the Inspector.
@export var fresnel_enabled: bool = true:
	set(value): fresnel_enabled = value; set_shader_parameter("fresnel_enabled", value)
@export var fresnel_color: Color = Color.WHITE:
	set(value): fresnel_color = value; set_shader_parameter("fresnel_color", value)
@export_range(0.1, 8.0) var fresnel_power: float = 3.0:
	set(value): fresnel_power = value; set_shader_parameter("fresnel_power", value)
@export_range(0.0, 4.0) var fresnel_strength: float = 1.0:
	set(value): fresnel_strength = value; set_shader_parameter("fresnel_strength", value)

## Code-triggered flash, additive on top of the fresnel rim above and
## independent of fresnel_enabled — a hit-flash should still read even on
## an object with the ambient rim turned off. Not @export: meant to be
## animated at runtime (see core/shading/fresnel_flash.gd), not authored
## per-object. flash_strength stays 0 until something actually flashes.
var flash_color: Color = Color.WHITE:
	set(value):
		flash_color = value
		set_shader_parameter("flash_color", value)

var flash_strength: float = 0.0:
	set(value):
		flash_strength = value
		set_shader_parameter("flash_strength", value)


## Shrinks every texture slot on this material to max_size — mirrors
## SettingsManager._downsample_if_needed() for BaseMaterial3D.
## albedo_texture, just reaching every slot this material has instead of
## that one. Called by SettingsManager._patch_material_recursive() when
## Force Texture Downsample is on. Reassigns through this class's own
## setters above, so a shrunk texture reaches the shader immediately.
func apply_texture_downsample(max_size: int) -> void:
	albedo_texture_1 = TextureDownsampler.shrink_if_needed(albedo_texture_1, max_size)
	emission_texture_1 = TextureDownsampler.shrink_if_needed(emission_texture_1, max_size)
	normal_texture_1 = TextureDownsampler.shrink_if_needed(normal_texture_1, max_size)
	smoothness_texture_1 = TextureDownsampler.shrink_if_needed(smoothness_texture_1, max_size)
	metallic_texture_1 = TextureDownsampler.shrink_if_needed(metallic_texture_1, max_size)
	albedo_texture_2 = TextureDownsampler.shrink_if_needed(albedo_texture_2, max_size)
	emission_texture_2 = TextureDownsampler.shrink_if_needed(emission_texture_2, max_size)
	normal_texture_2 = TextureDownsampler.shrink_if_needed(normal_texture_2, max_size)
	smoothness_texture_2 = TextureDownsampler.shrink_if_needed(smoothness_texture_2, max_size)
	metallic_texture_2 = TextureDownsampler.shrink_if_needed(metallic_texture_2, max_size)
