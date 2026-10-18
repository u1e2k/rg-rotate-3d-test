class_name MusouHorde
extends Node3D

## High-performance Horde Simulation using MultiMeshInstance3D for ANBERNIC RG Rotate
## Supports 30 to 150+ low-poly soldiers with 1 Draw Call and custom 2D pushout physics.

signal enemy_defeated(count: int)
signal horde_size_changed(new_size: int)

@export var max_enemies: int = 100
@export var arena_radius: float = 28.0

@onready var multi_mesh_instance: MultiMeshInstance3D = $MultiMeshInstance3D

class SoldierData:
	var position: Vector3 = Vector3.ZERO
	var velocity: Vector3 = Vector3.ZERO
	var rotation_y: float = 0.0
	var state: int = 0 # 0 = marching, 1 = flying (knocked back), 2 = defeated
	var walk_phase: float = 0.0
	var respawn_timer: float = 0.0
	var scale_y: float = 1.0

var soldiers: Array[SoldierData] = []
var active_count: int = 60 # Default starting count
var target_player: Node3D = null

# Preset enemy count tiers for benchmark testing
const COUNT_TIERS: Array[int] = [30, 60, 100, 150]
var current_tier_idx: int = 1

func _ready() -> void:
	_create_soldier_multimesh()
	_init_soldiers()

func set_target(player_node: Node3D) -> void:
	target_player = player_node

func cycle_enemy_tier() -> int:
	current_tier_idx = (current_tier_idx + 1) % COUNT_TIERS.size()
	set_active_count(COUNT_TIERS[current_tier_idx])
	return active_count

func set_active_count(count: int) -> void:
	active_count = clamp(count, 10, max_enemies)
	# Re-initialize or adjust positions
	for i in range(soldiers.size()):
		if i < active_count:
			if soldiers[i].state == 2:
				_spawn_soldier(soldiers[i])
		else:
			# Hide inactive soldiers underground
			soldiers[i].position = Vector3(0, -50, 0)
			soldiers[i].velocity = Vector3.ZERO
			soldiers[i].state = 2
	horde_size_changed.emit(active_count)

func _create_soldier_multimesh() -> void:
	var mesh = _generate_soldier_mesh()
	
	var multi_mesh = MultiMesh.new()
	multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
	multi_mesh.use_colors = true
	multi_mesh.mesh = mesh
	multi_mesh.instance_count = max_enemies
	
	multi_mesh_instance.multimesh = multi_mesh

func _generate_soldier_mesh() -> ArrayMesh:
	# Generate a low-poly PS2-style soldier mesh (Helmet, Armor body, Spear)
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var mat = StandardMaterial3D.new()
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_PER_VERTEX
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.8
	
	# Colors
	var col_helmet = Color(0.85, 0.25, 0.2) # Red enemy helmet
	var col_armor = Color(0.35, 0.4, 0.45)  # Iron armor
	var col_skin = Color(0.9, 0.75, 0.6)   # Face
	var col_spear = Color(0.7, 0.5, 0.3)   # Wooden spear shaft
	var col_blade = Color(0.9, 0.95, 1.0)  # Silver blade
	
	# Helper to append box
	var add_box = func(center: Vector3, size: Vector3, col: Color):
		var hx = size.x * 0.5
		var hy = size.y * 0.5
		var hz = size.z * 0.5
		
		var p = [
			center + Vector3(-hx, -hy, -hz),
			center + Vector3(hx, -hy, -hz),
			center + Vector3(hx, hy, -hz),
			center + Vector3(-hx, hy, -hz),
			center + Vector3(-hx, -hy, hz),
			center + Vector3(hx, -hy, hz),
			center + Vector3(hx, hy, hz),
			center + Vector3(-hx, hy, hz)
		]
		
		var faces = [
			[0,2,1], [0,3,2], # Back
			[4,5,6], [4,6,7], # Front
			[0,1,5], [0,5,4], # Bottom
			[3,6,2], [3,7,6], # Top
			[0,4,7], [0,7,3], # Left
			[1,2,6], [1,6,5]  # Right
		]
		
		for f in faces:
			st.set_color(col)
			st.add_vertex(p[f[0]])
			st.set_color(col)
			st.add_vertex(p[f[1]])
			st.set_color(col)
			st.add_vertex(p[f[2]])

	# Torso & Armor (Height: 0.8, Width: 0.5, Depth: 0.35)
	add_box.call(Vector3(0, 0.7, 0), Vector3(0.5, 0.6, 0.35), col_armor)
	# Head & Face
	add_box.call(Vector3(0, 1.15, 0), Vector3(0.3, 0.3, 0.3), col_skin)
	# Helmet & Plume
	add_box.call(Vector3(0, 1.35, 0), Vector3(0.36, 0.18, 0.36), col_helmet)
	add_box.call(Vector3(0, 1.48, 0), Vector3(0.1, 0.16, 0.3), Color(1.0, 0.8, 0.1)) # Gold crest
	# Left Leg
	add_box.call(Vector3(-0.15, 0.25, 0), Vector3(0.18, 0.5, 0.2), Color(0.25, 0.25, 0.3))
	# Right Leg
	add_box.call(Vector3(0.15, 0.25, 0), Vector3(0.18, 0.5, 0.2), Color(0.25, 0.25, 0.3))
	# Spear (Shaft + Blade in right hand)
	add_box.call(Vector3(0.35, 0.8, 0.2), Vector3(0.06, 1.6, 0.06), col_spear)
	add_box.call(Vector3(0.35, 1.7, 0.2), Vector3(0.12, 0.35, 0.04), col_blade)
	
	st.generate_normals()
	var mesh = st.commit()
	mesh.surface_set_material(0, mat)
	return mesh

func _init_soldiers() -> void:
	soldiers.clear()
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	for i in range(max_enemies):
		var s = SoldierData.new()
		s.walk_phase = rng.randf() * TAU
		if i < active_count:
			_spawn_soldier(s)
		else:
			s.position = Vector3(0, -50, 0)
			s.state = 2
		soldiers.append(s)

func _spawn_soldier(s: SoldierData) -> void:
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var angle = rng.randf() * TAU
	var dist = rng.randf_range(8.0, arena_radius - 2.0)
	s.position = Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
	s.velocity = Vector3.ZERO
	s.rotation_y = angle + PI
	s.state = 0
	s.respawn_timer = 0.0
	s.scale_y = 1.0

func _physics_process(delta: float) -> void:
	var player_pos = target_player.global_position if target_player else Vector3.ZERO
	var mm = multi_mesh_instance.multimesh
	if not mm:
		return
		
	for i in range(active_count):
		var s = soldiers[i]
		
		if s.state == 0:
			# Marching / Chasing Player
			var to_player = player_pos - s.position
			to_player.y = 0.0
			var dist = to_player.length()
			
			if dist > 1.2:
				var move_dir = to_player.normalized()
				var speed = 2.2
				s.position += move_dir * speed * delta
				s.rotation_y = atan2(-move_dir.x, -move_dir.z)
				s.walk_phase += delta * 8.0
				
				# Keep within arena bounds
				var r = Vector2(s.position.x, s.position.z).length()
				if r > arena_radius:
					var clamped = Vector2(s.position.x, s.position.z).normalized() * arena_radius
					s.position.x = clamped.x
					s.position.z = clamped.y
			
			# Ground clamping
			s.position.y = 0.0
			
		elif s.state == 1:
			# Flying / Knocked back
			s.position += s.velocity * delta
			s.velocity.y -= 18.0 * delta # Heavy gravity
			s.rotation_y += delta * 12.0 # Fast spin while flying
			
			if s.position.y <= 0.0:
				s.position.y = 0.0
				if s.velocity.y < -3.0:
					# Bounce once
					s.velocity.y = -s.velocity.y * 0.35
					s.velocity.x *= 0.6
					s.velocity.z *= 0.6
				else:
					# Landing - Defeated!
					s.state = 2
					s.respawn_timer = 1.2
					enemy_defeated.emit(1)
					
		elif s.state == 2:
			# Defeated / Shrinking and waiting to respawn
			s.respawn_timer -= delta
			s.scale_y = maxf(0.0, s.scale_y - delta * 2.0)
			if s.respawn_timer <= 0.0:
				_spawn_soldier(s)
		
		# Update MultiMesh Transform
		var t = Transform3D()
		# Add procedural walking bob & tilt
		var bob = sin(s.walk_phase) * 0.08 if s.state == 0 else 0.0
		var tilt = cos(s.walk_phase) * 0.06 if s.state == 0 else 0.0
		
		t = t.scaled(Vector3(1.0, s.scale_y, 1.0))
		t = t.rotated(Vector3.UP, s.rotation_y)
		t = t.rotated(Vector3.FORWARD, tilt)
		t.origin = s.position + Vector3(0, bob, 0)
		
		mm.set_instance_transform(i, t)
		
		# Hit flash / state color
		var col = Color.WHITE
		if s.state == 1:
			col = Color(1.5, 0.4, 0.3, 1.0) # Knocked back glow
		elif s.state == 2:
			col = Color(0.4, 0.4, 0.4, 0.5)
		mm.set_instance_color(i, col)
		
	# Simple separation pass (every 2 frames to save CPU)
	if Engine.get_physics_frames() % 2 == 0:
		_apply_separation(delta)

func _apply_separation(_delta: float) -> void:
	var push_radius = 0.85
	var push_sq = push_radius * push_radius
	
	for i in range(active_count):
		var s1 = soldiers[i]
		if s1.state != 0:
			continue
		for j in range(i + 1, min(active_count, i + 8)): # Check only neighboring indices
			var s2 = soldiers[j]
			if s2.state != 0:
				continue
			var dx = s1.position.x - s2.position.x
			var dz = s1.position.z - s2.position.z
			var d_sq = dx * dx + dz * dz
			if d_sq < push_sq and d_sq > 0.001:
				var d = sqrt(d_sq)
				var overlap = (push_radius - d) * 0.5
				var nx = dx / d
				var nz = dz / d
				s1.position.x += nx * overlap
				s1.position.z += nz * overlap
				s2.position.x -= nx * overlap
				s2.position.z -= nz * overlap

## Sweeping attack from player: blows back all enemies within sector or radius
func perform_sweep_attack(center: Vector3, forward: Vector3, radius: float, arc_degrees: float, power: float) -> int:
	var hits = 0
	var forward_2d = Vector2(forward.x, forward.z).normalized()
	var arc_rad = deg_to_rad(arc_degrees * 0.5)
	
	for i in range(active_count):
		var s = soldiers[i]
		if s.state != 0:
			continue
			
		var to_s = Vector2(s.position.x - center.x, s.position.z - center.z)
		var dist = to_s.length()
		
		if dist <= radius:
			var dir_to_s = to_s.normalized()
			var dot = forward_2d.dot(dir_to_s)
			var angle = acos(clampf(dot, -1.0, 1.0))
			
			if arc_degrees >= 360.0 or angle <= arc_rad:
				# HIT! Blow back!
				hits += 1
				s.state = 1
				var launch_dir = Vector3(dir_to_s.x, 0.8, dir_to_s.y).normalized()
				s.velocity = launch_dir * power * (1.1 - (dist / radius) * 0.4)
				s.velocity.y = maxf(s.velocity.y, power * 0.65)
				
	return hits
