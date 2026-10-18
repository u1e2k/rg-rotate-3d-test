class_name MusouPlayer
extends CharacterBody3D

## Musou-style Player Controller optimized for ANBERNIC RG Rotate
## Supports 3-hit combo, 360 Whirlwind Special, D-pad tank turning, and visual slash arcs.

signal attack_performed(combo_step: int, hits: int)
signal special_performed(hits: int)

@export var move_speed: float = 6.0
@export var sprint_speed: float = 9.5
@export var turn_speed: float = 3.6
@export var jump_velocity: float = 7.5
@export var gravity: float = 19.6

@onready var visual_mesh: Node3D = $Visual
@onready var slash_effect: Node3D = $Visual/SlashEffect
@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D
@onready var weapon_mesh: Node3D = $Visual/Weapon

const MusouHordeScript = preload("res://scripts/musou_horde.gd")

var combo_step: int = 0
var combo_reset_timer: float = 0.0
var attack_cooldown: float = 0.0
var is_attacking: bool = false
var slash_anim_timer: float = 0.0

var horde_ref: Node3D = null

func _ready() -> void:
	if slash_effect:
		slash_effect.visible = false

func set_horde(horde: Node3D) -> void:
	horde_ref = horde

func _physics_process(delta: float) -> void:
	if combo_reset_timer > 0.0:
		combo_reset_timer -= delta
		if combo_reset_timer <= 0.0:
			combo_step = 0
			
	if attack_cooldown > 0.0:
		attack_cooldown -= delta
		
	if slash_anim_timer > 0.0:
		slash_anim_timer -= delta
		if slash_anim_timer <= 0.0 and slash_effect:
			slash_effect.visible = false
			is_attacking = false
			
	# Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
		
	# D-pad Tank Turning
	var turn_input = 0.0
	if Input.is_action_pressed("turn_left") or Input.is_action_pressed("ui_left"):
		turn_input += 1.0
	if Input.is_action_pressed("turn_right") or Input.is_action_pressed("ui_right"):
		turn_input -= 1.0
	rotate_y(turn_input * turn_speed * delta)
	
	# Movement
	var forward_input = 0.0
	if Input.is_action_pressed("move_forward") or Input.is_action_pressed("ui_up"):
		forward_input += 1.0
	if Input.is_action_pressed("move_backward") or Input.is_action_pressed("ui_down"):
		forward_input -= 0.65
		
	var is_sprinting = Input.is_action_pressed("sprint") or Input.is_joy_button_pressed(0, JOY_BUTTON_Y)
	var speed = sprint_speed if is_sprinting else move_speed
	
	# If attacking, slow down slightly for weapon momentum
	if is_attacking:
		speed *= 0.5
		
	var forward_dir = -global_transform.basis.z
	var target_vel = forward_dir * forward_input * speed
	velocity.x = target_vel.x
	velocity.z = target_vel.z
	
	# Jump
	var jump_pressed = Input.is_action_just_pressed("jump") or Input.is_joy_button_pressed(0, JOY_BUTTON_B)
	if jump_pressed and is_on_floor() and not is_attacking:
		velocity.y = jump_velocity
		var sm = SoundManager.get_instance()
		if sm:
			sm.play_jump()
			
	move_and_slide()
	
	# Smooth Camera Follow
	if camera_pivot:
		camera_pivot.global_position = camera_pivot.global_position.lerp(global_position + Vector3(0, 1.4, 0), delta * 8.0)
		camera_pivot.rotation.y = lerp_angle(camera_pivot.rotation.y, rotation.y, delta * 5.0)

func _input(event: InputEvent) -> void:
	# RB Button / F Key = Regular Combo Attack
	var is_rb = event.is_action_pressed("shoot") or (event is InputEventJoypadButton and event.button_index == JOY_BUTTON_RIGHT_SHOULDER and event.pressed)
	if is_rb:
		get_viewport().set_input_as_handled()
		_perform_combo_attack()
		return
		
	# A Button / E Key = 360 Whirlwind Special
	var is_a = event.is_action_pressed("interact") or (event is InputEventJoypadButton and event.button_index == JOY_BUTTON_A and event.pressed)
	if is_a:
		get_viewport().set_input_as_handled()
		_perform_whirlwind_special()
		return
		
	# LB Button / Q Key = Toggle Horde Count Tier
	var is_lb = event.is_action_pressed("quick_turn") or (event is InputEventJoypadButton and event.button_index == JOY_BUTTON_LEFT_SHOULDER and event.pressed)
	if is_lb:
		get_viewport().set_input_as_handled()
		if horde_ref:
			horde_ref.cycle_enemy_tier()
			var sm = SoundManager.get_instance()
			if sm and sm.has_method("play_cursor"):
				sm.play_cursor()
		return

func _perform_combo_attack() -> void:
	if attack_cooldown > 0.0 or not horde_ref:
		return
		
	combo_step = (combo_step % 3) + 1
	combo_reset_timer = 1.2
	attack_cooldown = 0.22
	is_attacking = true
	slash_anim_timer = 0.18
	
	var forward_dir = -global_transform.basis.z
	var radius = 3.6 + combo_step * 0.4
	var arc_deg = 130.0 if combo_step < 3 else 90.0
	var power = 10.0 + combo_step * 3.5
	
	# Visual Slash Effect
	if slash_effect:
		slash_effect.visible = true
		slash_effect.scale = Vector3(1.0 + combo_step * 0.2, 1.0, 1.0 + combo_step * 0.2)
		slash_effect.rotation.y = randf_range(-0.3, 0.3)
		
	var hits = horde_ref.perform_sweep_attack(global_position, forward_dir, radius, arc_deg, power)
	
	var sm = SoundManager.get_instance()
	if sm:
		sm.play_shoot() # Sword whoosh
		if hits > 0:
			sm.play_hit()
			
	attack_performed.emit(combo_step, hits)

func _perform_whirlwind_special() -> void:
	if attack_cooldown > 0.0 or not horde_ref:
		return
		
	attack_cooldown = 0.45
	is_attacking = true
	slash_anim_timer = 0.35
	
	# Massive 360 degree spin
	if slash_effect:
		slash_effect.visible = true
		slash_effect.scale = Vector3(2.2, 1.0, 2.2)
		
	var hits = horde_ref.perform_sweep_attack(global_position, Vector3.FORWARD, 6.2, 360.0, 18.0)
	
	var sm = SoundManager.get_instance()
	if sm:
		sm.play_explode()
		
	special_performed.emit(hits)
