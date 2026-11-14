extends CanvasLayer

const UIStyle := preload("res://Scripts/ui_style.gd")
const MENU_SCENE := "res://Scenes/MainMenu.tscn"

@export var band_height: float = 300.0

@onready var dim: ColorRect = $Dim
@onready var band: ColorRect = $Band
@onready var title: Control = $Title
@onready var buttons: Control = $Buttons
@onready var resume_button: Button = $Buttons/Resume
@onready var menu_button: Button = $Buttons/MainMenu
@onready var click_sound: AudioStreamPlayer = $ClickSound

var _open := false
var _leaving := false
var _grace := 1.0
var _was_captured := false
var _tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("pause_menu")
	visible = false
	for b in [resume_button, menu_button]:
		UIStyle.style_button(b, 26)
		b.mouse_entered.connect(func(): b.grab_focus())
	resume_button.pressed.connect(_on_resume)
	menu_button.pressed.connect(_to_main_menu)


func _player() -> Node:
	return get_tree().get_first_node_in_group("player")


func _can_pause() -> bool:
	if _leaving:
		return false
	var p = _player()
	if p and p.get("is_dead"):
		return false
	return true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _open:
			close()
		elif _can_pause():
			open()
		get_viewport().set_input_as_handled()


func _in_gameplay() -> bool:
	var p = _player()
	return p != null and p.visible and p.process_mode != Node.PROCESS_MODE_DISABLED


func _process(delta: float) -> void:
	_grace = maxf(_grace - delta, 0.0)
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if not _open and _grace <= 0.0 and _was_captured and not captured and _in_gameplay() and _can_pause():
		open()
	if not _open:
		_was_captured = captured


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and not _open and _grace <= 0.0 and _in_gameplay() and _can_pause():
		open()


func open() -> void:
	_open = true
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var vp := get_viewport().get_visible_rect().size
	dim.color.a = 0.0
	title.modulate.a = 0.0
	buttons.modulate.a = 0.0
	_set_line_width(0.0)
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(dim, "color:a", 0.4, 0.25)
	_tween.parallel().tween_method(_set_line_width, 0.0, vp.x, 0.3).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_tween.tween_method(_set_band_height, 4.0, band_height, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(func(): title.set("glitch", 1.0))
	_tween.tween_property(title, "modulate:a", 1.0, 0.1)
	_tween.parallel().tween_property(buttons, "modulate:a", 1.0, 0.2)
	_tween.tween_callback(_on_open_done)


func _on_open_done() -> void:
	title.set("glitch", 0.0)
	resume_button.grab_focus()


func close() -> void:
	if not _open:
		return
	_open = false
	if _tween and _tween.is_valid():
		_tween.kill()
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_grace = 0.3


func lock() -> void:
	_leaving = true
	if _open:
		close()


func _on_resume() -> void:
	_click()
	close()


func _to_main_menu() -> void:
	_click()
	_leaving = true
	get_tree().paused = false
	SceneFader.fade_to_scene(MENU_SCENE, 0.8, 0.8)


func _click() -> void:
	click_sound.play()


func _set_line_width(w: float) -> void:
	var vp := get_viewport().get_visible_rect().size
	band.size = Vector2(w, 4)
	band.position = Vector2((vp.x - w) * 0.5, vp.y * 0.5 - 2)


func _set_band_height(h: float) -> void:
	var vp := get_viewport().get_visible_rect().size
	band.size = Vector2(vp.x, h)
	band.position = Vector2(0, (vp.y - h) * 0.5)
