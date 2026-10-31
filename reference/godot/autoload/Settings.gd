extends Node

const DEFAULT_API_URL: String = "http://192.168.1.100:8000"
const SETTINGS_PATH: String = "user://settings.cfg"
const SECTION: String = "settings"

var api_base_url: String = DEFAULT_API_URL
var mock_mode: bool = false
var haptics_enabled: bool = true
var hints_seen: Dictionary = {}


func _ready() -> void:
	load_settings()


func load_settings() -> Error:
	var config: ConfigFile = ConfigFile.new()
	var error: Error = config.load(SETTINGS_PATH)
	if error == ERR_FILE_NOT_FOUND:
		return OK
	if error != OK:
		push_error("Could not load settings: %s" % error_string(error))
		return error
	var url: Variant = config.get_value(SECTION, "api_base_url", DEFAULT_API_URL)
	var mock: Variant = config.get_value(SECTION, "mock_mode", false)
	var haptics: Variant = config.get_value(SECTION, "haptics_enabled", true)
	var hints: Variant = config.get_value(SECTION, "hints_seen", {})
	api_base_url = url if url is String else DEFAULT_API_URL
	mock_mode = mock if mock is bool else false
	haptics_enabled = haptics if haptics is bool else true
	hints_seen = hints if hints is Dictionary else {}
	return OK


func save_settings() -> Error:
	var config: ConfigFile = ConfigFile.new()
	config.set_value(SECTION, "api_base_url", api_base_url)
	config.set_value(SECTION, "mock_mode", mock_mode)
	config.set_value(SECTION, "haptics_enabled", haptics_enabled)
	config.set_value(SECTION, "hints_seen", hints_seen)
	return config.save(SETTINGS_PATH)
