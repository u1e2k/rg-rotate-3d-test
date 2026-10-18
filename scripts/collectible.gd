class_name Collectible
extends Area3D

signal collected

const SoundManagerScript = preload("res://scripts/sound_manager.gd")

var base_y: float = 0.0
var time_offset: float = 0.0
var is_collected: bool = false

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var light: OmniLight3D = $OmniLight3D

func _ready() -> void:
	base_y = position.y
	time_offset = randf() * TAU
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	if is_collected:
		return
	var t = Time.get_ticks_msec() / 1000.0 + time_offset
	# Bobbing and rotation
	mesh.rotation.y += delta * 2.2
	mesh.rotation.x = sin(t * 1.5) * 0.15
	position.y = base_y + sin(t * 3.0) * 0.2

func _on_body_entered(body: Node3D) -> void:
	if is_collected or not body.has_method("start_quick_turn"):
		return
	is_collected = true
	collected.emit()
	
	var sm = SoundManagerScript.get_instance()
	if sm:
		sm.play_coin()
	
	# Pop effect
	var tween = create_tween().set_parallel(true)
	tween.tween_property(mesh, "scale", Vector3(1.8, 1.8, 1.8), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(mesh, "position:y", 0.5, 0.2)
	tween.tween_property(light, "light_energy", 3.0, 0.2)
	
	var fade_tween = create_tween()
	fade_tween.tween_interval(0.18)
	fade_tween.tween_property(mesh, "scale", Vector3.ZERO, 0.15)
	fade_tween.tween_callback(queue_free)
