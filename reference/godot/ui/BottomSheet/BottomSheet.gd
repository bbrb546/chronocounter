class_name BottomSheet
extends Control

signal opened
signal closed

@export var modal: bool = true:
	set(value):
		modal = value
		if is_node_ready():
			_scrim.visible = modal
@export var side_margin: int = DesignTokens.SIDE_MARGIN
@export var focus_text_fields_on_open: bool = true

var content: VBoxContainer
var is_open: bool = false
var _scrim: ColorRect
var _panel: PanelContainer
var _handle_mark: Panel
var _tween: Tween
var _drag_start: float = -1.0
var _drag_offset: float = 0.0
var _sheet_height: float = 0.0
var _target_y: float = 0.0
var _previous_focus: Control

func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_to_group("dismissible_overlays")
	_scrim = ColorRect.new()
	_scrim.color = DesignTokens.SCRIM
	_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_scrim)
	_scrim.gui_input.connect(_on_scrim_input)
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style: StyleBoxFlat = ThemeFactory.box(DesignTokens.SURFACE, 0, 0)
	style.corner_radius_top_left = DesignTokens.SHEET_RADIUS
	style.corner_radius_top_right = DesignTokens.SHEET_RADIUS
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	var safe: SafeAreaContainer = SafeAreaContainer.new()
	safe.side_margin = side_margin
	safe.include_top_inset = false
	safe.top_padding = 0
	_panel.add_child(safe)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", DesignTokens.SPACE_12)
	safe.add_child(stack)
	var handle: Control = Control.new()
	handle.custom_minimum_size = Vector2(DesignTokens.HIT_SIZE, DesignTokens.HIT_SIZE)
	handle.mouse_default_cursor_shape = Control.CURSOR_DRAG
	handle.gui_input.connect(_on_handle_input)
	var handle_margin: MarginContainer = MarginContainer.new()
	handle_margin.add_theme_constant_override("margin_left", DesignTokens.GESTURE_MARGIN - side_margin)
	handle_margin.add_theme_constant_override("margin_right", DesignTokens.GESTURE_MARGIN - side_margin)
	stack.add_child(handle_margin)
	handle_margin.add_child(handle)
	handle.add_to_group("touch_targets")
	_handle_mark = Panel.new()
	_handle_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_handle_mark.add_theme_stylebox_override("panel", ThemeFactory.box(DesignTokens.TEXT_PRIMARY, DesignTokens.SPACE_12, 0))
	handle.add_child(_handle_mark)
	handle.resized.connect(func() -> void:
		_handle_mark.size = Vector2(DesignTokens.SPACE_72, DesignTokens.ICON_STROKE)
		_handle_mark.position = Vector2((handle.size.x - _handle_mark.size.x) / 2.0, DesignTokens.SPACE_12))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	stack.add_child(scroll)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", DesignTokens.SPACE_24)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	content.minimum_size_changed.connect(func() -> void: _on_resize.call_deferred())
	resized.connect(_on_resize)
	get_viewport().size_changed.connect(_on_resize)

func open() -> void:
	_previous_focus = get_viewport().gui_get_focus_owner()
	is_open = true
	visible = true
	_scrim.visible = modal
	_refresh_geometry()
	_panel.position.y = size.y
	_slide_to(size.y - _sheet_height)
	_focus_first(content)
	opened.emit()

func close() -> void:
	if not is_open:
		return
	is_open = false
	_slide_to(size.y)
	_tween.finished.connect(func() -> void:
		if not is_open:
			hide()
			if is_instance_valid(_previous_focus):
				_previous_focus.grab_focus()
			closed.emit(), CONNECT_ONE_SHOT)

func _refresh_geometry() -> void:
	var insets: Vector4 = SafeAreaContainer.viewport_insets(get_viewport_rect().size)
	var natural: float = content.get_combined_minimum_size().y + DesignTokens.HIT_SIZE + DesignTokens.SPACE_12 + DesignTokens.SPACE_24 + insets.w
	_sheet_height = minf(natural, maxf(0, size.y - insets.y - DesignTokens.SPACE_24))
	_panel.size = Vector2(size.x, _sheet_height)
	_panel.position.x = 0

func _on_resize() -> void:
	if not is_open:
		return
	_refresh_geometry()
	var target: float = size.y - _sheet_height
	if is_equal_approx(target, _target_y):
		return
	if _tween and _tween.is_running():
		_slide_to(target)
	else:
		_target_y = target
		_panel.position.y = target

func _slide_to(y: float) -> void:
	_target_y = y
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_panel, "position:y", y, DesignTokens.SHEET_SLIDE)

func _on_scrim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		close()
		accept_event()

func _on_handle_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_drag_start = event.global_position.y
			_drag_offset = 0
			if _tween:
				_tween.kill()
		elif _drag_start >= 0:
			_drag_start = -1
			if _drag_offset >= DesignTokens.GESTURE_MARGIN:
				close()
			else:
				_slide_to(size.y - _sheet_height)
	elif event is InputEventMouseMotion and _drag_start >= 0:
		_drag_offset = maxf(0, event.global_position.y - _drag_start)
		_panel.position.y = size.y - _sheet_height + _drag_offset

func _focus_first(node: Node) -> bool:
	if node is LineEdit and not focus_text_fields_on_open:
		return false
	if node is Control and node.focus_mode == Control.FOCUS_ALL and node.is_visible_in_tree():
		node.grab_focus()
		return true
	for child: Node in node.get_children():
		if _focus_first(child):
			return true
	return false
