extends SceneTree

var _failed: bool = false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var state: Node = root.get_node("AppState")
	state.reset_session()
	root.size = Vector2i(1080, 1920)
	var screen: Control = load("res://scenes/capture/capture.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	await process_frame
	_check("Empty capture disables processing and pickup defaults off", screen._process_button.disabled and not state.pickup_first_bar)
	for height: int in [1920, 2400]:
		root.size = Vector2i(1080, height)
		await process_frame
		await process_frame
		_check("Capture panel fits 45 percent at %d" % height, screen._panel.size.y <= height * DesignTokens.CAPTURE_PANEL_FRACTION and screen._panel.size.y >= screen._panel.get_combined_minimum_size().y)
		var preview: TextureRect = screen.get_node("Preview")
		_check("Preview clears top bar at %d" % height, preview.global_position.y >= screen._top.global_position.y + screen._top.size.y + DesignTokens.SPACE_24)
		_check("Preview fits above controls at %d" % height, preview.get_global_rect().end.y <= screen._panel.global_position.y and preview.global_position.x >= 0 and preview.get_global_rect().end.x <= 1080 and preview.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
		_check("Empty caption fits its text at %d" % height, screen._caption.size.y <= screen._caption.get_combined_minimum_size().y + 1.0 and screen._caption.get_rect().end.y < screen._panel.position.y)
		_check("Capture message fits its text at %d" % height, screen._message.size.y <= screen._message.get_combined_minimum_size().y + 1.0 and screen._message.get_rect().end.y < screen._panel.position.y)
		_check("Shutter is 216 px", screen._shutter.size == Vector2.ONE * DesignTokens.SHUTTER_SIZE)
		_check("Thumbnail strip has gesture margins", screen._strip.global_position.x >= DesignTokens.GESTURE_MARGIN)
	var still: FrameSize = FrameSize.new({"width": 4032, "height": 3024})
	var sizes: Array[FrameSize] = [still, FrameSize.new({"width": 1280, "height": 720}), FrameSize.new({"width": 640, "height": 480}), FrameSize.new({"width": 1024, "height": 768})]
	var chosen: FrameSize = CameraService.choose_preview_size(sizes, still)
	_check("Preview uses small supported size with still aspect", chosen.get_width() == 1024 and chosen.get_height() == 768)
	_check("Preview falls back safely when only still exists", CameraService.choose_preview_size([still], still) == still)
	await _check_camera_switch()
	var original: PackedByteArray = FileAccess.get_file_as_bytes("res://fixtures/test.png")
	screen.camera._import_file(ProjectSettings.globalize_path("res://fixtures/test.png"))
	_check("Encoding shows loading and blocks shutter", screen._task >= 0 and screen._spinner.visible and screen._shutter.disabled)
	await _finish(screen)
	_check("Import stores exact PNG bytes", state.pages.size() == 1 and state.pages[0].bytes == original and state.pages[0].mime == "image/png")
	_check("Thumbnail is bounded and caption hidden", maxi(state.pages[0].thumbnail.get_width(), state.pages[0].thumbnail.get_height()) <= 256 and not screen._caption.visible)
	var first_id: String = state.pages[0].id
	screen.camera._import_file(ProjectSettings.globalize_path("res://fixtures/test.png"))
	await _finish(screen)
	var second_id: String = state.pages[1].id
	screen._open_page(0)
	_check("Thumbnail opens modal with larger preview", screen._sheet.is_open and screen._sheet.modal and screen._sheet_preview.texture != null)
	screen._retake_selected()
	screen.camera._import_file(ProjectSettings.globalize_path("res://fixtures/exif6.jpg"))
	await _finish(screen)
	_check("Retake replaces in place and keeps next page", state.pages.size() == 2 and state.pages[0].id == first_id and state.pages[1].id == second_id and state.pages[0].height > state.pages[0].width)
	screen._selected_index = 0
	screen._delete_selected()
	_check("Delete removes and renumbers badge", state.pages.size() == 1 and state.pages[0].id == second_id and screen._strip.get_child(0).get_child(1).text == "1")
	await create_timer(0.25).timeout
	screen.request_back()
	_check("Back with pages asks before discard", screen._confirm.is_open and state.pages.size() == 1)
	screen._confirm.close()
	await create_timer(0.25).timeout
	while state.pages.size() < 30:
		state.pages.append(state.pages[0])
	screen._refresh()
	_check("30-page cap disables shutter with clear message", screen._shutter.disabled and screen._message.text.contains("30-page limit"))
	screen._selected_index = 10
	screen._retake_selected()
	_check("Retake remains available at cap", not screen._shutter.disabled)
	screen.camera.capture_cancelled.emit()
	_check("Cancelled import clears retake without losing pages", screen._retake_index == -1 and not screen._busy and state.pages.size() == 30)
	screen.free()
	state.reset_session()
	print("CAPTURE_BEHAVIOR_COMPLETED")
	quit(1 if _failed else 0)

func _finish(screen: Control) -> void:
	var deadline: int = Time.get_ticks_msec() + 15000
	while screen._task >= 0 and Time.get_ticks_msec() < deadline:
		await process_frame
	_check("Worker completes", screen._task < 0 and not screen._busy and screen._result.is_empty())

func _check(name: String, passed: bool) -> void:
	print("%s: %s" % ["PASS" if passed else "FAIL", name])
	_failed = _failed or not passed

class FakeCamera extends NativeCamera:
	var requests: Array[Dictionary] = []
	var stops: int = 0
	func _ready() -> void:
		pass
	func start(request: FeedRequest) -> void:
		requests.append(request.get_raw_data().duplicate())
	func stop() -> void:
		stops += 1

func _check_camera_switch() -> void:
	var service: CameraService = CameraService.new()
	root.add_child(service)
	var native: FakeCamera = FakeCamera.new()
	service.add_child(native)
	service._camera = native
	service._rotation = 0
	service._sensor_rotation = 0
	service._preview_request = FeedRequest.new().set_width(8).set_height(6).set_rotation(0)
	service._capture_request = FeedRequest.new().set_width(40).set_height(30).set_rotation(0)
	service._request = service._preview_request
	service._active = true
	var results: Array[Vector2i] = []
	service.photo_captured.connect(func(image: Image) -> void: results.append(image.get_size()))
	var preview_image: Image = Image.create(8, 6, false, Image.FORMAT_RGBA8)
	var preview_frame: FrameInfo = FrameInfo.new({"width": 8, "height": 6, "rotation": 0, "buffer": preview_image.get_data()})
	service._update_frame(preview_frame, service._generation)
	service._begin_native_capture()
	_check("Shutter switches to largest request and waits", native.requests.size() == 1 and native.requests[0].width == 40 and service._capture_pending and results.is_empty())
	service._update_frame(preview_frame, service._generation)
	_check("Delayed preview frame cannot become the photo", results.is_empty() and service._capture_pending)
	var still_image: Image = Image.create(40, 30, false, Image.FORMAT_RGBA8)
	var still_frame: FrameInfo = FrameInfo.new({"width": 40, "height": 30, "rotation": 0, "buffer": still_image.get_data()})
	service._update_frame(still_frame, service._generation - 1)
	_check("Stale generation is rejected", results.is_empty())
	service._update_frame(still_frame, service._generation)
	_check("Fresh full-resolution frame captured once", results == [Vector2i(40, 30)] and not service._capture_pending and not service._active)
	service._update_frame(still_frame, service._generation)
	_check("Further frames do not duplicate capture", results.size() == 1)
	service._active = true
	service._request = service._preview_request
	service._update_frame(preview_frame, service._generation)
	service._begin_native_capture()
	var cancellations: Array[bool] = []
	service.capture_cancelled.connect(func() -> void: cancellations.append(true))
	service.stop_preview()
	_check("Pause cancels pending native capture", cancellations.size() == 1 and not service._capture_pending)
	service.free()
