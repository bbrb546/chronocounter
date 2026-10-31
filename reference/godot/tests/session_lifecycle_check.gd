extends SceneTree

var menu_scene: PackedScene
var capture_scene: PackedScene
var results_scene: PackedScene
var processing_scene: PackedScene
var _failed: bool = false
var state: Node
var router: Node
var settings: Node
var before_memory: int

class DelayedClient extends Node:
	signal release
	var calls: int = 0
	var cancelled: int = 0
	var initials: Array[int] = []
	func send_page(_bytes: PackedByteArray, _mime: String, initial: int) -> Dictionary:
		calls += 1
		initials.append(initial)
		if calls == 2:
			await release
		return {"ok": true, "lines": [[DetectionData.from_json({"class": "long rest", "measures_spanned": 4, "measure_number": initial})]]}
	func cancel() -> void:
		cancelled += 1

func _initialize() -> void:
	_run.call_deferred()

func _check(message: String, passed: bool) -> void:
	print("%s: %s" % ["PASS" if passed else "FAIL", message])
	_failed = _failed or not passed

func _settle() -> void:
	var deadline: int = Time.get_ticks_msec() + 3000
	await process_frame
	while router._transition_pending and Time.get_ticks_msec() < deadline:
		await process_frame
	await create_timer(DesignTokens.SHEET_SLIDE + 0.05).timeout

func _run() -> void:
	menu_scene = load("res://scenes/main_menu/main_menu.tscn")
	capture_scene = load("res://scenes/capture/capture.tscn")
	results_scene = load("res://scenes/results/results.tscn")
	processing_scene = load("res://scenes/processing/processing.tscn")
	state = root.get_node("AppState")
	router = root.get_node("Router")
	settings = root.get_node("Settings")
	settings.hints_seen = {"capture": true, "results": true, "detections": true}
	settings.mock_mode = false
	_check("Desktop close auto-accept disabled", not is_auto_accept_quit())
	var menu: Node = menu_scene.instantiate()
	root.add_child(menu)
	current_scene = menu
	before_memory = OS.get_static_memory_usage()
	print("MEMORY before first session: %d bytes" % before_memory)
	menu._on_take_photos_pressed()
	await _settle()
	var capture: Node = current_scene
	_check("New capture is empty with preview requested", state.pages.is_empty() and not state.pickup_first_bar and capture._strip.get_child_count() == 0 and capture.camera._wanted)
	capture.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	_check("Background stops camera", not capture.camera._wanted)
	capture.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	_check("Resume requests fresh preview", capture.camera._wanted)
	var page: PhotoPage = PhotoPage.new()
	var image: Image = Image.create(64, 96, false, Image.FORMAT_RGB8)
	image.fill(Color.WHITE)
	page.bytes = image.save_png_to_buffer()
	page.mime = "image/png"
	page.thumbnail = ImageTexture.create_from_image(image)
	page.status = PhotoPage.Status.DONE
	page.lines = [[DetectionData.from_json({"class": "bar", "x": 20, "y": 30, "width": 2, "height": 10})]]
	state.pages.append(page)
	state.pickup_first_bar = true
	capture._refresh()
	router.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	await process_frame
	_check("Capture desktop close asks with pages", capture._confirm.is_open and not state.pages.is_empty())
	capture._confirm._cancel.pressed.emit()
	await _settle()
	_check("Cancel preserves photos and restarts preview", state.pages.size() == 1 and capture.camera._wanted)
	router.goto("results")
	await _settle()
	var results: Node = current_scene
	while results._task != -1:
		await process_frame
	results._top.get_child(0).pressed.emit()
	_check("Results button opens shared discard dialog", results.exit_dialog.is_open and results.exit_dialog.title == "Discard photos and results?" and results.exit_dialog.confirm_text == "Back to menu")
	results.exit_dialog._cancel.pressed.emit()
	await _settle()
	_check("Results Cancel retains data", state.pages.size() == 1 and results.photo.texture != null)
	results._on_marker_tapped(results.markers.get_child(0))
	router.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await _settle()
	_check("Back dismisses edit before leaving Results", not results.edit_popup.is_open and not results.exit_dialog.is_open)
	router.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await process_frame
	_check("Results Android Back asks to discard", results.exit_dialog.is_open)
	results.exit_dialog._confirm.pressed.emit()
	await _settle()
	_check("Confirm returns to menu and clears retained page payload", current_scene.scene_file_path.ends_with("main_menu.tscn") and state.pages.is_empty() and not state.pickup_first_bar and state.current_page_index == 0 and page.bytes.is_empty() and page.thumbnail == null and page.lines.is_empty())
	page = null
	image = null
	print("MEMORY after reset: %d bytes; delta: %+d bytes" % [OS.get_static_memory_usage(), OS.get_static_memory_usage() - before_memory])
	current_scene._on_take_photos_pressed()
	await _settle()
	capture = current_scene
	_check("Second session starts clean with camera preview", state.pages.is_empty() and not state.pickup_first_bar and capture._strip.get_child_count() == 0 and capture.camera._wanted)
	router.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await _settle()
	_check("Empty Capture Back returns without confirmation", current_scene.scene_file_path.ends_with("main_menu.tscn"))
	print("MEMORY after second reset: %d bytes" % OS.get_static_memory_usage())
	await _processing_pause(false)
	await _processing_pause(true)
	# The menu's close request must end this subprocess through Router.
	print("SESSION_LIFECYCLE_COMPLETED")
	if _failed:
		quit(1)
	else:
		router.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)

func _processing_pause(quick_resume: bool) -> void:
	state.reset_session()
	for i: int in 3:
		state.pages.append(PhotoPage.new())
	var client: DelayedClient = DelayedClient.new()
	root.add_child(client)
	var scene: Node = processing_scene.instantiate()
	scene.set_meta("tour", true)
	scene.processor.client = client
	root.add_child(scene)
	scene._started = true
	scene.processor.start()
	_check("First page finishes before interrupted upload", state.pages[0].status == PhotoPage.Status.DONE and client.calls == 2)
	scene.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	if quick_resume:
		scene.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	client.release.emit()
	_check("Background response does not install detections", state.pages[1].lines.is_empty() and state.pages[2].status == PhotoPage.Status.PENDING)
	if not quick_resume:
		_check("No background dialog", not scene.dialog.is_open)
		scene.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	_check("Resume offers explicit retry and preserves completed page", scene.dialog.is_open and state.pages[0].status == PhotoPage.Status.DONE and client.cancelled == 1)
	# Block navigation so this isolated processor check stays on the menu.
	scene._leaving = true
	await scene.processor.retry()
	_check("Retry resumes same initial and completes remaining pages", client.initials == [2, 6, 6, 10] and state.pages[2].status == PhotoPage.Status.DONE)
	scene.free()
	client.free()
	state.reset_session()
