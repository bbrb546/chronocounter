extends RefCounted

func run() -> Array:
	var cases: Array = []
	for pair_name: String in DesignTokens.TEXT_PAIRS:
		var pair: Array = DesignTokens.TEXT_PAIRS[pair_name]
		var ratio: float = _contrast(pair[0], pair[1])
		cases.append(_case("Contrast: " + pair_name, ratio >= 4.5, "%.2f:1 (minimum 4.5:1)" % ratio))
	var theme: Theme = load("res://theme/app_theme.tres")
	cases.append(_case("Project theme", ProjectSettings.get_setting("gui/theme/custom") == "res://theme/app_theme.tres", "Shared theme is the project default"))
	cases.append(_case("Clear colour", ProjectSettings.get_setting("rendering/environment/defaults/default_clear_color").is_equal_approx(DesignTokens.BG), "Matches BG"))
	for name: String in ["PrimaryButton", "SecondaryButton", "IconButton", "Pill", "BottomSheet", "Snackbar", "ConfirmDialog", "Spinner", "SafeAreaContainer"]:
		var packed: PackedScene = load("res://ui/%s/%s.tscn" % [name, name])
		var instance: Node = packed.instantiate()
		instance.set("theme", theme)
		Engine.get_main_loop().root.add_child(instance)
		_check_targets(instance, name, cases)
		instance.free()
	for path: String in ["res://scenes/main_menu/main_menu.tscn", "res://scenes/capture/capture.tscn", "res://scenes/results/results.tscn", "res://tests/ui_gallery.tscn"]:
		var packed: PackedScene = load(path)
		var screen: Node = packed.instantiate()
		Engine.get_main_loop().root.add_child(screen)
		_check_targets(screen, path.get_file(), cases)
		cases.append(_case("Safe area: " + path.get_file(), _has_safe_area(screen), "Every screen wraps its UI"))
		screen.free()
	# Native controls also receive the touch minimum, including disabled states.
	for kind: String in ["CheckButton", "LineEdit"]:
		var control: Control = ClassDB.instantiate(kind)
		control.theme = theme
		control.custom_minimum_size = Vector2.ONE * DesignTokens.HIT_SIZE
		_check_targets(control, kind, cases)
		control.free()
	return cases

func _check_targets(node: Node, prefix: String, cases: Array) -> void:
	if node is BaseButton or node is LineEdit or node.is_in_group("touch_targets"):
		var size: Vector2 = node.get_combined_minimum_size()
		cases.append(_case("Touch target: %s/%s" % [prefix, node.name], size.x >= DesignTokens.HIT_SIZE and size.y >= DesignTokens.HIT_SIZE, "%s (minimum 144 × 144)" % size))
	for child: Node in node.get_children():
		_check_targets(child, prefix, cases)

func _has_safe_area(node: Node) -> bool:
	if node is SafeAreaContainer:
		return true
	for child: Node in node.get_children():
		if _has_safe_area(child):
			return true
	return false

func _linear(value: float) -> float:
	return value / 12.92 if value <= 0.04045 else pow((value + 0.055) / 1.055, 2.4)

func _luminance(color: Color) -> float:
	return 0.2126 * _linear(color.r) + 0.7152 * _linear(color.g) + 0.0722 * _linear(color.b)

func _contrast(foreground: Color, background: Color) -> float:
	var a: float = _luminance(foreground)
	var b: float = _luminance(background)
	return (maxf(a, b) + 0.05) / (minf(a, b) + 0.05)

func _case(name: String, passed: bool, detail: String) -> Dictionary:
	return {"name": name, "passed": passed, "detail": detail}
