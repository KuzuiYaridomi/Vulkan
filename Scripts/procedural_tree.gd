@tool
class_name ProceduralTree
extends Node3D

const LEAF_SHADER := preload("res://Scripts/leaf_wind.gdshader")

@export var tree_seed: int = 1:
	set(v):
		tree_seed = v
		_queue_rebuild()

@export_group("Trunk")
@export_range(0.5, 40.0, 0.1) var height: float = 8.0:
	set(v):
		height = v
		_queue_rebuild()
@export_range(0.01, 2.0, 0.01) var trunk_radius: float = 0.3:
	set(v):
		trunk_radius = v
		_queue_rebuild()
@export_range(1, 8) var trunk_count: int = 1:
	set(v):
		trunk_count = v
		_queue_rebuild()
@export_range(0.0, 1.0) var trunk_lean: float = 0.08:
	set(v):
		trunk_lean = v
		_queue_rebuild()
@export var directional_lean := Vector3.ZERO:
	set(v):
		directional_lean = v
		_queue_rebuild()
@export_range(0.0, 1.0) var curviness: float = 0.15:
	set(v):
		curviness = v
		_queue_rebuild()
@export_range(0.0, 2.0) var root_flare: float = 0.5:
	set(v):
		root_flare = v
		_queue_rebuild()

@export_group("Branches")
@export_range(0, 3) var branch_levels: int = 2:
	set(v):
		branch_levels = v
		_queue_rebuild()
@export_range(0, 20) var branches_per_level: int = 7:
	set(v):
		branches_per_level = v
		_queue_rebuild()
@export_range(0, 10) var sub_branches: int = 4:
	set(v):
		sub_branches = v
		_queue_rebuild()
@export_range(0.0, 0.95) var branch_start: float = 0.35:
	set(v):
		branch_start = v
		_queue_rebuild()
@export_range(5.0, 90.0) var branch_angle: float = 45.0:
	set(v):
		branch_angle = v
		_queue_rebuild()
@export_range(0.1, 1.0) var branch_length_ratio: float = 0.55:
	set(v):
		branch_length_ratio = v
		_queue_rebuild()
@export_range(-1.0, 1.0) var branch_upward: float = 0.3:
	set(v):
		branch_upward = v
		_queue_rebuild()

@export_group("Leaves")
@export var leaf_texture: Texture2D:
	set(v):
		leaf_texture = v
		_queue_rebuild()
@export var leaf_uv_region := Rect2(0, 0, 1, 1):
	set(v):
		leaf_uv_region = v
		_queue_rebuild()
@export_range(0.05, 6.0) var leaf_size: float = 1.5:
	set(v):
		leaf_size = v
		_queue_rebuild()
@export_range(0, 60) var leaves_per_branch: int = 8:
	set(v):
		leaves_per_branch = v
		_queue_rebuild()
@export var leaf_hanging: bool = false:
	set(v):
		leaf_hanging = v
		_queue_rebuild()
@export var leaf_tint := Color.WHITE:
	set(v):
		leaf_tint = v
		_queue_rebuild()
@export_range(0.0, 0.5) var wind_strength: float = 0.08:
	set(v):
		wind_strength = v
		_queue_rebuild()

@export_group("Bark")
@export var bark_texture: Texture2D:
	set(v):
		bark_texture = v
		_queue_rebuild()
@export var bark_uv_region := Rect2(0, 0, 1, 1):
	set(v):
		bark_uv_region = v
		_queue_rebuild()
@export var bark_tint := Color.WHITE:
	set(v):
		bark_tint = v
		_queue_rebuild()
@export_range(0.1, 8.0) var bark_tiling: float = 1.0:
	set(v):
		bark_tiling = v
		_queue_rebuild()

@export_group("Physics")
@export var add_collision: bool = true:
	set(v):
		add_collision = v
		_queue_rebuild()

var _rng := RandomNumberGenerator.new()
var _pending := false
var _generated: Array[Node] = []

var _bv := PackedVector3Array()
var _bn := PackedVector3Array()
var _buv := PackedVector2Array()
var _bi := PackedInt32Array()
var _lv := PackedVector3Array()
var _ln := PackedVector3Array()
var _luv := PackedVector2Array()
var _lc := PackedColorArray()
var _li := PackedInt32Array()


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
	_build_nodes(generate_mesh())


func generate_mesh() -> ArrayMesh:
	_bv = PackedVector3Array(); _bn = PackedVector3Array(); _buv = PackedVector2Array(); _bi = PackedInt32Array()
	_lv = PackedVector3Array(); _ln = PackedVector3Array(); _luv = PackedVector2Array(); _lc = PackedColorArray(); _li = PackedInt32Array()

	_rng.seed = tree_seed
	for i in trunk_count:
		var offset := Vector3.ZERO
		var lean := trunk_lean
		if trunk_count > 1:
			var a := TAU * i / trunk_count + _rng.randf() * 0.5
			offset = Vector3(cos(a), 0, sin(a)) * trunk_radius * 1.5
			lean = maxf(trunk_lean, 0.35)
		var dir := (Vector3.UP + _rand_vec() * lean + directional_lean).normalized()
		var h := height * (_rng.randf_range(0.75, 1.0) if trunk_count > 1 else 1.0)
		_grow(offset, dir, h, trunk_radius, 0)

	_finalize_leaf_normals()
	return _make_mesh()


func _grow(start: Vector3, dir: Vector3, length: float, radius: float, level: int) -> void:
	var seg_count := clampi(int(length * 2.0), 3, 16)
	var radial := 12 if level == 0 else (6 if level == 1 else 4)
	var seg_len := length / seg_count
	var points := PackedVector3Array([start])
	var dirs := PackedVector3Array([dir])
	var p := start
	var d := dir
	for i in seg_count:
		var bend := _rand_vec() * curviness * (0.5 if level == 0 else 1.0)
		var vertical := Vector3.UP * (0.12 if level == 0 else branch_upward * 0.15)
		vertical += directional_lean * (0.06 if level == 0 else 0.12)
		d = (d + bend + vertical).normalized()
		p += d * seg_len
		points.append(p)
		dirs.append(d)

	var is_last := level >= branch_levels
	var tip_radius := radius * (0.12 if is_last else 0.3)
	_add_tube(points, dirs, radius, tip_radius, radial, level == 0)

	if not is_last:
		var count := branches_per_level if level == 0 else sub_branches
		var t_min := branch_start if level == 0 else 0.25
		var az0 := _rng.randf() * TAU
		for k in count:
			var t := lerpf(t_min, 0.95, (k + _rng.randf() * 0.8) / maxf(count, 1))
			var s := _sample(points, dirs, t)
			var pos: Vector3 = s[0]
			var pd: Vector3 = s[1]
			var r_at := lerpf(radius, tip_radius, t)
			var perp := _perpendicular(pd).rotated(pd, az0 + k * 2.39996 + _rng.randf_range(-0.3, 0.3))
			var angle := deg_to_rad(branch_angle * _rng.randf_range(0.8, 1.2))
			var nd := pd.rotated(perp, angle)
			var shrink := (1.0 - t * 0.55) if level == 0 else (1.0 - t * 0.5)
			var child_len := length * branch_length_ratio * _rng.randf_range(0.75, 1.1) * shrink
			var child_r := maxf(r_at * 0.6, 0.008)
			_grow(pos, nd, child_len, child_r, level + 1)

	if leaf_texture == null or leaves_per_branch == 0:
		return
	var n_leaves := 0
	var t_from := 0.25
	if is_last:
		n_leaves = leaves_per_branch
		if level == 0:
			t_from = branch_start
	elif level == branch_levels - 1 and level > 0:
		n_leaves = int(leaves_per_branch / 3.0)
		t_from = 0.6
	for k in n_leaves:
		var s := _sample(points, dirs, _rng.randf_range(t_from, 1.0))
		_add_leaf(s[0], s[1])


func _add_tube(points: PackedVector3Array, dirs: PackedVector3Array, r0: float, r1: float, radial: int, is_trunk: bool) -> void:
	var base := _bv.size()
	var side := _perpendicular(dirs[0])
	var dist := 0.0
	var n := points.size()
	for i in n:
		var d := dirs[i]
		side = (side - d * side.dot(d)).normalized()
		var bin := d.cross(side)
		var t := float(i) / (n - 1)
		var r := lerpf(r0, r1, pow(t, 0.8))
		if i > 0:
			dist += points[i].distance_to(points[i - 1])
		var flare := 0.0
		if is_trunk and root_flare > 0.0:
			flare = root_flare * exp(-(points[i].y) / maxf(trunk_radius * 1.5, 0.05))
		for k in radial + 1:
			var ang := TAU * k / radial
			var nrm := side * cos(ang) + bin * sin(ang)
			var rr := r * (1.0 + flare * (0.6 + 0.4 * sin(ang * 5.0)))
			_bv.append(points[i] + nrm * rr)
			_bn.append(nrm)
			_buv.append(Vector2(float(k) / radial, dist / (TAU * r0) * bark_tiling))
	var ring := radial + 1
	for i in n - 1:
		for k in radial:
			var a := base + i * ring + k
			var b := a + 1
			var c := a + ring
			var e := c + 1
			_bi.append_array(PackedInt32Array([a, c, b, b, c, e]))


func _add_leaf(anchor: Vector3, branch_dir: Vector3) -> void:
	var s := leaf_size * _rng.randf_range(0.7, 1.3)
	var outward := Vector3(anchor.x, 0, anchor.z)
	outward = outward.normalized() if outward.length() > 0.01 else _rand_vec()
	var dir: Vector3
	if leaf_hanging:
		dir = (branch_dir * 0.4 + outward * 0.5 + Vector3.DOWN * 0.8 + _rand_vec() * 0.4).normalized()
	else:
		dir = _rand_vec()
	var right := dir.cross(_rand_vec()).normalized()
	if right.length() < 0.01:
		right = _perpendicular(dir)
	var top := anchor if leaf_hanging else anchor - dir * s * 0.5
	var a0 := top - right * s * 0.5
	var a1 := top + right * s * 0.5
	var b1 := a1 + dir * s
	var b0 := a0 + dir * s
	var wind := clampf(anchor.y / maxf(height, 0.1), 0.0, 1.0)
	var col := Color(wind, _rng.randf(), 0.0)
	var base := _lv.size()
	_lv.append_array(PackedVector3Array([a0, a1, b1, b0]))
	_luv.append_array(PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]))
	for j in 4:
		_lc.append(col)
		_ln.append(Vector3.UP)
	_li.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))


func _finalize_leaf_normals() -> void:
	if _lv.is_empty():
		return
	var centre := Vector3.ZERO
	for v in _lv:
		centre += v
	centre /= _lv.size()
	for i in _lv.size():
		var n := (_lv[i] - centre) * Vector3(1.0, 0.7, 1.0)
		_ln[i] = (n.normalized() + Vector3.UP * 0.4).normalized()


static func make_leaf_material(tex: Texture2D, region: Rect2, tint: Color, wind: float) -> ShaderMaterial:
	var leaf := ShaderMaterial.new()
	leaf.shader = LEAF_SHADER
	leaf.set_shader_parameter("leaf_texture", tex)
	leaf.set_shader_parameter("uv_region", Vector4(region.position.x, region.position.y, region.size.x, region.size.y))
	leaf.set_shader_parameter("tint", tint)
	leaf.set_shader_parameter("wind_strength", wind)
	return leaf


func _make_mesh() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if not _bv.is_empty():
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = _bv
		arrays[Mesh.ARRAY_NORMAL] = _bn
		arrays[Mesh.ARRAY_TEX_UV] = _buv
		arrays[Mesh.ARRAY_INDEX] = _bi
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var bark := StandardMaterial3D.new()
		bark.albedo_texture = bark_texture
		bark.albedo_color = bark_tint
		bark.uv1_offset = Vector3(bark_uv_region.position.x, bark_uv_region.position.y, 0)
		bark.uv1_scale = Vector3(bark_uv_region.size.x, bark_uv_region.size.y, 1)
		bark.roughness = 0.95
		bark.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		mesh.surface_set_material(mesh.get_surface_count() - 1, bark)
	if not _lv.is_empty():
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = _lv
		arrays[Mesh.ARRAY_NORMAL] = _ln
		arrays[Mesh.ARRAY_TEX_UV] = _luv
		arrays[Mesh.ARRAY_COLOR] = _lc
		arrays[Mesh.ARRAY_INDEX] = _li
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var leaf := make_leaf_material(leaf_texture, leaf_uv_region, leaf_tint, wind_strength)
		mesh.surface_set_material(mesh.get_surface_count() - 1, leaf)
	return mesh


func _build_nodes(mesh: ArrayMesh) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	add_child(mi, false, Node.INTERNAL_MODE_BACK)
	_generated.append(mi)

	if add_collision and trunk_count == 1:
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		var col_h := height * maxf(branch_start, 0.5)
		shape.radius = trunk_radius
		shape.height = col_h
		cs.shape = shape
		cs.position.y = col_h * 0.5
		body.add_child(cs)
		add_child(body, false, Node.INTERNAL_MODE_BACK)
		_generated.append(body)


func _sample(points: PackedVector3Array, dirs: PackedVector3Array, t: float) -> Array:
	var f := clampf(t, 0.0, 1.0) * (points.size() - 1)
	var i := mini(int(f), points.size() - 2)
	var w := f - i
	return [points[i].lerp(points[i + 1], w), dirs[i].lerp(dirs[i + 1], w).normalized()]


func _perpendicular(v: Vector3) -> Vector3:
	var a := Vector3.RIGHT if absf(v.x) < 0.9 else Vector3.FORWARD
	return v.cross(a).normalized()


func _rand_vec() -> Vector3:
	var v := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1))
	return v.normalized() if v.length() > 0.001 else Vector3.UP
