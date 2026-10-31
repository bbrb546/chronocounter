extends RefCounted

func run() -> Array:
	var output: Array = []
	var code: int = OS.execute(OS.get_executable_path(), PackedStringArray([
		"--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--quit-after", "2400", "--script", "res://tests/session_lifecycle_check.gd",
	]), output, true)
	var transcript: String = "".join(output)
	return [{"name": "Session exit, back/close, memory cleanup and interrupted processing", "passed": code == 0 and transcript.contains("SESSION_LIFECYCLE_COMPLETED") and not transcript.contains("ERROR:") and not transcript.contains("FAIL:"), "detail": transcript.strip_edges()}]
