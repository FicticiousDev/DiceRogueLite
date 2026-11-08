class_name Die3D
extends RigidBody3D

## A physical die. Collision is always a cube of side [size]; the visible body comes from a swappable DieDesign
## (authored at unit size) and the six faces are quads on the design's flat face areas, textured with the
## DieType's carved symbols. The body and faces wear the player's finish, a design's trim its trim finish (DieFinish),
## unless [member finish] / [member trim_finish] are set. Physics bodies can't be scaled, so animate [visual] for
## squash/pop effects.

enum State { IDLE, SELECTED, USED, DISABLED }

## Face directions in die space, indexed like DieType.faces. Opposite faces sum to 5.
const FACE_NORMALS: Array[Vector3] = [Vector3.UP, Vector3.RIGHT, Vector3.BACK, Vector3.FORWARD, Vector3.LEFT, Vector3.DOWN]
## Which way is "up" on each face's artwork
const FACE_UPS: Array[Vector3] = [Vector3.FORWARD, Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP, Vector3.BACK]
const BODY_SHADER: Shader = preload("res://shaders/die_body.gdshader")
const FACE_SHADER: Shader = preload("res://shaders/die_face.gdshader")
## See-through finishes (DieFinish.is_transparent)
const BODY_GLASS_SHADER: Shader = preload("res://shaders/die_body_glass.gdshader")
const FACE_GLASS_SHADER: Shader = preload("res://shaders/die_face_glass.gdshader")
## Minimum dot between the top face and up to count as lying flat
const FLAT_THRESHOLD: float = 0.97
## Render layer for dice and the tray, lit only by the tray's own light
const DICE_LAYER: int = 2
## Darkens a trim finish so it reads apart from the body
const TRIM_SHADE: float = 0.8

@onready var visual: Node3D = $Visual
@onready var body: MeshInstance3D = $Visual/Body
@onready var faces_root: Node3D = $Visual/Faces
@onready var collision: CollisionShape3D = $Collision

var index: int
var die_type: DieType
var design: DieDesign
## Side length in world units
var size: float = 1.0
## Finishes for the body and faces, and for a design's trim; the player's if not set before it enters the tree
var finish: DieFinish
var trim_finish: DieFinish
var state: State = State.IDLE
var _materials: Array[ShaderMaterial] = []
var _face_materials: Array[ShaderMaterial] = []
var _lift_tween: Tween


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

	if finish == null:
		finish = player_finish(false)
	if trim_finish == null:
		trim_finish = player_finish(true)
	body.mesh = design.mesh
	# The first surface is the body; any other is the design's trim
	for i in design.mesh.get_surface_count():
		body.set_surface_override_material(i, _material(BODY_SHADER, color, finish if i == 0 else trim_finish, 1.0 if i == 0 else TRIM_SHADE))
	body.layers = DICE_LAYER

	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * design.face_size
	for i in 6:
		var textures := DieFaceTextures.get_textures(die_type.faces[i])
		var material := _material(FACE_SHADER, color, finish)
		material.set_shader_parameter("ink_texture", textures[0])
		material.set_shader_parameter("normal_texture", textures[1])
		_face_materials.append(material)
		var face := MeshInstance3D.new()
		face.mesh = quad
		face.material_override = material
		face.layers = DICE_LAYER
		# Quad faces +Z with +Y up; orient it onto face i, just above the surface
		var normal := FACE_NORMALS[i]
		var up := FACE_UPS[i]
		face.transform = Transform3D(Basis(up.cross(normal), up, normal), normal * (design.face_offset + 0.002))
		# The finish's pattern is laid out in die space, so the face carries on the body's
		material.set_shader_parameter("pattern_transform", face.transform)
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


## Redraws one face, e.g. with buff bonuses added, with a pop.
func set_face_display(face_index: int, face: DieFace) -> void:
	var textures := DieFaceTextures.get_textures(face)
	_face_materials[face_index].set_shader_parameter("ink_texture", textures[0])
	_face_materials[face_index].set_shader_parameter("normal_texture", textures[1])
	pop()


## Replaces a face's artwork with custom textures: [ink] (colour, alpha = shape) and [normal] (relief). [recess] is how dark
## the shape is against the face (1: not darkened), e.g. for embossed logos.
func set_face_art(face_index: int, ink: Texture2D, normal: Texture2D, recess: float = 0.45, ink_strength: float = 0.7) -> void:
	var material := _face_materials[face_index]
	material.set_shader_parameter("ink_texture", ink)
	material.set_shader_parameter("normal_texture", normal)
	material.set_shader_parameter("recess_shade", recess)
	material.set_shader_parameter("ink_strength", ink_strength)


## Raises the visual by [offset] (world space) relative to the body, e.g. towards the top of the screen.
func lift(offset: Vector3) -> void:
	if _lift_tween:
		_lift_tween.kill()
	_lift_tween = create_tween()
	_lift_tween.tween_property(visual, "position", global_basis.inverse() * offset, Anim.t(0.15)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func pop() -> void:
	var tween := create_tween()
	tween.tween_property(visual, "scale", Vector3.ONE * size * 1.25, Anim.t(0.08))
	tween.tween_property(visual, "scale", _rest_scale(), Anim.t(0.35)).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Quick side-to-side shake to refuse a click.
func shake(direction: Vector3) -> void:
	var local := global_basis.inverse() * direction
	var base := visual.position
	var tween := create_tween()
	for i in 4:
		tween.tween_property(visual, "position", base + local * (1.0 if i % 2 == 0 else -1.0), Anim.t(0.04))
	tween.tween_property(visual, "position", base, Anim.t(0.04))


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
	create_tween().tween_property(visual, "scale", _rest_scale(), Anim.t(0.15)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _rest_scale() -> Vector3:
	return Vector3.ONE * size * (0.85 if state == State.USED else 1.0)


func _face_towards(direction: Vector3) -> int:
	var best := 0
	var best_dot := -INF
	for i in 6:
		var d := (global_basis * FACE_NORMALS[i]).dot(direction)
		if d > best_dot:
			best_dot = d
			best = i
	return best


## The player's chosen finish (the trim's if [trim]), or a default if it's missing.
static func player_finish(trim: bool) -> DieFinish:
	var progression := SaveManager.progression_data
	var found: DieFinish = Database.get_content("die_finishes", progression.die_trim_finish if trim else progression.die_finish)
	if found == null:
		found = Database.get_content("die_finishes", &"brass" if trim else &"plastic")
	return found


func _material(shader: Shader, color: Color, look: DieFinish, shade: float = 1.0) -> ShaderMaterial:
	if look and look.is_transparent():
		shader = BODY_GLASS_SHADER if shader == BODY_SHADER else FACE_GLASS_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("body_color", color)
	if look:
		look.apply(material)
	material.set_shader_parameter("trim_shade", shade)
	if Rarity.GLOW.has(die_type.rarity):
		material.set_shader_parameter("glow", 1.0)
		material.set_shader_parameter("glow_facing", Rarity.GLOW[die_type.rarity][0])
		material.set_shader_parameter("glow_edge", Rarity.GLOW[die_type.rarity][1])
	_materials.append(material)
	return material
