extends SceneTree
## Converts the Blender-baked cabinet AO PNGs (16-bit RGB) into single-channel
## BC4 textures with mipmaps, saved beside them as .res. At runtime this replaces
## decoding each PNG into an uncompressed L8 texture: 11.2 MB of video memory
## becomes about 3.4 MB, and startup skips the decode and mip generation.
## The back map matches the 1024 px resolution of every other rear texture.
## Usage: godot --headless --path . --script scripts/prepare-cabinet-ao.gd
const FOLDER := "res://build/crt-model/ao"
const MAPS := {"tvfront_ao": 2048, "tvback_ao": 1024}

func _initialize() -> void:
	var failed := false
	for name in MAPS:
		var source := ProjectSettings.globalize_path(FOLDER.path_join(name + ".png"))
		var image := Image.load_from_file(source)
		if image == null:
			push_error("Missing AO bake: " + source); failed = true; continue
		image.convert(Image.FORMAT_R8)
		var size: int = MAPS[name]
		if image.get_width() != size: image.resize(size, size, Image.INTERPOLATE_LANCZOS)
		image.generate_mipmaps()
		var error := image.compress_from_channels(Image.COMPRESS_S3TC, Image.USED_CHANNELS_R)
		if error != OK or image.get_format() != Image.FORMAT_RGTC_R:
			push_error("BC4 compression failed for %s: %s" % [name, error_string(error)]); failed = true; continue
		var texture := ImageTexture.create_from_image(image)
		var target := FOLDER.path_join(name + ".res")
		error = ResourceSaver.save(texture, target, ResourceSaver.FLAG_COMPRESS)
		if error != OK:
			push_error("Could not save " + target); failed = true; continue
		print("%s: %dx%d BC4 with mipmaps -> %s (%d bytes)" % [name, size, size, target, FileAccess.get_file_as_bytes(target).size()])
	quit(1 if failed else 0)
