class_name LootContainer
extends StaticBody3D

@export var container_id: int = 1
@export var pool: String = "supply"
@export var search_time: float = 0.75

var is_looted: bool = false

var _box_mesh: MeshInstance3D
var _lid_pivot: Node3D
var _label: Label3D
var _sense_beacon: MeshInstance3D
var _sense_active: bool = false


func _ready() -> void:
	collision_layer = 1 | 8
	collision_mask = 0
	add_to_group("loot_containers")
	_build_visuals()


func configure(id: int, pool_name: String) -> void:
	container_id = id
	pool = pool_name
	match pool:
		"crash":
			search_time = 0.60
		"lab":
			search_time = 0.95
		_:
			search_time = 0.75


func _build_visuals() -> void:
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.15, 0.78, 0.85)
	col.shape = shape
	col.position = Vector3(0.0, 0.39, 0.0)
	add_child(col)

	var base_color := Color(0.75, 0.62, 0.44)
	var title := "Supply Crate"
	match pool:
		"crash":
			base_color = Color(0.92, 0.64, 0.38)
			title = "Plane Case"
		"lab":
			base_color = Color(0.42, 0.72, 0.85)
			title = "Bio-Lab Locker"

	var ref_crate := RefAssets.create_normalized_model("crate", 0.78, 0.0, base_color)
	if ref_crate != null:
		_box_mesh = ref_crate
		add_child(_box_mesh)
	else:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = base_color
		mat.roughness = 0.7

		_box_mesh = MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(1.15, 0.65, 0.85)
		_box_mesh.mesh = box
		_box_mesh.position = Vector3(0.0, 0.325, 0.0)
		_box_mesh.material_override = mat
		add_child(_box_mesh)

		_lid_pivot = Node3D.new()
		_lid_pivot.position = Vector3(0.0, 0.65, -0.425)
		add_child(_lid_pivot)

		var lid_mesh := MeshInstance3D.new()
		var lid_box := BoxMesh.new()
		lid_box.size = Vector3(1.18, 0.13, 0.88)
		lid_mesh.mesh = lid_box
		lid_mesh.position = Vector3(0.0, 0.065, 0.425)
		var lid_mat := StandardMaterial3D.new()
		lid_mat.albedo_color = base_color.lightened(0.15)
		lid_mat.roughness = 0.55
		lid_mesh.material_override = lid_mat
		_lid_pivot.add_child(lid_mesh)

	_label = Label3D.new()
	_label.text = title
	_label.position = Vector3(0.0, 1.15, 0.0)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 28
	_label.outline_size = 6
	add_child(_label)

	_sense_beacon = MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.22
	sph.height = 0.44
	_sense_beacon.mesh = sph
	_sense_beacon.position = Vector3(0.0, 0.55, 0.0)
	var bmat := StandardMaterial3D.new()
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bmat.no_depth_test = true
	bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bmat.albedo_color = Color(1.0, 0.82, 0.18, 0.72)
	_sense_beacon.material_override = bmat
	_sense_beacon.visible = false
	add_child(_sense_beacon)


func set_sense_highlight(active: bool) -> void:
	_sense_active = active and not is_looted
	if _sense_beacon != null:
		_sense_beacon.visible = _sense_active
	if _label != null:
		_label.no_depth_test = _sense_active
		if _sense_active:
			_label.modulate = Color(1.0, 0.88, 0.22)
		elif is_looted:
			_label.modulate = Color(0.65, 0.65, 0.65)
		else:
			_label.modulate = Color.WHITE


func get_display_name() -> String:
	match pool:
		"crash":
			return "Plane Case"
		"lab":
			return "Bio-Lab Locker"
		_:
			return "Supply Crate"


func open_and_roll(run_seed: int, day: int) -> Dictionary:
	if is_looted:
		return {"items": {}, "weapon_tier": 0}
	is_looted = true
	if _lid_pivot:
		_lid_pivot.rotation_degrees.x = -68.0
	if _box_mesh and _box_mesh.material_override is StandardMaterial3D:
		(_box_mesh.material_override as StandardMaterial3D).albedo_color = Color(0.28, 0.28, 0.28)
	if _label:
		_label.text = "Empty"
		_label.no_depth_test = false
		_label.modulate = Color(0.65, 0.65, 0.65)
	if _sense_beacon:
		_sense_beacon.visible = false
	_sense_active = false
	return LootTable.roll_container(run_seed, container_id, pool, day)
