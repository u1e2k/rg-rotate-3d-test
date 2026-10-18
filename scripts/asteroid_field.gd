class_name AsteroidField
extends Node3D

## Asteroid Belt and Starfield generator using MultiMeshInstance3D for 60 FPS performance on Mali-G52

@export var asteroid_count: int = 110
@export var min_radius: float = 35.0
@export var max_radius: float = 320.0
@export var height_spread: float = 85.0

@onready var asteroid_multimesh: MultiMeshInstance3D = $AsteroidsMultiMesh
@onready var starfield_multimesh: MultiMeshInstance3D = $StarfieldMultiMesh

class AsteroidData:
	var pos: Vector3
	var rot_axis: Vector3
	var rot_speed: float
	var rot_current: float
	var scale: Vector3
	var radius: float

var asteroids: Array[AsteroidData] = []

func _ready() -> void:
	_create_starfield()
	_create_asteroid_belt()

func _create_starfield() -> void:
	if not starfield_multimesh:
		return
		
	var star_count = 260
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.instance_count = star_count
	
	# Small diamond / tetrahedron star mesh
	var star_mesh = BoxMesh.new()
	star_mesh.size = Vector3(1.2, 1.2, 1.2)
	var star_mat = StandardMaterial3D.new()
	star_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	star_mat.vertex_color_use_as_albedo = true
	star_mesh.material = star_mat
	mm.mesh = star_mesh
	
	var rng = RandomNumberGenerator.new()
	rng.seed = 98765
	
	var star_colors = [
		Color(1.0, 1.0, 1.0),
		Color(0.7, 0.85, 1.0),
		Color(1.0, 0.9, 0.7),
		Color(0.5, 0.75, 1.0),
		Color(1.0, 0.6, 0.5)
	]
	
	for i in range(star_count):
		# Distribute on outer sphere at ~480m radius
		var u = rng.randf_range(-1.0, 1.0)
		var theta = rng.randf_range(0.0, TAU)
		var r = sqrt(1.0 - u * u)
		var dir = Vector3(r * cos(theta), u, r * sin(theta)).normalized()
		var dist = rng.randf_range(440.0, 520.0)
		var pos = dir * dist
		
		var t = Transform3D()
		var scale_val = rng.randf_range(0.6, 2.2)
		t = t.scaled(Vector3.ONE * scale_val)
		t.origin = pos
		
		mm.set_instance_transform(i, t)
		var col = star_colors[rng.randi_range(0, star_colors.size() - 1)]
		mm.set_instance_color(i, col)
		
	starfield_multimesh.multimesh = mm

func _create_asteroid_belt() -> void:
	if not asteroid_multimesh:
		return
		
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = asteroid_count
	
	# Faceted low-poly asteroid rock mesh
	var rock_mesh = _generate_lowpoly_rock_mesh()
	mm.mesh = rock_mesh
	
	var rng = RandomNumberGenerator.new()
	rng.seed = 12345
	asteroids.clear()
	
	for i in range(asteroid_count):
		var data = AsteroidData.new()
		
		# Torus / Belt distribution with vertical spread
		var angle = rng.randf_range(0.0, TAU)
		var radius = rng.randf_range(min_radius, max_radius)
		var y = rng.randf_range(-height_spread, height_spread) * (1.0 - (radius / max_radius) * 0.3)
		data.pos = Vector3(cos(angle) * radius, y, sin(angle) * radius)
		
		data.rot_axis = Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
		data.rot_speed = rng.randf_range(0.1, 0.6)
		data.rot_current = rng.randf_range(0.0, TAU)
		
		# Scale variation (majority medium 3-6m, some huge 12-18m)
		var is_huge = rng.randf() < 0.12
		var base_scale = rng.randf_range(10.0, 18.0) if is_huge else rng.randf_range(2.5, 7.5)
		data.scale = Vector3(
			base_scale * rng.randf_range(0.8, 1.25),
			base_scale * rng.randf_range(0.75, 1.2),
			base_scale * rng.randf_range(0.8, 1.3)
		)
		data.radius = base_scale * 0.5
		
		asteroids.append(data)
		
		var t = Transform3D()
		t = t.rotated(data.rot_axis, data.rot_current)
		t = t.scaled(data.scale)
		t.origin = data.pos
		mm.set_instance_transform(i, t)
		
		# If it's a huge asteroid, add a static body with collision shape so player/lasers can collide!
		if is_huge:
			_spawn_collision_proxy(data.pos, data.radius * 1.8)
			
	asteroid_multimesh.multimesh = mm

func _spawn_collision_proxy(pos: Vector3, radius: float) -> void:
	var sb = StaticBody3D.new()
	sb.collision_layer = 2 # Treat as world / obstacle
	sb.collision_mask = 5
	var cs = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = radius
	cs.shape = shape
	sb.add_child(cs)
	sb.global_position = pos
	add_child(sb)

func _generate_lowpoly_rock_mesh() -> ArrayMesh:
	# Create faceted irregular asteroid mesh
	var sphere = SphereMesh.new()
	sphere.radial_segments = 6
	sphere.rings = 4
	sphere.radius = 1.0
	sphere.height = 2.0
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.42, 0.40, 0.38, 1.0)
	mat.roughness = 0.95
	mat.metallic = 0.1
	
	# Convert primitive mesh to ArrayMesh
	var arr_mesh = ArrayMesh.new()
	var arrays = sphere.get_mesh_arrays()
	
	# Displace vertices with pseudo-noise for craggy asteroid look
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var rng = RandomNumberGenerator.new()
	rng.seed = 54321
	for v_idx in range(verts.size()):
		var v = verts[v_idx]
		var displace = 1.0 + rng.randf_range(-0.25, 0.25)
		verts[v_idx] = v * displace
	arrays[Mesh.ARRAY_VERTEX] = verts
	
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	arr_mesh.surface_set_material(0, mat)
	return arr_mesh

func _process(delta: float) -> void:
	# High-performance zero-reupload tumble:
	# Rotate the multi-mesh container nodes directly rather than re-uploading buffer data to GPU!
	if asteroid_multimesh:
		asteroid_multimesh.rotate_y(0.03 * delta)
		asteroid_multimesh.rotate_x(0.015 * delta)

