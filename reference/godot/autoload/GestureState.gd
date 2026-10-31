extends Node

const MULTITOUCH_COOLDOWN_MS: int = 150
var multitouch_active: bool = false
var _touches: Dictionary = {}
var _clear_at: int = 0

func update_touch(index: int, pressed: bool) -> void:
	if pressed:
		_touches[index] = true
		_clear_at = 0
		if _touches.size() >= 2:
			multitouch_active = true
	else:
		_touches.erase(index)
		if _touches.is_empty() and multitouch_active:
			_clear_at = Time.get_ticks_msec() + MULTITOUCH_COOLDOWN_MS

func _process(_delta: float) -> void:
	if _clear_at > 0 and Time.get_ticks_msec() >= _clear_at:
		multitouch_active = false
		_clear_at = 0

func reset() -> void:
	_touches.clear()
	multitouch_active = false
	_clear_at = 0

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		reset()
