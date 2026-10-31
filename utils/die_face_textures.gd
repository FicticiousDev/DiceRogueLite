class_name DieFaceTextures
extends RefCounted

## Builds and caches the textures for a die face: an ink map (symbol colour, alpha = carving) and a normal map
## generated from the symbols' height masks so they look pressed into the surface.

const SIZE: int = 256
## Normal map strength
const BUMP_SCALE: float = 6.0

## Symbol centres (0-1 face space) and icon size, by symbol count. Laid out like pips.
const LAYOUTS: Dictionary = {
	1: [[Vector2(0.5, 0.5)], 0.62],
	2: [[Vector2(0.3, 0.3), Vector2(0.7, 0.7)], 0.42],
	3: [[Vector2(0.24, 0.24), Vector2(0.5, 0.5), Vector2(0.76, 0.76)], 0.34],
	4: [[Vector2(0.28, 0.28), Vector2(0.72, 0.28), Vector2(0.28, 0.72), Vector2(0.72, 0.72)], 0.38],
	5: [[Vector2(0.24, 0.24), Vector2(0.76, 0.24), Vector2(0.5, 0.5), Vector2(0.24, 0.76), Vector2(0.76, 0.76)], 0.32],
	6: [[Vector2(0.28, 0.2), Vector2(0.72, 0.2), Vector2(0.28, 0.5), Vector2(0.72, 0.5), Vector2(0.28, 0.8), Vector2(0.72, 0.8)], 0.28],
}

static var _cache: Dictionary = {}
static var _icon_images: Dictionary = {}
static var _tinted_images: Dictionary = {}


## Returns [ink texture, normal texture] for [face].
static func get_textures(face: DieFace) -> Array[Texture2D]:
	var key := face.key()
	if not _cache.has(key):
		_cache[key] = _build(face)
	return _cache[key]


static func _build(face: DieFace) -> Array[Texture2D]:
	var ink := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	ink.fill(Color(0, 0, 0, 0))
	var height := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	height.fill(Color.WHITE)

	var symbols: Array[Symbol.Type] = []
	for face_symbol in face.display_symbols():
		for i in face_symbol.count:
			symbols.append(face_symbol.symbol)
	var layout: Array = _layout(symbols.size())
	var icon_px := int(SIZE * layout[1])
	for i in symbols.size():
		var at := Vector2i(layout[0][i] * SIZE) - Vector2i(icon_px, icon_px) / 2
		var rect := Rect2i(0, 0, icon_px, icon_px)
		ink.blend_rect(_tinted(symbols[i], icon_px, Symbol.INK[symbols[i]]), rect, at)
		height.blend_rect(_tinted(symbols[i], icon_px, Color.BLACK), rect, at)

	# Symbols are low (black) in the height map, so they read as carved
	height.bump_map_to_normal_map(BUMP_SCALE)
	ink.generate_mipmaps()
	height.generate_mipmaps()
	return [ImageTexture.create_from_image(ink), ImageTexture.create_from_image(height)]


static func _layout(count: int) -> Array:
	if LAYOUTS.has(count):
		return LAYOUTS[count]
	# More than six: plain grid
	var columns := ceili(sqrt(count))
	var rows := ceili(float(count) / columns)
	var points: Array[Vector2] = []
	for i in count:
		points.append(Vector2((i % columns + 0.5) / columns, (i / columns + 0.5) / rows))
	return [points, 0.9 / maxi(columns, rows)]


## Icon mask scaled to [px], cached.
static func _icon_mask(type: Symbol.Type, px: int) -> Image:
	var key := "%d:%d" % [type, px]
	if not _icon_images.has(key):
		var image := Symbol.ICONS[type].get_image()
		if image.is_compressed():
			image.decompress()
		image.convert(Image.FORMAT_RGBA8)
		image.resize(px, px, Image.INTERPOLATE_LANCZOS)
		_icon_images[key] = image
	return _icon_images[key]


## Solid [color] with the icon mask's brightness as alpha, cached.
static func _tinted(type: Symbol.Type, px: int, color: Color) -> Image:
	var key := "%d:%d:%s" % [type, px, color.to_html()]
	if not _tinted_images.has(key):
		var mask := _icon_mask(type, px)
		var result := Image.create(px, px, false, Image.FORMAT_RGBA8)
		for y in px:
			for x in px:
				result.set_pixel(x, y, Color(color, mask.get_pixel(x, y).r))
		_tinted_images[key] = result
	return _tinted_images[key]
