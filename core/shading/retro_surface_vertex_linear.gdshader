// Per-vertex lit, linear-filtered variant of RetroSurface — cheaper,
// blockier lighting (computed once per vertex instead of per pixel),
// closer to how N64-era hardware actually looked. The actual shader
// logic lives in retro_surface.gdshaderinc, shared by all four variants
// (this one, _pixel_nearest, _pixel_linear, _vertex_nearest). Selected via
// RetroSurfaceMaterial.per_pixel_lighting = false and
// apply_texture_filter(nearest = false) (matching the active
// VisualStyleProfile, applied automatically by SettingsManager — see
// that script, never assign this shader directly).
shader_type spatial;
// depth_draw_always: writing ALPHA below (needed for Alpha Over) puts this
// shader in Godot's transparent pass at compile time regardless of the
// actual alpha value — see retro_surface.gdshaderinc's fragment() doc
// comment for why this is required to keep depth-sorting against other
// objects correct even when a given material ends up fully opaque.
render_mode vertex_lighting, depth_draw_always;

#include "res://core/shading/retro_surface.gdshaderinc"
