class_name Zombie
extends CharacterBody3D

signal died(zombie: Zombie)

@export var is_bunker_enemy: bool = false
@export var is_brute: bool = false
@export var is_night_runner: bool = false

var hp: float = 65.0
var max_hp: float = 65.0
var stagger_timer: float = 0.0
var downed_timer: float = 0.0
var knockback_vel: Vector3 = Vector3.ZERO
var is_night_ref: bool = false
# DodgeModule (0x144cea8, AIModule::m_DodgeProbability — AI zombie sidestep, distinct from Player MoveController dodge)
var dodge_probability: float = 0.0
var _ai_dodge_cd: float = 0.0

var _spawn_pos: Vector3
var _attack_timer: float = 0.0
var _attack_anim_timer: float = 0.0
var _grab_cd: float = 2.0
var _wander_timer: float = 0.0
var _wander_dir: Vector3 = Vector3.ZERO
var _flash_timer: float = 0.0
var _lunge_timer: float = 0.0
var _lunge_cd: float = 0.0
var _lunge_dir: Vector3 = Vector3.ZERO
var _is_dying: bool = false
var _death_timer: float = 0.0
var _hit_freeze_timer: float = 0.0

var _col_shape: CollisionShape3D
var _cap_shape: CapsuleShape3D

var _dl_rig: Node3D
var _anim_player: AnimationPlayer
var _current_anim: String = ""
var _dl_meshes: Array[MeshInstance3D] = []
var _flash_overlay_mat: StandardMaterial3D
var _sunlight_overlay_mat: StandardMaterial3D
var _body_mesh: MeshInstance3D
var _head_mesh: MeshInstance3D
var _body_mat: StandardMaterial3D
var _uses_ref_model: bool = false
var _sense_label: Label3D
var _sense_beacon: MeshInstance3D
var _groan_timer: float = 4.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	collision_layer = 4
	collision_mask = 1 | 2 | 4 | 16
	platform_floor_layers = 1
	add_to_group("enemies")
	_spawn_pos = global_position
	max_hp = 150.0 if is_brute else 65.0
	hp = max_hp
	_build_visuals()
	_refresh_sunlight_visuals()
	_play_anim("shamble" if is_active_state(is_night_ref) else "idle_sunlight")


func configure(bunker: bool, brute: bool, night_runner: bool = false) -> void:
	is_bunker_enemy = bunker
	is_brute = brute
	is_night_runner = night_runner
	dodge_probability = 0.25 if (not brute and (bunker or night_runner)) else 0.0


func try_ai_dodge(threat_dir: Vector3) -> bool:
	if _is_dying or is_downed() or stagger_timer > 0.0 or _ai_dodge_cd > 0.0 or dodge_probability <= 0.0:
		return false
	if not is_active_state(is_night_ref):
		return false
	_ai_dodge_cd = 2.5
	var flat := Vector3(threat_dir.x, 0.0, threat_dir.z)
	var side := Vector3(-flat.z, 0.0, flat.x).normalized() if flat.length() > 0.05 else Vector3.RIGHT
	knockback_vel = side * 5.5
	stagger_timer = maxf(stagger_timer, 0.22)
	return true


func is_active_state(is_night: bool) -> bool:
	return is_night or is_bunker_enemy


func set_night_state(is_night: bool) -> void:
	if is_night_ref != is_night:
		is_night_ref = is_night
		_refresh_sunlight_visuals()


func _build_visuals() -> void:
	var scale_mul := 1.28 if is_brute else 1.0

	_col_shape = CollisionShape3D.new()
	_cap_shape = CapsuleShape3D.new()
	_cap_shape.radius = 0.38 * scale_mul
	_cap_shape.height = 1.75 * scale_mul
	_col_shape.shape = _cap_shape
	_col_shape.position = Vector3(0.0, 0.88 * scale_mul, 0.0)
	add_child(_col_shape)

	var dl_key := "dl_zombie_goon" if is_brute else ("dl_zombie_volatile" if (is_bunker_enemy or is_night_runner) else "dl_zombie_biter")
	_dl_rig = RefAssets.instantiate_dl_zombie(dl_key)
	if _dl_rig != null:
		if is_brute:
			_dl_rig.scale = Vector3(1.22, 1.22, 1.22)
		add_child(_dl_rig)
		_anim_player = RefAssets.find_animation_player(_dl_rig)
		RefAssets.set_loop_mode_for_clips(_anim_player, ["idle_sunlight", "shamble", "chase_run"])
		_collect_dl_meshes(_dl_rig)
		_flash_overlay_mat = StandardMaterial3D.new()
		_flash_overlay_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flash_overlay_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_flash_overlay_mat.albedo_color = Color(1.0, 0.25, 0.20, 0.45)
		_sunlight_overlay_mat = StandardMaterial3D.new()
		_sunlight_overlay_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_sunlight_overlay_mat.albedo_color = Color(0.55, 0.52, 0.42, 0.32)
	else:
		var model_key := "zombie_mutated" if is_brute else ("zombie_lab" if is_bunker_enemy else "zombie_hazmat")
		var target_h := 2.15 if is_brute else 1.82
		var ref_model := RefAssets.create_normalized_model(model_key, target_h)
		if ref_model != null:
			_uses_ref_model = true
			_body_mesh = ref_model
			_body_mesh.rotation_degrees.y = 180.0
			_body_mat = _body_mesh.material_override as StandardMaterial3D
			add_child(_body_mesh)
		else:
			_body_mat = StandardMaterial3D.new()
			_body_mat.roughness = 0.85

			_body_mesh = MeshInstance3D.new()
			var body_cap := CapsuleMesh.new()
			body_cap.radius = 0.36 * scale_mul
			body_cap.height = 1.35 * scale_mul
			_body_mesh.mesh = body_cap
			_body_mesh.position = Vector3(0.0, 0.72 * scale_mul, 0.0)
			_body_mesh.material_override = _body_mat
			add_child(_body_mesh)

			_head_mesh = MeshInstance3D.new()
			var head_sph := SphereMesh.new()
			head_sph.radius = 0.24 * scale_mul
			head_sph.height = 0.48 * scale_mul
			_head_mesh.mesh = head_sph
			_head_mesh.position = Vector3(0.0, 1.56 * scale_mul, 0.0)
			_head_mesh.material_override = _body_mat
			add_child(_head_mesh)

	_sense_beacon = MeshInstance3D.new()
	var s_sph := SphereMesh.new()
	s_sph.radius = 0.24 * scale_mul
	s_sph.height = 0.48 * scale_mul
	_sense_beacon.mesh = s_sph
	_sense_beacon.position = Vector3(0.0, 1.15 * scale_mul, 0.0)
	var s_mat := StandardMaterial3D.new()
	s_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	s_mat.no_depth_test = true
	s_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	s_mat.albedo_color = Color(1.0, 0.18, 0.14, 0.65)
	_sense_beacon.material_override = s_mat
	_sense_beacon.visible = false
	add_child(_sense_beacon)

	_sense_label = Label3D.new()
	_sense_label.text = "BRUTE" if is_brute else "INFECTED"
	_sense_label.position = Vector3(0.0, 2.25 * scale_mul, 0.0)
	_sense_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sense_label.no_depth_test = true
	_sense_label.modulate = Color(1.0, 0.28, 0.22)
	_sense_label.font_size = 28
	_sense_label.outline_size = 6
	_sense_label.visible = false
	add_child(_sense_label)


func set_sense_highlight(active: bool) -> void:
	var show := active and not _is_dying
	if _sense_beacon != null:
		_sense_beacon.visible = show
	if _sense_label != null:
		_sense_label.visible = show


func is_downed() -> bool:
	return downed_timer > 0.0 and not _is_dying


func is_headshot_pos(world_pos: Vector3) -> bool:
	var scale_mul := 1.28 if is_brute else 1.0
	return world_pos.y >= global_position.y + 1.32 * scale_mul


func apply_knockdown(duration: float) -> void:
	if _is_dying:
		return
	downed_timer = maxf(downed_timer, duration)
	stagger_timer = maxf(stagger_timer, duration)
	_lunge_timer = 0.0
	_update_downed_capsule(true)
	_play_anim("knockdown")


func on_grab_broken(stun_dur: float) -> void:
	_grab_cd = 8.0
	_attack_timer = 1.6
	stagger_timer = maxf(stagger_timer, stun_dur)
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player != null and is_instance_valid(player):
		var away := global_position - player.global_position
		away.y = 0.0
		if away.length() > 0.05:
			knockback_vel = away.normalized() * 8.5
	_play_anim("stagger")


func _update_downed_capsule(downed: bool) -> void:
	if _cap_shape == null or _col_shape == null:
		return
	var scale_mul := 1.28 if is_brute else 1.0
	if downed:
		_cap_shape.height = 0.78 * scale_mul
		_col_shape.position.y = 0.39 * scale_mul
	else:
		_cap_shape.height = 1.75 * scale_mul
		_col_shape.position.y = 0.88 * scale_mul


func apply_stun(duration: float) -> void:
	stagger_timer = maxf(stagger_timer, duration)
	_lunge_timer = 0.0
	_flash_timer = 0.14
	_refresh_sunlight_visuals()


func pause_hit_freeze(duration: float) -> void:
	_hit_freeze_timer = maxf(_hit_freeze_timer, duration)


func _collect_dl_meshes(node: Node) -> void:
	if node is MeshInstance3D:
		_dl_meshes.append(node as MeshInstance3D)
	for child in node.get_children():
		_collect_dl_meshes(child)


func _play_anim(anim_name: String) -> void:
	if _anim_player == null or not _anim_player.has_animation(anim_name):
		return
	if _current_anim == anim_name and _anim_player.is_playing():
		return
	_current_anim = anim_name
	_anim_player.play(anim_name, 0.14)


func _refresh_sunlight_visuals() -> void:
	var active := is_active_state(is_night_ref)
	if not _dl_meshes.is_empty():
		var overlay: Material = null
		if _flash_timer > 0.0:
			overlay = _flash_overlay_mat
		elif not active:
			overlay = _sunlight_overlay_mat
		for m in _dl_meshes:
			if is_instance_valid(m):
				m.material_overlay = overlay
		return
	if _body_mat == null:
		return
	if _flash_timer > 0.0:
		_body_mat.albedo_color = Color(1.0, 0.55, 0.55) if _uses_ref_model else Color(1.0, 0.92, 0.88)
		return
	if active:
		_body_mat.albedo_color = Color.WHITE if _uses_ref_model else (Color(0.45, 0.16, 0.16) if is_brute else Color(0.28, 0.36, 0.26))
	else:
		_body_mat.albedo_color = Color(0.68, 0.66, 0.56) if _uses_ref_model else Color(0.62, 0.60, 0.52)


func _physics_process(delta: float) -> void:
	if _hit_freeze_timer > 0.0:
		_hit_freeze_timer -= delta
		if _anim_player != null:
			_anim_player.speed_scale = 0.0
		return
	elif _anim_player != null:
		_anim_player.speed_scale = 1.0

	if _is_dying:
		_death_timer -= delta
		if _dl_rig == null:
			rotation.x = lerpf(rotation.x, -1.48, clampf(delta * 9.0, 0.0, 1.0))
			if _body_mat != null:
				_body_mat.albedo_color = _body_mat.albedo_color.lerp(Color(0.14, 0.14, 0.14), clampf(delta * 6.0, 0.0, 1.0))
		if _death_timer <= 0.0:
			queue_free()
		return

	if not is_on_floor():
		velocity.y -= DLReference.GRAVITY * delta
	else:
		velocity.y = 0.0

	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			_refresh_sunlight_visuals()

	_attack_timer = maxf(0.0, _attack_timer - delta)
	_attack_anim_timer = maxf(0.0, _attack_anim_timer - delta)
	_grab_cd = maxf(0.0, _grab_cd - delta)
	_lunge_cd = maxf(0.0, _lunge_cd - delta)
	_ai_dodge_cd = maxf(0.0, _ai_dodge_cd - delta)
	knockback_vel = knockback_vel.move_toward(Vector3.ZERO, 24.0 * delta)

	if downed_timer > 0.0:
		downed_timer = maxf(0.0, downed_timer - delta)
		if downed_timer <= 0.0:
			_update_downed_capsule(false)

	if stagger_timer > 0.0:
		stagger_timer -= delta
		_lunge_timer = 0.0
		velocity.x = knockback_vel.x
		velocity.z = knockback_vel.z
		move_and_slide()
		_play_anim("knockdown" if (downed_timer > 0.0 or stagger_timer > 1.3) else "stagger")
		return

	var active := is_active_state(is_night_ref)
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var detect_range := 45.0 if active else 9.0
	var move_speed := (3.3 if is_brute else 4.4) if active else 1.5
	var attack_cd := 1.1 if active else 1.8
	var attack_dmg := 26.0 if is_brute else 14.0
	if not active:
		attack_dmg *= 0.65

	var desired_dir := Vector3.ZERO
	var target_dist := INF
	if player != null and is_instance_valid(player):
		var to_player := player.global_position - global_position
		to_player.y = 0.0
		target_dist = to_player.length()
		if target_dist <= detect_range and target_dist > 0.05:
			desired_dir = to_player / target_dist

	if active and _lunge_timer <= 0.0 and _lunge_cd <= 0.0 and is_on_floor() and target_dist >= 1.8 and target_dist <= 4.2 and desired_dir != Vector3.ZERO:
		_lunge_timer = 0.24
		_lunge_cd = 2.6
		_lunge_dir = desired_dir

	if _lunge_timer > 0.0:
		_lunge_timer -= delta
		desired_dir = _lunge_dir
		move_speed *= 2.1
		if _body_mesh != null:
			_body_mesh.rotation.x = lerpf(_body_mesh.rotation.x, -0.32, clampf(delta * 16.0, 0.0, 1.0))
	elif _body_mesh != null:
		_body_mesh.rotation.x = lerpf(_body_mesh.rotation.x, 0.0, clampf(delta * 10.0, 0.0, 1.0))

	if desired_dir == Vector3.ZERO:
		_wander_timer -= delta
		if _wander_timer <= 0.0:
			_wander_timer = randf_range(1.8, 3.8)
			var to_home := _spawn_pos - global_position
			to_home.y = 0.0
			if to_home.length() > 6.0:
				_wander_dir = to_home.normalized()
			else:
				_wander_dir = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized()
		desired_dir = _wander_dir * 0.45

	if desired_dir.length() > 0.05:
		var look_yaw := atan2(-desired_dir.x, -desired_dir.z)
		rotation.y = lerp_angle(rotation.y, look_yaw, clampf(delta * 8.0, 0.0, 1.0))

	velocity.x = desired_dir.x * move_speed + knockback_vel.x
	velocity.z = desired_dir.z * move_speed + knockback_vel.z
	move_and_slide()

	# Grab or Attack blocking Structure or Player
	if active and not is_brute and _grab_cd <= 0.0 and player != null and target_dist <= 1.25 and absf(player.global_position.y - global_position.y) < 1.4:
		if player.has_method("can_be_grabbed") and player.can_be_grabbed():
			_grab_cd = 8.0
			_attack_timer = 2.0
			player.start_zombie_grab(self)
			_play_anim("attack_swipe")
			return

	if _attack_timer <= 0.0:
		var hit_structure := _find_blocking_structure()
		if hit_structure != null:
			hit_structure.take_damage(attack_dmg)
			Sfx.play(self, "zombie_attack", -8.0, randf_range(0.9, 1.1))
			_attack_timer = attack_cd
			_attack_anim_timer = 0.55
		elif player != null and target_dist <= 1.85 and absf(player.global_position.y - global_position.y) < 1.8:
			if player.has_method("take_damage"):
				player.take_damage(attack_dmg, global_position)
			Sfx.play(self, "zombie_attack", -6.0, randf_range(0.9, 1.1))
			_attack_timer = attack_cd
			_attack_anim_timer = 0.55

	if _attack_anim_timer > 0.0:
		_play_anim("attack_swipe")
	elif active and target_dist <= detect_range:
		_play_anim("chase_run")
	elif desired_dir.length() > 0.05:
		_play_anim("shamble")
	else:
		_play_anim("idle_sunlight")

	_groan_timer -= delta
	if _groan_timer <= 0.0:
		_groan_timer = randf_range(5.0, 11.0)
		if active and target_dist < 18.0:
			Sfx.play(self, "zombie_groan", -12.0, randf_range(0.85, 1.12))


func _find_blocking_structure() -> Structure:
	var best: Structure = null
	var best_d := 2.05
	for node in get_tree().get_nodes_in_group("structures"):
		if not is_instance_valid(node) or not (node is Structure):
			continue
		var s := node as Structure
		var d := Vector2(s.global_position.x - global_position.x, s.global_position.z - global_position.z).length()
		if d < best_d:
			best_d = d
			best = s
	return best


func apply_hit(damage: float, knockback: Vector3, stagger: float = 0.35) -> bool:
	if _is_dying:
		return false
	hp -= damage
	knockback_vel = Vector3(knockback.x, 0.0, knockback.z)
	stagger_timer = maxf(stagger_timer, stagger)
	_flash_timer = 0.10
	_refresh_sunlight_visuals()
	if hp <= 0.0:
		_is_dying = true
		downed_timer = 0.0
		_death_timer = 4.0
		_play_anim("death")
		set_sense_highlight(false)
		collision_layer = 0
		collision_mask = 0
		if is_in_group("enemies"):
			remove_from_group("enemies")
		died.emit(self)
		return true
	return false
