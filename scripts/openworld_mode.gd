class_name OpenWorldMode
extends Node3D

## Controller for the Open World & Terrain LOD Benchmark Stage (720x720)

const SoundManagerScript = preload("res://scripts/sound_manager.gd")
const SettingsScript = preload("res://scripts/settings_manager.gd")

@onready var sound_manager: Node = $SoundManager
@onready var terrain_manager: TerrainChunkManager = $TerrainChunkManager
@onready var vegetation_streamer: VegetationStreamer = $VegetationStreamer
@onready var buggy: OffroadBuggy = $OffroadBuggy
@onready var pause_menu: Node = $PauseMenu

# HUD References
@onready var fps_label: Label = $HUD/Margin/TopBar/FpsLabel
@onready var speed_label: Label = $HUD/Margin/TopBar/SpeedBox/HBox/SpeedLabel
@onready var gear_badge: Label = $HUD/Margin/TopBar/SpeedBox/HBox/GearBadge
@onready var lod_stats_label: Label = $HUD/Margin/TopBar/LodBox/HBox/LodLabel
@onready var coords_label: Label = $HUD/Margin/NavInfo/CoordsLabel
@onready var turbo_bar: ProgressBar = $HUD/Margin/NavInfo/TurboBar

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

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	SettingsScript.load_settings()
	
	if terrain_manager and buggy:
		terrain_manager.set_target(buggy)
		buggy.set_terrain(terrain_manager)
		buggy.speed_changed.connect(_on_buggy_speed_changed)
		
	if vegetation_streamer and terrain_manager and buggy:
		vegetation_streamer.setup(terrain_manager, buggy)

func _process(_delta: float) -> void:
	fps_label.text = "%d FPS" % Engine.get_frames_per_second()
	
	if buggy and terrain_manager:
		var pos = buggy.global_position
		coords_label.text = "GPS: X: %+4dm  Z: %+4dm  ALT: %2dm" % [int(pos.x), int(pos.z), int(pos.y)]
		turbo_bar.value = buggy.turbo_energy
		
		var stats = terrain_manager.get_lod_stats()
		lod_stats_label.text = "%d chunks (Hi:%d / Lo:%d)" % [stats["total"], stats["high"], stats["low"]]
		
	_update_indicators()

func _on_buggy_speed_changed(kmh: float, is_turbo: bool) -> void:
	speed_label.text = "%3d km/h" % int(kmh)
	if is_turbo:
		gear_badge.text = "[TURBO]"
		gear_badge.add_theme_color_override("font_color", Color(1.0, 0.65, 0.15))
	elif buggy and buggy.is_drifting:
		gear_badge.text = "[DRIFT]"
		gear_badge.add_theme_color_override("font_color", Color(0.2, 0.85, 1.0))
	elif buggy and buggy.current_forward_speed < -0.2:
		gear_badge.text = "[REV]"
		gear_badge.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	else:
		gear_badge.text = "[DRIVE]"
		gear_badge.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))

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
