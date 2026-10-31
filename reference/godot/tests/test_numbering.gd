extends RefCounted

var cases: Array = []


func check(name: String, passed: bool, detail: String = "") -> void:
	cases.append({"name": name, "passed": passed, "detail": detail})


func run() -> Array:
	_page_case("A", "B,B,B/B,B", 1, [[1,2,3],[4,5]], 5, [0,3])
	_page_case("B1 server parity", "R4,B,B/B,RB2,B", 2, [[2,6,7],[8,8,10]], 10, [2,7])
	_page_case("B2 resolved initial", "R4,B,B/B,RB2,B", 1, [[1,5,6],[7,7,9]], 9, [1,6])
	_page_case("D", "B,R3/B,B", 1, [[1,1],[5,6]], 6, [0,4])
	_page_case("G", "B,R2", 2, [[2,2]], 4, [1])
	var edited_lines: Array = _lines("B,B,B/B,B")
	edited_lines[0].remove_at(1)
	NumberingEngine.number_page(edited_lines, 1)
	check("Edit deletes second bar", _numbers(edited_lines) == [[1,2],[3,4]] and NumberingEngine.end_value(edited_lines, 1) == 4 and NumberingEngine.line_start_labels(edited_lines) == [0,2])
	check("Page 1 ignores previous end", NumberingEngine.resolve_initial(_lines("B,R2"), 0, 83, false) == 2 and NumberingEngine.resolve_initial(_lines("R4,B"), 0, 83, false) == 1 and NumberingEngine.resolve_initial(_lines("B"), 0, 83, true) == 1)
	_chain("Chain 1", ["B,B,B/B,B", "B,B/B", "R2,B"], true, [1,6,8], [[[1,2,3],[4,5]],[[6,7],[8]],[[8,10]]], [5,8,10], [[0,3],[5,7],[8]])
	_chain("Chain 2", ["B,B,B/B,B", "", "B"], true, [1,6,6], [[[1,2,3],[4,5]],[],[[6]]], [5,5,6], [[0,3],[],[5]])
	_chain("Chain 3", ["R4,B", "B"], false, [1,6], [[[1,5]],[[6]]], [5,6], [[1],[5]])
	_page_case("Empty lines preserve count and labels", "/B,R2//B/", 1, [[],[1,1],[],[4],[]], 4, [-1,0,-1,3,-1])
	_page_case("Entirely empty page", "//", 6, [[],[],[]], 5, [-1,-1,-1])
	_page_case("All bar classes", "B,repeat bar,double bar/R2,double bar,repeat bar", 1, [[1,2,3],[3,5,6]], 6, [0,3])
	_test_edits()
	_parity()
	return cases


func _lines(notation: String) -> Array:
	var lines: Array = []
	if notation.is_empty():
		return lines
	for row: String in notation.split("/"):
		var line: Array[DetectionData] = []
		for token: String in row.split(",", false):
			var cls: String = "bar" if token == "B" else token
			var length: int = 0
			if token.begins_with("R"):
				cls = "long rest bottom" if token.begins_with("RB") else "long rest"
				length = int(token.substr(2 if token.begins_with("RB") else 1))
			line.append(DetectionData.from_json({"class": cls, "measures_spanned": length}))
		lines.append(line)
	return lines


func _numbers(lines: Array) -> Array:
	var result: Array = []
	for line: Array in lines:
		var numbers: Array[int] = []
		for detection: DetectionData in line:
			numbers.append(detection.measure_number)
		result.append(numbers)
	return result


func _page_case(name: String, notation: String, initial: int, expected: Array, end: int, labels: Array) -> void:
	var lines: Array = _lines(notation)
	NumberingEngine.number_page(lines, initial)
	check(name, _numbers(lines) == expected and NumberingEngine.end_value(lines, initial) == end and NumberingEngine.line_start_labels(lines) == labels, str(_numbers(lines)))


func _chain(name: String, notations: Array, pickup: bool, initials: Array, numbers: Array, ends: Array, labels: Array) -> void:
	var pages: Array[PhotoPage] = []
	for notation: String in notations:
		var page: PhotoPage = PhotoPage.new()
		page.lines = _lines(notation)
		pages.append(page)
	NumberingEngine.number_all_pages(pages, pickup)
	for index: int in range(pages.size()):
		var page: PhotoPage = pages[index]
		var actual_labels: Array = NumberingEngine.line_start_labels(page.lines)
		check("%s page %d" % [name, index + 1], page.initial_measure_number == initials[index] and _numbers(page.lines) == numbers[index] and NumberingEngine.end_value(page.lines, page.initial_measure_number) == ends[index] and actual_labels == labels[index])
		for line_index: int in range(page.lines.size()):
			if page.lines[line_index].is_empty():
				continue
			var first: DetectionData = page.lines[line_index][0]
			var expected: int = first.measure_number if first.is_long_rest() else first.measure_number - 1
			if index > 0:
				expected = NumberingEngine.end_value(pages[index - 1].lines, pages[index - 1].initial_measure_number)
			check("%s page %d first-label invariant" % [name, index + 1], actual_labels[line_index] == expected)
			break


func _test_edits() -> void:
	var chain: Array[PhotoPage] = []
	for notation: String in ["B,B,B/B,B", "B,B/B", "R2,B"]:
		var page: PhotoPage = PhotoPage.new()
		page.lines = _lines(notation)
		chain.append(page)
	NumberingEngine.number_all_pages(chain, true)
	var before: int = chain[1].initial_measure_number
	chain[0].lines[0].remove_at(1)
	NumberingEngine.number_all_pages(chain, true)
	var page_one_end: int = NumberingEngine.end_value(chain[0].lines, chain[0].initial_measure_number)
	check("Chain 1 delete on page 1 renumbers page 2", before == 6 and page_one_end == 4 and chain[1].initial_measure_number == 5 and _numbers(chain[0].lines) == [[1,2],[3,4]] and _numbers(chain[1].lines) == [[5,6],[7]] and chain[2].initial_measure_number == 7 and _numbers(chain[2].lines) == [[7,9]], "page 1 end: %d; page 2 initial: %d -> %d; page 3 initial: %d" % [page_one_end, before, chain[1].initial_measure_number, chain[2].initial_measure_number])
	var first: PhotoPage = PhotoPage.new()
	first.lines = _lines("B,R2")
	var second: PhotoPage = PhotoPage.new()
	second.lines = _lines("B")
	var pages: Array[PhotoPage] = [first, second]
	NumberingEngine.number_all_pages(pages, false)
	var rest: DetectionData = first.lines[0][1]
	rest.apply_length(4)
	NumberingEngine.number_all_pages(pages, false)
	check("Length edit renumbers later pages", second.initial_measure_number == 7 and _numbers(second.lines) == [[7]])
	first.lines[0].remove_at(0)
	NumberingEngine.number_all_pages(pages, false)
	check("Deleting first bar resolves page initial again", first.initial_measure_number == 1 and _numbers(first.lines) == [[1]] and second.initial_measure_number == 6)


func _parity() -> void:
	var directory: DirAccess = DirAccess.open("res://fixtures")
	check("Parity fixture directory exists", directory != null)
	if directory == null:
		return
	var fixture_count: int = 0
	for filename: String in directory.get_files():
		if not filename.begins_with("predictions_") or not filename.ends_with(".json"):
			continue
		fixture_count += 1
		var initial_text: String = filename.trim_prefix("predictions_").trim_suffix(".json")
		var json: JSON = JSON.new()
		var error: Error = json.parse(FileAccess.get_file_as_string("res://fixtures/" + filename))
		check(filename + " parses", error == OK and json.data is Array and initial_text.is_valid_int())
		if error != OK or not json.data is Array or not initial_text.is_valid_int():
			continue
		var lines: Array = []
		for row: Array in json.data:
			var line: Array[DetectionData] = []
			for dict: Dictionary in row:
				line.append(DetectionData.from_json(dict))
			lines.append(line)
		NumberingEngine.number_page(lines, int(initial_text))
		var total: int = 0
		var rest_count: int = 0
		var mismatches: Array[String] = []
		for line_index: int in range(lines.size()):
			for detection_index: int in range(lines[line_index].size()):
				var detection: DetectionData = lines[line_index][detection_index]
				total += 1
				if detection.is_long_rest():
					rest_count += 1
				if detection.measure_number != detection.server_measure_number:
					mismatches.append("line %d detection %d: computed %d, server %d" % [line_index, detection_index, detection.measure_number, detection.server_measure_number])
		check(filename + " server parity", mismatches.is_empty() and total > 0, "%d detections, %d long rests; %s" % [total, rest_count, "; ".join(mismatches)])
	check("Parity fixtures found", fixture_count > 0, str(fixture_count))
