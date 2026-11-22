class_name Building
extends BoardPiece

## A large piece the player uses by clicking it once the level is clear: a shop (the run opens the ShopMenu with its
## [member stock]) or a bank (BankMenu). Art: TEXTURES (the cut-out) with the ICONS symbol above it.
## A closed building can't be used: it swaps to its CLOSED_TEXTURES art if it has one, otherwise it's greyed out.
## A bank closes after one deposit or withdrawal.

enum Kind { SHOP, BANK }

const TEXTURES: Dictionary[Kind, Texture2D] = {
	Kind.SHOP: preload("res://assets/pieces/buildings/shop.png"),
	Kind.BANK: preload("res://assets/pieces/buildings/bank.png"),
}
const CLOSED_TEXTURES: Dictionary[Kind, Texture2D] = {
	Kind.BANK: preload("res://assets/pieces/buildings/bank_closed.png"),
}
const ICONS: Dictionary[Kind, Texture2D] = {
	Kind.SHOP: preload("res://assets/pieces/buildings/shop_symbol.png"),
	Kind.BANK: preload("res://assets/pieces/buildings/bank_symbol.png"),
}
const TINTS: Dictionary[Kind, Color] = {
	Kind.SHOP: Color(0.45, 0.85, 0.78),
	Kind.BANK: Color(0.95, 0.75, 0.4),
}
const CLOSED_TINT: Color = Color(0.38, 0.38, 0.42)

@onready var symbol: Sprite3D = $Cutout/Symbol
@onready var backing: Sprite3D = $Cutout/Symbol/Backing

var kind: Kind = Kind.SHOP
## Shop only: the offers (DieType / EquipmentData, see ShopStock) and which of them have been bought
var stock: Array[Resource] = []
var sold: Array[bool] = []
var closed: bool = false


## Call before adding to the tree.
func setup(building_kind: Kind) -> void:
	kind = building_kind


func _ready() -> void:
	symbol.texture = ICONS[kind]
	_apply_look()


func set_hovered(hovered: bool) -> void:
	create_tween().tween_property(cutout, "scale", Vector3.ONE * (1.08 if hovered else 1.0), Anim.t(0.12))


## Shuts the building for the rest of the level. [animate] squashes it as it greys out.
func close(animate: bool = true) -> void:
	closed = true
	_apply_look()
	if animate:
		_land()


func _apply_look() -> void:
	var closed_art := closed and CLOSED_TEXTURES.has(kind)
	cutout.texture = CLOSED_TEXTURES[kind] if closed_art else TEXTURES[kind]
	var tint := CLOSED_TINT if closed else TINTS[kind]
	# Closed art already reads as closed, so it isn't greyed
	cutout.tint = Color.WHITE if closed_art else tint
	backing.modulate = tint
	symbol.modulate = Color(0.6, 0.6, 0.65, 0.7) if closed else Color.WHITE
