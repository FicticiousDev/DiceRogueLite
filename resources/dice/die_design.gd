class_name DieDesign
extends Resource

## The look of a die's body, swappable independently of its symbols. Physics always uses a 1x1x1 cube,
## so designs must fit that cube and have a flat square area centred on each face for the symbols.
## Designs will be unlockable collectables (see the plan's meta progression phase).

@export var id: StringName
@export var display_name: String
@export var mesh: Mesh
## Side length of the flat area on each face that the symbols are drawn on
@export var face_size: float = 0.76
## Distance from the die centre to the face surface
@export var face_offset: float = 0.5
@export_range(0.0, 1.0) var roughness: float = 0.45
@export_range(0.0, 1.0) var metallic: float = 0.0
