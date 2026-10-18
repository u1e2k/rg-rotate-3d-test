class_name OffroadBuggy
extends CharacterBody3D

## High-speed 4-Wheel Offroad Buggy with dynamic terrain suspension physics for ANBERNIC RG Rotate

signal speed_changed(kmh: float, is_turbo: bool)

const SoundManagerScript = preload("res://scripts/sound_manager.gd")

@export var max_speed: float = 32.0 # ~115 km/h
@export var turbo_speed: float = 54.0 # ~195 km/h
@export var reverse_speed: float = 12.0
@export var acceleration: float = 24.0
@export var brake_decel: float = 38.0
@export var steer_speed: float = 2.4
@export var max_steer_angle: float = 0.58 # ~33 deg

var current_forward_speed: float = 0.0
var current_steer_angle: float = 0.0
var is_turbo: bool = false
var is_drifting: bool = false
var turbo_energy: float = 100.0

var terrain_manager: TerrainChunkManager = null

# Wheel node references
@onready var wheel_fl: Node3D = $Chassis/WheelFL
@onready var wheel_fr: Node3D = $Chassis/WheelFR
@onready var wheel_rl: Node3D = $Chassis/WheelRL
@onready var wheel_rr: Node3D = $Chassis/WheelRR
@onready var chassis_mesh: Node3D = $Chassis
@onready var chase_mount: Node3D = $ChaseMount
@onready var camera: Camera3D = $ChaseMount/SpringArm3D/Camera3D

# Suspension spring state
var suspension_pitch: float = 0.0
var suspension_roll: float = 0.0

func _ready() -> void:
	chase_mount.top_level = true
	camera.current = true

func set_terrain(terrain: TerrainChunkManager) -> void:
	terrain_manager = terrain
	# Align initial spawn to terrain height
	if terrain_manager:
		global_position.y = terrain_manager.get_height(global_position.x, global_position.z) + 0.85

func _physics_process(delta: float) -> void:
	_process_inputs(delta)
	_process_physics(delta)
	_update_chase_camera(delta)
	
	var kmh = abs(current_forward_speed) * 3.6
	speed_changed.emit(kmh, is_turbo)

func _process_inputs(delta: float) -> void:
	# Turbo Boost (Y Button / Shift)
	is_turbo = (Input.is_action_pressed("sprint") or Input.is_joy_button_pressed(0, JOY_BUTTON_Y)) and turbo_energy > 5.0
	if is_turbo:
		turbo_energy = maxf(turbo_energy - 35.0 * delta, 0.0)
	elif turbo_energy < 100.0:
		turbo_energy = minf(turbo_energy + 20.0 * delta, 100.0)
		
	# Handbrake Drift (B Button / Space)
	is_drifting = Input.is_action_pressed("jump") or Input.is_joy_button_pressed(0, JOY_BUTTON_B)
	
	# Throttle & Brake (▲▼ / W / S)
	var throttle = Input.get_action_strength("move_forward") - Input.get_action_strength("move_backward")
	var steer_in = Input.get_action_strength("turn_left") - Input.get_action_strength("turn_right")
	
	# Steering interpolation
	var target_steer = steer_in * max_steer_angle
	current_steer_angle = lerpf(current_steer_angle, target_steer, delta * 10.0)
	
	# Front wheel steering visual rotation
	wheel_fl.rotation.y = current_steer_angle
	wheel_fr.rotation.y = current_steer_angle
	
	# Speed target calculation
	var top_speed = turbo_speed if is_turbo else max_speed
	var target_speed = 0.0
	
	if throttle > 0.05:
		target_speed = top_speed * throttle
		current_forward_speed = move_toward(current_forward_speed, target_speed, acceleration * delta)
	elif throttle < -0.05:
		target_speed = -reverse_speed * abs(throttle)
		current_forward_speed = move_toward(current_forward_speed, target_speed, brake_decel * delta)
	else:
		# Coasting deceleration
		var coast_friction = 12.0 if not is_drifting else 6.0
		current_forward_speed = move_toward(current_forward_speed, 0.0, coast_friction * delta)
		
	# Apply Steering rotation
	if abs(current_forward_speed) > 0.2:
		var steer_factor = 1.0 if current_forward_speed >= 0.0 else -1.0
		var drift_mult = 1.6 if is_drifting else 1.0
		rotate_y(current_steer_angle * steer_factor * steer_speed * drift_mult * delta)
		
	# Quick Turn 180 J-Turn (LB Button)
	if Input.is_action_just_pressed("quick_turn") or Input.is_joy_button_pressed(0, JOY_BUTTON_LEFT_SHOULDER):
		rotate_y(PI * 0.95)
		current_forward_speed *= 0.5
		var sm = SoundManagerScript.get_instance()
		if sm: sm.play_barrel_roll()

func _process_physics(delta: float) -> void:
	var forward = -global_transform.basis.z.normalized()
	velocity.x = forward.x * current_forward_speed
	velocity.z = forward.z * current_forward_speed
	
	# Terrain height following & suspension
	if terrain_manager:
		var target_ground_y = terrain_manager.get_height(global_position.x, global_position.z) + 0.75
		# Smooth suspension vertical follow
		global_position.y = lerpf(global_position.y, target_ground_y, delta * 16.0)
		
		# Terrain surface normal alignment (pitch & roll slope conforming)
		var ground_normal = terrain_manager.get_normal(global_position.x, global_position.z)
		
		# Calculate chassis banking and pitch from slope
		var forward_slope = -forward.dot(ground_normal)
		var right = global_transform.basis.x.normalized()
		var side_slope = right.dot(ground_normal)
		
		chassis_mesh.rotation.x = lerpf(chassis_mesh.rotation.x, forward_slope * 0.8, delta * 12.0)
		chassis_mesh.rotation.z = lerpf(chassis_mesh.rotation.z, side_slope * 0.8, delta * 12.0)
	
	move_and_slide()
	
	# Wheel spinning visual animation
	var spin_delta = (current_forward_speed / 0.55) * delta
	wheel_fl.rotate_x(spin_delta)
	wheel_fr.rotate_x(spin_delta)
	wheel_rl.rotate_x(spin_delta)
	wheel_rr.rotate_x(spin_delta)

func _update_chase_camera(delta: float) -> void:
	if not chase_mount:
		return
		
	# Camera mount smoothly follows buggy position and yaw
	chase_mount.global_position = chase_mount.global_position.lerp(global_position, delta * 14.0)
	chase_mount.global_rotation.y = lerp_angle(chase_mount.global_rotation.y, global_rotation.y, delta * 8.0)
	
	# Dynamic FOV for speed sensation
	var target_fov = 82.0 if is_turbo else (74.0 if abs(current_forward_speed) > 20.0 else 68.0)
	camera.fov = lerpf(camera.fov, target_fov, delta * 6.0)
