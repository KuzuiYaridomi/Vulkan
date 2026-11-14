extends Node3D

const PixelText := preload("res://Scripts/pixel_text.gd")
const MENU_SCENE := "res://Scenes/MainMenu.tscn"

@export var white_fade_time: float = 3.5
@export var line := "I found heaven... *dies*"
@export var hold_time: float = 4.0

@onready var area: Area3D = $Area3D
@onready var rift: Node3D = $Rift

var _triggered := false


func _ready() -> void:
	add_to_group("end_portal")
	area.body_entered.connect(_on_body_entered)
	rift.scale = Vector3(0.01, 0.01, 0.01)
	create_tween().tween_property(rift, "scale", Vector3.ONE, 1.2).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _on_body_entered(body: Node3D) -> void:
	if _triggered or not body.is_in_group("player") or body.get("is_dead"):
		return
	_triggered = true
	_play_ending(body)


func _play_ending(player: Node3D) -> void:
	add_to_group("ending_active")
	player.set("_invulnerable_until", 1.0e12)
	var pm = get_tree().get_first_node_in_group("pause_menu")
	if pm:
		pm.lock()
	player.process_mode = Node.PROCESS_MODE_DISABLED
	for z in get_tree().get_nodes_in_group("zombie"):
		z.process_mode = Node.PROCESS_MODE_DISABLED
	var spawner = get_tree().get_first_node_in_group("zombie_spawner")
	if spawner:
		spawner.enabled = false
	var subs = get_tree().get_first_node_in_group("subtitles")
	if subs:
		subs.clear()
		subs.hide_objective()

	var layer := CanvasLayer.new()
	layer.layer = 60
	add_child(layer)
	var white := ColorRect.new()
	white.color = Color(1, 1, 1, 0)
	white.set_anchors_preset(Control.PRESET_FULL_RECT)
	white.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(white)
	var text := PixelText.new()
	text.text = line
	text.font_size = 12
	text.pixel_scale = 3.0
	text.color = Color(0.02, 0.02, 0.02)
	text.outline_px = 0
	text.split_texels = 0.0
	text.reveal = 0.0
	text.set_anchors_preset(Control.PRESET_FULL_RECT)
	text.offset_top = 260.0
	text.offset_bottom = 260.0
	layer.add_child(text)

	var t := create_tween()
	t.tween_property(white, "color:a", 1.0, white_fade_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_interval(0.6)
	t.tween_property(text, "reveal", 1.0, line.length() / 18.0)
	t.tween_interval(hold_time)
	t.tween_callback(func(): SceneFader.fade_to_scene(MENU_SCENE, 1.5, 1.0))
	print("Ending: player entered the portal")
