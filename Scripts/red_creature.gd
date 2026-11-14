extends CharacterBody3D

signal died_at(position: Vector3)

@export var max_health: int = 30
@export var damage: int = 2
@export var follow_speed: float = 6.5
@export var dive_speed: float = 12.0
@export var lunge_speed: float = 12.0
@export var behind_distance: float = 2.6
@export var hover_height: float = 1.9
@export var attack_interval := Vector2(3.0, 4.8)
@export var knockback: float = 0.35
@export var intro_turn_time: float = 1.0
@export var intro_hold_time: float = 1.8
@export var flank_radius: float = 3.4
@export var flank_time: float = 0.9
@export var portal_scene: PackedScene = preload("res://Scenes/end_portal.tscn")

@onready var body_mesh: MeshInstance3D = $Visual/Core
@onready var visual: Node3D = $Visual
@onready var wing_l: Node3D = $Visual/WingL
@onready var wing_r: Node3D = $Visual/WingR
@onready var shards: Node3D = $Visual/Shards
@onready var halo: MeshInstance3D = $Visual/Halo
@onready var glow: OmniLight3D = $Glow
@onready var hit_sound: AudioStreamPlayer3D = $HitSound
@onready var spawn_sound: AudioStreamPlayer3D = $SpawnSound

enum State { INTRO, FOLLOW, LUNGE, RETREAT, FLANK, DEAD }
var state := State.INTRO
var health: int
var _player: Node3D
var _attack_timer := 3.0
var _state_t := 0.0
var _lunge_target := Vector3.ZERO
var _hit_this_lunge := false
var _time := 0.0
var _mat: StandardMaterial3D
var _intro_started := false
var _flank_from := 0.0
var _flank_to := 0.0


func _ready() -> void:
	health = max_health
	add_to_group("zombie")
	add_to_group("creature")
	_mat = body_mesh.get_active_material(0).duplicate()
	body_mesh.set_surface_override_material(0, _mat)
	visual.scale = Vector3.ONE * 0.01
	create_tween().tween_property(visual, "scale", Vector3.ONE * 1.4, 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	spawn_sound.play()


func _physics_process(delta: float) -> void:
	_time += delta
	_animate(delta)
	if state == State.DEAD:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
	if _player == null or not _player.visible or _player.get("is_dead"):
		_hover_in_place(delta)
		return
	var head: Vector3 = _player.global_position + Vector3.UP * 1.6
	_state_t += delta
	match state:
		State.INTRO:
			if not _intro_started:
				_intro_started = true
				if _player.has_method("force_look_at"):
					_player.force_look_at(self, intro_turn_time + intro_hold_time)
			_hover_in_place(delta)
			if _state_t >= intro_turn_time + intro_hold_time:
				state = State.FOLLOW
				_state_t = 0.0
				_attack_timer = randf_range(attack_interval.x, attack_interval.y) + 1.0
				var tw := create_tween()
				tw.tween_property(visual, "scale", Vector3.ONE, 0.6)
				tw.parallel().tween_property(halo, "scale", Vector3.ZERO, 0.6)
				tw.tween_callback(halo.hide)
		State.FOLLOW:
			var back := _player.global_basis.z
			back.y = 0.0
			back = back.normalized()
			var side := Vector3(back.z, 0.0, -back.x)
			var target := _player.global_position + back * behind_distance + Vector3.UP * hover_height \
				+ side * sin(_time * 1.3) * 0.8 + Vector3.UP * sin(_time * 2.1) * 0.25
			var speed := dive_speed if global_position.distance_to(target) > 6.0 else follow_speed
			_fly_toward(target, speed, delta)
			_attack_timer -= delta
			if _attack_timer <= 0.0 and global_position.distance_to(head) < 9.0:
				_start_lunge(head)
		State.LUNGE:
			_lunge_target = _lunge_target.lerp(head, delta * 2.0)
			_fly_toward(_lunge_target, lunge_speed, delta)
			if not _hit_this_lunge and global_position.distance_to(head) < 1.1:
				_hit_this_lunge = true
				if _player.has_method("take_damage"):
					_player.take_damage(damage, "creature")
				_start_retreat()
			elif _state_t > 1.4:
				_start_retreat()
		State.RETREAT:
			var away := (global_position - head)
			away.y = 0.0
			_fly_toward(global_position + away.normalized() * 3.0 + Vector3.UP * 1.0, follow_speed, delta)
			if _state_t > 0.7:
				state = State.FOLLOW
				_state_t = 0.0
				_attack_timer = randf_range(attack_interval.x, attack_interval.y)
		State.FLANK:
			var k := smoothstep(0.0, 1.0, clampf(_state_t / flank_time, 0.0, 1.0))
			var ang := lerpf(_flank_from, _flank_to, k)
			var target := _player.global_position + Vector3(cos(ang), 0.0, sin(ang)) * flank_radius \
				+ Vector3.UP * (hover_height + sin(k * PI) * 1.2)
			_fly_toward(target, 16.0, delta)
			if _state_t >= flank_time:
				_start_lunge(head)
	if global_position.distance_to(head) > 0.2:
		look_at(head, Vector3.UP)


func _start_lunge(head: Vector3) -> void:
	state = State.LUNGE
	_state_t = 0.0
	_hit_this_lunge = false
	_lunge_target = head


func _start_retreat() -> void:
	state = State.RETREAT
	_state_t = 0.0


func _start_flank() -> void:
	var rel := global_position - _player.global_position
	_flank_from = atan2(rel.z, rel.x)
	_flank_to = _flank_from + PI * (1.0 if randf() < 0.5 else -1.0)
	state = State.FLANK
	_state_t = 0.0


func _fly_toward(target: Vector3, speed: float, delta: float) -> void:
	var to := target - global_position
	var step := minf(to.length(), speed * delta)
	if to.length() > 0.001:
		global_position += to.normalized() * step


func _hover_in_place(delta: float) -> void:
	global_position.y += sin(_time * 2.0) * 0.2 * delta


func _animate(delta: float) -> void:
	var flap := sin(_time * 14.0) * 0.6
	wing_l.rotation.z = flap
	wing_r.rotation.z = -flap
	shards.rotation.y += delta * 2.5
	shards.rotation.x = sin(_time * 0.7) * 0.4
	glow.light_energy = 2.2 + sin(_time * 6.0) * 0.6


func take_damage(amount: int) -> void:
	if state == State.DEAD:
		return
	health -= amount
	hit_sound.play()
	_mat.emission = Color(1, 1, 1)
	_mat.emission_energy_multiplier = 6.0
	var t := create_tween()
	t.tween_property(_mat, "emission", Color(1, 0.04, 0.02), 0.15)
	t.parallel().tween_property(_mat, "emission_energy_multiplier", 2.5, 0.15)
	if health <= 0:
		_die()
		return
	if _player and state != State.INTRO:
		global_position += (global_position - _player.global_position).normalized() * knockback
		_start_flank()
func _die() -> void:
	state = State.DEAD
	remove_from_group("zombie")
	$CollisionShape3D.set_deferred("disabled", true)
	var death_pos := global_position
	var t := create_tween()
	t.tween_property(visual, "scale", Vector3.ONE * 1.6, 0.15)
	t.parallel().tween_property(glow, "light_energy", 12.0, 0.15)
	t.tween_property(visual, "scale", Vector3.ONE * 0.01, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(glow, "light_energy", 0.0, 0.5)
	t.tween_callback(_open_portal.bind(death_pos))


func _open_portal(at: Vector3) -> void:
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.5, at + Vector3.DOWN * 30.0)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var ground: Vector3 = hit.position if not hit.is_empty() else Vector3(at.x, 0.0, at.z)
	var portal := portal_scene.instantiate() as Node3D
	get_parent().add_child(portal)
	portal.global_position = ground
	if _player:
		var face := _player.global_position
		face.y = ground.y
		if face.distance_to(ground) > 0.1:
			portal.look_at(face, Vector3.UP)
	died_at.emit(ground)
	queue_free()
