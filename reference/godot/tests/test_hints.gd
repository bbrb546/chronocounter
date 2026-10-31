extends RefCounted

func run() -> Array:
	var settings: Node = Engine.get_main_loop().root.get_node("Settings")
	var saved: Dictionary = settings.hints_seen.duplicate(true)
	var host: Control = Control.new()
	Engine.get_main_loop().root.add_child(host)
	settings.hints_seen = {"seen": true}
	HintOverlay.show_once(host, "seen", "Already seen")
	var skipped: bool = host.get_child_count() == 0
	HintOverlay.show_once(host, "new", "New hint")
	HintOverlay.show_once(host, "new", "Duplicate")
	var single: bool = host.get_child_count() == 1 and host.get_child(0) is HintOverlay
	var pending: bool = not settings.hints_seen.has("new")
	host.free()
	settings.hints_seen = saved
	return [
		{"name": "Seen hints stay hidden", "passed": skipped, "detail": "Persisted keys suppress coach marks"},
		{"name": "Pending hints do not stack", "passed": single, "detail": "Repeated page requests keep one card"},
		{"name": "Hints wait for dismissal", "passed": pending, "detail": "Showing a card alone does not consume it"},
	]
