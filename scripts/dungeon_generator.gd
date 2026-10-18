class_name DungeonGenerator
extends Node3D

## Procedural Stone Dungeon Arena with Dynamic Lighting Stress Controller
## Allows toggling between Optimized (2 Dynamic Lights / 60 FPS) and Stress (6 Dynamic Lights)

signal lighting_mode_changed(mode_name: String, light_count: int)

@export var arena_size: float = 36.0
@export var wall_height: float = 6.0

var is_stress_mode: bool = false
var dynamic_torch_lights: Array[OmniLight3D] = []
var static_torch_flames: Array[MeshInstance3D] = []

func _ready() -> void:
	_build_dungeon_geometry()
	_setup_lighting()

func _build_dungeon_geometry() -> void:
	# Materials
	var floor_mat = StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.22, 0.23, 0.25)
	floor_mat.roughness = 0.85
	
	var wall_mat = StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.32, 0.33, 0.35)
	wall_mat.roughness = 0.9
	
	var pillar_mat = StandardMaterial3D.new()
	pillar_mat.albedo_color = Color(0.26, 0.27, 0.29)
	pillar_mat.roughness = 0.8

	# Floor
	var floor_mesh = PlaneMesh.new()
	floor_mesh.size = Vector2(arena_size, arena_size)
	var floor_inst = MeshInstance3D.new()
	floor_inst.mesh = floor_mesh
	floor_inst.material_override = floor_mat
	add_child(floor_inst)
	
	# Floor StaticBody3D
	var floor_body = StaticBody3D.new()
	var floor_col = CollisionShape3D.new()
	var floor_shape = WorldBoundaryShape3D.new()
	floor_col.shape = floor_shape
	floor_body.add_child(floor_col)
	add_child(floor_body)

	# 4 Perimeter Walls
	var half_size = arena_size * 0.5
	_create_wall(Vector3(0, wall_height * 0.5, -half_size), Vector3(arena_size, wall_height, 1.2), wall_mat)
	_create_wall(Vector3(0, wall_height * 0.5, half_size), Vector3(arena_size, wall_height, 1.2), wall_mat)
	_create_wall(Vector3(-half_size, wall_height * 0.5, 0), Vector3(1.2, wall_height, arena_size), wall_mat)
	_create_wall(Vector3(half_size, wall_height * 0.5, 0), Vector3(1.2, wall_height, arena_size), wall_mat)

	# 8 Stone Pillars (Arranged along the arena perimeter)
	var pillar_radius = 13.5
	for i in range(8):
		var angle = (float(i) / 8.0) * TAU
		var px = cos(angle) * pillar_radius
		var pz = sin(angle) * pillar_radius
		_create_pillar(Vector3(px, wall_height * 0.5, pz), pillar_mat)

func _create_wall(pos: Vector3, size: Vector3, mat: Material) -> void:
	var wall_inst = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = size
	wall_inst.mesh = box
	wall_inst.material_override = mat
	wall_inst.position = pos
	wall_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(wall_inst)

	var body = StaticBody3D.new()
	body.position = pos
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	add_child(body)

func _create_pillar(pos: Vector3, mat: Material) -> void:
	var pillar_inst = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.9
	cyl.bottom_radius = 1.05
	cyl.height = wall_height
	pillar_inst.mesh = cyl
	pillar_inst.material_override = mat
	pillar_inst.position = pos
	pillar_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(pillar_inst)

	var body = StaticBody3D.new()
	body.position = pos
	var col = CollisionShape3D.new()
	var shape = CylinderShape3D.new()
	shape.radius = 1.0
	shape.height = wall_height
	col.shape = shape
	body.add_child(col)
	add_child(body)

func _setup_lighting() -> void:
	# 4 Wall Torches at Cardinal Positions
	var torch_dist = (arena_size * 0.5) - 1.2
	var torch_positions = [
		Vector3(0, 3.2, -torch_dist),
		Vector3(0, 3.2, torch_dist),
		Vector3(-torch_dist, 3.2, 0),
		Vector3(torch_dist, 3.2, 0)
	]

	var flame_mat = StandardMaterial3D.new()
	flame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame_mat.albedo_color = Color(1.0, 0.55, 0.15)

	for pos in torch_positions:
		# Flame Visual
		var flame = MeshInstance3D.new()
		var sphere = SphereMesh.new()
		sphere.radius = 0.25
		sphere.height = 0.55
		flame.mesh = sphere
		flame.material_override = flame_mat
		flame.position = pos
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(flame)
		static_torch_flames.append(flame)

		# Dynamic OmniLight3D (Disabled by default for 60 FPS, enabled during Stress Test)
		var light = OmniLight3D.new()
		light.position = pos
		light.light_color = Color(1.0, 0.65, 0.25)
		light.light_energy = 2.2
		light.omni_range = 14.0
		light.shadow_enabled = false
		light.visible = false
		add_child(light)
		dynamic_torch_lights.append(light)

func toggle_lighting_stress_mode() -> void:
	is_stress_mode = !is_stress_mode
	for l in dynamic_torch_lights:
		l.visible = is_stress_mode
		
	var mode_name = "STRESS (6 Lights)" if is_stress_mode else "OPTIMIZED (2 Lights)"
	var count = 6 if is_stress_mode else 2
	lighting_mode_changed.emit(mode_name, count)

func _process(delta: float) -> void:
	# Subtle flame flicker
	var t = Time.get_ticks_msec() * 0.015
	var flicker = sin(t * 1.7) * cos(t * 2.3) * 0.15
	for f in static_torch_flames:
		f.scale = Vector3(1.0 + flicker, 1.0 + flicker * 1.5, 1.0 + flicker)
	if is_stress_mode:
		for l in dynamic_torch_lights:
			l.light_energy = 2.2 + flicker * 0.8
