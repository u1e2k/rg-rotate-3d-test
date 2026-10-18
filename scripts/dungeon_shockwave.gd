class_name DungeonShockwave
extends Area3D

## Expanding Shockwave Ring from Golem Boss Ground Slam
## Tests jumping / dodge rolling over expanding hazards at 60 FPS

@export var expand_speed: float = 12.0
@export var max_radius: float = 24.0
@export var damage: float = 20.0

var current_radius: float = 1.0
var mesh_instance: MeshInstance3D
var ring_mat: StandardMaterial3D
var hit_player: bool = false

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 # Player layer
	
	# Create Torus ring mesh
	mesh_instance = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = 0.8
	torus.outer_radius = 1.1
	torus.rings = 24
	torus.ring_segments = 8
	mesh_instance.mesh = torus
	
	ring_mat = StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.albedo_color = Color(1.0, 0.45, 0.1, 0.9)
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_instance.material_override = ring_mat
	add_child(mesh_instance)
	
	# Cylinder collision shape
	var col = CollisionShape3D.new()
	var cyl = CylinderShape3D.new()
	cyl.radius = 1.0
	cyl.height = 0.5
	col.shape = cyl
	add_child(col)
	
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	current_radius += expand_speed * delta
	
	# Scale mesh and collision horizontally
	mesh_instance.scale = Vector3(current_radius, 1.0, current_radius)
	var col = get_child(1) as CollisionShape3D
	if col and col.shape is CylinderShape3D:
		(col.shape as CylinderShape3D).radius = current_radius
		
	# Fade out towards max radius
	var alpha = clamp(1.0 - (current_radius / max_radius), 0.0, 1.0)
	ring_mat.albedo_color.a = alpha * 0.85
	
	if current_radius >= max_radius:
		queue_free()

func _on_body_entered(body: Node3D) -> void:
	if hit_player:
		return
	if body.has_method("take_damage"):
		var push_dir = (body.global_position - global_position).normalized()
		push_dir.y = 0.5
		body.take_damage(damage, push_dir * 8.0)
		hit_player = true
