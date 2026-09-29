extends CharacterBody3D

var world: Node
var speed := 5.0
var camera: Camera3D
var character_visual: Node3D
var view_quadrant := 0
var high_angle := false
var action_timer := 0.0
var facing := Vector3(0.0, 0.0, 1.0)
const VIEW_NAMES := ["南向", "西向", "北向", "东向"]

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
		character_visual = character_scene.instantiate() as Node3D
		character_visual.position = Vector3(0.0, 0.22, 0.0)
		character_visual.scale = Vector3(0.22, 0.22, 0.22)
		add_child(character_visual)

	camera = Camera3D.new()
	camera.current = true
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 18.0
	camera.near = 0.1
	camera.far = 80.0
	add_child(camera)
	# RPG 制作工具式伪 3D：正交投影、固定斜视、四个可切换方向。
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_update_camera()

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
	if event is InputEventKey and event.pressed and event.keycode == KEY_Q:
		rotate_view(-1)
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		rotate_view(1)
	if event is InputEventKey and event.pressed and event.keycode == KEY_V:
		toggle_angle()
	if event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		if world:
			world.toggle_cli()

func _physics_process(delta: float) -> void:
	action_timer = max(0.0, action_timer - delta)
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
	if direction.length() > 0.01:
		facing = direction
		if character_visual:
			character_visual.rotation.y = lerp_angle(character_visual.rotation.y, atan2(direction.x, direction.z), min(1.0, delta * 12.0))
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	velocity.y = -0.2
	move_and_slide()
	global_position.y = -0.05
	global_position.x = clamp(global_position.x, -19.0, 19.0)
	global_position.z = clamp(global_position.z, -19.0, 19.0)
	if character_visual:
		var bob := sin(Time.get_ticks_msec() * 0.012) * 0.035 if direction.length() > 0.01 else 0.0
		character_visual.position.y = 0.22 + bob
		character_visual.rotation.x = -sin((0.28 - action_timer) * 10.0) * 0.18 if action_timer > 0.0 else lerp(character_visual.rotation.x, 0.0, min(1.0, delta * 12.0))
	_update_camera()

func _update_camera() -> void:
	var base_offset := Vector3(9.0, 10.5, 9.0) if not high_angle else Vector3(13.0, 14.0, 13.0)
	var offset := base_offset.rotated(Vector3.UP, float(view_quadrant) * PI * 0.5)
	camera.global_position = global_position + offset
	camera.look_at(global_position + Vector3(0.0, 0.8, 0.0), Vector3.UP)

func rotate_view(step: int = 1) -> void:
	view_quadrant = posmod(view_quadrant + step, 4)
	_update_camera()
	if world:
		world._set_message("视角切换：%s" % view_name())

func toggle_angle() -> void:
	high_angle = not high_angle
	_update_camera()
	if world:
		world._set_message("镜头高度：%s" % ("远景" if high_angle else "近景"))

func view_name() -> String:
	return VIEW_NAMES[view_quadrant] + ("·远景" if high_angle else "·近景")

func play_attack() -> void:
	action_timer = 0.28
