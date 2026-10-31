class_name AttackArc
extends MeshInstance3D

## Red arched line from one board position to another, for ranged attacks. A flat ribbon facing the camera,
## rebuilt as it draws in. Positions are in the parent's (board's) space.

const COLOR: Color = Color(1.0, 0.2, 0.15)
const SEGMENTS: int = 28
const WIDTH: float = 0.05
## Height above the tiles where the arc starts and ends, and extra rise per unit of distance
const BASE_HEIGHT: float = 0.55
const RISE_PER_UNIT: float = 0.3

var _from: Vector3
var _to: Vector3
var _material: StandardMaterial3D


## Arc between two tile tops. [progress] 0-1 draws part of it.
func setup(from: Vector3, to: Vector3, progress: float = 1.0) -> void:
	_from = from + Vector3.UP * BASE_HEIGHT
	_to = to + Vector3.UP * BASE_HEIGHT
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.albedo_color = COLOR
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_build(progress)


## Draws in, holds while [hold] is awaited by the caller, then fades out and frees itself.
func play() -> void:
	var tween := create_tween()
	tween.tween_method(_build, 0.0, 1.0, Anim.t(0.25)).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	await tween.finished


func fade_out() -> void:
	var tween := create_tween()
	tween.tween_property(_material, "albedo_color:a", 0.0, Anim.t(0.3))
	tween.tween_callback(queue_free)


func _point(t: float) -> Vector3:
	var rise := BASE_HEIGHT + _from.distance_to(_to) * RISE_PER_UNIT
	var middle := (_from + _to) / 2.0 + Vector3.UP * rise
	return _from.lerp(middle, t).lerp(middle.lerp(_to, t), t)


func _build(progress: float) -> void:
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	var view := camera.global_basis.z if camera else Vector3.BACK
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var count := maxi(2, int(SEGMENTS * progress) + 1)
	for i in count:
		var t := progress * i / (count - 1)
		var tangent := (_point(minf(t + 0.01, 1.0)) - _point(maxf(t - 0.01, 0.0))).normalized()
		var side := tangent.cross(view).normalized() * WIDTH / 2.0
		surface.add_vertex(_point(t) - side)
		surface.add_vertex(_point(t) + side)
	surface.set_material(_material)
	mesh = surface.commit()
