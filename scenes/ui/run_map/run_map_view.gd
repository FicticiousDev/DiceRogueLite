class_name RunMapView
extends CanvasLayer

## The run map, toggled with [M]: every level entered, plus the levels their exits offered. Each shows the same
## symbol as its exit gate, in its biome's colour. Choices not taken are greyed out; levels never offered are hidden.

const DISC: Texture2D = preload("res://assets/ui/disc.png")
const ARROW: Texture2D = preload("res://assets/ui/indicator_arrow.png")
const NODE_SIZE: float = 84.0
const MAX_COLUMN: float = 190.0
const MAX_ROW: float = 130.0
const AREA: Rect2 = Rect2(140, 200, 1640, 720)
const GREY: Color = Color(0.4, 0.4, 0.42)
const TAKEN: Color = Color(1, 1, 1, 0.9)
const PENDING: Color = Color(1, 0.9, 0.55, 0.9)

var _graph: Control
## Lines to draw, as [from, to, color, width]
var _edges: Array[Array] = []
var _bounce: Tween


func _ready() -> void:
	layer = 35
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.06, 0.06, 0.09, 0.97)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(event: InputEvent):
		if event.is_action_pressed("select") or event.is_action_pressed("cancel"):
			toggle())
	add_child(dim)
	var title := Label.new()
	title.text = "MAP"
	title.add_theme_font_size_override("font_size", 56)
	title.position = Vector2(140, 70)
	add_child(title)
	var hint := Label.new()
	hint.text = "[M] close"
	hint.add_theme_font_size_override("font_size", 24)
	hint.modulate.a = 0.6
	hint.position = Vector2(140, 990)
	add_child(hint)
	_graph = Control.new()
	_graph.mouse_filter = Control.MOUSE_FILTER_PASS
	_graph.set_anchors_preset(Control.PRESET_FULL_RECT)
	_graph.draw.connect(_draw_edges)
	add_child(_graph)


func toggle() -> void:
	visible = not visible
	if visible:
		_rebuild()
	elif _bounce:
		_bounce.kill()


func _rebuild() -> void:
	for child in _graph.get_children():
		child.queue_free()
	_edges.clear()
	var run := SaveManager.run_data
	var path: Array[int] = []
	for i in run.path:
		path.append(int(i))

	# Columns follow the route taken; offered levels sit one column on from the level that offered them
	var cells: Dictionary[int, Vector2] = {}
	for i in path.size():
		cells[path[i]] = Vector2(i, float(RunMap.node(run, path[i]).row))
	for i in path.size():
		for next in RunMap.next(run, path[i]):
			if not cells.has(next):
				cells[next] = Vector2(i + 1, float(RunMap.node(run, next).row))
	var rows := cells.values().map(func(c: Vector2): return c.y)
	var columns := maxf(cells.values().map(func(c: Vector2): return c.x).max() + 1.0, 2.0)
	var column := minf(MAX_COLUMN, AREA.size.x / columns)
	var row := minf(MAX_ROW, AREA.size.y / maxf(rows.max() - rows.min(), 1.0))
	var origin := AREA.get_center() - Vector2((columns - 1) * column, (rows.max() + rows.min()) * row) / 2.0
	var at := func(index: int) -> Vector2: return origin + cells[index] * Vector2(column, row)

	var current := path[-1]
	for i in path.size():
		for next in RunMap.next(run, path[i]):
			var taken := i + 1 < path.size() and path[i + 1] == next
			var pending := path[i] == current
			_edges.append([at.call(path[i]), at.call(next), TAKEN if taken else (PENDING if pending else GREY), 8.0 if taken else 4.0])
	for index in cells:
		var greyed := not path.has(index) and not RunMap.next(run, current).has(index)
		_add_node(index, at.call(index), greyed)
	_add_marker(at.call(current))
	_graph.queue_redraw()


func _add_node(index: int, centre: Vector2, greyed: bool) -> void:
	var run := SaveManager.run_data
	var biome := RunMap.biome(run, index)
	var type := RunMap.level(run, index).type
	var color := GREY if greyed else biome.color
	var disc := TextureRect.new()
	disc.texture = DISC
	disc.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	disc.size = Vector2.ONE * NODE_SIZE
	disc.position = centre - disc.size / 2.0
	disc.modulate = color
	disc.tooltip_text = "%s: %s" % [biome.display_name, LevelData.NAMES[type]]
	_graph.add_child(disc)
	var icon := TextureRect.new()
	icon.texture = LevelData.ICONS[type]
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.size = Vector2.ONE * NODE_SIZE * 0.55
	icon.position = (disc.size - icon.size) / 2.0
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	disc.add_child(icon)


## Bouncing arrow over the current level.
func _add_marker(centre: Vector2) -> void:
	var arrow := TextureRect.new()
	arrow.texture = ARROW
	arrow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	arrow.size = Vector2.ONE * 56.0
	arrow.position = centre - Vector2(arrow.size.x / 2.0, NODE_SIZE / 2.0 + arrow.size.y + 4.0)
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_graph.add_child(arrow)
	if _bounce:
		_bounce.kill()
	_bounce = create_tween().set_loops()
	_bounce.tween_property(arrow, "position:y", arrow.position.y - 10.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_bounce.tween_property(arrow, "position:y", arrow.position.y, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _draw_edges() -> void:
	for edge in _edges:
		_graph.draw_line(edge[0], edge[1], edge[2], edge[3], true)
