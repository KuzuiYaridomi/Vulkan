extends CanvasLayer

const PixelText := preload("res://Scripts/pixel_text.gd")

@export var chars_per_second: float = 32.0
@export var base_hold: float = 1.6
@export var hold_per_char: float = 0.03

var _line
var _band: ColorRect
var _objective
var _queue: Array = []
var _current_left := 0.0
var _current_total := 0.0
var _typing := 0.0


func _ready() -> void:
	add_to_group("subtitles")
	layer = 7
	_band = ColorRect.new()
	_band.color = Color(0, 0, 0, 0.55)
	_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_band.anchor_left = 0.0
	_band.anchor_right = 1.0
	_band.anchor_top = 1.0
	_band.anchor_bottom = 1.0
	_band.offset_top = -128.0
	_band.offset_bottom = -78.0
	add_child(_band)
	_line = _make_pixel_text(10, 2.2, Color(0.95, 0.95, 0.9), false)
	_line.anchor_left = 0.0
	_line.anchor_right = 1.0
	_line.anchor_top = 1.0
	_line.anchor_bottom = 1.0
	_line.offset_top = -128.0
	_line.offset_bottom = -78.0
	add_child(_line)
	_objective = _make_pixel_text(9, 2.6, Color(0.68, 0.68, 0.66), true)
	_objective.anchor_left = 0.0
	_objective.anchor_top = 0.0
	_objective.offset_left = 22.0
	_objective.offset_top = 18.0
	_objective.offset_right = 900.0
	_objective.offset_bottom = 60.0
	add_child(_objective)
	_band.visible = false
	_line.visible = false
	_objective.visible = false


func _make_pixel_text(fs: int, px: float, col: Color, left: bool):
	var p := PixelText.new()
	p.font_size = fs
	p.pixel_scale = px
	p.color = col
	p.outline_px = 1
	p.split_texels = 0.4
	p.align_left = left
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func say(text: String, duration := -1.0, interrupt := false) -> float:
	if interrupt:
		clear()
	if duration <= 0.0:
		duration = text.length() / chars_per_second + base_hold + text.length() * hold_per_char
	_queue.append({"text": text, "duration": duration})
	var wait := _current_left
	for q in _queue:
		wait += q.duration
	return wait


func clear() -> void:
	_queue.clear()
	_current_left = 0.0
	_band.visible = false
	_line.visible = false


func show_objective(text: String) -> void:
	_objective.text = text
	_objective.visible = true
	_objective.modulate.a = 0.0
	_objective.set("glitch", 1.0)
	var t := create_tween()
	t.tween_property(_objective, "modulate:a", 1.0, 0.4)
	t.tween_callback(func(): _objective.set("glitch", 0.0))


func hide_objective() -> void:
	if not _objective.visible:
		return
	var t := create_tween()
	t.tween_property(_objective, "modulate:a", 0.0, 0.4)
	t.tween_callback(func(): _objective.visible = false)


func _process(delta: float) -> void:
	if _current_left > 0.0:
		_current_left -= delta
		_typing += delta
		_line.reveal = clampf(_typing * chars_per_second / maxf(float(_line.text.length()), 1.0), 0.0, 1.0)
		_line.modulate.a = clampf(_current_left / 0.3, 0.0, 1.0)
		_band.modulate.a = _line.modulate.a
		if _current_left <= 0.0:
			_line.visible = false
			_band.visible = false
	if _current_left <= 0.0 and not _queue.is_empty():
		var q: Dictionary = _queue.pop_front()
		_line.text = q.text
		_line.set("reveal", 0.0)
		_typing = 0.0
		_current_left = q.duration
		_current_total = q.duration
		_line.visible = true
		_band.visible = true
		_line.modulate.a = 1.0
		_band.modulate.a = 1.0
