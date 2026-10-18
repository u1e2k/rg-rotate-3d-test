class_name MainScene
extends Node3D

const SoundManagerScript = preload("res://scripts/sound_manager.gd")

@onready var sound_manager: Node = $SoundManager
@onready var hud_gem_label: Label = $HUD/MarginContainer/TopBar/GemBox/HBox/GemLabel
@onready var hud_time_label: Label = $HUD/MarginContainer/TopBar/TimeBox/HBox/TimeLabel
@onready var hud_fps_label: Label = $HUD/MarginContainer/TopBar/FpsLabel
@onready var clear_banner: Control = $HUD/ClearBanner
@onready var player: Node3D = $Player
@onready var collectibles_container: Node3D = $Environment/Collectibles

var total_gems: int = 0
var collected_gems: int = 0
var elapsed_time: float = 0.0
var is_cleared: bool = false

func _ready() -> void:
	# Setup collectibles count and signals
	total_gems = collectibles_container.get_child_count()
	for child in collectibles_container.get_children():
		if child.has_signal("collected"):
			child.connect("collected", _on_gem_collected)
	_update_hud()
	clear_banner.visible = false

func _process(delta: float) -> void:
	if not is_cleared:
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
