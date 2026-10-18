class_name Player
extends CharacterBody3D

const SoundManagerScript = preload("res://scripts/sound_manager.gd")
const SettingsScript = preload("res://scripts/settings_manager.gd")
const BulletScene = preload("res://scenes/bullet.tscn")

@export var forward_speed: float = 6.0
@export var sprint_speed: float = 9.5
@export var backward_speed: float = 3.5
@export var turn_speed: float = 2.8
@export var jump_velocity: float = 8.5
@export var gravity: float = 22.0

@export var camera_follow_speed: float = 8.0
@export var camera_rotation_speed: float = 5.0

# Node references
@onready var camera_mount: Node3D = $CameraMount
@onready var spring_arm: SpringArm3D = $CameraMount/SpringArm3D
@onready var camera: Camera3D = $CameraMount/SpringArm3D/Camera3D
@onready var model: Node3D = $VisualModel
@onready var body_mesh: Node3D = $VisualModel/Body
@onready var head_mesh: Node3D = $VisualModel/Head
@onready var left_leg: Node3D = $VisualModel/LeftLeg
@onready var right_leg: Node3D = $VisualModel/RightLeg
@onready var left_arm: Node3D = $VisualModel/LeftArm
@onready var right_arm: Node3D = $VisualModel/RightArm
@onready var visor_light: OmniLight3D = $VisualModel/Head/VisorLight

# Internal states
var anim_time: float = 0.0
var step_timer: float = 0.0
var shoot_cooldown_timer: float = 0.0
var target_tilt_z: float = 0.0
var current_tilt_z: float = 0.0
var is_turning_180: bool = false
var quick_turn_progress: float = 0.0
var quick_turn_start_yaw: float = 0.0
var quick_turn_target_yaw: float = 0.0
var was_on_floor_last: bool = true
var spawn_position: Vector3 = Vector3(0, 1.5, 0)
var spawn_rotation: float = 0.0

func _ready() -> void:
	SettingsScript.load_settings()
	apply_settings()
	spawn_position = global_position
	spawn_rotation = rotation.y
	# Detach camera mount to allow smoothed third-person follow
	camera_mount.top_level = true
	camera_mount.global_position = global_position
	camera_mount.rotation.y = rotation.y

func apply_settings() -> void:
	turn_speed = SettingsScript.turn_sensitivity
	camera_rotation_speed = SettingsScript.camera_smoothing

func _physics_process(delta: float) -> void:
	# Fall reset check
	if global_position.y < -15.0:
		respawn()
		return

	# Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		if not was_on_floor_last and velocity.y <= 0:
			var sm = SoundManagerScript.get_instance()
			if sm:
				sm.play_land()
		was_on_floor_last = true

	# Manual reset key
	if Input.is_action_just_pressed("reset_pos"):
		respawn()
		return

	# Handle 180 quick turn
	if Input.is_action_just_pressed("quick_turn") and not is_turning_180:
		start_quick_turn()

	if is_turning_180:
		_process_quick_turn(delta)
	else:
		_process_rotation(delta)

	_process_movement(delta)
	_process_jump()
	_process_shoot(delta)
	
	move_and_slide()
	
	_update_camera(delta)
	_update_procedural_animation(delta)

func _process_shoot(delta: float) -> void:
	if shoot_cooldown_timer > 0.0:
		shoot_cooldown_timer -= delta
		
	if Input.is_action_just_pressed("shoot") and shoot_cooldown_timer <= 0.0:
		shoot_cooldown_timer = 0.2
		_fire_bullet()

func _fire_bullet() -> void:
	var bullet = BulletScene.instantiate()
	var spawn_pos = global_position + Vector3(0, 0.85, 0) - transform.basis.z * 0.7
	bullet.global_position = spawn_pos
	bullet.direction = -transform.basis.z.normalized()
	get_tree().current_scene.add_child(bullet)
	
	var sm = SoundManagerScript.get_instance()
	if sm:
		sm.play_shoot()
		
	# Recoil animation
	var recoil_tween = create_tween()
	recoil_tween.tween_property(model, "position:z", 0.08, 0.05)
	recoil_tween.tween_property(model, "position:z", 0.0, 0.1)
	
	# Visor flash
	if visor_light:
		var flash_tween = create_tween()
		flash_tween.tween_property(visor_light, "light_energy", 2.5, 0.04)
		flash_tween.tween_property(visor_light, "light_energy", 0.6, 0.12)

func _process_rotation(delta: float) -> void:
	var turn_left_val = Input.get_action_strength("turn_left")
	var turn_right_val = Input.get_action_strength("turn_right")
	var turn_input = turn_left_val - turn_right_val
	
	# Rotate player body on Y axis
	if abs(turn_input) > 0.01:
		rotation.y += turn_input * turn_speed * delta
		target_tilt_z = -turn_input * 0.12 # Bank tilt when turning
	else:
		target_tilt_z = 0.0
		
	current_tilt_z = lerpf(current_tilt_z, target_tilt_z, delta * 10.0)
	model.rotation.z = current_tilt_z

func start_quick_turn() -> void:
	is_turning_180 = true
	quick_turn_progress = 0.0
	quick_turn_start_yaw = rotation.y
	quick_turn_target_yaw = rotation.y + PI
	var sm = SoundManagerScript.get_instance()
	if sm:
		sm.play_jump()

func _process_quick_turn(delta: float) -> void:
	quick_turn_progress += delta * 5.0 # ~0.2 sec turn
	if quick_turn_progress >= 1.0:
		quick_turn_progress = 1.0
		is_turning_180 = false
	rotation.y = lerp_angle(quick_turn_start_yaw, quick_turn_target_yaw, quick_turn_progress)

func _process_movement(delta: float) -> void:
	var fwd = Input.get_action_strength("move_forward")
	var bwd = Input.get_action_strength("move_backward")
	var is_sprinting = Input.is_action_pressed("sprint")
	
	var forward_dir = -transform.basis.z.normalized()
	var speed = 0.0
	var move_vector = Vector3.ZERO
	
	if fwd > 0.05:
		speed = sprint_speed if is_sprinting else forward_speed
		speed *= fwd
		move_vector = forward_dir * speed
	elif bwd > 0.05:
		speed = backward_speed * bwd
		move_vector = -forward_dir * speed # Backward walking
	
	# Horizontal velocity interpolation for smooth acceleration/deceleration
	var accel = 14.0 if is_on_floor() else 5.0
	velocity.x = lerpf(velocity.x, move_vector.x, delta * accel)
	velocity.z = lerpf(velocity.z, move_vector.z, delta * accel)

func _process_jump() -> void:
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
		was_on_floor_last = false
		var sm = SoundManagerScript.get_instance()
		if sm:
			sm.play_jump()

func _update_camera(delta: float) -> void:
	# Smoothly interpolate camera mount position to player position
	var target_pos = global_position + Vector3(0, 1.2, 0)
	camera_mount.global_position = camera_mount.global_position.lerp(target_pos, delta * camera_follow_speed)
	
	# Smoothly interpolate camera mount yaw to match player's rotation
	var current_cam_yaw = camera_mount.rotation.y
	var target_cam_yaw = rotation.y
	camera_mount.rotation.y = lerp_angle(current_cam_yaw, target_cam_yaw, delta * camera_rotation_speed)

func _update_procedural_animation(delta: float) -> void:
	var horizontal_vel = Vector3(velocity.x, 0, velocity.z)
	var speed = horizontal_vel.length()
	var is_moving = speed > 0.2
	
	if is_moving and is_on_floor():
		anim_time += delta * speed * 2.2
		step_timer += delta * speed
		if step_timer > 3.2:
			step_timer = 0.0
			var sm = SoundManagerScript.get_instance()
			if sm:
				sm.play_step()
	else:
		anim_time += delta * 2.0
		step_timer = 0.0

	if is_on_floor():
		if is_moving:
			# Walking bob and stride
			var leg_swing = sin(anim_time) * 0.55
			var arm_swing = -sin(anim_time) * 0.45
			left_leg.rotation.x = leg_swing
			right_leg.rotation.x = -leg_swing
			left_arm.rotation.x = arm_swing
			right_arm.rotation.x = -arm_swing
			
			var bounce = abs(sin(anim_time * 2.0)) * 0.1
			body_mesh.position.y = 0.6 + bounce
			head_mesh.position.y = 1.25 + bounce * 0.5
			
			# Slight forward lean when moving
			var is_backward = velocity.dot(transform.basis.z) > 0.1
			var lean = -0.1 if is_backward else 0.15
			model.rotation.x = lerpf(model.rotation.x, lean, delta * 8.0)
		else:
			# Idle breathing
			var breath = sin(anim_time) * 0.03
			body_mesh.position.y = 0.6 + breath
			head_mesh.position.y = 1.25 + breath * 0.7
			left_leg.rotation.x = lerpf(left_leg.rotation.x, 0.0, delta * 10.0)
			right_leg.rotation.x = lerpf(right_leg.rotation.x, 0.0, delta * 10.0)
			left_arm.rotation.x = lerpf(left_arm.rotation.x, 0.0, delta * 10.0)
			right_arm.rotation.x = lerpf(right_arm.rotation.x, 0.0, delta * 10.0)
			model.rotation.x = lerpf(model.rotation.x, 0.0, delta * 8.0)
	else:
		# Jumping pose
		body_mesh.position.y = 0.65
		head_mesh.position.y = 1.3
		left_leg.rotation.x = lerpf(left_leg.rotation.x, -0.4, delta * 8.0)
		right_leg.rotation.x = lerpf(right_leg.rotation.x, 0.3, delta * 8.0)
		left_arm.rotation.x = lerpf(left_arm.rotation.x, -0.6, delta * 8.0)
		right_arm.rotation.x = lerpf(right_arm.rotation.x, -0.6, delta * 8.0)
		model.rotation.x = lerpf(model.rotation.x, -0.1, delta * 6.0)

func respawn() -> void:
	global_position = spawn_position
	velocity = Vector3.ZERO
	rotation.y = spawn_rotation
	camera_mount.global_position = global_position
	camera_mount.rotation.y = rotation.y
	var sm = SoundManagerScript.get_instance()
	if sm:
		sm.play_respawn()
