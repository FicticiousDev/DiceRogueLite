extends Node3D

@onready var settings_scene: SettingsScene = $Settings
@onready var exit_confirmation: ConfirmExit = $ConfirmExit
@onready var rules_button = $Rulebook
@onready var rules_ui = $RulesUI
@onready var animation_player = $AnimationPlayer

var original_transform: Transform3D

@export var rules_open_ratio: float = 0.0:
	set(val):
		rules_open_ratio = val
		_update_rulebook_transform()


func _ready() -> void:
	exit_confirmation.exit_confirmed.connect(_on_confirm_exit_pressed)
	exit_confirmation.cancel_exit.connect(_on_cancel_exit_pressed)
	rules_button.rules_pressed.connect(_on_rules_button_rules_pressed)
	rules_ui.close_requested.connect(_on_rules_close_requested)
	
	original_transform = rules_button.global_transform
	
	# Show UI briefly on startup to force layout computation, then hide it
	rules_ui.visible = true
	await get_tree().process_frame
	rules_ui.visible = false


func _process(_delta: float) -> void:
	if rules_open_ratio > 0.0:
		_update_rulebook_transform()


func get_target_transform() -> Transform3D:
	var camera: Camera3D = $Camera
	var control: Control = rules_ui.get_rules_rect()
	
	# Compute global coordinates of the UI section in viewport pixels
	var canvas_global_transform = control.get_global_transform_with_canvas()
	var size = control.size
	var pos_tl = canvas_global_transform * Vector2.ZERO
	var pos_br = canvas_global_transform * size
	var rect = Rect2(pos_tl, pos_br - pos_tl)
	
	# Determine depth: we want to place it in front of the camera.
	var depth = 0.4
	
	# Center of the rect on screen
	var screen_center = rect.get_center()
	var pos_3d = camera.project_position(screen_center, depth)
	
	# Project the corners to calculate the 3D dimensions of the rect at this depth
	var left_3d = camera.project_position(Vector2(rect.position.x, screen_center.y), depth)
	var right_3d = camera.project_position(Vector2(rect.end.x, screen_center.y), depth)
	var top_3d = camera.project_position(Vector2(screen_center.x, rect.position.y), depth)
	var bottom_3d = camera.project_position(Vector2(screen_center.x, rect.end.y), depth)
	
	var width_3d = left_3d.distance_to(right_3d)
	var height_3d = top_3d.distance_to(bottom_3d)
	
	# The tablet's local BoxMesh size is (0.2, 0.01, 0.26)
	var target_scale_x = width_3d / 0.2
	var target_scale_z = height_3d / 0.26
	var target_scale_y = (target_scale_x + target_scale_z) / 2.0
	
	# Calculate basis:
	# Local X is camera right
	# Local Y is camera back (so tablet faces the camera)
	# Local Z is camera down (so top of tablet points up)
	var basis_x = camera.global_transform.basis.x.normalized()
	var basis_y = camera.global_transform.basis.z.normalized()
	var basis_z = -camera.global_transform.basis.y.normalized()
	
	var target_basis = Basis(basis_x, basis_y, basis_z)
	target_basis = target_basis.scaled(Vector3(target_scale_x, target_scale_y, target_scale_z))
	
	return Transform3D(target_basis, pos_3d)


func _update_rulebook_transform() -> void:
	if not is_inside_tree():
		return
		
	if rules_open_ratio <= 0.0:
		rules_button.global_transform = original_transform
		return
	
	var target_trans = get_target_transform()
	
	var orig_pos = original_transform.origin
	var orig_rot = original_transform.basis.get_rotation_quaternion()
	var orig_scale = original_transform.basis.get_scale()
	
	var target_pos = target_trans.origin
	var target_rot = target_trans.basis.get_rotation_quaternion()
	var target_scale = target_trans.basis.get_scale()
	
	# Interpolate position, rotation, and scale independently to avoid skewing
	var current_pos = orig_pos.lerp(target_pos, rules_open_ratio)
	var current_rot = orig_rot.slerp(target_rot, rules_open_ratio)
	var current_scale = orig_scale.lerp(target_scale, rules_open_ratio)
	
	var current_basis = Basis(current_rot).scaled(current_scale)
	rules_button.global_transform = Transform3D(current_basis, current_pos)


func _on_rules_button_rules_pressed() -> void:
	animation_player.play("open_rules")
	
	await animation_player.animation_finished
	rules_ui.visible = true


func _on_rules_close_requested() -> void:
	rules_ui.visible = false
	
	animation_player.play_backwards("open_rules")


func _on_settings_button_settings_pressed() -> void:
	get_node("Settings").show_settings()


func _on_exit_button_exit_pressed() -> void:
	exit_confirmation.show_confirmation()


func _on_confirm_exit_pressed() -> void:
	SaveManager.save_data()
	get_tree().quit()


func _on_cancel_exit_pressed() -> void:
	exit_confirmation.hide_confirmation()
