extends RefCounted

func run() -> Array:
	var output: Array = []
	var code: int = OS.execute(OS.get_executable_path(), PackedStringArray([
		"--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--quit-after", "2400", "--script", "res://tests/processing_behavior_check.gd",
	]), output, true)
	var transcript: String = "".join(output)
	return [{"name": "Ordered processing, retry, mock pairs and cancellation", "passed": code == 0 and transcript.contains("PROCESSING_BEHAVIOR_COMPLETED") and not transcript.contains("ERROR:") and not transcript.contains("FAIL:"), "detail": transcript.strip_edges()}]
