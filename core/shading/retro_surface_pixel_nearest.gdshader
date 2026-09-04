// Per-pixel lit, nearest-filtered variant of RetroSurface — the actual
// shader logic lives in retro_surface.gdshaderinc, shared by all four
// variants (this one, _pixel_linear, _vertex_nearest, _vertex_linear).
// Selected via RetroSurfaceMaterial.per_pixel_lighting = true (default)
// and apply_texture_filter(nearest = true) (matching the active
// VisualStyleProfile, applied automatically by SettingsManager — see
// that script, never assign this shader directly).
shader_type spatial;

#define RETRO_FILTER_NEAREST
#include "res://core/shading/retro_surface.gdshaderinc"
