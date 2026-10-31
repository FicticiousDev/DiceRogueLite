@tool
class_name Cutout
extends Node3D

## Cardboard cut-out: a stack of textured quads (front + edge layers) standing on its base, turning about Y
## to face the camera. Animate [body] for squash/flip so facing stays independent.

const SHADER: Shader = preload("res://shaders/cutout.gdshader")
const PADDING: float = 0.08

@export var texture: Texture2D = preload("res://icon.svg"):
	set(value):
		texture = value
		_rebuild()
@export var tint: Color = Color.WHITE:
	set(value):
		tint = value
		_rebuild()
## Height of the texture in world units (excludes the outline border)
@export var height: float = 0.8:
	set(value):
		height = value
		_rebuild()
@export var thickness: float = 0.05:
	set(value):
		thickness = value
		_rebuild()
@export_range(2, 8) var layers: int = 4:
	set(value):
		layers = value
		_rebuild()
@export var outline_width: float = 0.05:
	set(value):
		outline_width = value
		_rebuild()
@export var face_camera: bool = true
@export var casts_shadow: bool = true:
	set(value):
		casts_shadow = value
		_rebuild()

var body: Node3D


func _ready() -> void:
	_rebuild()


func _process(_delta: float) -> void:
	if not face_camera:
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	# Turn about Y only; the quads' front faces +Z
	var to_camera := camera.global_position - global_position
	global_rotation.y = atan2(to_camera.x, to_camera.z)


func _rebuild() -> void:
	if not is_node_ready() or texture == null:
		return
	if body:
		body.free()
	body = Node3D.new()
	add_child(body)

	var aspect := float(texture.get_width()) / texture.get_height()
	var size := Vector2(height * aspect, height) / (1.0 - 2.0 * PADDING)
	var quad := QuadMesh.new()
	quad.size = size
	# Bottom of the texture sits on y = 0
	quad.center_offset = Vector3(0.0, size.y / 2.0 - size.y * PADDING, 0.0)

	for i in layers:
		var material := ShaderMaterial.new()
		material.shader = SHADER
		material.set_shader_parameter("texture_albedo", texture)
		material.set_shader_parameter("tint", tint)
		material.set_shader_parameter("outline_width", outline_width)
		material.set_shader_parameter("padding", PADDING)
		material.set_shader_parameter("is_edge", i > 0)
		var layer := MeshInstance3D.new()
		layer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if casts_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		layer.mesh = quad
		layer.material_override = material
		layer.position.z = thickness / 2.0 - thickness * i / (layers - 1)
		body.add_child(layer)
