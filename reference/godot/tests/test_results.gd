extends RefCounted

func run() -> Array:
	var output: Array = []
	var code: int = OS.execute(OS.get_executable_path(), PackedStringArray([
		"--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--quit-after", "2400", "--script", "res://tests/results_behavior_check.gd",
	]), output, true)
	var transcript: String = "".join(output)
	return [{"name": "Results paging, image-space fit, labels and stale decode", "passed": code == 0 and transcript.contains("RESULTS_BEHAVIOR_COMPLETED") and not transcript.contains("ERROR:"), "detail": transcript.strip_edges()}]
