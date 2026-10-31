extends SceneTree

func _initialize() -> void:
	var error: Error = ResourceSaver.save(ThemeFactory.build(), "res://theme/app_theme.tres")
	quit(0 if error == OK else 1)
