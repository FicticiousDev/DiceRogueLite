class_name ShaderList
extends RefCounted

## Everything the loading screen compiles before the game starts (ShaderWarmup). Add new shaders and materials here.
##
## Dice need no entry: every design in data/die_designs is drawn in an opaque and a glass finish, which covers the
## die_body*/die_face* shaders. A new die shader only has to be wired into Die3D.

## Spatial shaders; each is drawn on a quad
const SPATIAL_SHADERS: Array[String] = [
	"res://shaders/cutout.gdshader",
	"res://shaders/streak.gdshader",
]

## Canvas item shaders; each is drawn on a small TextureRect
const CANVAS_SHADERS: Array[String] = [
	"res://shaders/mask_icon.gdshader",
]

## 3D scenes that are safe to instance with no setup; their materials are compiled as they are. For anything built in
## code, add a stand-in with the same flags to [method materials] instead.
const SCENES_3D: Array[String] = [
]


## Stand-ins for StandardMaterial3Ds that are created in code. Each combination of flags is its own shader, so these
## mirror the flags used in game: lit opaque (tile bodies, tray), unshaded (tile mark ring), unshaded + alpha (tile
## highlights, tray dim) and unshaded + alpha + no culling (attack arc).
static func materials() -> Array[Material]:
	var list: Array[Material] = []
	var lit := StandardMaterial3D.new()
	lit.roughness = 0.9
	list.append(lit)
	var unshaded := StandardMaterial3D.new()
	unshaded.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	list.append(unshaded)
	var overlay := StandardMaterial3D.new()
	overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	list.append(overlay)
	var arc := StandardMaterial3D.new()
	arc.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	arc.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	arc.cull_mode = BaseMaterial3D.CULL_DISABLED
	list.append(arc)
	return list
