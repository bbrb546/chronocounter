class_name IconButton
extends Button

@export var filled: bool = false

func _init() -> void:
	custom_minimum_size = Vector2.ONE * DesignTokens.HIT_SIZE
	theme_type_variation = "IconButton"
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	expand_icon = true
	icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_theme_constant_override("icon_max_width", DesignTokens.ICON_SIZE)
	add_theme_constant_override("h_separation", 0)

func _ready() -> void:
	var style: StyleBoxFlat = ThemeFactory.box(DesignTokens.SURFACE_RAISED if filled else Color.TRANSPARENT, DesignTokens.HIT_SIZE / 2, DesignTokens.SPACE_24)
	for state: String in ["normal", "hover", "disabled"]:
		add_theme_stylebox_override(state, style)
	var down: StyleBoxFlat = style.duplicate()
	down.set_border_width_all(DesignTokens.ICON_STROKE)
	down.border_color = DesignTokens.ACCENT
	add_theme_stylebox_override("pressed", down)
	pressed.connect(Haptics.tap)
