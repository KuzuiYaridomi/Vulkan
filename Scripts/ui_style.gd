extends RefCounted


static func style_button(b: Button, font_size := 28) -> void:
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
	b.add_theme_font_size_override("font_size", font_size)
