class_name Pill
extends PanelContainer

@export var text: String = "1 / 3":
	set(value):
		text = value
		if is_node_ready():
			$Label.text = text

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", ThemeFactory.box(DesignTokens.SURFACE_RAISED, DesignTokens.SPACE_72, DesignTokens.SPACE_12))
	$Label.text = text
	$Label.add_theme_font_size_override("font_size", DesignTokens.CAPTION_SIZE)
