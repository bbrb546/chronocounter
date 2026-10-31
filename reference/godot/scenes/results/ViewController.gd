extends Camera2D

signal view_zoom_changed(value: float)

const MIN_FIT_RATIO: float = 0.5
const MAX_ZOOM: float = 8.0
const MIN_VISIBLE_RATIO: float = 0.25
const WHEEL_FACTOR: float = 1.15

var marker_picker: MarkerPicker
var ui_root: Node
var _image_size: Vector2
var _image_area: Rect2
var _fit_zoom: float = 1.0
var _touches: Dictionary = {}
var _excluded: Dictionary = {}
var _starts: Dictionary = {}
var _single_pan: Dictionary = {}
var _mouse_button: int = 0

func fit_to_screen(image_size: Vector2 = _image_size, image_area: Rect2 = _image_area) -> void:
	_image_size = image_size
	_image_area = image_area
	if image_size.x <= 0 or image_size.y <= 0 or not image_area.has_area():
		return
	_fit_zoom = minf(image_area.size.x / image_size.x, image_area.size.y / image_size.y)
	var value: float = minf(_fit_zoom, MAX_ZOOM)
	var origin: Vector2 = image_area.position + (image_area.size - image_size * value) / 2.0
	position = (get_viewport_rect().size / 2.0 - origin) / value
	var unchanged: bool = is_equal_approx(zoom.x, value)
	_set_zoom(value)
	if unchanged:
		view_zoom_changed.emit(value)
	force_update_scroll()

func _set_zoom(value: float) -> void:
	var changed: bool = not is_equal_approx(zoom.x, value)
	zoom = Vector2.ONE * value
	if changed:
		view_zoom_changed.emit(value)

func _transform_view(previous: Vector2, current: Vector2, ratio: float) -> void:
	if _image_size == Vector2.ZERO:
		return
	force_update_scroll()
	var anchor: Vector2 = get_canvas_transform().affine_inverse() * previous
	var value: float = clampf(zoom.x * ratio, minf(_fit_zoom * MIN_FIT_RATIO, MAX_ZOOM), MAX_ZOOM)
	_set_zoom(value)
	position = anchor - (current - get_viewport_rect().size / 2.0) / value
	clamp_to_image()
	force_update_scroll()

func clamp_to_image() -> void:
	# Retain at least 25% of image area, or fill the viewport when zoomed in.
	var extent: Vector2 = get_viewport_rect().size / zoom
	var retained: Vector2 = (_image_size * sqrt(MIN_VISIBLE_RATIO)).min(extent)
	position = position.clamp(retained - extent / 2.0, _image_size - retained + extent / 2.0)

func _over_ui(node: Node, point: Vector2) -> bool:
	if node == null:
		return false
	if node is Control:
		var control: Control = node as Control
		if not control.is_visible_in_tree():
			return false
		if control.mouse_filter != Control.MOUSE_FILTER_IGNORE and control.get_global_rect().has_point(point):
			return true
	for child: Node in node.get_children():
		if _over_ui(child, point):
			return true
	return false

func _on_detection(point: Vector2) -> bool:
	if marker_picker == null or marker_picker.marker_parent == null:
		return false
	var world: Vector2 = marker_picker.marker_parent.get_global_transform_with_canvas().affine_inverse() * point
	return marker_picker.pick(world) != null

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
			_excluded[event.index] = _over_ui(ui_root, event.position)
			_starts[event.index] = event.position
			_single_pan[event.index] = not _on_detection(event.position)
		else:
			_touches.erase(event.index)
			_excluded.erase(event.index)
			_starts.erase(event.index)
			_single_pan.erase(event.index)
		GestureState.update_touch(event.index, event.pressed)
	elif event is InputEventScreenDrag and _touches.has(event.index):
		var keys: Array = _touches.keys()
		var can_move: bool = keys.size() == 2
		for key: int in keys:
			can_move = can_move and not _excluded[key]
		var previous: Vector2
		var distance: float = 0.0
		if can_move:
			previous = (_touches[keys[0]] + _touches[keys[1]]) / 2.0
			distance = (_touches[keys[0]] as Vector2).distance_to(_touches[keys[1]])
		var last_point: Vector2 = _touches[event.index]
		_touches[event.index] = event.position
		if keys.size() == 1 and not _excluded[event.index] and _single_pan[event.index]:
			if event.position.distance_to(_starts[event.index]) > DesignTokens.MARKER_TAP_SLOP:
				_transform_view(last_point, event.position, 1.0)
		if can_move:
			var midpoint: Vector2 = (_touches[keys[0]] + _touches[keys[1]]) / 2.0
			var next_distance: float = (_touches[keys[0]] as Vector2).distance_to(_touches[keys[1]])
			_transform_view(previous, midpoint, next_distance / distance if distance > 0.0 else 1.0)
	elif event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT]:
			if not event.pressed:
				_mouse_button = 0
			elif not _over_ui(ui_root, event.position):
				_mouse_button = event.button_index
		elif event.pressed and not _over_ui(ui_root, event.position):
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_transform_view(event.position, event.position, WHEEL_FACTOR)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_transform_view(event.position, event.position, 1.0 / WHEEL_FACTOR)
	elif event is InputEventMouseMotion and _mouse_button != 0:
		_transform_view(event.position - event.relative, event.position, 1.0)

func _exit_tree() -> void:
	for index: int in _touches:
		GestureState.update_touch(index, false)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		_touches.clear()
		_excluded.clear()
		_starts.clear()
		_single_pan.clear()
		_mouse_button = 0
