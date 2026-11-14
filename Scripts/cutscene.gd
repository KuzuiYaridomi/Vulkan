extends Node3D

signal finished

const CUES := [
	[0.6, "I don't honestly know why im here..", 3.1],
	[3.8, "I heard there's a portal that randomly spawns somewhere around here...", 3.3],
	[7.2, "Entering the portal is said to take you to heaven..", 3.0],
	[10.3, "I'm tired of this life.. maybe I'll go somewhere better?", 3.0],
]
const EYES_START := 13.4

@export var player_path: NodePath = ^"../Player"
@export var player_spawn := Vector3(2.9, 0.4, 262.0)
@export var ride_end_time: float = 15.0
@export var black_time: float = 15.8
@export var shake_strength: float = 0.012
@export var base_fov: float = 75.0
@export var speed_fov: float = 85.0

@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var rig: Node3D = $bikeonplayer
@onready var rider: Node3D = $bikeonplayer/Rider
@onready var cam: Camera3D = $bikeonplayer/Rider/Head/Camera3D
@onready var fade: ColorRect = $CutsceneUI/Fade
@onready var player: Node3D = get_node(player_path)
@onready var headlight: Light3D = get_node_or_null("bikeonplayer/Headlight")

@onready var eyelids: ColorRect = get_node_or_null("CutsceneUI/Eyelids")

var _swapped := false
var _done := false
var _cue := 0
var _eyes_started := false
var _eyes_tween: Tween
var _base_yaw := 0.0


func _ready() -> void:
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.visible = false
	cam.make_current()
	_base_yaw = rig.rotation.y
	if eyelids:
		eyelids.visible = false
	anim.animation_finished.connect(_on_animation_finished)
	anim.play("cutscene")


func _subs():
	return get_tree().get_first_node_in_group("subtitles")


func _process(_delta: float) -> void:
	if _swapped:
		return
	var t := anim.current_animation_position
	while _cue < CUES.size() and t >= CUES[_cue][0]:
		if _subs():
			_subs().say(CUES[_cue][1], CUES[_cue][2])
		_cue += 1
	if t >= EYES_START and not _eyes_started:
		_eyes_started = true
		_start_eyes()
	if t >= EYES_START and t < ride_end_time:
		var w := (t - EYES_START) / (ride_end_time - EYES_START)
		rig.rotation = Vector3(0.0, _base_yaw + sin(t * 6.5) * 0.14 * w, sin(t * 4.7) * 0.2 * w)
		cam.rotation.z = sin(t * 3.1) * 0.1 * w
	elif t >= ride_end_time:
		rig.rotation = Vector3(0.0, _base_yaw, 0.0)
		cam.rotation.z = 0.0
	if t < ride_end_time:
		var s := Time.get_ticks_msec() / 1000.0
		cam.position = Vector3(
			sin(s * 37.0) * 0.5 + sin(s * 23.0) * 0.5,
			sin(s * 41.0) + sin(s * 17.0) * 0.5,
			0.0) * shake_strength
		cam.fov = lerpf(base_fov, speed_fov, clampf(t / 2.0, 0.0, 1.0))
	else:
		cam.position = Vector3.ZERO
		if headlight:
			headlight.visible = t < ride_end_time + 0.45 and randf() > 0.45


func _unhandled_input(event: InputEvent) -> void:
	if not _done and event.is_action_pressed("skip_cutscene"):
		skip()


func skip() -> void:
	if _done:
		return
	_done = true
	print("Cutscene: skipped")
	anim.seek(black_time + 0.01, true)
	anim.pause()
	if headlight:
		headlight.visible = false
	if _subs():
		_subs().clear()
	_stop_eyes()
	swap_to_player()
	fade.color = Color(0, 0, 0, 1)
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 0.0, 0.5)
	tw.tween_callback(_finish)


func swap_to_player() -> void:
	if _swapped:
		return
	_swapped = true
	rider.visible = false
	player.global_position = player_spawn
	var look := rig.global_position
	look.y = player_spawn.y
	player.look_at(look, Vector3.UP)
	if player.has_node("Head"):
		player.get_node("Head").rotation = Vector3.ZERO
	player.visible = true
	var player_cam := player.get_node_or_null("Head/Camera3D") as Camera3D
	if player_cam:
		player_cam.make_current()
	print("Cutscene: bike crashed at %s, player spawned at %s" % [rig.global_position, player.global_position])


func _start_eyes() -> void:
	if eyelids == null:
		return
	eyelids.visible = true
	var mat := eyelids.material as ShaderMaterial
	mat.set_shader_parameter("open", 1.0)
	_eyes_tween = create_tween()
	var set_open := func(v: float): mat.set_shader_parameter("open", v)
	_eyes_tween.tween_method(set_open, 1.0, 0.08, 0.45).set_trans(Tween.TRANS_SINE)
	_eyes_tween.tween_interval(0.15)
	_eyes_tween.tween_method(set_open, 0.08, 0.75, 0.3).set_trans(Tween.TRANS_SINE)
	_eyes_tween.tween_method(set_open, 0.75, 0.0, 0.35).set_trans(Tween.TRANS_SINE)
	_eyes_tween.tween_interval(0.12)
	_eyes_tween.tween_method(set_open, 0.0, 1.0, 0.2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_eyes_tween.tween_callback(func(): eyelids.visible = false)


func _stop_eyes() -> void:
	if _eyes_tween and _eyes_tween.is_valid():
		_eyes_tween.kill()
	if eyelids:
		eyelids.visible = false
	rig.rotation = Vector3(0.0, _base_yaw, 0.0)
	cam.rotation.z = 0.0


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == &"cutscene":
		_finish()


func _finish() -> void:
	_done = true
	swap_to_player()
	player.process_mode = Node.PROCESS_MODE_INHERIT
	fade.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	set_process(false)
	set_process_unhandled_input(false)
	print("Cutscene: finished, player has control")
	finished.emit()
