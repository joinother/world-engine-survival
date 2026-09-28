class_name ContentRegistry
extends RefCounted

var pack: Dictionary = {}

func load_pack(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	pack = parsed
	return true

func item(id: String) -> Dictionary:
	return pack.get("items", {}).get(id, {})

func recipe(id: String) -> Dictionary:
	return pack.get("recipes", {}).get(id, {})
