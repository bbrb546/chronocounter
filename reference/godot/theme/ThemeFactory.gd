class_name ThemeFactory
extends RefCounted

static func box(fill: Color, radius: int = DesignTokens.RADIUS, padding: int = DesignTokens.SPACE_24) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(radius)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	return style

static func build() -> Theme:
	var result: Theme = Theme.new()
	result.default_font_size = DesignTokens.BODY_SIZE
	for kind: String in ["Button", "PrimaryButton", "SecondaryButton", "DangerButton", "IconButton", "CheckButton", "LineEdit", "Label"]:
		if kind in ["PrimaryButton", "SecondaryButton", "DangerButton", "IconButton"]:
			result.set_type_variation(kind, "Button")
		result.set_color("font_color", kind, DesignTokens.TEXT_PRIMARY)
		result.set_color("font_disabled_color", kind, DesignTokens.TEXT_SECONDARY)
		result.set_color("font_hover_color", kind, DesignTokens.TEXT_PRIMARY)
		result.set_color("font_pressed_color", kind, DesignTokens.TEXT_PRIMARY)
		result.set_color("font_focus_color", kind, DesignTokens.TEXT_PRIMARY)
		result.set_font_size("font_size", kind, DesignTokens.BODY_SIZE if kind in ["Label", "LineEdit"] else DesignTokens.BUTTON_SIZE)
	for kind: String in ["Button", "PrimaryButton", "SecondaryButton", "DangerButton", "IconButton", "CheckButton", "LineEdit"]:
		var fill: Color = DesignTokens.SURFACE_RAISED
		if kind == "PrimaryButton":
			fill = DesignTokens.ACCENT
		elif kind == "DangerButton":
			fill = DesignTokens.DANGER
		var normal: StyleBoxFlat = box(fill)
		# Theme-native fields/switches also have a 144px minimum height.
		if kind in ["CheckButton", "LineEdit"]:
			normal.content_margin_top = DesignTokens.SPACE_48 + DesignTokens.SPACE_12
			normal.content_margin_bottom = DesignTokens.SPACE_48 + DesignTokens.SPACE_12
		result.set_stylebox("normal", kind, normal)
		result.set_stylebox("hover", kind, normal.duplicate())
		result.set_stylebox("read_only", kind, normal.duplicate())
		var pressed: StyleBoxFlat = normal.duplicate()
		pressed.set_border_width_all(DesignTokens.ICON_STROKE)
		pressed.border_color = DesignTokens.ACCENT_INK if kind in ["PrimaryButton", "DangerButton"] else DesignTokens.ACCENT
		result.set_stylebox("pressed", kind, pressed)
		result.set_stylebox("hover_pressed", kind, pressed.duplicate())
		result.set_stylebox("disabled", kind, box(DesignTokens.SURFACE))
		var focus: StyleBoxFlat = box(Color.TRANSPARENT)
		focus.set_border_width_all(DesignTokens.ICON_STROKE)
		focus.border_color = DesignTokens.TEXT_PRIMARY
		result.set_stylebox("focus", kind, focus)
		if kind in ["PrimaryButton", "DangerButton"]:
			for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
				result.set_color(state, kind, DesignTokens.ACCENT_INK)
	result.set_color("font_placeholder_color", "LineEdit", DesignTokens.TEXT_SECONDARY)
	result.set_color("caret_color", "LineEdit", DesignTokens.ACCENT)
	result.set_color("selection_color", "LineEdit", DesignTokens.ACCENT)
	result.set_color("font_selected_color", "LineEdit", DesignTokens.ACCENT_INK)
	for state: String in ["checked", "checked_disabled", "checked_mirrored", "checked_disabled_mirrored"]:
		result.set_icon(state, "CheckButton", load("res://theme/icons/switch-on.svg"))
	for state: String in ["unchecked", "unchecked_disabled", "unchecked_mirrored", "unchecked_disabled_mirrored"]:
		result.set_icon(state, "CheckButton", load("res://theme/icons/switch-off.svg"))
	result.set_color("icon_disabled_color", "IconButton", DesignTokens.TEXT_SECONDARY)
	result.set_color("icon_normal_color", "CheckButton", DesignTokens.TEXT_PRIMARY)
	result.set_stylebox("panel", "PanelContainer", box(DesignTokens.SURFACE))
	result.set_stylebox("background", "ProgressBar", box(DesignTokens.SURFACE_RAISED))
	result.set_stylebox("fill", "ProgressBar", box(DesignTokens.ACCENT))
	result.set_color("font_color", "ProgressBar", DesignTokens.TEXT_PRIMARY)
	result.set_color("font_outline_color", "ProgressBar", DesignTokens.ACCENT_INK)
	result.set_constant("outline_size", "ProgressBar", DesignTokens.ICON_STROKE)
	result.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	for kind: String in ["VBoxContainer", "HBoxContainer"]:
		result.set_constant("separation", kind, DesignTokens.GAP)
	return result
