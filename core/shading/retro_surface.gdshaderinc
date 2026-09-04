// Shared logic for the four RetroSurface shader variants — see
// retro_surface_{pixel,vertex}_{nearest,linear}.gdshader, which #include
// this file and differ only in their `render_mode` line and whether
// RETRO_FILTER_NEAREST is #define'd before the #include (both decided at
// shader-compile time, not via a uniform — see
// core/shading/retro_surface_material.gd's per_pixel_lighting export and
// apply_texture_filter()). Keeping the actual logic in one #include'd
// file means the four variants can never drift apart.
//
// Two independently configurable texture layers, blended by
// layer_blend, plus an always-available fresnel rim
// (fresnel_enabled/fresnel_color/fresnel_power/fresnel_strength) and a
// separate code-triggered flash on top of it (flash_color/
// flash_strength, driven by core/shading/fresnel_flash.gd, never
// authored directly — see that file's doc comment for why materials in
// this project need a per-instance-unique copy before it's safe to
// animate flash_strength on one).
//
// Every sampler's filter follows the active VisualStyleProfile's
// texture_filter_nearest, same as SettingsManager patches
// BaseMaterial3D.texture_filter live everywhere else — see
// SettingsManager._patch_material_recursive() and
// RetroSurfaceMaterial.apply_texture_filter(). A ShaderMaterial's sampler
// filter is a compile-time hint though, unlike BaseMaterial3D's
// runtime-patchable property, hence the RETRO_FILTER_NEAREST #ifdef
// picking one of two filter_* hints per sampler below instead of a
// uniform.

#ifdef RETRO_FILTER_NEAREST
uniform sampler2D albedo_texture_1 : source_color, hint_default_white, filter_nearest, repeat_enable;
#else
uniform sampler2D albedo_texture_1 : source_color, hint_default_white, filter_linear_mipmap, repeat_enable;
#endif
uniform vec4 albedo_color_1 : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec2 tiling_1 = vec2(1.0, 1.0);
uniform vec2 offset_1 = vec2(0.0, 0.0);
// Tiles per second on each axis independently — e.g. (0.1, 0.0) scrolls
// slowly rightward, (0.0, -0.2) scrolls down faster.
uniform vec2 scroll_speed_1 = vec2(0.0, 0.0);
#ifdef RETRO_FILTER_NEAREST
uniform sampler2D emission_texture_1 : source_color, hint_default_black, filter_nearest, repeat_enable;
uniform sampler2D normal_texture_1 : hint_normal, filter_nearest, repeat_enable;
uniform sampler2D smoothness_texture_1 : hint_default_white, filter_nearest, repeat_enable;
uniform sampler2D metallic_texture_1 : hint_default_white, filter_nearest, repeat_enable;
#else
uniform sampler2D emission_texture_1 : source_color, hint_default_black, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_texture_1 : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D smoothness_texture_1 : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D metallic_texture_1 : hint_default_white, filter_linear_mipmap, repeat_enable;
#endif
uniform vec4 emission_color_1 : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float normal_strength_1 : hint_range(0.0, 2.0) = 1.0;
uniform float smoothness_1 : hint_range(0.0, 1.0) = 0.5;
uniform float metallic_1 : hint_range(0.0, 1.0) = 0.0;

#ifdef RETRO_FILTER_NEAREST
uniform sampler2D albedo_texture_2 : source_color, hint_default_white, filter_nearest, repeat_enable;
uniform sampler2D emission_texture_2 : source_color, hint_default_black, filter_nearest, repeat_enable;
uniform sampler2D normal_texture_2 : hint_normal, filter_nearest, repeat_enable;
uniform sampler2D smoothness_texture_2 : hint_default_white, filter_nearest, repeat_enable;
uniform sampler2D metallic_texture_2 : hint_default_white, filter_nearest, repeat_enable;
#else
uniform sampler2D albedo_texture_2 : source_color, hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D emission_texture_2 : source_color, hint_default_black, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_texture_2 : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D smoothness_texture_2 : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D metallic_texture_2 : hint_default_white, filter_linear_mipmap, repeat_enable;
#endif
uniform vec4 albedo_color_2 : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec2 tiling_2 = vec2(1.0, 1.0);
uniform vec2 offset_2 = vec2(0.0, 0.0);
uniform vec2 scroll_speed_2 = vec2(0.0, 0.0);
uniform vec4 emission_color_2 : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float normal_strength_2 : hint_range(0.0, 2.0) = 1.0;
uniform float smoothness_2 : hint_range(0.0, 1.0) = 0.5;
uniform float metallic_2 : hint_range(0.0, 1.0) = 0.0;

// How layer 2 combines onto layer 1 — same operation applied uniformly
// to every channel (albedo/emission/normal/smoothness/metallic). Alpha
// Over (0) is the odd one out: it additionally folds layer 2's own
// texture alpha into how much shows through, same as compositing a
// transparent decal on top — see the effective_blend computation in
// fragment() below. Every other mode ignores alpha entirely and just
// uses layer_blend on its own as a plain opacity control over the
// operation's full-strength result.
uniform int layer_blend_mode : hint_enum("Alpha Over", "Multiply", "Additive", "Subtract", "Divide") = 0;
// 0 = layer 1 only, 1 = full strength of layer_blend_mode's operation.
uniform float layer_blend : hint_range(0.0, 1.0) = 0.0;

uniform bool fresnel_enabled = true;
uniform vec4 fresnel_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float fresnel_power : hint_range(0.1, 8.0) = 3.0;
uniform float fresnel_strength : hint_range(0.0, 4.0) = 1.0;

uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float flash_strength : hint_range(0.0, 1.0) = 0.0;

varying vec2 scroll_offset_1;
varying vec2 scroll_offset_2;

// layer_blend_mode: 0 Alpha Over, 1 Multiply, 2 Additive, 3 Subtract,
// 4 Divide. `factor` is expected pre-combined with layer 2's alpha by
// the caller when mode == 0 (Alpha Over) — see fragment()'s
// effective_blend. Two overloads (vec3/float) cover every channel this
// shader blends.
vec3 combine_layers(vec3 base, vec3 overlay, float factor, int mode) {
	if (mode == 1) {
		return mix(base, base * overlay, factor);
	} else if (mode == 2) {
		return mix(base, base + overlay, factor);
	} else if (mode == 3) {
		return mix(base, base - overlay, factor);
	} else if (mode == 4) {
		return mix(base, base / max(overlay, vec3(0.0001)), factor);
	}
	return mix(base, overlay, factor); // Alpha Over (mode == 0) and fallback.
}

float combine_layers(float base, float overlay, float factor, int mode) {
	if (mode == 1) {
		return mix(base, base * overlay, factor);
	} else if (mode == 2) {
		return mix(base, base + overlay, factor);
	} else if (mode == 3) {
		return mix(base, base - overlay, factor);
	} else if (mode == 4) {
		return mix(base, base / max(overlay, 0.0001), factor);
	}
	return mix(base, overlay, factor);
}

void vertex() {
	scroll_offset_1 = offset_1 + scroll_speed_1 * TIME;
	scroll_offset_2 = offset_2 + scroll_speed_2 * TIME;
}

void fragment() {
	vec2 uv1 = UV * tiling_1 + scroll_offset_1;
	vec2 uv2 = UV * tiling_2 + scroll_offset_2;

	vec4 albedo1 = texture(albedo_texture_1, uv1) * albedo_color_1;
	vec4 albedo2 = texture(albedo_texture_2, uv2) * albedo_color_2;

	float effective_blend = layer_blend;
	if (layer_blend_mode == 0) {
		effective_blend *= albedo2.a;
	}

	vec3 albedo_rgb = combine_layers(albedo1.rgb, albedo2.rgb, effective_blend, layer_blend_mode);

	float alpha;
	if (layer_blend_mode == 0) {
		// Porter-Duff "over", not a plain mix: a plain mix(albedo1.a,
		// albedo2.a, effective_blend) drags the result below layer 1's
		// own opacity wherever layer 2 is only partially opaque — even
		// over a fully opaque layer 1. This keeps the result exactly as
		// opaque as layer 1 already was wherever layer 1 is opaque,
		// which is what "layer 2 stacked on top of layer 1" (Photoshop-
		// style layers) actually means — layer 2's alpha only controls
		// how much of *layer 2* shows through, never layer 1's own.
		alpha = effective_blend + albedo1.a * (1.0 - effective_blend);
	} else {
		alpha = combine_layers(albedo1.a, albedo2.a, effective_blend, layer_blend_mode);
	}

	vec3 emission1 = texture(emission_texture_1, uv1).rgb * emission_color_1.rgb;
	vec3 emission2 = texture(emission_texture_2, uv2).rgb * emission_color_2.rgb;
	vec3 layer_emission = combine_layers(emission1, emission2, effective_blend, layer_blend_mode);

	float smooth1 = texture(smoothness_texture_1, uv1).r * smoothness_1;
	float smooth2 = texture(smoothness_texture_2, uv2).r * smoothness_2;
	float smoothness = combine_layers(smooth1, smooth2, effective_blend, layer_blend_mode);

	float metal1 = texture(metallic_texture_1, uv1).r * metallic_1;
	float metal2 = texture(metallic_texture_2, uv2).r * metallic_2;
	float metallic = combine_layers(metal1, metal2, effective_blend, layer_blend_mode);

	vec3 normal1 = texture(normal_texture_1, uv1).rgb;
	vec3 normal2 = texture(normal_texture_2, uv2).rgb;

	ALBEDO = albedo_rgb;
	ALPHA = alpha;
	ROUGHNESS = 1.0 - smoothness;
	METALLIC = metallic;
	NORMAL_MAP = combine_layers(normal1, normal2, effective_blend, layer_blend_mode);
	NORMAL_MAP_DEPTH = mix(normal_strength_1, normal_strength_2, effective_blend);

	float fresnel = 0.0;
	if (fresnel_enabled || flash_strength > 0.0) {
		fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), fresnel_power);
	}

	vec3 total_emission = layer_emission;
	if (fresnel_enabled) {
		total_emission += fresnel_color.rgb * fresnel * fresnel_strength;
	}
	if (flash_strength > 0.0) {
		total_emission += flash_color.rgb * fresnel * flash_strength;
	}
	EMISSION = total_emission;
}
