class_name SpaceEnemy
extends CharacterBody3D

signal defeated(enemy_node: Node3D)

const SoundManagerScript = preload("res://scripts/sound_manager.gd")
const LaserScene = preload("res://scenes/space_laser.tscn")

@export var max_health: float = 3.0
@export var cruise_speed: float = 26.0
@export var attack_speed: float = 38.0
@export var turn_rate: float = 2.4

var health: float = 3.0
var target_player: Node3D = null
var shoot_cooldown: float = 1.0
var state_timer: float = 0.0
var is_dying: bool = false

# AI states: 0 = Patrol, 1 = AttackRun, 2 = EvasiveLoop
enum AIState { PATROL, ATTACK_RUN, EVASIVE_LOOP }
var current_state: AIState = AIState.PATROL
var patrol_target_pos: Vector3 = Vector3.ZERO
var evasive_axis: Vector3 = Vector3.UP

@onready var visual_mesh: Node3D = $Visual
@onready var left_muzzle: Marker3D = $Visual/LeftMuzzle
@onready var right_muzzle: Marker3D = $Visual/RightMuzzle

func _ready() -> void:
	add_to_group("enemy")
	health = max_health
	_pick_new_patrol_target()

func set_target(player_node: Node3D) -> void:
	target_player = player_node

func take_damage(amount: float) -> void:
	if is_dying:
		return
	health -= amount
	
	# Flash visual
	var tw = create_tween()
	tw.tween_property(visual_mesh, "scale", Vector3(1.2, 1.2, 1.2), 0.05)
	tw.tween_property(visual_mesh, "scale", Vector3.ONE, 0.05)
	
	if health <= 0:
		_die()
	else:
		# If hit, trigger evasive maneuver
		current_state = AIState.EVASIVE_LOOP
		state_timer = randf_range(2.0, 3.5)
		evasive_axis = Vector3(randf_range(-1, 1), randf_range(0.2, 1), randf_range(-1, 1)).normalized()

func _die() -> void:
	if is_dying:
		return
	is_dying = true
	defeated.emit(self)
	
	var sm = SoundManagerScript.get_instance()
	if sm:
		sm.play_explode()
		
	# Death explosion effect
		
	var tw = create_tween().set_parallel(true)
	tw.tween_property(visual_mesh, "scale", Vector3(3.0, 3.0, 3.0), 0.15)
	tw.tween_property(visual_mesh, "rotation:y", rotation.y + PI, 0.2)
	
	var fade_tw = create_tween()
	fade_tw.tween_interval(0.15)
	fade_tw.tween_callback(queue_free)

func _physics_process(delta: float) -> void:
	if is_dying:
		return
		
	state_timer -= delta
	shoot_cooldown -= delta
	
	var move_speed = cruise_speed
	var forward = -global_transform.basis.z.normalized()
	
	if not is_instance_valid(target_player):
		_process_patrol(delta)
	else:
		var dist_to_player = global_position.distance_to(target_player.global_position)
		
		match current_state:
			AIState.PATROL:
				if dist_to_player < 280.0:
					current_state = AIState.ATTACK_RUN
					state_timer = randf_range(4.0, 6.0)
				else:
					_process_patrol(delta)
					
			AIState.ATTACK_RUN:
				move_speed = attack_speed
				var dir_to_player = (target_player.global_position - global_position).normalized()
				
				# Steer toward player
				var target_transform = global_transform.looking_at(global_position + dir_to_player, Vector3.UP)
				global_transform = global_transform.interpolate_with(target_transform, turn_rate * delta)
				
				# Check if in front arc and within range to fire
				var angle = forward.angle_to(dir_to_player)
				if angle < deg_to_rad(28.0) and dist_to_player < 180.0 and shoot_cooldown <= 0.0:
					_fire_lasers()
					shoot_cooldown = randf_range(0.8, 1.4)
					
				# If we flew past player or time expired, switch to evasive loop
				if dist_to_player < 30.0 or state_timer <= 0.0:
					current_state = AIState.EVASIVE_LOOP
					state_timer = randf_range(2.5, 4.0)
					evasive_axis = Vector3(randf_range(-1, 1), randf_range(0.5, 1.2), randf_range(-1, 1)).normalized()
					
			AIState.EVASIVE_LOOP:
				move_speed = attack_speed * 1.1
				# Barrel loop / bank away
				rotate_object_local(Vector3.RIGHT, 1.8 * delta)
				rotate_object_local(Vector3.FORWARD, 2.2 * delta)
				if state_timer <= 0.0:
					current_state = AIState.ATTACK_RUN
					state_timer = randf_range(4.0, 6.5)
	
	# Apply forward movement
	velocity = forward * move_speed
	move_and_slide()
	
	# Keep within space arena boundaries
	if global_position.length() > 380.0:
		# Steer back to center
		var to_center = -global_position.normalized()
		var target_trans = global_transform.looking_at(global_position + to_center, Vector3.UP)
		global_transform = global_transform.interpolate_with(target_trans, 3.5 * delta)

func _process_patrol(delta: float) -> void:
	if global_position.distance_to(patrol_target_pos) < 30.0 or state_timer <= 0.0:
		_pick_new_patrol_target()
		state_timer = randf_range(6.0, 10.0)
		
	var dir = (patrol_target_pos - global_position).normalized()
	var target_transform = global_transform.looking_at(global_position + dir, Vector3.UP)
	global_transform = global_transform.interpolate_with(target_transform, turn_rate * 0.7 * delta)

func _pick_new_patrol_target() -> void:
	patrol_target_pos = Vector3(
		randf_range(-180.0, 180.0),
		randf_range(-60.0, 60.0),
		randf_range(-180.0, 180.0)
	)

func _fire_lasers() -> void:
	var shoot_dir = -global_transform.basis.z.normalized()
	
	if left_muzzle:
		var l1 = LaserScene.instantiate()
		l1.global_position = left_muzzle.global_position
		l1.direction = shoot_dir
		l1.is_enemy_fire = true
		_tint_enemy_laser(l1)
		get_tree().current_scene.add_child(l1)
		
	if right_muzzle:
		var l2 = LaserScene.instantiate()
		l2.global_position = right_muzzle.global_position
		l2.direction = shoot_dir
		l2.is_enemy_fire = true
		_tint_enemy_laser(l2)
		get_tree().current_scene.add_child(l2)
		
	var sm = SoundManagerScript.get_instance()
	if sm:
		sm.play_shoot()

func _tint_enemy_laser(laser: Node3D) -> void:
	var mesh = laser.get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh and mesh.material_override == null:
		var red_mat = StandardMaterial3D.new()
		red_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		red_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		red_mat.albedo_color = Color(1.0, 0.2, 0.1, 0.9)
		red_mat.emission_enabled = true
		red_mat.emission = Color(1.0, 0.2, 0.1)
		red_mat.emission_energy_multiplier = 3.0
		mesh.material_override = red_mat
		
	var light = laser.get_node_or_null("OmniLight3D") as OmniLight3D
	if light:
		light.light_color = Color(1.0, 0.2, 0.1)
