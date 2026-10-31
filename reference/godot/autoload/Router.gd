extends Node

const ROUTES: Dictionary = {
	"main_menu": "res://scenes/main_menu/main_menu.tscn",
	"capture": "res://scenes/capture/capture.tscn",
	"processing": "res://scenes/processing/processing.tscn",
	"results": "res://scenes/results/results.tscn",
}

var _transition_pending: bool = false
var _fade: ColorRect

func _ready() -> void:
	get_tree().set_auto_accept_quit(false)
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 1000
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = DesignTokens.BG
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.modulate.a = 0
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.hide()
	layer.add_child(_fade)

func goto(key: String) -> Error:
	if not ROUTES.has(key):
		push_error("Unknown route: %s" % key)
		return ERR_INVALID_PARAMETER
	if _transition_pending:
		return ERR_BUSY
	var destination: PackedScene = load(ROUTES[key]) as PackedScene
	if destination == null:
		return ERR_CANT_OPEN
	_transition_pending = true
	_transition.call_deferred(destination)
	return OK

func _transition(destination: PackedScene) -> void:
	_fade.show()
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tween: Tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_fade, "modulate:a", 1.0, DesignTokens.SCREEN_FADE / 2.0)
	await tween.finished
	var error: Error = get_tree().change_scene_to_packed(destination)
	if error == OK:
		await get_tree().scene_changed
	else:
		push_error("Could not open scene: %s" % error_string(error))
	tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_fade, "modulate:a", 0.0, DesignTokens.SCREEN_FADE / 2.0)
	await tween.finished
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.hide()
	_transition_pending = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_handle_back.call_deferred()

func _handle_back() -> void:
	if _transition_pending:
		return
	var overlays: Array[Node] = get_tree().get_nodes_in_group("dismissible_overlays")
	overlays.reverse()
	for overlay: Node in overlays:
		if overlay is BottomSheet and overlay.visible:
			overlay.close()
			return
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	if scene.has_method("request_back"):
		scene.request_back()
	elif scene.scene_file_path == ROUTES["main_menu"]:
		get_tree().quit()
	else:
		goto("main_menu")
