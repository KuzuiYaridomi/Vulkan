@tool
extends Node3D

const TREE_LIBRARY := preload("res://Scenes/Trees.tscn")

@export var regenerate: bool = false:
	set(v):
		_queue_rebuild()
@export var area_seed: int = 7:
	set(v):
		area_seed = v
		_queue_rebuild()
@export var size := Vector2(80, 80)

@export_group("Trees")
@export var tree_spacing: float = 12.0
@export var shrub_spacing: float = 7.0
@export var edge_tree_line: bool = true
@export var edge_spacing: float = 5.0
@export_range(1, 6) var variants_per_type: int = 3
@export var view_distance: float = 100.0

@export_group("Clearing")
@export var clear_around: Node3D
@export var clear_radius: float = 7.0

@export_group("Boundary")
@export var wall_height: float = 30.0
@export var wall_thickness: float = 1.0

@export_group("Boundary Fog")
@export var fog_wall: bool = true
@export var fog_layers: PackedFloat32Array = PackedFloat32Array([-2.0, 1.5, 5.0, 10.0, 16.0])
@export var fog_height: float = 18.0
@export var fog_color := Color(0.17, 0.175, 0.19)
@export_range(0.0, 1.0) var fog_density: float = 0.7

const FOG_SHADER := preload("res://Scripts/fog_wall.gdshader")

var _pending := false
var _generated: Array[Node] = []
var _rng := RandomNumberGenerator.new()
var _entries: Array = []
var _kinds: Dictionary = {}
var _instances: Dictionary = {}
var _colliders: Array = []


func _ready() -> void:
	_rebuild()


func _queue_rebuild() -> void:
	if not is_inside_tree() or _pending:
		return
	_pending = true
	_rebuild.call_deferred()


func _rebuild() -> void:
	_pending = false
	for n in _generated:
		if is_instance_valid(n):
			n.queue_free()
	_generated.clear()
	_entries.clear()
	_kinds.clear()
	_instances.clear()
	_colliders.clear()
	_rng.seed = area_seed

	var lib := TREE_LIBRARY.instantiate()
	_add_kind("oak", [lib.get_node("Oak_A"), lib.get_node("Oak_B")], true)
	_add_kind("birch", [lib.get_node("Birch_A"), lib.get_node("Birch_B")], true)
	_add_kind("weeping", [lib.get_node("Weeping")], true)
	_add_kind("shrub", [lib.get_node("Shrub")], false)
	lib.free()

	var count := _scatter()
	_build_multimeshes()
	_build_boundary()
	if fog_wall:
		_build_fog_wall()
	if not Engine.is_editor_hint():
		_build_tree_collision()
	print("TreeArea '%s': %d trees/shrubs in %.0f x %.0f m, boundary walls up" % [name, count, size.x, size.y])


func _add_kind(kind: String, templates: Array, collide: bool) -> void:
	var list: Array[int] = []
	for t in templates:
		var base_seed: int = t.tree_seed
		for v in variants_per_type:
			t.tree_seed = base_seed + v * 131 + area_seed
			list.append(_entries.size())
			_entries.append({"mesh": t.generate_mesh(), "radius": t.trunk_radius, "collide": collide})
		t.tree_seed = base_seed
	_kinds[kind] = list


func _scatter() -> int:
	var count := 0
	var half := size * 0.5
	var inset := wall_thickness + 1.5

	count += _grid(tree_spacing, 0.85, half - Vector2(inset + edge_spacing, inset + edge_spacing), _pick_tree)
	count += _grid(shrub_spacing, 0.45, half - Vector2(inset, inset), _pick_shrub)

	if edge_tree_line:
		var e := half - Vector2(inset, inset)
		for side in 4:
			var along := e.x if side < 2 else e.y
			var d := -along
			while d <= along:
				var p: Vector2
				match side:
					0: p = Vector2(d, -e.y)
					1: p = Vector2(d, e.y)
					2: p = Vector2(-e.x, d)
					3: p = Vector2(e.x, d)
				p += Vector2(_rng.randf_range(-1.5, 1.5), _rng.randf_range(-1.5, 1.5))
				if _try_place("oak" if _rng.randf() < 0.55 else "birch", p):
					count += 1
				d += edge_spacing * _rng.randf_range(0.8, 1.2)
	return count


func _pick_tree() -> String:
	var r := _rng.randf()
	return "oak" if r < 0.45 else ("birch" if r < 0.8 else "weeping")


func _pick_shrub() -> String:
	return "shrub"


func _grid(spacing: float, chance: float, half: Vector2, pick: Callable) -> int:
	var count := 0
	var z := -half.y
	while z <= half.y:
		var x := -half.x
		while x <= half.x:
			if _rng.randf() < chance:
				var p := Vector2(x, z) + Vector2(_rng.randf_range(-0.4, 0.4), _rng.randf_range(-0.4, 0.4)) * spacing
				if _try_place(pick.call(), p):
					count += 1
			x += spacing
		z += spacing
	return count


func _try_place(kind: String, p: Vector2) -> bool:
	if clear_around and is_inside_tree():
		var c := to_local(clear_around.global_position)
		if Vector2(c.x, c.z).distance_to(p) < clear_radius:
			return false
	var list: Array = _kinds[kind]
	var idx: int = list[_rng.randi() % list.size()]
	var s := _rng.randf_range(0.7, 1.4) if kind == "shrub" else _rng.randf_range(0.85, 1.25)
	var xf := Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(p.x, -0.05, p.y))
	if not _instances.has(idx):
		_instances[idx] = []
	_instances[idx].append(xf)
	if _entries[idx].collide:
		_colliders.append([idx, xf.origin])
	return true


func _build_multimeshes() -> void:
	for idx in _instances:
		var xfs: Array = _instances[idx]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _entries[idx].mesh
		mm.instance_count = xfs.size()
		for i in xfs.size():
			mm.set_instance_transform(i, xfs[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.visibility_range_end = view_distance
		_add_internal(mmi)


func _build_boundary() -> void:
	var body := StaticBody3D.new()
	body.name = "Boundary"
	var half := size * 0.5
	var t := wall_thickness
	var walls := [
		[Vector3(0, 0, -half.y - t * 0.5), Vector3(size.x + t * 2.0, wall_height, t)],
		[Vector3(0, 0, half.y + t * 0.5), Vector3(size.x + t * 2.0, wall_height, t)],
		[Vector3(-half.x - t * 0.5, 0, 0), Vector3(t, wall_height, size.y)],
		[Vector3(half.x + t * 0.5, 0, 0), Vector3(t, wall_height, size.y)],
	]
	for w in walls:
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = w[1]
		cs.shape = box
		cs.position = w[0] + Vector3(0, wall_height * 0.5 - 1.0, 0)
		body.add_child(cs)
	_add_internal(body)


func _build_fog_wall() -> void:
	var noise := FastNoiseLite.new()
	noise.frequency = 0.02
	noise.fractal_octaves = 3
	var tex := NoiseTexture2D.new()
	tex.width = 128
	tex.height = 128
	tex.seamless = true
	tex.noise = noise
	var mat := ShaderMaterial.new()
	mat.shader = FOG_SHADER
	mat.set_shader_parameter("noise_tex", tex)
	mat.set_shader_parameter("fog_color", fog_color)
	mat.set_shader_parameter("density", fog_density)
	mat.set_shader_parameter("height", fog_height)

	var half := size * 0.5
	for off in fog_layers:
		var hx := half.x + off
		var hz := half.y + off
		var sides := [
			[Vector3(0, 0, -hz), false, hx * 2.0],
			[Vector3(0, 0, hz), false, hx * 2.0],
			[Vector3(-hx, 0, 0), true, hz * 2.0],
			[Vector3(hx, 0, 0), true, hz * 2.0],
		]
		for s in sides:
			var quad := QuadMesh.new()
			quad.size = Vector2(s[2], fog_height)
			var mi := MeshInstance3D.new()
			mi.mesh = quad
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.position = s[0] + Vector3(0, fog_height * 0.5 - 0.2, 0)
			if s[1]:
				mi.rotation.y = PI * 0.5
			_add_internal(mi)


func _build_tree_collision() -> void:
	var body := StaticBody3D.new()
	var shapes := {}
	for c in _colliders:
		var idx: int = c[0]
		if not shapes.has(idx):
			var shape := CylinderShape3D.new()
			shape.radius = _entries[idx].radius
			shape.height = 4.0
			shapes[idx] = shape
		var cs := CollisionShape3D.new()
		cs.shape = shapes[idx]
		cs.position = (c[1] as Vector3) + Vector3.UP * 2.0
		body.add_child(cs)
	_add_internal(body)


func _add_internal(n: Node) -> void:
	add_child(n, false, Node.INTERNAL_MODE_BACK)
	_generated.append(n)
