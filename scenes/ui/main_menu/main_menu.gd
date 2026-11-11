extends Node3D

## Main menu over a slowly turning pile of the player's dice (DicePile), centred in the space left of the menu, with the
## levels' falling streaks and dice behind (Backdrop). DICE opens the dice designer (DiceDesigner).
## One item is always selected: a highlight slides behind it and its text scales up (through the offset transform, so the
## list's layout doesn't move).

const RUN_SCENE: String = "res://scenes/run/run.tscn"

## Text scale of the selected item
@export var selected_scale: float = 1.25
## Seconds for the highlight to move and the text to scale
@export var select_time: float = 0.15

@onready var new_run_button: Button = %NewRunButton
@onready var continue_button: Button = %ContinueButton
@onready var settings_button: Button = %SettingsButton
@onready var dice_button: Button = %DiceButton
@onready var quit_button: Button = %QuitButton
@onready var menu: VBoxContainer = $UI/Menu
@onready var highlight: Control = $UI/Highlight
@onready var confirm_dialog: ConfirmDialog = $ConfirmDialog
@onready var camera: Camera3D = $Camera3D
@onready var dice_pile: DicePile = $DicePile

var _designer: DiceDesigner
var _buttons: Array[Button] = []
var _selected: Button
var _select_tween: Tween


func _ready() -> void:
	new_run_button.pressed.connect(_on_new_run_pressed)
	settings_button.pressed.connect(Settings.show_settings)
	quit_button.pressed.connect(_on_quit_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	continue_button.disabled = not SaveManager.has_run()
	_designer = DiceDesigner.new()
	add_child(_designer)
	dice_button.pressed.connect(_designer.open)
	_designer.closed.connect(dice_pile.refresh)
	var backdrop := Backdrop.new()
	backdrop.camera_distance = camera.position.length()
	camera.add_child(backdrop)
	# Challenges a run ended from here (abandoned) may have completed
	if SaveManager.progression_data.complete_challenges().size() > 0:
		SaveManager.save_data()
	_setup_selection()
	InputMode.register_menu($UI, func() -> Control: return _selected)


func _on_new_run_pressed() -> void:
	if SaveManager.has_run():
		if not await confirm_dialog.ask(tr("DIALOG_NEW_RUN_TITLE"), tr("DIALOG_NEW_RUN_MESSAGE")):
			return
		SaveManager.end_run(ProgressionData.Outcome.ABANDONED)
	else:
		SaveManager.clear_run()
		SaveManager.save_data()
	SceneManager.change_scene(RUN_SCENE)


func _on_continue_pressed() -> void:
	SceneManager.change_scene(RUN_SCENE)


func _on_quit_pressed() -> void:
	if await confirm_dialog.ask(tr("DIALOG_QUIT_TITLE"), tr("DIALOG_QUIT_MESSAGE")):
		SaveManager.save_data()
		get_tree().quit()



# ===========================================================================================================================================
# Selection
# ===========================================================================================================================================


func _setup_selection() -> void:
	for child in menu.get_children():
		if child is Button:
			var button: Button = child
			_buttons.append(button)
			button.offset_transform_enabled = true
			button.offset_transform_pivot_ratio = Vector2(0.5, 0.5)
			button.focus_entered.connect(_select.bind(button))
			button.mouse_entered.connect(_on_button_hovered.bind(button))
	_selected = new_run_button if continue_button.disabled else continue_button
	_selected.offset_transform_scale = Vector2.ONE * selected_scale
	# The menu's layout isn't final until it has sorted; follow it if it changes later (resolution, language)
	menu.resized.connect(_on_menu_laid_out)
	get_tree().process_frame.connect(_on_menu_laid_out, CONNECT_ONE_SHOT)


func _on_menu_laid_out() -> void:
	_place_highlight()
	_place_pile()


## Keeps keyboard focus and the selection together, so Enter presses what is highlighted.
func _on_button_hovered(button: Button) -> void:
	if button.disabled:
		return
	if get_viewport().gui_get_focus_owner() != null:
		button.grab_focus()
	else:
		_select(button)


func _select(button: Button) -> void:
	if button == _selected or button.disabled:
		return
	_selected = button
	if _select_tween:
		_select_tween.kill()
	_select_tween = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_select_tween.tween_property(highlight, "position", _highlight_position(button), select_time)
	_select_tween.tween_property(highlight, "size", button.size, select_time)
	for other in _buttons:
		var target := Vector2.ONE * (selected_scale if other == button else 1.0)
		_select_tween.tween_property(other, "offset_transform_scale", target, select_time)


## Snaps the highlight to the selected item.
func _place_highlight() -> void:
	if _select_tween and _select_tween.is_running():
		return
	highlight.position = _highlight_position(_selected)
	highlight.size = _selected.size


## The container's layout position, unaffected by the offset transform. Highlight and menu share the CanvasLayer.
func _highlight_position(button: Button) -> Vector2:
	return menu.position + button.position


# ===========================================================================================================================================
# Dice pile
# ===========================================================================================================================================


## Puts the pile's centre under the middle of the space between the screen's left edge and the menu items, halfway down.
func _place_pile() -> void:
	var screen := get_viewport().get_visible_rect().size
	var point := Vector2(menu.position.x * 0.5, screen.y * 0.5)
	var origin := camera.project_ray_origin(point)
	var direction := camera.project_ray_normal(point)
	# Aim at the pile's middle height, then drop to its base
	var hit := origin + direction * (dice_pile.centre_height() - origin.y) / direction.y
	dice_pile.place(Vector3(hit.x, 0.0, hit.z))
