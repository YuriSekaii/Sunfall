class_name Structure
extends StaticBody3D

signal destroyed(structure: Structure)

@export var kind: String = "wall" # "wall" | "turret"

var tier: int = 1
var hp: float = 120.0
var max_hp: float = 120.0

var _main_mesh: MeshInstance3D
var _head_pivot: Node3D
var _hp_label: Label3D
var _scan_timer: float = 0.0
var _fire_timer: float = 0.0
var _target: Node3D = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	collision_layer = 16
	collision_mask = 1 | 2 | 4
	add_to_group("structures")
	_setup_kind()


func configure(structure_kind: String) -> void:
	kind = structure_kind


func _setup_kind() -> void:
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	var mat := StandardMaterial3D.new()

	if kind == "turret":
		tier = 1
		max_hp = 90.0
		hp = max_hp
		shape.size = Vector3(1.0, 1.4, 1.0)
		col.shape = shape
		col.position = Vector3(0.0, 0.7, 0.0)
		add_child(col)

		var ref_turret := RefAssets.create_normalized_model("turret", 1.28)
		if ref_turret != null:
			_main_mesh = ref_turret
			add_child(_main_mesh)
			_head_pivot = Node3D.new()
			_head_pivot.position = Vector3(0.0, 1.18, 0.0)
			add_child(_head_pivot)
		else:
			mat.albedo_color = Color(0.28, 0.36, 0.42)
			mat.metallic = 0.45
			mat.roughness = 0.45
			_main_mesh = MeshInstance3D.new()
			var base_box := BoxMesh.new()
			base_box.size = Vector3(0.95, 1.0, 0.95)
			_main_mesh.mesh = base_box
			_main_mesh.position = Vector3(0.0, 0.5, 0.0)
			_main_mesh.material_override = mat
			add_child(_main_mesh)

			_head_pivot = Node3D.new()
			_head_pivot.position = Vector3(0.0, 1.18, 0.0)
			add_child(_head_pivot)

			var head_mesh := MeshInstance3D.new()
			var head_box := BoxMesh.new()
			head_box.size = Vector3(0.55, 0.38, 0.75)
			head_mesh.mesh = head_box
			var head_mat := StandardMaterial3D.new()
			head_mat.albedo_color = Color(0.18, 0.22, 0.26)
			head_mat.metallic = 0.7
			head_mesh.material_override = head_mat
			_head_pivot.add_child(head_mesh)

			var barrel := MeshInstance3D.new()
			var barrel_box := BoxMesh.new()
			barrel_box.size = Vector3(0.14, 0.14, 0.75)
			barrel.mesh = barrel_box
			barrel.position = Vector3(0.0, 0.0, -0.55)
			barrel.material_override = head_mat
			_head_pivot.add_child(barrel)
	else:
		tier = 1
		max_hp = 120.0
		hp = max_hp
		shape.size = Vector3(2.6, 2.0, 0.45)
		col.shape = shape
		col.position = Vector3(0.0, 1.0, 0.0)
		add_child(col)

		var ref_wall := RefAssets.create_normalized_model("barricade", 0.0, 2.55)
		if ref_wall != null:
			_main_mesh = ref_wall
			_main_mesh.scale.y *= 1.65
			add_child(_main_mesh)
		else:
			mat.albedo_color = Color(0.52, 0.36, 0.20)
			mat.roughness = 0.85
			_main_mesh = MeshInstance3D.new()
			var wall_box := BoxMesh.new()
			wall_box.size = Vector3(2.6, 2.0, 0.45)
			_main_mesh.mesh = wall_box
			_main_mesh.position = Vector3(0.0, 1.0, 0.0)
			_main_mesh.material_override = mat
			add_child(_main_mesh)

	_hp_label = Label3D.new()
	_hp_label.position = Vector3(0.0, 2.35 if kind == "wall" else 1.85, 0.0)
	_hp_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hp_label.font_size = 24
	_hp_label.outline_size = 5
	add_child(_hp_label)
	_refresh_visuals()


func _physics_process(delta: float) -> void:
	if kind != "turret":
		return
	_scan_timer -= delta
	_fire_timer -= delta
	if _scan_timer <= 0.0:
		_scan_timer = 0.15
		_target = _find_nearest_enemy()
	if is_instance_valid(_target) and _head_pivot != null:
		var aim_pos := _target.global_position + Vector3(0.0, 1.0, 0.0)
		var flat := aim_pos - _head_pivot.global_position
		if flat.length() > 0.1:
			var target_yaw := atan2(-flat.x, -flat.z)
			_head_pivot.rotation.y = lerp_angle(_head_pivot.rotation.y, target_yaw, clampf(delta * 10.0, 0.0, 1.0))
		if _fire_timer <= 0.0:
			_fire_timer = 0.55
			_fire_at(_target)


func _find_nearest_enemy() -> Node3D:
	var best: Node3D = null
	var best_dist := 15.0
	var origin := global_position + Vector3(0.0, 1.2, 0.0)
	var space := get_world_3d().direct_space_state
	for node in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(node) or not (node is Node3D):
			continue
		var enemy := node as Node3D
		var dist := origin.distance_to(enemy.global_position + Vector3(0.0, 1.0, 0.0))
		if dist < best_dist:
			var query := PhysicsRayQueryParameters3D.create(origin, enemy.global_position + Vector3(0.0, 1.0, 0.0), 1 | 16, [get_rid()])
			var hit := space.intersect_ray(query)
			if hit.is_empty():
				best_dist = dist
				best = enemy
	return best


func _fire_at(enemy: Node3D) -> void:
	if enemy.has_method("apply_hit"):
		var dir := (enemy.global_position - global_position).normalized()
		enemy.apply_hit(16.0, dir * 3.0, 0.12)
	Sfx.play(self, "turret", -10.0, randf_range(0.95, 1.08))
	_spawn_tracer(global_position + Vector3(0.0, 1.2, 0.0), enemy.global_position + Vector3(0.0, 1.0, 0.0))


func _spawn_tracer(from_pos: Vector3, to_pos: Vector3) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var dist := from_pos.distance_to(to_pos)
	if dist < 0.1:
		return
	var beam := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.04, 0.04, dist)
	beam.mesh = box
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.85, 0.25)
	beam.material_override = mat
	parent.add_child(beam)
	beam.global_position = (from_pos + to_pos) * 0.5
	beam.look_at(to_pos, Vector3.UP)
	get_tree().create_timer(0.07).timeout.connect(beam.queue_free)


func take_damage(amount: float) -> void:
	hp = maxf(0.0, hp - amount)
	_refresh_visuals()
	if hp <= 0.0:
		destroyed.emit(self)
		queue_free()


func repair(amount: float) -> bool:
	if hp >= max_hp:
		return false
	hp = minf(max_hp, hp + amount)
	_refresh_visuals()
	return true


func upgrade() -> bool:
	if kind != "wall" or tier >= 2:
		return false
	tier = 2
	max_hp = 280.0
	hp = max_hp
	_refresh_visuals()
	return true


func get_status_text() -> String:
	var label := "Turret" if kind == "turret" else ("Metal Wall" if tier >= 2 else "Wood Wall")
	return "%s (%d/%d HP)" % [label, int(ceil(hp)), int(max_hp)]


func _refresh_visuals() -> void:
	if _hp_label != null:
		var pct := hp / max_hp
		_hp_label.text = "%d/%d" % [int(ceil(hp)), int(max_hp)]
		_hp_label.modulate = Color(0.45, 1.0, 0.5) if pct > 0.6 else (Color(1.0, 0.85, 0.3) if pct > 0.3 else Color(1.0, 0.35, 0.3))
	if _main_mesh != null and _main_mesh.material_override is StandardMaterial3D:
		var mat := _main_mesh.material_override as StandardMaterial3D
		if kind == "wall":
			var has_ref := RefAssets.is_available() and RefAssets.get_mesh("barricade") != null
			var base := (Color(0.58, 0.64, 0.72) if tier >= 2 else Color(0.85, 0.75, 0.65)) if has_ref else (Color(0.42, 0.47, 0.52) if tier >= 2 else Color(0.52, 0.36, 0.20))
			if tier >= 2:
				var metal_tex := RefAssets.get_texture("metal")
				if metal_tex != null:
					mat.albedo_texture = metal_tex
			mat.metallic = 0.65 if tier >= 2 else 0.0
			mat.roughness = 0.4 if tier >= 2 else 0.85
			mat.albedo_color = base.lerp(Color(0.45, 0.16, 0.14), (1.0 - hp / max_hp) * 0.55)
		else:
			var base_t := Color.WHITE if (RefAssets.is_available() and RefAssets.get_mesh("turret") != null) else Color(0.28, 0.36, 0.42)
			mat.albedo_color = base_t.lerp(Color(0.55, 0.18, 0.18), (1.0 - hp / max_hp) * 0.5)
