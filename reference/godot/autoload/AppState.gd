extends Node

signal numbering_changed

var pickup_first_bar: bool = false
var pages: Array[PhotoPage] = []
var current_page_index: int = 0


func reset_session() -> void:
	pickup_first_bar = false
	for page: PhotoPage in pages:
		page.clear_session_data()
	pages.clear()
	GestureState.reset()
	current_page_index = 0
	numbering_changed.emit()


# Only for the server request. Display numbering must use
# NumberingEngine.resolve_initial once the response is available.
func first_page_provisional_initial() -> int:
	return 1 if pickup_first_bar else 2
