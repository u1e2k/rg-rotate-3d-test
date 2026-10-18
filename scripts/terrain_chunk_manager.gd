class_name TerrainChunkManager
extends Node3D

## High-Performance Streaming Chunked Terrain with Distance LOD for Mali-G52 (60 FPS)
## Generates a vast 1.2km procedural landscape with continuous rolling hills, valleys, and mountain peaks.

@export var chunk_size: float = 140.0
@export var grid_radius: int = 2 # 5x5 chunks around player = 700m x 700m active span
@export var high_lod_distance: float = 180.0
@export var max_height: float = 48.0

var noise: FastNoiseLite
var mountain_noise: FastNoiseLite

# Active chunk instances: Vector2i(chunk_x, chunk_z) -> MeshInstance3D
var active_chunks: Dictionary = {}
var chunk_lods: Dictionary = {} # Vector2i -> int (0 = High, 1 = Low)

var tracked_target: Node3D = null
var last_chunk_coord: Vector2i = Vector2i(-9999, -9999)

# Terrain Material (Unshaded or simple per-vertex lighting with vertex color)
var terrain_material: StandardMaterial3D

func _ready() -> void:
	_init_noise()
	_init_material()

func _init_noise() -> void:
	noise = FastNoiseLite.new()
	noise.seed = 42817
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.0038
	noise.fractal_octaves = 3
	noise.fractal_lacunarity = 2.0
	noise.fractal_gain = 0.45
	
	mountain_noise = FastNoiseLite.new()
	mountain_noise.seed = 98123
	mountain_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	mountain_noise.frequency = 0.0018
	mountain_noise.fractal_octaves = 2

func _init_material() -> void:
	terrain_material = StandardMaterial3D.new()
	terrain_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	terrain_material.vertex_color_use_as_albedo = true
	terrain_material.roughness = 0.85
	terrain_material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED

func set_target(target: Node3D) -> void:
	tracked_target = target
	_update_chunks(true)

func get_height(world_x: float, world_z: float) -> float:
	if not noise:
		return 0.0
	var base = noise.get_noise_2d(world_x, world_z) # -1.0 to 1.0
	var ridge = mountain_noise.get_noise_2d(world_x, world_z) # Mountain multiplier
	
	# Undulating valleys, rolling green hills, and elevated mountain ridges
	var elevated_ridge = pow(maxf(ridge + 0.35, 0.0), 1.6) * 28.0
	var hills = (base + 0.3) * 18.0
	return hills + elevated_ridge

func get_normal(world_x: float, world_z: float) -> Vector3:
	var delta = 1.0
	var h_l = get_height(world_x - delta, world_z)
	var h_r = get_height(world_x + delta, world_z)
	var h_d = get_height(world_x, world_z - delta)
	var h_u = get_height(world_x, world_z + delta)
	return Vector3(h_l - h_r, 2.0 * delta, h_d - h_u).normalized()

func _process(_delta: float) -> void:
	if not is_instance_valid(tracked_target):
		return
		
	var target_pos = tracked_target.global_position
	var cur_chunk = Vector2i(
		int(floor(target_pos.x / chunk_size)),
		int(floor(target_pos.z / chunk_size))
	)
	
	if cur_chunk != last_chunk_coord:
		last_chunk_coord = cur_chunk
		_update_chunks(false)

func _update_chunks(force_rebuild: bool) -> void:
	if not is_instance_valid(tracked_target):
		return
		
	var target_pos = tracked_target.global_position
	var center_chunk = Vector2i(
		int(floor(target_pos.x / chunk_size)),
		int(floor(target_pos.z / chunk_size))
	)
	
	var needed_coords: Dictionary = {}
	
	# Determine chunks within grid radius
	for cx in range(center_chunk.x - grid_radius, center_chunk.x + grid_radius + 1):
		for cz in range(center_chunk.y - grid_radius, center_chunk.y + grid_radius + 1):
			var coord = Vector2i(cx, cz)
			needed_coords[coord] = true
			
			var chunk_center = Vector3(
				(float(cx) + 0.5) * chunk_size,
				0.0,
				(float(cz) + 0.5) * chunk_size
			)
			var dist = Vector2(target_pos.x - chunk_center.x, target_pos.z - chunk_center.z).length()
			var desired_lod = 0 if dist < high_lod_distance else 1
			
			if not active_chunks.has(coord) or force_rebuild:
				_build_chunk(coord, desired_lod)
			elif chunk_lods.get(coord, -1) != desired_lod:
				# LOD switch
				_build_chunk(coord, desired_lod)
				
	# Remove out-of-range chunks
	var to_remove = []
	for coord in active_chunks.keys():
		if not needed_coords.has(coord):
			to_remove.append(coord)
			
	for coord in to_remove:
		var mi = active_chunks[coord] as MeshInstance3D
		if mi:
			mi.queue_free()
		active_chunks.erase(coord)
		chunk_lods.erase(coord)

func _build_chunk(coord: Vector2i, lod: int) -> void:
	# Clean old chunk at this coord if replacing
	if active_chunks.has(coord):
		var old_mi = active_chunks[coord] as MeshInstance3D
		if old_mi:
			old_mi.queue_free()
			
	var subdivisions = 12 if lod == 0 else 4
	var mesh = _generate_chunk_mesh(coord.x, coord.y, subdivisions)
	
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = terrain_material
	add_child(mi)
	
	active_chunks[coord] = mi
	chunk_lods[coord] = lod

func _generate_chunk_mesh(chunk_x: int, chunk_z: int, resolution: int) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var step = chunk_size / float(resolution)
	var origin_x = float(chunk_x) * chunk_size
	var origin_z = float(chunk_z) * chunk_size
	
	for z_idx in range(resolution):
		for x_idx in range(resolution):
			var x0 = origin_x + float(x_idx) * step
			var x1 = x0 + step
			var z0 = origin_z + float(z_idx) * step
			var z1 = z0 + step
			
			var y00 = get_height(x0, z0)
			var y10 = get_height(x1, z0)
			var y01 = get_height(x0, z1)
			var y11 = get_height(x1, z1)
			
			var p00 = Vector3(x0, y00, z0)
			var p10 = Vector3(x1, y10, z0)
			var p01 = Vector3(x0, y01, z1)
			var p11 = Vector3(x1, y11, z1)
			
			var n00 = get_normal(x0, z0)
			var n10 = get_normal(x1, z0)
			var n01 = get_normal(x0, z1)
			var n11 = get_normal(x1, z1)
			
			var c00 = _get_altitude_color(y00, n00)
			var c10 = _get_altitude_color(y10, n10)
			var c01 = _get_altitude_color(y01, n01)
			var c11 = _get_altitude_color(y11, n11)
			
			# Quad Triangle 1: p00 -> p10 -> p11
			st.set_normal(n00); st.set_color(c00); st.add_vertex(p00)
			st.set_normal(n10); st.set_color(c10); st.add_vertex(p10)
			st.set_normal(n11); st.set_color(c11); st.add_vertex(p11)
			
			# Quad Triangle 2: p00 -> p11 -> p01
			st.set_normal(n00); st.set_color(c00); st.add_vertex(p00)
			st.set_normal(n11); st.set_color(c11); st.add_vertex(p11)
			st.set_normal(n01); st.set_color(c01); st.add_vertex(p01)
			
	return st.commit()

func _get_altitude_color(altitude: float, normal: Vector3) -> Color:
	var slope = 1.0 - normal.y # 0.0 = completely flat, 1.0 = vertical wall
	
	# Lush Green Plains / Valleys
	var col_grass = Color(0.24, 0.58, 0.22)
	# Highland Meadow
	var col_highland = Color(0.42, 0.55, 0.26)
	# Rocky Mountain Slate
	var col_rock = Color(0.50, 0.48, 0.44)
	# Snowy Peak
	var col_snow = Color(0.88, 0.92, 0.96)
	
	if slope > 0.42:
		# Steep cliff face
		return col_rock
		
	if altitude < 14.0:
		var t = clampf(altitude / 14.0, 0.0, 1.0)
		return col_grass.lerp(col_highland, t)
	elif altitude < 30.0:
		var t = clampf((altitude - 14.0) / 16.0, 0.0, 1.0)
		return col_highland.lerp(col_rock, t)
	else:
		var t = clampf((altitude - 30.0) / 15.0, 0.0, 1.0)
		return col_rock.lerp(col_snow, t)

func get_lod_stats() -> Dictionary:
	var high = 0
	var low = 0
	for lod in chunk_lods.values():
		if lod == 0: high += 1
		else: low += 1
	return {"total": active_chunks.size(), "high": high, "low": low}
