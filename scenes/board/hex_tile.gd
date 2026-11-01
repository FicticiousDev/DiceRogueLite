class_name HexTile
extends Node3D

## A 3D tile placed from a cell of the board's 2D Layout layer, linked to it by [id] and [coords].

enum Highlight { NONE, VALID, INVALID, MOVABLE, TARGET }

const HIGHLIGHT_COLORS: Dictionary[Highlight, Color] = {
	Highlight.VALID: Color(0.35, 1.0, 0.45, 0.5),
	Highlight.INVALID: Color(1.0, 0.3, 0.3, 0.5),
	Highlight.MOVABLE: Color(0.35, 0.65, 1.0, 0.5),
	Highlight.TARGET: Color(1.0, 0.55, 0.1, 0.6),
}
const SELECTED_COLOR: Color = Color(1.0, 1.0, 1.0, 0.45)
## Body radius as a fraction of the cell radius, leaving a small gap between tiles
const BODY_SCALE: float = 0.95

@export var intro_duration: float = 0.6
@export var intro_drop: float = 1.5
@export var outro_duration: float = 0.35

@onready var body: MeshInstance3D = $Body
@onready var highlight_mesh: MeshInstance3D = $Highlight
@onready var selected_mesh: MeshInstance3D = $Selected

var id: int
var coords: Vector2i
var terrain: Terrain.Type
var radius: float
var color: Color
var highlight: Highlight = Highlight.NONE
## Piece standing on this tile, if any. Set by BoardPiece.
var piece: BoardPiece
var played: bool = false

# Shared between all tiles, keyed by terrain/highlight
static var _body_meshes: Dictionary = {}
static var _overlay_meshes: Dictionary = {}
static var _materials: Dictionary = {}


## Call before adding to the tree.
func setup(cell: Vector2i, type: Terrain.Type, cell_radius: float, tile_color: Color) -> void:
	coords = cell
	id = Hex.id(cell)
	terrain = type
	radius = cell_radius
	color = tile_color


func _ready() -> void:
	body.mesh = _get_body_mesh()
	body.position.y = top_height() / 2.0
	highlight_mesh.mesh = _get_overlay_mesh(0.8)
	highlight_mesh.position.y = top_height() + 0.01
	selected_mesh.mesh = _get_overlay_mesh(0.95)
	selected_mesh.material_override = _get_overlay_material(SELECTED_COLOR)
	selected_mesh.position.y = top_height() + 0.02
	clear_highlights()


## World-space height of the tile's top surface, relative to the board.
func top_height() -> float:
	return Terrain.HEIGHTS[terrain]


# ===========================================================================================================================================
# Highlights
# ===========================================================================================================================================


func set_highlight(kind: Highlight) -> void:
	highlight = kind
	highlight_mesh.visible = kind != Highlight.NONE
	if highlight_mesh.visible:
		highlight_mesh.material_override = _get_overlay_material(HIGHLIGHT_COLORS[kind])


func set_selected(selected: bool) -> void:
	selected_mesh.visible = selected


func clear_highlights() -> void:
	set_highlight(Highlight.NONE)
	set_selected(false)


# ===========================================================================================================================================
# Intro
# ===========================================================================================================================================


func play_intro(delay: float = 0.0) -> void:
	if played:
		return
	played = true
	visible = false

	await get_tree().create_timer(Anim.t(delay)).timeout

	visible = true
	var end_pos := position
	position.y += intro_drop
	scale = Vector3.ONE * 0.01

	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector3.ONE, Anim.t(intro_duration)).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", end_pos, Anim.t(intro_duration * 0.6)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Appears in place with no animation.
func show_now() -> void:
	played = true
	visible = true


## Shrinks away, rising. The reverse of the intro.
func play_outro(delay: float = 0.0) -> void:
	await get_tree().create_timer(Anim.t(delay)).timeout
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector3.ONE * 0.01, Anim.t(outro_duration)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "position:y", position.y + intro_drop, Anim.t(outro_duration)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished
	visible = false


# ===========================================================================================================================================
# Meshes
# ===========================================================================================================================================


func _get_body_mesh() -> Mesh:
	var key := "%d:%f:%s" % [terrain, radius, color]
	if not _body_meshes.has(key):
		# CylinderMesh with 6 segments has a corner on +Z, matching the pointy-top 2D layout (2D y -> 3D z)
		var mesh := CylinderMesh.new()
		mesh.radial_segments = 6
		mesh.rings = 1
		mesh.top_radius = radius * BODY_SCALE
		mesh.bottom_radius = radius * BODY_SCALE
		mesh.height = top_height()
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.9
		mesh.material = material
		_body_meshes[key] = mesh
	return _body_meshes[key]


func _get_overlay_mesh(size: float) -> Mesh:
	var key := "%f:%f" % [radius, size]
	if not _overlay_meshes.has(key):
		var mesh := CylinderMesh.new()
		mesh.radial_segments = 6
		mesh.rings = 1
		mesh.top_radius = radius * size
		mesh.bottom_radius = radius * size
		mesh.height = 0.01
		_overlay_meshes[key] = mesh
	return _overlay_meshes[key]


func _get_overlay_material(color: Color) -> Material:
	if not _materials.has(color):
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = color
		_materials[color] = material
	return _materials[color]
