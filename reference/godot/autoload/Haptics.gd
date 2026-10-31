extends Node

func tap() -> void:
	_vibrate(DesignTokens.HAPTIC_TAP_MS)

func heavy() -> void:
	_vibrate(DesignTokens.HAPTIC_HEAVY_MS)

func _vibrate(duration_ms: int) -> void:
	if OS.get_name() in ["Android", "iOS"] and Settings.haptics_enabled:
		Input.vibrate_handheld(duration_ms)
