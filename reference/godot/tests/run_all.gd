extends SceneTree

const TEST_DIRECTORY: String = "res://tests"
const RUNNER_PATH: String = "res://tests/run_all.gd"
const COMPLETION_MARKER: String = "TEST_SCRIPT_COMPLETED"
const WORKER_FRAME_LIMIT: int = 600


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.size() == 2 and arguments[0] == "--test":
		_run_test(arguments[1])
		return
	var directory: DirAccess = DirAccess.open(TEST_DIRECTORY)
	if directory == null:
		print("FAIL: Cannot open test directory")
		quit(1)
		return
	var scripts: PackedStringArray = directory.get_files()
	scripts.sort()
	var failed: bool = false
	var count: int = 0
	# Each script runs in its own engine process. GDScript runtime errors do
	# not throw catchable exceptions, so also inspect stderr and completion.
	for filename: String in scripts:
		if not filename.begins_with("test_") or not filename.ends_with(".gd"):
			continue
		count += 1
		var output: Array = []
		var exit_code: int = OS.execute(OS.get_executable_path(), PackedStringArray([
			"--headless", "--path", ProjectSettings.globalize_path("res://"),
			"--quit-after", str(WORKER_FRAME_LIMIT), "--script", RUNNER_PATH,
			"--", "--test", TEST_DIRECTORY.path_join(filename),
		]), output, true)
		var transcript: String = "".join(output)
		for line: String in transcript.split("\n"):
			if line != COMPLETION_MARKER and not line.is_empty() and not line.begins_with("Godot Engine"):
				print(line)
		if exit_code != 0 or not transcript.contains(COMPLETION_MARKER) or transcript.contains("ERROR:"):
			print("FAIL: %s (script error, incomplete run, or failed case)" % filename)
			failed = true
	if count == 0:
		print("FAIL: No test scripts found")
		failed = true
	print("Test scripts: %d" % count)
	quit(1 if failed else 0)


func _run_test(path: String) -> void:
	var script: GDScript = load(path) as GDScript
	if script == null or not script.can_instantiate():
		print("FAIL: Cannot load %s" % path)
		quit(1)
		return
	var instance: Object = script.new()
	if not instance.has_method("run"):
		print("FAIL: %s has no run()" % path)
		_release(instance)
		quit(1)
		return
	var cases: Variant = instance.call("run")
	var failed: bool = false
	if not cases is Array:
		print("FAIL: %s run() must return Array" % path)
		failed = true
	else:
		for result: Variant in cases:
			if not result is Dictionary or not result.get("name") is String or not result.get("passed") is bool or not result.get("detail") is String:
				print("FAIL: %s returned a malformed case" % path)
				failed = true
				continue
			print("%s: %s — %s" % ["PASS" if result.passed else "FAIL", result.name, result.detail])
			failed = failed or not result.passed
	_release(instance)
	print(COMPLETION_MARKER)
	quit(1 if failed else 0)


func _release(instance: Object) -> void:
	if not instance is RefCounted:
		instance.free()
