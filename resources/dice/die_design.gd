class_name DieDesign
extends Resource

## The shape of a die's body, swappable independently of its symbols. Physics always uses a 1x1x1 cube, so designs must
## fit that cube and have a flat square area centred on each face for the symbols. A mesh with a second surface has a
## trim (frame, studs, edges...) drawn in the player's trim finish; the first surface and the faces use the main finish
## (DieFinish, ProgressionData.die_finish / die_trim_finish). Designs that don't start unlocked are unlocked by a
## challenge (UnlockChallenge).

@export var id: StringName
@export var display_name: String
@export var mesh: Mesh
## Side length of the flat area on each face that the symbols are drawn on
@export var face_size: float = 0.76
## Distance from the die centre to the face surface
@export var face_offset: float = 0.5
## Pickable from the start; otherwise it needs an entry in ProgressionData.unlocked_die_designs
@export var starts_unlocked: bool = true


## True if the mesh has a trim surface (drawn in the trim finish).
func has_trim() -> bool:
	return mesh != null and mesh.get_surface_count() > 1
