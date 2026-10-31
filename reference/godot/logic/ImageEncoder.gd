class_name ImageEncoder
extends RefCounted

const MAX_UPLOAD_BYTES: int = 9961472
const MIN_SHORT_SIDE: int = 1500
const SCALE_STEP: float = 0.9
const INITIAL_QUALITY_PERCENT: int = 95
const MIN_QUALITY_PERCENT: int = 70
const QUALITY_STEP_PERCENT: int = 5
const RESIZED_QUALITY_PERCENT: int = 85


# Decode stored pixels; encode_for_upload applies the source EXIF exactly once.
# Process one image at a time and set the caller's Image reference to null after encoding.
static func decode(bytes: PackedByteArray, mime: String) -> Image:
	var start: int = Time.get_ticks_msec()
	var image: Image = Image.new()
	var result: Error = ERR_FILE_UNRECOGNIZED
	if not bytes.is_empty():
		match mime:
			"image/png": result = image.load_png_from_buffer(bytes)
			"image/jpeg": result = image.load_jpg_from_buffer(bytes)
			"image/webp": result = image.load_webp_from_buffer(bytes)
	if OS.is_debug_build():
		print("ImageEncoder decode: %d ms" % (Time.get_ticks_msec() - start))
	return image if result == OK and not image.is_empty() else null


# Consumes/mutates image to avoid a second full-size decoded allocation.
static func encode_for_upload(image: Image, source_bytes: PackedByteArray = PackedByteArray(), source_mime: String = "") -> Dictionary:
	var start: int = Time.get_ticks_msec()
	if image == null or image.is_empty():
		return {"error": "Image is empty or could not be decoded."}
	if source_mime == "image/png" and not source_bytes.is_empty() and source_bytes.size() <= MAX_UPLOAD_BYTES:
		_log(start, 1.0, 1.0, source_bytes.size())
		return {"bytes": source_bytes, "mime": "image/png", "width": image.get_width(), "height": image.get_height()}
	if source_mime == "image/jpeg":
		apply_orientation(image, read_exif_orientation(source_bytes))
	image.convert(Image.FORMAT_RGB8)
	var original_width: int = image.get_width()
	var quality_start: int = INITIAL_QUALITY_PERCENT
	while true:
		for quality_percent: int in range(quality_start, MIN_QUALITY_PERCENT - 1, -QUALITY_STEP_PERCENT):
			var bytes: PackedByteArray = image.save_jpg_to_buffer(quality_percent / 100.0)
			if bytes.is_empty():
				return {"error": "JPEG encoding failed."}
			if bytes.size() <= MAX_UPLOAD_BYTES:
				_log(start, quality_percent / 100.0, float(image.get_width()) / original_width, bytes.size())
				return {"bytes": bytes, "mime": "image/jpeg", "width": image.get_width(), "height": image.get_height()}
		var next_width: int = int(image.get_width() * SCALE_STEP)
		var next_height: int = int(image.get_height() * SCALE_STEP)
		if mini(next_width, next_height) < MIN_SHORT_SIDE:
			return {"error": "Image cannot fit the upload limit without reducing its shorter side below 1500 pixels."}
		image.resize(next_width, next_height, Image.INTERPOLATE_LANCZOS)
		quality_start = RESIZED_QUALITY_PERCENT
	return {"error": "JPEG encoding failed."}


static func _log(start: int, quality: float, scale: float, size: int) -> void:
	if OS.is_debug_build():
		print("ImageEncoder encode: quality %.2f, scale %.4f, %d bytes, %d ms" % [quality, scale, size, Time.get_ticks_msec() - start])


static func apply_orientation(image: Image, orientation: int) -> void:
	if image == null or image.is_empty():
		return
	match orientation:
		2: image.flip_x()
		3: image.rotate_180()
		4: image.flip_y()
		5:
			image.rotate_90(CLOCKWISE)
			image.flip_x()
		6: image.rotate_90(CLOCKWISE)
		7:
			image.rotate_90(CLOCKWISE)
			image.flip_y()
		8: image.rotate_90(COUNTERCLOCKWISE)


static func _u16(bytes: PackedByteArray, offset: int, little: bool) -> int:
	if little:
		return bytes[offset] | (bytes[offset + 1] << 8)
	return (bytes[offset] << 8) | bytes[offset + 1]


static func _u32(bytes: PackedByteArray, offset: int, little: bool) -> int:
	if little:
		return _u16(bytes, offset, true) | (_u16(bytes, offset + 2, true) << 16)
	return (_u16(bytes, offset, false) << 16) | _u16(bytes, offset + 2, false)


static func read_exif_orientation(bytes: PackedByteArray) -> int:
	if bytes.size() < 4 or bytes[0] != 0xff or bytes[1] != 0xd8:
		return 1
	var pos: int = 2
	while pos < bytes.size():
		if bytes[pos] != 0xff:
			return 1
		while pos < bytes.size() and bytes[pos] == 0xff:
			pos += 1
		if pos >= bytes.size():
			return 1
		var marker: int = bytes[pos]
		pos += 1
		if marker == 0xda or marker == 0xd9:
			return 1
		if marker == 0x01 or (marker >= 0xd0 and marker <= 0xd7):
			continue
		if pos + 2 > bytes.size():
			return 1
		var length: int = _u16(bytes, pos, false)
		var end: int = pos + length
		if length < 2 or end > bytes.size():
			return 1
		if marker == 0xe1 and length >= 16 and bytes.slice(pos + 2, pos + 8) == PackedByteArray([69, 120, 105, 102, 0, 0]):
			var base: int = pos + 8
			var little: bool = bytes[base] == 0x49 and bytes[base + 1] == 0x49
			if not little and not (bytes[base] == 0x4d and bytes[base + 1] == 0x4d):
				return 1
			if _u16(bytes, base + 2, little) != 42:
				return 1
			var ifd: int = base + _u32(bytes, base + 4, little)
			if ifd < base + 8 or ifd + 2 > end:
				return 1
			var count: int = _u16(bytes, ifd, little)
			if ifd + 2 + count * 12 > end:
				return 1
			for index: int in range(count):
				var entry: int = ifd + 2 + index * 12
				if _u16(bytes, entry, little) == 0x0112:
					if _u16(bytes, entry + 2, little) != 3 or _u32(bytes, entry + 4, little) != 1:
						return 1
					var orientation: int = _u16(bytes, entry + 8, little)
					return orientation if orientation >= 1 and orientation <= 8 else 1
		pos = end
	return 1
