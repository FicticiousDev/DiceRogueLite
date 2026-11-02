@tool
class_name CameraRig
extends Node3D

## Fixed-angle camera looking down at the rig's position. Pitch is tweakable in the inspector.

@export_range(10.0, 89.0) var pitch_degrees: float = 55.0:
	set(value):
		pitch_degrees = value
		_update_camera()
@export var distance: float = 14.0:
	set(value):
		distance = value
		_update_camera()
@export var fov: float = 40.0:
	set(value):
		fov = value
		_update_camera()
## Screen fractions kept clear when framing: left, top, right, bottom. Bottom leaves room for the dice row.
@export var frame_margins: Vector4 = Vector4(0.04, 0.08, 0.04, 0.2)

@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	_update_camera()


## Centres on [bounds] and finds the closest distance that keeps all its corners inside the frame margins,
## easing in from further out.
func frame(bounds: AABB, animate: bool = true) -> void:
	frame_points(_corners(bounds), animate)


## Like frame(), but fits the given world points (e.g. the outline of every tile), so the shape itself fills the
## frame rather than its bounding box.
func frame_points(points: PackedVector3Array, animate: bool = true) -> void:
	var centre := Vector3.ZERO
	for point in points:
		centre += point
	global_position = centre / maxf(points.size(), 1)
	var viewport_size := get_viewport().get_visible_rect().size
	var safe := Rect2(
		viewport_size * Vector2(frame_margins.x, frame_margins.y),
		viewport_size * Vector2(1.0 - frame_margins.x - frame_margins.z, 1.0 - frame_margins.y - frame_margins.w))

	# Perspective makes the board sit off-centre, so alternate fitting the distance and re-centring
	for pass_index in 4:
		_fit_distance(points, safe)
		_centre_in(points, safe)

	var target := distance
	if animate:
		distance = target * 1.4
		create_tween().tween_property(self, "distance", target, Anim.t(0.9)).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)


## Frames [points] like frame_points(), gliding there from the current view.
func glide(points: PackedVector3Array, duration: float) -> void:
	var from_position := global_position
	var from_distance := distance
	frame_points(points, false)
	var to_position := global_position
	var to_distance := distance
	global_position = from_position
	distance = from_distance
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "global_position", to_position, Anim.t(duration))
	tween.tween_property(self, "distance", to_distance, Anim.t(duration))


## Binary search for the closest distance where [points] fit inside [safe].
func _fit_distance(points: PackedVector3Array, safe: Rect2) -> void:
	var near := 1.0
	var far := 200.0
	for i in 24:
		distance = (near + far) / 2.0
		if safe.encloses(_project(points)):
			far = distance
		else:
			near = distance
	distance = far


## Moves the pivot along the ground so [points] are centred in [safe].
func _centre_in(points: PackedVector3Array, safe: Rect2) -> void:
	var offset := safe.get_center() - _project(points).get_center()
	var pivot_screen := camera.unproject_position(global_position) - offset
	var hit = Plane(Vector3.UP, global_position).intersects_ray(camera.project_ray_origin(pivot_screen), camera.project_ray_normal(pivot_screen))
	if hit != null:
		global_position = hit


## Screen-space rect enclosing [points].
func _project(points: PackedVector3Array) -> Rect2:
	var rect := Rect2(camera.unproject_position(points[0]), Vector2.ZERO)
	for i in range(1, points.size()):
		rect = rect.expand(camera.unproject_position(points[i]))
	return rect


static func _corners(bounds: AABB) -> PackedVector3Array:
	var points := PackedVector3Array()
	for i in 8:
		points.append(bounds.get_endpoint(i))
	return points


func _update_camera() -> void:
	if not is_node_ready():
		return
	var pitch := deg_to_rad(pitch_degrees)
	camera.position = Vector3(0.0, sin(pitch), cos(pitch)) * distance
	camera.rotation = Vector3(-pitch, 0.0, 0.0)
	camera.fov = fov
