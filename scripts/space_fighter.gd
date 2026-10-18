class_name SpaceFighter
extends CharacterBody3D

signal weapon_fired(type: String)
signal camera_switched(is_cockpit: bool)
signal damage_taken(current_hp: float, current_shield: float)

const SoundManagerScript = preload("res://scripts/sound_manager.gd")
const LaserScene = preload("res://scenes/space_laser.tscn")
const MissileScene = preload("res://scenes/space_missile.tscn")

@export var cruise_speed: float = 32.0
@export var boost_speed: float = 68.0
@export var brake_speed: float = 14.0
@export var pitch_rate: float = 2.0
@export var turn_rate: float = 2.2
@export var roll_rate: float = 3.2

# Stats
var max_shield: float = 10.0
var shield: float = 10.0
var max_hull: float = 10.0
var hull: float = 10.0
var boost_energy: float = 100.0
var max_boost_energy: float = 100.0
var shield_regen_timer: float = 0.0

# Flight state
var current_speed: float = 30.0
var is_boosting: bool = false
var is_braking: bool = false

# Barrel roll state
var is_barrel_rolling: bool = false
var barrel_roll_timer: float = 0.0
var barrel_roll_dir: float = 1.0

# Weapon cooldowns
var blaster_cooldown: float = 0.0
var missile_cooldown: float = 0.0

# Camera mode
var is_cockpit_view: bool = false

# Lock-on target
var locked_target: Node3D = null
var target_candidate: Node3D = null
var lock_timer: float = 0.0
const LOCK_TIME_REQUIRED: float = 0.35

# Node references
@onready var visual_model: Node3D = $VisualModel
@onready var left_muzzle: Marker3D = $VisualModel/Wings/LeftMuzzle
@onready var right_muzzle: Marker3D = $VisualModel/Wings/RightMuzzle
@onready var missile_hardpoint: Marker3D = $VisualModel/Fuselage/MissileHardpoint
@onready var flame_left: MeshInstance3D = $VisualModel/Thrusters/FlameLeft
@onready var flame_right: MeshInstance3D = $VisualModel/Thrusters/FlameRight
@onready var chase_camera: Camera3D = $ChaseMount/SpringArm3D/Camera3D
@onready var cockpit_camera: Camera3D = $VisualModel/CockpitMount/Camera3D
@onready var chase_mount: Node3D = $ChaseMount

func _ready() -> void:
	add_to_group("player")
	chase_camera.current = true
	cockpit_camera.current = false
	current_speed = cruise_speed

func take_damage(amount: float) -> void:
	if is_barrel_rolling:
		# Barrel roll deflects attacks!
		var sm = SoundManagerScript.get_instance()
		if sm:
			sm.play_hit()
		return
		
	shield_regen_timer = 4.0
	
	if shield > 0.0:
		shield -= amount
		if shield < 0.0:
			hull += shield
			shield = 0.0
	else:
		hull -= amount
		
	hull = maxf(hull, 0.0)
	damage_taken.emit(hull, shield)
	
	var sm = SoundManagerScript.get_instance()
	if sm:
		sm.play_hit()

func _physics_process(delta: float) -> void:
	_process_regen(delta)
	_process_inputs(delta)
	_process_flight(delta)
	_process_weapons(delta)
	_process_lockon(delta)
	_update_camera(delta)

func _process_regen(delta: float) -> void:
	# Shield recharge after delay
	if shield_regen_timer > 0.0:
		shield_regen_timer -= delta
	elif shield < max_shield:
		shield = minf(shield + 2.0 * delta, max_shield)
		damage_taken.emit(hull, shield)
		
	# Boost energy recharge
	if not is_boosting and boost_energy < max_boost_energy:
		boost_energy = minf(boost_energy + 25.0 * delta, max_boost_energy)

func _process_inputs(delta: float) -> void:
	# Camera toggle (X button / Joy Button 2 / Key X)
	var x_pressed = Input.is_joy_button_pressed(0, JOY_BUTTON_X) or Input.is_key_pressed(KEY_X)
	if x_pressed and not get_meta("x_held", false):
		set_meta("x_held", true)
		_toggle_camera_mode()
	elif not x_pressed:
		set_meta("x_held", false)
		
	# Barrel roll (LB button / Joy Button 9 / Key Q)
	if (Input.is_action_just_pressed("quick_turn") or Input.is_joy_button_pressed(0, JOY_BUTTON_LEFT_SHOULDER)) and not is_barrel_rolling:
		_start_barrel_roll()

func _toggle_camera_mode() -> void:
	is_cockpit_view = not is_cockpit_view
	chase_camera.current = not is_cockpit_view
	cockpit_camera.current = is_cockpit_view
	camera_switched.emit(is_cockpit_view)
	
	var sm = SoundManagerScript.get_instance()
	if sm:
		sm.play_cursor()

func _start_barrel_roll() -> void:
	is_barrel_rolling = true
	barrel_roll_timer = 0.45
	# Roll in direction of current turning, or left by default
	var turn_in = Input.get_action_strength("turn_right") - Input.get_action_strength("turn_left")
	barrel_roll_dir = 1.0 if turn_in >= 0.0 else -1.0
	
	var sm = SoundManagerScript.get_instance()
	if sm:
		sm.play_barrel_roll()

func _process_flight(delta: float) -> void:
	# Boost / Brake
	is_boosting = (Input.is_action_pressed("sprint") or Input.is_joy_button_pressed(0, JOY_BUTTON_Y)) and boost_energy > 5.0
	is_braking = Input.is_action_pressed("jump") or Input.is_joy_button_pressed(0, JOY_BUTTON_B)
	
	var target_speed = cruise_speed
	if is_boosting:
		target_speed = boost_speed
		boost_energy = maxf(boost_energy - 35.0 * delta, 0.0)
		if flame_left: flame_left.scale.z = 2.0
		if flame_right: flame_right.scale.z = 2.0
	elif is_braking:
		target_speed = brake_speed
		if flame_left: flame_left.scale.z = 0.4
		if flame_right: flame_right.scale.z = 0.4
	else:
		target_speed = cruise_speed
		if flame_left: flame_left.scale.z = 1.0
		if flame_right: flame_right.scale.z = 1.0
		
	current_speed = lerpf(current_speed, target_speed, delta * 3.5)
	
	# Flight Steering
	var pitch_input = Input.get_action_strength("move_backward") - Input.get_action_strength("move_forward")
	var turn_input = Input.get_action_strength("turn_left") - Input.get_action_strength("turn_right")
	
	# Barrel roll handling
	if is_barrel_rolling:
		barrel_roll_timer -= delta
		visual_model.rotate_object_local(Vector3.FORWARD, barrel_roll_dir * 14.0 * delta)
		if barrel_roll_timer <= 0.0:
			is_barrel_rolling = false
			visual_model.rotation.z = 0.0
	else:
		# Pitch: Local X
		if abs(pitch_input) > 0.01:
			rotate_object_local(Vector3.RIGHT, pitch_input * pitch_rate * delta)
			
		# Yaw: World UP (intuitive stickless steering)
		if abs(turn_input) > 0.01:
			rotate_y(turn_input * turn_rate * delta)
			
		# Bank tilt on visual model
		var target_roll = -turn_input * 0.75
		var target_pitch_tilt = -pitch_input * 0.25
		visual_model.rotation.z = lerpf(visual_model.rotation.z, target_roll, delta * 8.0)
		visual_model.rotation.x = lerpf(visual_model.rotation.x, target_pitch_tilt, delta * 8.0)
		
	# Move forward in facing direction
	var forward = -global_transform.basis.z.normalized()
	velocity = forward * current_speed
	move_and_slide()
	
	# Space boundary tether
	if global_position.length() > 420.0:
		var dir_to_center = -global_position.normalized()
		var target_trans = global_transform.looking_at(global_position + dir_to_center, Vector3.UP)
		global_transform = global_transform.interpolate_with(target_trans, 2.5 * delta)

func _process_weapons(delta: float) -> void:
	if blaster_cooldown > 0.0:
		blaster_cooldown -= delta
	if missile_cooldown > 0.0:
		missile_cooldown -= delta
		
	# RB Button / Key F: Twin Plasma Blaster
	var shoot_pressed = Input.is_action_pressed("shoot") or Input.is_joy_button_pressed(0, JOY_BUTTON_RIGHT_SHOULDER) or Input.is_key_pressed(KEY_F)
	if shoot_pressed and blaster_cooldown <= 0.0:
		blaster_cooldown = 0.14
		_fire_twin_blasters()
		
	# A Button / Key E: Homing Missile
	var missile_pressed = Input.is_action_just_pressed("interact") or Input.is_joy_button_pressed(0, JOY_BUTTON_A) or Input.is_key_pressed(KEY_E)
	if missile_pressed and missile_cooldown <= 0.0:
		missile_cooldown = 1.6
		_fire_missile()

func _fire_twin_blasters() -> void:
	var shoot_dir = -global_transform.basis.z.normalized()
	
	if left_muzzle:
		var l1 = LaserScene.instantiate()
		l1.global_position = left_muzzle.global_position
		l1.direction = shoot_dir
		get_tree().current_scene.add_child(l1)
		
	if right_muzzle:
		var l2 = LaserScene.instantiate()
		l2.global_position = right_muzzle.global_position
		l2.direction = shoot_dir
		get_tree().current_scene.add_child(l2)
		
	var sm = SoundManagerScript.get_instance()
	if sm:
		sm.play_plasma()
		
	weapon_fired.emit("blaster")

func _fire_missile() -> void:
	var missile = MissileScene.instantiate()
	missile.global_position = missile_hardpoint.global_position if missile_hardpoint else global_position
	missile.global_transform.basis = global_transform.basis
	if is_instance_valid(locked_target):
		missile.target = locked_target
		
	get_tree().current_scene.add_child(missile)
	
	var sm = SoundManagerScript.get_instance()
	if sm:
		sm.play_missile_launch()
		
	weapon_fired.emit("missile")

func _process_lockon(delta: float) -> void:
	# Find closest enemy within forward cone
	var forward = -global_transform.basis.z.normalized()
	var enemies = get_tree().get_nodes_in_group("enemy")
	var best_candidate: Node3D = null
	var best_score: float = 999999.0
	
	for e in enemies:
		if not is_instance_valid(e) or e == self:
			continue
		var to_e = e.global_position - global_position
		var dist = to_e.length()
		if dist > 260.0 or dist < 2.0:
			continue
		var angle = forward.angle_to(to_e.normalized())
		if angle < deg_to_rad(32.0):
			# Lower score is better (weighted by angle and distance)
			var score = dist * (1.0 + angle * 2.0)
			if score < best_score:
				best_score = score
				best_candidate = e
				
	if best_candidate != null and best_candidate == target_candidate:
		lock_timer += delta
		if lock_timer >= LOCK_TIME_REQUIRED and locked_target != best_candidate:
			locked_target = best_candidate
			var sm = SoundManagerScript.get_instance()
			if sm:
				sm.play_lockon()
	else:
		target_candidate = best_candidate
		lock_timer = 0.0
		if not is_instance_valid(locked_target) or (locked_target != null and forward.angle_to((locked_target.global_position - global_position).normalized()) > deg_to_rad(45.0)):
			locked_target = null

func _update_camera(delta: float) -> void:
	# Smoothly lag chase camera behind fighter
	if not is_cockpit_view and chase_mount:
		chase_mount.global_position = chase_mount.global_position.lerp(global_position, delta * 12.0)
		chase_mount.global_rotation.y = lerp_angle(chase_mount.global_rotation.y, global_rotation.y, delta * 10.0)
		chase_mount.global_rotation.x = lerp_angle(chase_mount.global_rotation.x, global_rotation.x, delta * 10.0)
		chase_mount.global_rotation.z = lerp_angle(chase_mount.global_rotation.z, global_rotation.z, delta * 10.0)
		
		# Dynamic FOV for boost sensation
		var target_fov = 82.0 if is_boosting else (64.0 if is_braking else 70.0)
		chase_camera.fov = lerpf(chase_camera.fov, target_fov, delta * 6.0)
	elif is_cockpit_view and cockpit_camera:
		var target_fov = 85.0 if is_boosting else (66.0 if is_braking else 74.0)
		cockpit_camera.fov = lerpf(cockpit_camera.fov, target_fov, delta * 6.0)
