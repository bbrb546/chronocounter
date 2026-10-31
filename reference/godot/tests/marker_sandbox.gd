extends Control

const MARKER: PackedScene = preload("res://scenes/detection_marker/detection_marker.tscn")
const PAPER_SIZE: Vector2 = Vector2(900, 1100)
var page: Node2D
var picker: MarkerPicker
var markers: Array[DetectionMarker] = []
var status: Label
var zoom_label: Label
var checked_rest: DetectionData


func _ready() -> void:
	page = Node2D.new()
	page.position = Vector2(DesignTokens.SPACE_72, DesignTokens.SPACE_72)
	add_child(page)
	var paper: ColorRect = ColorRect.new()
	paper.color = DesignTokens.CAPTURE_WHITE
	paper.size = PAPER_SIZE
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(paper)
	picker = MarkerPicker.new()
	picker.marker_parent = page
	add_child(picker)
	var classes: Array[String] = ["bar", "repeat bar", "double bar", "long rest", "long rest bottom"]
	for i: int in range(classes.size()):
		_add_marker(classes[i], Vector2(180 + i * 130, 160 + i * 130), Vector2(20 + i * 20, 100 - i * 12), i + 1, i + 2)
	_add_marker("bar", Vector2(250, 850), Vector2(6, 120), 12, 0)
	_add_marker("bar", Vector2(620, 850), Vector2(6, 120), 13, 0)
	_add_marker("double bar", Vector2(660, 850), Vector2(6, 120), 14, 0)
	checked_rest = markers[3].data
	checked_rest.needs_check = true
	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = DesignTokens.GESTURE_MARGIN
	panel.offset_right = -DesignTokens.GESTURE_MARGIN
	panel.offset_top = -DesignTokens.HIT_SIZE * 4
	panel.offset_bottom = -DesignTokens.SPACE_24
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var background: StyleBoxFlat = StyleBoxFlat.new()
	background.bg_color = DesignTokens.SURFACE
	panel.add_theme_stylebox_override("panel", background)
	add_child(panel)
	var controls: VBoxContainer = VBoxContainer.new()
	controls.add_theme_constant_override("separation", DesignTokens.SPACE_12)
	panel.add_child(controls)
	zoom_label = Label.new()
	controls.add_child(zoom_label)
	var slider: HSlider = HSlider.new()
	slider.min_value = 0.3
	slider.max_value = 1.5
	slider.step = 0.01
	slider.value = 1.0
	slider.custom_minimum_size.y = DesignTokens.HIT_SIZE
	slider.value_changed.connect(_zoom)
	controls.add_child(slider)
	var labels: CheckButton = CheckButton.new()
	labels.text = "Show class and measure labels"
	labels.custom_minimum_size.y = DesignTokens.HIT_SIZE
	labels.toggled.connect(func(value: bool) -> void:
		for marker: DetectionMarker in markers:
			marker.show_labels = value)
	controls.add_child(labels)
	var actions: HBoxContainer = HBoxContainer.new()
	controls.add_child(actions)
	for text: String in ["Change rest length", "Toggle ?"]:
		var button: Button = preload("res://ui/SecondaryButton/SecondaryButton.tscn").instantiate()
		button.text = text
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(button)
		if text == "Toggle ?":
			button.pressed.connect(func() -> void: checked_rest.needs_check = not checked_rest.needs_check)
		else:
			button.pressed.connect(func() -> void: checked_rest.measures_spanned = checked_rest.measures_spanned % 9 + 1)
	status = Label.new()
	status.text = "Tap a box or nearby paper to select it."
	controls.add_child(status)
	_zoom(1.0)


func _add_marker(cls: String, center: Vector2, extent: Vector2, measure: int, span: int) -> void:
	var data: DetectionData = DetectionData.from_json({"class": cls, "x": center.x, "y": center.y, "width": extent.x, "height": extent.y, "measure_number": measure, "measures_spanned": span})
	var marker: DetectionMarker = MARKER.instantiate()
	marker.setup(data)
	marker.tapped.connect(_selected)
	page.add_child(marker)
	markers.append(marker)


func _zoom(value: float) -> void:
	page.scale = Vector2.ONE * value
	picker.set_view_zoom(value)
	for marker: DetectionMarker in markers:
		marker.set_view_zoom(value)
	zoom_label.text = "Zoom %.2f — outlines 2 px; pick radius 96 px" % value


func _selected(selected: DetectionMarker) -> void:
	for marker: DetectionMarker in markers:
		marker.set_selected(marker == selected)
	status.text = "Selected %s, m%d" % [selected.data.cls, selected.data.measure_number]


# Desktop sandbox clicks exercise the same touch recognizer.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var touch: InputEventScreenTouch = InputEventScreenTouch.new()
		touch.index = 0
		touch.position = event.position
		touch.pressed = event.pressed
		picker._unhandled_input(touch)
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		var drag: InputEventScreenDrag = InputEventScreenDrag.new()
		drag.index = 0
		drag.position = event.position
		picker._unhandled_input(drag)
