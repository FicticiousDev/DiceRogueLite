extends Area3D

@onready var animation_player = $AnimationPlayer

var original_transform: Transform3D
var ui_target: CanvasLayer
var camera: Camera3D

signal rules_pressed
signal rules_showing

@export var rules_open_ratio: float = 0.0:
	set(val):
		rules_open_ratio = val
		_update_rulebook_transform()


func _ready() -> void:
	original_transform = global_transform


func _process(_delta: float) -> void:
	if rules_open_ratio > 0.0:
		_update_rulebook_transform()


func _on_input_event(_camera, event, _position, _normal, _shape_idx) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		emit_signal("rules_pressed")


func _update_rulebook_transform() -> void:
	if not is_inside_tree():
		return
		
	if rules_open_ratio <= 0.0:
		global_transform = original_transform
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
	global_transform = Transform3D(current_basis, current_pos)


func get_target_transform() -> Transform3D:
	if not ui_target:
		return original_transform

	var control: Control = ui_target.get_rules_rect()
	
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


func show_rules() -> void:
	animation_player.play("open_rules")
	await animation_player.animation_finished
	emit_signal("rules_showing")


func hide_rules() -> void:
	animation_player.play_backwards("open_rules")


func set_ui_targets(target: CanvasLayer, target_camera: Camera3D) -> void:
	ui_target = target
	camera = target_camera
