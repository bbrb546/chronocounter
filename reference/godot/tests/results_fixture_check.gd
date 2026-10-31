extends SceneTree

var screen: Node
var state: Node

func _initialize() -> void:
	_check.call_deferred()

func _settle() -> void:
	while screen._task != -1:
		await process_frame
	for frame: int in range(4):
		await process_frame
	await RenderingServer.frame_post_draw

func _check() -> void:
	root.size = Vector2i(1080, 2400)
	state = root.get_node("AppState")
	for index: int in range(3):
		var page: PhotoPage = PhotoPage.new()
		page.bytes = FileAccess.get_file_as_bytes("res://fixtures/mock_page_%d.png" % index)
		page.mime = "image/png"
		var image: Image = Image.new()
		assert(image.load_png_from_buffer(page.bytes) == OK)
		page.width = image.get_width()
		page.height = image.get_height()
		var raw: Array = JSON.parse_string(FileAccess.get_file_as_string("res://fixtures/mock_page_%d.json" % index))
		for raw_line: Array in raw:
			var line: Array = []
			for dict: Dictionary in raw_line:
				line.append(DetectionData.from_json(dict))
			page.lines.append(line)
		page.status = PhotoPage.Status.DONE
		state.pages.append(page)
	NumberingEngine.number_all_pages(state.pages, false)
	screen = load("res://scenes/results/results.tscn").instantiate()
	root.add_child(screen)
	await _settle()
	for index: int in range(3):
		assert(state.current_page_index == index)
		assert(screen.indicator.text == "%d / 3" % (index + 1))
		assert(screen.left_arrow.disabled == (index == 0))
		assert(screen.right_arrow.disabled == (index == 2))
		for marker: DetectionMarker in screen.markers.get_children():
			var d: DetectionData = marker.data
			assert(marker.position == Vector2(d.x - d.w / 2, d.y - d.h / 2))
			assert(marker.size == Vector2(d.w, d.h))
			assert(marker.get_global_transform_with_canvas().is_equal_approx(screen.photo.get_global_transform_with_canvas() * Transform2D(0, marker.position)))
			# Pipeline test.py truncates its box endpoints to integers.
			assert(absf(marker.position.x - int(d.x - d.w / 2)) < 1)
			assert(absf(marker.position.y - int(d.y - d.h / 2)) < 1)
		print("PAGE %d: %d markers aligned; indicator and arrow bounds correct" % [index + 1, screen.markers.get_child_count()])
		root.get_texture().get_image().save_png("/tmp/results-page-%d.png" % (index + 1))
		if index < 2:
			screen.right_arrow.pressed.emit()
			await _settle()
	var memory: Array[int] = []
	for iteration: int in range(12):
		screen.left_arrow.pressed.emit()
		await _settle()
		assert(state.current_page_index == 1 and screen.indicator.text == "2 / 3")
		screen.right_arrow.pressed.emit()
		await _settle()
		assert(state.current_page_index == 2 and screen.indicator.text == "3 / 3")
		memory.append(int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)))
	print("Performance.RENDER_TEXTURE_MEM_USED after each 3 → 2 → 3 cycle: ", memory)
	assert(memory[0] > 0, "Requires a real renderer; headless texture memory is not evidence")
	assert(memory.min() == memory.max(), "Texture memory grew between cycles")
	screen.labels.button_pressed = true
	await _settle()
	for marker: DetectionMarker in screen.markers.get_children():
		assert(marker.show_labels)
	root.get_texture().get_image().save_png("/tmp/results-labels-on.png")
	screen.labels.button_pressed = false
	await _settle()
	for marker: DetectionMarker in screen.markers.get_children():
		assert(not marker.show_labels)
	print("Labels toggle: all current-page markers show/hide class and m#")
	# Encode the very same upright mock page as JPEG to isolate format handling.
	var png: Image = Image.new()
	assert(png.load_png_from_buffer(state.pages[2].bytes) == OK)
	var jpeg: PhotoPage = PhotoPage.new()
	jpeg.bytes = png.save_jpg_to_buffer(0.95)
	jpeg.mime = "image/jpeg"
	jpeg.lines = state.pages[2].lines
	jpeg.status = PhotoPage.Status.DONE
	state.pages.append(jpeg)
	screen.show_page(3)
	await _settle()
	var decoded: Image = screen.photo.texture.get_image()
	assert(decoded.get_size() == png.get_size())
	var error: float = 0.0
	var count: int = 0
	for y: int in range(0, png.get_height(), 13):
		for x: int in range(0, png.get_width(), 13):
			var a: Color = png.get_pixel(x, y)
			var b: Color = decoded.get_pixel(x, y)
			error += absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)
			count += 3
	assert(error / count < 0.02)
	assert(screen.photo.position == Vector2.ZERO and not screen.photo.centered)
	assert(screen.photo.rotation == 0 and screen.photo.scale == Vector2.ONE)
	root.get_texture().get_image().save_png("/tmp/results-jpeg.png")
	print("PNG/JPEG: same upright fixture, unchanged dimensions/origin, mean channel error = ", error / count)
	screen.free()
	state.reset_session()
	print("RESULTS_FIXTURE_CHECK_COMPLETED")
	quit()
