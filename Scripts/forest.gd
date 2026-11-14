@tool
extends Node3D

const TreeScript := preload("res://Scripts/procedural_tree.gd")
const TREE_LIBRARY := preload("res://Scenes/Trees.tscn")
const LEAF_CLUMP := preload("res://All_Assets/Objects/low-poly_trees_3.png")
const LEAF_HANGING := preload("res://All_Assets/Objects/low-poly_trees_4.png")

@export var regenerate: bool = false:
	set(v):
		_queue_rebuild()
@export var forest_seed: int = 1:
	set(v):
		forest_seed = v
		_queue_rebuild()

@export_group("Road")
@export var road_x: float = 0.0
@export var road_start_z: float = -60.0
@export var road_end_z: float = 520.0
@export var road_half_width: float = 2.7

@export_group("Forest")
@export var forest_half_width: float = 55.0
@export var tree_spacing: float = 6.5
@export var shrub_spacing: float = 3.5
@export_range(1, 6) var variants_per_type: int = 3
@export var chunk_length: float = 40.0
@export var view_distance: float = 220.0

@export_group("Canopy")
@export var canopy: bool = true
@export var canopy_tree_spacing: float = 5.0
@export var canopy_height: float = 8.5
@export_range(0.0, 1.0) var canopy_coverage: float = 0.55

var _pending := false
var _generated: Array[Node] = []
var _rng := RandomNumberGenerator.new()
var _entries: Array = []
var _kinds: Dictionary = {}
var _chunks: Dictionary = {}
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
	var t0 := Time.get_ticks_msec()
	for n in _generated:
		if is_instance_valid(n):
			n.queue_free()
	_generated.clear()
	_entries.clear()
	_kinds.clear()
	_chunks.clear()
	_colliders.clear()
	_rng.seed = forest_seed

	_build_library()
	var count := _scatter()
	_build_multimeshes()
	if canopy:
		_build_canopy_roof()
	if not Engine.is_editor_hint():
		_build_collision()
	print("Forest: %d trees/shrubs, %d variants, generated in %d ms" % [count, _entries.size(), Time.get_ticks_msec() - t0])


func _build_library() -> void:
	var lib := TREE_LIBRARY.instantiate()
	_add_kind("oak", [lib.get_node("Oak_A"), lib.get_node("Oak_B")], true)
	_add_kind("birch", [lib.get_node("Birch_A"), lib.get_node("Birch_B")], true)
	_add_kind("weeping", [lib.get_node("Weeping")], true)
	_add_kind("shrub", [lib.get_node("Shrub")], false)

	var c = lib.get_node("Oak_A")
	c.height = 12.0
	c.trunk_radius = 0.38
	c.directional_lean = Vector3(0.55, 0, 0)
	c.branch_start = 0.45
	c.branches_per_level = 9
	c.branch_length_ratio = 0.7
	c.branch_upward = 0.12
	c.leaves_per_branch = 9
	_add_kind("canopy", [c], true)
	lib.free()


func _add_kind(kind: String, templates: Array, collide: bool) -> void:
	var list: Array[int] = []
	for t in templates:
		var base_seed: int = t.tree_seed
		for v in variants_per_type:
			t.tree_seed = base_seed + v * 97
			list.append(_entries.size())
			_entries.append({"mesh": t.generate_mesh(), "radius": t.trunk_radius, "collide": collide, "kind": kind})
		t.tree_seed = base_seed
	_kinds[kind] = list


func _scatter() -> int:
	var count := 0
	var clear_zone := road_half_width + (4.5 if canopy else 2.0)

	var z := road_start_z
	while z <= road_end_z:
		var x := road_x - forest_half_width
		while x <= road_x + forest_half_width:
			var px := x + _rng.randf_range(-0.4, 0.4) * tree_spacing
			var pz := z + _rng.randf_range(-0.4, 0.4) * tree_spacing
			if absf(px - road_x) >= clear_zone:
				var r := _rng.randf()
				var kind := "oak" if r < 0.45 else ("birch" if r < 0.8 else "weeping")
				_place(kind, px, pz, _rng.randf() * TAU, _rng.randf_range(0.8, 1.25))
				count += 1
			x += tree_spacing
		z += tree_spacing

	z = road_start_z
	while z <= road_end_z:
		var x := road_x - forest_half_width
		while x <= road_x + forest_half_width:
			var px := x + _rng.randf_range(-0.5, 0.5) * shrub_spacing
			var pz := z + _rng.randf_range(-0.5, 0.5) * shrub_spacing
			var d := absf(px - road_x)
			if d >= road_half_width + 0.8 and _rng.randf() < lerpf(0.75, 0.25, d / forest_half_width):
				_place("shrub", px, pz, _rng.randf() * TAU, _rng.randf_range(0.7, 1.4))
				count += 1
			x += shrub_spacing
		z += shrub_spacing

	if canopy:
		for side in [-1, 1]:
			var cz := road_start_z
			while cz <= road_end_z:
				if _rng.randf() > 0.1:
					var px: float = road_x + side * (road_half_width + _rng.randf_range(1.2, 3.0))
					var yaw: float = (0.0 if side < 0 else PI) + _rng.randf_range(-0.3, 0.3)
					_place("canopy", px, cz + _rng.randf_range(-1.0, 1.0), yaw, _rng.randf_range(0.9, 1.15))
					count += 1
				cz += canopy_tree_spacing
	return count


func _place(kind: String, px: float, pz: float, yaw: float, s: float) -> void:
	var list: Array = _kinds[kind]
	var idx: int = list[_rng.randi() % list.size()]
	var xf := Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), Vector3(px, -0.05, pz))
	var ci := _chunk_of(pz)
	if not _chunks.has(ci):
		_chunks[ci] = {}
	if not _chunks[ci].has(idx):
		_chunks[ci][idx] = []
	_chunks[ci][idx].append(xf)
	if _entries[idx].collide:
		_colliders.append([idx, xf])


func _chunk_of(z: float) -> int:
	return int(floor((z - road_start_z) / chunk_length))


func _build_multimeshes() -> void:
	for ci in _chunks:
		for idx in _chunks[ci]:
			var xfs: Array = _chunks[ci][idx]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = _entries[idx].mesh
			mm.instance_count = xfs.size()
			for i in xfs.size():
				mm.set_instance_transform(i, xfs[i])
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			if _entries[idx].kind == "shrub":
				mmi.visibility_range_end = view_distance * 0.4
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			else:
				mmi.visibility_range_end = view_distance
			_add_internal(mmi)


func _build_collision() -> void:
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
		cs.position = (c[1] as Transform3D).origin + Vector3.UP * 2.0
		body.add_child(cs)
	_add_internal(body)


func _build_canopy_roof() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = forest_seed
	noise.frequency = 0.09
	var clump_mat := TreeScript.make_leaf_material(LEAF_CLUMP, Rect2(0, 0, 1, 1), Color(0.95, 1.0, 0.9), 0.06)
	var hang_mat := TreeScript.make_leaf_material(LEAF_HANGING, Rect2(0, 0, 1, 1), Color.WHITE, 0.1)
	var span := road_half_width + 2.0
	var n_chunks := _chunk_of(road_end_z) + 1
	for ci in n_chunks:
		var z0 := road_start_z + ci * chunk_length
		var clump := _new_surface()
		var hang := _new_surface()
		var z := z0
		while z < z0 + chunk_length and z <= road_end_z:
			var x := -span
			while x <= span:
				var px := road_x + x + _rng.randf_range(-0.3, 0.3)
				var pz := z + _rng.randf_range(-0.3, 0.3)
				var n := (noise.get_noise_2d(px, pz) + 1.0) * 0.5
				if n < canopy_coverage + 0.15:
					var arch := 1.0 - pow(x / span, 2.0)
					var py := canopy_height + arch * 1.5 + _rng.randf_range(-0.6, 0.6)
					if _rng.randf() < 0.7:
						_add_clump_card(clump, Vector3(px, py, pz), _rng.randf_range(1.8, 2.8))
					else:
						_add_hanging_card(hang, Vector3(px, py + 0.3, pz), _rng.randf_range(2.0, 3.2))
				x += 0.85
			z += 0.75
		var mesh := ArrayMesh.new()
		_commit_surface(mesh, clump, clump_mat)
		_commit_surface(mesh, hang, hang_mat)
		if mesh.get_surface_count() == 0:
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.visibility_range_end = view_distance
		_add_internal(mi)


func _add_clump_card(s: Dictionary, c: Vector3, size: float) -> void:
	var yaw := _rng.randf() * TAU
	var right := Vector3(cos(yaw), 0, sin(yaw))
	var fwd := right.cross(Vector3.UP).rotated(right, _rng.randf_range(-0.6, 0.6))
	var h := size * 0.5
	_add_quad(s, c - right * h - fwd * h, c + right * h - fwd * h, c + right * h + fwd * h, c - right * h + fwd * h)


func _add_hanging_card(s: Dictionary, anchor: Vector3, size: float) -> void:
	var yaw := _rng.randf() * TAU
	var right := Vector3(cos(yaw), 0, sin(yaw))
	var down := (Vector3.DOWN + Vector3(_rng.randf_range(-0.4, 0.4), 0, _rng.randf_range(-0.4, 0.4))).normalized()
	var h := size * 0.5
	_add_quad(s, anchor - right * h, anchor + right * h, anchor + right * h + down * size, anchor - right * h + down * size)


func _add_quad(s: Dictionary, a0: Vector3, a1: Vector3, b1: Vector3, b0: Vector3) -> void:
	var base: int = s.v.size()
	s.v.append_array([a0, a1, b1, b0])
	s.uv.append_array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	var col := Color(0.6, _rng.randf(), 0.0)
	var nrm := (Vector3.UP + Vector3(_rng.randf_range(-0.4, 0.4), 0, _rng.randf_range(-0.4, 0.4))).normalized()
	for j in 4:
		s.c.append(col)
		s.n.append(nrm)
	s.i.append_array([base, base + 1, base + 2, base, base + 2, base + 3])


func _new_surface() -> Dictionary:
	return {"v": [], "n": [], "uv": [], "c": [], "i": []}


func _commit_surface(mesh: ArrayMesh, s: Dictionary, mat: Material) -> void:
	if s.v.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array(s.v)
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array(s.n)
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array(s.uv)
	arrays[Mesh.ARRAY_COLOR] = PackedColorArray(s.c)
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array(s.i)
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(mesh.get_surface_count() - 1, mat)


func _add_internal(n: Node) -> void:
	add_child(n, false, Node.INTERNAL_MODE_BACK)
	_generated.append(n)
