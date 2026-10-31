class_name DetectionData
extends RefCounted

signal changed

const MIN_REST_LENGTH: int = 1
const MAX_REST_LENGTH: int = 999

var id: String = ""
var cls: String = ""
# Coordinates are image-pixel centers, exactly as returned by the API.
var x: float = 0.0
var y: float = 0.0
var w: float = 0.0
var h: float = 0.0
var _batch_change: bool = false
var measures_spanned: int = 0:
	set(value):
		if measures_spanned == value:
			return
		measures_spanned = value
		if not _batch_change:
			changed.emit()
var measure_number: int = 0
var server_measure_number: int = 0
var edited: bool = false
var needs_check: bool = false:
	set(value):
		if needs_check == value:
			return
		needs_check = value
		if not _batch_change:
			changed.emit()


static func from_json(dict: Dictionary) -> DetectionData:
	var detection: DetectionData = DetectionData.new()
	detection.id = str(dict.get("id", ""))
	detection.cls = str(dict.get("class", ""))
	detection.x = float(dict.get("x", 0.0))
	detection.y = float(dict.get("y", 0.0))
	detection.w = float(dict.get("width", 0.0))
	detection.h = float(dict.get("height", 0.0))
	detection.server_measure_number = int(dict.get("measure_number", 0))
	detection.measure_number = detection.server_measure_number
	if detection.is_long_rest():
		detection.measures_spanned = int(dict.get("measures_spanned", MIN_REST_LENGTH))
		detection.needs_check = dict.get("measures_spanned_confident", true) == false
	return detection


func is_long_rest() -> bool:
	return cls == "long rest" or cls == "long rest bottom"


func is_bar() -> bool:
	return cls in ["bar", "repeat bar", "double bar"]


func end_measure() -> int:
	return measure_number + measures_spanned if is_long_rest() else measure_number


func apply_length(length: int) -> void:
	if not is_long_rest():
		return
	_batch_change = true
	measures_spanned = clampi(length, MIN_REST_LENGTH, MAX_REST_LENGTH)
	edited = true
	needs_check = false
	_batch_change = false
	changed.emit()
