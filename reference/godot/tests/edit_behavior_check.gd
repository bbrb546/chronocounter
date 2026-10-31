extends SceneTree

func _initialize() -> void:
	_check.call_deferred()

func _check() -> void:
	var state: Node = root.get_node("AppState")
	var rest: DetectionData = DetectionData.from_json({"class": "long rest", "x": 400, "y": 1700, "width": 100, "height": 40, "measures_spanned": 4, "measures_spanned_confident": false})
	var bar: DetectionData = DetectionData.from_json({"class": "bar", "x": 600, "y": 500, "width": 10, "height": 100})
	var page: PhotoPage = PhotoPage.new()
	page.status = PhotoPage.Status.DONE
	page.lines = [[bar], [rest]]
	var later: PhotoPage = PhotoPage.new()
	var later_bar: DetectionData = DetectionData.from_json({"class": "bar"})
	later.lines = [[later_bar]]
	state.pages.assign([page, later])
	NumberingEngine.number_all_pages(state.pages, false)
	var screen: Node = load("res://scenes/results/results.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	var marker: DetectionMarker = screen.markers.get_child(1)
	screen.snackbar.show_message("Settings saved.")
	screen._on_marker_tapped(marker)
	assert(not screen.snackbar.visible)
	var popup: Control = screen.edit_popup
	assert(popup.is_open and not popup.modal and marker.selected)
	assert(popup.warning.visible and screen.check_pill.visible)
	await process_frame
	var selected_bottom: Vector2 = screen.markers.get_global_transform_with_canvas() * Vector2(rest.x, rest.y + rest.h / 2.0)
	assert(selected_bottom.y <= popup.top_edge() - DesignTokens.SPACE_48 + 1.0)
	for invalid: String in ["", "0", "1000", "1.5", "-1", "abc", " 2", "+2"]:
		popup.field.text = invalid
		popup._apply()
		assert(popup.is_open and popup.error.visible and rest.measures_spanned == 4)
	popup.field.text = "4"
	popup._apply()
	assert(rest.edited and not rest.needs_check and not screen.check_pill.visible)
	assert(marker.badge_text() == "×4")
	assert(not popup.is_open)
	var before: int = later_bar.measure_number
	popup.show_detection(marker)
	popup.field.text = "999"
	popup._apply()
	assert(later_bar.measure_number == before + 995)
	screen._delete_detection(rest)
	assert(page.lines.size() == 1 and screen.markers.get_child_count() == 1)
	screen._undo_delete()
	assert(page.lines.size() == 2 and page.lines[1][0] == rest)
	assert(screen.markers.get_child_count() == 2 and later_bar.measure_number == before + 995)
	# A detection in a surviving line returns to its exact slot.
	page.lines = [[bar, rest]]
	screen._delete_detection(bar)
	assert(page.lines.size() == 1 and page.lines[0][0] == rest)
	screen._undo_delete()
	assert(page.lines[0][0] == bar and page.lines[0][1] == rest)
	page.lines = [[bar], [rest]]
	# New delete replaces the pending undo, including deletion of the last line.
	screen._delete_detection(rest)
	screen._delete_detection(bar)
	assert(page.lines.is_empty())
	screen._undo_delete()
	assert(page.lines.size() == 1 and page.lines[0][0] == bar)
	# Undo expiry is enforced even if the action is invoked directly.
	screen._delete_detection(bar)
	screen._undo_deadline = Time.get_ticks_msec() - 1
	screen._undo_delete()
	assert(page.lines.is_empty())
	while screen._task != -1:
		await process_frame
	screen.free()
	await _verify_scenarios(state)
	state.reset_session()
	print("EDIT_BEHAVIOR_COMPLETED")
	quit()

func _make_page(types: Array) -> PhotoPage:
	var page: PhotoPage = PhotoPage.new()
	page.status = PhotoPage.Status.DONE
	var line: Array = []
	for index: int in range(types.size()):
		line.append(DetectionData.from_json({"class": types[index], "x": 300 + index * 250, "y": 1600, "width": 6 if types[index] == "bar" else 100, "height": 100, "measures_spanned": 4}))
	page.lines = [line]
	return page

func _snapshot(state: Node) -> Array:
	var result: Array = []
	for page: PhotoPage in state.pages:
		var rows: Array = []
		for line: Array in page.lines:
			var numbers: Array = []
			for data: DetectionData in line:
				numbers.append([data.measure_number, data.measures_spanned])
			rows.append(numbers)
		result.append([page.initial_measure_number, rows, NumberingEngine.line_start_labels(page.lines)])
	return result

func _initials(state: Node) -> Array:
	var values: Array = []
	for page: PhotoPage in state.pages:
		values.append(page.initial_measure_number)
	return values

func _verify_scenarios(state: Node) -> void:
	var image: Image = Image.create(1200, 2000, false, Image.FORMAT_RGB8)
	image.fill(Color.WHITE)
	var encoded: PackedByteArray = image.save_png_to_buffer()
	for scenario: String in ["length 6", "interior bar", "first pickup bar", "first ordinary bar", "first bar reveals rest", "later bar reveals rest", "later rest reveals bar", "page-ending rest", "flagged rest"]:
		var first: PhotoPage = _make_page(["bar", "bar", "bar", "bar"])
		var second: PhotoPage = _make_page(["bar", "bar", "bar"])
		var third: PhotoPage = _make_page(["bar", "bar"])
		var page_index: int = 0
		var detection_index: int = 0
		state.pickup_first_bar = scenario == "first pickup bar"
		match scenario:
			"length 6", "page-ending rest", "flagged rest":
				first = _make_page(["bar", "long rest", "bar", "bar"] if scenario == "length 6" else ["bar", "bar", "long rest"])
				detection_index = 1 if scenario == "length 6" else 2
			"interior bar": detection_index = 1
			"first bar reveals rest": first = _make_page(["bar", "long rest", "bar"])
			"later bar reveals rest":
				second = _make_page(["bar", "long rest", "bar"])
				page_index = 1
			"later rest reveals bar":
				second = _make_page(["long rest", "bar", "bar"])
				page_index = 1
		state.pages.assign([first, second, third])
		for page: PhotoPage in state.pages:
			page.bytes = encoded
			page.mime = "image/png"
		state.current_page_index = page_index
		var target: DetectionData = state.pages[page_index].lines[0][detection_index]
		if scenario == "flagged rest":
			target.needs_check = true
		NumberingEngine.number_all_pages(state.pages, state.pickup_first_bar)
		var original: Array = _snapshot(state)
		var before: Array = _initials(state)
		var screen: Node = load("res://scenes/results/results.tscn").instantiate()
		root.add_child(screen)
		while screen._task != -1:
			await process_frame
		screen.camera._transform_view(screen.get_viewport_rect().size / 2, screen.get_viewport_rect().size / 2 + Vector2(30, 20), 1.5)
		var fitted_position: Vector2 = screen.camera.position
		var saved_zoom: Vector2 = screen.camera.zoom
		var marker: DetectionMarker = screen.markers.get_child(detection_index)
		# Exercise the picker's fit-zoom hit test and its marker tap signal.
		assert(screen.picker.pick(Vector2(target.x + 2 / screen.camera.zoom.x, target.y)) == marker)
		var tap_position: Vector2 = screen.markers.get_global_transform_with_canvas() * Vector2(target.x, target.y)
		screen.picker._start = tap_position
		screen.picker._started_ms = Time.get_ticks_msec()
		screen.picker._cancelled = false
		screen.picker._finish(tap_position, false)
		assert(screen.edit_popup.field.text == str(target.measures_spanned))
		assert(screen.edit_popup.is_open and marker.selected)
		await process_frame
		var bottom: Vector2 = screen.markers.get_global_transform_with_canvas() * Vector2(target.x, target.y + target.h / 2)
		assert(bottom.y <= screen.edit_popup.top_edge() - DesignTokens.SPACE_48 + 1)
		if scenario == "length 6":
			# Close, Apply and Delete restore the custom view from before opening.
			screen.edit_popup.close()
			await screen.edit_popup.closed
			assert(screen.camera.position.is_equal_approx(fitted_position))
			assert(screen.camera.zoom.is_equal_approx(saved_zoom))
			marker.tap()
			await process_frame
			var row: HBoxContainer = screen.edit_popup.field.get_parent()
			var minus: Control = row.get_child(0)
			var plus: Control = row.get_child(2)
			var field: LineEdit = screen.edit_popup.field
			var center: float = field.global_position.x + field.size.x / 2
			assert(is_equal_approx(center - (minus.global_position.x + minus.size.x / 2), plus.global_position.x + plus.size.x / 2 - center))
			assert(is_equal_approx(center, screen.get_viewport_rect().size.x / 2))
			var later_number: int = first.lines[0][2].measure_number
			var label: int = NumberingEngine.line_start_labels(second.lines)[0]
			screen.edit_popup.field.text = "6"
			screen.edit_popup._apply()
			await screen.edit_popup.closed
			assert(screen.camera.position.is_equal_approx(fitted_position))
			assert(screen.camera.zoom.is_equal_approx(saved_zoom))
			assert(marker.badge_text() == "×6")
			assert(first.lines[0][2].measure_number == later_number + 2)
			assert(NumberingEngine.line_start_labels(second.lines)[0] == label + 2)
			screen.show_page(1)
			assert(screen.line_numbers._labels[0].text == str(label + 2))
			print("VERIFY length 4 -> 6: initials ", before, " -> ", _initials(state), "; page 2 first label ", label, " -> ", label + 2)
		else:
			if scenario == "flagged rest":
				assert(marker.badge_text() == "×4 ?" and screen.check_pill.text == "1 to check" and screen.check_pill.visible and screen.edit_popup.warning.visible)
			var following: DetectionData = state.pages[page_index].lines[0][detection_index + 1] if detection_index + 1 < state.pages[page_index].lines[0].size() else null
			var following_before: int = following.measure_number if following != null else 0
			screen._delete_detection(target)
			await screen.edit_popup.closed
			assert(screen.camera.position.is_equal_approx(fitted_position))
			assert(screen.camera.zoom.is_equal_approx(saved_zoom))
			var after: Array = _initials(state)
			print("VERIFY ", scenario, ": page initials ", before, " -> ", after)
			match scenario:
				"interior bar":
					assert(following.measure_number == following_before - 1 and after == [before[0], before[1] - 1, before[2] - 1])
				"first pickup bar": assert(first.initial_measure_number == 1 and following.measure_number == 1)
				"first ordinary bar": assert(first.initial_measure_number == 2 and following.measure_number == 2)
				"first bar reveals rest": assert(first.initial_measure_number == 1 and following.measure_number == 1)
				"later bar reveals rest": assert(after[1] == before[1] - 1 and after[2] == before[2] - 1)
				"later rest reveals bar": assert(after[1] == before[1] + 1 and after[2] != before[2])
				"page-ending rest", "flagged rest": assert(after[1] != before[1])
			if scenario.begins_with("later"):
				var previous_end: int = NumberingEngine.end_value(first.lines, first.initial_measure_number)
				assert(NumberingEngine.line_start_labels(second.lines)[0] == previous_end)
				assert(screen.line_numbers._labels[0].text == str(previous_end))
				print("VERIFY page 2 first label = previous page end = ", previous_end)
			if scenario == "flagged rest": assert(not screen.check_pill.visible)
			screen.snackbar.action_pressed.emit()
			assert(_snapshot(state) == original)
			print("VERIFY Undo restores every number: ", _initials(state))
		while screen._task != -1:
			await process_frame
		await process_frame
		screen.free()
