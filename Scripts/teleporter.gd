extends Area3D

signal teleported(body: Node3D)

@export var destination: Node3D
@export var player_group: StringName = &"player"


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if destination == null or not body.is_in_group(player_group):
		return
	_teleport.call_deferred(body)


func _teleport(body: Node3D) -> void:
	body.global_position = destination.global_position
	body.global_rotation = Vector3(0.0, destination.global_rotation.y, 0.0)
	if body is CharacterBody3D:
		body.velocity = Vector3.ZERO
	if body.has_node("Head"):
		body.get_node("Head").rotation.x = 0.0
	print("Teleported %s to %s" % [body.name, destination.global_position])
	teleported.emit(body)
