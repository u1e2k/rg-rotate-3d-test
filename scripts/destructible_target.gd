class_name DestructibleTarget
extends StaticBody3D

const SoundManagerScript = preload("res://scripts/sound_manager.gd")

@export var max_health: int = 3
var current_health: int = 3
var is_destroyed: bool = false

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

func _ready() -> void:
	current_health = max_health

func take_damage(amount: int = 1) -> void:
	if is_destroyed:
		return
		
	current_health -= amount
	
	if current_health <= 0:
		destroy()
	else:
		# Hit flash and shake
		var tween = create_tween()
		tween.tween_property(mesh, "scale", Vector3(1.2, 0.8, 1.2), 0.06)
		tween.tween_property(mesh, "scale", Vector3.ONE, 0.1)

func destroy() -> void:
	is_destroyed = true
	collision_shape.disabled = true
	mesh.visible = false
	
	var sm = SoundManagerScript.get_instance()
	if sm:
		sm.play_explode()
		
	# Spawn debris fragments
	_spawn_debris()
	
	# Delay free
	var timer = get_tree().create_timer(1.8)
	timer.timeout.connect(queue_free)

func _spawn_debris() -> void:
	var fragment_mesh = BoxMesh.new()
	fragment_mesh.size = Vector3(0.3, 0.3, 0.3)
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.35, 0.2, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.4, 0.1, 1.0)
	mat.emission_energy_multiplier = 1.5
	fragment_mesh.material = mat
	
	for i in range(8):
		var debris = RigidBody3D.new()
		debris.mass = 1.0
		debris.collision_layer = 1
		debris.collision_mask = 1
		
		var mi = MeshInstance3D.new()
		mi.mesh = fragment_mesh
		debris.add_child(mi)
		
		var col = CollisionShape3D.new()
		var box_shape = BoxShape3D.new()
		box_shape.size = Vector3(0.3, 0.3, 0.3)
		col.shape = box_shape
		debris.add_child(col)
		
		get_tree().current_scene.add_child(debris)
		debris.global_position = global_position + Vector3(randf_range(-0.3, 0.3), randf_range(0.2, 0.8), randf_range(-0.3, 0.3))
		
		# Impulse blast
		var blast_dir = Vector3(randf_range(-1, 1), randf_range(0.5, 1.5), randf_range(-1, 1)).normalized()
		debris.apply_central_impulse(blast_dir * randf_range(6.0, 12.0))
		debris.apply_torque_impulse(Vector3(randf_range(-5, 5), randf_range(-5, 5), randf_range(-5, 5)))
		
		# Fade and free debris
		var fade_tween = create_tween()
		fade_tween.tween_interval(1.2)
		fade_tween.tween_property(mi, "scale", Vector3.ZERO, 0.3)
		fade_tween.tween_callback(debris.queue_free)
