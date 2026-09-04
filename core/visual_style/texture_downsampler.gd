class_name TextureDownsampler
extends RefCounted
## Shared "shrink this texture to max_size if it's bigger" logic for Force
## Texture Downsample — used by SettingsManager (BaseMaterial3D.
## albedo_texture) and RetroSurfaceMaterial (its own several texture
## slots — see apply_texture_downsample() there), so there's one
## implementation instead of two that can drift apart.


## Returns `texture` unchanged if it's null or already within max_size on
## both axes (this only ever shrinks, so repeated calls — every scene
## change re-applies it — are cheap no-ops); otherwise returns a new,
## shrunk ImageTexture (aspect preserved, nearest-neighbor resize,
## deliberately blocky rather than smoothed, to match the retro look).
static func shrink_if_needed(texture: Texture2D, max_size: int) -> Texture2D:
	if texture == null:
		return null
	var size := texture.get_size()
	if size.x <= max_size and size.y <= max_size:
		return texture

	var image := texture.get_image()
	if image == null:
		return texture  # e.g. a texture format that can't be read back on this backend.
	if image.is_compressed():
		# Textures import as VRAM-compressed (S3TC/BPTC) by default, so
		# get_image() above hands back a still-compressed Image and
		# Image.resize() silently does nothing on that — decompress first.
		if image.decompress() != OK:
			return texture  # Can't decompress this format on this backend — leave as-is.

	var scale := float(max_size) / maxf(size.x, size.y)
	var new_size := Vector2i(maxi(1, roundi(size.x * scale)), maxi(1, roundi(size.y * scale)))
	image.resize(new_size.x, new_size.y, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(image)
