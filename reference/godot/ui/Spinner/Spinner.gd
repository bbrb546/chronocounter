class_name Spinner
extends Control

var _angle: float = 0.0

func _init() -> void:
	custom_minimum_size = Vector2.ONE * DesignTokens.ICON_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	if is_visible_in_tree():
		_angle = fmod(_angle + delta * TAU / DesignTokens.SPINNER_PERIOD, TAU)
		queue_redraw()

func _draw() -> void:
	var radius: float = minf(size.x, size.y) / 2.0 - DesignTokens.ICON_STROKE
	draw_arc(size / 2.0, radius, _angle, _angle + DesignTokens.SPINNER_SWEEP,
		DesignTokens.SPINNER_SEGMENTS, DesignTokens.ACCENT, DesignTokens.ICON_STROKE, true)
