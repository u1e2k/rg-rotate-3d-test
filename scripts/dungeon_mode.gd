class_name DungeonMode
extends Node3D

## Controller for Phase 5: Dungeon Exploration & Boss Battle Benchmark (720x720)
## Demonstrates: Z-Targeting Lock-on, Step Dodge i-frames, Telegraphed Boss AI, Lighting Stress

const SoundManagerScript = preload("res://scripts/sound_manager.gd")
const SettingsScript = preload("res://scripts/settings_manager.gd")
const ShockwaveScene = preload("res://scripts/dungeon_shockwave.gd")

@onready var sound_manager: Node = $SoundManager
@onready var dungeon_generator: DungeonGenerator = $DungeonGenerator
@onready var player: DungeonPlayer = $DungeonPlayer
@onready var boss: GolemBoss = $GolemBoss
@onready var pause_menu: Node = $PauseMenu

# HUD
@onready var fps_label: Label = $HUD/Margin/TopBar/FpsLabel
@onready var lighting_label: Label = $HUD/Margin/TopBar/LightingBox/HBox/LightingLabel
@onready var telegraph_label: Label = $HUD/Margin/TelegraphLabel
@onready var boss_hp_bar: ProgressBar = $HUD/Margin/BossBox/BossHpBar
@onready var boss_name_label: Label = $HUD/Margin/BossBox/BossName
@onready var player_hp_bar: ProgressBar = $HUD/Margin/PlayerBox/HpBar
@onready var lock_reticle: Control = $HUD/LockReticle

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

var telegraph_timer: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	SettingsScript.load_settings()

	if player and boss:
		player.set_lock_target(boss)
		boss.set_target(player)
		
		boss.health_changed.connect(_on_boss_health_changed)
		boss.attack_telegraphed.connect(_on_boss_attack_telegraphed)
		boss.boss_defeated.connect(_on_boss_defeated)
		
		player.health_changed.connect(_on_player_health_changed)
		player.lock_on_toggled.connect(_on_player_lock_on_toggled)

	if dungeon_generator:
		dungeon_generator.lighting_mode_changed.connect(_on_lighting_mode_changed)

func _input(event: InputEvent) -> void:
	# LB button: Toggle Lighting Stress Test Mode
	if event.is_action_pressed("quick_turn") or (event is InputEventJoypadButton and event.button_index == JOY_BUTTON_LEFT_SHOULDER and event.pressed):
		if dungeon_generator:
			dungeon_generator.toggle_lighting_stress_mode()

func _process(delta: float) -> void:
	fps_label.text = "%d FPS" % Engine.get_frames_per_second()
	
	if telegraph_timer > 0.0:
		telegraph_timer -= delta
		if telegraph_timer <= 0.0:
			telegraph_label.visible = false

	# Update Lock-on Reticle Screen Position
	if player and player.is_locked_on and boss and is_instance_valid(boss):
		lock_reticle.visible = true
		var cam = player.camera
		if cam:
			var world_pos = boss.get_lockon_position()
			if not cam.is_position_behind(world_pos):
				var screen_pos = cam.unproject_position(world_pos)
				lock_reticle.position = screen_pos - (lock_reticle.size * 0.5)
			else:
				lock_reticle.visible = false
	else:
		lock_reticle.visible = false

	_update_indicators()

func spawn_shockwave(pos: Vector3) -> void:
	var sw = ShockwaveScene.new()
	sw.position = pos
	sw.position.y = 0.1
	add_child(sw)
	
	if sound_manager and sound_manager.has_method("play_hit"):
		sound_manager.play_hit()

func _on_boss_health_changed(hp: float, max_hp: float) -> void:
	boss_hp_bar.value = (hp / max_hp) * 100.0

func _on_player_health_changed(hp: float, max_hp: float) -> void:
	player_hp_bar.value = (hp / max_hp) * 100.0

func _on_boss_attack_telegraphed(attack_name: String) -> void:
	telegraph_label.text = "⚠️ " + attack_name
	telegraph_label.visible = true
	telegraph_timer = 1.2
	
	# Shake effect
	var t = create_tween()
	telegraph_label.scale = Vector2(1.2, 1.2)
	t.tween_property(telegraph_label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)

func _on_boss_defeated() -> void:
	telegraph_label.text = "🏆 GOLEM DEFEATED! 🏆"
	telegraph_label.visible = true
	telegraph_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	telegraph_timer = 999.0
	if sound_manager and sound_manager.has_method("play_crystal"):
		sound_manager.play_crystal()

func _on_player_lock_on_toggled(is_locked: bool, _target: Node3D) -> void:
	lock_reticle.visible = is_locked

func _on_lighting_mode_changed(mode_name: String, _count: int) -> void:
	lighting_label.text = mode_name
	if sound_manager and sound_manager.has_method("play_cursor"):
		sound_manager.play_cursor()

func _update_indicators() -> void:
	var press_col = Color(0.2, 1.0, 0.4)
	var idle_col = Color(0.4, 0.4, 0.4)

	var u = Input.is_action_pressed("move_forward") or Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_UP)
	var d = Input.is_action_pressed("move_backward") or Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_DOWN)
	var l = Input.is_action_pressed("turn_left") or Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_LEFT)
	var r = Input.is_action_pressed("turn_right") or Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_RIGHT)

	var b_a = Input.is_action_pressed("interact") or Input.is_joy_button_pressed(0, JOY_BUTTON_A)
	var b_b = Input.is_action_pressed("jump") or Input.is_joy_button_pressed(0, JOY_BUTTON_B)
	var b_x = Input.is_action_pressed("camera_toggle") or Input.is_joy_button_pressed(0, JOY_BUTTON_X)
	var b_y = Input.is_action_pressed("sprint") or Input.is_joy_button_pressed(0, JOY_BUTTON_Y)
	var b_lb = Input.is_action_pressed("quick_turn") or Input.is_joy_button_pressed(0, JOY_BUTTON_LEFT_SHOULDER)
	var b_rb = Input.is_action_pressed("shoot") or Input.is_joy_button_pressed(0, JOY_BUTTON_RIGHT_SHOULDER)

	key_up.modulate = press_col if u else idle_col
	key_down.modulate = press_col if d else idle_col
	key_left.modulate = press_col if l else idle_col
	key_right.modulate = press_col if r else idle_col

	key_a.modulate = press_col if b_a else idle_col
	key_b.modulate = press_col if b_b else idle_col
	key_x.modulate = press_col if b_x else idle_col
	key_y.modulate = press_col if b_y else idle_col
	key_lb.modulate = press_col if b_lb else idle_col
	key_rb.modulate = press_col if b_rb else idle_col
