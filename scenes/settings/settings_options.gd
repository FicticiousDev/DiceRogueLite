extends VBoxContainer

# Game settings
@onready var show_fps_checkbutton = $ShowFPS/CheckButton
@onready var skip_splash_checkbutton = $SkipSplashScreen/CheckButton

# Graphics settings
@onready var resolution_options = $Resolution/OptionButton
@onready var resolution_scale_label = $ResolutionScaling/ScalingSettings/ScaleLabel
@onready var resolution_scale_slider = $ResolutionScaling/ScalingSettings/ScaleSlider
@onready var resolution_scaler_options = $ResolutionScaling/ScalingSettings/Scaler
@onready var resolution_fsr_options = $ResolutionScaling/ScalingSettings/FSROptions
@onready var anti_aliasing_options = $AntiAliasing/OptionButton
@onready var screen_space_aa_options = $ScreenSpaceAA/OptionButton
@onready var full_screen_checkbutton = $Fullscreen/CheckButton
@onready var borderless_checkbutton = $Borderless/CheckButton
@onready var vsync_checkbutton = $VSync/CheckButton
@onready var screen_options = $Screen/OptionButton
@onready var brightness_slider = $Brightness/HBoxContainer/HSlider
@onready var brightness_label = $Brightness/HBoxContainer/Label
@onready var contrast_slider = $Contrast/HBoxContainer/HSlider
@onready var contrast_label = $Contrast/HBoxContainer/Label

# Audio settings
@onready var master_volume_slider = $MasterVolume/HBoxContainer/HSlider
@onready var master_volume_label = $MasterVolume/HBoxContainer/Label
@onready var music_volume_slider = $MusicVolume/HBoxContainer/HSlider
@onready var music_volume_label = $MusicVolume/HBoxContainer/Label
@onready var sfx_volume_slider = $SFXVolume/HBoxContainer/HSlider
@onready var sfx_volume_label = $SFXVolume/HBoxContainer/Label
@onready var ui_volume_slider = $UIVolume/HBoxContainer/HSlider
@onready var ui_volume_label = $UIVolume/HBoxContainer/Label

const RESOLUTIONS: Dictionary = {
	"3840x2160": Vector2i(3840, 2160),
	"3440x1440": Vector2i(3440, 1440),
	"2560x1600": Vector2i(2560, 1600),
	"2560x1440": Vector2i(2560, 1440),
	"1920x1200": Vector2i(1920, 1200),
	"1920x1080": Vector2i(1920, 1080),
	"1366x768": Vector2i(1366, 768),
	"1280x720": Vector2i(1280, 720)
}


func _ready() -> void:
	# Populate resolutions option button
	for resolution in RESOLUTIONS:
		resolution_options.add_item(resolution)

	# Populate screens option button
	var screens = DisplayServer.get_screen_count()
	var current_screen = DisplayServer.window_get_current_screen()
	for screen in screens:
		screen_options.add_item("Screen: " + str(screen))
	screen_options.select(current_screen)

	# Restoring settings to what was saved or the default
	# Resolution
	var set_resolution = SaveManager.settings_data.resolution
	var resolution_key = str(int(set_resolution.x)) + "x" + str(int(set_resolution.y))
	var selected_resolution = RESOLUTIONS.keys().find(resolution_key)
	resolution_options.select(selected_resolution)
	_on_resolution_selected(selected_resolution)
	# Resolution Scaling
	resolution_scale_slider.set_value(SaveManager.settings_data.resolution_scale)
	resolution_scaler_options.select(0 if SaveManager.settings_data.resolution_scaler == Viewport.SCALING_3D_MODE_BILINEAR else 1)
	resolution_fsr_options.select(SaveManager.settings_data.fsr_profile)
	if SaveManager.settings_data.resolution_scaler != Viewport.SCALING_3D_MODE_FSR2:
		resolution_fsr_options.hide()
	# else:
	# 	_on_fsr_profile_selected(SaveManager.settings_data.fsr_profile)
	# AA
	anti_aliasing_options.select(SaveManager.settings_data.antialiasing)
	_on_aa_profile_selected(SaveManager.settings_data.antialiasing)
	screen_space_aa_options.select(SaveManager.settings_data.screen_space_aa)
	_on_sp_aa_selected(SaveManager.settings_data.screen_space_aa)
	# Fullscreen
	full_screen_checkbutton.set_pressed(SaveManager.settings_data.fullscreen)
	if SaveManager.settings_data.fullscreen:
		resolution_options.set_disabled(true)
	# Borderless
	borderless_checkbutton.set_pressed(SaveManager.settings_data.borderless)
	# VSync
	vsync_checkbutton.set_pressed(SaveManager.settings_data.vsync)
	# Screen
	if SaveManager.settings_data.screen < DisplayServer.get_screen_count():
		screen_options.select(SaveManager.settings_data.screen)
		_on_screen_selected(SaveManager.settings_data.screen)
	else:
		screen_options.select(0)
		_on_screen_selected(0)
	# Brightness
	brightness_slider.value = get_tree().root.get_node("Game/World/WorldEnvironment").environment.adjustment_brightness
	brightness_label.text = str(brightness_slider.value).pad_decimals(2)
	# Contrast
	contrast_slider.value = get_tree().root.get_node("Game/World/WorldEnvironment").environment.adjustment_contrast
	contrast_label.text = str(contrast_slider.value).pad_decimals(2)
	# Volumes
	master_volume_slider.value = SaveManager.settings_data.master_volume
	master_volume_label.text = str(int(master_volume_slider.value * 100))
	music_volume_slider.value = SaveManager.settings_data.music_volume
	music_volume_label.text = str(int(music_volume_slider.value * 100))
	sfx_volume_slider.value = SaveManager.settings_data.sfx_volume
	sfx_volume_label.text = str(int(sfx_volume_slider.value * 100))
	ui_volume_slider.value = SaveManager.settings_data.ui_volume
	ui_volume_label.text = str(int(ui_volume_slider.value * 100))
	# FPS
	show_fps_checkbutton.set_pressed(SaveManager.settings_data.show_fps)
	# Skip splash
	skip_splash_checkbutton.set_pressed(SaveManager.settings_data.skip_splash)

	centre_window()


## Centring the window after its size is set
func centre_window() -> void:
	var centre_screen = DisplayServer.screen_get_position() + Vector2i(DisplayServer.screen_get_size() / 2.0)
	var window_size = get_window().get_size_with_decorations()
	get_window().position = centre_screen - Vector2i(window_size / 2.0)


## Setting the text that shows on the resolutions options button - called when resolution is changed independently - resets resolution scale
func set_resolution_text() -> void:
	var resolution_text = str(get_window().get_size().x) + "x" + str(get_window().get_size().y)
	resolution_options.set_text(resolution_text)


## Reacting to FPS button press
func _on_fps_toggled(toggled_on: bool) -> void:
	SaveManager.settings_data.show_fps = toggled_on


## Reacting to skip splash screen button press
func _on_skip_splash_toggled(toggled_on: bool) -> void:
	SaveManager.settings_data.skip_splash = toggled_on


## Reacting to resolution options button press
func _on_resolution_selected(index: int) -> void:
	var resolution_id = resolution_options.get_item_text(index)
	get_window().set_size(RESOLUTIONS[resolution_id])
	set_resolution_text()
	centre_window()
	SaveManager.settings_data.resolution = RESOLUTIONS[resolution_id]


## Reacting to resolution scale slider change
func _on_resolution_scale_value_changed(value: float) -> void:
	var resolution_scale = value / 100.0
	var window = get_window()
	var resolution_scale_text = str(int(window.get_size().x * resolution_scale)) + "x" + str(int(window.get_size().y * resolution_scale))

	resolution_scale_label.set_text(str(int(value)) + "% - " + resolution_scale_text)
	get_viewport().set_scaling_3d_scale(resolution_scale)
	SaveManager.settings_data.resolution_scale = value


## Reacting to resolution scaler options button press
func _on_resolution_scaler_selected(index: int) -> void:
	var scaler = Viewport.SCALING_3D_MODE_BILINEAR if index == 0 else Viewport.SCALING_3D_MODE_FSR2
	var viewport = get_viewport()
	match scaler:
		Viewport.SCALING_3D_MODE_BILINEAR: 
			viewport.set_scaling_3d_mode(Viewport.SCALING_3D_MODE_BILINEAR)
			resolution_scale_slider.set_editable(true)
			resolution_fsr_options.hide()
		Viewport.SCALING_3D_MODE_FSR2: 
			viewport.set_scaling_3d_mode(Viewport.SCALING_3D_MODE_FSR2)
			resolution_scale_slider.set_editable(false)
			resolution_fsr_options.show()
			_on_fsr_profile_selected(SaveManager.settings_data.fsr_profile)
	SaveManager.settings_data.resolution_scaler = scaler


## Reacting to FSR profile options button press
func _on_fsr_profile_selected(index: int) -> void:
	match index:
		0: 
			resolution_scale_slider.set_value(50.0)
		1: 
			resolution_scale_slider.set_value(59.0)
		2: 
			resolution_scale_slider.set_value(67.0)
		3: 
			resolution_scale_slider.set_value(77.0)
	SaveManager.settings_data.fsr_profile = index


## Reacting to anti-aliasing profile options button press
func _on_aa_profile_selected(index: int) -> void:
	match index:
		0: 
			get_viewport().msaa_3d = Viewport.MSAA_DISABLED
		1: 
			get_viewport().msaa_3d = Viewport.MSAA_2X
		2: 
			get_viewport().msaa_3d = Viewport.MSAA_4X
		3: 
			get_viewport().msaa_3d = Viewport.MSAA_8X

	SaveManager.settings_data.antialiasing = index


## Reacting to screen space anti-aliasing profile options button press
func _on_sp_aa_selected(index: int) -> void:
	match index:
		0: 
			get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
		1: 
			get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
		2: 
			get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_SMAA
	
	SaveManager.settings_data.screen_space_aa = index


## Reacting to fullscreen button press
func _on_fullscreen_toggled(toggled_on: bool) -> void:
	if toggled_on:
		get_window().set_mode(Window.MODE_FULLSCREEN)
	else:
		get_window().set_mode(Window.MODE_WINDOWED)
		get_window().set_current_screen(SaveManager.settings_data.screen)
		centre_window()
	resolution_options.set_disabled(toggled_on)
	SaveManager.settings_data.fullscreen = toggled_on
	await get_tree().create_timer(0.05).timeout
	set_resolution_text()


## Reacting to borderless button press
func _on_borderless_toggled(toggled_on: bool) -> void:
	get_window().borderless = toggled_on
	SaveManager.settings_data.borderless = toggled_on


## Reacting to vsync button press
func _on_vsync_toggled(toggled_on: bool) -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if toggled_on else DisplayServer.VSYNC_DISABLED)
	SaveManager.settings_data.vsync = toggled_on


## Reacting to screen selector button press
func _on_screen_selected(index: int) -> void:
	get_window().set_current_screen(index)
	SaveManager.settings_data.screen = index


## Reacting to brightness slider change
func _on_brightness_value_changed(value: float) -> void:
	get_tree().get_root().get_node("Game/World/WorldEnvironment").environment.adjustment_brightness = value
	brightness_label.set_text(str(value).pad_decimals(2))
	SaveManager.settings_data.brightness = value


## Reacting to contrast slider change
func _on_contrast_value_changed(value: float) -> void:
	get_tree().get_root().get_node("Game/World/WorldEnvironment").environment.adjustment_contrast = value
	contrast_label.set_text(str(value).pad_decimals(2))
	SaveManager.settings_data.contrast = value


## Reacting to master volume slider change
func _on_master_volume_value_changed(value: float) -> void:
	var db_value = linear_to_db(value)
	AudioServer.set_bus_volume_db(0, db_value)
	master_volume_label.set_text(str(int(value * 100.0)))
	SaveManager.settings_data.master_volume = value


## Reacting to music volume slider change
func _on_music_volume_value_changed(value: float) -> void:
	var db_value = linear_to_db(value)
	AudioServer.set_bus_volume_db(1, db_value)
	music_volume_label.set_text(str(int(value * 100.0)))
	SaveManager.settings_data.music_volume = value


## Reacting to SFX volume slider change
func _on_sfx_volume_value_changed(value: float) -> void:
	var db_value = linear_to_db(value)
	AudioServer.set_bus_volume_db(2, db_value)
	sfx_volume_label.set_text(str(int(value * 100.0)))
	SaveManager.settings_data.sfx_volume = value


## Reacting to UI volume slider change
func _on_ui_volume_value_changed(value: float) -> void:
	var db_value = linear_to_db(value)
	AudioServer.set_bus_volume_db(3, db_value)
	ui_volume_label.set_text(str(int(value * 100.0)))
	SaveManager.settings_data.ui_volume = value
