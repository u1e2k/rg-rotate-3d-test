class_name InteractiveTerminal
extends Interactable

const SoundManagerScript = preload("res://scripts/sound_manager.gd")

@export var is_active: bool = false

@onready var light: OmniLight3D = $TerminalLight
@onready var screen_mesh: MeshInstance3D = $Pedestal/Console/Screen
@onready var core_mesh: MeshInstance3D = $EnergyCore
@onready var status_label: Label3D = $StatusLabel

var base_core_y: float = 1.35
var anim_time: float = 0.0

func _ready() -> void:
	super._ready()
	_update_visuals(false)

func _process(delta: float) -> void:
	anim_time += delta * (4.5 if is_active else 1.2)
	core_mesh.rotation.y += delta * (3.0 if is_active else 0.8)
	core_mesh.rotation.x = sin(anim_time * 0.5) * 0.2
	core_mesh.position.y = base_core_y + sin(anim_time) * (0.12 if is_active else 0.04)

func _on_interacted(_by_player: Node3D) -> void:
	is_active = !is_active
	_update_visuals(true)
	
	var sm = SoundManagerScript.get_instance()
	if sm:
		sm.play_interact()

func _update_visuals(animate: bool) -> void:
	if is_active:
		prompt_text = "[A] コア停止 (OFF)"
		status_label.text = "● ONLINE\n720p SYS ACT"
		status_label.modulate = Color(0.2, 1.0, 0.8, 1.0)
	else:
		prompt_text = "[A] 電源起動 (ON)"
		status_label.text = "○ STANDBY\nPRESS [A]"
		status_label.modulate = Color(1.0, 0.35, 0.25, 1.0)
		
	var target_color = Color(0.1, 0.95, 0.8, 1.0) if is_active else Color(0.95, 0.2, 0.2, 1.0)
	var target_energy = 2.2 if is_active else 0.8
	
	if animate:
		var tween = create_tween().set_parallel(true)
		tween.tween_property(light, "light_color", target_color, 0.35)
		tween.tween_property(light, "light_energy", target_energy * 2.0, 0.15)
		tween.chain().tween_property(light, "light_energy", target_energy, 0.2)
		
		# Screen material pulse
		var mat = screen_mesh.get_active_material(0)
		if mat is StandardMaterial3D:
			var mat_copy = mat.duplicate() as StandardMaterial3D
			screen_mesh.set_surface_override_material(0, mat_copy)
			tween.tween_property(mat_copy, "emission", target_color, 0.3)
	else:
		light.light_color = target_color
		light.light_energy = target_energy
		var mat = screen_mesh.get_active_material(0)
		if mat is StandardMaterial3D:
			var mat_copy = mat.duplicate() as StandardMaterial3D
			mat_copy.emission = target_color
			screen_mesh.set_surface_override_material(0, mat_copy)
