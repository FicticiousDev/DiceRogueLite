class_name GridOverlay
extends Node3D

## Debug: outlines every Layout cell at full cell size on its tile's top height (the boundaries picking uses),
## labels cells with their coordinates, marks where the mouse ray hit, and draws a 2D crosshair where Godot
## reports the mouse to be.

const LINE_COLOR: Color = Color(1.0, 0.9, 0.1)
const HOVER_COLOR: Color = Color(1.0, 0.2, 0.9)
const LIFT: float = 0.03

var _board: Board
var _hover_mesh: MeshInstance3D
var _marker: MeshInstance3D
var _crosshair: Control


func setup(board: Board) -> void:
	_board = board
	var lines := MeshInstance3D.new()
	lines.mesh = _outline_mesh(board.tiles.keys(), LINE_COLOR, 1)
	lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(lines)

	for tile: HexTile in board.tiles.values():
		var label := Label3D.new()
		label.text = "%d,%d" % [tile.coords.x, tile.coords.y]
		label.font_size = 28
		label.pixel_size = 0.004
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.position = tile.position + Vector3.UP * (tile.top_height() + LIFT)
		add_child(label)

	_hover_mesh = MeshInstance3D.new()
	_hover_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_hover_mesh)

	_marker = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.03
	sphere.height = 0.06
	sphere.material = _material()
	_marker.mesh = sphere
	_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_marker)

	var layer := CanvasLayer.new()
	layer.layer = 99
	add_child(layer)
	_crosshair = Control.new()
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crosshair.set_anchors_preset(Control.PRESET_FULL_RECT)
	_crosshair.draw.connect(_draw_crosshair)
	layer.add_child(_crosshair)


func _process(_delta: float) -> void:
	_crosshair.queue_redraw()


func _draw_crosshair() -> void:
	var m := _crosshair.get_local_mouse_position()
	_crosshair.draw_line(m - Vector2(14, 0), m + Vector2(14, 0), Color.CYAN, 2.0)
	_crosshair.draw_line(m - Vector2(0, 14), m + Vector2(0, 14), Color.CYAN, 2.0)


## Outlines [tile_id] and moves the marker to [point] (board-local).
func show_pick(tile_id: int, point: Vector3) -> void:
	_hover_mesh.mesh = _outline_mesh([tile_id], HOVER_COLOR, 3) if _board.has_tile(tile_id) else null
	_marker.visible = _board.has_tile(tile_id)
	_marker.position = point


## Hex outlines at full cell radius. [passes] > 1 draws slightly inset copies to fake a thicker line.
func _outline_mesh(tile_ids: Array, color: Color, passes: int) -> ImmediateMesh:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, _material())
	mesh.surface_set_color(color)
	for tile_id in tile_ids:
		var tile := _board.get_tile(tile_id)
		var centre := tile.position + Vector3.UP * (tile.top_height() + LIFT)
		for p in passes:
			var r := tile.radius * (1.0 - p * 0.015)
			for i in 6:
				mesh.surface_add_vertex(centre + _corner(r, i))
				mesh.surface_add_vertex(centre + _corner(r, i + 1))
	mesh.surface_end()
	return mesh


## Pointy-top corner (corner 0 on +Z), matching HexTile and the 2D layout.
func _corner(r: float, i: int) -> Vector3:
	var angle := deg_to_rad(60.0 * i)
	return Vector3(r * sin(angle), 0.0, r * cos(angle))


func _material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.no_depth_test = true
	material.render_priority = 10
	material.albedo_color = Color.WHITE
	return material
