// Shared logic for the two RetroSurface shader variants — see
// retro_surface_pixel.gdshader / retro_surface_vertex.gdshader, which
// #include this file and differ only in their `render_mode` line
// (Godot decides per-pixel vs per-vertex lighting at shader-compile
// time, not via a uniform, so "toggling" it means swapping which
// compiled Shader resource is assigned — see
// core/shading/retro_surface_material.gd's per_pixel_lighting export).
// Keeping the actual logic in one #include'd file means the two
// variants can never drift apart.
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
// Every sampler is filter_nearest — this project's whole retro look
// defaults to blocky/pixelated, so that's the sane default here too;
// unlike BaseMaterial3D, a ShaderMaterial's sampler filter is a
// compile-time hint, not something SettingsManager can patch at
// runtime the way it does texture_filter_nearest for BaseMaterial3D
// (see docs/visual_style.md) — a future per-style nearest/linear toggle
// for this shader would need its own pixel/vertex-style variant split.

uniform sampler2D albedo_texture_1 : source_color, hint_default_white, filter_nearest, repeat_enable;
uniform vec4 albedo_color_1 : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec2 tiling_1 = vec2(1.0, 1.0);
uniform vec2 offset_1 = vec2(0.0, 0.0);
// Tiles per second on each axis independently — e.g. (0.1, 0.0) scrolls
// slowly rightward, (0.0, -0.2) scrolls down faster.
uniform vec2 scroll_speed_1 = vec2(0.0, 0.0);
uniform sampler2D emission_texture_1 : source_color, hint_default_black, filter_nearest, repeat_enable;
uniform vec4 emission_color_1 : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform sampler2D normal_texture_1 : hint_normal, filter_nearest, repeat_enable;
uniform float normal_strength_1 : hint_range(0.0, 2.0) = 1.0;
uniform sampler2D smoothness_texture_1 : hint_default_white, filter_nearest, repeat_enable;
uniform float smoothness_1 : hint_range(0.0, 1.0) = 0.5;
uniform sampler2D metallic_texture_1 : hint_default_white, filter_nearest, repeat_enable;
uniform float metallic_1 : hint_range(0.0, 1.0) = 0.0;

uniform sampler2D albedo_texture_2 : source_color, hint_default_white, filter_nearest, repeat_enable;
uniform vec4 albedo_color_2 : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec2 tiling_2 = vec2(1.0, 1.0);
uniform vec2 offset_2 = vec2(0.0, 0.0);
uniform vec2 scroll_speed_2 = vec2(0.0, 0.0);
uniform sampler2D emission_texture_2 : source_color, hint_default_black, filter_nearest, repeat_enable;
uniform vec4 emission_color_2 : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform sampler2D normal_texture_2 : hint_normal, filter_nearest, repeat_enable;
uniform float normal_strength_2 : hint_range(0.0, 2.0) = 1.0;
uniform sampler2D smoothness_texture_2 : hint_default_white, filter_nearest, repeat_enable;
uniform float smoothness_2 : hint_range(0.0, 1.0) = 0.5;
uniform sampler2D metallic_texture_2 : hint_default_white, filter_nearest, repeat_enable;
uniform float metallic_2 : hint_range(0.0, 1.0) = 0.0;

// 0 = layer 1 only, 1 = layer 2 only, in between linearly mixes every
// channel (albedo/emission/normal/smoothness/metallic) between the two.
uniform float layer_blend : hint_range(0.0, 1.0) = 0.0;

uniform bool fresnel_enabled = true;
uniform vec4 fresnel_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float fresnel_power : hint_range(0.1, 8.0) = 3.0;
uniform float fresnel_strength : hint_range(0.0, 4.0) = 1.0;

uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float flash_strength : hint_range(0.0, 1.0) = 0.0;

varying vec2 scroll_offset_1;
varying vec2 scroll_offset_2;

void vertex() {
	scroll_offset_1 = offset_1 + scroll_speed_1 * TIME;
	scroll_offset_2 = offset_2 + scroll_speed_2 * TIME;
}

void fragment() {
	vec2 uv1 = UV * tiling_1 + scroll_offset_1;
	vec2 uv2 = UV * tiling_2 + scroll_offset_2;

	vec4 albedo1 = texture(albedo_texture_1, uv1) * albedo_color_1;
	vec4 albedo2 = texture(albedo_texture_2, uv2) * albedo_color_2;
	vec4 albedo = mix(albedo1, albedo2, layer_blend);

	vec3 emission1 = texture(emission_texture_1, uv1).rgb * emission_color_1.rgb;
	vec3 emission2 = texture(emission_texture_2, uv2).rgb * emission_color_2.rgb;
	vec3 layer_emission = mix(emission1, emission2, layer_blend);

	float smooth1 = texture(smoothness_texture_1, uv1).r * smoothness_1;
	float smooth2 = texture(smoothness_texture_2, uv2).r * smoothness_2;
	float smoothness = mix(smooth1, smooth2, layer_blend);

	float metal1 = texture(metallic_texture_1, uv1).r * metallic_1;
	float metal2 = texture(metallic_texture_2, uv2).r * metallic_2;
	float metallic = mix(metal1, metal2, layer_blend);

	vec3 normal1 = texture(normal_texture_1, uv1).rgb;
	vec3 normal2 = texture(normal_texture_2, uv2).rgb;

	ALBEDO = albedo.rgb;
	ALPHA = albedo.a;
	ROUGHNESS = 1.0 - smoothness;
	METALLIC = metallic;
	NORMAL_MAP = mix(normal1, normal2, layer_blend);
	NORMAL_MAP_DEPTH = mix(normal_strength_1, normal_strength_2, layer_blend);

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
