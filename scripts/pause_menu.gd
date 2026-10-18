class_name CommonPauseMenu
extends CanvasLayer

## Universal Pause & Settings Menu for ANBERNIC RG Rotate
## Self-contained modal that handles D-pad navigation, physical buttons, sensitivity settings,
## and guaranteed clean exit to launcher across all game modes.

signal menu_opened
signal menu_closed
signal settings_changed

const SoundManagerScript = preload("res://scripts/sound_manager.gd")
const SettingsScript = preload("res://scripts/settings_manager.gd")

@onready var modal_panel: Control = $Modal
@onready var turn_slider: HSlider = $Modal/Center/Panel/Margin/VBox/TurnSetting/HBox/TurnSlider
@onready var turn_value_label: Label = $Modal/Center/Panel/Margin/VBox/TurnSetting/HBox/TurnValueLabel
@onready var cam_slider: HSlider = $Modal/Center/Panel/Margin/VBox/CamSetting/HBox/CamSlider
@onready var cam_value_label: Label = $Modal/Center/Panel/Margin/VBox/CamSetting/HBox/CamValueLabel
@onready var resume_btn: Button = $Modal/Center/Panel/Margin/VBox/ResumeButton
@onready var exit_hub_btn: Button = $Modal/Center/Panel/Margin/VBox/ExitHubButton

var is_open: bool = false
var menu_items: Array[Control] = []
var current_index: int = 0
var input_cooldown: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100 # Always on top
	
	SettingsScript.load_settings()
	menu_items = [turn_slider, cam_slider, resume_btn, exit_hub_btn]
	
	# Turn Sensitivity Setup
	turn_slider.value = SettingsScript.turn_sensitivity
	_update_turn_label(turn_slider.value)
	turn_slider.value_changed.connect(_on_turn_slider_changed)
	
	# Camera Smoothing Setup
	cam_slider.value = SettingsScript.camera_smoothing
	_update_cam_label(cam_slider.value)
	cam_slider.value_changed.connect(_on_cam_slider_changed)
	
	# Button Connections
	resume_btn.pressed.connect(close)
	exit_hub_btn.pressed.connect(_on_exit_hub_pressed)
	
	modal_panel.visible = false

func _process(delta: float) -> void:
	if input_cooldown > 0.0:
		input_cooldown -= delta

func _input(event: InputEvent) -> void:
	# Check Start Button explicitly on ANBERNIC RG Rotate (JOY_BUTTON_START = 6)
	var is_start_press = false
	if event is InputEventJoypadButton and event.button_index == JOY_BUTTON_START and event.pressed:
		is_start_press = true
	elif event.is_action_pressed("toggle_menu"):
		is_start_press = true
		
	if not is_open:
		if is_start_press:
			_safe_handle_input()
			open()
		return
		
	# --- Menu is OPEN ---
	if input_cooldown > 0.0:
		return
		
	# B Button or Start Button or Esc closes the menu
	var is_cancel = is_start_press
	if event is InputEventJoypadButton and event.button_index == JOY_BUTTON_B and event.pressed:
		is_cancel = true
	elif event.is_action_pressed("ui_cancel"):
		is_cancel = true
		
	if is_cancel:
		_safe_handle_input()
		close()
		return
		
	# Navigation Down (D-Pad Down, ui_down, S, Down arrow)
	var is_down = false
	if event is InputEventJoypadButton and event.button_index == JOY_BUTTON_DPAD_DOWN and event.pressed:
		is_down = true
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("move_backward"):
		is_down = true
		
	if is_down:
		_safe_handle_input()
		current_index = (current_index + 1) % menu_items.size()
		_highlight_current()
		input_cooldown = 0.16
		_play_sound("play_cursor")
		return
		
	# Navigation Up (D-Pad Up, ui_up, W, Up arrow)
	var is_up = false
	if event is InputEventJoypadButton and event.button_index == JOY_BUTTON_DPAD_UP and event.pressed:
		is_up = true
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("move_forward"):
		is_up = true
		
	if is_up:
		_safe_handle_input()
		current_index = (current_index - 1 + menu_items.size()) % menu_items.size()
		_highlight_current()
		input_cooldown = 0.16
		_play_sound("play_cursor")
		return
		
	# Adjust Left (D-Pad Left, ui_left, A, Left arrow)
	var is_left = false
	if event is InputEventJoypadButton and event.button_index == JOY_BUTTON_DPAD_LEFT and event.pressed:
		is_left = true
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("turn_left"):
		is_left = true
		
	if is_left:
		if current_index == 0:
			turn_slider.value = clampf(turn_slider.value - turn_slider.step, turn_slider.min_value, turn_slider.max_value)
			input_cooldown = 0.1
			_safe_handle_input()
		elif current_index == 1:
			cam_slider.value = clampf(cam_slider.value - cam_slider.step, cam_slider.min_value, cam_slider.max_value)
			input_cooldown = 0.1
			_safe_handle_input()
		return
		
	# Adjust Right (D-Pad Right, ui_right, D, Right arrow)
	var is_right = false
	if event is InputEventJoypadButton and event.button_index == JOY_BUTTON_DPAD_RIGHT and event.pressed:
		is_right = true
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("turn_right"):
		is_right = true
		
	if is_right:
		if current_index == 0:
			turn_slider.value = clampf(turn_slider.value + turn_slider.step, turn_slider.min_value, turn_slider.max_value)
			input_cooldown = 0.1
			_safe_handle_input()
		elif current_index == 1:
			cam_slider.value = clampf(cam_slider.value + cam_slider.step, cam_slider.min_value, cam_slider.max_value)
			input_cooldown = 0.1
			_safe_handle_input()
		return
		
	# Activate / Select (A Button, Enter, Space)
	var is_accept = false
	if event is InputEventJoypadButton and event.button_index == JOY_BUTTON_A and event.pressed:
		is_accept = true
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		is_accept = true
		
	if is_accept:
		_safe_handle_input()
		if current_index == 2:
			close()
		elif current_index == 3:
			_on_exit_hub_pressed()
		return

func open() -> void:
	is_open = true
	modal_panel.visible = true
	get_tree().paused = true
	input_cooldown = 0.22
	current_index = 0
	_highlight_current()
	_play_sound("play_cursor")
	menu_opened.emit()

func close() -> void:
	is_open = false
	modal_panel.visible = false
	get_tree().paused = false
	input_cooldown = 0.22
	SettingsScript.save_settings()
	settings_changed.emit()
	_play_sound("play_cancel")
	menu_closed.emit()

func _on_exit_hub_pressed() -> void:
	get_tree().paused = false
	_play_sound("play_confirm")
	get_tree().change_scene_to_file("res://scenes/launcher.tscn")

func _highlight_current() -> void:
	for i in range(menu_items.size()):
		var item = menu_items[i]
		if i == current_index:
			item.grab_focus()
			item.modulate = Color(1.25, 1.25, 1.0, 1.0)
		else:
			item.modulate = Color(1.0, 1.0, 1.0, 0.75)

func _on_turn_slider_changed(val: float) -> void:
	SettingsScript.turn_sensitivity = val
	_update_turn_label(val)
	SettingsScript.save_settings()
	settings_changed.emit()

func _update_turn_label(val: float) -> void:
	var desc = ""
	if val < 2.0:
		desc = " (遅)"
	elif val > 3.6:
		desc = " (速)"
	else:
		desc = " (標準)"
	turn_value_label.text = "%.1f%s" % [val, desc]

func _on_cam_slider_changed(val: float) -> void:
	SettingsScript.camera_smoothing = val
	_update_cam_label(val)
	SettingsScript.save_settings()
	settings_changed.emit()

func _update_cam_label(val: float) -> void:
	cam_value_label.text = "%.1f" % val

func _safe_handle_input() -> void:
	var vp = get_viewport()
	if vp:
		vp.set_input_as_handled()

func _play_sound(method_name: String) -> void:
	var sm = SoundManagerScript.get_instance()
	if sm and sm.has_method(method_name):
		sm.call(method_name)
