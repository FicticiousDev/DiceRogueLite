extends TabContainer

## Settings menu controls, one tab page each for General, Graphics and Audio. Applies saved settings on startup and saves
## changes to SaveManager.settings_data.

# Game settings
@onready var show_fps_checkbutton = $General/Center/Rows/ShowFPS/CheckButton
@onready var skip_splash_checkbutton = $General/Center/Rows/SkipSplashScreen/CheckButton
@onready var animation_speed_slider = $General/Center/Rows/AnimationSpeed/HBoxContainer/HSlider
@onready var animation_speed_label = $General/Center/Rows/AnimationSpeed/HBoxContainer/Label
@onready var fast_dice_checkbutton = $General/Center/Rows/FastDice/CheckButton
@onready var screen_shake_checkbutton = $General/Center/Rows/ScreenShake/CheckButton
@onready var confirm_unused_dice_checkbutton = $General/Center/Rows/ConfirmUnusedDice/CheckButton
@onready var auto_spend_defence_checkbutton = $General/Center/Rows/AutoSpendDefence/CheckButton
@onready var turn_plan_side_options = $General/Center/Rows/TurnPlanSide/OptionButton
@onready var controller_scheme_options = $General/Center/Rows/ControllerType/OptionButton

# Graphics settings
@onready var resolution_options = $Graphics/Scroll/Center/Rows/Resolution/OptionButton
@onready var resolution_scale_label = $Graphics/Scroll/Center/Rows/ResolutionScaling/ScalingSettings/ScaleLabel
@onready var resolution_scale_slider = $Graphics/Scroll/Center/Rows/ResolutionScaling/ScalingSettings/ScaleSlider
@onready var resolution_scaler_options = $Graphics/Scroll/Center/Rows/ResolutionScaling/ScalingSettings/Scaler
@onready var resolution_fsr_options = $Graphics/Scroll/Center/Rows/ResolutionScaling/ScalingSettings/FSROptions
@onready var anti_aliasing_options = $Graphics/Scroll/Center/Rows/AntiAliasing/OptionButton
@onready var screen_space_aa_options = $Graphics/Scroll/Center/Rows/ScreenSpaceAA/OptionButton
@onready var full_screen_checkbutton = $Graphics/Scroll/Center/Rows/Fullscreen/CheckButton
@onready var borderless_checkbutton = $Graphics/Scroll/Center/Rows/Borderless/CheckButton
@onready var vsync_checkbutton = $Graphics/Scroll/Center/Rows/VSync/CheckButton
@onready var screen_options = $Graphics/Scroll/Center/Rows/Screen/OptionButton
@onready var max_fps_options = $Graphics/Scroll/Center/Rows/MaxFPS/OptionButton
@onready var shadow_quality_options = $Graphics/Scroll/Center/Rows/ShadowQuality/OptionButton
@onready var brightness_slider = $Graphics/Scroll/Center/Rows/Brightness/HBoxContainer/HSlider
@onready var brightness_label = $Graphics/Scroll/Center/Rows/Brightness/HBoxContainer/Label
@onready var contrast_slider = $Graphics/Scroll/Center/Rows/Contrast/HBoxContainer/HSlider
@onready var contrast_label = $Graphics/Scroll/Center/Rows/Contrast/HBoxContainer/Label

# Graphics preview
@onready var preview_holder: Control = $Graphics/Preview

# Audio settings
@onready var master_volume_slider = $Audio/Center/Rows/MasterVolume/HBoxContainer/HSlider
@onready var master_volume_label = $Audio/Center/Rows/MasterVolume/HBoxContainer/Label
@onready var music_volume_slider = $Audio/Center/Rows/MusicVolume/HBoxContainer/HSlider
@onready var music_volume_label = $Audio/Center/Rows/MusicVolume/HBoxContainer/Label
@onready var sfx_volume_slider = $Audio/Center/Rows/SFXVolume/HBoxContainer/HSlider
@onready var sfx_volume_label = $Audio/Center/Rows/SFXVolume/HBoxContainer/Label
@onready var ui_volume_slider = $Audio/Center/Rows/UIVolume/HBoxContainer/HSlider
@onready var ui_volume_label = $Audio/Center/Rows/UIVolume/HBoxContainer/Label

var _preview: DieView

## Shared by every 3D scene so brightness/contrast apply everywhere
var environment: Environment = preload("res://assets/default_environment.tres")

## Preview die: the first of these that exists
const PREVIEW_DICE: Array[StringName] = [&"attack", &"all_rounder"]

const MAX_FPS: Array[int] = [0, 30, 60, 120, 144]
const SHADOW_ATLAS_SIZES: Array[int] = [1024, 2048, 4096]

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
		screen_options.add_item(tr("SETTINGS_SCREEN_N") + " " + str(screen))
	screen_options.select(current_screen)

	# Restoring settings to what was saved or the default
	# Resolution
	var set_resolution = SaveManager.settings_data.resolution
	var resolution_key = str(int(set_resolution.x)) + "x" + str(int(set_resolution.y))
	var selected_resolution = max(RESOLUTIONS.keys().find(resolution_key), RESOLUTIONS.keys().find("1920x1080"))
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
	# Max FPS
	max_fps_options.select(max(MAX_FPS.find(SaveManager.settings_data.max_fps), 0))
	_on_max_fps_selected(max_fps_options.selected)
	# Shadows
	shadow_quality_options.select(SaveManager.settings_data.shadow_quality)
	_on_shadow_quality_selected(SaveManager.settings_data.shadow_quality)
	# Brightness
	brightness_slider.value = SaveManager.settings_data.brightness
	_on_brightness_value_changed(brightness_slider.value)
	# Contrast
	contrast_slider.value = SaveManager.settings_data.contrast
	_on_contrast_value_changed(contrast_slider.value)
	# Volumes
	master_volume_slider.value = SaveManager.settings_data.master_volume
	_on_master_volume_value_changed(master_volume_slider.value)
	music_volume_slider.value = SaveManager.settings_data.music_volume
	_on_music_volume_value_changed(music_volume_slider.value)
	sfx_volume_slider.value = SaveManager.settings_data.sfx_volume
	_on_sfx_volume_value_changed(sfx_volume_slider.value)
	ui_volume_slider.value = SaveManager.settings_data.ui_volume
	_on_ui_volume_value_changed(ui_volume_slider.value)
	# FPS
	show_fps_checkbutton.set_pressed(SaveManager.settings_data.show_fps)
	# Skip splash
	skip_splash_checkbutton.set_pressed(SaveManager.settings_data.skip_splash)
	# Gameplay
	animation_speed_slider.value = SaveManager.settings_data.animation_speed
	_on_animation_speed_value_changed(animation_speed_slider.value)
	fast_dice_checkbutton.set_pressed(SaveManager.settings_data.fast_dice)
	screen_shake_checkbutton.set_pressed(SaveManager.settings_data.screen_shake)
	confirm_unused_dice_checkbutton.set_pressed(SaveManager.settings_data.confirm_unused_dice)
	auto_spend_defence_checkbutton.set_pressed(SaveManager.settings_data.auto_spend_defence)
	turn_plan_side_options.select(SaveManager.settings_data.turn_plan_side)
	controller_scheme_options.select(SaveManager.settings_data.controller_scheme)
	_on_controller_scheme_selected(SaveManager.settings_data.controller_scheme)

	# Prompts with a "Don't show this again" box change settings behind this menu's back
	visibility_changed.connect(_sync_prompt_toggles)
	preview_holder.visibility_changed.connect(_ensure_preview)

	centre_window()


## Keeps the checkbuttons for settings that in-game prompts can flip in step with the saved values
func _sync_prompt_toggles() -> void:
	confirm_unused_dice_checkbutton.set_pressed_no_signal(SaveManager.settings_data.confirm_unused_dice)


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


## Reacting to animation speed slider change
func _on_animation_speed_value_changed(value: float) -> void:
	animation_speed_label.set_text(str(value).pad_decimals(2) + "x")
	SaveManager.settings_data.animation_speed = value


## Reacting to fast dice button press
func _on_fast_dice_toggled(toggled_on: bool) -> void:
	SaveManager.settings_data.fast_dice = toggled_on


## Reacting to screen shake button press
func _on_screen_shake_toggled(toggled_on: bool) -> void:
	SaveManager.settings_data.screen_shake = toggled_on


## Reacting to confirm unused dice button press
func _on_confirm_unused_dice_toggled(toggled_on: bool) -> void:
	SaveManager.settings_data.confirm_unused_dice = toggled_on


## Reacting to auto-spend defence button press
func _on_auto_spend_defence_toggled(toggled_on: bool) -> void:
	SaveManager.settings_data.auto_spend_defence = toggled_on


## Reacting to turn plan side options button press - the run re-lays itself out on [signal Resource.changed]
func _on_turn_plan_side_selected(index: int) -> void:
	if SaveManager.settings_data.turn_plan_side != index:
		SaveManager.settings_data.turn_plan_side = index
		SaveManager.settings_data.emit_changed()


## Reacting to controller icons options button press
func _on_controller_scheme_selected(index: int) -> void:
	InputMode.set_pad_scheme(index as InputMode.PadScheme)
	SaveManager.settings_data.controller_scheme = index


# ===========================================================================================================================================
# Graphics preview
# ===========================================================================================================================================


## Builds the preview die the first time the Graphics tab is shown.
func _ensure_preview() -> void:
	if _preview or not preview_holder.is_visible_in_tree():
		return
	var type: DieType
	for id in PREVIEW_DICE:
		type = Database.get_content("dice", id)
		if type:
			break
	if type == null and Database.get_all("dice").size() > 0:
		type = Database.get_all("dice")[0]
	if type == null:
		return
	_preview = DieView.create(type, 400.0)
	_preview.inspect_on_click = false
	_preview.set_anchors_preset(Control.PRESET_FULL_RECT)
	preview_holder.add_child(_preview)
	_apply_preview()


## Shows the current anti-aliasing, brightness and contrast on the preview die.
func _apply_preview() -> void:
	if _preview == null:
		return
	var data := SaveManager.settings_data
	_preview.mirror_settings(data.antialiasing, data.screen_space_aa, data.brightness, data.contrast)


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
	_apply_preview()


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
	_apply_preview()


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


## Reacting to max FPS options button press
func _on_max_fps_selected(index: int) -> void:
	Engine.max_fps = MAX_FPS[index]
	SaveManager.settings_data.max_fps = MAX_FPS[index]


## Reacting to shadow quality options button press
func _on_shadow_quality_selected(index: int) -> void:
	RenderingServer.directional_shadow_atlas_set_size(SHADOW_ATLAS_SIZES[index], true)
	# Low/Medium/High map to SHADOW_QUALITY_SOFT_LOW..SOFT_HIGH
	RenderingServer.directional_soft_shadow_filter_set_quality(index + 2)
	SaveManager.settings_data.shadow_quality = index


## Reacting to screen selector button press
func _on_screen_selected(index: int) -> void:
	get_window().set_current_screen(index)
	SaveManager.settings_data.screen = index


## Reacting to brightness slider change
func _on_brightness_value_changed(value: float) -> void:
	environment.adjustment_brightness = value
	brightness_label.set_text(str(value).pad_decimals(2))
	SaveManager.settings_data.brightness = value
	_apply_preview()


## Reacting to contrast slider change
func _on_contrast_value_changed(value: float) -> void:
	environment.adjustment_contrast = value
	contrast_label.set_text(str(value).pad_decimals(2))
	SaveManager.settings_data.contrast = value
	_apply_preview()


## Reacting to master volume slider change
func _on_master_volume_value_changed(value: float) -> void:
	var db_value = linear_to_db(value)
	AudioServer.set_bus_volume_db(0, db_value)
	master_volume_label.set_text(str(int(value * 100.0)) + "%")
	SaveManager.settings_data.master_volume = value


## Reacting to music volume slider change
func _on_music_volume_value_changed(value: float) -> void:
	var db_value = linear_to_db(value)
	AudioServer.set_bus_volume_db(1, db_value)
	music_volume_label.set_text(str(int(value * 100.0)) + "%")
	SaveManager.settings_data.music_volume = value


## Reacting to SFX volume slider change
func _on_sfx_volume_value_changed(value: float) -> void:
	var db_value = linear_to_db(value)
	AudioServer.set_bus_volume_db(2, db_value)
	sfx_volume_label.set_text(str(int(value * 100.0)) + "%")
	SaveManager.settings_data.sfx_volume = value


## Reacting to UI volume slider change
func _on_ui_volume_value_changed(value: float) -> void:
	var db_value = linear_to_db(value)
	AudioServer.set_bus_volume_db(3, db_value)
	ui_volume_label.set_text(str(int(value * 100.0)) + "%")
	SaveManager.settings_data.ui_volume = value
