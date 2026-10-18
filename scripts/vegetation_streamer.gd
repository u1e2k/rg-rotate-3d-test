class_name VegetationStreamer
extends Node3D

## High-performance vegetation and boulder streamer using MultiMeshInstance3D (1-2 Draw Calls)
## Conforms foliage and rocks procedurally to terrain height and slope.

@export var tree_instance_count: int = 140
@export var rock_instance_count: int = 70
@export var stream_radius: float = 175.0

@onready var tree_multimesh: MultiMeshInstance3D = $TreeMultiMesh
@onready var rock_multimesh: MultiMeshInstance3D = $RockMultiMesh

var terrain_manager: TerrainChunkManager = null
var tracked_target: Node3D = null
var last_stream_pos: Vector3 = Vector3(9999, 9999, 9999)

func _ready() -> void:
	_init_tree_mesh()
	_init_rock_mesh()

func setup(terrain: TerrainChunkManager, target: Node3D) -> void:
	terrain_manager = terrain
	tracked_target = target
	_rebuild_vegetation()

func _process(_delta: float) -> void:
	if not is_instance_valid(tracked_target) or not terrain_manager:
		return
		
	if tracked_target.global_position.distance_to(last_stream_pos) > 65.0:
		_rebuild_vegetation()

func _rebuild_vegetation() -> void:
	if not is_instance_valid(tracked_target) or not terrain_manager:
		return
		
	last_stream_pos = tracked_target.global_position
	var center_x = last_stream_pos.x
	var center_z = last_stream_pos.z
	
	var rng = RandomNumberGenerator.new()
	rng.seed = int(center_x * 13.0 + center_z * 37.0)
	
	# 1. Distribute Trees
	var t_mm = tree_multimesh.multimesh
	var tree_idx = 0
	for i in range(tree_instance_count):
		var r = rng.randf_range(18.0, stream_radius)
		var angle = rng.randf_range(0.0, TAU)
		var px = center_x + cos(angle) * r
		var pz = center_z + sin(angle) * r
		var py = terrain_manager.get_height(px, pz)
		var norm = terrain_manager.get_normal(px, pz)
		
		# Trees grow mostly on grassy plains and gentle slopes (slope < 0.28, altitude < 28m)
		var slope = 1.0 - norm.y
		if slope < 0.30 and py < 28.0 and py > 2.0:
			var t = Transform3D()
			var scale_s = rng.randf_range(0.8, 1.4)
			t = t.scaled(Vector3(scale_s, scale_s * rng.randf_range(0.9, 1.3), scale_s))
			t = t.rotated(Vector3.UP, rng.randf_range(0.0, TAU))
			t.origin = Vector3(px, py - 0.2, pz)
			t_mm.set_instance_transform(tree_idx, t)
			tree_idx += 1
			
	# Hide unused trees
	for i in range(tree_idx, tree_instance_count):
		var t = Transform3D()
		t = t.scaled(Vector3.ZERO)
		t.origin = Vector3(0, -100, 0)
		t_mm.set_instance_transform(i, t)
		
	# 2. Distribute Rocks
	var r_mm = rock_multimesh.multimesh
	var rock_idx = 0
	for i in range(rock_instance_count):
		var r = rng.randf_range(12.0, stream_radius)
		var angle = rng.randf_range(0.0, TAU)
		var px = center_x + cos(angle) * r
		var pz = center_z + sin(angle) * r
		var py = terrain_manager.get_height(px, pz)
		var norm = terrain_manager.get_normal(px, pz)
		
		var t = Transform3D()
		var scale_s = rng.randf_range(1.5, 3.8)
		t = t.scaled(Vector3(scale_s * rng.randf_range(0.8, 1.2), scale_s * rng.randf_range(0.6, 1.1), scale_s * rng.randf_range(0.8, 1.2)))
		t = t.rotated(norm.cross(Vector3.UP).normalized() if norm.y < 0.99 else Vector3.UP, rng.randf_range(0.0, TAU))
		t.origin = Vector3(px, py - 0.4, pz)
		r_mm.set_instance_transform(rock_idx, t)
		rock_idx += 1
		
	for i in range(rock_idx, rock_instance_count):
		var t = Transform3D()
		t = t.scaled(Vector3.ZERO)
		t.origin = Vector3(0, -100, 0)
		r_mm.set_instance_transform(i, t)

func _init_tree_mesh() -> void:
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = tree_instance_count
	
	# Build stylized conifer tree ArrayMesh (Trunk + 2 tiered cones)
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	
	var col_trunk = Color(0.38, 0.26, 0.16)
	var col_leaf1 = Color(0.12, 0.40, 0.18)
	var col_leaf2 = Color(0.18, 0.48, 0.24)
	
	_add_cylinder(st, 0.25, 0.35, 1.8, col_trunk, Vector3(0, 0.9, 0))
	_add_cone(st, 1.8, 2.2, col_leaf1, Vector3(0, 2.4, 0))
	_add_cone(st, 1.3, 1.9, col_leaf2, Vector3(0, 3.8, 0))
	
	var mesh = st.commit()
	mesh.surface_set_material(0, mat)
	mm.mesh = mesh
	tree_multimesh.multimesh = mm

func _init_rock_mesh() -> void:
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = rock_instance_count
	
	# Faceted craggy boulder
	var sphere = SphereMesh.new()
	sphere.radial_segments = 5
	sphere.rings = 3
	sphere.radius = 1.0
	sphere.height = 1.8
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.44, 0.42, 0.40)
	mat.roughness = 0.95
	
	var arr_mesh = ArrayMesh.new()
	var arrays = sphere.get_mesh_arrays()
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	arr_mesh.surface_set_material(0, mat)
	
	mm.mesh = arr_mesh
	rock_multimesh.multimesh = mm

func _add_cylinder(st: SurfaceTool, r_top: float, r_bot: float, h: float, col: Color, offset: Vector3) -> void:
	var segs = 6
	for i in range(segs):
		var a0 = float(i) / float(segs) * TAU
		var a1 = float(i + 1) / float(segs) * TAU
		var p0_b = offset + Vector3(cos(a0) * r_bot, -h * 0.5, sin(a0) * r_bot)
		var p1_b = offset + Vector3(cos(a1) * r_bot, -h * 0.5, sin(a1) * r_bot)
		var p0_t = offset + Vector3(cos(a0) * r_top, h * 0.5, sin(a0) * r_top)
		var p1_t = offset + Vector3(cos(a1) * r_top, h * 0.5, sin(a1) * r_top)
		
		var norm = Vector3(cos((a0 + a1) * 0.5), 0, sin((a0 + a1) * 0.5)).normalized()
		st.set_normal(norm); st.set_color(col); st.add_vertex(p0_b)
		st.set_normal(norm); st.set_color(col); st.add_vertex(p1_b)
		st.set_normal(norm); st.set_color(col); st.add_vertex(p1_t)
		
		st.set_normal(norm); st.set_color(col); st.add_vertex(p0_b)
		st.set_normal(norm); st.set_color(col); st.add_vertex(p1_t)
		st.set_normal(norm); st.set_color(col); st.add_vertex(p0_t)

func _add_cone(st: SurfaceTool, r: float, h: float, col: Color, offset: Vector3) -> void:
	var segs = 6
	var tip = offset + Vector3(0, h * 0.5, 0)
	for i in range(segs):
		var a0 = float(i) / float(segs) * TAU
		var a1 = float(i + 1) / float(segs) * TAU
		var p0 = offset + Vector3(cos(a0) * r, -h * 0.5, sin(a0) * r)
		var p1 = offset + Vector3(cos(a1) * r, -h * 0.5, sin(a1) * r)
		
		var norm = (tip - (p0 + p1) * 0.5).cross(p1 - p0).normalized()
		st.set_normal(norm); st.set_color(col); st.add_vertex(p0)
		st.set_normal(norm); st.set_color(col); st.add_vertex(p1)
		st.set_normal(norm); st.set_color(col); st.add_vertex(tip)
