extends CanvasLayer

const UIStyle := preload("res://Scripts/ui_style.gd")
const MENU_SCENE := "res://Scenes/MainMenu.tscn"

@export var respawn_time: float = 4.0
@export var band_height: float = 330.0
@export var bar_blocks: int = 24

@onready var dim: ColorRect = $Dim
@onready var band: ColorRect = $Band
@onready var you_died: Control = $YouDied
@onready var restart_label: Control = $Restarting
@onready var bar: Control = $Bar
@onready var killed_by: Control = $KilledBy
@onready var him: Control = $Him
@onready var title_button: Button = $TitleButton

var _progress := 0.0
var _running := false


func _ready() -> void:
	visible = false
	bar.draw.connect(_draw_bar)
	UIStyle.style_button(title_button, 24)
	title_button.pressed.connect(_to_title)
	for c in [killed_by, him, title_button]:
		c.visible = false
	var p := owner
	if p and p.has_signal("died"):
		p.died.connect(_on_died)


func _on_died() -> void:
	if _running:
		return
	if owner and owner.get("last_damage_source") == "creature":
		_killed_by_him()
		return
	_running = true
	visible = true
	for c in [you_died, restart_label, bar]:
		c.visible = true
	for c in [killed_by, him, title_button]:
		c.visible = false
	_progress = 0.0
	var vp := get_viewport().get_visible_rect().size
	dim.color.a = 0.0
	band.size = Vector2(0, 4)
	band.position = Vector2(vp.x * 0.5, vp.y * 0.5 - 2)
	for c in [you_died, restart_label, bar]:
		c.modulate.a = 0.0
	bar.queue_redraw()

	var t := create_tween()
	t.tween_property(dim, "color:a", 0.45, 0.6)
	t.parallel().tween_method(_set_line_width, 0.0, vp.x, 0.45).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t.tween_method(_set_band_height, 4.0, band_height, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_callback(func(): you_died.set("glitch", 1.0))
	t.tween_property(you_died, "modulate:a", 1.0, 0.15)
	t.tween_interval(0.35)
	t.tween_callback(func(): you_died.set("glitch", 0.0))
	t.tween_property(restart_label, "modulate:a", 1.0, 0.3)
	t.parallel().tween_property(bar, "modulate:a", 1.0, 0.3)
	t.tween_method(_set_progress, 0.0, 1.0, respawn_time)
	t.tween_callback(_respawn)
	for c in [dim, band, you_died, restart_label, bar]:
		t.parallel().tween_property(c, "modulate:a", 0.0, 0.6)
	t.tween_callback(_finish)


func _killed_by_him() -> void:
	_running = true
	visible = true
	_progress = 0.0
	bar.queue_redraw()
	title_button.visible = false
	you_died.visible = false
	for c in [killed_by, him, restart_label, bar]:
		c.visible = true
		c.modulate.a = 0.0
	var vp := get_viewport().get_visible_rect().size
	dim.color.a = 0.0
	_set_line_width(0.0)
	var t := create_tween()
	t.tween_property(dim, "color:a", 0.6, 0.8)
	t.parallel().tween_method(_set_line_width, 0.0, vp.x, 0.5).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t.tween_method(_set_band_height, 4.0, band_height, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(killed_by, "modulate:a", 1.0, 0.4)
	t.tween_interval(0.4)
	t.tween_callback(func(): him.set("glitch", 1.0))
	t.tween_property(him, "modulate:a", 1.0, 0.1)
	t.tween_interval(0.6)
	t.tween_property(restart_label, "modulate:a", 1.0, 0.3)
	t.parallel().tween_property(bar, "modulate:a", 1.0, 0.3)
	t.tween_method(_set_progress, 0.0, 1.0, respawn_time)
	t.tween_callback(_respawn)
	for c in [dim, band, killed_by, him, restart_label, bar]:
		t.parallel().tween_property(c, "modulate:a", 0.0, 0.6)
	t.tween_callback(_finish)


func _show_cursor() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	title_button.grab_focus()


func _to_title() -> void:
	title_button.disabled = true
	SceneFader.fade_to_scene(MENU_SCENE, 1.0, 1.0)


func _set_line_width(w: float) -> void:
	var vp := get_viewport().get_visible_rect().size
	band.size = Vector2(w, 4)
	band.position = Vector2((vp.x - w) * 0.5, vp.y * 0.5 - 2)


func _set_band_height(h: float) -> void:
	var vp := get_viewport().get_visible_rect().size
	band.size = Vector2(vp.x, h)
	band.position = Vector2(0, (vp.y - h) * 0.5)


func _set_progress(v: float) -> void:
	_progress = v
	bar.queue_redraw()


func _draw_bar() -> void:
	var gap := 3.0
	var w := (bar.size.x - gap * (bar_blocks - 1)) / bar_blocks
	var filled := int(floor(_progress * bar_blocks + 0.0001))
	for i in bar_blocks:
		var r := Rect2(Vector2(i * (w + gap), 0), Vector2(w, bar.size.y))
		if i < filled:
			bar.draw_rect(r, Color(0.93, 0.93, 0.9))
		else:
			bar.draw_rect(r, Color(0.08, 0.08, 0.09))
			bar.draw_rect(r, Color(0.45, 0.45, 0.45), false, 1.0)


func _respawn() -> void:
	if owner and owner.has_method("respawn"):
		owner.respawn()


func _finish() -> void:
	visible = false
	_running = false
	for c in [dim, band, you_died, restart_label, bar]:
		c.modulate.a = 1.0
