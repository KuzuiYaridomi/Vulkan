extends CharacterBody3D

signal health_changed(current: int, maximum: int)
signal died
signal respawned
signal gun_equipped
signal kills_changed(kills: int)

const NORMAL_DAMAGE := 1

@export_group("Health (half-hearts)")
@export var max_health: int = 10
@export var invulnerable_time: float = 0.8

@export_group("Speeds (m/s)")
@export var walk_speed: float = 4.0
@export var sprint_speed: float = 7.0
@export var crouch_speed: float = 2.0
@export var acceleration: float = 12.0
@export var air_control: float = 3.0
@export var jump_velocity: float = 4.5

@export_group("Body (m)")
@export var stand_height: float = 1.8
@export var crouch_height: float = 1.1
@export var radius: float = 0.4
@export var eye_offset: float = 0.2
@export var crouch_transition_speed: float = 10.0

@export_group("Mouse")
@export var mouse_sensitivity: float = 0.002
@export var max_pitch_deg: float = 89.0

@export_group("Interaction")
@export var interact_distance: float = 2.6
@export var pickup_scene: PackedScene = preload("res://Scenes/shotgun_pickup.tscn")
@export var footstep_clip_length: float = 1.0

const FOOTSTEP_MIN_SPEED := 1.0

@onready var collision: CollisionShape3D = $CollisionShape3D
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var head: Node3D = $Head

var _capsule: CapsuleShape3D
var _mesh: CapsuleMesh
var _current_height: float
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var health: int
var is_dead := false
var has_gun := false
var kills := 0
var last_damage_source := ""
var _invulnerable_until := 0.0
var _focused: Node = null
var _step_time := 0.0

@onready var shotgun: Node3D = get_node_or_null("Head/Camera3D/Shotgun")
@onready var crosshair: Control = get_node_or_null("HUD/Crosshair")
@onready var prompt_label: Label = get_node_or_null("HUD/Prompt")
@onready var footsteps: AudioStreamPlayer = get_node_or_null("Footsteps")
@onready var hurt_sound: AudioStreamPlayer = get_node_or_null("HurtSound")


func _ready() -> void:
	health = max_health
	health_changed.emit(health, max_health)
	if has_node("HUD"):
		$HUD.visible = visible
		visibility_changed.connect(func(): $HUD.visible = visible)

	_capsule = collision.shape.duplicate()
	collision.shape = _capsule
	_mesh = mesh_instance.mesh.duplicate()
	mesh_instance.mesh = _mesh
	_capsule.radius = radius
	_mesh.radius = radius
	_current_height = stand_height
	_apply_height(_current_height)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if shotgun:
		shotgun.set_equipped(false)
		shotgun.fired.connect(func(): if crosshair: crosshair.kick())
	if crosshair:
		crosshair.set_armed(false)
	if prompt_label:
		prompt_label.text = ""


func _unhandled_input(event: InputEvent) -> void:
	if is_dead:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clampf(head.rotation.x, deg_to_rad(-max_pitch_deg), deg_to_rad(max_pitch_deg))
	elif event.is_action_pressed("interact"):
		if _focused and is_instance_valid(_focused):
			_focused.interact(self)
	elif event.is_action_pressed("drop_weapon"):
		drop_gun()
	elif event.is_action_pressed("flashlight") and has_node("Head/Flashlight"):
		var light: SpotLight3D = $Head/Flashlight
		light.visible = not light.visible
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_K:
			take_damage(NORMAL_DAMAGE)
		elif event.physical_keycode == KEY_H:
			heal(NORMAL_DAMAGE)


func take_damage(amount: int = NORMAL_DAMAGE, source: String = "") -> bool:
	if is_dead or amount <= 0:
		return false
	var now := Time.get_ticks_msec() / 1000.0
	if now < _invulnerable_until:
		return false
	_invulnerable_until = now + invulnerable_time
	last_damage_source = source
	if hurt_sound:
		hurt_sound.pitch_scale = randf_range(0.95, 1.05)
		hurt_sound.play()
	health = maxi(health - amount, 0)
	health_changed.emit(health, max_health)
	if health == 0:
		_die()
	return true


func equip_gun() -> bool:
	if has_gun or shotgun == null:
		return false
	has_gun = true
	shotgun.set_equipped(true)
	if crosshair:
		crosshair.set_armed(true)
	gun_equipped.emit()
	return true


func drop_gun() -> void:
	if not has_gun or is_dead:
		return
	has_gun = false
	shotgun.set_equipped(false)
	if crosshair:
		crosshair.set_armed(false)
	var fwd := -global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var spot := global_position + fwd * 1.2 + Vector3.UP * 1.0
	var q := PhysicsRayQueryParameters3D.create(spot, spot + Vector3.DOWN * 4.0)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var drop := pickup_scene.instantiate() as Node3D
	get_parent().add_child(drop)
	drop.global_position = hit.position if not hit.is_empty() else global_position + fwd * 1.2
	drop.rotation.y = rotation.y + randf_range(-0.4, 0.4)


func _update_focus() -> void:
	var cam := get_viewport().get_camera_3d()
	var found: Node = null
	if cam and visible and not is_dead:
		var space := get_world_3d().direct_space_state
		var from := cam.global_position
		var to := from - cam.global_basis.z * interact_distance
		var qa := PhysicsRayQueryParameters3D.create(from, to)
		qa.collide_with_areas = true
		qa.collide_with_bodies = false
		var area_hit := space.intersect_ray(qa)
		if not area_hit.is_empty():
			var qb := PhysicsRayQueryParameters3D.create(from, to)
			qb.exclude = [get_rid()]
			var body_hit := space.intersect_ray(qb)
			var area_d := from.distance_to(area_hit.position)
			if body_hit.is_empty() or from.distance_to(body_hit.position) + 0.35 >= area_d:
				var n: Node = area_hit.collider
				while n and not n.is_in_group("interactable"):
					n = n.get_parent()
				found = n
	_focused = found
	if prompt_label:
		prompt_label.text = _focused.get_prompt() if _focused and not has_gun else ""
		if _focused and has_gun:
			prompt_label.text = "Already holding a shotgun  ·  [Q] drop"


func _update_footsteps(delta: float, horizontal_speed: float) -> void:
	if footsteps == null:
		return
	var walking := is_on_floor() and horizontal_speed > FOOTSTEP_MIN_SPEED
	if not walking:
		if footsteps.playing:
			footsteps.stop()
		_step_time = 0.0
		return
	_step_time += delta
	if not footsteps.playing or _step_time >= footstep_clip_length:
		_step_time = 0.0
		footsteps.play(0.0)
	footsteps.pitch_scale = 1.25 if horizontal_speed > walk_speed + 0.5 else (0.85 if _is_crouching() else 1.0)
	footsteps.volume_db = -14.0 if _is_crouching() else -6.0


func heal(amount: int) -> void:
	if is_dead or amount <= 0:
		return
	health = mini(health + amount, max_health)
	health_changed.emit(health, max_health)


func _die() -> void:
	is_dead = true
	velocity = Vector3.ZERO
	set_physics_process(false)
	if footsteps:
		footsteps.stop()
	if prompt_label:
		prompt_label.text = ""
	var t := create_tween()
	t.tween_property(head, "position:y", 0.35, 0.6).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(head, "rotation:z", deg_to_rad(75.0), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	died.emit()
	print("Player died")


func respawn() -> void:
	var rp := get_tree().get_first_node_in_group("respawn_point") as Node3D
	if rp:
		global_position = rp.global_position
		rotation = Vector3(0.0, rp.global_rotation.y, 0.0)
	head.rotation = Vector3.ZERO
	velocity = Vector3.ZERO
	_current_height = stand_height
	_apply_height(_current_height)
	for z in get_tree().get_nodes_in_group("zombie"):
		z.queue_free()
	kills = 0
	kills_changed.emit(kills)
	health = max_health
	is_dead = false
	_invulnerable_until = Time.get_ticks_msec() / 1000.0 + 2.0
	health_changed.emit(health, max_health)
	set_physics_process(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	respawned.emit()
	print("Player respawned at ", global_position)


func add_kill() -> void:
	kills += 1
	kills_changed.emit(kills)


func _physics_process(delta: float) -> void:
	_update_crouch(delta)

	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif Input.is_action_just_pressed("jump") and not _is_crouching():
		velocity.y = jump_velocity

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

	var speed := walk_speed
	if _is_crouching():
		speed = crouch_speed
	elif Input.is_action_pressed("sprint") and input_dir.y < 0.0:
		speed = sprint_speed

	var target := direction * speed
	var accel := acceleration if is_on_floor() else air_control
	velocity.x = lerpf(velocity.x, target.x, clampf(accel * delta, 0.0, 1.0))
	velocity.z = lerpf(velocity.z, target.z, clampf(accel * delta, 0.0, 1.0))

	move_and_slide()
	_update_footsteps(delta, Vector2(velocity.x, velocity.z).length())
	_update_focus()


func _is_crouching() -> bool:
	return Input.is_action_pressed("crouch") or _current_height < stand_height - 0.05


func _update_crouch(delta: float) -> void:
	var target_height := crouch_height if Input.is_action_pressed("crouch") else stand_height
	if target_height > _current_height and _ceiling_blocked(target_height):
		target_height = _current_height
	if is_equal_approx(target_height, _current_height):
		return
	_current_height = move_toward(_current_height, target_height,
		absf(stand_height - crouch_height) * crouch_transition_speed * delta * 0.5)
	_apply_height(_current_height)


func _ceiling_blocked(target_height: float) -> bool:
	return test_move(global_transform, Vector3.UP * (target_height - _current_height))


func _apply_height(h: float) -> void:
	_capsule.height = h
	_mesh.height = h
	collision.position.y = h * 0.5
	mesh_instance.position.y = h * 0.5
	head.position.y = h - eye_offset
