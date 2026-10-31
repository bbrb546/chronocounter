class_name ConfirmDialog
extends BottomSheet

signal confirmed
signal cancelled

@export var title: String = "Delete photo?"
@export var message: String = "This removes the photo from this session."
@export var confirm_text: String = "Delete"
@export var cancel_text: String = "Cancel"
@export var danger: bool = false
var _title_label: Label
var _message_label: Label
var _confirm: PrimaryButton
var _cancel: SecondaryButton
var _accepted: bool = false

func _ready() -> void:
	super._ready()
	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", DesignTokens.HEADING_SIZE)
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_title_label)
	_message_label = Label.new()
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_message_label)
	_confirm = PrimaryButton.new()
	_confirm.pressed.connect(func() -> void:
		_accepted = true
		if danger:
			Haptics.heavy()
		confirmed.emit()
		close())
	content.add_child(_confirm)
	_cancel = SecondaryButton.new()
	_cancel.pressed.connect(close)
	content.add_child(_cancel)
	closed.connect(func() -> void:
		if not _accepted:
			cancelled.emit())

func open() -> void:
	_accepted = false
	_title_label.text = title
	_message_label.text = message
	_confirm.text = confirm_text
	_cancel.text = cancel_text
	_confirm.theme_type_variation = "DangerButton" if danger else "PrimaryButton"
	super.open()
