class_name PhotoPage
extends RefCounted

enum Status { PENDING, PROCESSING, DONE, FAILED }

var id: String = ""
var bytes: PackedByteArray = PackedByteArray()
var mime: String = ""
var width: int = 0
var height: int = 0
var thumbnail: ImageTexture
var lines: Array = []
var initial_measure_number: int = 1
var status: Status = Status.PENDING
var error_message: String = ""

# Release payloads even when Undo or another observer still holds this page.
func clear_session_data() -> void:
	bytes = PackedByteArray()
	thumbnail = null
	lines.clear()
	id = ""
	mime = ""
	width = 0
	height = 0
	initial_measure_number = 1
	status = Status.PENDING
	error_message = ""
