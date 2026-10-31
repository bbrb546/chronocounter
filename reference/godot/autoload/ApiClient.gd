extends Node

const TIMEOUT_SECONDS: float = 120.0
const MOCK_DELAY: float = 1.5
const CLASSES: Array[String] = ["bar", "repeat bar", "double bar", "long rest", "long rest bottom"]
var _requests: Array[HTTPRequest] = []
var _generation: int = 0
var _mock_index: int = 0

func send_page(bytes: PackedByteArray, mime: String, initial: int) -> Dictionary:
	if Settings.mock_mode:
		var index: int = _mock_index
		_mock_index += 1
		return await send_mock_page(index)
	var url: String = base_url() + "/count?initial_measure_number=" + str(initial)
	return await _request(url, HTTPClient.METHOD_POST, bytes, PackedStringArray(["Content-Type: " + mime]), true)

func base_url() -> String:
	return Settings.api_base_url.strip_edges().rstrip("/")

func test_connection(url: String = "", mock: bool = Settings.mock_mode) -> Dictionary:
	if mock:
		return {"ok": true, "lines": [], "status": 200, "error": ""}
	return await _request((base_url() if url.is_empty() else url.strip_edges().rstrip("/")) + "/docs", HTTPClient.METHOD_GET, PackedByteArray(), PackedStringArray(), false)

func cancel() -> void:
	_generation += 1
	for request: HTTPRequest in _requests.duplicate():
		request.cancel_request()
		request.request_completed.emit(HTTPRequest.RESULT_REQUEST_FAILED, 0, PackedStringArray(), PackedByteArray())

func _request(url: String, method: HTTPClient.Method, bytes: PackedByteArray, headers: PackedStringArray, parse: bool) -> Dictionary:
	var generation: int = _generation
	var request: HTTPRequest = HTTPRequest.new()
	request.timeout = TIMEOUT_SECONDS
	add_child(request)
	_requests.append(request)
	var error: Error = request.request_raw(url, headers, method, bytes)
	if error != OK:
		_requests.erase(request)
		request.queue_free()
		return failure("Can't reach the server. Check your Wi-Fi and server address in Settings.")
	var response: Array = await request.request_completed
	_requests.erase(request)
	request.queue_free()
	if generation != _generation:
		return failure("Request cancelled.")
	var result: int = response[0]
	var status: int = response[1]
	if result == HTTPRequest.RESULT_TIMEOUT:
		return failure("The server took too long to respond. Please try again.", status)
	if result != HTTPRequest.RESULT_SUCCESS:
		return failure("Can't reach the server. Check your Wi-Fi and server address in Settings.", status)
	if status != 200:
		return failure(status_message(status), status)
	return parse_detections(response[3].get_string_from_utf8()) if parse else {"ok": true, "lines": [], "status": status, "error": ""}

func status_message(status: int) -> String:
	match status:
		400: return "The server couldn't read this photo. Try retaking it."
		413: return "This photo is too large. The server accepts images up to 10 MB."
		415: return "The server doesn't support this image format. Use JPEG, PNG or WebP."
		503: return "The server is not ready to process photos. Ask the person running it to check its setup."
	return "The server returned an error (%d). Please try again." % status

func failure(message: String, status: int = 0) -> Dictionary:
	return {"ok": false, "lines": [], "status": status, "error": message}

func _numeric(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

func parse_detections(text: String) -> Dictionary:
	var json: JSON = JSON.new()
	if json.parse(text) != OK or not json.data is Array:
		return failure("The server sent an unreadable response. Please try again.", 200)
	var lines: Array = []
	for raw_line: Variant in json.data:
		if not raw_line is Array:
			return failure("The server sent an unreadable response. Please try again.", 200)
		var line: Array[DetectionData] = []
		for item: Variant in raw_line:
			if not item is Dictionary or not item.get("class") is String or not item.get("class") in CLASSES:
				return failure("The server sent an unreadable response. Please try again.", 200)
			for key: String in ["x", "y", "width", "height", "measure_number"]:
				if not item.has(key) or not _numeric(item[key]):
					return failure("The server sent an unreadable response. Please try again.", 200)
			if item.width <= 0 or item.height <= 0 or float(item.measure_number) != floor(float(item.measure_number)):
				return failure("The server sent an unreadable response. Please try again.", 200)
			if item.has("measures_spanned_confident") and not item.measures_spanned_confident is bool:
				return failure("The server sent an unreadable response. Please try again.", 200)
			if item.has("measures_spanned") and (not _numeric(item.measures_spanned) or float(item.measures_spanned) != floor(float(item.measures_spanned)) or item.measures_spanned < 1 or item.measures_spanned > 999):
				return failure("The server sent an unreadable response. Please try again.", 200)
			line.append(DetectionData.from_json(item))
		lines.append(line)
	return {"ok": true, "lines": lines, "status": 200, "error": ""}

func fixture_pairs() -> Array[String]:
	var pairs: Array[String] = []
	for file: String in DirAccess.get_files_at("res://fixtures"):
		if file.begins_with("mock_page_") and file.ends_with(".json"):
			var stem: String = "res://fixtures/" + file.trim_suffix(".json")
			if FileAccess.file_exists(stem + ".png") or FileAccess.file_exists(stem + ".jpg"):
				pairs.append(stem)
	pairs.sort_custom(func(a: String, b: String) -> bool: return a.get_file().trim_prefix("mock_page_").to_int() < b.get_file().trim_prefix("mock_page_").to_int())
	return pairs

func replace_mock_image(page: PhotoPage, index: int) -> Dictionary:
	var pairs: Array[String] = fixture_pairs()
	if pairs.is_empty():
		return failure("No mock image and detection pairs were found.")
	var stem: String = pairs[index % pairs.size()]
	var path: String = stem + (".png" if FileAccess.file_exists(stem + ".png") else ".jpg")
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var mime: String = "image/png" if path.ends_with(".png") else "image/jpeg"
	var image: Image = ImageEncoder.decode(bytes, mime)
	if image == null:
		return failure("Couldn't open the sample photo.")
	page.bytes = bytes
	page.mime = mime
	page.width = image.get_width()
	page.height = image.get_height()
	var scale: float = minf(1.0, float(DesignTokens.THUMBNAIL_LONG_SIDE) / maxi(page.width, page.height))
	image.resize(maxi(1, roundi(page.width * scale)), maxi(1, roundi(page.height * scale)), Image.INTERPOLATE_BILINEAR)
	page.thumbnail = ImageTexture.create_from_image(image)
	return {"ok": true}

func send_mock_page(index: int) -> Dictionary:
	var generation: int = _generation
	await get_tree().create_timer(MOCK_DELAY).timeout
	if generation != _generation:
		return failure("Request cancelled.")
	var pairs: Array[String] = fixture_pairs()
	if pairs.is_empty():
		return failure("No mock image and detection pairs were found.")
	return parse_detections(FileAccess.get_file_as_string(pairs[index % pairs.size()] + ".json"))
