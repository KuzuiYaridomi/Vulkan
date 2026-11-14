extends Node3D

signal spawned(zombie: Node3D)

@export var enabled: bool = true:
	set(v):
		if v and not enabled:
			_timer = 1.5
		enabled = v
@export var zombie_scene: PackedScene = preload("res://Scenes/zombie_enemy.tscn")
@export var area_size := Vector2(80, 80)
@export var edge_margin: float = 5.0
@export var spawn_distance := Vector2(9.0, 15.0)
@export var first_spawn_delay: float = 4.0
@export var spawn_interval := Vector2(2.0, 4.0)
@export var max_alive: int = 8

var _timer := 0.0
var _player_was_inside := false
var _probe := CapsuleShape3D.new()


func _ready() -> void:
	add_to_group("zombie_spawner")
	_probe.radius = 0.4
	_probe.height = 1.8


func _process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null or not player.visible or player.get("is_dead"):
		return
	var inside := _inside(to_local(player.global_position), 0.0)
	if inside and not _player_was_inside:
		_timer = first_spawn_delay
	_player_was_inside = inside
	if not inside or not enabled:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = randf_range(spawn_interval.x, spawn_interval.y)
	if get_tree().get_nodes_in_group("enemy").size() >= max_alive:
		return
	var spot = _find_spot(player)
	if spot == null:
		return
	var z := zombie_scene.instantiate() as Node3D
	get_parent().add_child(z)
	z.global_position = spot
	z.look_at(Vector3(player.global_position.x, spot.y, player.global_position.z), Vector3.UP)
	spawned.emit(z)


func _inside(local: Vector3, margin: float) -> bool:
	return absf(local.x) <= area_size.x * 0.5 - margin and absf(local.z) <= area_size.y * 0.5 - margin


func _find_spot(player: Node3D):
	var space := get_world_3d().direct_space_state
	var forward := -player.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	for attempt in 12:
		var ang := randf() * TAU
		var dir := Vector3(cos(ang), 0.0, sin(ang))
		if attempt < 8 and dir.dot(forward) > 0.35:
			continue
		var p := player.global_position + dir * randf_range(spawn_distance.x, spawn_distance.y)
		var local := to_local(p)
		if not _inside(local, edge_margin):
			continue
		p.y = global_position.y + 0.1
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = _probe
		q.transform = Transform3D(Basis(), p + Vector3(0, 1.0, 0))
		if space.intersect_shape(q, 1).is_empty():
			return p
	return null
