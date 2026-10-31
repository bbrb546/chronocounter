class_name Snackbar
extends Control

signal action_pressed
signal dismissed

var bottom_clearance: float = 0.0
var _watched_buttons: Array[BaseButton] = []
var _label: Label
var _action: SecondaryButton
var _timer: Timer
var _row: Control
var _tween: Tween
var _style: StyleBoxFlat

func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	_style = ThemeFactory.box(DesignTokens.SURFACE_RAISED)
	_row = Control.new()
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_row)
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_row.add_child(_label)
	_action = SecondaryButton.new()
	_row.add_child(_action)
	_action.pressed.connect(func() -> void:
		action_pressed.emit()
		dismiss())
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(dismiss)
	add_child(_timer)
	get_viewport().size_changed.connect(_place)

func show_message(message: String, action: String = "", duration: float = DesignTokens.SNACKBAR_DURATION) -> void:
	_label.text = message
	_action.text = action
	_action.visible = not action.is_empty()
	# Measure at the final width before showing, independent of container caches.
	_place()
	show()
	if _tween:
		_tween.kill()
	var target: float = position.y
	position.y += size.y + DesignTokens.SPACE_24
	_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "position:y", target, DesignTokens.SHEET_SLIDE)
	_timer.start(duration)
	_watch_buttons(get_tree().root)
	if not get_tree().node_added.is_connected(_watch_button):
		get_tree().node_added.connect(_watch_button)

func dismiss() -> void:
	var was_visible: bool = visible
	_timer.stop()
	if _tween:
		_tween.kill()
	hide()
	_disconnect_buttons()
	if was_visible:
		dismissed.emit()

func _watch_buttons(node: Node) -> void:
	_watch_button(node)
	for child: Node in node.get_children():
		_watch_buttons(child)

func _watch_button(node: Node) -> void:
	if node is BaseButton and node != _action and not node.button_down.is_connected(dismiss):
		# Dismiss on press-down, before the button can create a new snackbar.
		node.button_down.connect(dismiss)
		_watched_buttons.append(node)

func _disconnect_buttons() -> void:
	for button: BaseButton in _watched_buttons:
		if is_instance_valid(button) and button.button_down.is_connected(dismiss):
			button.button_down.disconnect(dismiss)
	_watched_buttons.clear()
	if get_tree() != null and get_tree().node_added.is_connected(_watch_button):
		get_tree().node_added.disconnect(_watch_button)

func _exit_tree() -> void:
	_disconnect_buttons()

func _place() -> void:
	var insets: Vector4 = SafeAreaContainer.viewport_insets(get_viewport_rect().size)
	var viewport_size: Vector2 = get_viewport_rect().size
	var width: float = maxf(1, viewport_size.x - insets.x - insets.z - DesignTokens.SPACE_48)
	var padding: float = DesignTokens.SPACE_24
	var action_size: Vector2 = _action.get_combined_minimum_size() if _action.visible else Vector2.ZERO
	var text_width: float = maxf(1, width - padding * 2 - action_size.x - (DesignTokens.GAP if _action.visible else 0))
	var font: Font = _label.get_theme_font("font")
	var text_height: float = font.get_multiline_string_size(_label.text, HORIZONTAL_ALIGNMENT_LEFT, text_width, _label.get_theme_font_size("font_size")).y
	var height: float = maxf(text_height, action_size.y) + padding * 2
	size = Vector2(width, height)
	position = Vector2(insets.x + DesignTokens.SIDE_MARGIN, viewport_size.y - insets.w - DesignTokens.SPACE_24 - height - bottom_clearance)
	_row.position = Vector2.ONE * padding
	_row.size = Vector2(width - padding * 2, height - padding * 2)
	# Hidden containers can postpone their first child layout. Give the label
	# its measured rectangle directly so the first message can draw immediately.
	_label.position = Vector2(0, (_row.size.y - text_height) / 2.0)
	# Clear the zero-width text layout before assigning the final rectangle.
	var message: String = _label.text
	_label.text = ""
	_label.size = Vector2(text_width, text_height)
	_label.text = message
	_label.size = Vector2(text_width, text_height)
	if _action.visible:
		_action.position = Vector2(text_width + DesignTokens.GAP, (_row.size.y - action_size.y) / 2.0)
		_action.size = action_size
	queue_redraw()

func _draw() -> void:
	if _style != null:
		draw_style_box(_style, Rect2(Vector2.ZERO, size))
