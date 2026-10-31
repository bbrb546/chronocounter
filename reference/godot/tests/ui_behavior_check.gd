extends SceneTree

const COMPLETION_MARKER: String = "UI_BEHAVIOR_COMPLETED"
var _failed: bool = false
var _outside_taps: int = 0
var _actions: int = 0
var _confirmed: int = 0
var _cancelled: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var screen: Control = Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(screen)
	var outside: Button = load("res://ui/SecondaryButton/SecondaryButton.tscn").instantiate()
	outside.text = "Outside"
	outside.position = Vector2(DesignTokens.GESTURE_MARGIN, DesignTokens.GESTURE_MARGIN)
	outside.pressed.connect(func() -> void: _outside_taps += 1)
	screen.add_child(outside)
	var sheet: Control = load("res://ui/BottomSheet/BottomSheet.tscn").instantiate()
	screen.add_child(sheet)
	var close_button: Button = load("res://ui/SecondaryButton/SecondaryButton.tscn").instantiate()
	close_button.text = "Close"
	close_button.pressed.connect(sheet.close)
	sheet.content.add_child(close_button)
	await process_frame
	await process_frame
	sheet.modal = false
	sheet.open()
	await create_timer(DesignTokens.SHEET_SLIDE / 2.0).timeout
	_check("Sheet animates rather than jumping", sheet._panel.position.y > sheet.size.y - sheet._sheet_height and sheet._panel.position.y < sheet.size.y)
	await create_timer(DesignTokens.SHEET_SLIDE / 2.0 + DesignTokens.SPACE_24 / 1000.0).timeout
	_check("Sheet handle sits 12 px below its top", is_equal_approx(sheet._handle_mark.global_position.y - sheet._panel.global_position.y, DesignTokens.SPACE_12))
	_check("Sheet opens above bottom edge", sheet.is_open and sheet.visible and is_equal_approx(sheet._panel.position.y + sheet._panel.size.y, sheet.size.y))
	_check("Nonmodal scrim hidden", not sheet._scrim.visible and sheet.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	await _tap(outside.get_global_rect().get_center())
	_check("Nonmodal outside input passes through", _outside_taps == 1)
	sheet.close()
	await create_timer(DesignTokens.SHEET_SLIDE + DesignTokens.SPACE_12 / 1000.0).timeout
	_check("Sheet closes after animation", not sheet.visible)
	sheet.modal = true
	sheet.open()
	await create_timer(DesignTokens.SHEET_SLIDE + DesignTokens.SPACE_12 / 1000.0).timeout
	await _tap(outside.get_global_rect().get_center())
	await create_timer(DesignTokens.SHEET_SLIDE + DesignTokens.SPACE_12 / 1000.0).timeout
	_check("Modal scrim closes and blocks outside action", not sheet.visible and _outside_taps == 1)
	sheet.open()
	await create_timer(DesignTokens.SHEET_SLIDE + DesignTokens.SPACE_12 / 1000.0).timeout
	var down: InputEventMouseButton = InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.global_position = Vector2(0, DesignTokens.HIT_SIZE)
	sheet._on_handle_input(down)
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.global_position = Vector2(0, DesignTokens.HIT_SIZE + DesignTokens.GESTURE_MARGIN)
	sheet._on_handle_input(motion)
	down.pressed = false
	sheet._on_handle_input(down)
	await create_timer(DesignTokens.SHEET_SLIDE + DesignTokens.SPACE_12 / 1000.0).timeout
	_check("Downward drag dismisses sheet", not sheet.visible)
	sheet.open()
	sheet.close()
	sheet.open()
	await create_timer(DesignTokens.SHEET_SLIDE + DesignTokens.SPACE_12 / 1000.0).timeout
	_check("Reopening interrupts close safely", sheet.visible and sheet.is_open)
	sheet.close()
	await create_timer(DesignTokens.SHEET_SLIDE + DesignTokens.SPACE_12 / 1000.0).timeout
	var snackbar: Control = load("res://ui/Snackbar/Snackbar.tscn").instantiate()
	screen.add_child(snackbar)
	snackbar.action_pressed.connect(func() -> void: _actions += 1)
	snackbar.show_message("Settings saved.", "", DesignTokens.SETTINGS_SAVED_DURATION)
	var first_snackbar_size: Vector2 = snackbar.size
	_check("First snackbar text has a drawable rectangle immediately", snackbar._label.text == "Settings saved." and snackbar._label.size.x > 0 and snackbar._label.size.y > 0 and snackbar.get_rect().encloses(Rect2(snackbar.position + snackbar._row.position + snackbar._label.position, snackbar._label.size)))
	_check("First snackbar is compact before first frame", first_snackbar_size.y < screen.get_viewport_rect().size.y / 2.0 and snackbar.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	await process_frame
	await process_frame
	_check("First snackbar label is visible after layout", snackbar._label.is_visible_in_tree() and snackbar._label.size.y > 0)
	_check("First snackbar size stays stable after layout", snackbar.size == first_snackbar_size)
	var taps_before: int = _outside_taps
	await _tap(outside.get_global_rect().get_center())
	_check("First snackbar allows other menu actions", _outside_taps == taps_before + 1)
	_check("Other button dismisses snackbar and stops timer", not snackbar.visible and snackbar._timer.is_stopped())
	snackbar.dismiss()
	snackbar.show_message("Settings saved.")
	_check("Repeated snackbar matches first size", snackbar.size == first_snackbar_size)
	snackbar.dismiss()
	snackbar.show_message("Removed.", "Undo")
	await process_frame
	await process_frame
	_check("Snackbar offers an action", snackbar.visible and snackbar._action.visible)
	await create_timer(DesignTokens.SHEET_SLIDE).timeout
	await _tap(snackbar._action.get_global_rect().get_center())
	_check("Snackbar action emits and dismisses", _actions == 1 and not snackbar.visible)
	var added: CheckButton = CheckButton.new()
	added.text = "Added switch"
	added.position = Vector2(DesignTokens.GESTURE_MARGIN, DesignTokens.HIT_SIZE * 2)
	added.custom_minimum_size = Vector2.ONE * DesignTokens.HIT_SIZE
	snackbar.show_message("Settings saved.")
	screen.add_child(added)
	await process_frame
	await _tap(added.get_global_rect().get_center())
	_check("Dynamically added native button dismisses snackbar", not snackbar.visible and added.button_pressed)
	added.queue_free()
	outside.pressed.connect(func() -> void: snackbar.show_message("New message"), CONNECT_ONE_SHOT)
	snackbar.show_message("Old message")
	await _tap(outside.get_global_rect().get_center())
	_check("Button can replace a dismissed snackbar", snackbar.visible and snackbar._label.text == "New message")
	snackbar.dismiss()
	snackbar.show_message("Saved.")
	_check("Snackbar hides optional action", not snackbar._action.visible)
	await create_timer(DesignTokens.SNACKBAR_DURATION + DesignTokens.SPACE_48 / 1000.0).timeout
	_check("Snackbar auto-dismisses after five seconds", not snackbar.visible)
	snackbar.show_message("Settings saved.", "", DesignTokens.SETTINGS_SAVED_DURATION)
	_check("Settings saved uses one-third duration", is_equal_approx(snackbar._timer.wait_time, DesignTokens.SNACKBAR_DURATION / 3.0))
	await create_timer(DesignTokens.SETTINGS_SAVED_DURATION + DesignTokens.SPACE_48 / 1000.0).timeout
	_check("Settings saved auto-dismisses sooner", not snackbar.visible)
	var dialog: Control = load("res://ui/ConfirmDialog/ConfirmDialog.tscn").instantiate()
	screen.add_child(dialog)
	dialog.confirmed.connect(func() -> void: _confirmed += 1)
	dialog.cancelled.connect(func() -> void: _cancelled += 1)
	dialog.danger = true
	dialog.open()
	await create_timer(DesignTokens.SHEET_SLIDE + DesignTokens.SPACE_12 / 1000.0).timeout
	_check("Danger confirmation uses explicit danger styling", dialog._confirm.theme_type_variation == "DangerButton")
	dialog._confirm.pressed.emit()
	await create_timer(DesignTokens.SHEET_SLIDE + DesignTokens.SPACE_12 / 1000.0).timeout
	_check("Confirmation emits once without cancellation", _confirmed == 1 and _cancelled == 0 and not dialog.visible)
	dialog.open()
	dialog.close()
	await create_timer(DesignTokens.SHEET_SLIDE + DesignTokens.SPACE_12 / 1000.0).timeout
	_check("Cancel dismissal emits cancelled", _cancelled == 1)
	# Exercise menu validation without persisting a setting.
	var menu: Control = load("res://scenes/main_menu/main_menu.tscn").instantiate()
	root.add_child(menu)
	menu._on_settings_pressed()
	_check("Settings does not focus address on open", not menu.settings_sheet.url_edit.has_focus())
	await create_timer(DesignTokens.SHEET_SLIDE + 0.05).timeout
	var address: LineEdit = menu.settings_sheet.url_edit
	_check("Server label shares address row", address.get_parent() is HBoxContainer and address.get_parent().get_child(0).text == "Server address")
	await _tap(address.get_global_rect().get_center())
	_check("Address focuses only when tapped", address.has_focus())
	menu.settings_sheet.url_edit.text = "invalid"
	menu.settings_sheet._on_save_pressed()
	_check("Invalid URL keeps settings open with error", menu.settings_sheet.is_open and menu.settings_sheet.status_label.visible and not menu.settings_sheet.status_label.text.is_empty())
	await create_timer(DesignTokens.SHEET_SLIDE + DesignTokens.SPACE_12 / 1000.0).timeout
	root.get_node("Router")._handle_back()
	await create_timer(DesignTokens.SHEET_SLIDE + DesignTokens.SPACE_12 / 1000.0).timeout
	_check("Android back dismisses settings", not menu.settings_sheet.visible)
	menu.free()
	screen.free()
	var router: Node = root.get_node("Router")
	_check("Router accepts route", router.goto("capture") == OK)
	_check("Router prevents overlapping transitions", router.goto("results") == ERR_BUSY)
	var fade_deadline: int = Time.get_ticks_msec() + 1000
	while router._transition_pending and Time.get_ticks_msec() < fade_deadline:
		await process_frame
	_check("Fade finishes at destination", current_scene != null and current_scene.scene_file_path.ends_with("capture.tscn") and not router._fade.visible and not router._transition_pending)
	print(COMPLETION_MARKER)
	quit(1 if _failed else 0)

func _tap(position: Vector2) -> void:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	root.push_input(motion, true)
	await process_frame
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = position
		event.global_position = position
		root.push_input(event, true)
		await process_frame

func _check(name: String, passed: bool) -> void:
	print("%s: %s" % ["PASS" if passed else "FAIL", name])
	_failed = _failed or not passed
