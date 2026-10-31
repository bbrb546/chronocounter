extends RefCounted

var cases: Array = []
var taps: int = 0


func check(name: String, passed: bool) -> void:
	cases.append({"name": name, "passed": passed, "detail": ""})


func touch(picker: MarkerPicker, point: Vector2, pressed: bool, index: int = 0) -> void:
	var event: InputEventScreenTouch = InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = pressed
	picker._unhandled_input(event)


func run() -> Array:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var page: Node2D = Node2D.new()
	tree.root.add_child(page)
	var marker_scene: PackedScene = load("res://scenes/detection_marker/detection_marker.tscn")
	var colours: Array[Color] = []
	var markers: Array[DetectionMarker] = []
	for cls: String in ["bar", "repeat bar", "double bar", "long rest", "long rest bottom"]:
		var marker: DetectionMarker = marker_scene.instantiate()
		marker.setup(DetectionData.from_json({"class": cls, "x": 300 + markers.size() * 400, "y": 300, "width": 6, "height": 100, "measures_spanned": 4}))
		page.add_child(marker)
		markers.append(marker)
		colours.append(marker.class_colour())
		check("%s ignores input and positions from center" % cls, marker.mouse_filter == Control.MOUSE_FILTER_IGNORE and marker.position == Vector2(marker.data.x - 3, 250) and marker.size == Vector2(6, 100))
		if marker.data.is_long_rest():
			check("%s always has span badge" % cls, marker.badge_text() == "×4" and not marker.show_labels)
	check("Five distinct class colours", colours.size() == 5 and colours[0] != colours[1] and colours[1] != colours[2] and colours[2] != colours[3] and colours[3] != colours[4] and colours[3] != colours[0])
	var first: DetectionMarker = markers[0]
	check("Distance inside, beside and diagonally outside box", first.hit_distance(Vector2(300, 300)) == 0 and is_equal_approx(first.hit_distance(Vector2(307, 300)), 4) and is_equal_approx(first.hit_distance(Vector2(306, 354)), 5))
	var rest: DetectionMarker = markers[3]
	rest.data.x += 10
	rest.data.measures_spanned = 8
	check("Direct span assignment triggers marker refresh", rest.position.x == rest.data.x - rest.data.w / 2.0)
	rest.data.needs_check = true
	check("Direct data edits update badge", rest.badge_text() == "×8 ?")
	rest.data.needs_check = false
	check("Clearing check removes question", rest.badge_text() == "×8")
	var replacement: DetectionData = DetectionData.from_json({"class": "long rest", "x": 20, "y": 30, "width": 10, "height": 20})
	var old: DetectionData = rest.data
	rest.setup(replacement)
	check("Setup disconnects old data and connects new", not old.changed.is_connected(rest.refresh) and replacement.changed.is_connected(rest.refresh))
	replacement.x = 40
	replacement.changed.emit()
	check("Changed signal refreshes geometry", rest.position == Vector2(35, 20))
	page.scale = Vector2.ONE * 0.3
	var picker: MarkerPicker = MarkerPicker.new()
	picker.marker_parent = page
	page.add_child(picker)
	picker.set_view_zoom(0.3)
	first.set_view_zoom(0.3)
	check("Zoom updates drawing scale", first.view_zoom == 0.3)
	check("Thin bar picked 96 screen pixels away at 0.3", picker.pick(Vector2(300, 670)) == first)
	check("Far tap picks nothing", picker.pick(Vector2(4000, 4000)) == null)
	markers[1].data.x = 340
	markers[1].refresh()
	check("Close bars choose nearest", picker.pick(Vector2(310, 300)) == first and picker.pick(Vector2(330, 300)) == markers[1])
	markers[1].data.x = 300
	markers[1].data.w = 4
	markers[1].refresh()
	check("Smaller box wins equal distance", picker.pick(Vector2(300, 300)) == markers[1])
	first.tapped.connect(func(_marker: DetectionMarker) -> void: taps += 1)
	markers[1].data.x = 340
	markers[1].refresh()
	var point: Vector2 = page.get_global_transform_with_canvas() * Vector2(300, 300)
	touch(picker, point, true)
	touch(picker, point, false)
	check("Single finger tap emits marker", taps == 1)
	var far: Vector2 = page.get_global_transform_with_canvas() * Vector2(4000, 4000)
	touch(picker, far, true)
	touch(picker, far, false)
	check("Far tap emits nothing", taps == 1)
	touch(picker, point, true)
	var drag: InputEventScreenDrag = InputEventScreenDrag.new()
	drag.index = 0
	drag.position = point + Vector2(20, 0)
	picker._unhandled_input(drag)
	touch(picker, point, false)
	check("Drag out and back remains cancelled", taps == 1)
	touch(picker, point, true)
	touch(picker, point + Vector2(13, 0), false)
	check("Movement over 12 px rejected", taps == 1)
	touch(picker, point, true)
	picker._started_ms -= 401
	touch(picker, point, false)
	check("Tap over 400 ms rejected", taps == 1)
	touch(picker, point, true)
	touch(picker, point, true, 1)
	touch(picker, point, false, 1)
	touch(picker, point, false)
	check("Second finger cancels entire tap", taps == 1)
	var gestures: Node = tree.root.get_node("GestureState")
	gestures.multitouch_active = true
	touch(picker, point, true)
	gestures.multitouch_active = false
	touch(picker, point, false)
	check("GestureState blocks tap even if cleared before release", taps == 1)
	first.set_selected(true)
	first.show_labels = true
	check("Selection and optional labels callable", first.selected and first.show_labels)
	page.free()
	return cases
