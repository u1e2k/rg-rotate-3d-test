class_name DungeonPlayer
extends CharacterBody3D

## Dungeon Warrior Player for RG Rotate (720x720)
## Features: D-pad tank/strafe, X Z-Targeting Lock-on, B Step Dodge with i-frames, RB 3-hit slash

signal health_changed(current_hp: float, max_hp: float)
signal lock_on_toggled(is_locked: bool, target_node: Node3D)
signal player_defeated()

@export var max_health: float = 100.0
var current_health: float = 100.0

@export var move_speed: float = 6.2
@export var sprint_speed: float = 9.5
@export var turn_speed: float = 3.2
@export var dodge_speed: float = 15.0

# Combat & Dodge State
var is_dodging: bool = false
var dodge_timer: float = 0.0
var dodge_direction: Vector3 = Vector3.ZERO
var is_invulnerable: bool = false
var combo_step: int = 0
var combo_timer: float = 0.0
var attack_cooldown: float = 0.0

# Z-Targeting Lock-on
var is_locked_on: bool = false
var lock_target: Node3D = null

# Camera & Mount
@onready var camera_mount: Node3D = $CameraMount
@onready var camera: Camera3D = $CameraMount/SpringArm3D/Camera3D
@onready var sword_mesh: MeshInstance3D = $Model/Torso/Sword
@onready var model_root: Node3D = $Model

var sound_manager: Node = null

func _ready() -> void:
	current_health = max_health
	camera_mount.top_level = true
	var stage = get_parent()
	if stage and stage.has_node("SoundManager"):
		sound_manager = stage.get_node("SoundManager")

func set_lock_target(boss_node: Node3D) -> void:
	lock_target = boss_node

func _input(event: InputEvent) -> void:
	# X button (or C key): Toggle Lock-on
	if event.is_action_pressed("camera_toggle") or (event is InputEventJoypadButton and event.button_index == JOY_BUTTON_X and event.pressed):
		_toggle_lock_on()

func _toggle_lock_on() -> void:
	if not lock_target:
		return
	is_locked_on = !is_locked_on
	if is_locked_on and sound_manager and sound_manager.has_method("play_lockon"):
		sound_manager.play_lockon()
	lock_on_toggled.emit(is_locked_on, lock_target)

func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	else:
		velocity.y = 0.0

	# Dodge timer
	if is_dodging:
		dodge_timer -= delta
		velocity.x = dodge_direction.x * dodge_speed
		velocity.z = dodge_direction.z * dodge_speed
		if dodge_timer <= 0.0:
			is_dodging = false
			is_invulnerable = false
		move_and_slide()
		_update_camera(delta)
		return

	# Attack Combo Timers
	if combo_timer > 0.0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			combo_step = 0
	if attack_cooldown > 0.0:
		attack_cooldown -= delta

	# Read Input
	var is_sprint = Input.is_action_pressed("sprint") or Input.is_joy_button_pressed(0, JOY_BUTTON_Y)
	var speed = sprint_speed if is_sprint else move_speed

	# Action: Dodge Roll / Step (B button / Space)
	if Input.is_action_just_pressed("jump") or Input.is_joy_button_pressed(0, JOY_BUTTON_B):
		_perform_dodge()
		move_and_slide()
		_update_camera(delta)
		return

	# Action: Attack Slash (RB button / F key)
	if Input.is_action_just_pressed("shoot") or Input.is_joy_button_pressed(0, JOY_BUTTON_RIGHT_SHOULDER):
		_perform_attack()

	# Movement & Turning
	var input_forward = 0.0
	var input_strafe = 0.0

	if Input.is_action_pressed("move_forward") or Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_UP):
		input_forward += 1.0
	if Input.is_action_pressed("move_backward") or Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_DOWN):
		input_forward -= 1.0
	if Input.is_action_pressed("turn_left") or Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_LEFT):
		input_strafe -= 1.0
	if Input.is_action_pressed("turn_right") or Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_RIGHT):
		input_strafe += 1.0

	if is_locked_on and lock_target and is_instance_valid(lock_target):
		# Z-Targeting Mode: Face Boss, Strafe left/right, move toward/away
		var to_boss = (lock_target.global_position - global_position).normalized()
		to_boss.y = 0.0
		var right_dir = to_boss.cross(Vector3.UP).normalized()
		
		# Auto-face target smoothly
		var target_rot = atan2(-to_boss.x, -to_boss.z)
		rotation.y = lerp_angle(rotation.y, target_rot, delta * 8.0)

		var move_dir = (to_boss * input_forward + right_dir * -input_strafe).normalized()
		velocity.x = move_dir.x * speed
		velocity.z = move_dir.z * speed
	else:
		# Free 3D D-pad Tank Mode: Turn with left/right, forward/back
		rotation.y -= input_strafe * turn_speed * delta
		var forward = -transform.basis.z
		velocity.x = forward.x * input_forward * speed
		velocity.z = forward.z * input_forward * speed

	move_and_slide()
	_animate_body(delta, input_forward != 0.0 or input_strafe != 0.0)
	_update_camera(delta)

func _perform_dodge() -> void:
	is_dodging = true
	is_invulnerable = true
	dodge_timer = 0.35
	
	# Direction of dodge
	var forward = -transform.basis.z
	var right = transform.basis.x
	
	var dir = Vector3.ZERO
	if Input.is_action_pressed("move_forward") or Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_UP):
		dir += forward
	if Input.is_action_pressed("move_backward") or Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_DOWN):
		dir -= forward
	if Input.is_action_pressed("turn_left") or Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_LEFT):
		dir -= right
	if Input.is_action_pressed("turn_right") or Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_RIGHT):
		dir += right
		
	if dir.length_squared() < 0.01:
		dir = forward # Default forward dive
		
	dodge_direction = dir.normalized()
	
	if sound_manager and sound_manager.has_method("play_hit"):
		sound_manager.play_hit()

func _perform_attack() -> void:
	if attack_cooldown > 0.0:
		return
		
	attack_cooldown = 0.28
	combo_step = (combo_step % 3) + 1
	combo_timer = 0.8
	
	if sound_manager and sound_manager.has_method("play_shoot"):
		sound_manager.play_shoot()

	# Sword swing tween
	if sword_mesh:
		var slash_tween = create_tween()
		var start_rot = -1.2 if combo_step == 1 else (1.2 if combo_step == 2 else -2.2)
		var end_rot = 1.4 if combo_step == 1 else (-1.4 if combo_step == 2 else 1.8)
		sword_mesh.rotation.y = start_rot
		slash_tween.tween_property(sword_mesh, "rotation:y", end_rot, 0.16)

	# Hit detection forward cone
	var forward = -transform.basis.z
	if lock_target and is_instance_valid(lock_target):
		var dist = global_position.distance_to(lock_target.global_position)
		if dist < 4.2:
			var to_target = (lock_target.global_position - global_position).normalized()
			if forward.dot(to_target) > 0.4:
				# Critical if locked onto exposed core
				var is_crit = (lock_target is GolemBoss and (lock_target as GolemBoss).current_state == GolemBoss.State.STAGGER)
				lock_target.take_damage(20.0, is_crit)
				if sound_manager and sound_manager.has_method("play_crystal"):
					sound_manager.play_crystal()

func take_damage(amount: float, knockback: Vector3 = Vector3.ZERO) -> void:
	if is_invulnerable:
		return
		
	current_health = max(0.0, current_health - amount)
	health_changed.emit(current_health, max_health)
	
	if knockback.length_squared() > 0.1:
		velocity += knockback

	if sound_manager and sound_manager.has_method("play_hit"):
		sound_manager.play_hit()

	if current_health <= 0.0:
		player_defeated.emit()

func _update_camera(delta: float) -> void:
	if not camera_mount:
		return

	if is_locked_on and lock_target and is_instance_valid(lock_target):
		# Position between player and boss, focused slightly behind player
		var midpoint = (global_position + lock_target.global_position) * 0.5
		var to_boss = (lock_target.global_position - global_position).normalized()
		var cam_target_pos = global_position - to_boss * 4.2 + Vector3(0, 1.8, 0)
		camera_mount.global_position = camera_mount.global_position.lerp(cam_target_pos, delta * 7.0)
		
		# Look at midpoint
		var target_look = atan2(to_boss.x, to_boss.z)
		camera_mount.rotation.y = lerp_angle(camera_mount.rotation.y, target_look, delta * 7.0)
		camera_mount.rotation.x = -0.22
	else:
		# Standard Third Person Smoothed Follow
		var target_pos = global_position + Vector3(0, 1.2, 0)
		camera_mount.global_position = camera_mount.global_position.lerp(target_pos, delta * 8.0)
		camera_mount.rotation.y = lerp_angle(camera_mount.rotation.y, rotation.y, delta * 6.0)
		camera_mount.rotation.x = -0.26

func _animate_body(delta: float, is_moving: bool) -> void:
	if not model_root:
		return
	if is_moving:
		var t = Time.get_ticks_msec() * 0.012
		model_root.position.y = abs(sin(t)) * 0.1
	else:
		model_root.position.y = lerp(model_root.position.y, 0.0, delta * 10.0)
