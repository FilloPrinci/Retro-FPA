// Per-vertex lit variant of RetroSurface — cheaper, blockier lighting
// (computed once per vertex instead of per pixel), closer to how N64-era
// hardware actually looked. The actual shader logic lives in
// retro_surface.gdshaderinc (shared with retro_surface_pixel.gdshader,
// which is identical to this file except for render_mode). Selected via
// RetroSurfaceMaterial.per_pixel_lighting = false — see that script,
// never assign this shader directly.
shader_type spatial;
render_mode vertex_lighting;

#include "res://core/shading/retro_surface.gdshaderinc"
