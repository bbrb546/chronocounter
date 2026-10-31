extends Camera2D

signal view_zoom_changed(value: float)

func fit_to_screen(image_size: Vector2, image_area: Rect2) -> void:
	if image_size.x <= 0 or image_size.y <= 0 or not image_area.has_area():
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	var value: float = minf(image_area.size.x / image_size.x, image_area.size.y / image_size.y)
	zoom = Vector2.ONE * value
	var image_origin: Vector2 = image_area.position
	image_origin += (image_area.size - image_size * value) / 2.0
	position = (viewport_size / 2.0 - image_origin) / value
	view_zoom_changed.emit(value)
