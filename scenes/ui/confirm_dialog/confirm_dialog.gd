extends CanvasLayer
class_name ConfirmDialog

## Yes/no prompt. Use: if await dialog.ask("Title", "Message"): ...
## Pass the name of a bool SettingsData flag (true = show this prompt) as the third argument to add a
## tr("DIALOG_DONT_SHOW_AGAIN") checkbox that flips that setting, so it stays in step with the settings scene.

signal answered(confirmed: bool)

@onready var confirm_button: TextureButton = $Panel/Confirm
@onready var cancel_button: TextureButton = $Panel/Cancel
@onready var panel: Panel = $Panel
@onready var title_label: Label = $Panel/Title
@onready var description_label: Label = $Panel/Description

var _tween: Tween
var _skip_check: CheckBox
var _skip_setting: StringName = &""


func _ready() -> void:
	confirm_button.pressed.connect(answered.emit.bind(true))
	cancel_button.pressed.connect(answered.emit.bind(false))
	# Starts on the safe answer
	InputMode.register_menu(self, func() -> Control: return cancel_button)
	ButtonPrompt.footer(self, ButtonPrompt.standard("PROMPT_SELECT", "PROMPT_NO"))
	for button in [confirm_button, cancel_button]:
		_highlight_on_focus(button)
	_build_skip_check()


## Shows the dialog and returns true if confirmed.
func ask(title: String, description: String, skip_setting: StringName = &"") -> bool:
	title_label.text = title
	description_label.text = description
	_skip_setting = skip_setting
	_skip_check.visible = skip_setting != &""
	if _skip_check.visible:
		_skip_check.set_pressed_no_signal(not SaveManager.settings_data.get(skip_setting))
	_show_dialog()
	var confirmed: bool = await answered
	_hide_dialog()
	return confirmed


## The tr("DIALOG_DONT_SHOW_AGAIN") checkbox, under the buttons. Hidden unless ask() is given a setting.
func _build_skip_check() -> void:
	_skip_check = CheckBox.new()
	_skip_check.text = tr("DIALOG_DONT_SHOW_AGAIN")
	_skip_check.visible = false
	_skip_check.set_anchors_preset(Control.PRESET_CENTER)
	_skip_check.offset_left = -340.0
	_skip_check.offset_right = 340.0
	_skip_check.offset_top = 155.0
	_skip_check.offset_bottom = 190.0
	_skip_check.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_skip_check.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_skip_check.add_theme_font_size_override("font_size", 18)
	_skip_check.toggled.connect(_on_skip_toggled)
	panel.add_child(_skip_check)


## Ticking the box turns the matching setting off (and back on if unticked), saved straight away.
func _on_skip_toggled(toggled_on: bool) -> void:
	if _skip_setting == &"":
		return
	SaveManager.settings_data.set(_skip_setting, not toggled_on)
	SaveManager.save_data()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("cancel"):
		get_viewport().set_input_as_handled()
		answered.emit(false)


## Texture buttons have no focus look of their own: the focused one brightens and swells.
func _highlight_on_focus(button: TextureButton) -> void:
	button.focus_entered.connect(func():
		button.pivot_offset = button.size / 2.0
		button.modulate = Color(1.3, 1.25, 1.1)
		create_tween().tween_property(button, "scale", Vector2.ONE * 1.1, Anim.t(0.1)))
	button.focus_exited.connect(func():
		button.modulate = Color.WHITE
		button.scale = Vector2.ONE)


func _show_dialog() -> void:
	# Set pivot to centre of the menu so it scales from the middle
	panel.pivot_offset = panel.size / 2.0

	visible = true
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Kill any running tween to avoid conflicts
	if _tween:
		_tween.kill()

	# Start from invisible & scaled-down
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.7, 0.7)

	_tween = create_tween().set_parallel(true)
	_tween.tween_property(panel, "modulate:a", 1.0, Anim.t(0.35)).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	_tween.tween_property(panel, "scale", Vector2(1.0, 1.0), Anim.t(0.25)).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)


func _hide_dialog() -> void:
	panel.pivot_offset = panel.size / 2.0

	if _tween:
		_tween.kill()

	_tween = create_tween().set_parallel(true)
	_tween.tween_property(panel, "modulate:a", 0.0, Anim.t(0.2)).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUART)
	_tween.tween_property(panel, "scale", Vector2(0.0, 0.0), Anim.t(0.2)).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)

	await _tween.finished
	visible = false
