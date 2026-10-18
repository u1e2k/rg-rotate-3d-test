class_name GolemBoss
extends CharacterBody3D

## Ancient Stone Golem Boss for RG Rotate 3D Benchmark (720x720)
## Features: Telegraphed attacks, expanding shockwave ring, destructible core, state AI

signal health_changed(current_hp: float, max_hp: float)
signal boss_defeated()
signal attack_telegraphed(attack_name: String)

enum State {
	IDLE,
	WALK,
	TELEGRAPH_SLAM,
	SLAM,
	TELEGRAPH_SWIPE,
	SWIPE,
	ROCK_THROW,
	STAGGER,
	DEFEATED
}

@export var max_health: float = 300.0
var current_health: float = 300.0

var current_state: State = State.IDLE
var state_timer: float = 2.0
var target: Node3D = null

# Visual node references
var torso: MeshInstance3D
var head: MeshInstance3D
var eye_core: MeshInstance3D
var arm_left: Node3D
var arm_right: Node3D
var fist_left: MeshInstance3D
var fist_right: MeshInstance3D
var core_mat: StandardMaterial3D

# Attack mechanics
var slam_windup_time: float = 1.1
var shockwave_scene: PackedScene = null
var is_invulnerable: bool = false
var stagger_count: int = 0

func _ready() -> void:
	current_health = max_health
	_build_procedural_golem_model()
	
func set_target(player_node: Node3D) -> void:
	target = player_node

func _build_procedural_golem_model() -> void:
	# Rock material
	var rock_mat = StandardMaterial3D.new()
	rock_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	rock_mat.albedo_color = Color(0.42, 0.44, 0.46)
	rock_mat.roughness = 0.95
	
	var dark_rock_mat = StandardMaterial3D.new()
	dark_rock_mat.albedo_color = Color(0.28, 0.30, 0.32)
	dark_rock_mat.roughness = 0.9
	
	core_mat = StandardMaterial3D.new()
	core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	core_mat.albedo_color = Color(0.1, 0.8, 1.0)
	core_mat.emission_enabled = true
	core_mat.emission = Color(0.1, 0.8, 1.0)
	core_mat.emission_energy_multiplier = 3.5

	# Base Root Node for model
	var model_root = Node3D.new()
	model_root.name = "Model"
	add_child(model_root)

	# Torso (Heavy boulder shape)
	torso = MeshInstance3D.new()
	var torso_mesh = BoxMesh.new()
	torso_mesh.size = Vector3(2.4, 2.2, 1.8)
	torso.mesh = torso_mesh
	torso.material_override = rock_mat
	torso.position = Vector3(0, 2.5, 0)
	torso.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	model_root.add_child(torso)

	# Glowing Chest Core (Eye / Weak Point)
	eye_core = MeshInstance3D.new()
	var core_mesh = SphereMesh.new()
	core_mesh.radius = 0.45
	core_mesh.height = 0.9
	eye_core.mesh = core_mesh
	eye_core.material_override = core_mat
	eye_core.position = Vector3(0, 0.2, 0.95)
	eye_core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	torso.add_child(eye_core)

	# Head
	head = MeshInstance3D.new()
	var head_mesh = BoxMesh.new()
	head_mesh.size = Vector3(1.2, 1.0, 1.2)
	head.mesh = head_mesh
	head.material_override = dark_rock_mat
	head.position = Vector3(0, 1.5, 0.1)
	head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	torso.add_child(head)

	# Left Arm
	arm_left = Node3D.new()
	arm_left.position = Vector3(1.7, 0.6, 0)
	torso.add_child(arm_left)
	
	fist_left = MeshInstance3D.new()
	var arm_mesh = BoxMesh.new()
	arm_mesh.size = Vector3(0.9, 2.0, 0.9)
	fist_left.mesh = arm_mesh
	fist_left.material_override = rock_mat
	fist_left.position = Vector3(0, -0.9, 0)
	fist_left.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	arm_left.add_child(fist_left)

	# Right Arm
	arm_right = Node3D.new()
	arm_right.position = Vector3(-1.7, 0.6, 0)
	torso.add_child(arm_right)
	
	fist_right = MeshInstance3D.new()
	fist_right.mesh = arm_mesh
	fist_right.material_override = rock_mat
	fist_right.position = Vector3(0, -0.9, 0)
	fist_right.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	arm_right.add_child(fist_right)

	# Legs (Pillars)
	var leg_mesh = CylinderMesh.new()
	leg_mesh.top_radius = 0.6
	leg_mesh.bottom_radius = 0.7
	leg_mesh.height = 1.6
	
	var leg_left = MeshInstance3D.new()
	leg_left.mesh = leg_mesh
	leg_left.material_override = dark_rock_mat
	leg_left.position = Vector3(0.7, 0.8, 0)
	leg_left.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	model_root.add_child(leg_left)

	var leg_right = MeshInstance3D.new()
	leg_right.mesh = leg_mesh
	leg_right.material_override = dark_rock_mat
	leg_right.position = Vector3(-0.7, 0.8, 0)
	leg_right.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	model_root.add_child(leg_right)

	# Collision Shape
	var col = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.radius = 1.3
	capsule.height = 3.6
	col.shape = capsule
	col.position = Vector3(0, 1.8, 0)
	add_child(col)

func _physics_process(delta: float) -> void:
	if current_state == State.DEFEATED:
		return

	# Handle gravity
	if not is_on_floor():
		velocity.y -= 18.0 * delta
	else:
		velocity.y = 0.0

	state_timer -= delta
	_update_state_machine(delta)
	move_and_slide()

func _update_state_machine(delta: float) -> void:
	if not target or current_state == State.DEFEATED:
		return

	var dist_to_target = global_position.distance_to(target.global_position)
	var dir_to_target = (target.global_position - global_position).normalized()
	dir_to_target.y = 0.0

	# Smoothly rotate towards player if not in locked attack execution
	if current_state in [State.IDLE, State.WALK, State.TELEGRAPH_SLAM, State.TELEGRAPH_SWIPE]:
		if dir_to_target.length_squared() > 0.001:
			var target_rot = atan2(-dir_to_target.x, -dir_to_target.z)
			rotation.y = lerp_angle(rotation.y, target_rot, delta * 3.5)

	match current_state:
		State.IDLE:
			velocity.x = 0.0
			velocity.z = 0.0
			_animate_idle(delta)
			if state_timer <= 0.0:
				if dist_to_target > 8.0:
					_switch_state(State.WALK, randf_range(2.0, 3.5))
				elif dist_to_target < 4.5:
					_switch_state(State.TELEGRAPH_SWIPE, 0.8)
				else:
					_switch_state(State.TELEGRAPH_SLAM, 1.0)

		State.WALK:
			velocity.x = dir_to_target.x * 3.2
			velocity.z = dir_to_target.z * 3.2
			_animate_walk(delta)
			if dist_to_target < 5.0 or state_timer <= 0.0:
				if randf() > 0.5:
					_switch_state(State.TELEGRAPH_SLAM, 1.0)
				else:
					_switch_state(State.TELEGRAPH_SWIPE, 0.8)

		State.TELEGRAPH_SLAM:
			velocity.x = 0.0
			velocity.z = 0.0
			# Raise arms high, core flashes red/orange
			var progress = 1.0 - (state_timer / 1.0)
			arm_left.rotation.x = lerp(0.0, -2.4, progress)
			arm_right.rotation.x = lerp(0.0, -2.4, progress)
			core_mat.emission = Color(1.0, 0.3, 0.1)
			core_mat.emission_energy_multiplier = 4.0 + sin(Time.get_ticks_msec() * 0.02) * 2.0
			if state_timer <= 0.0:
				_switch_state(State.SLAM, 0.7)

		State.SLAM:
			# Smash arms to floor, spawn shockwave
			arm_left.rotation.x = lerp(arm_left.rotation.x, 0.6, delta * 20.0)
			arm_right.rotation.x = lerp(arm_right.rotation.x, 0.6, delta * 20.0)
			if state_timer > 0.5:
				_execute_slam_impact()
				state_timer = 0.5
			if state_timer <= 0.0:
				core_mat.emission = Color(0.1, 0.8, 1.0)
				core_mat.emission_energy_multiplier = 3.5
				_switch_state(State.IDLE, randf_range(1.0, 1.8))

		State.TELEGRAPH_SWIPE:
			velocity.x = 0.0
			velocity.z = 0.0
			var progress = 1.0 - (state_timer / 0.8)
			arm_left.rotation.y = lerp(0.0, 1.6, progress)
			arm_left.rotation.z = lerp(0.0, 0.4, progress)
			core_mat.emission = Color(1.0, 0.8, 0.0)
			if state_timer <= 0.0:
				_switch_state(State.SWIPE, 0.5)

		State.SWIPE:
			arm_left.rotation.y = lerp(arm_left.rotation.y, -1.8, delta * 15.0)
			if state_timer > 0.3:
				_check_swipe_hit()
			if state_timer <= 0.0:
				arm_left.rotation = Vector3.ZERO
				core_mat.emission = Color(0.1, 0.8, 1.0)
				_switch_state(State.IDLE, randf_range(0.8, 1.5))

		State.STAGGER:
			velocity.x = 0.0
			velocity.z = 0.0
			torso.position.y = lerp(torso.position.y, 1.6, delta * 5.0)
			core_mat.emission = Color(0.4, 0.4, 1.0)
			core_mat.emission_energy_multiplier = 1.5
			if state_timer <= 0.0:
				torso.position.y = 2.5
				core_mat.emission = Color(0.1, 0.8, 1.0)
				core_mat.emission_energy_multiplier = 3.5
				_switch_state(State.IDLE, 1.0)

func _switch_state(new_state: State, duration: float) -> void:
	current_state = new_state
	state_timer = duration
	
	match new_state:
		State.TELEGRAPH_SLAM:
			attack_telegraphed.emit("GROUND SLAM!!")
		State.TELEGRAPH_SWIPE:
			attack_telegraphed.emit("HEAVY SWIPE!")
		State.STAGGER:
			attack_telegraphed.emit("CORE EXPOSED!!")

func _execute_slam_impact() -> void:
	# Emit shockwave event into the parent stage
	var stage = get_parent()
	if stage and stage.has_method("spawn_shockwave"):
		stage.spawn_shockwave(global_position + -transform.basis.z * 1.5)

func _check_swipe_hit() -> void:
	if not target:
		return
	var dist = global_position.distance_to(target.global_position)
	if dist < 4.2:
		var forward = -transform.basis.z
		var to_target = (target.global_position - global_position).normalized()
		if forward.dot(to_target) > 0.3:
			if target.has_method("take_damage"):
				target.take_damage(25.0, (to_target + Vector3.UP * 0.4).normalized() * 12.0)

func take_damage(amount: float, is_critical: bool = false) -> void:
	if current_state == State.DEFEATED:
		return

	var final_dmg = amount * (2.2 if is_critical else 1.0)
	current_health = max(0.0, current_health - final_dmg)
	health_changed.emit(current_health, max_health)

	# Flash core white on hit
	var flash_tween = create_tween()
	flash_tween.tween_property(core_mat, "emission", Color.WHITE, 0.05)
	flash_tween.tween_property(core_mat, "emission", Color(0.1, 0.8, 1.0), 0.15)

	# Stagger threshold check
	stagger_count += 1
	if stagger_count >= 8 and current_state not in [State.STAGGER, State.SLAM]:
		stagger_count = 0
		_switch_state(State.STAGGER, 3.0)

	if current_health <= 0.0:
		_on_defeated()

func _on_defeated() -> void:
	current_state = State.DEFEATED
	velocity = Vector3.ZERO
	core_mat.emission_enabled = false
	boss_defeated.emit()
	
	# Death crumble animation
	var t = create_tween()
	t.tween_property(torso, "position:y", 0.6, 1.2).set_trans(Tween.TRANS_BOUNCE)
	t.parallel().tween_property(head, "position:y", -0.5, 1.0)
	t.parallel().tween_property(arm_left, "position:y", -1.2, 0.8)
	t.parallel().tween_property(arm_right, "position:y", -1.2, 0.8)

func _animate_idle(delta: float) -> void:
	var t = Time.get_ticks_msec() * 0.002
	torso.position.y = 2.5 + sin(t) * 0.06
	arm_left.rotation.x = sin(t * 0.8) * 0.08
	arm_right.rotation.x = -sin(t * 0.8) * 0.08

func _animate_walk(delta: float) -> void:
	var t = Time.get_ticks_msec() * 0.006
	torso.position.y = 2.5 + abs(sin(t)) * 0.12
	torso.rotation.z = sin(t * 0.5) * 0.04
	arm_left.rotation.x = sin(t) * 0.4
	arm_right.rotation.x = -sin(t) * 0.4

func get_lockon_position() -> Vector3:
	if eye_core:
		return eye_core.global_position
	return global_position + Vector3(0, 2.5, 0)
