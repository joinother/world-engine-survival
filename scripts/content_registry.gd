class_name ContentRegistry
extends RefCounted

var pack: Dictionary = {}
var sources: Array[String] = []

func load_pack(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	pack = {}
	sources.clear()
	return _load_content_file(path, "core")

func load_mods(path: String) -> int:
	var directory := DirAccess.open(path)
	if not directory:
		return 0
	var loaded := 0
	directory.list_dir_begin()
	var entry_name := directory.get_next()
	while not entry_name.is_empty():
		if directory.current_is_dir() and not entry_name.begins_with("."):
			var content_path := path.path_join(entry_name).path_join("content.json")
			var manifest_path := path.path_join(entry_name).path_join("manifest.json")
			if FileAccess.file_exists(manifest_path) and FileAccess.file_exists(content_path):
				if _load_content_file(content_path, entry_name):
					loaded += 1
		entry_name = directory.get_next()
	directory.list_dir_end()
	return loaded

func _load_content_file(path: String, source: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var incoming: Dictionary = parsed
	_merge_pack(incoming)
	sources.append(source)
	return true

func _merge_pack(incoming: Dictionary) -> void:
	for section_key in incoming.keys():
		if typeof(incoming[section_key]) != TYPE_DICTIONARY:
			pack[section_key] = incoming[section_key]
			continue
		var section: Dictionary = pack.get(section_key, {})
		var incoming_section: Dictionary = incoming[section_key]
		for raw_id in incoming_section.keys():
			var content_id := str(raw_id)
			var entry: Dictionary = incoming_section[raw_id]
			var merged: Dictionary = {}
			var parent_id := str(entry.get("extends", ""))
			if not parent_id.is_empty() and section.has(parent_id):
				merged = _deep_merge(section[parent_id], {})
			if section.has(content_id):
				merged = _deep_merge(merged, section[content_id])
			merged = _deep_merge(merged, entry)
			merged.erase("extends")
			section[content_id] = merged
		pack[section_key] = section

func _deep_merge(base: Dictionary, overlay: Dictionary) -> Dictionary:
	var result: Dictionary = base.duplicate(true)
	for key in overlay.keys():
		var value = overlay[key]
		if typeof(value) == TYPE_DICTIONARY and typeof(result.get(key, null)) == TYPE_DICTIONARY:
			result[key] = _deep_merge(result[key], value)
		else:
			result[key] = value
	return result

func item(id: String) -> Dictionary:
	return pack.get("items", {}).get(id, {})

func recipe(id: String) -> Dictionary:
	return pack.get("recipes", {}).get(id, {})

func event(id: String) -> Dictionary:
	return pack.get("events", {}).get(id, {})

func ids(section_name: String) -> Array[String]:
	var result: Array[String] = []
	var section: Dictionary = pack.get(section_name, {})
	for key in section.keys():
		result.append(str(key))
	return result
