class_name HintOverlay
extends Control

signal dismissed

static func show_once(parent: Node, key: String, message: String) -> void:
	if Settings.hints_seen.get(key, false):
		return
	for active: Node in parent.get_tree().get_nodes_in_group("hint_overlays"):
		if active.get_meta("hint_key", "") == key and not active.is_queued_for_deletion():
			return
	var hint: HintOverlay = HintOverlay.new()
	hint.set_meta("hint_key", key)
	parent.add_child(hint)
	hint._show_card(message)
	hint.dismissed.connect(func() -> void:
		Settings.hints_seen[key] = true
		Settings.save_settings(), CONNECT_ONE_SHOT)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_to_group("hint_overlays")

func _show_card(message: String) -> void:
	var safe: SafeAreaContainer = SafeAreaContainer.new()
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(safe)
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(stack)
	var spacer: Control = Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(spacer)
	var card: PanelContainer = PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", ThemeFactory.box(DesignTokens.SURFACE_RAISED, DesignTokens.RADIUS, DesignTokens.SPACE_36))
	stack.add_child(card)
	var text: Label = Label.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.text = message + "\n\nTap anywhere to continue"
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(text)
	var gap: Control = Control.new()
	gap.custom_minimum_size.y = DesignTokens.HIT_SIZE * 3
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(gap)

func _input(event: InputEvent) -> void:
	if (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		get_viewport().set_input_as_handled()
		dismissed.emit()
		queue_free()
