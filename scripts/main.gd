class_name MainScene
extends Node3D

const SoundManagerScript = preload("res://scripts/sound_manager.gd")
const SettingsScript = preload("res://scripts/settings_manager.gd")

@onready var sound_manager: Node = $SoundManager
@onready var hud_gem_label: Label = $HUD/MarginContainer/TopBar/GemBox/HBox/GemLabel
@onready var hud_time_label: Label = $HUD/MarginContainer/TopBar/TimeBox/HBox/TimeLabel
@onready var hud_fps_label: Label = $HUD/MarginContainer/TopBar/FpsLabel
@onready var clear_banner: Control = $HUD/ClearBanner
@onready var player: Node3D = $Player
@onready var collectibles_container: Node3D = $Environment/Collectibles

# Settings Menu references
@onready var settings_menu: Control = $HUD/SettingsMenu
@onready var turn_slider: HSlider = $HUD/SettingsMenu/Center/Panel/Margin/VBox/TurnSetting/HBox/TurnSlider
@onready var turn_value_label: Label = $HUD/SettingsMenu/Center/Panel/Margin/VBox/TurnSetting/HBox/TurnValueLabel
@onready var cam_slider: HSlider = $HUD/SettingsMenu/Center/Panel/Margin/VBox/CamSetting/HBox/CamSlider
@onready var cam_value_label: Label = $HUD/SettingsMenu/Center/Panel/Margin/VBox/CamSetting/HBox/CamValueLabel
@onready var close_btn: Button = $HUD/SettingsMenu/Center/Panel/Margin/VBox/CloseButton

var total_gems: int = 0
var collected_gems: int = 0
var elapsed_time: float = 0.0
var is_cleared: bool = false
var is_menu_open: bool = false

func _ready() -> void:
	SettingsScript.load_settings()
	_setup_settings_ui()
	
	# Setup collectibles count and signals
	total_gems = collectibles_container.get_child_count()
	for child in collectibles_container.get_children():
		if child.has_signal("collected"):
			child.connect("collected", _on_gem_collected)
	_update_hud()
	clear_banner.visible = false
	settings_menu.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_menu"):
		toggle_settings_menu()
		get_viewport().set_input_as_handled()
	elif is_menu_open and event.is_action_pressed("ui_cancel"):
		toggle_settings_menu()
		get_viewport().set_input_as_handled()

func _setup_settings_ui() -> void:
	turn_slider.value = SettingsScript.turn_sensitivity
	_update_turn_label(turn_slider.value)
	turn_slider.value_changed.connect(_on_turn_slider_changed)
	
	cam_slider.value = SettingsScript.camera_smoothing
	_update_cam_label(cam_slider.value)
	cam_slider.value_changed.connect(_on_cam_slider_changed)
	
	close_btn.pressed.connect(toggle_settings_menu)

func toggle_settings_menu() -> void:
	is_menu_open = !is_menu_open
	settings_menu.visible = is_menu_open
	get_tree().paused = is_menu_open
	
	var sm = SoundManagerScript.get_instance()
	if sm:
		sm.play_coin()
		
	if is_menu_open:
		turn_slider.grab_focus()
	else:
		SettingsScript.save_settings()
		if player and player.has_method("apply_settings"):
			player.apply_settings()

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
	
	hud_fps_label.text = "%d FPS" % Engine.get_frames_per_second()

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
