extends RefCounted
## Original procedural assets. Shared palette and dimensions keep the district readable.

static func material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	return mat

static func box(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.position = pos
	mesh.material_override = material(color)
	parent.add_child(mesh)
	return mesh

static func cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.height = height
	shape.radial_segments = 10
	mesh.mesh = shape
	mesh.position = pos
	mesh.material_override = material(color)
	parent.add_child(mesh)
	return mesh

static func human(parent: Node3D, color: Color) -> Node3D:
	var model := Node3D.new()
	parent.add_child(model)
	box(model, Vector3(0, 0.95, 0), Vector3(0.55, 0.65, 0.35), color)
	box(model, Vector3(0, 1.5, 0), Vector3(0.36, 0.4, 0.34), Color("baa489"))
	box(model, Vector3(0, 1.71, 0), Vector3(0.39, 0.08, 0.37), Color("343c39"))
	for side in [-1.0, 1.0]:
		var leg := box(model, Vector3(side * 0.16, 0.36, 0), Vector3(0.21, 0.65, 0.25), Color("303e48"))
		leg.name = "LegL" if side < 0 else "LegR"
		box(model, Vector3(side * 0.16, 0.07, -0.06), Vector3(0.25, 0.14, 0.37), Color("202829"))
		box(model, Vector3(side * 0.39, 0.98, 0), Vector3(0.19, 0.59, 0.22), color.darkened(0.12))
	box(model, Vector3(0, 1.02, 0.25), Vector3(0.39, 0.48, 0.2), Color("6c6348"))
	return model

static func building(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> void:
	# Front faces south; roof edging and recessed windows give scale without texture dependencies.
	box(parent, pos + Vector3(0, -size.y / 2 + 0.08, 0), Vector3(size.x + 0.45, 0.16, size.z + 0.45), Color("87918a"))
	box(parent, pos + Vector3(0, size.y / 2 + 0.06, 0), Vector3(size.x + 0.3, 0.2, size.z + 0.3), Color("333e43"))
	box(parent, pos + Vector3(0, size.y / 2 + 0.3, 0), Vector3(size.x * 0.4, 0.5, size.z * 0.3), Color("636c6c"))
	var front := pos.z + size.z / 2 + 0.04
	for floor_index in range(max(1, int(size.y / 1.8))):
		for column in range(max(1, int(size.x / 1.5))):
			var x := pos.x - size.x / 2 + 0.85 + column * 1.5
			var y := pos.y - size.y / 2 + 1.2 + floor_index * 1.8
			box(parent, Vector3(x, y, front), Vector3(0.78, 0.85, 0.08), Color("233c45"))
			box(parent, Vector3(x, y - 0.47, front), Vector3(0.94, 0.09, 0.16), color.lightened(0.25))
	box(parent, Vector3(pos.x, 0.9, front + 0.05), Vector3(0.85, 1.7, 0.12), Color("283436"))
	box(parent, Vector3(pos.x, 1.92, front + 0.35), Vector3(1.65, 0.16, 0.8), Color("b17c51"))

static func district(parent: Node3D) -> void:
	# Two streets and a crosswalk replace the debug grid.
	box(parent, Vector3(0, 0.005, 2), Vector3(40, 0.04, 6), Color("363e40"))
	box(parent, Vector3(2, 0.012, 0), Vector3(5.5, 0.04, 40), Color("363e40"))
	for x in range(-18, 20, 4):
		if abs(x - 2) > 4:
			box(parent, Vector3(x, 0.04, 2), Vector3(1.8, 0.025, 0.09), Color("b9ad77"))
	for z in range(-18, 20, 4):
		if abs(z - 2) > 4:
			box(parent, Vector3(2, 0.05, z), Vector3(0.09, 0.025, 1.8), Color("b9ad77"))
	for x in [-1.4, 5.4]:
		box(parent, Vector3(x, 0.06, -7), Vector3(0.35, 0.12, 18), Color("9ba298"))
	for z in [-1.3, 5.3]:
		box(parent, Vector3(-10, 0.06, z), Vector3(17, 0.12, 0.35), Color("9ba298"))
	for x in range(-1, 6):
		box(parent, Vector3(x, 0.06, 6), Vector3(0.5, 0.02, 2), Color("cad0b5"))
	for point in [Vector3(-16,0,-2), Vector3(-1,0,10), Vector3(6,0,-12), Vector3(17,0,2)]:
		cylinder(parent, point + Vector3(0,1.8,0), 0.065, 3.6, Color("424e4d"))
		box(parent, point + Vector3(0.35,3.5,0), Vector3(0.8,0.12,0.22), Color("d3cba2"))
		var light := OmniLight3D.new()
		light.position = point + Vector3(0.5,3.3,0)
		light.light_color = Color("ffda99")
		light.light_energy = 0.7
		light.omni_range = 5
		parent.add_child(light)
	# Fence along the north edge of the district.
	for x in range(-19, 20, 2):
		box(parent, Vector3(x,0.7,-19), Vector3(0.09,1.4,0.09), Color("646e60"))
	box(parent, Vector3(0,0.45,-19), Vector3(39,0.08,0.08), Color("7b806b"))
	box(parent, Vector3(0,1.1,-19), Vector3(39,0.08,0.08), Color("7b806b"))

static func prop(parent: Node3D, kind: String, _color: Color) -> void:
	if kind == "废料":
		box(parent, Vector3(0,0.25,0), Vector3(0.9,0.5,0.7), Color("887153"))
		for x in [-0.3,0.3]:
			box(parent, Vector3(x,0.26,0), Vector3(0.09,0.55,0.74), Color("c0aa7c"))
