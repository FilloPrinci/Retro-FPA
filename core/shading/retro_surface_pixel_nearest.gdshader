// Per-pixel lit, nearest-filtered variant of RetroSurface — the actual
// shader logic lives in retro_surface.gdshaderinc, shared by all four
// variants (this one, _pixel_linear, _vertex_nearest, _vertex_linear).
// Selected via RetroSurfaceMaterial.per_pixel_lighting = true (default)
// and apply_texture_filter(nearest = true) (matching the active
// VisualStyleProfile, applied automatically by SettingsManager — see
// that script, never assign this shader directly).
shader_type spatial;
// Writing ALPHA below (needed for Alpha Over) puts this shader in Godot's
// transparent pass at compile time regardless of the actual alpha value —
// see retro_surface.gdshaderinc's fragment() doc comment for why
// depth_draw_always is required to keep depth-sorting against other
// objects correct even when a given material ends up fully opaque.
render_mode depth_draw_always;

#define RETRO_FILTER_NEAREST
#include "res://core/shading/retro_surface.gdshaderinc"
