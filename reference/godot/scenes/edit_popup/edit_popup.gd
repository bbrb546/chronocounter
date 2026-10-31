class_name EditPopup
extends BottomSheet

signal applied(data: DetectionData)
signal delete_requested(data: DetectionData)

const ICON_BUTTON: PackedScene = preload("res://ui/IconButton/IconButton.tscn")
const PRIMARY: PackedScene = preload("res://ui/PrimaryButton/PrimaryButton.tscn")
const SECONDARY: PackedScene = preload("res://ui/SecondaryButton/SecondaryButton.tscn")
var data: DetectionData
var heading: Label
var warning: Label
var field: LineEdit
var error: Label
var rest_controls: VBoxContainer
var dot: Panel

func _ready() -> void:
	super._ready()
	var header: HBoxContainer = HBoxContainer.new()
	content.add_child(header)
	dot = Panel.new()
	dot.custom_minimum_size = Vector2.ONE * DesignTokens.SPACE_24
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(dot)
	heading = Label.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	var close_button: IconButton = _icon("close", "Close")
	header.add_child(close_button)
	close_button.pressed.connect(close)
	warning = Label.new()
	warning.text = "Couldn't read this number with confidence. Check it against the page."
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(warning)
	rest_controls = VBoxContainer.new()
	content.add_child(rest_controls)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row.add_theme_constant_override("separation", DesignTokens.SPACE_24)
	rest_controls.add_child(row)
	var minus: IconButton = _icon("minus", "Decrease rest length")
	row.add_child(minus)
	field = LineEdit.new()
	field.custom_minimum_size = Vector2.ONE * DesignTokens.HIT_SIZE
	field.alignment = HORIZONTAL_ALIGNMENT_CENTER
	field.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	field.accessibility_name = "Rest length"
	row.add_child(field)
	var plus: IconButton = _icon("plus", "Increase rest length")
	row.add_child(plus)
	minus.pressed.connect(_step.bind(-1))
	plus.pressed.connect(_step.bind(1))
	error = Label.new()
	error.text = "Enter a whole number from 1 to 999."
	error.add_theme_color_override("font_color", DesignTokens.DANGER)
	error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rest_controls.add_child(error)
	var apply: PrimaryButton = PRIMARY.instantiate()
	apply.text = "Apply"
	rest_controls.add_child(apply)
	apply.pressed.connect(_apply)
	field.text_submitted.connect(func(_text: String) -> void: _apply())
	var delete_button: SecondaryButton = SECONDARY.instantiate()
	delete_button.text = "Delete"
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		delete_button.add_theme_color_override(state, DesignTokens.DANGER)
	content.add_child(delete_button)
	delete_button.pressed.connect(func() -> void: delete_requested.emit(data))

func _icon(icon_name: String, description: String) -> IconButton:
	var button: IconButton = ICON_BUTTON.instantiate()
	button.icon = load("res://theme/icons/%s.svg" % icon_name)
	button.tooltip_text = description
	return button

func show_detection(marker: DetectionMarker) -> void:
	data = marker.data
	heading.text = "%s\nMeasure %d" % [data.cls.left(1).to_upper() + data.cls.substr(1), data.measure_number]
	dot.add_theme_stylebox_override("panel", ThemeFactory.box(marker.class_colour(), DesignTokens.SPACE_12, 0))
	warning.visible = data.is_long_rest() and data.needs_check
	rest_controls.visible = data.is_long_rest()
	field.text = str(data.measures_spanned)
	error.hide()
	if not is_open:
		open()
	else:
		_on_resize()

func valid_length() -> bool:
	var value: String = field.text
	if value.is_empty() or value.length() > 3:
		return false
	for character: String in value:
		if character < "0" or character > "9":
			return false
	return value.to_int() >= DetectionData.MIN_REST_LENGTH and value.to_int() <= DetectionData.MAX_REST_LENGTH

func _step(amount: int) -> void:
	if not valid_length():
		error.show()
		return
	field.text = str(clampi(field.text.to_int() + amount, DetectionData.MIN_REST_LENGTH, DetectionData.MAX_REST_LENGTH))
	error.hide()

func _apply() -> void:
	if not valid_length():
		error.show()
		return
	Haptics.tap()
	data.apply_length(field.text.to_int())
	applied.emit(data)
	close()

func top_edge() -> float:
	return size.y - _sheet_height
