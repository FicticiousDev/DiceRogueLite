class_name DieFinish
extends Resource

## A material for die bodies and faces (shaders/die_finish.gdshaderinc), picked in the dice designer: the main finish
## (ProgressionData.die_finish) and, for designs with a trim, the trim's (die_trim_finish). The die's rarity colour
## tints it, so rarity still reads whatever the finish.

enum Pattern { PLASTIC, METAL, GLASS, RUST, MARBLE, OBSIDIAN, GALAXY, FLECKED, WOOD, PEARL }

@export var id: StringName
## Localised name. The key is DIE_FINISH_<ID>_NAME (localisation/strings.csv)
var display_name: String:
	get: return tr("DIE_FINISH_%s_NAME" % String(id).to_upper())
@export var pattern: Pattern = Pattern.PLASTIC
@export var base_color: Color = Color.WHITE
## Share of the rarity colour in the finish's colour (0: the base colour only)
@export_range(0.0, 1.0) var tint: float = 1.0
## Veins, rust, flecks, nebula...
@export var detail_color: Color = Color(0.2, 0.2, 0.2)
@export_range(0.0, 1.0) var roughness: float = 0.45
@export_range(0.0, 1.0) var metallic: float = 0.0
@export var pattern_scale: float = 1.0
## Below 1 the die is see-through (glass): this much alpha where it faces the camera, more towards its edges
@export_range(0.0, 1.0) var opacity: float = 1.0


## True if dice in this finish are drawn see-through (Die3D picks the *_glass shaders).
func is_transparent() -> bool:
	return opacity < 1.0


## Sets the finish's shader parameters on [material] (die_body / die_face shaders).
func apply(material: ShaderMaterial) -> void:
	material.set_shader_parameter("pattern", int(pattern))
	material.set_shader_parameter("base_color", base_color)
	material.set_shader_parameter("tint", tint)
	material.set_shader_parameter("detail_color", detail_color)
	material.set_shader_parameter("roughness", roughness)
	material.set_shader_parameter("metallic", metallic)
	material.set_shader_parameter("pattern_scale", pattern_scale)
	material.set_shader_parameter("opacity", opacity)
