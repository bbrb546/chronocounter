extends Control

var _list: VBoxContainer
var _snackbar: Snackbar
var _modal_sheet: BottomSheet
var _nonmodal_sheet: BottomSheet
var _confirm: ConfirmDialog

func _ready() -> void:
	var safe: SafeAreaContainer = SafeAreaContainer.new()
	safe.side_margin = DesignTokens.GESTURE_MARGIN
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(safe)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	safe.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	_label("Component gallery", DesignTokens.TITLE_SIZE)
	_label("Scroll to see every component and state.", DesignTokens.CAPTION_SIZE)
	for component: String in ["PrimaryButton", "SecondaryButton", "IconButton"]:
		_label(component, DesignTokens.HEADING_SIZE)
		for state: String in ["Normal", "Disabled", "Pressed"]:
			var button: Button = load("res://ui/%s/%s.tscn" % [component, component]).instantiate()
			button.text = state
			button.disabled = state == "Disabled"
			if state == "Pressed":
				button.toggle_mode = true
				button.button_pressed = true
			if component == "IconButton":
				button.text = ""
				button.icon = preload("res://theme/icons/settings.svg")
				button.tooltip_text = "Settings: " + state
				button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			_list.add_child(button)
		var filled: IconButton = IconButton.new()
		if component == "IconButton":
			filled.filled = true
			filled.icon = preload("res://theme/icons/plus.svg")
			filled.tooltip_text = "Add"
			filled.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			_list.add_child(filled)
		else:
			filled.free()
	_label("Icons", DesignTokens.HEADING_SIZE)
	for icon_name: String in ["chevron-left", "chevron-right", "close", "trash", "undo", "reset-view", "minus", "plus", "settings", "check"]:
		var icon_button: IconButton = IconButton.new()
		icon_button.icon = load("res://theme/icons/%s.svg" % icon_name)
		icon_button.tooltip_text = icon_name
		icon_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_list.add_child(icon_button)
	_label("Switch and field states", DesignTokens.HEADING_SIZE)
	for state: String in ["Off", "On", "Disabled"]:
		var check: CheckButton = CheckButton.new()
		check.text = "Use mock server: " + state
		check.custom_minimum_size = Vector2.ONE * DesignTokens.HIT_SIZE
		check.button_pressed = state == "On"
		check.disabled = state == "Disabled"
		_list.add_child(check)
	for state: String in ["Empty", "Filled", "Read only"]:
		var field: LineEdit = LineEdit.new()
		field.custom_minimum_size = Vector2.ONE * DesignTokens.HIT_SIZE
		field.placeholder_text = "Server URL"
		field.text = "" if state == "Empty" else "http://192.168.1.100:8000"
		field.editable = state != "Read only"
		_list.add_child(field)
	_label("Pill: counter and page indicator", DesignTokens.HEADING_SIZE)
	for value: String in ["12 measures", "1 / 3"]:
		var pill: Pill = preload("res://ui/Pill/Pill.tscn").instantiate()
		pill.text = value
		pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_list.add_child(pill)
	_label("Loading", DesignTokens.HEADING_SIZE)
	var spinner: Spinner = Spinner.new()
	spinner.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_list.add_child(spinner)
	for value: float in [0.0, 50.0, 100.0]:
		var progress: ProgressBar = ProgressBar.new()
		progress.show_percentage = false
		progress.custom_minimum_size.y = DesignTokens.SPACE_24
		progress.value = value
		_list.add_child(progress)
		_label("%d%% complete" % value)
	_modal_sheet = _make_sheet(true)
	_nonmodal_sheet = _make_sheet(false)
	_action("Open modal sheet", _modal_sheet.open)
	_action("Open nonmodal sheet", _nonmodal_sheet.open)
	_snackbar = preload("res://ui/Snackbar/Snackbar.tscn").instantiate()
	add_child(_snackbar)
	_action("Show snackbar", func() -> void: _snackbar.show_message("Settings saved.", "", DesignTokens.SETTINGS_SAVED_DURATION))
	_action("Show snackbar with action", func() -> void: _snackbar.show_message("Photo removed.", "Undo"))
	_confirm = preload("res://ui/ConfirmDialog/ConfirmDialog.tscn").instantiate()
	add_child(_confirm)
	_action("Confirm dialog", func() -> void:
		_confirm.title = "Start again?"
		_confirm.message = "This clears the current session."
		_confirm.confirm_text = "Start again"
		_confirm.danger = false
		_confirm.open())
	_action("Danger confirmation", func() -> void:
		_confirm.title = "Delete photo?"
		_confirm.message = "This removes the photo from this session."
		_confirm.confirm_text = "Delete"
		_confirm.danger = true
		_confirm.open())
	_label("Empty state: No photos yet.")
	_label("Error state: Could not connect. Try again.")

func _label(text: String, font_size: int = DesignTokens.BODY_SIZE) -> void:
	var label: Label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	_list.add_child(label)

func _action(text: String, callback: Callable) -> void:
	var button: SecondaryButton = SecondaryButton.new()
	button.text = text
	button.pressed.connect(callback)
	_list.add_child(button)

func _make_sheet(is_modal: bool) -> BottomSheet:
	var sheet: BottomSheet = preload("res://ui/BottomSheet/BottomSheet.tscn").instantiate()
	sheet.modal = is_modal
	add_child(sheet)
	var label: Label = Label.new()
	label.text = "Modal sheet" if is_modal else "Nonmodal sheet: outside controls stay active."
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sheet.content.add_child(label)
	var button: SecondaryButton = SecondaryButton.new()
	button.text = "Close"
	button.pressed.connect(sheet.close)
	sheet.content.add_child(button)
	return sheet
