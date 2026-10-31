class_name DetectionMarker
extends Control

signal tapped(marker: DetectionMarker)

var data: DetectionData
var view_zoom: float = 1.0
var selected: bool = false
var show_labels: bool = false:
	set(value):
		show_labels = value
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(detection: DetectionData) -> void:
	if data != null and data.changed.is_connected(refresh):
		data.changed.disconnect(refresh)
	data = detection
	data.changed.connect(refresh)
	refresh()


func refresh() -> void:
	if data != null:
		position = Vector2(data.x - data.w / 2.0, data.y - data.h / 2.0)
		size = Vector2(data.w, data.h)
	queue_redraw()


func set_view_zoom(zoom: float) -> void:
	view_zoom = maxf(zoom, 0.001)
	queue_redraw()


func set_selected(value: bool) -> void:
	selected = value
	queue_redraw()


func tap() -> void:
	tapped.emit(self)


# world_point uses image coordinates, shared with this marker's parent.
func hit_distance(world_point: Vector2) -> float:
	var local: Vector2 = world_point - position
	return local.distance_to(local.clamp(Vector2.ZERO, size))


func class_colour() -> Color:
	match data.cls:
		"bar": return DesignTokens.BAR
		"repeat bar": return DesignTokens.REPEAT_BAR
		"double bar": return DesignTokens.DOUBLE_BAR
		"long rest": return DesignTokens.LONG_REST
		"long rest bottom": return DesignTokens.LONG_REST_BOTTOM
	return DesignTokens.TEXT_PRIMARY


func badge_text() -> String:
	return "×%d%s" % [data.measures_spanned, " ?" if data.needs_check else ""]


func _draw() -> void:
	if data == null:
		return
	var box: Rect2 = Rect2(Vector2.ZERO, size)
	var colour: Color = class_colour()
	draw_rect(box, Color(colour, DesignTokens.MARKER_FILL_ALPHA))
	if selected:
		draw_rect(box, DesignTokens.BG, false, (DesignTokens.MARKER_SELECTION + 2.0 * DesignTokens.MARKER_OUTLINE) / view_zoom)
		draw_rect(box, DesignTokens.ACCENT, false, DesignTokens.MARKER_SELECTION / view_zoom)
	else:
		draw_rect(box, colour, false, DesignTokens.MARKER_OUTLINE / view_zoom)
	if data.is_long_rest():
		var badge_center: Vector2 = Vector2(size.x / 2.0, 0.0 if data.cls == "long rest bottom" else size.y)
		_draw_pill(badge_text(), badge_center, data.needs_check, data.edited)
	if show_labels:
		var gap: float = DesignTokens.SPACE_24 / view_zoom
		_draw_pill(data.cls, Vector2(size.x / 2.0, -gap), false)
		_draw_pill("m%d" % data.measure_number, Vector2(size.x / 2.0, size.y + gap), false)


func _draw_pill(text: String, center: Vector2, highlight_question: bool, edited: bool = false) -> void:
	var font: Font = get_theme_default_font()
	var font_size: int = maxi(1, roundi(DesignTokens.MARKER_TEXT_SIZE / view_zoom))
	var extent: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var padding: Vector2 = Vector2(DesignTokens.SPACE_12, DesignTokens.SPACE_12 / 2.0) / view_zoom
	if edited:
		extent.x += DesignTokens.SPACE_24 / view_zoom
	var rect: Rect2 = Rect2(center - (extent + padding * 2.0) / 2.0, extent + padding * 2.0)
	var pill: StyleBoxFlat = StyleBoxFlat.new()
	pill.bg_color = DesignTokens.BG
	pill.set_corner_radius_all(roundi(rect.size.y / 2.0))
	draw_style_box(pill, rect)
	if edited:
		draw_circle(Vector2(rect.end.x - padding.x, center.y), DesignTokens.ICON_STROKE / view_zoom, DesignTokens.ACCENT)
	var baseline: Vector2 = Vector2(rect.position.x + padding.x, center.y + (font.get_ascent(font_size) - font.get_descent(font_size)) / 2.0)
	var prefix: String = text.trim_suffix("?") if highlight_question else text
	draw_string(font, baseline, prefix, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, DesignTokens.TEXT_PRIMARY)
	if highlight_question:
		baseline.x += font.get_string_size(prefix, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string(font, baseline, "?", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, DesignTokens.ACCENT)
