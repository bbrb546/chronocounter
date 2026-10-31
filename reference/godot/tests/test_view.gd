extends RefCounted

var cases: Array = []

func check(label: String, passed: bool) -> void:
	cases.append({"name": label, "passed": passed, "detail": ""})

func touch(camera: Camera2D, index: int, point: Vector2, pressed: bool) -> void:
	var event: InputEventScreenTouch = InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = pressed
	camera._input(event)

func drag(camera: Camera2D, index: int, point: Vector2) -> void:
	var event: InputEventScreenDrag = InputEventScreenDrag.new()
	event.index = index
	event.position = point
	camera._input(event)

func run() -> Array:
	var tree: SceneTree = Engine.get_main_loop()
	var camera: Camera2D = load("res://scenes/results/ViewController.gd").new()
	tree.root.add_child(camera)
	var area: Rect2 = Rect2(Vector2.ZERO, camera.get_viewport_rect().size)
	camera.fit_to_screen(Vector2(1000, 2000), area)
	var initial: Vector2 = camera.position
	var initial_zoom: float = camera.zoom.x
	var center: Vector2 = area.get_center()
	touch(camera, 3, center - Vector2(100, 0), true)
	drag(camera, 3, center - Vector2(120, 0))
	check("One finger pans empty space without zoom", camera.position.distance_to(initial - Vector2(-20, 0) / initial_zoom) < 0.01 and camera.zoom.x == initial_zoom)
	touch(camera, 7, center + Vector2(120, 0), true)
	check("Second finger activates suppression immediately", GestureState.multitouch_active)
	camera.force_update_scroll()
	var anchor: Vector2 = camera.get_canvas_transform().affine_inverse() * center
	drag(camera, 7, center + Vector2(240, 0))
	var midpoint: Vector2 = center + Vector2(60, 0)
	check("Pinch zoom ratio and moving midpoint anchor", is_equal_approx(camera.zoom.x, initial_zoom * 1.5) and (camera.get_canvas_transform() * anchor).distance_to(midpoint) < 0.01)
	touch(camera, 7, midpoint, false)
	touch(camera, 3, midpoint, false)
	check("Pinch release remains suppressed", GestureState.multitouch_active and GestureState._clear_at > Time.get_ticks_msec())
	GestureState._clear_at = Time.get_ticks_msec() - 1
	GestureState._process(0)
	check("Suppression clears after cooldown", not GestureState.multitouch_active)
	camera._transform_view(center, center, 100000)
	check("Zoom maximum is 8", camera.zoom.x == 8)
	camera._transform_view(center, center, 0.000001)
	check("Zoom minimum is half fit", is_equal_approx(camera.zoom.x, initial_zoom * 0.5))
	camera.position = Vector2(-100000, 100000)
	camera.clamp_to_image()
	var visible: Rect2 = Rect2(camera.position - area.size / camera.zoom / 2, area.size / camera.zoom)
	check("Pan keeps quarter of image visible", visible.intersection(Rect2(Vector2.ZERO, Vector2(1000, 2000))).get_area() >= 1000 * 2000 * 0.25)
	var ui: Control = Control.new()
	ui.size = area.size
	tree.root.add_child(ui)
	camera.ui_root = ui
	initial = camera.position
	initial_zoom = camera.zoom.x
	touch(camera, 1, center, true)
	touch(camera, 2, center + Vector2(100, 0), true)
	drag(camera, 2, center + Vector2(200, 0))
	check("Touches beginning on UI cannot transform view", camera.position == initial and camera.zoom.x == initial_zoom)
	touch(camera, 1, center, false)
	touch(camera, 2, center, false)
	ui.free()
	camera.ui_root = null
	camera.fit_to_screen()
	var wheel: InputEventMouseButton = InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.position = center
	camera._input(wheel)
	check("Desktop wheel zooms", is_equal_approx(camera.zoom.x, initial_zoom * 2.0 * camera.WHEEL_FACTOR))
	var marker_parent: Node2D = Node2D.new()
	tree.root.add_child(marker_parent)
	var picker: MarkerPicker = MarkerPicker.new()
	picker.marker_parent = marker_parent
	marker_parent.add_child(picker)
	picker.set_view_zoom(camera.zoom.x)
	camera.marker_picker = picker
	camera.force_update_scroll()
	var world: Vector2 = marker_parent.get_global_transform_with_canvas().affine_inverse() * center
	var marker: DetectionMarker = load("res://scenes/detection_marker/detection_marker.tscn").instantiate()
	marker.setup(DetectionData.from_json({"class": "bar", "x": world.x, "y": world.y, "width": 10, "height": 100}))
	marker_parent.add_child(marker)
	initial = camera.position
	initial_zoom = camera.zoom.x
	touch(camera, 9, center, true)
	drag(camera, 9, center + Vector2(80, 0))
	check("One-finger drag starting on detection cannot pan", camera.position == initial and camera.zoom.x == initial_zoom)
	touch(camera, 9, center, false)
	marker_parent.free()
	camera.marker_picker = null
	GestureState._clear_at = Time.get_ticks_msec() - 1
	GestureState._process(0)
	camera.free()
	return cases
