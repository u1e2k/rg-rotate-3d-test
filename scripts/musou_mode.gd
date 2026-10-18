class_name MusouMode
extends Node3D

## Controller for the Musou Horde Benchmark Stage

const SoundManagerScript = preload("res://scripts/sound_manager.gd")
const SettingsScript = preload("res://scripts/settings_manager.gd")

@onready var sound_manager: Node = $SoundManager
@onready var player: Node3D = $Player
@onready var horde: Node3D = $EnemyHorde

# HUD References
@onready var ko_count_label: Label = $HUD/Margin/TopBar/KoBox/HBox/KoLabel
@onready var combo_label: Label = $HUD/Margin/TopBar/ComboLabel
@onready var enemy_count_label: Label = $HUD/Margin/TopBar/HordeBox/HBox/CountLabel
@onready var fps_label: Label = $HUD/Margin/TopBar/FpsLabel
@onready var hit_banner: Label = $HUD/HitBanner

# Pause / Exit Modal references
@onready var settings_menu: Control = $HUD/SettingsMenu
@onready var turn_slider: HSlider = $HUD/SettingsMenu/Center/Panel/Margin/VBox/TurnSetting/HBox/TurnSlider
@onready var turn_value_label: Label = $HUD/SettingsMenu/Center/Panel/Margin/VBox/TurnSetting/HBox/TurnValueLabel
@onready var close_btn: Button = $HUD/SettingsMenu/Center/Panel/Margin/VBox/CloseButton
@onready var exit_hub_btn: Button = $HUD/SettingsMenu/Center/Panel/Margin/VBox/ExitToHubButton

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
var is_menu_open: bool = false
var menu_items: Array[Control] = []
var current_menu_index: int = 0
var menu_cooldown: float = 0.0
var input_suppress_timer: float = 0.0

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
		
	_setup_settings_ui()
	_update_hud()
	settings_menu.visible = false
	hit_banner.visible = false

func _setup_settings_ui() -> void:
	settings_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	menu_items = [turn_slider, close_btn, exit_hub_btn]
	
	turn_slider.value = SettingsScript.turn_sensitivity
	_update_turn_label(turn_slider.value)
	turn_slider.value_changed.connect(func(val):
		SettingsScript.turn_sensitivity = val
		_update_turn_label(val)
		SettingsScript.save_settings()
		if player and player.has_method("apply_settings"):
			player.apply_settings()
	)
	close_btn.pressed.connect(toggle_settings_menu)
	exit_hub_btn.pressed.connect(_on_exit_to_hub_pressed)

func _update_turn_label(val: float) -> void:
	var desc = ""
	if val < 2.0:
		desc = " (遅)"
	elif val > 3.6:
		desc = " (速)"
	else:
		desc = " (標準)"
	turn_value_label.text = "%.1f%s" % [val, desc]

func _process(delta: float) -> void:
	fps_label.text = "%d FPS" % Engine.get_frames_per_second()
	
	if menu_cooldown > 0.0:
		menu_cooldown -= delta
		
	if input_suppress_timer > 0.0:
		input_suppress_timer -= delta
		
	if combo_timer > 0.0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			combo_hits = 0
			combo_label.text = ""
			
	_update_indicators()

func _safe_handle_input() -> void:
	var vp = get_viewport()
	if vp:
		vp.set_input_as_handled()

func _input(event: InputEvent) -> void:
	# Check Start Button explicitly for RG Rotate (JOY_BUTTON_START = 6)
	var is_start_press = false
	if event is InputEventJoypadButton and event.button_index == JOY_BUTTON_START and event.pressed:
		is_start_press = true
	elif event.is_action_pressed("toggle_menu"):
		is_start_press = true
		
	if not is_menu_open:
		if is_start_press:
			_safe_handle_input()
			toggle_settings_menu()
		return
		
	# --- Menu is OPEN ---
	if menu_cooldown > 0.0:
		return
		
	# B Button or Start Button or Esc closes the menu
	var is_cancel_or_start = is_start_press
	if event is InputEventJoypadButton and event.button_index == JOY_BUTTON_B and event.pressed:
		is_cancel_or_start = true
	elif event.is_action_pressed("ui_cancel"):
		is_cancel_or_start = true
		
	if is_cancel_or_start:
		_safe_handle_input()
		toggle_settings_menu()
		return
		
	# Navigation Down (D-Pad Down or ui_down)
	var is_down = false
	if event is InputEventJoypadButton and event.button_index == JOY_BUTTON_DPAD_DOWN and event.pressed:
		is_down = true
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("move_backward"):
		is_down = true
		
	if is_down:
		_safe_handle_input()
		current_menu_index = (current_menu_index + 1) % menu_items.size()
		_highlight_menu_item()
		menu_cooldown = 0.15
		var sm = SoundManagerScript.get_instance()
		if sm and sm.has_method("play_cursor"):
			sm.play_cursor()
		return
		
	# Navigation Up (D-Pad Up or ui_up)
	var is_up = false
	if event is InputEventJoypadButton and event.button_index == JOY_BUTTON_DPAD_UP and event.pressed:
		is_up = true
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("move_forward"):
		is_up = true
		
	if is_up:
		_safe_handle_input()
		current_menu_index = (current_menu_index - 1 + menu_items.size()) % menu_items.size()
		_highlight_menu_item()
		menu_cooldown = 0.15
		var sm = SoundManagerScript.get_instance()
		if sm and sm.has_method("play_cursor"):
			sm.play_cursor()
		return
		
	# Slider Adjust Left (D-Pad Left or ui_left)
	var is_left = false
	if event is InputEventJoypadButton and event.button_index == JOY_BUTTON_DPAD_LEFT and event.pressed:
		is_left = true
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("turn_left"):
		is_left = true
		
	if is_left:
		if current_menu_index == 0:
			turn_slider.value = clampf(turn_slider.value - turn_slider.step, turn_slider.min_value, turn_slider.max_value)
			menu_cooldown = 0.1
			_safe_handle_input()
		return
		
	# Slider Adjust Right (D-Pad Right or ui_right)
	var is_right = false
	if event is InputEventJoypadButton and event.button_index == JOY_BUTTON_DPAD_RIGHT and event.pressed:
		is_right = true
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("turn_right"):
		is_right = true
		
	if is_right:
		if current_menu_index == 0:
			turn_slider.value = clampf(turn_slider.value + turn_slider.step, turn_slider.min_value, turn_slider.max_value)
			menu_cooldown = 0.1
			_safe_handle_input()
		return
		
	# Accept / Activate (A Button or Enter or Space)
	var is_accept = false
	if event is InputEventJoypadButton and event.button_index == JOY_BUTTON_A and event.pressed:
		is_accept = true
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		is_accept = true
		
	if is_accept:
		_safe_handle_input()
		if current_menu_index == 1:
			toggle_settings_menu()
		elif current_menu_index == 2:
			_on_exit_to_hub_pressed()
		return

func _highlight_menu_item() -> void:
	for i in range(menu_items.size()):
		var item = menu_items[i]
		if i == current_menu_index:
			item.grab_focus()
			item.modulate = Color(1.2, 1.2, 1.0, 1.0)
		else:
			item.modulate = Color(1.0, 1.0, 1.0, 0.8)

func toggle_settings_menu() -> void:
	is_menu_open = !is_menu_open
	settings_menu.visible = is_menu_open
	get_tree().paused = is_menu_open
	menu_cooldown = 0.2
	
	var sm = SoundManagerScript.get_instance()
	if sm and sm.has_method("play_cursor"):
		sm.play_cursor()
		
	if is_menu_open:
		current_menu_index = 0
		_highlight_menu_item()
	else:
		input_suppress_timer = 0.3
		SettingsScript.save_settings()
		if player and player.has_method("apply_settings"):
			player.apply_settings()

func _on_exit_to_hub_pressed() -> void:
	get_tree().paused = false
	var sm = SoundManagerScript.get_instance()
	if sm and sm.has_method("play_confirm"):
		sm.play_confirm()
	get_tree().change_scene_to_file("res://scenes/launcher.tscn")

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
