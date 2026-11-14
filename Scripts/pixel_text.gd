extends Control

const GLITCH_SHADER := preload("res://Scripts/pixel_glitch.gdshader")

@export var text := "TEXT":
	set(v):
		text = v
		_shown_text = v
		_refresh()
@export var font_size: int = 16
@export var pixel_scale: float = 6.0
@export var color := Color(0.94, 0.94, 0.9)
@export var outline_color := Color(0, 0, 0, 1)
@export var outline_px: int = 1
@export var split_texels: float = 1.0
@export var align_left: bool = false
@export_range(0.0, 1.0) var reveal: float = 1.0:
	set(v):
		reveal = v
		if _label:
			_label.visible_ratio = v
@export_group("Auto glitch")
@export var auto_glitch: bool = false
@export var glitch_interval := Vector2(1.2, 3.5)
@export var glitch_duration := Vector2(0.08, 0.3)
@export var corrupt_variants: PackedStringArray = PackedStringArray()

var glitch: float = 0.0:
	set(v):
		glitch = v
		if _mat:
			_mat.set_shader_parameter("glitch", v)

var _vp: SubViewport
var _label: Label
var _rect: TextureRect
var _mat: ShaderMaterial
var _shown_text := ""
var _next_burst := 1.0
var _burst_left := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vp = SubViewport.new()
	_vp.transparent_bg = true
	_vp.disable_3d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	_label = Label.new()
	var ls := LabelSettings.new()
	ls.font_size = font_size
	ls.font_color = color
	ls.outline_size = outline_px * 2
	ls.outline_color = outline_color
	_label.label_settings = ls
	_label.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	_label.visible_ratio = reveal
	_vp.add_child(_label)
	_rect = TextureRect.new()
	_rect.texture = _vp.get_texture()
	_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = GLITCH_SHADER
	_mat.set_shader_parameter("split", split_texels)
	_rect.material = _mat
	add_child(_rect)
	_shown_text = text
	resized.connect(_layout)
	_refresh()
	_next_burst = randf_range(glitch_interval.x, glitch_interval.y)


func _process(delta: float) -> void:
	if not auto_glitch:
		return
	_next_burst -= delta
	if _next_burst <= 0.0:
		_burst_left = randf_range(glitch_duration.x, glitch_duration.y)
		_next_burst = randf_range(glitch_interval.x, glitch_interval.y)
	if _burst_left > 0.0:
		_burst_left -= delta
		glitch = randf_range(0.5, 1.0)
		if not corrupt_variants.is_empty() and randf() < 0.35:
			_set_shown(corrupt_variants[randi() % corrupt_variants.size()])
		if _burst_left <= 0.0:
			glitch = 0.0
			_set_shown(text)
	elif randf() < 0.01:
		glitch = 0.15
	elif glitch > 0.0 and glitch < 0.2:
		glitch = 0.0


func _set_shown(s: String) -> void:
	if s == _shown_text:
		return
	_shown_text = s
	if _label:
		_label.text = s


func _refresh() -> void:
	if _label == null:
		return
	_label.text = _shown_text
	_label.reset_size()
	var pad := Vector2i(4, 2)
	var sz := Vector2i(_label.get_minimum_size().ceil()) + pad * 2
	_label.position = Vector2(pad)
	_vp.size = sz
	_layout()


func _layout() -> void:
	if _rect == null:
		return
	var s := Vector2(_vp.size) * pixel_scale
	_rect.size = s
	_rect.position = Vector2(0.0 if align_left else (size.x - s.x) * 0.5, (size.y - s.y) * 0.5)
