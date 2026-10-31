class_name CameraService
extends Node

signal photo_captured(image: Image)
signal capture_failed(reason: String)
signal preview_updated(texture: ImageTexture)
signal permission_denied
signal capture_cancelled

const PREVIEW_LONG_SIDE: int = 960
const PREVIEW_MAX_LONG_SIDE: int = 1280
const ASPECT_TOLERANCE: float = 0.01
const MIN_DESIRED_LONG_SIDE: int = 3000
const FRAME_SKIP: int = 0
const FRAME_TIMEOUT: float = 10.0

var source_bytes: PackedByteArray = PackedByteArray()
var source_mime: String = ""
var _camera: NativeCamera
var _latest: FrameInfo
var _texture: ImageTexture
var _dialog: FileDialog
var _active: bool = false
var _wanted: bool = false
var _capture_pending: bool = false
var _preview_request: FeedRequest
var _capture_request: FeedRequest
var _request: FeedRequest
var _sensor_rotation: int = 90
var _rotation: int = 90
var _frame_pending: bool = false
var _generation: int = 0
var _frame_mutex: Mutex = Mutex.new()
var _frame_timer: Timer
var _timeout_generation: int = 0

func _ready() -> void:
	_frame_timer = Timer.new()
	_frame_timer.one_shot = true
	_frame_timer.timeout.connect(_on_frame_timeout)
	add_child(_frame_timer)
	if OS.get_name() == "Android":
		if not Engine.has_singleton(NativeCamera.PLUGIN_SINGLETON_NAME):
			return
		_camera = NativeCamera.new()
		add_child(_camera)
		_camera.camera_permission_granted.connect(_permission_granted)
		_camera.camera_permission_denied.connect(func() -> void: permission_denied.emit())
		_camera.frame_available.connect(_receive_frame)
	else:
		_dialog = FileDialog.new()
		_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		_dialog.filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; Photos"])
		_dialog.use_native_dialog = true
		add_child(_dialog)
		_dialog.file_selected.connect(_import_file)
		_dialog.canceled.connect(func() -> void: capture_cancelled.emit())

func start_preview() -> void:
	_wanted = true
	if OS.get_name() != "Android":
		return
	if _camera == null:
		capture_failed.emit("Native camera is unavailable. Check the Android plugin export.")
	elif _camera.has_camera_permission():
		_permission_granted()
	else:
		_camera.request_camera_permission()

func stop_preview() -> void:
	var cancelled_capture: bool = _capture_pending
	_capture_pending = false
	_wanted = false
	_active = false
	if is_instance_valid(_frame_timer):
		_frame_timer.stop()
	_advance_generation()
	_latest = null
	_texture = null
	if _camera != null:
		_camera.stop()
	preview_updated.emit(null)
	if cancelled_capture:
		capture_cancelled.emit()

func _permission_granted() -> void:
	if not _wanted or _active:
		return
	var selected: CameraInfo
	var largest: FrameSize
	# Prefer the rear camera advertising the largest image (main over ultrawide).
	for camera: CameraInfo in _camera.get_all_cameras():
		if camera.is_front_facing():
			continue
		for candidate: FrameSize in camera.get_output_sizes():
			if largest == null or candidate.get_width() * candidate.get_height() > largest.get_width() * largest.get_height():
				selected = camera
				largest = candidate
	if selected == null or largest == null:
		capture_failed.emit("No rear camera is available.")
		return
	_sensor_rotation = _read_sensor_rotation(selected.get_camera_id())
	_rotation = _held_rotation()
	var preview_size: FrameSize = choose_preview_size(selected.get_output_sizes(), largest)
	_preview_request = _make_request(selected.get_camera_id(), preview_size)
	_capture_request = _make_request(selected.get_camera_id(), largest)
	_request = _preview_request
	if OS.is_debug_build():
		print("Camera preview: %s %dx%d; capture: %dx%d, rotation %d (Pixel 6a target 4032x3024)" % [selected.get_camera_id(), preview_size.get_width(), preview_size.get_height(), largest.get_width(), largest.get_height(), _rotation])
		if maxi(largest.get_width(), largest.get_height()) < MIN_DESIRED_LONG_SIDE:
			print("Camera's largest advertised frame is below 3000 px.")
	_active = true
	_advance_generation()
	_camera.start(_request)
	_watch_first_frame(_generation)

func _watch_first_frame(generation: int) -> void:
	_timeout_generation = generation
	_frame_timer.start(FRAME_TIMEOUT)

func _on_frame_timeout() -> void:
	if _active and _timeout_generation == _generation and _latest == null:
		var was_capture: bool = _capture_pending
		_capture_pending = false
		stop_preview()
		capture_failed.emit("No high-resolution photo arrived. Try again." if was_capture else "No camera frame arrived. Try granting permission again.")
		if was_capture:
			start_preview()

func _process(_delta: float) -> void:
	if _active and not _capture_pending and _request != null:
		var rotation: int = _held_rotation()
		if rotation != _rotation:
			_rotation = rotation
			_latest = null
			_advance_generation()
			_camera.stop()
			_camera.start(_request.set_rotation(rotation))
			_watch_first_frame(_generation)

static func choose_preview_size(sizes: Array[FrameSize], still: FrameSize) -> FrameSize:
	var selected: FrameSize = still
	var still_ratio: float = float(maxi(still.get_width(), still.get_height())) / mini(still.get_width(), still.get_height())
	var best_distance: int = 2147483647
	for candidate: FrameSize in sizes:
		var long_side: int = maxi(candidate.get_width(), candidate.get_height())
		var short_side: int = mini(candidate.get_width(), candidate.get_height())
		if short_side <= 0 or long_side > PREVIEW_MAX_LONG_SIDE:
			continue
		var ratio: float = float(long_side) / short_side
		# Match the still aspect so preview and capture show the same composition.
		if absf(ratio - still_ratio) > ASPECT_TOLERANCE:
			continue
		var distance: int = absi(long_side - PREVIEW_LONG_SIDE)
		if distance < best_distance:
			selected = candidate
			best_distance = distance
	return selected

func _make_request(camera_id: String, frame_size: FrameSize) -> FeedRequest:
	return FeedRequest.new().set_camera_id(camera_id).set_width(frame_size.get_width()).set_height(frame_size.get_height()).set_frames_to_skip(FRAME_SKIP).set_rotation(_rotation).set_grayscale(false)

func _matches_request(frame: FrameInfo) -> bool:
	var data: Dictionary = _request.get_raw_data()
	return mini(frame.get_width(), frame.get_height()) == mini(data.width, data.height) and maxi(frame.get_width(), frame.get_height()) == maxi(data.width, data.height) and frame.get_rotation() == _rotation

func _held_rotation() -> int:
	var gravity: Vector3 = Input.get_gravity()
	if gravity.length() < 1.0:
		gravity = Input.get_accelerometer()
	# A dead band avoids reopening the stream repeatedly near a diagonal.
	var degrees: int = posmod(_sensor_rotation - _rotation, 360)
	if absf(gravity.x) - absf(gravity.y) > 2.0 and absf(gravity.x) > 4.0:
		degrees = 90 if gravity.x < 0 else 270
	elif absf(gravity.y) - absf(gravity.x) > 2.0 and absf(gravity.y) > 4.0:
		degrees = 180 if gravity.y > 0 else 0
	return posmod(_sensor_rotation - degrees, 360)

func _read_sensor_rotation(camera_id: String) -> int:
	# Installed wrapper predates README's get_sensor_orientation/auto_upright.
	# Read the same Camera2 hardware property through Godot's Android bridge.
	if Engine.has_singleton("AndroidRuntime") and Engine.has_singleton("JavaClassWrapper"):
		var bridge: Object = Engine.get_singleton("JavaClassWrapper")
		var runtime: Object = Engine.get_singleton("AndroidRuntime")
		var characteristics_class: Object = bridge.wrap("android.hardware.camera2.CameraCharacteristics")
		var activity: Object = runtime.getActivity()
		var manager: Object = activity.getSystemService("camera")
		var characteristics: Object = manager.getCameraCharacteristics(camera_id)
		# Dynamic dispatch avoids Object.get shadowing the Java get(Key) overload.
		var orientation: Variant = characteristics.call("get", characteristics_class.SENSOR_ORIENTATION)
		if bridge.get_exception() == null and orientation != null:
			return int(orientation.intValue()) if orientation is Object else int(orientation)
	return 90 # Pixel 6a rear sensor; verify actual rotation on device.

func _advance_generation() -> void:
	_frame_mutex.lock()
	_generation += 1
	_frame_mutex.unlock()

func _receive_frame(frame: FrameInfo) -> void:
	# Plugin may emit on a native thread; bound deferred work to one frame.
	_frame_mutex.lock()
	if _frame_pending:
		_frame_mutex.unlock()
		return
	_frame_pending = true
	var generation: int = _generation
	_frame_mutex.unlock()
	_update_frame.call_deferred(frame, generation)

func _update_frame(frame: FrameInfo, generation: int) -> void:
	_frame_mutex.lock()
	_frame_pending = false
	_frame_mutex.unlock()
	if not _active or generation != _generation or not _matches_request(frame):
		return
	if _capture_pending:
		var captured: Image = frame.get_image()
		if captured == null or captured.is_empty():
			return
		_frame_timer.stop()
		if OS.is_debug_build():
			print("Camera captured actual: %dx%d, rotation %d" % [captured.get_width(), captured.get_height(), frame.get_rotation()])
		_capture_pending = false
		stop_preview()
		photo_captured.emit(captured)
		return
	var image: Image = frame.get_image()
	if image == null or image.is_empty():
		return
	_latest = frame
	_frame_timer.stop()
	var scale: float = minf(1.0, float(PREVIEW_LONG_SIDE) / maxi(image.get_width(), image.get_height()))
	image.resize(maxi(1, roundi(image.get_width() * scale)), maxi(1, roundi(image.get_height() * scale)), Image.INTERPOLATE_BILINEAR)
	if _texture == null or _texture.get_size() != Vector2(image.get_size()):
		_texture = ImageTexture.create_from_image(image)
	else:
		_texture.update(image)
	preview_updated.emit(_texture)

func capture() -> void:
	source_bytes = PackedByteArray()
	source_mime = ""
	if OS.get_name() != "Android":
		_dialog.popup_centered_ratio()
		return
	_begin_native_capture()

func _begin_native_capture() -> void:
	if _capture_pending:
		return
	if not _active or _latest == null or _capture_request == null:
		capture_failed.emit("Camera is not ready. Wait for the live preview.")
		return
	_capture_pending = true
	_latest = null
	_advance_generation()
	# The plugin only streams frames: switch streams and wait for a fresh still.
	# Keep the last small texture visible while the camera session reconfigures.
	_camera.stop()
	_request = _capture_request.set_rotation(_rotation)
	_camera.start(_request)
	_watch_first_frame(_generation)

func _import_file(path: String) -> void:
	var mime: String = ""
	match path.get_extension().to_lower():
		"png": mime = "image/png"
		"jpg", "jpeg": mime = "image/jpeg"
		"webp": mime = "image/webp"
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var image: Image = ImageEncoder.decode(bytes, mime)
	if image == null:
		capture_failed.emit("This photo could not be opened. Choose PNG, JPEG or WebP.")
		return
	source_bytes = bytes
	source_mime = mime
	photo_captured.emit(image)

func take_source() -> Dictionary:
	var result: Dictionary = {"bytes": source_bytes, "mime": source_mime}
	source_bytes = PackedByteArray()
	source_mime = ""
	return result

func open_system_settings() -> void:
	if not Engine.has_singleton("AndroidRuntime") or not Engine.has_singleton("JavaClassWrapper"):
		capture_failed.emit("Open Android Settings, then Apps → Chronocounter → Permissions → Camera.")
		return
	var bridge: Object = Engine.get_singleton("JavaClassWrapper")
	var runtime: Object = Engine.get_singleton("AndroidRuntime")
	var intent_class: Object = bridge.wrap("android.content.Intent")
	var uri_class: Object = bridge.wrap("android.net.Uri")
	var activity: Object = runtime.getActivity()
	var intent: Object = intent_class.Intent()
	intent.setAction("android.settings.APPLICATION_DETAILS_SETTINGS")
	intent.setData(uri_class.parse("package:" + str(activity.getPackageName())))
	activity.startActivity(intent)
	if bridge.get_exception() != null:
		capture_failed.emit("Open Android Settings, then Apps → Chronocounter → Permissions → Camera.")

func _exit_tree() -> void:
	stop_preview()
