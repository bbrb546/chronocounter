class_name MarkerPicker
extends Node

signal empty_tapped

# Assign the image-space parent containing the page's markers.
@export var marker_parent: Node2D
var view_zoom: float = 1.0
var pick_radius: float = DesignTokens.MARKER_PICK_RADIUS
var _finger: int = -1
var _start: Vector2
var _started_ms: int
var _cancelled: bool = false
var _touches: Dictionary = {}


func set_view_zoom(zoom: float) -> void:
	view_zoom = maxf(zoom, 0.001)


func pick(world_point: Vector2) -> DetectionMarker:
	if marker_parent == null:
		return null
	var best: DetectionMarker = null
	var distance: float = maxf(pick_radius, DesignTokens.MARKER_PICK_RADIUS) / view_zoom
	var area: float = INF
	for child: Node in marker_parent.get_children():
		if not child is DetectionMarker or not child.is_visible_in_tree():
			continue
		var marker: DetectionMarker = child as DetectionMarker
		var candidate: float = marker.hit_distance(world_point)
		var candidate_area: float = marker.size.x * marker.size.y
		if candidate < distance or (is_equal_approx(candidate, distance) and candidate_area < area):
			best = marker
			distance = candidate
			area = candidate_area
	return best


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = true
			if _touches.size() > 1:
				_cancelled = true
			if _finger == -1:
				_finger = event.index
				_start = event.position
				_started_ms = Time.get_ticks_msec()
				_cancelled = _touches.size() > 1 or GestureState.multitouch_active
		else:
			_touches.erase(event.index)
			if event.index == _finger:
				_finish(event.position, event.canceled)
	elif event is InputEventScreenDrag and event.index == _finger:
		_cancelled = _cancelled or event.position.distance_to(_start) > DesignTokens.MARKER_TAP_SLOP
	if GestureState.multitouch_active and _finger != -1:
		_cancelled = true


func _process(_delta: float) -> void:
	if GestureState.multitouch_active and _finger != -1:
		_cancelled = true


func _finish(point: Vector2, cancelled: bool) -> void:
	var valid: bool = not cancelled and not _cancelled and not GestureState.multitouch_active
	valid = valid and point.distance_to(_start) <= DesignTokens.MARKER_TAP_SLOP
	valid = valid and Time.get_ticks_msec() - _started_ms <= DesignTokens.MARKER_TAP_MS
	_finger = -1
	if valid and marker_parent != null:
		var world: Vector2 = marker_parent.get_global_transform_with_canvas().affine_inverse() * point
		var marker: DetectionMarker = pick(world)
		if marker != null:
			marker.tap()
		else:
			empty_tapped.emit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		_touches.clear()
		_finger = -1
		_cancelled = true
