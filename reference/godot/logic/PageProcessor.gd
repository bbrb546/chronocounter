class_name PageProcessor
extends RefCounted

signal progress(i: int, n: int)
signal page_done(i: int)
signal failed(i: int, message: String)
signal finished

var client: Node = ApiClient
var _index: int = 0
var _prev_end: int = 0
var _provisional: int = 1
var _cancelled: bool = false
var _running: bool = false
var _failed: bool = false
var _paused: bool = false
var _interrupted: bool = false

func start() -> void:
	if _running or _paused:
		return
	_index = 0
	_prev_end = 0
	_cancelled = false
	_failed = false
	await _run(false)

func retry() -> void:
	if _running or not _failed or _cancelled or _paused or _interrupted:
		return
	_failed = false
	await _run(true)

func cancel() -> void:
	_cancelled = true
	client.cancel()

func suspend() -> void:
	_paused = true
	if _running:
		_interrupted = true
		client.cancel()

func resume() -> void:
	_paused = false
	_report_interruption()

func _report_interruption() -> void:
	if _paused or _running or not _interrupted or _cancelled:
		return
	_interrupted = false
	_failed = true
	if _index < AppState.pages.size():
		var page: PhotoPage = AppState.pages[_index]
		page.status = PhotoPage.Status.FAILED
		page.error_message = "Processing stopped while the app was in the background. Tap Retry to continue."
		failed.emit(_index, page.error_message)

func _run(keep_initial: bool) -> void:
	_running = true
	while _index < AppState.pages.size() and not _cancelled:
		var page: PhotoPage = AppState.pages[_index]
		if not keep_initial:
			_provisional = AppState.first_page_provisional_initial() if _index == 0 else _prev_end + 1
		keep_initial = false
		page.status = PhotoPage.Status.PROCESSING
		page.error_message = ""
		var response: Dictionary = {"ok": true}
		if Settings.mock_mode:
			response = client.replace_mock_image(page, _index)
		progress.emit(_index, AppState.pages.size())
		if _cancelled or _interrupted:
			page.status = PhotoPage.Status.PENDING
			break
		if response.ok:
			response = await client.send_mock_page(_index) if Settings.mock_mode else await client.send_page(page.bytes, page.mime, _provisional)
		if _cancelled or _interrupted:
			page.status = PhotoPage.Status.PENDING
			break
		if not response.ok:
			page.status = PhotoPage.Status.FAILED
			page.error_message = response.error
			_failed = true
			_running = false
			failed.emit(_index, response.error)
			return
		page.lines = response.lines
		_check_parity(page.lines)
		page.initial_measure_number = NumberingEngine.resolve_initial(page.lines, _index, _prev_end, AppState.pickup_first_bar)
		NumberingEngine.number_page(page.lines, page.initial_measure_number)
		_prev_end = NumberingEngine.end_value(page.lines, page.initial_measure_number)
		page.status = PhotoPage.Status.DONE
		page_done.emit(_index)
		_index += 1
	_running = false
	if _interrupted:
		_report_interruption()
		return
	if not _cancelled:
		NumberingEngine.number_all_pages(AppState.pages, AppState.pickup_first_bar)
		AppState.numbering_changed.emit()
		finished.emit()

func _check_parity(lines: Array) -> void:
	if not OS.is_debug_build():
		return
	if Settings.mock_mode:
		print("PARITY SKIPPED (mock) page %d" % _index)
		return
	var copy: Array = []
	for line: Array in lines:
		var copied_line: Array = []
		for detection: DetectionData in line:
			var clone: DetectionData = DetectionData.new()
			for key: String in ["cls", "x", "y", "w", "h", "measures_spanned", "server_measure_number", "measure_number", "needs_check", "id", "edited"]:
				clone.set(key, detection.get(key))
			copied_line.append(clone)
		copy.append(copied_line)
	NumberingEngine.number_page(copy, _provisional)
	var matches: bool = true
	for line: Array in copy:
		for detection: DetectionData in line:
			matches = matches and detection.measure_number == detection.server_measure_number
	print("PARITY %s page %d" % ["OK" if matches else "MISMATCH", _index])
	if not matches:
		push_error("Server numbering parity mismatch on page %d" % _index)
