extends SceneTree

func _initialize() -> void:
	_check.call_deferred()

func _check() -> void:
	var state: Node = root.get_node("AppState")
	var image: Image = Image.create(3024, 4032, false, Image.FORMAT_RGB8)
	image.fill(Color.WHITE)
	var page: PhotoPage = PhotoPage.new()
	page.bytes = image.save_png_to_buffer()
	page.mime = "image/png"
	page.status = PhotoPage.Status.DONE
	var detection: DetectionData = DetectionData.new()
	detection.x = 400
	detection.y = 500
	detection.w = 10
	detection.h = 100
	detection.cls = "bar"
	page.lines = [[detection]]
	var empty: PhotoPage = PhotoPage.new()
	empty.bytes = page.bytes
	empty.mime = page.mime
	state.pages.assign([page, empty])
	state.pickup_first_bar = true
	NumberingEngine.number_all_pages(state.pages, true)
	var screen: Node = load("res://scenes/results/results.tscn").instantiate()
	root.add_child(screen)
	while screen._task != -1:
		await process_frame
	assert(screen.photo.texture != null)
	assert(screen.markers.get_child_count() == 1)
	var overlay: LineNumberOverlay = screen.line_numbers
	assert(overlay.get_index() > screen.photo.get_index())
	assert(overlay.get_index() < screen.markers.get_index())
	assert(overlay._labels.size() == 1 and overlay._labels[0].text == "0")
	assert(overlay._labels[0].position.x == 15.0 and overlay._labels[0].font_size == 70)
	var rest: DetectionData = DetectionData.from_json({"class": "long rest", "y": 700, "height": 20, "measures_spanned": 4})
	var next: DetectionData = DetectionData.from_json({"class": "bar", "y": 900, "height": 200})
	page.lines = [[], [detection, rest], [], [next]]
	NumberingEngine.number_all_pages(state.pages, true)
	state.numbering_changed.emit()
	assert(overlay._labels.size() == 2 and overlay._labels[1].text == "5")
	assert(overlay._labels[0].font_size == 42 and overlay._labels[1].font_size == 72)
	var baseline_offset: float = (overlay._font.get_ascent(42) - overlay._font.get_descent(42)) / 2.0
	assert(is_equal_approx(overlay._labels[0].position.y - baseline_offset, 600.0))
	rest.apply_length(8)
	NumberingEngine.number_all_pages(state.pages, true)
	state.numbering_changed.emit()
	assert(overlay._labels[1].text == "9")
	page.lines[1].remove_at(0)
	NumberingEngine.number_all_pages(state.pages, true)
	state.numbering_changed.emit()
	assert(overlay._labels[0].text == "1" and overlay._labels[0].font_size == 20)
	assert(screen.left_arrow.disabled and not screen.right_arrow.disabled)
	assert(screen.camera.zoom.x < screen.get_viewport_rect().size.x / 3024.0)
	var origin: Vector2 = screen.get_viewport_rect().size / 2.0 - screen.camera.position * screen.camera.zoom
	assert(origin.x >= DesignTokens.SIDE_MARGIN - 0.01)
	var top_gap: float = origin.y - (screen.chrome.global_position.y + DesignTokens.HIT_SIZE)
	var bottom_gap: float = screen._bottom.global_position.y - (origin.y + 4032.0 * screen.camera.zoom.y)
	assert(is_equal_approx(top_gap, bottom_gap))
	assert(top_gap >= DesignTokens.SPACE_24 - 0.01)
	screen.labels.button_pressed = true
	assert(screen.markers.get_child(0).show_labels)
	screen.show_page(1)
	assert(overlay._labels.is_empty())
	assert(screen.photo.texture == null)
	assert(screen.markers.get_child_count() == 0)
	assert(state.current_page_index == 1 and screen.right_arrow.disabled)
	while screen._task != -1:
		await process_frame
	assert(screen.message.visible)
	screen.show_page(0)
	screen.show_page(1)
	while screen._task != -1:
		await process_frame
	assert(screen.markers.get_child_count() == 0 and screen.photo.texture != null)
	screen.free()
	state.reset_session()
	print("RESULTS_BEHAVIOR_COMPLETED")
	quit()
