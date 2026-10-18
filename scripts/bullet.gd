class_name Bullet
extends Area3D

const SoundManagerScript = preload("res://scripts/sound_manager.gd")

@export var speed: float = 26.0
@export var damage: float = 10.0
@export var lifetime: float = 2.5

var direction: Vector3 = Vector3.FORWARD
var time_alive: float = 0.0
var has_hit: bool = false

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var light: OmniLight3D = $OmniLight3D

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	if has_hit:
		return
		
	time_alive += delta
	if time_alive >= lifetime:
		queue_free()
		return
		
	global_position += direction * speed * delta

func _on_body_entered(body: Node3D) -> void:
	if has_hit or body.name == "Player" or body is CharacterBody3D:
		return
	has_hit = true
	
	# Play hit sound
	var sm = SoundManagerScript.get_instance()
	if sm:
		sm.play_hit()
		
	# Apply physics impulse if hitting RigidBody3D (like the test boxes)
	if body is RigidBody3D:
		var impulse_dir = (direction + Vector3(0, 0.35, 0)).normalized()
		body.apply_central_impulse(impulse_dir * 22.0)
		
	# Damage destructible targets
	if body.has_method("take_damage"):
		body.take_damage(1)
		
	# Quick flash and burst animation
	var tween = create_tween().set_parallel(true)
	tween.tween_property(mesh, "scale", Vector3(2.5, 2.5, 2.5), 0.1)
	tween.tween_property(light, "light_energy", 4.0, 0.1)
	
	var fade_tween = create_tween()
	fade_tween.tween_interval(0.08)
	fade_tween.tween_property(mesh, "scale", Vector3.ZERO, 0.08)
	fade_tween.tween_callback(queue_free)
