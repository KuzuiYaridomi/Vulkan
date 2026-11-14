extends Node3D

@export var prompt := "[E]  Pick up shotgun"


func _ready() -> void:
	add_to_group("interactable")


func get_prompt() -> String:
	return prompt


func interact(player: Node) -> void:
	if player.has_method("equip_gun") and player.equip_gun():
		queue_free()
