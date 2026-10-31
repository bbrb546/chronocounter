extends RefCounted

var cases: Array = []
var change_count: int = 0


func check(name: String, passed: bool, detail: String = "") -> void:
	cases.append({"name": name, "passed": passed, "detail": detail})


func run() -> Array:
	for cls: String in ["long rest", "long rest bottom", "bar", "repeat bar", "double bar"]:
		for confidence: Variant in [false, true, null]:
			var dict: Dictionary = {"class": cls}
			if confidence != null:
				dict["measures_spanned_confident"] = confidence
			var detection: DetectionData = DetectionData.from_json(dict)
			check("%s confidence %s" % [cls, str(confidence)], detection.needs_check == (detection.is_long_rest() and confidence == false))
			check("%s default span %s" % [cls, str(confidence)], detection.measures_spanned == (1 if detection.is_long_rest() else 0))
	var rest: DetectionData = DetectionData.from_json({"id": "rest-1", "class": "long rest bottom", "x": 12.5, "y": 23.5, "width": 40.5, "height": 10.5, "measure_number": 83, "measures_spanned": 4, "measures_spanned_confident": false})
	check("API fields and center coordinates", rest.id == "rest-1" and rest.x == 12.5 and rest.y == 23.5 and rest.w == 40.5 and rest.h == 10.5 and rest.measure_number == 83 and rest.server_measure_number == 83 and not rest.edited)
	check("Rest end measure", rest.end_measure() == 87)
	rest.changed.connect(_on_changed)
	rest.apply_length(4)
	check("Applying unchanged length clears check and emits", not rest.needs_check and rest.edited and change_count == 1)
	rest.apply_length(7)
	check("Applying length updates span", rest.measures_spanned == 7 and rest.end_measure() == 90 and change_count == 2)
	rest.apply_length(0)
	check("Minimum length", rest.measures_spanned == 1)
	rest.apply_length(1000)
	check("Maximum length", rest.measures_spanned == 999)
	var bar: DetectionData = DetectionData.from_json({"class": "bar", "measure_number": 6, "measures_spanned": 99})
	bar.apply_length(4)
	check("Bar end and length", bar.is_bar() and not bar.is_long_rest() and bar.end_measure() == 6 and bar.measures_spanned == 0 and not bar.edited)
	var lines: Array = [[rest]]
	NumberingEngine.number_page(lines, 1)
	check("Renumber preserves received number and edit state", rest.measure_number == 1 and rest.server_measure_number == 83 and rest.edited and not rest.needs_check)
	return cases


func _on_changed() -> void:
	change_count += 1
