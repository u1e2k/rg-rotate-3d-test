class_name Interactable
extends Area3D

signal interacted(by_player: Node3D)

@export var prompt_text: String = "[A] 調べる"
@export var is_interactive: bool = true

func _ready() -> void:
	collision_layer = 16 # Layer 5: Interactables
	collision_mask = 2   # Detects Player

func can_interact(_by_player: Node3D) -> bool:
	return is_interactive

func get_prompt() -> String:
	return prompt_text

func interact(by_player: Node3D) -> void:
	if not can_interact(by_player):
		return
	emit_signal("interacted", by_player)
	_on_interacted(by_player)

func _on_interacted(_by_player: Node3D) -> void:
	pass
