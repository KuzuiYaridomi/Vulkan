extends Control

@export var color := Color(0.95, 0.95, 0.92, 0.9)
@export var outline := Color(0, 0, 0, 0.7)
@export var arm_length: float = 8.0
@export var gap: float = 6.0
@export var thickness: float = 2.0

var _spread := 0.0
var _armed := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_armed(armed: bool) -> void:
	_armed = armed
	queue_redraw()


func kick() -> void:
	_spread = 1.0


func _process(delta: float) -> void:
	if _spread > 0.0:
		_spread = maxf(_spread - delta * 4.0, 0.0)
		queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	if not _armed:
		draw_circle(c, 2.5, outline)
		draw_circle(c, 1.6, color)
		return
	var g := gap + 10.0 * _spread
	for d in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		var a: Vector2 = c + d * g
		var b: Vector2 = c + d * (g + arm_length)
		draw_line(a, b, outline, thickness + 2.0)
		draw_line(a, b, color, thickness)
	draw_circle(c, 1.4, color)
