class_name SpaceLaser
extends Area3D

const SoundManagerScript = preload("res://scripts/sound_manager.gd")

@export var speed: float = 120.0
@export var damage: float = 1.0
@export var lifetime: float = 2.0
@export var is_enemy_fire: bool = false

var direction: Vector3 = Vector3.FORWARD
var time_alive: float = 0.0
var has_hit: bool = false

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	
	# Rotate mesh to point in direction
	if direction.length_squared() > 0.001:
		look_at(global_position + direction, Vector3.UP)

func _physics_process(delta: float) -> void:
	if has_hit:
		return
		
	time_alive += delta
	if time_alive >= lifetime:
		queue_free()
		return
		
	global_position += direction * speed * delta

func _on_body_entered(body: Node3D) -> void:
	_handle_hit(body)

func _on_area_entered(area: Area3D) -> void:
	_handle_hit(area)

func _handle_hit(target: Node) -> void:
	if has_hit:
		return
		
	# Ignore shooting self / same team
	if is_enemy_fire and (target.name.begins_with("Enemy") or target.is_in_group("enemy")):
		return
	if not is_enemy_fire and (target.name == "Player" or target.name == "SpaceFighter" or target.is_in_group("player")):
		return
		
	has_hit = true
	
	if target.has_method("take_damage"):
		target.take_damage(damage)
	elif target.get_parent() and target.get_parent().has_method("take_damage"):
		target.get_parent().take_damage(damage)
		
	var sm = SoundManagerScript.get_instance()
	if sm:
		sm.play_hit()
		
	# Quick flash and burst animation
	if mesh_instance:
		var tween = create_tween().set_parallel(true)
		tween.tween_property(mesh_instance, "scale", Vector3(2.5, 2.5, 2.5), 0.08)
	
	var fade_tween = create_tween()
	fade_tween.tween_interval(0.06)
	fade_tween.tween_callback(queue_free)
