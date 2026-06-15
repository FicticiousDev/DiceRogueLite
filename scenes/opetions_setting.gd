extends VBoxContainer


@onready var resolution_option_button = $Resolution_OptionButton
@onready var full_screen_check_box = $FullScreen_CheckBox
@onready var scale_label = $ScaleBox/ScaleLabel
@onready var scale_slider = $ScaleBox/ScaleSlider
@onready var fsr_options = $FSROptions
@onready var vsync_check_box = $VSync_CheckBox
@onready var screen_selector = $ScreenSelector

const RESOLUTIONS: Dictionary = {
	"3840x2160": Vector2i(3840, 2160),
	"2560x1440": Vector2i(2560, 1440),
	"1920x1080": Vector2i(1920, 1080),
	"1280x720": Vector2i(1280, 720),
	"1440x900": Vector2i(1440, 900),
	"1600x900": Vector2i(1600, 900),
	"1024x600": Vector2i(1024, 600),
	"800x600": Vector2i(800, 600)
}


## TODO:
	# Move to settings scene
	# Save and restore settings
	# Detect and set current screen
	# Set default AMD FSR setting when selecting it
	# Detect scaling mode on start (default to bilinear if not set)
	# Add anti-aliasing settings (MSAA - 2x, 4x, and 8x)


func _ready() -> void:
	add_resolutions()
	check_variables()
	get_screens()


func check_variables() -> void:
	var _window = get_window()
	var mode = _window.get_mode()

	if mode == Window.MODE_FULLSCREEN:
		resolution_option_button.set_disabled(true)
		full_screen_check_box.set_pressed_no_signal(true)
	
	if DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_ENABLED:
		vsync_check_box.set_pressed_no_signal(true)


func set_resolution_text() -> void:
	var resolution_text = str(get_window().get_size().x) + "x" + str(get_window().get_size().y)
	resolution_option_button.set_text(resolution_text)

	scale_slider.set_value(100.0)


func add_resolutions() -> void:
	var current_resolution = get_window().get_size()
	var id = 0

	for r in RESOLUTIONS:
		resolution_option_button.add_item(r)
		if RESOLUTIONS[r] == current_resolution:
			resolution_option_button.select(id)

		id+=1


func centre_window() -> void:
	var centre_screen = DisplayServer.screen_get_position() + Vector2i(DisplayServer.screen_get_size() / 2.0)
	var window_size = get_window().get_size_with_decorations()
	get_window().set_position(centre_screen - Vector2i(window_size / 2.0))


func _on_option_button_item_selected(index: int) -> void:
	var id = resolution_option_button.get_item_text(index)
	get_window().set_size(RESOLUTIONS[id])
	set_resolution_text()
	centre_window()


func _on_full_screen_check_box_toggled(toggled_on: bool):
	resolution_option_button.set_disabled(toggled_on)
	if toggled_on:
		get_window().set_mode(Window.MODE_FULLSCREEN)
	else:
		get_window().set_mode(Window.MODE_WINDOWED)
		centre_window()
	
	await get_tree().create_timer(0.05).timeout
	set_resolution_text()


func _on_scale_slider_value_changed(value: float):
	var resolution_scale = value / 100.0
	var resolution_text = str(int(get_window().get_size().x * resolution_scale)) + "x" + str(int(get_window().get_size().y * resolution_scale))

	scale_label.set_text(str(int(value)) + "% - " + resolution_text)
	get_viewport().set_scaling_3d_scale(resolution_scale)
	


func _on_scaler_item_selected(index: int):
	var _viewport = get_viewport()
	match index:
		1:
			_viewport.set_scaling_3d_mode(Viewport.SCALING_3D_MODE_BILINEAR)
			scale_slider.set_editable(true)
			fsr_options.hide()
		2:
			_viewport.set_scaling_3d_mode(Viewport.SCALING_3D_MODE_FSR2)
			scale_slider.set_editable(false)
			fsr_options.show()
		


func _on_fsr_options_item_selected(index: int):
	match index:
		1:
			_on_scale_slider_value_changed(50.00)
		2:
			_on_scale_slider_value_changed(59.00)
		3:
			_on_scale_slider_value_changed(67.00)
		4:
			_on_scale_slider_value_changed(77.00)
		


func _on_v_sync_check_box_toggled(toggled_on: bool):
	if toggled_on:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)


func get_screens() -> void:
	var screens = DisplayServer.get_screen_count()

	for screen in screens:
		screen_selector.add_item("Screen:" + str(screen))
	

func _on_screen_selector_item_selected(index: int):
	var _window = get_window()
	_window.set_current_screen(index)
	
