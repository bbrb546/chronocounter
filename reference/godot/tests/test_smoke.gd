extends RefCounted


func run() -> Array:
	return [{"name": "Smoke: arithmetic", "passed": 1 + 1 == 2, "detail": "1 + 1 equals 2"}]
