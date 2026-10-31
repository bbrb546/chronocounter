extends SceneTree

class FakeClient extends Node:
	var initials: Array[int] = []
	var calls: int = 0
	func send_page(_bytes: PackedByteArray, _mime: String, initial: int) -> Dictionary:
		initials.append(initial)
		calls += 1
		await get_tree().process_frame
		if calls == 2:
			return {"ok": false, "error": "Try again"}
		var data: DetectionData = DetectionData.from_json({"class": "long rest", "measures_spanned": 4, "measure_number": initial})
		return {"ok": true, "lines": [[data]] if calls == 1 else []}
	func cancel() -> void:
		pass

var server: TCPServer = TCPServer.new()
var peer: StreamPeerTCP
var received: PackedByteArray = PackedByteArray()
var reply_status: int = 200
var hold_response: bool = false
var last_request: String = ""

func _process(_delta: float) -> bool:
	if peer == null and server.is_connection_available():
		peer = server.take_connection()
		received.clear()
	if peer == null:
		return false
	peer.poll()
	if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		peer = null
		return false
	if peer.get_available_bytes() > 0:
		received.append_array(peer.get_data(peer.get_available_bytes())[1])
	var request: String = received.get_string_from_utf8()
	var split: int = request.find("\r\n\r\n")
	if split < 0 or hold_response:
		return false
	var length: int = 0
	for header: String in request.left(split).split("\r\n"):
		if header.to_lower().begins_with("content-length:"):
			length = header.get_slice(":", 1).strip_edges().to_int()
	if received.size() < split + 4 + length:
		return false
	last_request = request
	var body: String = '[[{"class":"bar","x":10,"y":20,"width":2,"height":4,"measure_number":7}]]'
	peer.put_data(("HTTP/1.1 %d Test\r\nContent-Type: application/json\r\nContent-Length: %d\r\nConnection: close\r\n\r\n" % [reply_status, body.to_utf8_buffer().size()] + body).to_utf8_buffer())
	peer.disconnect_from_host()
	peer = null
	return false

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if not condition:
		print("FAIL: " + message)
		quit(1)

func _run() -> void:
	var state: Node = root.get_node("AppState")
	var settings: Node = root.get_node("Settings")
	var api: Node = root.get_node("ApiClient")
	settings.mock_mode = false
	_check(server.listen(0, "127.0.0.1") == OK, "Local HTTP test server starts")
	settings.api_base_url = "http://127.0.0.1:%d///" % server.get_local_port()
	var response: Dictionary = await api.send_page("PHOTO".to_utf8_buffer(), "image/jpeg", 7)
	_check(response.ok and response.lines[0][0].server_measure_number == 7 and last_request.begins_with("POST /count?initial_measure_number=7 ") and last_request.contains("Content-Type: image/jpeg") and last_request.ends_with("PHOTO"), "Raw POST, MIME, URL and JSON conversion")
	response = await api.test_connection()
	_check(response.ok and last_request.begins_with("GET /docs "), "Connection test GET docs")
	for status: int in [400, 413, 415, 503]:
		reply_status = status
		response = await api.send_page(PackedByteArray([1]), "image/png", 2)
		_check(not response.ok and response.status == status and not response.error.is_empty(), "HTTP error status preserved")
	hold_response = true
	create_timer(0.1).timeout.connect(api.cancel)
	response = await api.send_page(PackedByteArray([1]), "image/png", 2)
	_check(not response.ok and response.error.contains("cancelled") and api._requests.is_empty(), "Cancel resumes pending await and frees request")
	if peer != null:
		peer.disconnect_from_host()
		peer = null
	server.stop()
	response = await api.test_connection()
	_check(not response.ok and response.error.contains("Wi-Fi") and response.error.contains("Settings"), "Connection failure copy")
	for i: int in 3:
		state.pages.append(PhotoPage.new())
	var fake: FakeClient = FakeClient.new()
	root.add_child(fake)
	var processor: RefCounted = load("res://logic/PageProcessor.gd").new()
	processor.client = fake
	await processor.start()
	_check(fake.initials == [2, 6], "Chaining uses resolved long-rest end")
	_check(state.pages[0].status == PhotoPage.Status.DONE and state.pages[1].status == PhotoPage.Status.FAILED and state.pages[2].status == PhotoPage.Status.PENDING, "Failure stops at current page")
	await processor.retry()
	_check(fake.initials == [2, 6, 6, 6], "Retry keeps initial; empty pages pass count through")
	_check(state.pages[2].status == PhotoPage.Status.DONE, "Retry continues to finish")
	fake.queue_free()
	state.reset_session()
	settings.mock_mode = true
	for i: int in 4:
		var page: PhotoPage = PhotoPage.new()
		page.bytes = PackedByteArray([1, 2])
		state.pages.append(page)
	processor = load("res://logic/PageProcessor.gd").new()
	await processor.start()
	_check(state.pages[0].bytes == state.pages[3].bytes and state.pages[0].bytes.size() > 2, "Mock images cycle and replace capture")
	for page: PhotoPage in state.pages:
		_check(page.width > 0 and page.height > 0 and page.thumbnail != null and page.status == PhotoPage.Status.DONE, "Paired image metadata and completion")
	state.reset_session()
	var page: PhotoPage = PhotoPage.new()
	state.pages.append(page)
	processor = load("res://logic/PageProcessor.gd").new()
	var stop: Callable = func(_i: int, _n: int) -> void: processor.cancel()
	processor.progress.connect(stop)
	await processor.start()
	processor.progress.disconnect(stop)
	stop = Callable()
	_check(page.lines.is_empty(), "Cancel prevents late detections")
	# Load the actual screen and cancel an in-flight mock timer.
	var scene: Node = load("res://scenes/processing/processing.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	scene.processor.cancel()
	await create_timer(1.6).timeout
	scene.queue_free()
	await process_frame
	print("PROCESSING_BEHAVIOR_COMPLETED")
	quit()
