extends RefCounted

func run() -> Array:
	var output: Array = []
	var code: int = OS.execute(OS.get_executable_path(), PackedStringArray([
		"--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--quit-after", "1800", "--script", "res://tests/capture_behavior_check.gd",
	]), output, true)
	var transcript: String = "".join(output)
	return [{"name": "Capture import, worker, layout, retake, delete, cap and discard", "passed": code == 0 and transcript.contains("CAPTURE_BEHAVIOR_COMPLETED") and not transcript.contains("ERROR:") and not transcript.contains("FAIL:"), "detail": transcript.strip_edges()}]
