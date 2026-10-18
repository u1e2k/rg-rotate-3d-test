class_name SpaceMissile
extends Area3D

const SoundManagerScript = preload("res://scripts/sound_manager.gd")

@export var initial_speed: float = 24.0
@export var max_speed: float = 85.0
@export var acceleration: float = 65.0
@export var turn_rate: float = 4.5
@export var damage: float = 5.0
@export var lifetime: float = 4.5

var target: Node3D = null
var current_speed: float = 0.0
var time_alive: float = 0.0
var has_exploded: bool = false
var velocity_dir: Vector3 = Vector3.FORWARD

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

func _ready() -> void:
	current_speed = initial_speed
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	velocity_dir = -global_transform.basis.z.normalized()

func _physics_process(delta: float) -> void:
	if has_exploded:
		return
		
	time_alive += delta
	if time_alive >= lifetime:
		_explode()
		return
		
	current_speed = minf(current_speed + acceleration * delta, max_speed)
	
	# Homing steering
	if is_instance_valid(target):
		var target_pos = target.global_position
		var to_target = (target_pos - global_position).normalized()
		# Smoothly rotate velocity_dir towards target
		velocity_dir = velocity_dir.slerp(to_target, turn_rate * delta).normalized()
		look_at(global_position + velocity_dir, Vector3.UP)
	
	global_position += velocity_dir * current_speed * delta

func _on_body_entered(body: Node3D) -> void:
	_handle_hit(body)

func _on_area_entered(area: Area3D) -> void:
	_handle_hit(area)

func _handle_hit(hit_node: Node) -> void:
	if has_exploded:
		return
	if hit_node.name == "Player" or hit_node.name == "SpaceFighter" or hit_node.is_in_group("player"):
		return
		
	has_exploded = true
	
	if hit_node.has_method("take_damage"):
		hit_node.take_damage(damage)
	elif hit_node.get_parent() and hit_node.get_parent().has_method("take_damage"):
		hit_node.get_parent().take_damage(damage)
		
	_explode()

func _explode() -> void:
	has_exploded = true
	var sm = SoundManagerScript.get_instance()
	if sm:
		sm.play_explode()
		
	if mesh_instance:
		var tw = create_tween().set_parallel(true)
		tw.tween_property(mesh_instance, "scale", Vector3(4.0, 4.0, 4.0), 0.12)
			
	var fade_tw = create_tween()
	fade_tw.tween_interval(0.12)
	fade_tw.tween_callback(queue_free)
