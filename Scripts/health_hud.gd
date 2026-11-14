extends Control

const FILL_TEX := preload("res://All_Assets/UI/heart_fill.png")
const OUTLINE_TEX := preload("res://All_Assets/UI/heart_outline.png")

@export var heart_size: float = 40.0
@export var spacing: float = 6.0
@export var full_color := Color(0.93, 0.93, 0.9)
@export var empty_color := Color(0.06, 0.06, 0.07)
@export var outline_color := Color(0.53, 0.53, 0.53)

var health: int = 10
var max_health: int = 10

var _shake := 0.0
var _flash := 0.0
var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var p := owner
	if p and p.has_signal("health_changed"):
		p.health_changed.connect(_on_health_changed)
	_update_min_size()


func _on_health_changed(current: int, maximum: int) -> void:
	if current < health:
		_shake = 0.3
		_flash = 0.35
	health = current
	max_health = maximum
	_update_min_size()
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	var animating := _shake > 0.0 or _flash > 0.0 or (health <= 2 and health > 0)
	_shake = maxf(_shake - delta, 0.0)
	_flash = maxf(_flash - delta, 0.0)
	if animating:
		queue_redraw()


func _draw() -> void:
	var hearts := int(ceil(max_health / 2.0))
	var offset := Vector2.ZERO
	if _shake > 0.0:
		offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 4.0 * (_shake / 0.3)
	var last_filled := int((health - 1) / 2.0)
	for i in hearts:
		var state := clampi(health - i * 2, 0, 2)
		var center := Vector2(i * (heart_size + spacing) + heart_size * 0.5, heart_size * 0.5) + offset
		var s := 1.0
		if health <= 2 and health > 0 and state > 0 and i == last_filled:
			s += 0.12 * maxf(sin(_time * 7.0), 0.0)
		_draw_heart(center, s, state)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_heart(center: Vector2, s: float, state: int) -> void:
	draw_set_transform(center, 0.0, Vector2(s, s))
	var rect := Rect2(Vector2(-heart_size, -heart_size) * 0.5, Vector2(heart_size, heart_size))
	var dark := empty_color
	if _flash > 0.0:
		dark = empty_color.lerp(Color(0.5, 0.5, 0.5), _flash / 0.35 * 0.5)
	draw_texture_rect(FILL_TEX, rect, false, dark)
	if state == 2:
		draw_texture_rect(FILL_TEX, rect, false, full_color)
	elif state == 1:
		var tex_size := FILL_TEX.get_size()
		var left := Rect2(rect.position, Vector2(rect.size.x * 0.5, rect.size.y))
		draw_texture_rect_region(FILL_TEX, left, Rect2(Vector2.ZERO, Vector2(tex_size.x * 0.5, tex_size.y)), full_color)
	draw_texture_rect(OUTLINE_TEX, rect, false, outline_color)


func _update_min_size() -> void:
	var hearts := int(ceil(max_health / 2.0))
	custom_minimum_size = Vector2(hearts * (heart_size + spacing) - spacing, heart_size)
	size = custom_minimum_size
