class_name SecondaryButton
extends Button

func _init() -> void:
	custom_minimum_size = Vector2.ONE * DesignTokens.HIT_SIZE
	theme_type_variation = "SecondaryButton"

func _ready() -> void:
	pressed.connect(Haptics.tap)
