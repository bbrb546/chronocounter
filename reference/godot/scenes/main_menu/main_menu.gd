extends "res://ui/plain_screen.gd"

@onready var settings_sheet: SettingsSheet = $SettingsSheet
@onready var snackbar: Snackbar = $Snackbar
func _ready() -> void:
	super._ready()
	if OS.is_debug_build():
		print("Session memory at menu (bytes): ", OS.get_static_memory_usage())
	$SafeArea/Layout/Title.add_theme_font_size_override("font_size", DesignTokens.TITLE_SIZE)
	$SafeArea/Layout/Tagline.add_theme_color_override("font_color", DesignTokens.TEXT_SECONDARY)
	$SafeArea/Layout/Version.add_theme_font_size_override("font_size", DesignTokens.CAPTION_SIZE)
	$SafeArea/Layout/Version.add_theme_color_override("font_color", DesignTokens.TEXT_SECONDARY)
	$SafeArea/Layout/Version.text = "Version %s" % ProjectSettings.get_setting("application/config/version", "0.1.0")

func _on_settings_pressed() -> void:
	settings_sheet._on_settings_pressed()

func _on_take_photos_pressed() -> void:
	if OS.is_debug_build():
		print("Session memory before capture (bytes): ", OS.get_static_memory_usage())
	AppState.reset_session()
	Router.goto("capture")
