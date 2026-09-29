extends CharacterBody3D

var world: Node
var speed := 5.0
var camera: Camera3D

func _ready() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.45
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	add_child(shape)

	var body := MeshInstance3D.new()
	var capsule_mesh := CapsuleMesh.new()
	capsule_mesh.radius = 0.45
	capsule_mesh.height = 1.8
	body.mesh = capsule_mesh
	body.position.y = 0.9
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("66d9ef")
	body.material_override = material
	body.visible = false
	add_child(body)
	var character_scene := load("res://assets/kenney/blocky-characters/character-r.glb") as PackedScene
	if character_scene:
		var character := character_scene.instantiate() as Node3D
		character.position = Vector3(0.0, 0.22, 0.0)
		character.scale = Vector3(0.22, 0.22, 0.22)
		add_child(character)

	camera = Camera3D.new()
	camera.current = true
	camera.fov = 52.0
	add_child(camera)
	# 生存原型使用固定俯视镜头；鼠标保持可见，用于点击门、垃圾桶和搜刮点。
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if world:
			world.click_interact(event.position)
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if world:
			world.player_attack()
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_E:
		if world:
			world.player_interact()
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		if world:
			world.player_attack()

func _physics_process(_delta: float) -> void:
	var input_vec := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if Input.is_physical_key_pressed(KEY_A):
		input_vec.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		input_vec.x += 1.0
	if Input.is_physical_key_pressed(KEY_W):
		input_vec.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		input_vec.y += 1.0
	input_vec = input_vec.limit_length(1.0)
	var direction := Vector3(input_vec.x, 0.0, input_vec.y).normalized()
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	velocity.y = -0.2
	move_and_slide()
	global_position.y = -0.05
	global_position.x = clamp(global_position.x, -19.0, 19.0)
	global_position.z = clamp(global_position.z, -19.0, 19.0)
	_update_camera()

func _update_camera() -> void:
	var offset := Vector3(0.0, 12.0, 8.0)
	camera.global_position = global_position + offset
	camera.look_at(global_position + Vector3(0.0, 1.0, 0.0), Vector3.UP)
