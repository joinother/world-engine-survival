extends CharacterBody3D

var world: Node
var yaw := 0.0
var pitch := -0.5
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
	add_child(body)

	camera = Camera3D.new()
	camera.current = true
	camera.fov = 58.0
	add_child(camera)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * 0.003
		pitch = clamp(pitch - event.relative.y * 0.003, -1.15, -0.12)
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED)
	if event is InputEventKey and event.pressed and event.keycode == KEY_E:
		if world:
			world.player_interact()

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
	var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	var direction := (right * input_vec.x + forward * input_vec.y).normalized()
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	velocity.y = -0.2
	move_and_slide()
	global_position.x = clamp(global_position.x, -19.0, 19.0)
	global_position.z = clamp(global_position.z, -19.0, 19.0)
	_update_camera()

func _update_camera() -> void:
	var distance := 9.0
	var offset := Vector3(0.0, 4.8, distance)
	offset = offset.rotated(Vector3.RIGHT, pitch)
	offset = offset.rotated(Vector3.UP, yaw)
	camera.global_position = global_position + offset
	camera.look_at(global_position + Vector3(0.0, 1.0, 0.0), Vector3.UP)
