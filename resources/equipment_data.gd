class_name EquipmentData
extends Resource

## An item of equipment. Its effects are its [member abilities] - passives are always on while it's equipped,
## actives are used like the character's (see Ability). To make a new item: a new .tres in data/equipment/ with
## a slot, rarity and abilities (new effects are a new Ability subclass). The player wears 1 armour, 1 boots and
## 2 charms (RunData.equipment).

enum Slot { ARMOUR, BOOTS, CHARM }

## Localisation keys of the slot names (title case / lower case): wrap in tr() where shown
const SLOT_NAMES: Dictionary[Slot, String] = { Slot.ARMOUR: "ITEM_SLOT_ARMOUR", Slot.BOOTS: "ITEM_SLOT_BOOTS", Slot.CHARM: "ITEM_SLOT_CHARM" }
const SLOT_NAMES_LOWER: Dictionary[Slot, String] = { Slot.ARMOUR: "ITEM_SLOT_ARMOUR_LC", Slot.BOOTS: "ITEM_SLOT_BOOTS_LC", Slot.CHARM: "ITEM_SLOT_CHARM_LC" }
const SLOT_ICONS: Dictionary[Slot, Texture2D] = {
	Slot.ARMOUR: preload("res://assets/equipment/armour.png"),
	Slot.BOOTS: preload("res://assets/equipment/boots.png"),
	Slot.CHARM: preload("res://assets/equipment/charm.png"),
}

@export var id: StringName
## Localised name. The key is EQUIPMENT_<ID>_NAME (localisation/strings.csv)
var display_name: String:
	get: return tr("EQUIPMENT_%s_NAME" % String(id).to_upper())
@export var slot: Slot = Slot.CHARM
@export var rarity: Rarity.Tier = Rarity.Tier.COMMON
## Optional; defaults to the slot's placeholder icon, tinted by rarity
@export var icon: Texture2D
@export var abilities: Array[Ability] = []
## Added to the player's maximum (and current) health while equipped
@export var max_hp: int = 0
## Can drop as loot (chests, bosses, challenge rooms)
@export var loot: bool = true
## Can drop from the start; otherwise only once unlocked by a Mystery piece (ProgressionData.unlocked_items)
@export var starts_unlocked: bool = true


func get_icon() -> Texture2D:
	return icon if icon else SLOT_ICONS[slot]


## Explanation rows for tooltips and the award: each ability (actives with their uses), then any health bonus.
func info_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for ability in abilities:
		var text := "%s: %s" % [ability.display_name, ability.description]
		rows.append(InfoPanel.row(get_icon(), Rarity.COLORS[rarity], text))
	if max_hp != 0:
		rows.append(InfoPanel.row(preload("res://assets/ui/icons/heart.png"), Color(1, 0.35, 0.35), tr("ITEM_MAX_HEALTH") % max_hp))
	return rows


## "Rare Armour" etc.
func kind() -> String:
	return tr("ITEM_KIND") % [Rarity.display_name(rarity), tr(SLOT_NAMES_LOWER[slot])]
