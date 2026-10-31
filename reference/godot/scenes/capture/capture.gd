extends Control

const MAX_PAGES: int = 30
const COMPONENTS: String = "res://ui/%s/%s.tscn"

var _guides: Node2D
var camera: CameraService
var _panel: PanelContainer
var _top: PanelContainer
var _pill: Pill
var _strip: HBoxContainer
var _shutter: Button
var _process_button: PrimaryButton
var _caption: Label
var _message: Label
var _permission: VBoxContainer
var _spinner: Spinner
var _loading: Label
var _flash: ColorRect
var _sheet: BottomSheet
var _confirm: ConfirmDialog
var _retake_index: int = -1
var _selected_index: int = -1
var _busy: bool = false
var _paused: bool = false
var _leaving: bool = false
var _task: int = -1
var _result: Dictionary = {}
var _flash_tween: Tween
var _sheet_preview: TextureRect

func _component(kind: String) -> Node:
	return (load(COMPONENTS % [kind, kind]) as PackedScene).instantiate()

func _ready() -> void:
	_guides = Node2D.new()
	add_child(_guides)
	move_child(_guides, $Preview.get_index() + 1)
	_guides.draw.connect(_draw_guides)
	_build_ui()
	camera = CameraService.new()
	add_child(camera)
	camera.preview_updated.connect(func(texture: ImageTexture) -> void:
		$Preview.texture = texture
		_guides.queue_redraw()
		if texture != null:
			var recovering_permission: bool = _permission.visible
			_permission.hide()
			if recovering_permission:
				_message.text = ""
				_message.hide())
	camera.photo_captured.connect(_on_photo)
	camera.capture_failed.connect(_on_failure)
	camera.capture_cancelled.connect(func() -> void:
		_busy = false
		_retake_index = -1
		_refresh())
	camera.permission_denied.connect(func() -> void:
		_permission.show()
		_on_failure("Camera permission is needed to photograph pages."))
	_refresh()
	camera.start_preview()
	HintOverlay.show_once(self, "capture", "Fill the frame with the page. Keep it flat and well lit.")

func _build_ui() -> void:
	var chrome: Control = $SafeArea/Chrome
	_top = PanelContainer.new()
	_top.add_theme_stylebox_override("panel", ThemeFactory.box(DesignTokens.CAMERA_TOP_SURFACE, DesignTokens.RADIUS, 0))
	chrome.add_child(_top)
	var bar: HBoxContainer = HBoxContainer.new()
	_top.add_child(bar)
	var back: IconButton = _component("IconButton") as IconButton
	back.icon = load("res://theme/icons/chevron-left.svg")
	back.tooltip_text = "Back"
	back.pressed.connect(request_back)
	bar.add_child(back)
	var space: Control = Control.new()
	space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(space)
	_pill = _component("Pill") as Pill
	bar.add_child(_pill)
	_caption = Label.new()
	_caption.text = "Take a photo of each page, in order"
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.add_theme_stylebox_override("normal", ThemeFactory.box(DesignTokens.SURFACE))
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.add_theme_font_size_override("font_size", DesignTokens.CAPTION_SIZE)
	chrome.add_child(_caption)
	_message = Label.new()
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.add_theme_font_size_override("font_size", DesignTokens.CAPTION_SIZE)
	_message.add_theme_stylebox_override("normal", ThemeFactory.box(DesignTokens.SURFACE, DesignTokens.RADIUS, DesignTokens.SPACE_12))
	chrome.add_child(_message)
	_permission = VBoxContainer.new()
	chrome.add_child(_permission)
	var retry: PrimaryButton = _component("PrimaryButton") as PrimaryButton
	retry.text = "Allow camera"
	retry.pressed.connect(func() -> void: camera.start_preview())
	_permission.add_child(retry)
	var settings: SecondaryButton = _component("SecondaryButton") as SecondaryButton
	settings.text = "Open app settings"
	settings.pressed.connect(func() -> void: camera.open_system_settings())
	_permission.add_child(settings)
	_permission.hide()
	_panel = PanelContainer.new()
	var style: StyleBoxFlat = ThemeFactory.box(DesignTokens.CAMERA_SURFACE, 0, DesignTokens.SPACE_12)
	style.corner_radius_top_left = DesignTokens.SHEET_RADIUS
	style.corner_radius_top_right = DesignTokens.SHEET_RADIUS
	_panel.add_theme_stylebox_override("panel", style)
	chrome.add_child(_panel)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", DesignTokens.SPACE_12)
	_panel.add_child(stack)
	var inset: MarginContainer = MarginContainer.new()
	# SafeArea has already applied its 24 px sides.
	inset.add_theme_constant_override("margin_left", DesignTokens.GESTURE_MARGIN - DesignTokens.SIDE_MARGIN - DesignTokens.SPACE_12)
	inset.add_theme_constant_override("margin_right", DesignTokens.GESTURE_MARGIN - DesignTokens.SIDE_MARGIN - DesignTokens.SPACE_12)
	stack.add_child(inset)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size.y = DesignTokens.THUMBNAIL_SIZE
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inset.add_child(scroll)
	_strip = HBoxContainer.new()
	scroll.add_child(_strip)
	var pickup: CheckButton = CheckButton.new()
	pickup.text = "First bar is a pickup"
	pickup.custom_minimum_size = Vector2.ONE * DesignTokens.HIT_SIZE
	pickup.button_pressed = AppState.pickup_first_bar
	pickup.toggled.connect(func(value: bool) -> void: AppState.pickup_first_bar = value)
	stack.add_child(pickup)
	_shutter = Button.new()
	_shutter.tooltip_text = "Capture page"
	_shutter.custom_minimum_size = Vector2.ONE * DesignTokens.SHUTTER_SIZE
	_shutter.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var ring: StyleBoxFlat = ThemeFactory.box(DesignTokens.ACCENT, DesignTokens.SHUTTER_SIZE / 2, 0)
	ring.set_border_width_all(DesignTokens.SPACE_12)
	ring.border_color = DesignTokens.CAPTURE_WHITE
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		_shutter.add_theme_stylebox_override(state, ring)
	_shutter.pressed.connect(_capture)
	stack.add_child(_shutter)
	_process_button = _component("PrimaryButton") as PrimaryButton
	_process_button.pressed.connect(_process_pages)
	stack.add_child(_process_button)
	_spinner = _component("Spinner") as Spinner
	chrome.add_child(_spinner)
	_loading = Label.new()
	_loading.text = "Preparing photo…"
	_loading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chrome.add_child(_loading)
	_flash = ColorRect.new()
	_flash.color = DesignTokens.CAPTURE_WHITE
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.modulate.a = 0
	add_child(_flash)
	_sheet = _component("BottomSheet") as BottomSheet
	add_child(_sheet)
	_sheet_preview = TextureRect.new()
	_sheet_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sheet_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_sheet_preview.custom_minimum_size.y = DesignTokens.PHOTO_PREVIEW_HEIGHT
	_sheet.content.add_child(_sheet_preview)
	var delete: PrimaryButton = _component("PrimaryButton") as PrimaryButton
	delete.theme_type_variation = "DangerButton"
	delete.text = "Delete"
	delete.pressed.connect(_delete_selected)
	_sheet.content.add_child(delete)
	var retake: SecondaryButton = _component("SecondaryButton") as SecondaryButton
	retake.text = "Retake"
	retake.pressed.connect(_retake_selected)
	_sheet.content.add_child(retake)
	_sheet.closed.connect(func() -> void: _sheet_preview.texture = null)
	_confirm = _component("ConfirmDialog") as ConfirmDialog
	_confirm.title = "Discard captured pages?"
	_confirm.message = "These photos will be removed from this session."
	_confirm.confirm_text = "Discard pages"
	_confirm.danger = true
	_confirm.confirmed.connect(_leave_to_menu)
	_confirm.closed.connect(_resume_after_sheet)
	add_child(_confirm)
	chrome.resized.connect(_layout)
	_layout.call_deferred()

func _layout() -> void:
	if not is_instance_valid(_panel):
		return
	var chrome: Control = $SafeArea/Chrome
	_top.size = Vector2(chrome.size.x, DesignTokens.HIT_SIZE)
	_panel.size = Vector2(chrome.size.x, minf(_panel.get_combined_minimum_size().y, size.y * DesignTokens.CAPTURE_PANEL_FRACTION))
	_panel.position = Vector2(0, chrome.size.y - _panel.size.y)
	# Show the entire camera frame within the unobscured, safe-area viewport.
	var preview_top: float = _top.position.y + _top.size.y + DesignTokens.SPACE_24
	$Preview.position = chrome.position + $SafeArea.position + Vector2(0, preview_top)
	$Preview.size = Vector2(chrome.size.x, maxf(0, _panel.position.y - preview_top - DesignTokens.SPACE_24))
	_caption.position = Vector2(0, _top.size.y + DesignTokens.SPACE_48)
	# Wrapped labels can retain their initial narrow-layout height. Set width
	# first, then shrink their backgrounds to the newly measured text height.
	_caption.size.x = chrome.size.x
	_caption.size.y = _caption.get_combined_minimum_size().y
	_message.position = Vector2(0, _caption.position.y + (_caption.size.y + DesignTokens.SPACE_12 if _caption.visible else 0.0))
	_message.size.x = chrome.size.x
	_message.size.y = _message.get_combined_minimum_size().y
	_permission.position = Vector2(0, _message.position.y + _message.size.y + DesignTokens.SPACE_24)
	_permission.size.x = chrome.size.x
	_spinner.position = Vector2((chrome.size.x - DesignTokens.ICON_SIZE) / 2, _panel.position.y - DesignTokens.HIT_SIZE - DesignTokens.SPACE_72)
	_loading.position = Vector2(0, _spinner.position.y + DesignTokens.ICON_SIZE)
	_loading.size.x = chrome.size.x
	_guides.queue_redraw()

func _draw_guides() -> void:
	if not is_instance_valid(_panel):
		return
	var preview: TextureRect = $Preview
	var image_rect: Rect2 = preview.get_rect()
	if preview.texture != null:
		var image_size: Vector2 = preview.texture.get_size()
		var scale: float = minf(preview.size.x / image_size.x, preview.size.y / image_size.y)
		image_rect.size = image_size * scale
		image_rect.position = preview.position + (preview.size - image_rect.size) / 2.0
	var rect: Rect2 = image_rect
	if not rect.has_area():
		return
	for index: int in range(1, DesignTokens.CAPTURE_GUIDE_COUNT + 1):
		var y: float = rect.position.y + rect.size.y * index / (DesignTokens.CAPTURE_GUIDE_COUNT + 1.0)
		_guides.draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), DesignTokens.CAPTURE_GUIDE_COLOR, DesignTokens.CAPTURE_GUIDE_WIDTH, true)

func _refresh() -> void:
	for child: Node in _strip.get_children():
		_strip.remove_child(child)
		child.queue_free()
	for index: int in AppState.pages.size():
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2.ONE * DesignTokens.THUMBNAIL_SIZE
		button.tooltip_text = "Page %d: preview, delete or retake" % (index + 1)
		_strip.add_child(button)
		var photo: TextureRect = TextureRect.new()
		photo.texture = AppState.pages[index].thumbnail
		photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		photo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		button.add_child(photo)
		var badge: Pill = _component("Pill") as Pill
		badge.text = str(index + 1)
		button.add_child(badge)
		button.disabled = _busy
		button.pressed.connect(_open_page.bind(index))
	_pill.text = "%d / %d pages" % [AppState.pages.size(), MAX_PAGES]
	_process_button.text = "Process %d pages" % AppState.pages.size()
	_process_button.disabled = _busy or AppState.pages.is_empty()
	_shutter.disabled = _busy or (AppState.pages.size() >= MAX_PAGES and _retake_index < 0)
	_caption.visible = AppState.pages.is_empty()
	_spinner.visible = _task >= 0 or (_busy and OS.get_name() == "Android")
	_loading.text = "Preparing photo…" if _task >= 0 else "Taking photo…"
	_loading.visible = _spinner.visible
	if AppState.pages.size() >= MAX_PAGES and _retake_index < 0:
		_message.text = "30-page limit reached. Delete or retake a page to continue."
	elif OS.get_name() != "Android" and _message.text.is_empty():
		_message.text = "Use the shutter to import a photo."
	_message.visible = not _message.text.is_empty()
	_layout.call_deferred()

func _capture() -> void:
	if _busy:
		return
	if AppState.pages.size() >= MAX_PAGES and _retake_index < 0:
		_on_failure("30-page limit reached. Delete or retake a page to continue.")
		return
	_busy = true
	Haptics.tap()
	_flash.modulate.a = 1
	if _flash_tween:
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash, "modulate:a", 0.0, DesignTokens.FLASH_DURATION)
	_refresh()
	camera.capture()

func _on_photo(image: Image) -> void:
	_busy = true
	_permission.hide()
	_message.text = ""
	var source: Dictionary = camera.take_source()
	_result = {}
	_task = WorkerThreadPool.add_task(_encode.bind(image, source), false, "Encode captured page")
	_refresh()

func _encode(image: Image, source: Dictionary) -> void:
	var result: Dictionary = ImageEncoder.encode_for_upload(image, source.bytes, source.mime)
	if not result.has("error"):
		var scale: float = minf(1.0, float(DesignTokens.THUMBNAIL_LONG_SIDE) / maxi(image.get_width(), image.get_height()))
		image.resize(maxi(1, roundi(image.get_width() * scale)), maxi(1, roundi(image.get_height() * scale)), Image.INTERPOLATE_LANCZOS)
		result["thumbnail"] = image
	_result = result

func _process(_delta: float) -> void:
	if _task >= 0 and WorkerThreadPool.is_task_completed(_task):
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		if _result.has("error"):
			_on_failure(str(_result.error))
		else:
			var page: PhotoPage = PhotoPage.new()
			page.id = "%d-%d" % [Time.get_ticks_usec(), randi()]
			page.bytes = _result.bytes
			page.mime = _result.mime
			page.width = _result.width
			page.height = _result.height
			page.thumbnail = ImageTexture.create_from_image(_result.thumbnail)
			if _retake_index >= 0 and _retake_index < AppState.pages.size():
				page.id = AppState.pages[_retake_index].id
				AppState.pages[_retake_index] = page
			else:
				AppState.pages.append(page)
			_busy = false
			_retake_index = -1
		_result.clear()
		_refresh()
		if not _paused and not _sheet.is_open and not _confirm.is_open and not _leaving:
			camera.start_preview()

func _on_failure(reason: String) -> void:
	_busy = false
	_retake_index = -1
	_message.text = reason
	_refresh()

func _open_page(index: int) -> void:
	if _busy:
		return
	Haptics.tap()
	_selected_index = index
	camera.stop_preview()
	var page: PhotoPage = AppState.pages[index]
	var image: Image = ImageEncoder.decode(page.bytes, page.mime)
	if image != null:
		var scale: float = minf(1.0, float(DesignTokens.PHOTO_PREVIEW_HEIGHT) / image.get_height())
		image.resize(maxi(1, roundi(image.get_width() * scale)), maxi(1, roundi(image.get_height() * scale)), Image.INTERPOLATE_BILINEAR)
		_sheet_preview.texture = ImageTexture.create_from_image(image)
	_sheet.open()
	if not _sheet.closed.is_connected(_resume_after_sheet):
		_sheet.closed.connect(_resume_after_sheet)

func _resume_after_sheet() -> void:
	if not _paused and not _busy and not _leaving:
		camera.start_preview()

func _delete_selected() -> void:
	if _selected_index >= 0 and _selected_index < AppState.pages.size():
		Haptics.heavy()
		AppState.pages.remove_at(_selected_index)
		AppState.current_page_index = clampi(AppState.current_page_index, 0, maxi(0, AppState.pages.size() - 1))
		_message.text = "Photo deleted."
		_refresh()
	_sheet.close()

func _retake_selected() -> void:
	_retake_index = _selected_index
	_sheet.close()
	# Native retake needs a fresh preview before the next shutter press.
	_message.text = "Retake page %d. Tap the shutter when ready." % (_retake_index + 1)
	_refresh()

func _process_pages() -> void:
	if _busy or AppState.pages.is_empty():
		return
	camera.stop_preview()
	Router.goto("processing")

func request_back() -> void:
	if _leaving:
		return
	if AppState.pages.is_empty():
		_leave_to_menu()
	elif not _confirm.is_open:
		camera.stop_preview()
		_confirm.open()

func _leave_to_menu() -> void:
	if _leaving:
		return
	_leaving = true
	camera.stop_preview()
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
	_result.clear()
	$Preview.texture = null
	_sheet_preview.texture = null
	AppState.reset_session()
	_refresh()
	Router.goto("main_menu")

func _notification(what: int) -> void:
	if not is_instance_valid(camera):
		return
	if what == NOTIFICATION_APPLICATION_PAUSED:
		_paused = true
		camera.stop_preview()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		_paused = false
		if not _busy and not _sheet.is_open and not _confirm.is_open and not _leaving:
			camera.start_preview()

func _exit_tree() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
	_result.clear()
	if is_instance_valid(camera):
		camera.stop_preview()
