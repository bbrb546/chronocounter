extends RefCounted

func run() -> Array:
	var api: Node = (Engine.get_main_loop() as SceneTree).root.get_node("ApiClient")
	var valid: Dictionary = {"class": "long rest", "x": 1, "y": 2, "width": 3, "height": 4, "measure_number": 2, "measures_spanned": 5, "measures_spanned_confident": false}
	var parsed: Dictionary = api.parse_detections(JSON.stringify([[valid]]))
	var good: bool = parsed.ok and parsed.lines[0][0].needs_check and parsed.lines[0][0].server_measure_number == 2
	var rejected: bool = true
	for invalid: String in ['{', '{}', '[{}]', '[[null]]']:
		rejected = rejected and not api.parse_detections(invalid).ok
	for key: String in ["class", "x", "y", "width", "height", "measure_number"]:
		var missing: Dictionary = valid.duplicate()
		missing.erase(key)
		rejected = rejected and not api.parse_detections(JSON.stringify([[missing]])).ok
	for key: String in ["x", "measure_number", "measures_spanned_confident", "measures_spanned"]:
		var wrong: Dictionary = valid.duplicate()
		wrong[key] = "wrong"
		rejected = rejected and not api.parse_detections(JSON.stringify([[wrong]])).ok
	var legacy: Dictionary = valid.duplicate()
	legacy.erase("measures_spanned_confident")
	var legacy_result: Dictionary = api.parse_detections(JSON.stringify([[legacy]]))
	return [
		{"name": "Strict API JSON parsing", "passed": good and rejected and legacy_result.ok and not legacy_result.lines[0][0].needs_check, "detail": "Required keys, shapes, types and optional confidence validated"},
		{"name": "API error messages", "passed": api.status_message(400).contains("read") and api.status_message(413).contains("10 MB") and api.status_message(415).contains("format") and api.status_message(503).contains("not ready"), "detail": "Friendly messages for all specified statuses"},
	]
