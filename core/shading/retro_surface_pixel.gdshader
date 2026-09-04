// Per-pixel lit variant of RetroSurface — the actual shader logic lives
// in retro_surface.gdshaderinc (shared with retro_surface_vertex.gdshader,
// which is identical to this file except for render_mode). Selected via
// RetroSurfaceMaterial.per_pixel_lighting = true (the default) — see that
// script, never assign this shader directly.
shader_type spatial;

#include "res://core/shading/retro_surface.gdshaderinc"
