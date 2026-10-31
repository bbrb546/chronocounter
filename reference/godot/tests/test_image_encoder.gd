extends RefCounted

var cases: Array = []


func check(name: String, passed: bool, detail: String = "") -> void:
	cases.append({"name": name, "passed": passed, "detail": detail})


func run() -> Array:
	var page: PhotoPage = PhotoPage.new()
	check("PhotoPage defaults", page.lines.is_empty() and page.status == PhotoPage.Status.PENDING and page.bytes.is_empty())
	check("Empty image rejected", ImageEncoder.encode_for_upload(null).has("error"))
	check("Unsupported MIME rejected", ImageEncoder.decode(PackedByteArray([1]), "text/plain") == null)
	for fixture: String in ["test.png", "phone_photo.jpg", "exif6.jpg"]:
		var mime: String = "image/png" if fixture.ends_with("png") else "image/jpeg"
		var source: PackedByteArray = FileAccess.get_file_as_bytes("res://fixtures/" + fixture)
		var image: Image = ImageEncoder.decode(source, mime)
		if image == null:
			check(fixture, false, "Could not decode fixture")
			continue
		var orientation: int = ImageEncoder.read_exif_orientation(source)
		var width: int = image.get_width()
		var height: int = image.get_height()
		var result: Dictionary = ImageEncoder.encode_for_upload(image, source, mime)
		image = null
		check(fixture + " upload", not result.has("error") and result.bytes.size() <= ImageEncoder.MAX_UPLOAD_BYTES)
		if result.has("error"):
			continue
		if mime == "image/png":
			check("PNG exact passthrough", result.bytes == source and result.mime == mime)
			check("PNG SHA-256 identical", _sha256(result.bytes) == _sha256(source), _sha256(source))
		else:
			check(fixture + " raw dimensions", width == 4032 and height == 3024, "%dx%d; EXIF %d" % [width, height, orientation])
			check(fixture + " orientation", orientation == (6 if fixture == "exif6.jpg" else 1) and result.width == (height if orientation == 6 else width) and result.height == (width if orientation == 6 else height))
			check(fixture + " stripped EXIF", ImageEncoder.read_exif_orientation(result.bytes) == 1 and result.mime == "image/jpeg")
		var uploaded: Image = ImageEncoder.decode(result.bytes, result.mime)
		check(fixture + " output dimensions", uploaded != null and uploaded.get_width() == result.width and uploaded.get_height() == result.height)
		uploaded = null
		if fixture == "exif6.jpg":
			var debug_path: String = "user://debug/exif6_upload.jpg"
			var directory_error: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://debug"))
			var output: FileAccess = FileAccess.open(debug_path, FileAccess.WRITE) if directory_error == OK else null
			var saved: bool = false
			if output != null:
				output.store_buffer(result.bytes)
				saved = output.get_error() == OK
				output.close()
			check("Portrait debug upload saved", saved, ProjectSettings.globalize_path(debug_path))
	_test_orientation()
	_test_exif()
	var noise: PackedByteArray = PackedByteArray()
	noise.resize(2400 * 1800 * 3)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 12345
	for i: int in range(noise.size()):
		noise[i] = rng.randi() & 255
	var noisy: Image = Image.create_from_data(2400, 1800, false, Image.FORMAT_RGB8, noise)
	noise = PackedByteArray()
	var png: PackedByteArray = noisy.save_png_to_buffer()
	check("Generated PNG exceeds 12 MB", png.size() > 12000000, str(png.size()))
	var encoded: Dictionary = ImageEncoder.encode_for_upload(noisy, png, "image/png")
	noisy = null
	png = PackedByteArray()
	check("Large PNG becomes bounded JPEG", not encoded.has("error") and encoded.mime == "image/jpeg" and encoded.bytes.size() <= ImageEncoder.MAX_UPLOAD_BYTES and mini(encoded.width, encoded.height) >= 1500)
	if not encoded.has("error"):
		var noisy_upload: Image = ImageEncoder.decode(encoded.bytes, encoded.mime)
		check("Large PNG JPEG decodes cleanly", noisy_upload != null and noisy_upload.get_width() == encoded.width and noisy_upload.get_height() == encoded.height, "%d bytes" % encoded.bytes.size())
		noisy_upload = null
	var alpha: Image = Image.create(8, 8, false, Image.FORMAT_RGBA8)
	alpha.fill(Color(0.2, 0.5, 0.8, 0.0))
	var alpha_result: Dictionary = ImageEncoder.encode_for_upload(alpha)
	check("Camera image drops alpha", alpha.get_format() == Image.FORMAT_RGB8 and alpha_result.mime == "image/jpeg")
	var webp: PackedByteArray = alpha.save_webp_to_buffer()
	alpha = null
	var webp_image: Image = ImageEncoder.decode(webp, "image/webp")
	check("WebP decode", webp_image != null)
	var webp_result: Dictionary = ImageEncoder.encode_for_upload(webp_image, webp, "image/webp")
	webp_image = null
	check("WebP uploads as JPEG", not webp_result.has("error") and webp_result.mime == "image/jpeg")
	return cases


func _test_orientation() -> void:
	# Row-major pixel labels for a 3x2 source: [0,1,2;3,4,5].
	var expected: Array = [[0,1,2,3,4,5], [2,1,0,5,4,3], [5,4,3,2,1,0], [3,4,5,0,1,2], [0,3,1,4,2,5], [3,0,4,1,5,2], [5,2,4,1,3,0], [2,5,1,4,0,3]]
	for orientation: int in range(1, 9):
		var image: Image = Image.create(3, 2, false, Image.FORMAT_RGB8)
		for i: int in range(6):
			image.set_pixel(i % 3, i / 3, Color(i / 5.0, 0, 0))
		ImageEncoder.apply_orientation(image, orientation)
		var actual: Array = []
		for y: int in range(image.get_height()):
			for x: int in range(image.get_width()):
				actual.append(roundi(image.get_pixel(x, y).r * 5))
		check("Orientation %d pixels" % orientation, actual == expected[orientation - 1])


func _test_exif() -> void:
	for little: bool in [true, false]:
		for orientation: int in range(1, 9):
			var tiff: PackedByteArray
			if little:
				tiff = PackedByteArray([73,73,42,0,8,0,0,0,1,0,18,1,3,0,1,0,0,0,orientation,0,0,0,0,0,0,0])
			else:
				tiff = PackedByteArray([77,77,0,42,0,0,0,8,0,1,1,18,0,3,0,0,0,1,0,orientation,0,0,0,0,0,0])
			var jpeg: PackedByteArray = PackedByteArray([255,216,255,225,0,34,69,120,105,102,0,0])
			jpeg.append_array(tiff)
			jpeg.append_array(PackedByteArray([255,217]))
			check("EXIF %s %d" % ["II" if little else "MM", orientation], ImageEncoder.read_exif_orientation(jpeg) == orientation)
			var truncated_ok: bool = true
			for size: int in range(jpeg.size() - 2):
				truncated_ok = truncated_ok and ImageEncoder.read_exif_orientation(jpeg.slice(0, size)) == 1
			check("Truncated EXIF %s %d" % [little, orientation], truncated_ok)


func _sha256(bytes: PackedByteArray) -> String:
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()
