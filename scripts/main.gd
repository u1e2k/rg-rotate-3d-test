class_name MainScene
extends Node3D

const SoundManagerScript = preload("res://scripts/sound_manager.gd")
const SettingsScript = preload("res://scripts/settings_manager.gd")

@onready var sound_manager: Node = $SoundManager
@onready var hud_gem_label: Label = $HUD/MarginContainer/TopBar/GemBox/HBox/GemLabel
@onready var hud_time_label: Label = $HUD/MarginContainer/TopBar/TimeBox/HBox/TimeLabel
@onready var hud_fps_label: Label = $HUD/MarginContainer/TopBar/FpsBox/HBox/FpsLabel
@onready var clear_banner: Control = $HUD/ClearBanner
@onready var player: Node3D = $Player
@onready var collectibles_container: Node3D = $Environment/Collectibles

# Input visualizer indicators
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

# Settings Menu references
@onready var settings_menu: Control = $HUD/SettingsMenu
@onready var turn_slider: HSlider = $HUD/SettingsMenu/Center/Panel/Margin/VBox/TurnSetting/HBox/TurnSlider
@onready var turn_value_label: Label = $HUD/SettingsMenu/Center/Panel/Margin/VBox/TurnSetting/HBox/TurnValueLabel
@onready var cam_slider: HSlider = $HUD/SettingsMenu/Center/Panel/Margin/VBox/CamSetting/HBox/CamSlider
@onready var cam_value_label: Label = $HUD/SettingsMenu/Center/Panel/Margin/VBox/CamSetting/HBox/CamValueLabel
@onready var close_btn: Button = $HUD/SettingsMenu/Center/Panel/Margin/VBox/CloseButton
@onready var exit_hub_btn: Button = $HUD/SettingsMenu/Center/Panel/Margin/VBox/ExitToHubButton

# Interaction & Vehicle references
@onready var airplane: Node3D = $Environment/Airplane
@onready var interact_prompt_panel: Control = $HUD/InteractPrompt
@onready var interact_prompt_label: Label = $HUD/InteractPrompt/PromptLabel
@onready var guide_title: Label = $HUD/MarginContainer/BottomBar/ControlGuide/VBox/Title
@onready var guide_row1: Label = $HUD/MarginContainer/BottomBar/ControlGuide/VBox/Row1
@onready var guide_row2: Label = $HUD/MarginContainer/BottomBar/ControlGuide/VBox/Row2

var total_gems: int = 0
var collected_gems: int = 0
var elapsed_time: float = 0.0
var is_cleared: bool = false
var is_menu_open: bool = false

var menu_items: Array[Control] = []
var current_menu_index: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	SettingsScript.load_settings()
	_setup_settings_ui()
	
	total_gems = collectibles_container.get_child_count()
	for child in collectibles_container.get_children():
		if child.has_signal("collected"):
			child.connect("collected", _on_gem_collected)
	_update_hud()
	clear_banner.visible = false
	settings_menu.visible = false
	interact_prompt_panel.visible = false
	
	if player and player.has_signal("nearby_interactable_changed"):
		player.connect("nearby_interactable_changed", _on_player_nearby_interactable_changed)
		
	if airplane and airplane.has_signal("board_state_changed"):
		airplane.connect("board_state_changed", _on_airplane_board_state_changed)

func _setup_settings_ui() -> void:
	menu_items = [turn_slider, cam_slider, close_btn, exit_hub_btn]
	
	turn_slider.value = SettingsScript.turn_sensitivity
	_update_turn_label(turn_slider.value)
	turn_slider.value_changed.connect(_on_turn_slider_changed)
	
	cam_slider.value = SettingsScript.camera_smoothing
	_update_cam_label(cam_slider.value)
	cam_slider.value_changed.connect(_on_cam_slider_changed)
	
	close_btn.pressed.connect(toggle_settings_menu)
	exit_hub_btn.pressed.connect(_on_exit_to_hub_pressed)

func _on_exit_to_hub_pressed() -> void:
	get_tree().paused = false
	var sm = SoundManagerScript.get_instance()
	if sm and sm.has_method("play_confirm"):
		sm.play_confirm()
	get_tree().change_scene_to_file("res://scenes/launcher.tscn")

func _safe_handle_input() -> void:
	var vp = get_viewport()
	if vp:
		vp.set_input_as_handled()

func _input(event: InputEvent) -> void:
	if not is_menu_open:
		if event.is_action_pressed("toggle_menu"):
			_safe_handle_input()
			toggle_settings_menu()
		return
		
	# Menu is OPEN
	if event.is_action_pressed("toggle_menu") or event.is_action_pressed("ui_cancel"):
		_safe_handle_input()
		toggle_settings_menu()
		return
		
	if event.is_action_pressed("ui_down"):
		current_menu_index = (current_menu_index + 1) % menu_items.size()
		menu_items[current_menu_index].grab_focus()
		var sm = SoundManagerScript.get_instance()
		if sm:
			sm.play_step()
		_safe_handle_input()
		return
		
	if event.is_action_pressed("ui_up"):
		current_menu_index = (current_menu_index - 1 + menu_items.size()) % menu_items.size()
		menu_items[current_menu_index].grab_focus()
		var sm = SoundManagerScript.get_instance()
		if sm:
			sm.play_step()
		_safe_handle_input()
		return
		
	if event.is_action_pressed("ui_accept"):
		if current_menu_index == 2:
			_safe_handle_input()
			toggle_settings_menu()
		elif current_menu_index == 3:
			_safe_handle_input()
			_on_exit_to_hub_pressed()
		return
		
	if event.is_action_pressed("ui_left"):
		if current_menu_index == 0:
			turn_slider.value = clampf(turn_slider.value - turn_slider.step, turn_slider.min_value, turn_slider.max_value)
			_safe_handle_input()
		elif current_menu_index == 1:
			cam_slider.value = clampf(cam_slider.value - cam_slider.step, cam_slider.min_value, cam_slider.max_value)
			_safe_handle_input()
		return
		
	if event.is_action_pressed("ui_right"):
		if current_menu_index == 0:
			turn_slider.value = clampf(turn_slider.value + turn_slider.step, turn_slider.min_value, turn_slider.max_value)
			_safe_handle_input()
		elif current_menu_index == 1:
			cam_slider.value = clampf(cam_slider.value + cam_slider.step, cam_slider.min_value, cam_slider.max_value)
			_safe_handle_input()
		return

func toggle_settings_menu() -> void:
	is_menu_open = !is_menu_open
	settings_menu.visible = is_menu_open
	get_tree().paused = is_menu_open
	
	var sm = SoundManagerScript.get_instance()
	if sm:
		sm.play_coin()
		
	if is_menu_open:
		current_menu_index = 0
		turn_slider.grab_focus()
	else:
		SettingsScript.save_settings()
		if player and player.has_method("apply_settings"):
			player.apply_settings()
		if player and player.has_method("suppress_input"):
			player.suppress_input(0.3)

func _on_turn_slider_changed(value: float) -> void:
	SettingsScript.turn_sensitivity = value
	_update_turn_label(value)
	if player and player.has_method("apply_settings"):
		player.apply_settings()

func _update_turn_label(value: float) -> void:
	var desc = ""
	if value < 2.0:
		desc = " (ゆっくり)"
	elif value > 3.8:
		desc = " (超高速)"
	elif value > 3.2:
		desc = " (高速)"
	else:
		desc = " (標準)"
	turn_value_label.text = "%.1f%s" % [value, desc]

func _on_cam_slider_changed(value: float) -> void:
	SettingsScript.camera_smoothing = value
	_update_cam_label(value)
	if player and player.has_method("apply_settings"):
		player.apply_settings()

func _update_cam_label(value: float) -> void:
	cam_value_label.text = "%.1f" % value

func _process(delta: float) -> void:
	if not is_cleared and not is_menu_open:
		elapsed_time += delta
		var minutes = int(elapsed_time) / 60
		var seconds = int(elapsed_time) % 60
		var msec = int((elapsed_time - int(elapsed_time)) * 10)
		hud_time_label.text = "%02d:%02d.%d" % [minutes, seconds, msec]
	
	# High visibility FPS display
	hud_fps_label.text = "%d FPS" % Engine.get_frames_per_second()
	
	# Update input visualizer
	_update_input_overlay()

func _update_input_overlay() -> void:
	# Direction buttons (1-to-1)
	_set_key_active(key_up, Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_UP) or Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W))
	_set_key_active(key_down, Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_DOWN) or Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S))
	_set_key_active(key_left, Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_LEFT) or Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A))
	_set_key_active(key_right, Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_RIGHT) or Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D))
	
	# Action buttons (strictly 1-to-1, completely isolated!)
	_set_key_active(key_a, Input.is_joy_button_pressed(0, JOY_BUTTON_A) or Input.is_key_pressed(KEY_E) or Input.is_key_pressed(KEY_ENTER))
	_set_key_active(key_b, Input.is_joy_button_pressed(0, JOY_BUTTON_B) or Input.is_key_pressed(KEY_SPACE))
	_set_key_active(key_x, Input.is_joy_button_pressed(0, JOY_BUTTON_X) or Input.is_key_pressed(KEY_X))
	_set_key_active(key_y, Input.is_joy_button_pressed(0, JOY_BUTTON_Y) or Input.is_key_pressed(KEY_SHIFT))
	_set_key_active(key_lb, Input.is_joy_button_pressed(0, JOY_BUTTON_LEFT_SHOULDER) or Input.is_key_pressed(KEY_Q))
	_set_key_active(key_rb, Input.is_joy_button_pressed(0, JOY_BUTTON_RIGHT_SHOULDER) or Input.is_key_pressed(KEY_F))

func _on_player_nearby_interactable_changed(interactable: Interactable) -> void:
	if interactable and interactable.can_interact(player):
		interact_prompt_panel.visible = true
		interact_prompt_label.text = interactable.get_prompt()
	else:
		interact_prompt_panel.visible = false

func _on_airplane_board_state_changed(is_boarded: bool) -> void:
	interact_prompt_panel.visible = false
	if is_boarded:
		guide_title.text = "✈️ FLIGHT MODE / AIRPLANE CONTROLS"
		guide_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 1.0))
		guide_row1.text = "▲ 降下 (Dive)　▼ 上昇 (Climb)　◀ ▶ 旋回ロール"
		guide_row2.text = "[Y] 加速　[B] 減速/着陸　[RB] 連装射撃　[A] 降りる"
	else:
		guide_title.text = "ANBERNIC RG ROTATE / D-PAD CONTROLS"
		guide_title.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0, 1.0))
		guide_row1.text = "▲ 前進　▼ 後退　◀ ▶ 旋回"
		guide_row2.text = "[A] 調べる/乗る　[B] ジャンプ　[Y] ダッシュ　[RB] 射撃　[LB] 180°反転　[Start] 設定"

func _set_key_active(label: Label, is_active: bool) -> void:
	if is_active:
		label.modulate = Color(0.2, 0.95, 1.0, 1.0)
	else:
		label.modulate = Color(1.0, 1.0, 1.0, 0.28)

func _on_gem_collected() -> void:
	collected_gems += 1
	_update_hud()
	
	if collected_gems >= total_gems and not is_cleared:
		_trigger_stage_clear()

func _update_hud() -> void:
	hud_gem_label.text = "%d / %d" % [collected_gems, total_gems]

func _trigger_stage_clear() -> void:
	is_cleared = true
	clear_banner.visible = true
	clear_banner.modulate = Color(1, 1, 1, 0)
	clear_banner.scale = Vector2(0.7, 0.7)
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(clear_banner, "modulate:a", 1.0, 0.4)
	tween.tween_property(clear_banner, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	var sm = SoundManagerScript.get_instance()
	if sm:
		sm.play_respawn()
