class_name FaceSymbol
extends Resource

## A symbol and how many times it appears on a face.

@export var symbol: Symbol.Type = Symbol.Type.ATTACK
@export_range(1, 6) var count: int = 1
