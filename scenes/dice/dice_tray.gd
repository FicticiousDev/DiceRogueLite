class_name DiceTray
extends Node3D

## Rolls dice in a tray that floats between the board camera and the board, in the same 3D world.
## Sequence: board dims, tray slides in, dice drop straight down into it from above the top of the screen (inside a
## tall invisible tube so none escape), settle, fly over the front rim to a grouped row along the bottom of the
## screen showing their results, and the tray slides out. Dice stay in the row until the next roll or clear().
## The tray is authored in "tray units" (10 x 7 felt) and scaled so it always fills the same part of the screen.
## Dice and tray are on render layer 2 with their own light.

signal roll_finished(results: Array[DieResult])

const DIE_SCENE: PackedScene = preload("res://scenes/dice/die_3d.tscn")
## Distance (tray units) the tray layout was designed to be viewed from; sets world scale = tray_distance / this
const DESIGN_VIEW_DISTANCE: float = 16.7

## Distance from the camera to the tray centre, in world units. Shrunk for cameras close to the board.
@export var tray_distance: float = 8.0
## Screen point (fractions) the tray centre sits under
@export var tray_screen_point: Vector2 = Vector2(0.5, 0.42)
@export var settle_timeout: float = 4.0
## Row position as a fraction of screen height
@export var row_screen_y: float = 0.91
## Screen x (0-1) of the row centre
@export var row_screen_x: float = 0.5
@export var row_spacing_px: float = 112.0
@export var group_gap_px: float = 56.0
## Distance from the camera to the row (tray units); sets how big row dice look
@export var row_depth: float = 15.0
## Where the tray waits off screen (beyond the top edge), relative to its home (tray units)
@export var tray_offscreen_offset: Vector3 = Vector3(0, 0, -18)
## Height (tray units, above the tray floor) dice rise to on the way to the row, so they clear the front rim
@export var row_lift_height: float = 5.5
## Vertical gap (tray units) between dropped dice so they don't start overlapping
@export var drop_spacing: float = 1.4
@export var dim_alpha: float = 0.45

@onready var tray: Node3D = %Tray
@onready var dice_root: Node3D = %Dice
@onready var dim: MeshInstance3D = %Dim

var camera: Camera3D
var dice: Array[Die3D] = []
var rolling: bool = false
## World units per tray unit for the current roll
var _scale: float = 1.0
var _tray_home: Transform3D
var _tray_yaw: float
var _dim_material: StandardMaterial3D


func _ready() -> void:
	tray.visible = false
	_dim_material = dim.material_override
	_dim_material.albedo_color.a = 0.0
	dim.visible = false


## Rolls [types] using [design] and returns one result per die, in pool order. Awaitable.
func roll(types: Array[DieType], design: DieDesign) -> Array[DieResult]:
	rolling = true
	await clear()
	_place()
	_fade_dim(dim_alpha)
	await _slide_tray(true)

	var fast := SaveManager.settings_data.fast_dice
	for i in types.size():
		var die: Die3D = DIE_SCENE.instantiate()
		die.setup(i, types[i], design, _scale)
		# Positioned before entering the tree so it never appears in the tray first
		if not fast:
			die.position = _drop_position(i)
			die.basis = Basis.from_euler(Vector3(randf() * TAU, randf() * TAU, randf() * TAU))
			die.angular_velocity = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized() * randf_range(8.0, 16.0)
		dice_root.add_child(die)
		dice.append(die)

	if fast:
		_place_fast()
		await get_tree().create_timer(Anim.t(0.25)).timeout
	else:
		await _settle()

	var results: Array[DieResult] = []
	for die in dice:
		results.append(DieResult.new(die.index, die.die_type, die.top_face()))

	await _arrange_row(results)
	_fade_dim(0.0)
	await _slide_tray(false)
	rolling = false
	roll_finished.emit(results)
	return results


## Removes the dice currently shown. Awaitable.
func clear() -> void:
	if dice.is_empty():
		return
	var tween := create_tween().set_parallel(true)
	for die in dice:
		tween.tween_property(die.visual, "scale", Vector3.ONE * 0.01, Anim.t(0.2)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await tween.finished
	for die in dice:
		die.queue_free()
	dice.clear()


## Pool index of the die under a screen position, or -1.
func get_die_at(screen_position: Vector2) -> int:
	for die in dice:
		if camera.unproject_position(die.global_position).distance_to(screen_position) < row_spacing_px * 0.45:
			return die.index
	return -1


func get_die(pool_index: int) -> Die3D:
	for die in dice:
		if die.index == pool_index:
			return die
	return null


# ===========================================================================================================================================
# Placement
# ===========================================================================================================================================


## Positions the tray, level and facing the same way as the camera, under [tray_screen_point], and the dim card
## between the tray and the board.
func _place() -> void:
	var screen := get_viewport().get_visible_rect().size
	var board_distance := camera.global_position.y
	var distance := minf(tray_distance, board_distance * 0.45)
	_scale = distance / DESIGN_VIEW_DISTANCE
	var centre := camera.project_position(screen * tray_screen_point, distance)
	var forward := -camera.global_basis.z
	_tray_yaw = atan2(-forward.x, -forward.z)
	_tray_home = Transform3D(Basis(Vector3.UP, _tray_yaw).scaled(Vector3.ONE * _scale), centre)

	# Dim card: behind the tray, in front of the board, covering the screen
	var dim_distance := distance * 1.45
	var height := 2.0 * dim_distance * tan(deg_to_rad(camera.fov) / 2.0)
	dim.mesh.size = Vector2(height * screen.x / screen.y, height) * 1.2
	dim.global_transform = Transform3D(camera.global_basis, camera.global_position - camera.global_basis.z * dim_distance)


## Tray-unit position over the tray home, in world space.
func _tray_point(local: Vector3) -> Vector3:
	return _tray_home * local


# ===========================================================================================================================================
# Rolling
# ===========================================================================================================================================


## Random spot over the tray, just above the top edge of the screen. Later dice start higher so they don't overlap.
func _drop_position(order: int) -> Vector3:
	var spot := _tray_point(Vector3(randf_range(-3.5, 3.5), 0.0, randf_range(-2.5, 2.5)))
	var step := 0.25 * _scale
	# Raise until the die is fully off the top of the screen (or behind the camera)
	while not camera.is_position_behind(spot) and camera.unproject_position(spot).y > -row_spacing_px and spot.y < camera.global_position.y + 10.0:
		spot.y += step
	return spot + Vector3.UP * order * drop_spacing * _scale


## Waits for the dice to stop. Tilted dice (resting on a wall or another die) get nudged, then snapped flat.
func _settle() -> void:
	var elapsed := 0.0
	var still_for := 0.0
	var nudges := 0
	while elapsed < settle_timeout:
		await get_tree().physics_frame
		var step := get_physics_process_delta_time()
		elapsed += step
		still_for = still_for + step if _all_still() else 0.0
		if still_for < 0.25:
			continue
		var tilted := dice.filter(func(d: Die3D): return not d.is_flat())
		if tilted.is_empty() or nudges >= 2:
			break
		nudges += 1
		still_for = 0.0
		for die: Die3D in tilted:
			die.apply_central_impulse(Vector3(randf_range(-1, 1), 3.0, randf_range(-1, 1)) * _scale)
			die.apply_torque_impulse(Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * 2.0 * _scale)
	for die in dice:
		die.freeze = true
		if not die.is_flat():
			die.snap_flat()


func _all_still() -> bool:
	for die in dice:
		if die.linear_velocity.length() > 0.05 * _scale or die.angular_velocity.length() > 0.05:
			return false
	return true


## Fast dice setting: no physics, dice pop in already showing a random face.
func _place_fast() -> void:
	for i in dice.size():
		var die := dice[i]
		die.freeze = true
		die.position = _tray_point(Vector3((i % 5 - 2) * 1.6, 0.5, (i / 5) * 1.6 - 0.8))
		die.basis = Basis(Vector3.UP, _tray_yaw) * Die3D.basis_facing(randi() % 6, Basis(Vector3.RIGHT, Vector3.FORWARD, Vector3.UP))
		die.visual.scale = Vector3.ONE * 0.01
		create_tween().tween_property(die.visual, "scale", Vector3.ONE * _scale, Anim.t(0.25)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ===========================================================================================================================================
# Row
# ===========================================================================================================================================


## Flies each die to its slot in the row, turning its result face to the camera. Grouped attack, defence,
## move, other; within a group, higher totals first.
func _arrange_row(results: Array[DieResult]) -> void:
	var ordered := results.duplicate()
	ordered.sort_custom(func(a: DieResult, b: DieResult):
		if a.category() != b.category():
			return a.category() < b.category()
		if a.value() != b.value():
			return a.value() > b.value()
		return a.index < b.index)

	# Screen x for each slot, with a gap between groups
	var xs: Array[float] = []
	var x := 0.0
	for i in ordered.size():
		if i > 0:
			x += row_spacing_px
			if ordered[i].category() != ordered[i - 1].category():
				x += group_gap_px
		xs.append(x)
	var screen := get_viewport().get_visible_rect().size
	var offset: float = screen.x * row_screen_x - xs.back() / 2.0

	var last: Tween
	for i in ordered.size():
		var die := get_die(ordered[i].index)
		var target := camera.project_position(Vector2(offset + xs[i], screen.y * row_screen_y), row_depth * _scale)
		last = _fly_to(die, target, Die3D.basis_facing(ordered[i].face_index, _facing_camera(target)), i * 0.05)
	if last:
		await last.finished


## Basis whose +Z points from [point] at the camera, upright relative to the screen. Perspective would show
## the sides of dice away from the centre if they only matched the camera's rotation.
func _facing_camera(point: Vector3) -> Basis:
	var z := (camera.global_position - point).normalized()
	var x := camera.global_basis.y.cross(z).normalized()
	return Basis(x, z.cross(x), z)


func _fly_to(die: Die3D, target: Vector3, target_basis: Basis, delay: float) -> Tween:
	die.freeze = true
	var from := die.position
	# Rise straight up out of the tray, cross over the rim, drop straight onto the slot
	var height := _tray_home.origin.y + row_lift_height * _scale
	var control_1 := Vector3(from.x, height, from.z)
	var control_2 := Vector3(target.x, height, target.z)
	var from_rotation := die.quaternion
	var to_rotation := target_basis.get_rotation_quaternion()
	var size := Vector3.ONE * _scale
	var tween := create_tween()
	tween.tween_interval(Anim.t(delay))
	tween.tween_method(func(t: float):
		die.position = from.bezier_interpolate(control_1, control_2, target, t)
		die.quaternion = from_rotation.slerp(to_rotation, t), 0.0, 1.0, Anim.t(0.5)).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	# Punchy landing in the row
	tween.tween_property(die.visual, "scale", size * Vector3(1.15, 0.85, 1.15), Anim.t(0.06))
	tween.tween_property(die.visual, "scale", size, Anim.t(0.3)).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	return tween


# ===========================================================================================================================================
# Tray
# ===========================================================================================================================================


func _slide_tray(show: bool) -> void:
	var away := Transform3D(_tray_home.basis, _tray_point(tray_offscreen_offset))
	var tween := create_tween()
	if show:
		tray.visible = true
		tray.global_transform = away
		tween.tween_property(tray, "global_transform", _tray_home, Anim.t(0.45)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		tween.tween_property(tray, "global_transform", away, Anim.t(0.3)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await tween.finished
	tray.visible = show


func _fade_dim(alpha: float) -> void:
	dim.visible = true
	var tween := create_tween()
	tween.tween_property(_dim_material, "albedo_color:a", alpha, Anim.t(0.25))
	if is_zero_approx(alpha):
		tween.tween_callback(func(): dim.visible = false)
