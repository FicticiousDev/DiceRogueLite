class_name Die3D
extends RigidBody3D

## A physical die. Collision is always a cube of side [size]; the visible body comes from a swappable DieDesign
## (authored at unit size) and the six faces are quads on the design's flat face areas, textured with the
## DieType's carved symbols. Physics bodies can't be scaled, so animate [visual] for squash/pop effects.

enum State { IDLE, SELECTED, USED, DISABLED }

## Face directions in die space, indexed like DieType.faces. Opposite faces sum to 5.
const FACE_NORMALS: Array[Vector3] = [Vector3.UP, Vector3.RIGHT, Vector3.BACK, Vector3.FORWARD, Vector3.LEFT, Vector3.DOWN]
## Which way is "up" on each face's artwork
const FACE_UPS: Array[Vector3] = [Vector3.FORWARD, Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP, Vector3.BACK]
const BODY_SHADER: Shader = preload("res://shaders/die_body.gdshader")
const FACE_SHADER: Shader = preload("res://shaders/die_face.gdshader")
## Minimum dot between the top face and up to count as lying flat
const FLAT_THRESHOLD: float = 0.97
## Render layer for dice and the tray, lit only by the tray's own light
const DICE_LAYER: int = 2

@onready var visual: Node3D = $Visual
@onready var body: MeshInstance3D = $Visual/Body
@onready var faces_root: Node3D = $Visual/Faces
@onready var collision: CollisionShape3D = $Collision

var index: int
var die_type: DieType
var design: DieDesign
## Side length in world units
var size: float = 1.0
var state: State = State.IDLE
var _materials: Array[ShaderMaterial] = []


## Call before adding to the tree.
func setup(pool_index: int, type: DieType, die_design: DieDesign, die_size: float = 1.0) -> void:
	index = pool_index
	die_type = type
	design = die_design
	size = die_size


func _ready() -> void:
	var color := Rarity.COLORS[die_type.rarity]
	var shape := BoxShape3D.new()
	shape.size = Vector3.ONE * size
	collision.shape = shape
	visual.scale = Vector3.ONE * size

	body.mesh = design.mesh
	body.material_override = _material(BODY_SHADER, color)
	body.layers = DICE_LAYER

	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * design.face_size
	for i in 6:
		var textures := DieFaceTextures.get_textures(die_type.faces[i])
		var material := _material(FACE_SHADER, color)
		material.set_shader_parameter("ink_texture", textures[0])
		material.set_shader_parameter("normal_texture", textures[1])
		var face := MeshInstance3D.new()
		face.mesh = quad
		face.material_override = material
		face.layers = DICE_LAYER
		# Quad faces +Z with +Y up; orient it onto face i, just above the surface
		var normal := FACE_NORMALS[i]
		var up := FACE_UPS[i]
		face.transform = Transform3D(Basis(up.cross(normal), up, normal), normal * (design.face_offset + 0.002))
		faces_root.add_child(face)


## Face index currently pointing most upwards.
func top_face() -> int:
	return _face_towards(Vector3.UP)


func is_flat() -> bool:
	return (global_basis * FACE_NORMALS[top_face()]).dot(Vector3.UP) >= FLAT_THRESHOLD


## Rotation that shows [face_index] to a camera with the given basis, artwork upright.
static func basis_facing(face_index: int, camera_basis: Basis) -> Basis:
	var normal := FACE_NORMALS[face_index]
	var up := FACE_UPS[face_index]
	var local := Basis(up.cross(normal), up, normal)
	var target := Basis(camera_basis.x, camera_basis.y, camera_basis.z)
	return target * local.transposed()


## Rotates so the given face points straight up, keeping the current heading. Used to settle tilted dice.
func snap_flat() -> void:
	var face := top_face()
	var current := global_basis * FACE_NORMALS[face]
	global_basis = Basis(Quaternion(current.normalized(), Vector3.UP)) * global_basis


func set_state(new_state: State) -> void:
	state = new_state
	var dim := 0.0
	match state:
		State.USED:
			dim = 0.8
		State.DISABLED:
			dim = 0.5
	for material in _materials:
		material.set_shader_parameter("dim", dim)


func _face_towards(direction: Vector3) -> int:
	var best := 0
	var best_dot := -INF
	for i in 6:
		var d := (global_basis * FACE_NORMALS[i]).dot(direction)
		if d > best_dot:
			best_dot = d
			best = i
	return best


func _material(shader: Shader, color: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("body_color", color)
	material.set_shader_parameter("roughness", design.roughness)
	material.set_shader_parameter("metallic", design.metallic)
	if Rarity.GLOW.has(die_type.rarity):
		material.set_shader_parameter("glow", 1.0)
		material.set_shader_parameter("glow_facing", Rarity.GLOW[die_type.rarity][0])
		material.set_shader_parameter("glow_edge", Rarity.GLOW[die_type.rarity][1])
	_materials.append(material)
	return material
