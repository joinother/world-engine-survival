extends SceneTree

const ContentRegistry = preload("res://scripts/content_registry.gd")
const SaveManager = preload("res://scripts/save_manager.gd")

func _init() -> void:
	var registry := ContentRegistry.new()
	assert(registry.load_pack("res://content/core.json"))
	assert(registry.load_mods("res://mods") == 1)
	assert(int(registry.item("scrap").get("pickup_amount", 0)) == 4)
	assert(int(registry.event("horde").get("duration_minutes", 0)) == 300)

	var manager := SaveManager.new()
	var snapshot_name := "automated_check"
	assert(manager.save_snapshot(snapshot_name, {"day": 4, "scrap": 12}))
	var restored: Dictionary = manager.load_snapshot(snapshot_name)
	assert(int(restored.get("day", 0)) == 4)
	assert(int(restored.get("scrap", 0)) == 12)
	print("content inheritance and save snapshots: ok")
	quit()
