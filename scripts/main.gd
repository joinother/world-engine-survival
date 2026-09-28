extends Node3D

const Player = preload("res://scripts/player.gd")
const ContentRegistry = preload("res://scripts/content_registry.gd")
const SaveManager = preload("res://scripts/save_manager.gd")

var player: CharacterBody3D
var content: ContentRegistry
var save_manager: SaveManager
var operator_role := "admin"
var active_events: Dictionary = {}
var audit_log: Array[Dictionary] = []
var event_log: Array[String] = []
var zombie_speed_multiplier := 1.0
var scrap := 0
var energy := 20
var cores := 0
var food := 2
var water := 3
var hunger := 100.0
var thirst := 100.0
var fatigue := 0.0
var health := 100.0
var day := 1
var minutes := 8 * 60.0
var gate_open := false
var game_over := false
var game_won := false
var debris: Array[Dictionary] = []
var zombies: Array[Node3D] = []
var zombie_positions: Array[Vector3] = []
var survivor_position := Vector3(-7.0, 0.0, 7.0)
var survivor_node: Node3D
var survivor_rescued := false
var factory_position := Vector3(-5.0, 0.0, 2.0)
var portal_position := Vector3(13.0, 0.0, -12.0)
var gate_position := Vector3(4.0, 0.0, 3.0)
var message := "WASD 移动，鼠标拖动自由视角，E 互动。"
var time_label: Label
var stats_label: Label
var message_label: Label
var command_line: LineEdit
var command_log: Label
var cli_title_label: Label

func _ready() -> void:
	content = ContentRegistry.new()
	save_manager = SaveManager.new()
	if not content.load_pack("res://content/core.json"):
		push_warning("content/core.json could not be loaded; using fallback values")
	content.load_mods("res://mods")
	_setup_environment()
	_setup_player()
	_setup_ui()
	_set_message("%s 已加载 %d 个内容源。" % [message, content.sources.size()])

func _process(delta: float) -> void:
	if not game_over and not game_won:
		_advance_clock(delta * 2.0)
		_update_survival(delta * 2.0)
		_update_events(delta * 2.0)
		_update_zombies(delta)
		_update_survivor(delta)
		_update_energy(delta)
	_update_ui()

func _setup_environment() -> void:
	var world_env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("0b1118")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("8aa6b4")
	environment.ambient_light_energy = 0.55
	world_env.environment = environment
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -28.0, 0.0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	add_child(sun)

	_add_box(Vector3(0.0, -0.3, 0.0), Vector3(40.0, 0.5, 40.0), Color("172a2a"), true)
	for x in range(-16, 17, 4):
		_add_box(Vector3(x, 0.02, 0.0), Vector3(0.06, 0.03, 38.0), Color("284142"), false)
	for z in range(-16, 17, 4):
		_add_box(Vector3(0.0, 0.025, z), Vector3(38.0, 0.03, 0.06), Color("284142"), false)

	# 街区建筑：保留几何通道，方便测试自由视角和遮挡。
	_add_building(Vector3(-12.0, 2.0, -10.0), Vector3(7.0, 4.0, 6.0), Color("3d5864"))
	_add_building(Vector3(-2.0, 3.0, -11.0), Vector3(6.0, 6.0, 7.0), Color("455664"))
	_add_building(Vector3(9.0, 2.5, -4.0), Vector3(8.0, 5.0, 5.0), Color("4c526a"))
	_add_building(Vector3(13.0, 1.6, 7.0), Vector3(5.0, 3.2, 8.0), Color("5d4f65"))
	_add_building(Vector3(-12.0, 1.4, 10.0), Vector3(8.0, 2.8, 6.0), Color("4f6257"))

	_add_marker(factory_position + Vector3(0.0, 0.8, 0.0), Color("a47ce8"), "工厂")
	_add_marker(portal_position + Vector3(0.0, 0.6, 0.0), Color("5ee7f4"), "传送门")
	_add_marker(gate_position + Vector3(0.0, 0.45, 0.0), Color("dc9cff"), "纪念碑机关")
	survivor_node = _add_marker(survivor_position + Vector3(0.0, 0.55, 0.0), Color("76f6d2"), "幸存者")

	var debris_points := [Vector3(-8,0,6), Vector3(-3,0,-4), Vector3(2,0,8), Vector3(8,0,4), Vector3(15,0,-8), Vector3(-15,0,2)]
	for point in debris_points:
		debris.append({"position": point, "taken": false})
		_add_marker(point + Vector3(0.0, 0.35, 0.0), Color("d3a552"), "废料")

	for point in [Vector3(16,0,0), Vector3(11,0,11), Vector3(-6,0,-16), Vector3(17,0,-5)]:
		var zombie := _add_marker(point + Vector3(0.0, 0.8, 0.0), Color("ef5b62"), "感染者")
		zombies.append(zombie)
		zombie_positions.append(point)

func _setup_player() -> void:
	player = Player.new()
	player.world = self
	add_child(player)
	player.global_position = Vector3(-14.0, 0.0, 8.0)

func _setup_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := ColorRect.new()
	panel.position = Vector2(18, 18)
	panel.size = Vector2(380, 262)
	panel.color = Color(0.04, 0.07, 0.1, 0.9)
	layer.add_child(panel)
	var title := Label.new()
	title.position = Vector2(20, 14)
	title.text = "世界引擎 · 3D 生存原型"
	title.add_theme_font_size_override("font_size", 20)
	panel.add_child(title)
	time_label = Label.new()
	time_label.position = Vector2(20, 50)
	panel.add_child(time_label)
	stats_label = Label.new()
	stats_label.position = Vector2(20, 76)
	stats_label.size = Vector2(340, 58)
	panel.add_child(stats_label)
	message_label = Label.new()
	message_label.position = Vector2(20, 164)
	message_label.size = Vector2(340, 54)
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(message_label)
	var help := Label.new()
	help.position = Vector2(20, 226)
	help.text = "WASD 移动 · 鼠标自由视角 · E 互动 · Esc 释放鼠标"
	help.modulate = Color("9eacbb")
	panel.add_child(help)

	var cli_panel := ColorRect.new()
	cli_panel.position = Vector2(18, 570)
	cli_panel.size = Vector2(720, 125)
	cli_panel.color = Color(0.04, 0.07, 0.1, 0.94)
	layer.add_child(cli_panel)
	cli_title_label = Label.new()
	cli_title_label.position = Vector2(14, 10)
	cli_title_label.text = "AI / CLI 管理台（%s）" % operator_role
	cli_title_label.modulate = Color("6ee7f7")
	cli_panel.add_child(cli_title_label)
	command_log = Label.new()
	command_log.position = Vector2(14, 34)
	command_log.size = Vector2(690, 42)
	command_log.text = "输入 help 查看命令。所有命令都会经过规则验证。"
	command_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	command_log.modulate = Color("9bd6e4")
	cli_panel.add_child(command_log)
	command_line = LineEdit.new()
	command_line.position = Vector2(14, 84)
	command_line.size = Vector2(560, 28)
	command_line.placeholder_text = "state / spawn scrap 4 4 / event blackout / gate open"
	command_line.text_submitted.connect(_run_command)
	cli_panel.add_child(command_line)
	var run_button := Button.new()
	run_button.position = Vector2(586, 84)
	run_button.size = Vector2(115, 28)
	run_button.text = "执行"
	run_button.pressed.connect(func(): _run_command(command_line.text))
	cli_panel.add_child(run_button)

func _add_building(pos: Vector3, size: Vector3, color: Color) -> void:
	_add_box(pos, size, color, true)

func _add_box(pos: Vector3, size: Vector3, color: Color, solid: bool) -> Node3D:
	var node: Node3D = StaticBody3D.new() if solid else Node3D.new()
	node.position = pos
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = _material(color)
	node.add_child(mesh)
	if solid:
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		node.add_child(collision)
	add_child(node)
	return node

func _add_marker(pos: Vector3, color: Color, _label: String) -> Node3D:
	var node := Node3D.new()
	node.position = pos
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.45
	sphere.height = 0.9
	mesh.mesh = sphere
	mesh.material_override = _material(color)
	node.add_child(mesh)
	add_child(node)
	return node

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.78
	return material

func _update_zombies(delta: float) -> void:
	for i in range(zombies.size()):
		var zombie := zombies[i]
		var target := player.global_position
		var current := zombie_positions[i]
		var step := (target - current)
		step.y = 0.0
		if step.length() > 0.1:
			current += step.normalized() * delta * 0.8 * zombie_speed_multiplier
		zombie_positions[i] = current
		zombie.position = current + Vector3(0.0, 0.8, 0.0)
		if current.distance_to(player.global_position) < 1.25:
			game_over = true
			_set_message("你被感染者包围了。按 F6 重新加载场景。")

func _update_events(game_minutes: float) -> void:
	var expired: Array[String] = []
	for event_id in active_events.keys():
		var event_state: Dictionary = active_events[event_id]
		event_state["remaining_minutes"] = float(event_state.get("remaining_minutes", 0.0)) - game_minutes
		active_events[event_id] = event_state
		if float(event_state["remaining_minutes"]) <= 0.0:
			expired.append(str(event_id))
	for event_id in expired:
		active_events.erase(event_id)
		_event_log("事件结束：%s" % event_id)
	zombie_speed_multiplier = 1.0
	for event_id in active_events.keys():
		var active: Dictionary = content.event(str(event_id))
		zombie_speed_multiplier = max(zombie_speed_multiplier, float(active.get("zombie_speed_multiplier", 1.0)))

func _start_event(event_id: String) -> bool:
	var event: Dictionary = content.event(event_id)
	if event.is_empty():
		return false
	var duration := float(event.get("duration_minutes", 60.0))
	active_events[event_id] = {"remaining_minutes": duration}
	if event_id == "blackout":
		energy = max(0, energy - int(event.get("energy_loss", 0)))
	if event_id == "horde":
		_spawn_zombies(int(event.get("spawn_count", 0)))
		zombie_speed_multiplier = max(1.0, float(event.get("zombie_speed_multiplier", 1.0)))
	_event_log("事件开始：%s" % event.get("display_name", event_id))
	_set_message(str(event.get("message", "事件已开始。")))
	return true

func _spawn_zombies(count: int) -> void:
	for index in range(max(0, count)):
		var angle := float(index) * 1.7 + minutes * 0.01
		var point := Vector3(cos(angle) * 17.0, 0.0, sin(angle) * 17.0)
		var zombie := _add_marker(point + Vector3(0.0, 0.8, 0.0), Color("ef5b62"), "感染者")
		zombies.append(zombie)
		zombie_positions.append(point)

func _event_log(entry: String) -> void:
	event_log.append(entry)
	if event_log.size() > 8:
		event_log.pop_front()

func _advance_clock(game_minutes: float) -> void:
	minutes += game_minutes
	while minutes >= 1440.0:
		minutes -= 1440.0
		day += 1

func _update_survival(game_minutes: float) -> void:
	hunger = max(0.0, hunger - game_minutes * 0.035)
	thirst = max(0.0, thirst - game_minutes * 0.05)
	fatigue = min(100.0, fatigue + game_minutes * 0.028)
	if hunger <= 0.0 or thirst <= 0.0:
		health = max(0.0, health - game_minutes * 0.02)
	if fatigue >= 100.0:
		health = max(0.0, health - game_minutes * 0.01)
	if health <= 0.0:
		game_over = true
		_set_message("你因长期缺乏食物、水或休息而倒下了。")

func _update_survivor(delta: float) -> void:
	if not survivor_node or not survivor_rescued:
		return
	var target := player.global_position - Vector3(0.0, 0.0, 1.3)
	var offset := target - survivor_node.position
	if offset.length() > 1.2:
		survivor_node.position += offset.normalized() * delta * 3.0
	survivor_position = survivor_node.position

func _update_energy(delta: float) -> void:
	energy = clamp(energy + delta * 0.03, 0, 100)

func _world_state() -> Dictionary:
	var debris_state: Array[Dictionary] = []
	for item in debris:
		var point: Vector3 = item.get("position", Vector3.ZERO)
		debris_state.append({"x": point.x, "y": point.y, "z": point.z, "taken": bool(item.get("taken", false))})
	var event_state: Dictionary = {}
	for event_id in active_events.keys():
		event_state[str(event_id)] = active_events[event_id]
	return {
		"day": day,
		"minutes": minutes,
		"scrap": scrap,
		"energy": energy,
		"cores": cores,
		"food": food,
		"water": water,
		"hunger": hunger,
		"thirst": thirst,
		"fatigue": fatigue,
		"health": health,
		"gate_open": gate_open,
		"survivor_rescued": survivor_rescued,
		"player_position": {"x": player.global_position.x, "y": player.global_position.y, "z": player.global_position.z},
		"debris": debris_state,
		"active_events": event_state
	}

func _apply_world_state(state: Dictionary) -> void:
	day = int(state.get("day", day))
	minutes = float(state.get("minutes", minutes))
	scrap = int(state.get("scrap", scrap))
	energy = int(state.get("energy", energy))
	cores = int(state.get("cores", cores))
	food = int(state.get("food", food))
	water = int(state.get("water", water))
	hunger = float(state.get("hunger", hunger))
	thirst = float(state.get("thirst", thirst))
	fatigue = float(state.get("fatigue", fatigue))
	health = float(state.get("health", health))
	gate_open = bool(state.get("gate_open", gate_open))
	survivor_rescued = bool(state.get("survivor_rescued", survivor_rescued))
	var saved_position: Dictionary = state.get("player_position", {})
	if player and not saved_position.is_empty():
		player.global_position = Vector3(float(saved_position.get("x", 0.0)), float(saved_position.get("y", 0.0)), float(saved_position.get("z", 0.0)))
	active_events.clear()
	var saved_events: Dictionary = state.get("active_events", {})
	for event_id in saved_events.keys():
		active_events[str(event_id)] = saved_events[event_id]
	zombie_speed_multiplier = 1.0
	for event_id in active_events.keys():
		zombie_speed_multiplier = max(zombie_speed_multiplier, float(content.event(str(event_id)).get("zombie_speed_multiplier", 1.0)))
	var saved_debris: Array = state.get("debris", [])
	for index in range(min(saved_debris.size(), debris.size())):
		debris[index]["taken"] = bool(saved_debris[index].get("taken", false))
	game_over = health <= 0.0
	game_won = false
	_set_message("已恢复世界快照。")

func _role_level(role: String) -> int:
	match role:
		"player":
			return 1
		"director":
			return 2
		"admin":
			return 3
		_:
			return 0

func _has_role(required: String) -> bool:
	return _role_level(operator_role) >= _role_level(required)

func _audit(command: String, result: String) -> void:
	audit_log.append({"operator": operator_role, "command": command, "result": result, "day": day, "minutes": minutes})
	if audit_log.size() > 32:
		audit_log.pop_front()

func player_interact() -> void:
	if game_over or game_won:
		return
	for item in debris:
		if not item.taken and player.global_position.distance_to(item.position) < 1.8:
			item.taken = true
			scrap += int(content.item("scrap").get("pickup_amount", 3))
			_set_message("获得 %s。" % content.item("scrap").get("display_name", "废料"))
			return
	if player.global_position.distance_to(Vector3(-12.0, 0.0, 10.0)) < 3.0:
		food += 2
		water += 2
		hunger = min(100.0, hunger + 40.0)
		thirst = min(100.0, thirst + 50.0)
		fatigue = max(0.0, fatigue - 35.0)
		_set_message("安全屋补充了食物和水，你休息了一会儿。")
		return
	if player.global_position.distance_to(factory_position) < 2.2:
		var recipe: Dictionary = content.recipe("energy_core")
		var scrap_cost := int(recipe.get("scrap", 2))
		var energy_cost := int(recipe.get("energy", 5))
		if scrap >= scrap_cost and energy >= energy_cost and cores < 3:
			scrap -= scrap_cost
			energy -= energy_cost
			cores += 1
			_set_message("工厂制造了一个能量核心。")
		else:
			_set_message("工厂需要 %d 废料和 %d 能量。" % [scrap_cost, energy_cost])
		return
	if not survivor_rescued and player.global_position.distance_to(survivor_position) < 2.2:
		survivor_rescued = true
		_set_message("幸存者加入了队伍。")
		return
	if player.global_position.distance_to(gate_position) < 2.0:
		gate_open = not gate_open
		_set_message("纪念碑机关已" + ("打开。" if gate_open else "关闭。"))
		return
	if player.global_position.distance_to(portal_position) < 2.2:
		if cores >= 3 and survivor_rescued:
			game_won = true
			_set_message("传送门启动。第一片区 3D 原型完成。")
		else:
			_set_message("传送门需要 3 个能量核心和一名幸存者。")

func _run_command(raw: String) -> void:
	var cmd := raw.strip_edges()
	if cmd.is_empty():
		return
	var parts := cmd.split(" ", false)
	var output := "> " + cmd
	var audit_result := "ok"
	if parts[0] == "help":
		output += "\nstate | needs | content list | use food | use water | time advance 分钟 | event start id | event list | gate open | world snapshot 名称 | world rollback 名称 | world snapshots | audit tail"
	elif parts[0] == "state" or (parts[0] == "world" and parts.size() >= 2 and parts[1] == "state"):
		output += "\nday=%d time=%02d:%02d scrap=%d energy=%d cores=%d survivor=%s" % [day, int(minutes / 60.0), int(minutes) % 60, scrap, energy, cores, survivor_rescued]
	elif parts[0] == "needs":
		output += "\nhealth=%.0f hunger=%.0f thirst=%.0f fatigue=%.0f food=%d water=%d" % [health, hunger, thirst, fatigue, food, water]
	elif parts[0] == "content" and parts.size() >= 2 and parts[1] == "list":
		output += "\nsources=%s items=%s recipes=%s events=%s" % [", ".join(content.sources), ", ".join(content.ids("items")), ", ".join(content.ids("recipes")), ", ".join(content.ids("events"))]
	elif parts[0] == "use" and parts.size() >= 2 and parts[1] == "food":
		if food > 0:
			food -= 1
			hunger = min(100.0, hunger + 35.0)
			output += "\nok: 已食用食物"
		else:
			output += "\nerror: 没有食物"
	elif parts[0] == "use" and parts.size() >= 2 and parts[1] == "water":
		if water > 0:
			water -= 1
			thirst = min(100.0, thirst + 45.0)
			output += "\nok: 已饮用净水"
		else:
			output += "\nerror: 没有净水"
	elif parts[0] == "time" and parts.size() >= 3 and parts[1] == "advance":
		if not _has_role("director"):
			output += "\nerror: 需要 director 权限"
			audit_result = "denied"
		else:
			var game_minutes: float = max(0.0, float(parts[2]))
			_advance_clock(game_minutes)
			_update_survival(game_minutes)
			_update_events(game_minutes)
			output += "\nok: 时间已推进"
	elif parts[0] == "event" and parts.size() >= 2 and parts[1] == "list":
		output += "\nactive=%s recent=%s" % [str(active_events.keys()), " | ".join(event_log)]
	elif parts[0] == "event" and parts.size() >= 3 and parts[1] == "start":
		if not _has_role("director"):
			output += "\nerror: 需要 director 权限"
			audit_result = "denied"
		elif _start_event(parts[2]):
			output += "\nok: 事件已启动"
		else:
			output += "\nerror: 未知事件"
			audit_result = "error"
	elif parts[0] == "event" and parts.size() >= 2 and parts[1] == "blackout":
		if _has_role("director") and _start_event("blackout"):
			output += "\nok: 停电事件已启动"
		else:
			output += "\nerror: 需要 director 权限或事件不存在"
			audit_result = "denied"
	elif parts[0] == "gate" and parts.size() >= 2 and parts[1] == "open":
		if _has_role("director"):
			gate_open = true
			output += "\nok: 纪念碑通路已打开"
		else:
			output += "\nerror: 需要 director 权限"
			audit_result = "denied"
	elif parts[0] == "world" and parts.size() >= 3 and parts[1] == "snapshot":
		if not _has_role("admin"):
			output += "\nerror: 需要 admin 权限"
			audit_result = "denied"
		elif save_manager.save_snapshot(parts[2], _world_state()):
			output += "\nok: 快照已保存"
		else:
			output += "\nerror: 快照保存失败"
			audit_result = "error"
	elif parts[0] == "world" and parts.size() >= 3 and parts[1] == "rollback":
		if not _has_role("admin"):
			output += "\nerror: 需要 admin 权限"
			audit_result = "denied"
		else:
			var restored_state := save_manager.load_snapshot(parts[2])
			if restored_state.is_empty():
				output += "\nerror: 快照不存在"
				audit_result = "error"
			else:
				_apply_world_state(restored_state)
				output += "\nok: 世界已回滚"
	elif parts[0] == "world" and parts.size() >= 2 and parts[1] == "snapshots":
		output += "\n" + ", ".join(save_manager.list_snapshots())
	elif parts[0] == "audit" and parts.size() >= 2 and parts[1] == "tail":
		var recent: Array[String] = []
		for entry in audit_log:
			recent.append("%s:%s" % [entry.get("operator", "?"), entry.get("command", "?")])
		output += "\n" + " | ".join(recent)
	elif parts[0] == "auth" and parts.size() >= 3 and parts[1] == "role":
		if not _has_role("admin") or _role_level(parts[2]) == 0:
			output += "\nerror: 需要 admin 权限或角色无效"
			audit_result = "denied"
		else:
			operator_role = parts[2]
			output += "\nok: 当前角色=%s" % operator_role
	elif parts[0] == "spawn" and parts.size() >= 4 and parts[1] == "scrap":
		if not _has_role("admin"):
			output += "\nerror: 需要 admin 权限"
			audit_result = "denied"
		else:
			var point := Vector3(float(parts[2]), 0.0, float(parts[3]))
			debris.append({"position": point, "taken": false})
			_add_marker(point + Vector3(0.0, 0.35, 0.0), Color("d3a552"), "废料")
			output += "\nok: 生成废料于 %s" % point
	else:
		output += "\nerror: 未知命令，输入 help。"
		audit_result = "error"
	_audit(cmd, audit_result)
	command_log.text = output
	command_line.clear()

func _set_message(text: String) -> void:
	message = text
	if message_label:
		message_label.text = text

func _update_ui() -> void:
	if not time_label:
		return
	var hour := int(minutes / 60.0) % 24
	var minute := int(minutes) % 60
	time_label.text = "第 %d 天 %02d:%02d" % [day, hour, minute]
	stats_label.text = "废料 %d    能量 %d    核心 %d/3    幸存者 %d\n生命 %.0f    饥饿 %.0f    口渴 %.0f    疲劳 %.0f" % [scrap, energy, cores, 2 if survivor_rescued else 1, health, hunger, thirst, fatigue]
	if cli_title_label:
		cli_title_label.text = "AI / CLI 管理台（%s · 活跃事件 %d）" % [operator_role, active_events.size()]
