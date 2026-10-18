class_name MovingPlatform
extends AnimatableBody3D

@export var move_offset: Vector3 = Vector3(0, 0, 5)
@export var speed: float = 1.2
@export var wait_time: float = 0.5

var start_pos: Vector3
var target_pos: Vector3
var time_passed: float = 0.0

func _ready() -> void:
	start_pos = global_position
	target_pos = start_pos + move_offset

func _physics_process(delta: float) -> void:
	time_passed += delta * speed
	# Ping-pong movement between 0 and 1 with smooth sine curve
	var progress = (sin(time_passed - PI * 0.5) + 1.0) * 0.5
	global_position = start_pos.lerp(target_pos, progress)
