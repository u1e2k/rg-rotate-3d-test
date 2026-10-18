class_name Airplane
extends CharacterBody3D

signal board_state_changed(is_boarded: bool)

const SoundManagerScript = preload("res://scripts/sound_manager.gd")
const BulletScene = preload("res://scenes/bullet.tscn")

@export var cruise_speed: float = 14.0
@export var boost_speed: float = 24.0
@export var brake_speed: float = 6.0
@export var turn_rate: float = 1.9
@export var pitch_rate: float = 1.6

# Node references
@onready var visual_model: Node3D = $VisualModel
@onready var propeller: Node3D = $VisualModel/NoseCone/Propeller
@onready var camera_mount: Node3D = $CameraMount
@onready var camera: Camera3D = $CameraMount/SpringArm3D/Camera3D
@onready var left_muzzle: Marker3D = $VisualModel/MainWing/LeftGun/LeftMuzzle
@onready var right_muzzle: Marker3D = $VisualModel/MainWing/RightGun/RightMuzzle
@onready var interact_area: Area3D = $InteractArea
@onready var prompt_label: Label3D = $PromptLabel
@onready var engine_light: OmniLight3D = $VisualModel/EngineLight

var is_boarded: bool = false
var passenger: Player = null
var current_speed: float = 0.0
var shoot_cooldown: float = 0.0
var board_cooldown: float = 0.0
var prop_rot_speed: float = 10.0
var initial_spawn_transform: Transform3D

func _ready() -> void:
	initial_spawn_transform = global_transform
	camera.current = false
	prompt_label.visible = true
	prompt_label.text = "✈️ 飛行機\n[A] 搭乗する"
	
	if interact_area:
		interact_area.body_entered.connect(_on_interact_area_body_entered)
		interact_area.body_exited.connect(_on_interact_area_body_exited)

func _on_interact_area_body_entered(body: Node3D) -> void:
	if not is_boarded and body is Player:
		passenger = body
		prompt_label.visible = true

func _on_interact_area_body_exited(body: Node3D) -> void:
	if not is_boarded and body == passenger:
		passenger = null
		prompt_label.visible = false

func _physics_process(delta: float) -> void:
	if board_cooldown > 0.0:
		board_cooldown -= delta

	if not is_boarded:
		# Idle resting on ground
		prop_rot_speed = lerpf(prop_rot_speed, 4.0, delta * 3.0)
		propeller.rotation.z += prop_rot_speed * delta
		return

	# --- BOARDED FLIGHT LOGIC ---
	_process_flight(delta)
	_process_weapons(delta)
	
	# Dismount check
	if board_cooldown <= 0.0 and Input.is_action_just_pressed("interact"):
		dismount_player()

func _process_flight(delta: float) -> void:
	# Speed input: Y = boost, B = brake
	var target_speed = cruise_speed
	var is_boosting = Input.is_action_pressed("sprint")
	var is_braking = Input.is_action_pressed("jump")
	
	if is_boosting:
		target_speed = boost_speed
		prop_rot_speed = 45.0
		engine_light.light_energy = 2.5
	elif is_braking:
		target_speed = brake_speed
		prop_rot_speed = 15.0
		engine_light.light_energy = 0.5
	else:
		target_speed = cruise_speed
		prop_rot_speed = 28.0
		engine_light.light_energy = 1.2
		
	current_speed = lerpf(current_speed, target_speed, delta * 3.5)
	propeller.rotation.z += prop_rot_speed * delta
	
	# Pitch input (▲ = Dive / nose down, ▼ = Climb / nose up)
	var pitch_input = Input.get_action_strength("move_backward") - Input.get_action_strength("move_forward")
	
	# Yaw / Roll input (◀ = turn left, ▶ = turn right)
	var turn_input = Input.get_action_strength("turn_left") - Input.get_action_strength("turn_right")
	
	# Apply 3D rotation
	# 1. Pitch on local X axis
	if abs(pitch_input) > 0.01:
		rotate_object_local(Vector3.RIGHT, pitch_input * pitch_rate * delta)
		
	# 2. Yaw on world UP axis (keeps flight intuitive without disorienting roll lock)
	if abs(turn_input) > 0.01:
		rotate_y(turn_input * turn_rate * delta)
		
	# 3. Visual Banking Tilt (Roll on local Z)
	var target_bank_z = -turn_input * 0.65
	var target_bank_x = -pitch_input * 0.25
	visual_model.rotation.z = lerpf(visual_model.rotation.z, target_bank_z, delta * 8.0)
	visual_model.rotation.x = lerpf(visual_model.rotation.x, target_bank_x, delta * 8.0)
	
	# Forward velocity in look direction
	var forward_dir = -transform.basis.z.normalized()
	velocity = forward_dir * current_speed
	
	# Ground & Altitude boundaries
	move_and_slide()
	
	# Minimum altitude cushion (prevent sinking through floor)
	if global_position.y < 0.65:
		global_position.y = 0.65
		if velocity.y < 0:
			velocity.y = 0
		# Level out pitch when rolling on the ground
		rotation.x = lerp_angle(rotation.x, 0.0, delta * 6.0)
		rotation.z = lerp_angle(rotation.z, 0.0, delta * 6.0)
		
	# Ceiling cushion
	if global_position.y > 38.0:
		global_position.y = 38.0
		if velocity.y > 0:
			velocity.y = 0
			
	# Horizontal arena bounds
	global_position.x = clampf(global_position.x, -50.0, 50.0)
	global_position.z = clampf(global_position.z, -50.0, 50.0)

func _process_weapons(delta: float) -> void:
	if shoot_cooldown > 0.0:
		shoot_cooldown -= delta
		
	if Input.is_action_just_pressed("shoot") and shoot_cooldown <= 0.0:
		shoot_cooldown = 0.16
		_fire_twin_cannons()

func _fire_twin_cannons() -> void:
	var shoot_dir = -transform.basis.z.normalized()
	
	# Left Cannon
	var bullet_l = BulletScene.instantiate()
	bullet_l.global_position = left_muzzle.global_position
	bullet_l.direction = shoot_dir
	get_tree().current_scene.add_child(bullet_l)
	
	# Right Cannon
	var bullet_r = BulletScene.instantiate()
	bullet_r.global_position = right_muzzle.global_position
	bullet_r.direction = shoot_dir
	get_tree().current_scene.add_child(bullet_r)
	
	var sm = SoundManagerScript.get_instance()
	if sm:
		sm.play_shoot()
		
	# Muzzle flash pulse
	var muzzle_tween = create_tween()
	muzzle_tween.tween_property(engine_light, "light_energy", 3.5, 0.04)
	muzzle_tween.tween_property(engine_light, "light_energy", 1.2, 0.1)

func mount_player(p: Player) -> void:
	passenger = p
	is_boarded = true
	board_cooldown = 0.4
	prompt_label.visible = false
	
	# Disable and hide player
	passenger.visible = false
	passenger.process_mode = Node.PROCESS_MODE_DISABLED
	passenger.global_position = global_position
	
	# Switch to Airplane Camera
	camera.current = true
	current_speed = cruise_speed * 0.6
	
	var sm = SoundManagerScript.get_instance()
	if sm:
		sm.play_engine_rev()
		
	emit_signal("board_state_changed", true)

func dismount_player() -> void:
	if not passenger:
		return
		
	is_boarded = false
	board_cooldown = 0.4
	
	# Place player safely next to airplane
	var exit_pos = global_position + transform.basis.x * 2.0
	exit_pos.y = maxf(exit_pos.y, 0.2)
	passenger.global_position = exit_pos
	passenger.velocity = Vector3.ZERO
	passenger.visible = true
	passenger.process_mode = Node.PROCESS_MODE_INHERIT
	
	# Switch camera back to player
	if passenger.has_node("CameraMount/SpringArm3D/Camera3D"):
		var player_cam = passenger.get_node("CameraMount/SpringArm3D/Camera3D") as Camera3D
		player_cam.current = true
		
	if passenger.has_method("suppress_input"):
		passenger.suppress_input(0.35)
		
	# If dismounting high in air, gently land plane on runway
	if global_position.y > 4.0:
		var land_tween = create_tween()
		var target_land = initial_spawn_transform.origin
		land_tween.tween_property(self, "global_position", target_land, 1.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		land_tween.tween_property(self, "rotation", Vector3.ZERO, 1.5)
	
	var sm = SoundManagerScript.get_instance()
	if sm:
		sm.play_land()
		
	emit_signal("board_state_changed", false)
