class_name VehicleInteractable
extends Interactable

@export var vehicle_node: Node3D

func _ready() -> void:
	super._ready()
	if not vehicle_node and get_parent() is Node3D:
		vehicle_node = get_parent()

func can_interact(_by_player: Node3D) -> bool:
	if vehicle_node and "is_boarded" in vehicle_node:
		return not vehicle_node.is_boarded
	return true

func _on_interacted(by_player: Node3D) -> void:
	if vehicle_node and vehicle_node.has_method("mount_player") and by_player is Player:
		vehicle_node.mount_player(by_player)
