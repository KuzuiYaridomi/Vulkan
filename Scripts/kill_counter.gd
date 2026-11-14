extends "res://Scripts/pixel_text.gd"


func _ready() -> void:
	super()
	visible = false
	var p := owner
	if p and p.has_signal("kills_changed"):
		p.kills_changed.connect(_on_kills)


func _on_kills(kills: int) -> void:
	visible = kills > 0
	text = "KILLS %d" % kills
	if kills > 0:
		pivot_offset = size * 0.5
		scale = Vector2(1.35, 1.35)
		glitch = 0.8
		var t := create_tween()
		t.tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(self, "glitch", 0.0, 0.3)
