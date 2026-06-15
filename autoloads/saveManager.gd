extends Node

## To Cover
# Saving of settings and game run data
# Loading of settings and game run data
# Save file management


## Save file paths
const RUN_SAVE: String = "user://run.save"					# Current run (character, dice, gold, level, progress, etc.)
const PROGRESSION_SAVE: String = "user://progression.save"	# Unlocks and cumulative stats
const SETTINGS_SAVE: String = "user://settings.save"		# Settings

const RunData = preload("res://saves/run_data.gd")
const ProgressionData = preload("res://saves/progression_data.gd")
const SettingsData = preload("res://saves/settings_data.gd")

# Locally stored variables for the resources
var run_data: RunData
var progression_data: ProgressionData
var settings_data: SettingsData


func save_data() -> void:
	_save_current_run()
	_save_progression()
	_save_settings()


func load_data() -> void:
	_load_current_run()
	_load_progression()
	_load_settings()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_data()


func _save_current_run() -> void:
	_save_resource_to_file(run_data, RUN_SAVE)


func _save_progression() -> void:
	_save_resource_to_file(progression_data, PROGRESSION_SAVE)


func _save_settings() -> void:
	_save_resource_to_file(settings_data, SETTINGS_SAVE)


func _load_current_run() -> void:
	run_data = _load_resource_from_file(RUN_SAVE, RunData)


func _load_progression() -> void:
	progression_data = _load_resource_from_file(PROGRESSION_SAVE, ProgressionData)


func _load_settings() -> void:
	settings_data = _load_resource_from_file(SETTINGS_SAVE, SettingsData)


# Helper to save a resource as a JSON file
func _save_resource_to_file(res: Resource, file_path: String) -> void:
	if not res:
		return
	
	var serialized_dict: Dictionary = {}
	var script = res.get_script()
	if script:
		for prop in script.get_script_property_list():
			var prop_name = prop["name"]
			var prop_value = res.get(prop_name)
			
			# Handle custom types like Vector2 and Vector2i
			if prop_value is Vector2 or prop_value is Vector2i:
				serialized_dict[prop_name] = {
					"__type": "Vector2",
					"x": prop_value.x,
					"y": prop_value.y
				}
			else:
				serialized_dict[prop_name] = prop_value

	var json_string = JSON.stringify(serialized_dict, "\t")
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()


# Helper to load a resource from a JSON file, re-instancing it
func _load_resource_from_file(file_path: String, resource_class: Variant) -> Resource:
	var res = resource_class.new()
	if not FileAccess.file_exists(file_path):
		return res

	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return res

	var json_string = file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(json_string)
	if not parsed or not (parsed is Dictionary):
		return res

	var script = res.get_script()
	if script:
		for prop in script.get_script_property_list():
			var prop_name = prop["name"]
			if parsed.has(prop_name):
				var loaded_val = parsed[prop_name]
				var current_val = res.get(prop_name)

				# Deserialization type matching
				if current_val is Vector2 or current_val is Vector2i:
					if loaded_val is Dictionary and loaded_val.has("x") and loaded_val.has("y"):
						if current_val is Vector2i:
							res.set(prop_name, Vector2i(int(loaded_val["x"]), int(loaded_val["y"])))
						else:
							res.set(prop_name, Vector2(float(loaded_val["x"]), float(loaded_val["y"])))
					elif loaded_val is Array and loaded_val.size() >= 2:
						if current_val is Vector2i:
							res.set(prop_name, Vector2i(int(loaded_val[0]), int(loaded_val[1])))
						else:
							res.set(prop_name, Vector2(float(loaded_val[0]), float(loaded_val[1])))
				elif current_val is Array:
					if loaded_val is Array:
						current_val.clear()
						for item in loaded_val:
							current_val.append(item)
				else:
					# Coerce types for float/int if needed, Godot set() handles some automatic coercion
					res.set(prop_name, loaded_val)
	return res