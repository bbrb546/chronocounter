class_name NumberingEngine
extends RefCounted


static func number_page(lines: Array, initial: int) -> void:
	var measure_num: int = initial
	var first_counted: bool = true
	var pcls: String = "fpbar"
	for line: Array in lines:
		for detection: DetectionData in line:
			detection.measure_number = measure_num
			if detection.is_long_rest():
				first_counted = false
				measure_num += detection.measures_spanned
			elif detection.is_bar():
				if not first_counted and pcls in ["bar", "repeat bar", "double bar", "pbar", "fpbar"]:
					measure_num += 1
				detection.measure_number = measure_num
				first_counted = false
			pcls = detection.cls
		pcls = "pbar"


# page_index is zero-based, matching AppState.current_page_index.
static func resolve_initial(lines: Array, page_index: int, prev_end: int, pickup: bool) -> int:
	var first: DetectionData = _first_detection(lines)
	var starts_with_rest: bool = first != null and first.is_long_rest()
	if page_index == 0:
		return 1 if pickup or starts_with_rest else 2
	return prev_end if starts_with_rest else prev_end + 1


static func end_value(lines: Array, initial: int) -> int:
	for index: int in range(lines.size() - 1, -1, -1):
		var line: Array = lines[index]
		if not line.is_empty():
			var last: DetectionData = line.back()
			return last.end_measure()
	return initial - 1


static func line_start_labels(lines: Array) -> Array:
	var labels: Array[int] = []
	var previous: DetectionData = null
	for line: Array in lines:
		if line.is_empty():
			labels.append(-1)
			continue
		var first: DetectionData = line.front()
		if previous != null:
			labels.append(previous.end_measure())
		else:
			labels.append(first.measure_number if first.is_long_rest() else first.measure_number - 1)
		previous = line.back()
	return labels


static func number_all_pages(pages: Array, pickup: bool) -> void:
	var prev_end: int = 0
	for index: int in range(pages.size()):
		var page: PhotoPage = pages[index]
		page.initial_measure_number = resolve_initial(page.lines, index, prev_end, pickup)
		number_page(page.lines, page.initial_measure_number)
		prev_end = end_value(page.lines, page.initial_measure_number)


static func _first_detection(lines: Array) -> DetectionData:
	for line: Array in lines:
		if not line.is_empty():
			return line.front()
	return null
