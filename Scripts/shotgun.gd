extends Node3D

signal fired

@export var pellets: int = 8
@export var spread_deg: float = 4.5
@export var range_m: float = 60.0
@export var pellet_damage: int = 1
@export var fire_cooldown: float = 0.95
@export var pump_delay: float = 0.32

@export_group("Feel")
@export var recoil_kick := Vector3(0.0, 0.012, 0.07)
@export var recoil_rise_deg: float = 16.0
@export var camera_kick_deg: float = 3.5
@export var flash_time: float = 0.06
@export var flash_light_energy: float = 9.0

@onready var model: Node3D = $Model
@onready var muzzle: Node3D = $Muzzle
@onready var flash_front: MeshInstance3D = $Muzzle/FlashFront
@onready var flash_side: MeshInstance3D = $Muzzle/FlashSide
@onready var flash_light: OmniLight3D = $Muzzle/FlashLight
@onready var shoot_sound: AudioStreamPlayer = $ShootSound
@onready var pump_sound: AudioStreamPlayer = $PumpSound

var _rest_pos: Vector3
var _rest_rot: Vector3
var _recoil := 0.0
var _cam_kick := 0.0
var _shake := 0.0
var _flash_left := 0.0
var _flash_frames := 0
var _next_shot_time := 0.0
var _was_captured := false
var _pump_tween: Tween


var equipped := false


func _ready() -> void:
	_rest_pos = position
	_rest_rot = rotation
	_set_flash(false)
	set_equipped(equipped)


func set_equipped(on: bool) -> void:
	equipped = on
	visible = on
	_recoil = 0.0
	if on:
		_next_shot_time = Time.get_ticks_msec() / 1000.0 + 0.35
		var t := create_tween()
		model.position = Vector3(0.0, -0.12, 0.05)
		model.rotation.x = deg_to_rad(-25.0)
		t.tween_property(model, "position", Vector3.ZERO, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(model, "rotation:x", 0.0, 0.3)
	else:
		_set_flash(false)
		if _pump_tween and _pump_tween.is_valid():
			_pump_tween.kill()
		pump_sound.stop()


func _process(delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if equipped and captured and _was_captured and Input.is_action_just_pressed("shoot") and now >= _next_shot_time and _can_shoot():
		_fire(now)
	_was_captured = captured

	if _flash_frames > 0 or _flash_left > 0.0:
		_flash_left -= delta
		_flash_frames -= 1
		flash_light.light_energy = flash_light_energy * clampf(maxf(_flash_left / flash_time, 0.5), 0.0, 1.0)
		if _flash_left <= 0.0 and _flash_frames <= 0:
			_set_flash(false)

	_recoil = move_toward(_recoil, 0.0, delta * 5.0)
	var r := ease(_recoil, 0.4)
	position = _rest_pos + recoil_kick * r
	rotation = _rest_rot + Vector3(deg_to_rad(recoil_rise_deg) * r, 0.0, 0.0)

	var cam := get_parent() as Node3D
	if cam:
		_cam_kick = move_toward(_cam_kick, 0.0, delta * deg_to_rad(camera_kick_deg) * 6.0)
		_shake = maxf(_shake - delta, 0.0)
		var sh := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0.0) * 0.004 * (_shake / 0.15)
		cam.rotation = Vector3(_cam_kick, 0.0, 0.0)
		cam.position = sh


func _can_shoot() -> bool:
	var p = owner
	return p == null or (not p.get("is_dead") and not (p.has_method("is_forced_look") and p.is_forced_look()))


func _fire(now: float) -> void:
	_next_shot_time = now + fire_cooldown
	shoot_sound.pitch_scale = randf_range(0.95, 1.05)
	shoot_sound.play()
	_muzzle_flash()
	_recoil = 1.0
	_cam_kick = deg_to_rad(camera_kick_deg)
	_shake = 0.15
	_cast_pellets()
	fired.emit()
	_pump()


func _muzzle_flash() -> void:
	_flash_left = flash_time
	_flash_frames = 2
	_set_flash(true)
	flash_front.rotation.z = randf() * TAU
	var s := randf_range(0.85, 1.25)
	flash_front.scale = Vector3(s, s, s)
	flash_side.scale = Vector3(randf_range(0.9, 1.3), randf_range(0.8, 1.1), 1.0)
	flash_light.light_energy = flash_light_energy


func _set_flash(on: bool) -> void:
	flash_front.visible = on
	flash_side.visible = on
	flash_light.visible = on


func _pump() -> void:
	if _pump_tween and _pump_tween.is_valid():
		_pump_tween.kill()
	_pump_tween = create_tween()
	_pump_tween.tween_interval(pump_delay)
	_pump_tween.tween_callback(func(): pump_sound.play())
	_pump_tween.tween_property(model, "position", model.position + Vector3(0.0, -0.025, 0.035), 0.14) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_pump_tween.parallel().tween_property(model, "rotation:z", model.rotation.z + deg_to_rad(12.0), 0.14)
	_pump_tween.tween_property(model, "position", model.position, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_pump_tween.parallel().tween_property(model, "rotation:z", model.rotation.z, 0.2)


func _cast_pellets() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var space := get_world_3d().direct_space_state
	var origin := cam.global_position
	var forward := -cam.global_basis.z
	var right := cam.global_basis.x
	var up := cam.global_basis.y
	var exclude: Array[RID] = []
	if owner is CollisionObject3D:
		exclude.append((owner as CollisionObject3D).get_rid())
	var hits := {}
	for i in pellets:
		var a := randf() * TAU
		var r := sqrt(randf()) * tan(deg_to_rad(spread_deg))
		var dir := (forward + (right * cos(a) + up * sin(a)) * r).normalized()
		var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * range_m)
		q.exclude = exclude
		q.collision_mask = 1 | 2
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			continue
		var target: Object = hit.collider
		if not target.has_method("take_damage") and target is Node and (target as Node).get_parent() and (target as Node).get_parent().has_method("take_damage"):
			target = (target as Node).get_parent()
		if target.has_method("take_damage"):
			hits[target] = hits.get(target, 0) + pellet_damage
	for t in hits:
		t.take_damage(hits[t])
