extends CharacterBody3D

const ANIM_WALK := &"Armature|Walk2"
const ANIM_ATTACK := &"Armature|Attack"
const ANIM_DIE := &"Armature|Die2"
const WALK_CYCLE_SPEED := 0.54

@export var max_health: int = 6
@export var move_speed: float = 1.25
@export var attack_range: float = 1.4
@export var hit_range: float = 1.9
@export var attack_speed: float = 1.6
@export var attack_hit_point: float = 0.5
@export var damage: int = 1
@export var corpse_time: float = 8.0

@onready var anim: AnimationPlayer = $Model/AnimationPlayer
@onready var hit_sound: AudioStreamPlayer3D = $HitSound
@onready var collision: CollisionShape3D = $CollisionShape3D

enum State { CHASE, ATTACK, DEAD }
var state := State.CHASE
var health: int
var _player: Node3D
var _attack_t := 0.0
var _attack_len := 1.0
var _attack_dealt := false
var _stagger := 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

static var _anims_prepared := false


func _ready() -> void:
	health = max_health
	add_to_group("enemy")
	add_to_group("zombie")
	_prepare_animations(anim)
	_attack_len = anim.get_animation(ANIM_ATTACK).length / attack_speed
	anim.play(ANIM_WALK, 0.2, move_speed / WALK_CYCLE_SPEED)


static func _prepare_animations(ap: AnimationPlayer) -> void:
	if _anims_prepared:
		return
	_anims_prepared = true
	var walk := ap.get_animation(ANIM_WALK)
	walk.loop_mode = Animation.LOOP_LINEAR
	for t in walk.get_track_count():
		if str(walk.track_get_path(t)).ends_with("mixamorig_Hips") and walk.track_get_type(t) == Animation.TYPE_POSITION_3D:
			var z0: float = (walk.track_get_key_value(t, 0) as Vector3).z
			for k in walk.track_get_key_count(t):
				var v: Vector3 = walk.track_get_key_value(t, k)
				walk.track_set_key_value(t, k, Vector3(v.x, v.y, z0))


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if global_position.y < -20.0:
		queue_free()
		return
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0

	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
	var player_ok: bool = _player != null and _player.visible and not _player.get("is_dead")

	var to_player := Vector3.ZERO
	var dist := INF
	if player_ok:
		to_player = _player.global_position - global_position
		to_player.y = 0.0
		dist = to_player.length()
		if dist > 0.01:
			_face(to_player, delta)

	match state:
		State.CHASE:
			_stagger = maxf(_stagger - delta, 0.0)
			if player_ok and dist <= attack_range:
				_start_attack()
			elif player_ok:
				var dir := to_player.normalized()
				if is_on_wall():
					dir = (dir + get_wall_normal().cross(Vector3.UP) * 0.8).normalized()
				var spd := move_speed * (0.35 if _stagger > 0.0 else 1.0)
				velocity.x = dir.x * spd
				velocity.z = dir.z * spd
				if anim.current_animation != ANIM_WALK:
					anim.play(ANIM_WALK, 0.25, move_speed / WALK_CYCLE_SPEED)
			else:
				velocity.x = 0.0
				velocity.z = 0.0
		State.ATTACK:
			velocity.x = 0.0
			velocity.z = 0.0
			_attack_t += delta
			if not _attack_dealt and _attack_t >= _attack_len * attack_hit_point:
				_attack_dealt = true
				if player_ok and dist <= hit_range and _player.has_method("take_damage"):
					_player.take_damage(damage)
			if _attack_t >= _attack_len:
				state = State.CHASE
	move_and_slide()


func _face(dir: Vector3, delta: float) -> void:
	var target_yaw := atan2(-dir.x, -dir.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, clampf(delta * 8.0, 0.0, 1.0))


func _start_attack() -> void:
	state = State.ATTACK
	_attack_t = 0.0
	_attack_dealt = false
	anim.play(ANIM_ATTACK, 0.15, attack_speed)


func take_damage(amount: int) -> void:
	if state == State.DEAD:
		return
	health -= amount
	hit_sound.pitch_scale = randf_range(0.9, 1.1)
	hit_sound.play()
	_stagger = 0.35
	if health <= 0:
		_die()


func _die() -> void:
	state = State.DEAD
	remove_from_group("enemy")
	var p := get_tree().get_first_node_in_group("player")
	if p and p.has_method("add_kill"):
		p.add_kill()
	collision.set_deferred("disabled", true)
	anim.play(ANIM_DIE, 0.1, 1.0)
	get_tree().create_timer(corpse_time).timeout.connect(queue_free)
