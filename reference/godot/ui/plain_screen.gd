extends Control

func _ready() -> void:
	_apply_geometry(self)

func _apply_geometry(node: Node) -> void:
	if node is BaseButton or node is LineEdit:
		node.custom_minimum_size = Vector2.ONE * DesignTokens.HIT_SIZE
	if node is Label and node.name == "Title":
		node.add_theme_font_size_override("font_size", DesignTokens.TITLE_SIZE)
	for child: Node in node.get_children():
		_apply_geometry(child)
