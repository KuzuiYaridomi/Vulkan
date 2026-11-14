extends Node

@export var cutscene_path: NodePath = ^"../cutscene"
@export var player_path: NodePath = ^"../Player"
@export var portal_path: NodePath = ^"../teleporter1/TeleportArea"
@export var spawner_path: NodePath = ^"../ZombieSpawner"
@export var portal_look_dot: float = 0.93
@export var portal_look_range: float = 30.0
@export var portal_line_timeout: float = 10.0

@onready var cutscene = get_node_or_null(cutscene_path)
@onready var player = get_node_or_null(player_path)
@onready var portal = get_node_or_null(portal_path)
@onready var spawner = get_node_or_null(spawner_path)

var _watch_portal := false
var _portal_timer := 0.0
var _said_portal := false
var _teleported_once := false
var _gun_once := false
var _first_zombie := false
var _creature = null
var _said_creature := false
var _portal_open := false

@export var creature_scene: PackedScene = preload("res://Scenes/red_creature.tscn")
@export var kills_for_creature: int = 10


func _ready() -> void:
	if spawner:
		spawner.enabled = false
		spawner.spawned.connect(_on_zombie_spawned)
	if cutscene:
		cutscene.finished.connect(_on_wake_up)
	if portal:
		portal.teleported.connect(_on_teleported)
	if player:
		player.gun_equipped.connect(_on_gun_equipped)
		player.respawned.connect(_on_respawned)
		player.kills_changed.connect(_on_kills_changed)


func _subs():
	return get_tree().get_first_node_in_group("subtitles")


func _ending() -> bool:
	return get_tree().get_first_node_in_group("ending_active") != null


func _say(text: String, interrupt := false) -> float:
	if _ending():
		return 0.0
	var s = _subs()
	return s.say(text, -1.0, interrupt) if s else 0.0


func _on_wake_up() -> void:
	await get_tree().create_timer(0.8, false).timeout
	_say("Ah.... I want to go to heaven...")
	_watch_portal = true
	_portal_timer = 0.0


func _process(delta: float) -> void:
	_check_creature_seen()
	if not _watch_portal or player == null or portal == null:
		return
	_portal_timer += delta
	var cam := get_viewport().get_camera_3d()
	var looking := false
	if cam:
		var to_portal: Vector3 = portal.global_position - cam.global_position
		looking = to_portal.length() < portal_look_range and (-cam.global_basis.z).dot(to_portal.normalized()) > portal_look_dot
	if looking or _portal_timer >= portal_line_timeout:
		_watch_portal = false
		_said_portal = true
		_say("wtf? THE PORTAL? ITS REAL!!! I CANT WAIT TO GO TO HEL- I MEAN HEAVEN")


func _on_teleported(body: Node3D) -> void:
	if body != player or _teleported_once:
		return
	_teleported_once = true
	_watch_portal = false
	var s = _subs()
	if s:
		s.clear()
	var t: float = _say("wtf? I was supposed to be in heaven goddammit.")
	await get_tree().create_timer(t, false).timeout
	if not _gun_once and s:
		s.show_objective("GO TO A TABLE AND PICK THE SHOT GUN")


func _on_gun_equipped() -> void:
	if _gun_once:
		return
	_gun_once = true
	var s = _subs()
	if s:
		s.hide_objective()
	var t: float = _say("Why.... why am i forced to kill now suddenly?", true)
	await get_tree().create_timer(t, false).timeout
	if spawner and not _ending():
		spawner.enabled = true


func _on_zombie_spawned(_z: Node3D) -> void:
	if _first_zombie:
		return
	_first_zombie = true
	_say("NOOOOO I WANT HEAVEN. DIE ALL OF YOU", true)


func _on_kills_changed(kills: int) -> void:
	if _ending() or kills < kills_for_creature or _portal_open or (_creature and is_instance_valid(_creature)):
		return
	var back: Vector3 = player.global_basis.z
	back.y = 0.0
	_creature = creature_scene.instantiate()
	get_parent().add_child(_creature)
	_creature.global_position = player.global_position + back.normalized() * 10.0 + Vector3.UP * 14.0
	_creature.died_at.connect(_on_creature_died)
	print("Story: red creature spawned")


func _check_creature_seen() -> void:
	if _said_creature or _creature == null or not is_instance_valid(_creature):
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var to_c: Vector3 = _creature.global_position - cam.global_position
	if to_c.length() < 25.0 and (-cam.global_basis.z).dot(to_c.normalized()) > 0.9:
		_said_creature = true
		_say("Whats this? am i being scammed?", true)


func _on_creature_died(_at: Vector3) -> void:
	_portal_open = true
	_creature = null
	print("Story: creature killed, ending portal open")


func _on_respawned() -> void:
	var s = _subs()
	if s:
		s.clear()
	_say("dear god take me to heaven.", true)
