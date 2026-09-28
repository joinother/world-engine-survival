extends Node3D

const Player = preload("res://scripts/player.gd")
const ContentRegistry = preload("res://scripts/content_registry.gd")
const SaveManager = preload("res://scripts/save_manager.gd")
const CommandServer = preload("res://scripts/command_server.gd")

var player: CharacterBody3D
var content: ContentRegistry
var save_manager: SaveManager
var command_server: CommandServer
var operator_role := "admin"
var active_events: Dictionary = {}
var audit_log: Array[Dictionary] = []
var event_log: Array[String] = []
var zombie_speed_multiplier := 1.0
var zombie_health: Array[float] = []
var attack_cooldown_remaining := 0.0
var damage_cooldown_remaining := 0.0
var scrap := 0
var energy := 20
var cores := 0
var food := 2
var water := 3
var hunger := 100.0
var thirst := 100.0
var fatigue := 0.0
var health := 100.0
var bleeding := 0.0
var infection := 0.0
var bandages := 2
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
var last_command_output := ""

func _ready() -> void:
	content = ContentRegistry.new()
	save_manager = SaveManager.new()
	if not content.load_pack("res://content/core.json"):
		push_warning("content/core.json could not be loaded; using fallback values")
	content.load_mods("res://mods")
	_setup_environment()
	_setup_player()
	_setup_ui()
	command_server = CommandServer.new()
	command_server.request_received.connect(_handle_rpc_request)
	add_child(command_server)
	command_server.start(9555)
	_set_message("%s 已加载 %d 个内容源。" % [message, content.sources.size()])

func _process(delta: float) -> void:
	if not game_over and not game_won:
		_advance_clock(delta * 2.0)
		_update_survival(delta * 2.0)
		_update_events(delta * 2.0)
		_update_zombies(delta)
		attack_cooldown_remaining = max(0.0, attack_cooldown_remaining - delta)
		damage_cooldown_remaining = max(0.0, damage_cooldown_remaining - delta)
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
	for point in [Vector3(-7.0, 0.0, -1.0), Vector3(5.0, 0.0, 7.0), Vector3(11.0, 0.0, -10.0)]:
		_add_vehicle(point, Color("71808d"))
	for point in [Vector3(-10.0, 0.0, 4.0), Vector3(6.0, 0.0, -1.0), Vector3(16.0, 0.0, 8.0), Vector3(-2.0, 0.0, 15.0)]:
		_add_tree(point)
	for point in [Vector3(-1.0, 0.0, 3.0), Vector3(7.0, 0.0, 5.0)]:
		_add_barricade(point)

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
		zombie_health.append(float(content.rule("combat").get("zombie_health", 100.0)))

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
	panel.size = Vector2(380, 312)
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
	stats_label.size = Vector2(340, 82)
	panel.add_child(stats_label)
	message_label = Label.new()
	message_label.position = Vector2(20, 184)
	message_label.size = Vector2(340, 54)
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(message_label)
	var help := Label.new()
	help.position = Vector2(20, 264)
	help.text = "WASD 移动 · 空格/左键挥击 · E 互动 · Esc 释放鼠标"
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

func _add_vehicle(pos: Vector3, color: Color) -> void:
	var node := Node3D.new()
	node.position = pos
	var body := MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(2.4, 0.55, 1.25)
	body.mesh = body_mesh
	body.position.y = 0.42
	body.material_override = _material(color)
	node.add_child(body)
	var cabin := MeshInstance3D.new()
	var cabin_mesh := BoxMesh.new()
	cabin_mesh.size = Vector3(1.25, 0.5, 1.05)
	cabin.mesh = cabin_mesh
	cabin.position = Vector3(-0.15, 0.85, 0.0)
	cabin.material_override = _material(Color("273b4a"))
	node.add_child(cabin)
	add_child(node)

func _add_tree(pos: Vector3) -> void:
	var node := Node3D.new()
	node.position = pos
	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.16
	trunk_mesh.bottom_radius = 0.22
	trunk_mesh.height = 1.6
	trunk.mesh = trunk_mesh
	trunk.position.y = 0.8
	trunk.material_override = _material(Color("5b4030"))
	node.add_child(trunk)
	var crown := MeshInstance3D.new()
	var crown_mesh := SphereMesh.new()
	crown_mesh.radius = 1.0
	crown_mesh.height = 1.8
	crown.mesh = crown_mesh
	crown.position.y = 1.9
	crown.material_override = _material(Color("2f765d"))
	node.add_child(crown)
	add_child(node)

func _add_barricade(pos: Vector3) -> void:
	var node := Node3D.new()
	node.position = pos
	for offset in [-0.75, 0.0, 0.75]:
		var plank := MeshInstance3D.new()
		var plank_mesh := BoxMesh.new()
		plank_mesh.size = Vector3(0.65, 0.12, 0.12)
		plank.mesh = plank_mesh
		plank.position = Vector3(offset, 0.65 + abs(offset) * 0.15, 0.0)
		plank.rotation.z = offset * 0.15
		plank.material_override = _material(Color("b77b4b"))
		node.add_child(plank)
	add_child(node)

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
	var combat_rules := content.rule("combat")
	var contact_range := float(combat_rules.get("contact_range", 1.25))
	var contact_damage := float(combat_rules.get("zombie_contact_damage_per_second", 4.0))
	var nearby_count := 0
	for i in range(zombies.size()):
		var zombie := zombies[i]
		var target := player.global_position
		var current := zombie_positions[i]
		var step := (target - current)
		step.y = 0.0
		if step.length() > 0.1:
			current += step.normalized() * delta * float(content.rule("world").get("zombie_speed", 0.8)) * zombie_speed_multiplier
		zombie_positions[i] = current
		zombie.position = current + Vector3(0.0, 0.8, 0.0)
		if current.distance_to(player.global_position) < contact_range:
			nearby_count += 1
	if nearby_count > 0 and damage_cooldown_remaining <= 0.0:
		health = max(0.0, health - contact_damage * nearby_count * delta)
		fatigue = min(100.0, fatigue + nearby_count * delta * 2.0)
		bleeding = min(100.0, bleeding + nearby_count * float(combat_rules.get("bleeding_per_contact", 8.0)))
		infection = min(100.0, infection + nearby_count * float(combat_rules.get("infection_per_contact", 1.5)))
		damage_cooldown_remaining = 0.25
		_set_message("感染者正在撕扯你：按空格或鼠标左键挥击，然后立刻逃离。")
		if health <= 0.0:
			game_over = true
			_set_message("你因伤势过重倒下了。世界仍会保留这次失败的快照。")

func player_attack() -> void:
	if game_over or game_won or attack_cooldown_remaining > 0.0:
		return
	var combat_rules := content.rule("combat")
	var attack_range := float(combat_rules.get("attack_range", 2.4))
	var attack_damage := float(combat_rules.get("attack_damage", 35.0))
	var knockback := float(combat_rules.get("knockback", 3.5))
	var target_index := -1
	var target_distance := attack_range
	for index in range(zombies.size()):
		var distance := player.global_position.distance_to(zombie_positions[index])
		if distance <= target_distance:
			target_index = index
			target_distance = distance
	if target_index < 0:
		_set_message("挥击落空。")
		attack_cooldown_remaining = 0.2
		return
	var direction := (zombie_positions[target_index] - player.global_position).normalized()
	zombie_health[target_index] -= attack_damage
	zombie_positions[target_index] += direction * knockback
	attack_cooldown_remaining = float(combat_rules.get("attack_cooldown", 0.55))
	if zombie_health[target_index] <= 0.0:
		var defeated := zombies[target_index]
		defeated.queue_free()
		zombies.remove_at(target_index)
		zombie_positions.remove_at(target_index)
		zombie_health.remove_at(target_index)
		scrap += 1
		_set_message("感染者被击倒了，获得 1 废料。")
	else:
		_set_message("你用临时木棍击退了感染者。")

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
		_spawn_zombie_at(point)

func _spawn_zombie_at(point: Vector3) -> void:
	var zombie := _add_marker(point + Vector3(0.0, 0.8, 0.0), Color("ef5b62"), "感染者")
	zombies.append(zombie)
	zombie_positions.append(point)
	zombie_health.append(float(content.rule("combat").get("zombie_health", 100.0)))

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
	var survival_rules := content.rule("survival")
	hunger = max(0.0, hunger - game_minutes * float(survival_rules.get("hunger_per_minute", 0.035)))
	thirst = max(0.0, thirst - game_minutes * float(survival_rules.get("thirst_per_minute", 0.05)))
	fatigue = min(100.0, fatigue + game_minutes * float(survival_rules.get("fatigue_per_minute", 0.028)))
	if hunger <= 0.0 or thirst <= 0.0:
		health = max(0.0, health - game_minutes * float(survival_rules.get("starvation_damage_per_minute", 0.02)))
	if fatigue >= 100.0:
		health = max(0.0, health - game_minutes * float(survival_rules.get("exhaustion_damage_per_minute", 0.01)))
	if bleeding > 0.0:
		health = max(0.0, health - game_minutes * bleeding * 0.001)
		bleeding = max(0.0, bleeding - game_minutes * 0.008)
	if infection > 50.0:
		health = max(0.0, health - game_minutes * (infection - 50.0) * 0.0005)
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
	var zombie_state: Array[Dictionary] = []
	for index in range(zombies.size()):
		var zombie_point: Vector3 = zombie_positions[index]
		zombie_state.append({"x": zombie_point.x, "y": zombie_point.y, "z": zombie_point.z, "health": zombie_health[index]})
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
		"bleeding": bleeding,
		"infection": infection,
		"bandages": bandages,
		"gate_open": gate_open,
		"survivor_rescued": survivor_rescued,
		"zombie_count": zombies.size(),
		"zombies": zombie_state,
		"weapon": "improvised_club",
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
	bleeding = float(state.get("bleeding", bleeding))
	infection = float(state.get("infection", infection))
	bandages = int(state.get("bandages", bandages))
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
	var saved_zombies: Array = state.get("zombies", [])
	for zombie in zombies:
		zombie.queue_free()
	zombies.clear()
	zombie_positions.clear()
	zombie_health.clear()
	for saved_zombie in saved_zombies:
		var restored_point := Vector3(float(saved_zombie.get("x", 0.0)), float(saved_zombie.get("y", 0.0)), float(saved_zombie.get("z", 0.0)))
		var restored_node := _add_marker(restored_point + Vector3(0.0, 0.8, 0.0), Color("ef5b62"), "感染者")
		zombies.append(restored_node)
		zombie_positions.append(restored_point)
		zombie_health.append(float(saved_zombie.get("health", content.rule("combat").get("zombie_health", 100.0))))
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

func _observe_state(radius: float = 12.0) -> Dictionary:
	var observation := {
		"day": day,
		"minutes": minutes,
		"player_position": {"x": player.global_position.x, "y": player.global_position.y, "z": player.global_position.z},
		"scrap": scrap,
		"food": food,
		"water": water,
		"health": health,
		"hunger": hunger,
		"thirst": thirst,
		"fatigue": fatigue,
		"bleeding": bleeding,
		"infection": infection,
		"bandages": bandages,
		"survivor_rescued": survivor_rescued
	}
	var threats: Array[Dictionary] = []
	for index in range(zombie_positions.size()):
		var point: Vector3 = zombie_positions[index]
		if point.distance_to(player.global_position) <= radius:
			threats.append({"x": point.x, "y": point.y, "z": point.z, "distance": point.distance_to(player.global_position)})
	var nearby_items: Array[Dictionary] = []
	for item in debris:
		if bool(item.get("taken", false)):
			var point: Vector3 = item.get("position", Vector3.ZERO)
			if point.distance_to(player.global_position) <= radius:
				nearby_items.append({"type": "scrap", "x": point.x, "y": point.y, "z": point.z})
	observation["nearby_threats"] = threats
	observation["nearby_items"] = nearby_items
	observation["operator_role"] = operator_role
	return observation

func _rpc_error(request_id, code: int, message_text: String) -> Dictionary:
	return {"jsonrpc": "2.0", "id": request_id, "error": {"code": code, "message": message_text}}

func _handle_rpc_request(line: String, peer: StreamPeerTCP) -> void:
	var request_id = null
	var parsed = JSON.parse_string(line)
	if typeof(parsed) != TYPE_DICTIONARY:
		command_server.send_json(peer, _rpc_error(request_id, -32700, "invalid JSON"))
		return
	var request: Dictionary = parsed
	request_id = request.get("id", null)
	if str(request.get("jsonrpc", "2.0")) != "2.0":
		command_server.send_json(peer, _rpc_error(request_id, -32600, "jsonrpc must be 2.0"))
		return
	var method := str(request.get("method", ""))
	var params: Dictionary = request.get("params", {})
	if typeof(params) != TYPE_DICTIONARY:
		command_server.send_json(peer, _rpc_error(request_id, -32602, "params must be an object"))
		return
	var requested_role := str(params.get("role", "player"))
	if _role_level(requested_role) == 0:
		command_server.send_json(peer, _rpc_error(request_id, -32602, "unknown role"))
		return
	var previous_role := operator_role
	operator_role = requested_role
	var result: Dictionary = _dispatch_rpc(method, params)
	operator_role = previous_role
	command_server.send_json(peer, {"jsonrpc": "2.0", "id": request_id, "result": result})

func _dispatch_rpc(method: String, params: Dictionary) -> Dictionary:
	match method:
		"world.state":
			return {"ok": true, "state": _world_state() if _has_role("director") else _observe_state()}
		"player.observe":
			return {"ok": true, "observation": _observe_state(float(params.get("radius", 12.0)))}
		"player.attack":
			player_attack()
			return {"ok": true, "state": _observe_state()}
		"world.content":
			return {"ok": true, "sources": content.sources, "items": content.ids("items"), "recipes": content.ids("recipes"), "events": content.ids("events")}
		"world.command":
			var raw_command := str(params.get("command", ""))
			if raw_command.is_empty():
				return {"ok": false, "error": "command is required"}
			_run_command(raw_command)
			return {"ok": not last_command_output.contains("\nerror:"), "output": last_command_output}
		"time.advance":
			if not _has_role("director"):
				return {"ok": false, "error": "director role required"}
			var game_minutes: float = max(0.0, float(params.get("minutes", 0.0)))
			_advance_clock(game_minutes)
			_update_survival(game_minutes)
			_update_events(game_minutes)
			_audit("time.advance %s" % game_minutes, "ok")
			return {"ok": true, "minutes": game_minutes, "state": _world_state()}
		"event.start":
			if not _has_role("director"):
				return {"ok": false, "error": "director role required"}
			var event_id := str(params.get("id", ""))
			return {"ok": _start_event(event_id), "active": active_events}
		"world.snapshot":
			if not _has_role("admin"):
				return {"ok": false, "error": "admin role required"}
			var snapshot_name := str(params.get("name", "quick_save"))
			return {"ok": save_manager.save_snapshot(snapshot_name, _world_state()), "name": snapshot_name}
		"world.rollback":
			if not _has_role("admin"):
				return {"ok": false, "error": "admin role required"}
			var restore_name := str(params.get("name", "quick_save"))
			var restored := save_manager.load_snapshot(restore_name)
			if restored.is_empty():
				return {"ok": false, "error": "snapshot not found"}
			_apply_world_state(restored)
			return {"ok": true, "state": _world_state()}
		"world.snapshots":
			return {"ok": true, "snapshots": save_manager.list_snapshots()}
		_:
			return {"ok": false, "error": "unknown method"}

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
		bandages += 1
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
		output += "\nstate | needs | content list | use food | use water | use bandage | spawn scrap x z | spawn zombie x z | time advance 分钟 | event start id | event list | gate open | world snapshot 名称 | world rollback 名称 | world snapshots | audit tail"
	elif parts[0] == "state" or (parts[0] == "world" and parts.size() >= 2 and parts[1] == "state"):
		output += "\nday=%d time=%02d:%02d scrap=%d energy=%d cores=%d survivor=%s" % [day, int(minutes / 60.0), int(minutes) % 60, scrap, energy, cores, survivor_rescued]
	elif parts[0] == "needs":
		output += "\nhealth=%.0f hunger=%.0f thirst=%.0f fatigue=%.0f bleeding=%.0f infection=%.0f food=%d water=%d bandages=%d" % [health, hunger, thirst, fatigue, bleeding, infection, food, water, bandages]
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
	elif parts[0] == "use" and parts.size() >= 2 and parts[1] == "bandage":
		if bandages > 0:
			bandages -= 1
			bleeding = max(0.0, bleeding - 60.0)
			infection = max(0.0, infection - 4.0)
			output += "\nok: 已包扎伤口"
		else:
			output += "\nerror: 没有绷带"
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
	elif parts[0] == "spawn" and parts.size() >= 4 and (parts[1] == "scrap" or parts[1] == "zombie"):
		if not _has_role("admin"):
			output += "\nerror: 需要 admin 权限"
			audit_result = "denied"
		else:
			var point := Vector3(float(parts[2]), 0.0, float(parts[3]))
			if parts[1] == "scrap":
				debris.append({"position": point, "taken": false})
				_add_marker(point + Vector3(0.0, 0.35, 0.0), Color("d3a552"), "废料")
				output += "\nok: 生成废料于 %s" % point
			else:
				_spawn_zombie_at(point)
				output += "\nok: 生成感染者于 %s" % point
	else:
		output += "\nerror: 未知命令，输入 help。"
		audit_result = "error"
	_audit(cmd, audit_result)
	last_command_output = output
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
	stats_label.text = "废料 %d    能量 %d    核心 %d/3    幸存者 %d\n生命 %.0f    饥饿 %.0f    口渴 %.0f    疲劳 %.0f\n出血 %.0f    感染 %.0f    绷带 %d\n武器：临时木棍" % [scrap, energy, cores, 2 if survivor_rescued else 1, health, hunger, thirst, fatigue, bleeding, infection, bandages]
	if cli_title_label:
		cli_title_label.text = "AI / CLI 管理台（%s · 活跃事件 %d）" % [operator_role, active_events.size()]
