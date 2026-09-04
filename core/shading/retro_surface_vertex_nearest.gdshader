// Per-vertex lit, nearest-filtered variant of RetroSurface — cheaper,
// blockier lighting (computed once per vertex instead of per pixel),
// closer to how N64-era hardware actually looked. The actual shader
// logic lives in retro_surface.gdshaderinc, shared by all four variants
// (this one, _pixel_nearest, _pixel_linear, _vertex_linear). Selected via
// RetroSurfaceMaterial.per_pixel_lighting = false and
// apply_texture_filter(nearest = true) (matching the active
// VisualStyleProfile, applied automatically by SettingsManager — see
// that script, never assign this shader directly).
shader_type spatial;
render_mode vertex_lighting;

#define RETRO_FILTER_NEAREST
#include "res://core/shading/retro_surface.gdshaderinc"
