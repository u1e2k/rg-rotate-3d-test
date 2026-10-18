class_name SpaceFlightMode
extends Node3D

## Controller for the Star Flight & Space Dogfight Mode (720x720)

const SoundManagerScript = preload("res://scripts/sound_manager.gd")
const SettingsScript = preload("res://scripts/settings_manager.gd")
const EnemyScene = preload("res://scenes/space_enemy.tscn")

@onready var sound_manager: Node = $SoundManager
@onready var player: SpaceFighter = $SpaceFighter
@onready var asteroid_field: AsteroidField = $AsteroidField
@onready var pause_menu: Node = $PauseMenu
@onready var enemies_container: Node3D = $Enemies

# HUD References
@onready var fps_label: Label = $HUD/Margin/TopBar/FpsLabel
@onready var kills_label: Label = $HUD/Margin/TopBar/KillsBox/HBox/KillsLabel
@onready var enemies_count_label: Label = $HUD/Margin/TopBar/EnemiesBox/HBox/CountLabel
@onready var hull_bar: ProgressBar = $HUD/Margin/TopBar/HullBox/HullBar
@onready var shield_bar: ProgressBar = $HUD/Margin/TopBar/HullBox/ShieldBar
@onready var speed_label: Label = $HUD/Margin/FlightInfo/SpeedLabel
@onready var boost_bar: ProgressBar = $HUD/Margin/FlightInfo/BoostBar
@onready var cam_mode_label: Label = $HUD/Margin/FlightInfo/CamModeLabel
@onready var hit_banner: Label = $HUD/HitBanner

# Reticle and Lock-on UI
@onready var lock_box: Panel = $HUD/LockOverlay/LockBox
@onready var lock_label: Label = $HUD/LockOverlay/LockBox/LockLabel
@onready var lock_dist_label: Label = $HUD/LockOverlay/LockBox/DistLabel
@onready var offscreen_indicators: Control = $HUD/OffscreenIndicators

# Physical Button Indicators
@onready var key_up: Label = $HUD/InputOverlay/Grid/Up
@onready var key_down: Label = $HUD/InputOverlay/Grid/Down
@onready var key_left: Label = $HUD/InputOverlay/Grid/Left
@onready var key_right: Label = $HUD/InputOverlay/Grid/Right
@onready var key_a: Label = $HUD/InputOverlay/Grid/A
@onready var key_b: Label = $HUD/InputOverlay/Grid/B
@onready var key_x: Label = $HUD/InputOverlay/Grid/X
@onready var key_y: Label = $HUD/InputOverlay/Grid/Y
@onready var key_lb: Label = $HUD/InputOverlay/Grid/LB
@onready var key_rb: Label = $HUD/InputOverlay/Grid/RB

var total_kills: int = 0
var max_active_enemies: int = 5
var respawn_timer: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	SettingsScript.load_settings()
	
	if player:
		player.camera_switched.connect(_on_camera_switched)
		player.damage_taken.connect(_on_player_damage_taken)
		
	# Spawn initial squadron
	_spawn_enemy_squadron(max_active_enemies)
	
	lock_box.visible = false
	hit_banner.visible = false
	_update_hud()

func _process(delta: float) -> void:
	fps_label.text = "%d FPS" % Engine.get_frames_per_second()
	
	# Update flight gauges
	if player:
		var speed_text = "%d m/s" % int(player.current_speed)
		if player.is_boosting:
			speed_text += " [BOOST]"
		elif player.is_braking:
			speed_text += " [BRAKE]"
		else:
			speed_text += " [CRUISE]"
		speed_label.text = speed_text
		boost_bar.value = player.boost_energy
		
	_update_lockon_hud()
	_update_offscreen_arrows()
	_update_enemy_spawning(delta)
	_update_indicators()

func _update_enemy_spawning(delta: float) -> void:
	var active_count = _get_active_enemy_count()
	if active_count < max_active_enemies:
		respawn_timer += delta
		if respawn_timer >= 2.5:
			respawn_timer = 0.0
			_spawn_single_enemy()

func _spawn_enemy_squadron(count: int) -> void:
	for i in range(count):
		_spawn_single_enemy()

func _spawn_single_enemy() -> void:
	if not enemies_container:
		return
	var enemy = EnemyScene.instantiate() as SpaceEnemy
	var angle = randf_range(0.0, TAU)
	var dist = randf_range(140.0, 220.0)
	var y = randf_range(-30.0, 30.0)
	
	var base_pos = player.global_position if player else Vector3.ZERO
	enemy.global_position = base_pos + Vector3(cos(angle) * dist, y, sin(angle) * dist)
	
	enemies_container.add_child(enemy)
	if player:
		enemy.set_target(player)
	enemy.defeated.connect(_on_enemy_defeated)
	_update_hud()

func _on_enemy_defeated(enemy_node: Node3D) -> void:
	total_kills += 1
	_update_hud()
	_show_banner("🎯 敵機撃墜！ TARGET DESTROYED (+100 PTS)")

func _get_active_enemy_count() -> int:
	var count = 0
	if enemies_container:
		for c in enemies_container.get_children():
			if c is SpaceEnemy and not c.is_dying:
				count += 1
	return count

func _update_hud() -> void:
	kills_label.text = "%d 機" % total_kills
	enemies_count_label.text = "%d 機" % _get_active_enemy_count()
	if player:
		hull_bar.value = player.hull
		shield_bar.value = player.shield

func _on_player_damage_taken(current_hp: float, current_shield: float) -> void:
	hull_bar.value = current_hp
	shield_bar.value = current_shield

func _on_camera_switched(is_cockpit: bool) -> void:
	cam_mode_label.text = "VIEW: COCKPIT" if is_cockpit else "VIEW: CHASE"

func _show_banner(msg: String) -> void:
	hit_banner.text = msg
	hit_banner.visible = true
	var tw = create_tween()
	tw.tween_interval(1.6)
	tw.tween_callback(func(): hit_banner.visible = false)

func _get_current_camera() -> Camera3D:
	if not player:
		return null
	return player.cockpit_camera if player.is_cockpit_view else player.chase_camera

func _update_lockon_hud() -> void:
	var cam = _get_current_camera()
	if not cam or not player:
		lock_box.visible = false
		return
		
	var target = player.locked_target if player.locked_target else player.target_candidate
	if not is_instance_valid(target):
		lock_box.visible = false
		return
		
	var target_pos = target.global_position
	if cam.is_position_behind(target_pos):
		lock_box.visible = false
		return
		
	var screen_pos = cam.unproject_position(target_pos)
	var screen_size = get_viewport().get_visible_rect().size
	
	# Check if inside screen
	if screen_pos.x < 0 or screen_pos.x > screen_size.x or screen_pos.y < 0 or screen_pos.y > screen_size.y:
		lock_box.visible = false
		return
		
	lock_box.visible = true
	lock_box.position = screen_pos - Vector2(28, 28)
	
	var dist = int(player.global_position.distance_to(target_pos))
	lock_dist_label.text = "%dm" % dist
	
	if player.locked_target == target:
		lock_label.text = "LOCK-ON [A]"
		lock_box.add_theme_stylebox_override("panel", _get_lock_style(Color(1.0, 0.2, 0.2, 0.9)))
	else:
		lock_label.text = "TRACKING..."
		lock_box.add_theme_stylebox_override("panel", _get_lock_style(Color(0.2, 0.9, 1.0, 0.7)))

var _cached_lock_styles = {}
func _get_lock_style(border_col: Color) -> StyleBoxFlat:
	var key = border_col.to_html()
	if not _cached_lock_styles.has(key):
		var sb = StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0.15)
		sb.border_width_left = 2
		sb.border_width_top = 2
		sb.border_width_right = 2
		sb.border_width_bottom = 2
		sb.border_color = border_col
		sb.corner_radius_top_left = 4
		sb.corner_radius_top_right = 4
		sb.corner_radius_bottom_right = 4
		sb.corner_radius_bottom_left = 4
		_cached_lock_styles[key] = sb
	return _cached_lock_styles[key]

var arrow_pool: Array[Label] = []
const MAX_ARROWS: int = 8

func _init_arrow_pool() -> void:
	if not offscreen_indicators:
		return
	for i in range(MAX_ARROWS):
		var arrow = Label.new()
		arrow.text = "▲"
		arrow.add_theme_font_size_override("font_size", 14)
		arrow.add_theme_color_override("font_color", Color(1.0, 0.35, 0.2, 0.85))
		arrow.visible = false
		offscreen_indicators.add_child(arrow)
		arrow_pool.append(arrow)

func _update_offscreen_arrows() -> void:
	if arrow_pool.is_empty():
		_init_arrow_pool()
		
	var cam = _get_current_camera()
	if not cam or not player:
		for a in arrow_pool: a.visible = false
		return
		
	var screen_size = get_viewport().get_visible_rect().size
	var center = screen_size * 0.5
	var margin = 26.0
	var arrow_idx = 0
	
	var enemies = get_tree().get_nodes_in_group("enemy")
	for e in enemies:
		if not is_instance_valid(e) or e == player:
			continue
		var target_pos = e.global_position
		var is_behind = cam.is_position_behind(target_pos)
		var screen_pos = cam.unproject_position(target_pos)
		
		if is_behind:
			screen_pos = center - (screen_pos - center)
			
		var is_offscreen = screen_pos.x < margin or screen_pos.x > screen_size.x - margin or screen_pos.y < margin or screen_pos.y > screen_size.y - margin
		
		if is_behind or is_offscreen:
			if arrow_idx < MAX_ARROWS:
				var dir = (screen_pos - center).normalized()
				var border_pos = center + dir * (min(center.x, center.y) - margin)
				var arrow = arrow_pool[arrow_idx]
				arrow.rotation = dir.angle() + PI * 0.5
				arrow.position = border_pos - Vector2(7, 7)
				arrow.visible = true
				arrow_idx += 1
				
	for i in range(arrow_idx, MAX_ARROWS):
		arrow_pool[i].visible = false

func _update_indicators() -> void:
	var c_active = Color(0.2, 1.0, 0.4, 1.0)
	var c_dim = Color(1.0, 1.0, 1.0, 0.25)
	
	_set_key_state(key_up, Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_UP) or Input.is_action_pressed("move_forward") or Input.is_action_pressed("ui_up"), c_active, c_dim)
	_set_key_state(key_down, Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_DOWN) or Input.is_action_pressed("move_backward") or Input.is_action_pressed("ui_down"), c_active, c_dim)
	_set_key_state(key_left, Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_LEFT) or Input.is_action_pressed("turn_left") or Input.is_action_pressed("ui_left"), c_active, c_dim)
	_set_key_state(key_right, Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_RIGHT) or Input.is_action_pressed("turn_right") or Input.is_action_pressed("ui_right"), c_active, c_dim)
	
	var joy_a = Input.is_joy_button_pressed(0, JOY_BUTTON_A) or Input.is_key_pressed(KEY_E)
	var joy_b = Input.is_joy_button_pressed(0, JOY_BUTTON_B) or Input.is_key_pressed(KEY_SPACE)
	var joy_x = Input.is_joy_button_pressed(0, JOY_BUTTON_X) or Input.is_key_pressed(KEY_X)
	var joy_y = Input.is_joy_button_pressed(0, JOY_BUTTON_Y) or Input.is_key_pressed(KEY_SHIFT)
	var joy_lb = Input.is_joy_button_pressed(0, JOY_BUTTON_LEFT_SHOULDER) or Input.is_key_pressed(KEY_Q)
	var joy_rb = Input.is_joy_button_pressed(0, JOY_BUTTON_RIGHT_SHOULDER) or Input.is_key_pressed(KEY_F)
	
	_set_key_state(key_a, joy_a, c_active, c_dim)
	_set_key_state(key_b, joy_b, c_active, c_dim)
	_set_key_state(key_x, joy_x, c_active, c_dim)
	_set_key_state(key_y, joy_y, c_active, c_dim)
	_set_key_state(key_lb, joy_lb, c_active, c_dim)
	_set_key_state(key_rb, joy_rb, c_active, c_dim)

func _set_key_state(label: Label, pressed: bool, active_col: Color, dim_col: Color) -> void:
	if not label:
		return
	if pressed:
		label.add_theme_color_override("font_color", active_col)
	else:
		label.add_theme_color_override("font_color", dim_col)
