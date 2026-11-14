@tool
extends Node3D

@export_group("Pose (bike-local metres)")
@export var hip := Vector3(0.0, 0.82, 0.32):
	set(v):
		hip = v
		_queue_rebuild()
@export_range(0.0, 45.0) var torso_lean_deg: float = 15.0:
	set(v):
		torso_lean_deg = v
		_queue_rebuild()

@export_group("Body")
@export var torso_length: float = 0.95
@export var torso_radius: float = 0.24
@export var eye_from_hip: float = 0.78
@export var body_color := Color(0.25, 0.55, 0.95, 1)

@export_group("Look")
@export var mouse_look: bool = true
@export var mouse_sensitivity: float = 0.002
@export var max_yaw_deg: float = 110.0
@export var min_pitch_deg: float = -70.0
@export var max_pitch_deg: float = 60.0

@onready var head: Node3D = $Head

var _parts: Array[Node] = []
var _pending := false
var _yaw := 0.0
var _pitch := 0.0


func _ready() -> void:
	_rebuild()
	if not Engine.is_editor_hint():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not mouse_look:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw = clampf(_yaw - event.relative.x * mouse_sensitivity, deg_to_rad(-max_yaw_deg), deg_to_rad(max_yaw_deg))
		_pitch = clampf(_pitch - event.relative.y * mouse_sensitivity, deg_to_rad(min_pitch_deg), deg_to_rad(max_pitch_deg))
		head.basis = Basis.from_euler(Vector3(_pitch, _yaw, 0.0))
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _queue_rebuild() -> void:
	if not is_inside_tree() or _pending:
		return
	_pending = true
	_rebuild.call_deferred()


func _rebuild() -> void:
	_pending = false
	for p in _parts:
		if is_instance_valid(p):
			p.queue_free()
	_parts.clear()

	var mat := StandardMaterial3D.new()
	mat.albedo_color = body_color
	var lean := deg_to_rad(torso_lean_deg)
	var up := Vector3(0.0, cos(lean), -sin(lean))

	_limb(hip - up * 0.05, hip + up * (torso_length - 0.05), torso_radius, mat)

	if head:
		head.position = hip + up * eye_from_hip + Vector3(0.0, 0.0, -0.06)


func _limb(a: Vector3, b: Vector3, r: float, mat: Material) -> void:
	var axis := b - a
	var length := axis.length()
	if length < 0.001:
		return
	var mesh := CapsuleMesh.new()
	mesh.radius = r
	mesh.height = length + r * 2.0
	mesh.radial_segments = 16
	mesh.rings = 4
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var y := axis / length
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	mi.transform = Transform3D(Basis(x, y, z), (a + b) * 0.5)
	add_child(mi, false, Node.INTERNAL_MODE_BACK)
	_parts.append(mi)
