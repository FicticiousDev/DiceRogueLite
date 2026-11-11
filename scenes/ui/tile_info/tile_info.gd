class_name TileInfo
extends PanelContainer

## Strip just above the dice row naming the hovered tile: its terrain, the cost to move onto it and the piece on it.

const MOVE: Texture2D = preload("res://assets/ui/icons/move.png")
## Gap between the strip and the centre of the dice row, in pixels
const ROW_CLEARANCE: float = 62.0
const FONT_SIZE: int = 28

## Horizontal centre of the play area and the dice row's height, as screen fractions
var center_x: float = 0.5
var row_y: float = 0.91
var _swatch: Panel
var _swatch_style: StyleBoxFlat
var _terrain: Label
var _cost: Label
var _piece_dot: Label
var _piece: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.09, 0.85)
	style.set_corner_radius_all(10)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	add_theme_stylebox_override("panel", style)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(line)

	_swatch = Panel.new()
	_swatch_style = StyleBoxFlat.new()
	_swatch_style.set_corner_radius_all(4)
	_swatch.add_theme_stylebox_override("panel", _swatch_style)
	_swatch.custom_minimum_size = Vector2.ONE * 18
	_swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(_swatch)
	_terrain = _label(line, Color.WHITE)
	_label(line, Color(0.55, 0.55, 0.6)).text = "·"
	var icon := TextureRect.new()
	icon.texture = MOVE
	icon.modulate = Color(0.75, 0.85, 1.0)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2.ONE * 24
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(icon)
	_cost = _label(line, Color(0.75, 0.85, 1.0))
	_piece_dot = _label(line, Color(0.55, 0.55, 0.6))
	_piece_dot.text = "·"
	_piece = _label(line, InfoPanel.TITLE_COLOR)


func _process(_delta: float) -> void:
	if visible:
		size = get_combined_minimum_size()
		var screen := get_viewport_rect().size
		position = Vector2(screen.x * center_x - size.x / 2.0, screen.y * row_y - ROW_CLEARANCE - size.y)


## Shows tile [tile_id] of [board].
func show_tile(board: Board, tile_id: int) -> void:
	var tile := board.get_tile(tile_id)
	_swatch_style.bg_color = Terrain.COLORS[tile.terrain]
	_terrain.text = tr("TERRAIN_" + Terrain.Type.keys()[tile.terrain])
	var cost := board.move_cost(tile_id)
	_cost.text = tr("TILE_MOVE_COST") % cost if cost > 0 else tr("TILE_IMPASSABLE")
	var piece_name := piece_name(board, tile_id)
	_piece.text = piece_name
	_piece.visible = piece_name != ""
	_piece_dot.visible = _piece.visible
	visible = true


func clear() -> void:
	visible = false


## Display name of the piece on [tile_id] (or a chest or Mystery piece lying there), or "".
static func piece_name(board: Board, tile_id: int) -> String:
	var piece := board.get_piece(tile_id)
	if piece is Player:
		return piece.character.display_name if piece.character else TranslationServer.translate("PIECE_PLAYER")
	if piece is Enemy:
		return piece.data.display_name
	if piece is Building:
		return (TranslationServer.translate("PIECE_SHOP") if piece.kind == Building.Kind.SHOP else TranslationServer.translate("PIECE_BANK")) + ("  " + TranslationServer.translate("PIECE_CLOSED_SUFFIX") if piece.closed else "")
	if piece is ExitGate:
		var run := SaveManager.run_data
		return TranslationServer.translate("PIECE_GATE") % [RunMap.biome(run, piece.target).display_name, TranslationServer.translate(LevelData.NAMES[RunMap.level(run, piece.target).type])]
	if piece:
		return TranslationServer.translate("PIECE_" + piece.scene_file_path.get_file().get_basename().to_upper())
	# Chests and Mystery pieces don't occupy their tile
	for child in board.pieces_root.get_children():
		if child is BoardPiece and child.tile_id == tile_id and not child.is_queued_for_deletion():
			if child is Loot:
				return TranslationServer.translate("PIECE_CHEST")
			if child is Mystery:
				return TranslationServer.translate("PIECE_MYSTERY")
	return ""


func _label(parent: Control, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", color)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label
