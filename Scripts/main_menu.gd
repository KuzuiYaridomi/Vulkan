extends Control

const GAME_SCENE := "res://Scenes/MainScene.tscn"

@onready var play_button: Button = %PlayButton
@onready var howto_button: Button = %HowToButton
@onready var howto_popup: Control = %HowToPopup
@onready var close_button: Button = %CloseButton
@onready var click_sound: AudioStreamPlayer = %ClickSound

var _starting := false


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	howto_popup.visible = false
	for b in [play_button, howto_button, close_button]:
		_style_button(b)
		b.mouse_entered.connect(_on_hover.bind(b))
	play_button.pressed.connect(_on_play)
	howto_button.pressed.connect(_on_howto)
	close_button.pressed.connect(_close_howto)
	play_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and howto_popup.visible:
		_close_howto()
		get_viewport().set_input_as_handled()


func _style_button(b: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.0, 0.0, 0.0, 0.55)
	normal.border_color = Color(0.75, 0.75, 0.72)
	normal.set_border_width_all(2)
	normal.set_content_margin_all(12)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.9, 0.9, 0.86, 0.95)
	hover.border_color = Color(1, 1, 1)
	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.55, 0.55, 0.52, 1)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", hover)
	b.add_theme_color_override("font_color", Color(0.9, 0.9, 0.86))
	b.add_theme_color_override("font_hover_color", Color(0.02, 0.02, 0.02))
	b.add_theme_color_override("font_focus_color", Color(0.02, 0.02, 0.02))
	b.add_theme_color_override("font_pressed_color", Color(0.02, 0.02, 0.02))
	b.add_theme_font_size_override("font_size", 28)


func _on_hover(b: Button) -> void:
	if not _starting:
		b.grab_focus()


func _click() -> void:
	click_sound.pitch_scale = randf_range(0.95, 1.08)
	click_sound.play()


func _on_play() -> void:
	if _starting:
		return
	_starting = true
	_click()
	play_button.disabled = true
	howto_button.disabled = true
	SceneFader.fade_to_scene(GAME_SCENE, 1.25, 1.25)


func _on_howto() -> void:
	_click()
	howto_popup.visible = true
	close_button.grab_focus()


func _close_howto() -> void:
	_click()
	howto_popup.visible = false
	howto_button.grab_focus()
