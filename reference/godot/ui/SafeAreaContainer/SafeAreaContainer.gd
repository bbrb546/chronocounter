class_name SafeAreaContainer
extends MarginContainer

@export var include_top_inset: bool = true
@export var top_padding: int = DesignTokens.SPACE_24
@export var side_margin: int = DesignTokens.SIDE_MARGIN:
	set(value):
		side_margin = value
		if is_inside_tree():
			_update_margins()

static func viewport_insets(viewport_size: Vector2) -> Vector4:
	if OS.get_name() not in ["Android", "iOS"]:
		return Vector4.ZERO
	var safe: Rect2 = Rect2(DisplayServer.get_display_safe_area())
	var window_rect: Rect2 = Rect2(Vector2(DisplayServer.window_get_position()), Vector2(DisplayServer.window_get_size()))
	var usable: Rect2 = safe.intersection(window_rect)
	if not usable.has_area() or window_rect.size.x <= 0 or window_rect.size.y <= 0:
		return Vector4.ZERO
	var scale: Vector2 = viewport_size / window_rect.size
	return Vector4(maxf(0, usable.position.x - window_rect.position.x) * scale.x,
		maxf(0, usable.position.y - window_rect.position.y) * scale.y,
		maxf(0, window_rect.end.x - usable.end.x) * scale.x,
		maxf(0, window_rect.end.y - usable.end.y) * scale.y)

func _ready() -> void:
	get_viewport().size_changed.connect(_update_margins)
	_update_margins()

func _update_margins() -> void:
	var insets: Vector4 = viewport_insets(get_viewport_rect().size)
	add_theme_constant_override("margin_left", ceili(insets.x) + side_margin)
	add_theme_constant_override("margin_top", (ceili(insets.y) if include_top_inset else 0) + top_padding)
	add_theme_constant_override("margin_right", ceili(insets.z) + side_margin)
	add_theme_constant_override("margin_bottom", ceili(insets.w) + DesignTokens.SPACE_24)
