extends RefCounted

func run() -> Array:
	# SPEC's synchronous run() contract is preserved; a bounded child engine
	# exercises time-based UI behaviour and real viewport event routing.
	var output: Array = []
	var exit_code: int = OS.execute(OS.get_executable_path(), PackedStringArray([
		"--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--quit-after", "1800", "--script", "res://tests/ui_behavior_check.gd",
	]), output, true)
	var transcript: String = "".join(output)
	return [{"name": "UI behaviour: sheets, snackbar, confirmation, settings and router", "passed": exit_code == 0 and transcript.contains("UI_BEHAVIOR_COMPLETED") and not transcript.contains("ERROR:") and not transcript.contains("FAIL:"), "detail": transcript.strip_edges()}]
