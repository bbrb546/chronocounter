class_name LineNumberOverlay
extends Node2D

var _labels: Array[Dictionary] = []
var _font: Font = ThemeDB.fallback_font


func refresh(page: PhotoPage) -> void:
	_labels.clear()
	if page != null:
		var numbers: Array = NumberingEngine.line_start_labels(page.lines)
		for index: int in range(page.lines.size()):
			var line: Array = page.lines[index]
			if line.is_empty():
				continue
			var heights: Array[float] = []
			var mean_y: float = 0.0
			for detection: DetectionData in line:
				heights.append(detection.h)
				mean_y += detection.y
			heights.sort()
			var middle: int = heights.size() / 2
			var median: float = heights[middle]
			if heights.size() % 2 == 0:
				median = (heights[middle - 1] + heights[middle]) / 2.0
			var font_size: int = roundi(clampf(median * DesignTokens.LINE_NUMBER_HEIGHT_RATIO,
				DesignTokens.LINE_NUMBER_MIN_SIZE, DesignTokens.LINE_NUMBER_MAX_SIZE))
			# Canvas text uses a baseline; center the font's ascent/descent on mean y.
			var baseline: float = mean_y / line.size() + (_font.get_ascent(font_size) - _font.get_descent(font_size)) / 2.0
			_labels.append({"text": str(numbers[index]), "font_size": font_size,
				"position": Vector2(DesignTokens.LINE_NUMBER_LEFT, baseline)})
	queue_redraw()


func _draw() -> void:
	for label: Dictionary in _labels:
		draw_string_outline(_font, label.position, label.text, HORIZONTAL_ALIGNMENT_LEFT,
			-1, label.font_size, DesignTokens.LINE_NUMBER_HALO, DesignTokens.TEXT_PRIMARY)
		draw_string(_font, label.position, label.text, HORIZONTAL_ALIGNMENT_LEFT,
			-1, label.font_size, DesignTokens.BG)
