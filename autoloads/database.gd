extends Node

## Loads every content resource under res://data/ and looks them up by id.
## Each subfolder is a category, e.g. data/dice/ -> "dice". Resources must have an `id` property.

const DATA_PATH: String = "res://data/"

var _content: Dictionary[String, Dictionary] = {}


func _ready() -> void:
	for category in DirAccess.get_directories_at(DATA_PATH):
		_content[category] = _load_category(DATA_PATH + category + "/")


## Returns the resource with [id] in [category], or null.
func get_content(category: String, id: StringName) -> Resource:
	return _content.get(category, {}).get(id)


## Returns every resource in [category].
func get_all(category: String) -> Array:
	return _content.get(category, {}).values()


func _load_category(path: String) -> Dictionary:
	var resources: Dictionary = {}
	for file in DirAccess.get_files_at(path):
		# Exported builds list resources as *.remap
		file = file.trim_suffix(".remap")
		if not file.ends_with(".tres"):
			continue
		var res: Resource = load(path + file)
		if res and "id" in res:
			resources[res.id] = res
		else:
			printerr("Database: resource has no id: " + path + file)
	return resources
