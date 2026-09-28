class_name SaveManager
extends RefCounted

const SAVE_ROOT := "user://world_engine"

func save_snapshot(name: String, state: Dictionary) -> bool:
	_ensure_root()
	var path := SAVE_ROOT.path_join(_safe_name(name) + ".json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		return false
	var envelope := {
		"format": 1,
		"saved_at": Time.get_unix_time_from_system(),
		"state": state
	}
	file.store_string(JSON.stringify(envelope, "\t"))
	return true

func load_snapshot(name: String) -> Dictionary:
	var path := SAVE_ROOT.path_join(_safe_name(name) + ".json")
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var envelope: Dictionary = parsed
	var state = envelope.get("state", {})
	return state if typeof(state) == TYPE_DICTIONARY else {}

func list_snapshots() -> Array[String]:
	var result: Array[String] = []
	var directory := DirAccess.open(SAVE_ROOT)
	if not directory:
		return result
	directory.list_dir_begin()
	var entry_name := directory.get_next()
	while not entry_name.is_empty():
		if not directory.current_is_dir() and entry_name.ends_with(".json"):
			result.append(entry_name.trim_suffix(".json"))
		entry_name = directory.get_next()
	directory.list_dir_end()
	result.sort()
	return result

func _ensure_root() -> void:
	var directory := DirAccess.open("user://")
	if directory:
		directory.make_dir_recursive("world_engine")

func _safe_name(raw_name: String) -> String:
	var safe := raw_name.strip_edges().replace("..", "_").replace("/", "_").replace("\\", "_")
	return safe if not safe.is_empty() else "quick_save"
