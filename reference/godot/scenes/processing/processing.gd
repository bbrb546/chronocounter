extends Control

var processor: PageProcessor = PageProcessor.new()
var _leaving: bool = false
var _paused: bool = false
var _started: bool = false
@onready var label: Label = $SafeArea/Layout/Status
@onready var bar: ProgressBar = $SafeArea/Layout/Progress
@onready var thumbnail: TextureRect = $SafeArea/Layout/Thumbnail
@onready var spinner: Control = $SafeArea/Layout/Spinner
@onready var dialog: ConfirmDialog = $ErrorDialog

func _ready() -> void:
	$SafeArea/Layout.add_theme_constant_override("separation", DesignTokens.SPACE_36)
	label.add_theme_font_size_override("font_size", DesignTokens.HEADING_SIZE)
	$SafeArea/Layout/Cancel.custom_minimum_size.y = DesignTokens.HIT_SIZE
	processor.progress.connect(_progress)
	processor.page_done.connect(func(i: int) -> void: bar.value = i + 1)
	processor.failed.connect(_failed)
	processor.finished.connect(_finished)
	dialog.confirmed.connect(func() -> void:
		spinner.show()
		processor.retry.call_deferred())
	dialog.cancelled.connect(request_back)
	var settings_button: SecondaryButton = SecondaryButton.new()
	settings_button.text = "Settings"
	dialog.content.add_child(settings_button)
	settings_button.pressed.connect(func() -> void:
		var settings: SettingsSheet = SettingsSheet.new()
		add_child(settings)
		settings.closed.connect(settings.queue_free)
		settings._on_settings_pressed())
	if not get_meta("tour", false):
		_start_processing.call_deferred()

func _start_processing() -> void:
	if _started or _paused or _leaving:
		return
	_started = true
	processor.start()

func _notification(what: int) -> void:
	if _leaving:
		return
	if what == NOTIFICATION_APPLICATION_PAUSED:
		_paused = true
		processor.suspend()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		_paused = false
		processor.resume()
		if not _started and not get_meta("tour", false):
			_start_processing.call_deferred()

func _progress(i: int, n: int) -> void:
	label.text = "Processing page %d of %d" % [i + 1, n]
	bar.max_value = n
	bar.value = i
	thumbnail.texture = AppState.pages[i].thumbnail
	spinner.show()

func _failed(i: int, message: String) -> void:
	spinner.hide()
	label.text = "Page %d couldn't be processed" % (i + 1)
	dialog.title = "Couldn't process page %d" % (i + 1)
	dialog.message = message + "\nYour completed pages are kept. Retry this page or go back to your photos."
	dialog.open()

func _finished() -> void:
	if _leaving:
		return
	_leaving = true
	Router.goto("results")

func request_back() -> void:
	if _leaving:
		return
	_leaving = true
	processor.cancel()
	Router.goto("capture")

func _exit_tree() -> void:
	processor.cancel()
	thumbnail.texture = null
