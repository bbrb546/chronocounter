extends Node

var screen: Node
var output: String = ProjectSettings.globalize_path("res://../docs/screenshots")
var original_hints: Dictionary

func _ready() -> void:
	get_window().size = Vector2i(1080, 2400)
	original_hints = Settings.hints_seen.duplicate(true)
	Settings.hints_seen = {"capture": true, "results": true, "detections": true}
	_run.call_deferred()

func _open(route: String) -> void:
	if is_instance_valid(screen):
		screen.free()
	screen = load("res://scenes/%s/%s.tscn" % [route, route]).instantiate()
	screen.set_meta("tour", true)
	add_child(screen)
	await _settle()

func _settle() -> void:
	await get_tree().create_timer(0.3).timeout
	if is_instance_valid(screen) and screen.get("_task") != null:
		while screen._task != -1:
			await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw

func _shoot(name_: String) -> void:
	await _settle()
	var image: Image = get_viewport().get_texture().get_image()
	assert(image.get_size() == Vector2i(1080, 2400))
	assert(image.save_png(output.path_join(name_ + ".png")) == OK)
	print("Saved ", name_)

func _fixtures() -> void:
	AppState.reset_session()
	for index: int in range(3):
		var page: PhotoPage = PhotoPage.new()
		page.bytes = FileAccess.get_file_as_bytes("res://fixtures/mock_page_%d.png" % index)
		page.mime = "image/png"
		var image: Image = ImageEncoder.decode(page.bytes, page.mime)
		page.width = image.get_width()
		page.height = image.get_height()
		image.resize(192, 256)
		page.thumbnail = ImageTexture.create_from_image(image)
		var raw: Array = JSON.parse_string(FileAccess.get_file_as_string("res://fixtures/mock_page_%d.json" % index))
		for raw_line: Array in raw:
			var line: Array = []
			for item: Dictionary in raw_line:
				line.append(DetectionData.from_json(item))
			page.lines.append(line)
		page.status = PhotoPage.Status.DONE
		AppState.pages.append(page)
	NumberingEngine.number_all_pages(AppState.pages, false)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	await _open("main_menu")
	await _shoot("01-main-menu")
	screen._on_settings_pressed()
	await _shoot("02-settings")
	_fixtures()
	await _open("capture")
	screen.get_node("Preview").texture = ImageTexture.create_from_image(ImageEncoder.decode(AppState.pages[0].bytes, "image/png"))
	screen._message.text = ""
	screen._message.hide()
	await _shoot("03-capture")
	await _open("processing")
	screen._progress(1, 3)
	await _shoot("04-processing")
	await _open("results")
	await _shoot("05-results-fit")
	var selected: DetectionMarker
	for marker: DetectionMarker in screen.markers.get_children():
		if marker.data.is_long_rest():
			selected = marker
			break
	assert(selected != null)
	screen.camera._set_zoom(screen.camera.zoom.x * 2.0)
	screen._on_marker_tapped(selected)
	await _shoot("06-results-edit")
	screen._delete_detection(selected.data)
	await _shoot("07-delete-snackbar")
	await _open("processing")
	screen._progress(1, 3)
	screen._failed(1, "Can't reach the server. Check your Wi-Fi and server address in Settings.")
	await _shoot("08-error")
	Settings.hints_seen = original_hints
	AppState.reset_session()
	print("SCREENSHOT_TOUR_COMPLETED")
	get_tree().quit()
