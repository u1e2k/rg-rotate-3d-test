class_name MusouMode
extends Node3D

## Controller for the Musou Horde Benchmark Stage

const SoundManagerScript = preload("res://scripts/sound_manager.gd")
const SettingsScript = preload("res://scripts/settings_manager.gd")

@onready var sound_manager: Node = $SoundManager
@onready var player: Node3D = $Player
@onready var horde: Node3D = $EnemyHorde
@onready var pause_menu: Node = $PauseMenu

# HUD References
@onready var ko_count_label: Label = $HUD/Margin/TopBar/KoBox/HBox/KoLabel
@onready var combo_label: Label = $HUD/Margin/TopBar/ComboLabel
@onready var enemy_count_label: Label = $HUD/Margin/TopBar/HordeBox/HBox/CountLabel
@onready var fps_label: Label = $HUD/Margin/TopBar/FpsLabel
@onready var hit_banner: Label = $HUD/HitBanner

# Key Visualizer Indicators
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

var total_ko: int = 0
var combo_hits: int = 0
var combo_timer: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	SettingsScript.load_settings()
	
	if player and horde:
		player.set_horde(horde)
		horde.set_target(player)
		player.attack_performed.connect(_on_player_attack)
		player.special_performed.connect(_on_player_special)
		horde.enemy_defeated.connect(_on_enemy_defeated)
		horde.horde_size_changed.connect(_on_horde_size_changed)
		
	if pause_menu:
		pause_menu.settings_changed.connect(_on_settings_changed)
		
	_update_hud()
	hit_banner.visible = false

func _on_settings_changed() -> void:
	if player and player.has_method("apply_settings"):
		player.apply_settings()

func _process(delta: float) -> void:
	fps_label.text = "%d FPS" % Engine.get_frames_per_second()
	
	if combo_timer > 0.0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			combo_hits = 0
			combo_label.text = ""
			
	_update_indicators()

func _on_player_attack(combo_step: int, hits: int) -> void:
	if hits > 0:
		_add_hits(hits)

func _on_player_special(hits: int) -> void:
	if hits > 0:
		_add_hits(hits)
		_show_banner("🌪️ 無双奥義！ %d 体撃破！" % hits)

func _add_hits(hits: int) -> void:
	combo_hits += hits
	combo_timer = 2.5
	combo_label.text = "%d COMBO!" % combo_hits

func _show_banner(msg: String) -> void:
	hit_banner.text = msg
	hit_banner.visible = true
	var tw = create_tween()
	tw.tween_interval(1.5)
	tw.tween_callback(func(): hit_banner.visible = false)

func _on_enemy_defeated(count: int) -> void:
	total_ko += count
	_update_hud()

func _on_horde_size_changed(new_size: int) -> void:
	_update_hud()
	_show_banner("敵兵士数: %d 体に変更" % new_size)

func _update_hud() -> void:
	ko_count_label.text = "%d KO" % total_ko
	if horde:
		enemy_count_label.text = "%d 体" % horde.active_count

func _update_indicators() -> void:
	var c_active = Color(0.2, 1.0, 0.4, 1.0)
	var c_dim = Color(1.0, 1.0, 1.0, 0.25)
	
	_set_key_state(key_up, Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_UP) or Input.is_action_pressed("move_forward") or Input.is_action_pressed("ui_up"), c_active, c_dim)
	_set_key_state(key_down, Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_DOWN) or Input.is_action_pressed("move_backward") or Input.is_action_pressed("ui_down"), c_active, c_dim)
	_set_key_state(key_left, Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_LEFT) or Input.is_action_pressed("turn_left") or Input.is_action_pressed("ui_left"), c_active, c_dim)
	_set_key_state(key_right, Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_RIGHT) or Input.is_action_pressed("turn_right") or Input.is_action_pressed("ui_right"), c_active, c_dim)
	
	var joy_a = Input.is_joy_button_pressed(0, JOY_BUTTON_A) or Input.is_key_pressed(KEY_E)
	var joy_b = Input.is_joy_button_pressed(0, JOY_BUTTON_B) or Input.is_key_pressed(KEY_SPACE)
	var joy_x = Input.is_joy_button_pressed(0, JOY_BUTTON_X)
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
