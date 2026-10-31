class_name PrimaryButton
extends Button

func _init() -> void:
	custom_minimum_size = Vector2.ONE * DesignTokens.HIT_SIZE
	theme_type_variation = "PrimaryButton"

func _ready() -> void:
	pressed.connect(Haptics.tap)
