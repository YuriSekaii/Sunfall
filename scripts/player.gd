class_name Player
extends CharacterBody3D

signal died
signal log_message(text: String)

# Dying Light default_levels.xml tuned movement
const WALK_SPEED := 3.5
const BACK_STRAFE_SPEED := 2.5
const SPRINT_SPEED := 6.0
const CROUCH_SPEED := 1.5
const SLIDE_SPEED := 8.4
const SPRINT_ACCEL := 10.0
const AIR_CONTROL := 0.22
const JUMP_VELOCITY := 5.6
const MIN_JUMP_INTERVAL := 0.4
const BASE_FOV := 72.0
const SPRINT_FOV_BONUS := 4.5
const GRAVITY := 18.0
const WALL_RUN_EXTRA_GRAVITY := 9.5
const WALL_JUMP_BACK_HEIGHT := 0.8
const MAX_WALL_JUMPS := 2
const CROUCH_DAMPING_WINDOW_TIME := 1.0

# Stamina & survival
var hp: float = 100.0
var max_hp: float = 100.0
var stamina: float = 1.0
var exhausted: bool = false
var hunger: float = 100.0
var thirst: float = 100.0
var is_dead: bool = false

var inventory: Dictionary = {
	"wood": 6,
	"metal": 2,
	"gunpowder": 1,
	"food": 1,
	"water": 1,
	"medkit": 1,
}
var weapon_tier: int = 1
var active_slot: int = 1 # 1=Melee, 2=Wall, 3=Turret

var run_seed: int = 1337
var current_day: int = 1

var _head: Node3D
var _camera: Camera3D
var _flashlight: SpotLight3D
var _viewmodel_pivot: Node3D
var _viewmodel_mesh: MeshInstance3D
var _kick_pivot: Node3D
var _build_ghost: MeshInstance3D
var _fpp_rig: Node3D
var _fpp_skel: Skeleton3D
var _fpp_anim: AnimationPlayer
var _weapon_socket: BoneAttachment3D
var _current_fpp_anim: String = ""
var _fpp_action_lock_timer: float = 0.0
var _dodge_anim_name: String = "dodge_left"

var _yaw: float = 0.0
var _pitch: float = 0.0
var _jump_cd: float = 0.0
var _attack_cd: float = 0.0
var _kick_cd: float = 0.0
var _stamina_regen_delay: float = 0.0
var _hp_regen_delay: float = 0.0
var _slide_timer: float = 0.0
var _slide_dir: Vector3 = Vector3.ZERO
var _vaulting: bool = false
var _vault_start: Vector3 = Vector3.ZERO
var _vault_end: Vector3 = Vector3.ZERO
var _vault_t: float = 0.0
var _bob_phase: float = 0.0
var _step_phase: float = 0.0
var _swing_anim: float = 0.0
var _kick_anim: float = 0.0
var _cam_punch: float = 0.0
var _shake_intensity: float = 0.0
var damage_flash: float = 0.0
var damage_dir_x: float = 0.0
var _suppress_click_until_msec: int = 0
var allow_headless_mouse_look_for_test: bool = false

# DL1 combat & parkour state
var _melee_charging: bool = false
var _melee_charge_time: float = 0.0
var _combo_side: int = 1
var _swing_roll_impulse: float = 0.0
var _kick_hit_timer: float = -1.0
var _dropkicking: bool = false
var _dropkick_hit_done: bool = false
var _landing_recovery: float = 0.0
var _vault_peak_boost: float = 0.22
var _dodge_timer: float = 0.0
var _dodge_cd: float = 0.0
var _dodge_dir: Vector3 = Vector3.ZERO
var _dodge_roll: float = 0.0
var _sense_timer: float = 0.0
var _sense_cd: float = 0.0

# Wall-run, landing roll, and apex melee state
var _wall_running: bool = false
var _wall_run_timer: float = 0.0
var _wall_run_cd: float = 0.0
var _wall_run_side: int = 0 # -1=left, 1=right
var _wall_run_normal: Vector3 = Vector3.ZERO
var _wall_jumps_used: int = 0
var _wall_step_phase: float = 0.0
var _vault_kind: String = "vault"
var _vault_preserve_sprint: bool = false
var _was_airborne: bool = false
var _air_peak_y: float = 0.0
var _crouch_damping_timer: float = 0.0
var _landing_roll_timer: float = 0.0
var _landing_roll_dir: Vector3 = Vector3.ZERO
var _pending_melee_timer: float = -1.0
var _pending_melee_heavy: bool = false
var _hit_pause_timer: float = 0.0

var _loot_target: LootContainer = null
var _loot_progress: float = 0.0
var _prompt_text: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	collision_layer = 2
	collision_mask = 1 | 4 | 16
	add_to_group("player")
	_yaw = rotation.y
	_build_rig()
	_refresh_viewmodel()


func _build_rig() -> void:
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.38
	cap.height = 1.75
	col.shape = cap
	col.position = Vector3(0.0, 0.88, 0.0)
	add_child(col)

	_head = Node3D.new()
	_head.position = Vector3(0.0, 1.56, 0.0)
	add_child(_head)

	_camera = Camera3D.new()
	_camera.fov = BASE_FOV
	_camera.current = true
	_head.add_child(_camera)

	_flashlight = SpotLight3D.new()
	_flashlight.light_energy = 3.2
	_flashlight.spot_range = 24.0
	_flashlight.spot_angle = 32.0
	_flashlight.light_color = Color(1.0, 0.96, 0.86)
	_flashlight.visible = false
	_camera.add_child(_flashlight)

	_viewmodel_pivot = Node3D.new()
	_viewmodel_pivot.position = Vector3(0.32, -0.26, -0.45)
	_camera.add_child(_viewmodel_pivot)

	_viewmodel_mesh = MeshInstance3D.new()
	var vm_box := BoxMesh.new()
	vm_box.size = Vector3(0.08, 0.08, 0.62)
	_viewmodel_mesh.mesh = vm_box
	_viewmodel_mesh.position = Vector3(0.0, 0.0, -0.22)
	_viewmodel_mesh.material_override = StandardMaterial3D.new()
	_viewmodel_pivot.add_child(_viewmodel_mesh)

	_kick_pivot = Node3D.new()
	_kick_pivot.position = Vector3(0.0, -0.55, -0.22)
	_kick_pivot.visible = false
	_camera.add_child(_kick_pivot)

	var leg_mat := StandardMaterial3D.new()
	leg_mat.albedo_color = Color(0.22, 0.25, 0.30)
	leg_mat.roughness = 0.85
	var leg_mesh := MeshInstance3D.new()
	var leg_box := BoxMesh.new()
	leg_box.size = Vector3(0.14, 0.14, 0.56)
	leg_mesh.mesh = leg_box
	leg_mesh.position = Vector3(0.0, 0.0, -0.24)
	leg_mesh.material_override = leg_mat
	_kick_pivot.add_child(leg_mesh)

	var boot_mat := StandardMaterial3D.new()
	boot_mat.albedo_color = Color(0.16, 0.12, 0.10)
	boot_mat.roughness = 0.75
	var boot_mesh := MeshInstance3D.new()
	var boot_box := BoxMesh.new()
	boot_box.size = Vector3(0.16, 0.18, 0.22)
	boot_mesh.mesh = boot_box
	boot_mesh.position = Vector3(0.0, 0.03, -0.56)
	boot_mesh.material_override = boot_mat
	_kick_pivot.add_child(boot_mesh)

	_fpp_rig = RefAssets.instantiate_dl_player_fpp()
	if _fpp_rig != null:
		add_child(_fpp_rig)
		_hide_head_meshes(_fpp_rig)
		_fpp_anim = RefAssets.find_animation_player(_fpp_rig)
		_fpp_skel = RefAssets.find_skeleton(_fpp_rig)
		RefAssets.set_loop_mode_for_clips(_fpp_anim, ["idle", "walk", "sprint", "heavy_charge", "wall_run_left", "wall_run_right"])
		if _fpp_skel != null and _fpp_skel.find_bone("WeaponSocket") != -1:
			_weapon_socket = BoneAttachment3D.new()
			_weapon_socket.name = "WeaponSocketAttachment"
			_weapon_socket.bone_name = "WeaponSocket"
			_fpp_skel.add_child(_weapon_socket)
		_viewmodel_pivot.visible = false
		_kick_pivot.visible = false
		_play_fpp_anim("idle", true)

	_build_ghost = MeshInstance3D.new()
	_build_ghost.visible = false
	var ghost_mat := StandardMaterial3D.new()
	ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_mat.albedo_color = Color(0.2, 0.95, 0.4, 0.45)
	ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_build_ghost.material_override = ghost_mat
	get_tree().root.call_deferred("add_child", _build_ghost)


func _exit_tree() -> void:
	if is_instance_valid(_build_ghost):
		_build_ghost.queue_free()


func suppress_capture_click() -> void:
	_suppress_click_until_msec = Time.get_ticks_msec() + 120


func _input(event: InputEvent) -> void:
	if is_dead or get_tree() == null or get_tree().paused:
		return
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	var can_look := captured and DisplayServer.get_name() != "headless"
	if allow_headless_mouse_look_for_test:
		can_look = true
	if event is InputEventMouseMotion and can_look:
		_yaw -= event.relative.x * 0.0024
		_pitch = clampf(_pitch - event.relative.y * 0.0024, -1.42, 1.42)
		rotation.y = _yaw
		_head.rotation.x = _pitch


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	_jump_cd = maxf(0.0, _jump_cd - delta)
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_kick_cd = maxf(0.0, _kick_cd - delta)
	_dodge_cd = maxf(0.0, _dodge_cd - delta)
	_sense_cd = maxf(0.0, _sense_cd - delta)
	_wall_run_cd = maxf(0.0, _wall_run_cd - delta)
	_crouch_damping_timer = maxf(0.0, _crouch_damping_timer - delta)
	_fpp_action_lock_timer = maxf(0.0, _fpp_action_lock_timer - delta)
	_landing_recovery = maxf(0.0, _landing_recovery - delta)
	_stamina_regen_delay = maxf(0.0, _stamina_regen_delay - delta)
	_hp_regen_delay = maxf(0.0, _hp_regen_delay - delta)
	if _hit_pause_timer > 0.0:
		_hit_pause_timer = maxf(0.0, _hit_pause_timer - delta)
	else:
		_swing_anim = maxf(0.0, _swing_anim - delta * 4.2)
		_kick_anim = maxf(0.0, _kick_anim - delta * (2.2 if _dropkicking else 3.2))
	_swing_roll_impulse = lerpf(_swing_roll_impulse, 0.0, clampf(delta * 10.0, 0.0, 1.0))
	_dodge_roll = lerpf(_dodge_roll, 0.0, clampf(delta * 10.0, 0.0, 1.0))
	_cam_punch = lerpf(_cam_punch, 0.0, clampf(delta * 14.0, 0.0, 1.0))
	_shake_intensity = maxf(0.0, _shake_intensity - delta * 0.55)
	damage_flash = maxf(0.0, damage_flash - delta * 1.8)

	if _sense_timer > 0.0:
		_sense_timer -= delta
		if _sense_timer <= 0.0:
			_apply_survivor_sense(false)

	if _kick_hit_timer >= 0.0:
		_kick_hit_timer -= delta
		if _kick_hit_timer <= 0.0:
			_kick_hit_timer = -1.0
			_execute_kick_hit(false)

	if _pending_melee_timer >= 0.0 and _hit_pause_timer <= 0.0:
		_pending_melee_timer -= delta
		if _pending_melee_timer <= 0.0:
			_pending_melee_timer = -1.0
			_execute_melee_apex_hit(_pending_melee_heavy)

	_handle_hotkeys(delta)
	_update_survival_needs(delta)

	if _vaulting:
		var vault_dur := 0.20 if _vault_kind == "vault" else 0.34
		_vault_t += delta / vault_dur
		if _vault_t >= 1.0:
			global_position = _vault_end
			_vaulting = false
			_was_airborne = false
			_air_peak_y = global_position.y
			if _vault_preserve_sprint:
				var fwd := -transform.basis.z
				fwd.y = 0.0
				fwd = fwd.normalized()
				velocity = fwd * SPRINT_SPEED
			else:
				velocity = Vector3.ZERO
				_cam_punch = -0.045
		else:
			var ease_t := 1.0 - pow(1.0 - _vault_t, 2.0)
			var pos := _vault_start.lerp(_vault_end, ease_t)
			pos.y += sin(_vault_t * PI) * _vault_peak_boost
			global_position = pos
			velocity = Vector3.ZERO
	else:
		_process_movement(delta)

	if _dropkicking:
		if not _dropkick_hit_done:
			if _execute_kick_hit(true):
				_dropkick_hit_done = true
		if is_on_floor():
			_dropkicking = false
			_landing_recovery = 0.28
			_cam_punch = 0.11
			_shake_intensity = maxf(_shake_intensity, 0.08)

	_update_camera_and_viewmodel(delta)
	_update_interaction(delta)
	_update_build_ghost()


func _handle_hotkeys(delta: float) -> void:
	if Input.is_action_just_pressed("slot_1"):
		active_slot = 1
		_melee_charging = false
		_refresh_viewmodel()
	elif Input.is_action_just_pressed("slot_2"):
		active_slot = 2
		_melee_charging = false
		_refresh_viewmodel()
	elif Input.is_action_just_pressed("slot_3"):
		active_slot = 3
		_melee_charging = false
		_refresh_viewmodel()

	if Input.is_action_just_pressed("flashlight"):
		_flashlight.visible = not _flashlight.visible
	if Input.is_action_just_pressed("use_heal"):
		use_medkit()
	if Input.is_action_just_pressed("use_food"):
		use_food_or_water()
	if Input.is_action_just_pressed("kick"):
		perform_kick()
	if Input.is_action_just_pressed("survivor_sense"):
		trigger_survivor_sense()

	if Input.is_action_just_pressed("primary_action"):
		if Time.get_ticks_msec() <= _suppress_click_until_msec:
			_suppress_click_until_msec = 0
		elif active_slot == 1:
			_melee_charging = true
			_melee_charge_time = 0.0
		else:
			_perform_primary()

	if _melee_charging:
		if active_slot != 1:
			_melee_charging = false
		elif Input.is_action_pressed("primary_action"):
			_melee_charge_time += delta
		else:
			_melee_charging = false
			_melee_swing(_melee_charge_time >= 0.35)

	if Input.is_action_just_pressed("secondary_action"):
		_perform_secondary()


func _process_movement(delta: float) -> void:
	var input_vec := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish_dir := (transform.basis * Vector3(input_vec.x, 0.0, input_vec.y)).normalized()

	var wants_crouch := Input.is_action_pressed("crouch")
	if Input.is_action_just_pressed("crouch") or wants_crouch:
		_crouch_damping_timer = CROUCH_DAMPING_WINDOW_TIME
	var wants_sprint := Input.is_action_pressed("sprint") and input_vec.y < -0.1 and not wants_crouch and not exhausted and stamina > 0.02

	# Quick Dodge / Sidestep (Alt + A/D/S)
	var dodge_dir_input := Vector2.ZERO
	if Input.is_action_just_pressed("dodge") and (absf(input_vec.x) > 0.1 or input_vec.y > 0.1):
		dodge_dir_input = Vector2(input_vec.x, maxf(0.0, input_vec.y))
	elif Input.is_action_pressed("dodge"):
		if Input.is_action_just_pressed("move_left"):
			dodge_dir_input = Vector2(-1.0, 0.0)
		elif Input.is_action_just_pressed("move_right"):
			dodge_dir_input = Vector2(1.0, 0.0)
		elif Input.is_action_just_pressed("move_back"):
			dodge_dir_input = Vector2(0.0, 1.0)

	if dodge_dir_input != Vector2.ZERO and is_on_floor() and _dodge_cd <= 0.0 and _dodge_timer <= 0.0 and not exhausted and stamina >= 0.10:
		_spend_stamina(0.20)
		_dodge_timer = 0.22
		_dodge_cd = 0.55
		_dodge_dir = (transform.basis * Vector3(dodge_dir_input.x, 0.0, dodge_dir_input.y)).normalized()
		_dodge_roll = -dodge_dir_input.x * 0.11
		_dodge_anim_name = "dodge_right" if dodge_dir_input.x > 0.1 else "dodge_left"
		Sfx.play(self, "climb", -9.0, 1.25)

	# Crouch-slide trigger
	if Input.is_action_just_pressed("crouch") and is_on_floor() and velocity.length() > 4.6 and _slide_timer <= 0.0 and _landing_roll_timer <= 0.0:
		_slide_timer = 0.50
		_slide_dir = Vector3(velocity.x, 0.0, velocity.z).normalized()
		Sfx.play(self, "climb", -10.0, 0.85)

	if _landing_roll_timer > 0.0:
		_landing_roll_timer = maxf(0.0, _landing_roll_timer - delta)
		velocity.x = _landing_roll_dir.x * 7.8
		velocity.z = _landing_roll_dir.z * 7.8
	elif _dodge_timer > 0.0:
		_dodge_timer -= delta
		velocity.x = _dodge_dir.x * 12.5
		velocity.z = _dodge_dir.z * 12.5
	elif _slide_timer > 0.0:
		_slide_timer -= delta
		velocity.x = _slide_dir.x * SLIDE_SPEED
		velocity.z = _slide_dir.z * SLIDE_SPEED
		_check_slide_knockback()
	elif _wall_running:
		_process_wall_run(delta)
	else:
		var target_speed := WALK_SPEED
		if wants_crouch:
			target_speed = CROUCH_SPEED
		elif wants_sprint:
			target_speed = SPRINT_SPEED
			_spend_stamina(0.10 * delta)
		elif input_vec.y > 0.1 or absf(input_vec.x) > 0.1:
			target_speed = BACK_STRAFE_SPEED

		if hunger <= 0.0 or thirst <= 0.0:
			target_speed *= 0.8
		if _landing_recovery > 0.0:
			target_speed *= 0.45

		var accel := SPRINT_ACCEL if is_on_floor() else SPRINT_ACCEL * AIR_CONTROL
		if not _dropkicking:
			velocity.x = lerpf(velocity.x, wish_dir.x * target_speed, clampf(delta * accel, 0.0, 1.0))
			velocity.z = lerpf(velocity.z, wish_dir.z * target_speed, clampf(delta * accel, 0.0, 1.0))

	if _wall_running:
		if Input.is_action_just_pressed("jump") and _jump_cd <= 0.0:
			_perform_wall_jump()
	elif not is_on_floor():
		velocity.y -= GRAVITY * delta
		_try_start_wall_run(input_vec)
	elif Input.is_action_just_pressed("jump") and _jump_cd <= 0.0:
		var can_zombie_vault := wants_sprint or Vector2(velocity.x, velocity.z).length() > 4.2
		if not (can_zombie_vault and _try_vault_over_zombie()) and not _try_vault():
			velocity.y = JUMP_VELOCITY
			_jump_cd = MIN_JUMP_INTERVAL

	# Auto-mantle if moving forward in air toward a ledge
	if not is_on_floor() and not _wall_running and Input.is_action_pressed("jump") and input_vec.y < -0.1:
		_try_vault()

	move_and_slide()

	if is_on_floor():
		_wall_running = false
		_wall_jumps_used = 0
		if _was_airborne:
			_was_airborne = false
			var fall_dist := _air_peak_y - global_position.y
			_resolve_landing(fall_dist)
		_air_peak_y = global_position.y
	else:
		if not _was_airborne:
			_was_airborne = true
			_air_peak_y = global_position.y
		else:
			_air_peak_y = maxf(_air_peak_y, global_position.y)
		if _wall_running:
			_air_peak_y = global_position.y


func _try_start_wall_run(input_vec: Vector2) -> bool:
	if _wall_running or _wall_run_cd > 0.0 or _wall_jumps_used >= MAX_WALL_JUMPS or _dropkicking or _vaulting:
		return false
	var horiz := Vector2(velocity.x, velocity.z).length()
	if input_vec.y >= -0.1 and horiz < 3.0:
		return false
	var space := get_world_3d().direct_space_state
	var origin := global_position + Vector3(0.0, 1.0, 0.0)
	var right := transform.basis.x
	right.y = 0.0
	right = right.normalized()
	for side in [-1, 1]:
		var probe := right * float(side) * 0.85
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(origin, origin + probe, 1 | 16, [get_rid()]))
		if not hit.is_empty():
			var n := Vector3(hit["normal"])
			if absf(n.y) < 0.35:
				_wall_running = true
				_wall_run_timer = 1.1
				_wall_run_side = side
				_wall_run_normal = Vector3(n.x, 0.0, n.z).normalized()
				_wall_step_phase = 0.0
				velocity.y = maxf(velocity.y, 1.8)
				Sfx.play(self, "footstep", -12.0, 1.1)
				return true
	return false


func _process_wall_run(delta: float) -> void:
	_wall_run_timer -= delta
	velocity.y -= WALL_RUN_EXTRA_GRAVITY * delta
	var forward := -transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var tangent := forward.slide(_wall_run_normal)
	if tangent.length() < 0.1:
		_wall_running = false
		return
	tangent = tangent.normalized()
	var run_speed := maxf(SPRINT_SPEED, Vector2(velocity.x, velocity.z).length())
	velocity.x = tangent.x * run_speed
	velocity.z = tangent.z * run_speed

	var prev_step := _wall_step_phase
	_wall_step_phase += delta * 4.5
	if int(floor(_wall_step_phase)) > int(floor(prev_step)):
		Sfx.play(self, "footstep", -12.0, randf_range(0.95, 1.15))

	var space := get_world_3d().direct_space_state
	var origin := global_position + Vector3(0.0, 1.0, 0.0)
	var check_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(origin, origin - _wall_run_normal * 0.95, 1 | 16, [get_rid()]))
	if check_hit.is_empty() or _wall_run_timer <= 0.0:
		_wall_running = false
		_wall_run_cd = 0.2


func _perform_wall_jump() -> void:
	_wall_running = false
	_wall_jumps_used += 1
	_wall_run_cd = 0.22
	_jump_cd = 0.22
	var forward := -transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var tangent := forward.slide(_wall_run_normal).normalized()
	velocity = _wall_run_normal * 5.2 + tangent * 4.5 + Vector3.UP * (JUMP_VELOCITY + WALL_JUMP_BACK_HEIGHT)
	Sfx.play(self, "climb", -5.0, 1.15)


func _resolve_landing(fall_dist: float) -> void:
	if fall_dist <= 4.8:
		return
	if _crouch_damping_timer > 0.0 or Input.is_action_pressed("crouch"):
		_landing_roll_timer = 0.48
		var fwd := -transform.basis.z
		fwd.y = 0.0
		_landing_roll_dir = fwd.normalized()
		Sfx.play(self, "climb", -5.0, 0.9)
		log_message.emit("Parkour Landing Roll! (0 fall damage)")
	else:
		var dmg := clampf((fall_dist - 4.8) * 14.0, 8.0, 95.0)
		take_damage(dmg, global_position)
		_landing_recovery = 0.35
		_shake_intensity = maxf(_shake_intensity, 0.16)
		Sfx.play(self, "kick", -1.0, 0.65)
		log_message.emit("Hard landing! (-%d HP)" % int(round(dmg)))


func _try_vault() -> bool:
	var forward := -transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var space := get_world_3d().direct_space_state

	var chest_from := global_position + Vector3(0.0, 0.95, 0.0)
	var chest_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(chest_from, chest_from + forward * 1.15, 1 | 16, [get_rid()]))
	if chest_hit.is_empty():
		return false

	var head_from := global_position + Vector3(0.0, 2.55, 0.0)
	var head_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(head_from, head_from + forward * 1.15, 1 | 16, [get_rid()]))
	if not head_hit.is_empty():
		return false

	var top_probe := global_position + Vector3(0.0, 2.60, 0.0) + forward * 0.95
	var down_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(top_probe, top_probe + Vector3(0.0, -2.2, 0.0), 1 | 16, [get_rid()]))
	if down_hit.is_empty():
		return false

	var ledge_y: float = down_hit["position"].y
	var height_diff := ledge_y - global_position.y
	if height_diff < 0.45 or height_diff > 2.45:
		return false

	_vaulting = true
	_vault_t = 0.0
	if height_diff <= 1.25:
		_vault_kind = "vault"
		_vault_preserve_sprint = true
		_vault_peak_boost = 0.25
		_vault_end = Vector3(down_hit["position"].x, ledge_y + 0.05, down_hit["position"].z) + forward * 0.45
	else:
		_vault_kind = "climb_ledge"
		_vault_preserve_sprint = false
		_vault_peak_boost = 0.18
		_cam_punch = -0.055
		_vault_end = Vector3(down_hit["position"].x, ledge_y + 0.05, down_hit["position"].z) + forward * 0.25
	_vault_start = global_position
	Sfx.play(self, "climb", -6.0, randf_range(0.95, 1.1))
	return true


func _try_vault_over_zombie() -> bool:
	var forward := -transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var best_z: Zombie = null
	var best_d := 1.85
	for node in get_tree().get_nodes_in_group("enemies"):
		if not (node is Zombie) or not is_instance_valid(node):
			continue
		var z := node as Zombie
		if absf(z.global_position.y - global_position.y) > 1.5:
			continue
		var to_z := z.global_position - global_position
		to_z.y = 0.0
		var d := to_z.length()
		if d > 0.1 and d <= best_d and forward.dot(to_z / d) > 0.45:
			best_d = d
			best_z = z
	if best_z == null:
		return false

	best_z.apply_stun(2.5)
	_vaulting = true
	_vault_t = 0.0
	_vault_peak_boost = 1.45
	_vault_start = global_position
	_vault_end = best_z.global_position + forward * 1.65
	_jump_cd = MIN_JUMP_INTERVAL
	Sfx.play(self, "climb", -5.0, 1.15)
	log_message.emit("Vaulted over infected!")
	return true


func _check_slide_knockback() -> void:
	for node in get_tree().get_nodes_in_group("enemies"):
		if node is Zombie and is_instance_valid(node):
			var z := node as Zombie
			if global_position.distance_to(z.global_position) < 1.55 and z.stagger_timer <= 0.0:
				z.apply_hit(6.0, _slide_dir * 8.0, 0.7)


func _update_survival_needs(delta: float) -> void:
	if _stamina_regen_delay <= 0.0 and stamina < 1.0:
		var regen_rate := 0.45 if (hunger > 0.0 and thirst > 0.0) else 0.22
		stamina = minf(1.0, stamina + regen_rate * delta)
		if exhausted and stamina >= 0.33:
			exhausted = false

	if _hp_regen_delay <= 0.0 and hp < 25.0:
		hp = minf(25.0, hp + 3.0 * delta)

	hunger = maxf(0.0, hunger - 0.16 * delta)
	thirst = maxf(0.0, thirst - 0.22 * delta)
	if hunger <= 0.0 or thirst <= 0.0:
		hp = maxf(1.0, hp - 0.35 * delta)


func _spend_stamina(amount: float) -> void:
	stamina = maxf(0.0, stamina - amount)
	if stamina <= 0.001:
		exhausted = true
		_stamina_regen_delay = 4.0
	else:
		_stamina_regen_delay = maxf(_stamina_regen_delay, 2.5)


func _update_camera_and_viewmodel(delta: float) -> void:
	var target_h := 0.96 if (_slide_timer > 0.0 or Input.is_action_pressed("crouch")) else 1.56
	_head.position.y = lerpf(_head.position.y, target_h, clampf(delta * 12.0, 0.0, 1.0))

	var horiz_speed := Vector2(velocity.x, velocity.z).length()
	var is_sprinting := horiz_speed > 4.6 and is_on_floor() and _slide_timer <= 0.0
	var target_fov := BASE_FOV + (SPRINT_FOV_BONUS if is_sprinting else 0.0)
	_camera.fov = lerpf(_camera.fov, target_fov, clampf(delta * 8.0, 0.0, 1.0))

	var strafe := Input.get_axis("move_left", "move_right")
	var wall_roll := (-float(_wall_run_side) * deg_to_rad(11.0)) if _wall_running else 0.0
	var target_roll := (-0.08 if _slide_timer > 0.0 else 0.0) - strafe * 0.025 + _swing_roll_impulse + _dodge_roll + wall_roll
	_camera.rotation.z = lerpf(_camera.rotation.z, target_roll, clampf(delta * 10.0, 0.0, 1.0))
	var landing_pitch := -sin((_landing_recovery / 0.28) * PI) * 0.14 if _landing_recovery > 0.0 else 0.0
	var roll_pitch := -(1.0 - (_landing_roll_timer / 0.48)) * TAU if _landing_roll_timer > 0.0 else 0.0
	_camera.rotation.x = _cam_punch + landing_pitch + roll_pitch

	if _shake_intensity > 0.001:
		_camera.h_offset = randf_range(-1.0, 1.0) * _shake_intensity
		_camera.v_offset = randf_range(-1.0, 1.0) * _shake_intensity
	else:
		_camera.h_offset = lerpf(_camera.h_offset, 0.0, clampf(delta * 18.0, 0.0, 1.0))
		_camera.v_offset = lerpf(_camera.v_offset, 0.0, clampf(delta * 18.0, 0.0, 1.0))

	if is_on_floor() and horiz_speed > 0.4 and _slide_timer <= 0.0 and _dodge_timer <= 0.0:
		var prev_step := _step_phase
		var bob_rate := 12.5 if is_sprinting else 7.5
		_bob_phase += delta * bob_rate
		_step_phase += delta * (bob_rate / PI)
		if int(floor(_step_phase)) > int(floor(prev_step)):
			Sfx.play(self, "footstep", -16.0 if is_sprinting else -22.0, randf_range(0.92, 1.08))
		var bob_amp := 0.032 if is_sprinting else 0.014
		_camera.position.y = lerpf(_camera.position.y, sin(_bob_phase) * bob_amp, clampf(delta * 12.0, 0.0, 1.0))
		_camera.position.x = lerpf(_camera.position.x, cos(_bob_phase * 0.5) * bob_amp * 0.65, clampf(delta * 12.0, 0.0, 1.0))
		_viewmodel_pivot.position.y = -0.26 + sin(_bob_phase) * (0.028 if is_sprinting else 0.016)
		_viewmodel_pivot.position.x = 0.32 + cos(_bob_phase * 0.5) * (0.022 if is_sprinting else 0.014)
	else:
		_camera.position.y = lerpf(_camera.position.y, 0.0, clampf(delta * 10.0, 0.0, 1.0))
		_camera.position.x = lerpf(_camera.position.x, 0.0, clampf(delta * 10.0, 0.0, 1.0))
		_viewmodel_pivot.position.y = lerpf(_viewmodel_pivot.position.y, -0.26, clampf(delta * 8.0, 0.0, 1.0))
		_viewmodel_pivot.position.x = lerpf(_viewmodel_pivot.position.x, 0.32, clampf(delta * 8.0, 0.0, 1.0))

	var charge_pull := clampf(_melee_charge_time / 0.35, 0.0, 1.0) if _melee_charging else 0.0
	var swing_angle := sin(_swing_anim * PI) * 1.15
	_viewmodel_pivot.rotation.x = -swing_angle + charge_pull * 0.55
	_viewmodel_pivot.rotation.y = swing_angle * 0.45 * float(_combo_side)
	_viewmodel_pivot.rotation.z = swing_angle * 0.35 * float(_combo_side)

	if _fpp_rig != null:
		_update_fpp_animation(horiz_speed)
		return

	if _kick_pivot != null:
		if _kick_anim > 0.0:
			var k := sin(_kick_anim * PI)
			_kick_pivot.visible = true
			_kick_pivot.position = Vector3(0.0, lerpf(-0.56, -0.18 if _dropkicking else -0.22, k), lerpf(-0.18, -0.82 if _dropkicking else -0.68, k))
			_kick_pivot.rotation.x = lerpf(-0.25, 0.52 if _dropkicking else 0.42, k)
		else:
			_kick_pivot.visible = false


func _hide_head_meshes(node: Node) -> void:
	if node is MeshInstance3D:
		var n := node.name.to_lower()
		if n.contains("head") or n.contains("neck"):
			(node as MeshInstance3D).visible = false
	for child in node.get_children():
		_hide_head_meshes(child)


func _play_fpp_anim(anim_name: String, force: bool = false) -> void:
	if _fpp_anim == null or not _fpp_anim.has_animation(anim_name):
		return
	if not force and _current_fpp_anim == anim_name and _fpp_anim.is_playing():
		return
	_current_fpp_anim = anim_name
	_fpp_anim.play(anim_name, 0.12)


func _update_fpp_animation(horiz_speed: float) -> void:
	if _fpp_anim == null:
		return
	_fpp_anim.speed_scale = 0.0 if _hit_pause_timer > 0.0 else 1.0
	if _vaulting:
		_play_fpp_anim(_vault_kind)
	elif _dropkicking:
		_play_fpp_anim("dropkick")
	elif _landing_roll_timer > 0.0:
		_play_fpp_anim("slide")
	elif _dodge_timer > 0.0:
		_play_fpp_anim(_dodge_anim_name)
	elif _slide_timer > 0.0:
		_play_fpp_anim("slide")
	elif _wall_running:
		_play_fpp_anim("wall_run_left" if _wall_run_side < 0 else "wall_run_right")
	elif _fpp_action_lock_timer > 0.0:
		pass
	elif _melee_charging:
		_play_fpp_anim("heavy_charge")
	elif horiz_speed > 4.6 and is_on_floor():
		_play_fpp_anim("sprint")
	elif horiz_speed > 0.35 and is_on_floor():
		_play_fpp_anim("walk")
	else:
		_play_fpp_anim("idle")


func _perform_primary() -> void:
	if active_slot == 1:
		_melee_swing()
	elif active_slot == 2:
		if not _try_repair_targeted():
			_try_place_structure("wall")
	elif active_slot == 3:
		if not _try_repair_targeted():
			_try_place_structure("turret")


func _perform_secondary() -> void:
	var s := _raycast_structure()
	if s != null and s.kind == "wall" and s.tier < 2:
		if int(inventory.get("metal", 0)) >= 2:
			inventory["metal"] -= 2
			s.upgrade()
			Sfx.play(self, "build", -4.0, 1.2)
			log_message.emit("Upgraded Wall to Reinforced Metal!")
		else:
			log_message.emit("Need 2 Metal to upgrade wall.")


func _melee_swing(heavy: bool = false) -> void:
	if _attack_cd > 0.0 or exhausted:
		return
	var stats := LootTable.weapon_stats(weapon_tier)
	var stam_cost := float(stats["stamina_cost"]) * (1.5 if heavy else 1.0)

	_attack_cd = 0.60
	_swing_anim = 1.0
	_combo_side = -_combo_side
	_swing_roll_impulse = deg_to_rad(6.0) * float(_combo_side) * (1.35 if heavy else 1.0)
	_cam_punch = -0.05 if heavy else -0.02
	_pending_melee_heavy = heavy
	_pending_melee_timer = 0.22 if heavy else 0.16
	if _fpp_anim != null:
		_fpp_action_lock_timer = 0.52 if heavy else 0.45
		_play_fpp_anim("heavy_swing" if heavy else ("swing_right" if _combo_side > 0 else "swing_left"), true)
	_spend_stamina(stam_cost * 0.5)
	Sfx.play(self, "swing", -7.0, 0.82 if heavy else randf_range(0.92, 1.08))


func _execute_melee_apex_hit(heavy: bool) -> bool:
	var stats := LootTable.weapon_stats(weapon_tier)
	var reach := float(stats["reach"]) + (0.25 if heavy else 0.0)
	var dmg := float(stats["damage"]) * (1.8 if heavy else 1.0)
	var stam_cost := float(stats["stamina_cost"]) * (1.5 if heavy else 1.0)
	var knock_mul := 13.5 if heavy else 6.5
	var stagger_dur := 0.95 if heavy else 0.32

	var from := _camera.global_position
	var dir := -_camera.global_transform.basis.z
	var hit := get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(from, from + dir * reach, 4 | 1 | 16, [get_rid()])
	)
	if not hit.is_empty() and hit["collider"] is Zombie:
		var z := hit["collider"] as Zombie
		var killed := z.apply_hit(dmg, dir * knock_mul, stagger_dur)
		z.pause_hit_freeze(0.045)
		_hit_pause_timer = 0.045
		_spend_stamina(stam_cost * 0.5)
		_cam_punch = -0.11 if heavy else -0.065
		_shake_intensity = maxf(_shake_intensity, 0.09 if heavy else 0.05)
		Sfx.play(self, "hit", -2.0 if heavy else -3.0, 0.82 if heavy else randf_range(0.9, 1.12))
		_spawn_impact_burst(Vector3(hit["position"]), Color(0.86, 0.08, 0.08))
		if killed:
			log_message.emit("Eliminated infected.")
		elif heavy:
			log_message.emit("Heavy Power Swing!")
		return true
	elif not hit.is_empty():
		_spawn_impact_burst(Vector3(hit["position"]), Color(1.0, 0.82, 0.32))
		Sfx.play(self, "hit", -11.0, 1.35)
	return false


func _spawn_impact_burst(pos: Vector3, tint: Color) -> void:
	var parent := get_parent()
	if parent == null or DisplayServer.get_name() == "headless":
		return
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = tint
	for i in 6:
		var p := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.055, 0.055, 0.055)
		p.mesh = box
		p.material_override = mat
		parent.add_child(p)
		p.global_position = pos
		var vel := Vector3(randf_range(-1.0, 1.0), randf_range(0.2, 1.4), randf_range(-1.0, 1.0)).normalized() * randf_range(2.0, 4.5)
		var tw := p.create_tween()
		tw.tween_property(p, "global_position", pos + vel * 0.24, 0.24)
		tw.parallel().tween_property(p, "scale", Vector3(0.05, 0.05, 0.05), 0.24)
		tw.finished.connect(p.queue_free)


func perform_kick() -> void:
	if _kick_cd > 0.0:
		return
	var input_vec := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if not is_on_floor() and input_vec.y < -0.1 and not exhausted and stamina >= 0.15:
		# Mid-air Dropkick
		_spend_stamina(0.35)
		_dropkicking = true
		_dropkick_hit_done = false
		_kick_cd = 0.85
		_kick_anim = 1.0
		_cam_punch = 0.07
		var forward := -transform.basis.z
		forward.y = 0.0
		forward = forward.normalized()
		velocity.x = forward.x * 9.5
		velocity.z = forward.z * 9.5
		velocity.y = maxf(velocity.y, 2.2)
		Sfx.play(self, "kick", -3.0, 0.9)
		return

	# Standing Kick (0.625s cycle, 0.25s hit beat, 0 stamina)
	_kick_cd = 0.625
	_kick_hit_timer = 0.25
	_kick_anim = 1.0
	_cam_punch = 0.045
	if _fpp_anim != null:
		_fpp_action_lock_timer = 0.55
		_play_fpp_anim("kick", true)
	Sfx.play(self, "kick", -4.0, randf_range(0.95, 1.08))


func _execute_kick_hit(is_dropkick: bool) -> bool:
	var from := _camera.global_position
	var dir := -_camera.global_transform.basis.z
	var reach := 2.9 if is_dropkick else 2.6
	var hit := get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(from, from + dir * reach, 4, [get_rid()])
	)
	if not hit.is_empty() and hit["collider"] is Zombie:
		var z := hit["collider"] as Zombie
		var knock := 23.0 if is_dropkick else 11.5
		var dmg := 18.0 if is_dropkick else 8.0
		var stag := 1.6 if is_dropkick else 1.1
		z.apply_hit(dmg, dir * knock, stag)
		_shake_intensity = maxf(_shake_intensity, 0.10 if is_dropkick else 0.06)
		Sfx.play(self, "hit", -1.5 if is_dropkick else -2.0, 0.72 if is_dropkick else 0.78)
		if is_dropkick:
			log_message.emit("Dropkick!")
		return true
	return false


func trigger_survivor_sense() -> bool:
	if _sense_cd > 0.0:
		return false
	_sense_timer = 3.5
	_sense_cd = 6.0
	_apply_survivor_sense(true)
	Sfx.play(self, "loot", -8.0, 0.65)
	log_message.emit("Survivor Sense active!")
	return true


func _apply_survivor_sense(active: bool) -> void:
	if get_tree() == null:
		return
	for node in get_tree().get_nodes_in_group("loot_containers"):
		if node is LootContainer and is_instance_valid(node):
			(node as LootContainer).set_sense_highlight(active)
	for node in get_tree().get_nodes_in_group("enemies"):
		if node is Zombie and is_instance_valid(node):
			var z := node as Zombie
			var within := global_position.distance_to(z.global_position) <= 45.0
			z.set_sense_highlight(active and within)


func _raycast_structure() -> Structure:
	var from := _camera.global_position
	var dir := -_camera.global_transform.basis.z
	var hit := get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(from, from + dir * 4.5, 16, [get_rid()])
	)
	if not hit.is_empty() and hit["collider"] is Structure:
		return hit["collider"] as Structure
	return null


func _try_repair_targeted() -> bool:
	var s := _raycast_structure()
	if s == null or s.hp >= s.max_hp:
		return false
	if int(inventory.get("wood", 0)) < 1:
		log_message.emit("Need 1 Wood to repair!")
		return true
	inventory["wood"] -= 1
	s.repair(60.0)
	Sfx.play(self, "repair", -5.0)
	log_message.emit("Repaired %s." % s.get_status_text())
	return true


func _compute_build_transform(kind: String) -> Dictionary:
	var from := _camera.global_position
	var dir := -_camera.global_transform.basis.z
	var hit := get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(from, from + dir * 5.2, 1, [get_rid()])
	)
	if hit.is_empty() or Vector3(hit["normal"]).y < 0.7:
		return {"valid": false, "pos": Vector3.ZERO, "yaw": 0.0}
	var pos: Vector3 = hit["position"]
	if pos.distance_to(global_position) < 1.35:
		return {"valid": false, "pos": pos, "yaw": 0.0}
	var yaw := rotation.y if kind == "wall" else 0.0
	return {"valid": true, "pos": pos, "yaw": yaw}


func _can_afford(kind: String) -> bool:
	if kind == "turret":
		return int(inventory.get("wood", 0)) >= 3 and int(inventory.get("metal", 0)) >= 2 and int(inventory.get("gunpowder", 0)) >= 1
	return int(inventory.get("wood", 0)) >= 3


func _try_place_structure(kind: String) -> bool:
	var placement := _compute_build_transform(kind)
	if not placement["valid"]:
		log_message.emit("Aim at flat ground in front of you to build.")
		return false
	if not _can_afford(kind):
		log_message.emit("Not enough materials for %s!" % kind)
		return false

	if kind == "turret":
		inventory["wood"] -= 3
		inventory["metal"] -= 2
		inventory["gunpowder"] -= 1
	else:
		inventory["wood"] -= 3

	var s := Structure.new()
	s.configure(kind)
	get_parent().add_child(s)
	s.global_position = placement["pos"]
	s.rotation.y = placement["yaw"]
	Sfx.play(self, "build", -4.0)
	log_message.emit("Built %s!" % ("Auto-Turret" if kind == "turret" else "Wood Barricade"))
	return true


func _update_build_ghost() -> void:
	if not is_instance_valid(_build_ghost):
		return
	if active_slot == 1 or _raycast_structure() != null:
		_build_ghost.visible = false
		return
	var kind := "wall" if active_slot == 2 else "turret"
	var placement := _compute_build_transform(kind)
	if not placement["valid"]:
		_build_ghost.visible = false
		return
	_build_ghost.visible = true
	var box := BoxMesh.new()
	box.size = Vector3(2.6, 2.0, 0.45) if kind == "wall" else Vector3(1.0, 1.4, 1.0)
	_build_ghost.mesh = box
	_build_ghost.global_position = placement["pos"] + Vector3(0.0, box.size.y * 0.5, 0.0)
	_build_ghost.rotation = Vector3(0.0, placement["yaw"], 0.0)
	var mat := _build_ghost.material_override as StandardMaterial3D
	mat.albedo_color = Color(0.2, 0.95, 0.4, 0.42) if _can_afford(kind) else Color(0.95, 0.25, 0.25, 0.42)


func _update_interaction(delta: float) -> void:
	_prompt_text = ""
	var from := _camera.global_position
	var dir := -_camera.global_transform.basis.z
	var hit := get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(from, from + dir * 3.3, 8 | 16, [get_rid()])
	)

	var container: LootContainer = null
	if not hit.is_empty() and hit["collider"] is LootContainer:
		var c := hit["collider"] as LootContainer
		if not c.is_looted:
			container = c

	if container != _loot_target:
		_loot_target = container
		_loot_progress = 0.0

	if _loot_target != null:
		_prompt_text = "[E] Hold to Search %s" % _loot_target.get_display_name()
		if Input.is_action_pressed("interact"):
			_loot_progress += delta / _loot_target.search_time
			if _loot_progress >= 1.0:
				_finish_loot(_loot_target)
				_loot_target = null
				_loot_progress = 0.0
		else:
			_loot_progress = 0.0
	else:
		_loot_progress = 0.0
		var s := _raycast_structure()
		if s != null:
			var parts := [s.get_status_text()]
			if s.hp < s.max_hp:
				parts.append("[LMB] Repair (1 Wood)")
			if s.kind == "wall" and s.tier < 2:
				parts.append("[RMB] Metal Upgrade (2 Metal)")
			_prompt_text = " | ".join(parts)


func _finish_loot(container: LootContainer) -> void:
	var result := container.open_and_roll(run_seed, current_day)
	var items: Dictionary = result["items"]
	var summary := PackedStringArray()
	for k in items.keys():
		inventory[k] = int(inventory.get(k, 0)) + int(items[k])
		summary.append("+%d %s" % [int(items[k]), String(k).capitalize()])

	var rolled_tier := int(result["weapon_tier"])
	if rolled_tier > weapon_tier:
		weapon_tier = rolled_tier
		_refresh_viewmodel()
		summary.append("NEW WEAPON: %s!" % LootTable.weapon_stats(weapon_tier)["name"])

	Sfx.play(self, "loot", -4.0)
	log_message.emit("Looted %s: %s" % [container.get_display_name(), ", ".join(summary)])


func _refresh_viewmodel() -> void:
	if _weapon_socket != null:
		for child in _weapon_socket.get_children():
			_weapon_socket.remove_child(child)
			child.queue_free()
		var attached: Node3D = null
		if active_slot == 1:
			var dl_w_key := "dl_weapon_pipe" if weapon_tier == 1 else ("dl_weapon_machete" if weapon_tier == 2 else "dl_weapon_axe")
			attached = RefAssets.instantiate_dl_weapon(dl_w_key)
		elif active_slot == 2:
			attached = RefAssets.create_normalized_model("weapon_hammer", 0.36)
		else:
			attached = RefAssets.create_normalized_model("turret", 0.22)
		if attached != null:
			_weapon_socket.add_child(attached)
			return

	if _viewmodel_mesh == null:
		return
	var ref_key := ""
	var target_len := 0.62
	var tint := Color.WHITE
	if active_slot == 1:
		match weapon_tier:
			1:
				ref_key = "weapon_pipe"
			2:
				ref_key = "weapon_machete"
			_:
				ref_key = "weapon_axe"
	elif active_slot == 2:
		ref_key = "weapon_hammer"
		target_len = 0.48
	else:
		ref_key = "turret"
		target_len = 0.34

	if RefAssets.apply_weapon_to_mesh(_viewmodel_mesh, ref_key, target_len, tint):
		return

	var box := BoxMesh.new()
	box.size = Vector3(0.08, 0.08, 0.62)
	_viewmodel_mesh.mesh = box
	_viewmodel_mesh.scale = Vector3.ONE
	_viewmodel_mesh.position = Vector3(0.0, 0.0, -0.22)
	_viewmodel_mesh.rotation = Vector3.ZERO
	var mat := StandardMaterial3D.new()
	if active_slot == 1:
		var stats := LootTable.weapon_stats(weapon_tier)
		mat.albedo_color = stats["color"]
	elif active_slot == 2:
		mat.albedo_color = Color(0.62, 0.45, 0.25)
	else:
		mat.albedo_color = Color(0.32, 0.46, 0.55)
	_viewmodel_mesh.material_override = mat


func use_medkit() -> void:
	if int(inventory.get("medkit", 0)) <= 0 or hp >= max_hp:
		return
	inventory["medkit"] -= 1
	hp = minf(max_hp, hp + 50.0)
	Sfx.play(self, "loot", -6.0, 0.85)
	log_message.emit("Used Medkit (+50 HP).")


func use_food_or_water() -> void:
	if thirst <= hunger and int(inventory.get("water", 0)) > 0 and thirst < 98.0:
		inventory["water"] -= 1
		thirst = minf(100.0, thirst + 45.0)
		Sfx.play(self, "loot", -8.0, 1.15)
		log_message.emit("Drank Water (+45 Thirst).")
	elif int(inventory.get("food", 0)) > 0 and hunger < 98.0:
		inventory["food"] -= 1
		hunger = minf(100.0, hunger + 45.0)
		Sfx.play(self, "loot", -8.0, 0.95)
		log_message.emit("Ate Ration (+45 Hunger).")
	elif int(inventory.get("water", 0)) > 0 and thirst < 98.0:
		inventory["water"] -= 1
		thirst = minf(100.0, thirst + 45.0)
		Sfx.play(self, "loot", -8.0, 1.15)
		log_message.emit("Drank Water (+45 Thirst).")


func take_damage(amount: float, from_pos: Vector3) -> void:
	if is_dead:
		return
	hp = maxf(0.0, hp - amount)
	_hp_regen_delay = 4.0
	_cam_punch = 0.08
	_shake_intensity = maxf(_shake_intensity, 0.14)
	damage_flash = 0.75
	var push := (global_position - from_pos)
	push.y = 0.0
	if push.length() > 0.05:
		var push_dir := push.normalized()
		velocity += push_dir * 4.5
		damage_dir_x = transform.basis.x.dot(-push_dir)
	else:
		damage_dir_x = 0.0
	Sfx.play(self, "hurt", -3.0)
	if hp <= 0.0:
		is_dead = true
		died.emit()


func get_hud_state() -> Dictionary:
	return {
		"hp": hp,
		"max_hp": max_hp,
		"stamina": stamina,
		"exhausted": exhausted,
		"hunger": hunger,
		"thirst": thirst,
		"inventory": inventory,
		"weapon_name": LootTable.weapon_stats(weapon_tier)["name"],
		"active_slot": active_slot,
		"prompt": _prompt_text,
		"loot_progress": _loot_progress,
		"damage_flash": damage_flash,
		"damage_dir_x": damage_dir_x,
		"sense_active": _sense_timer > 0.0,
		"sense_cd": _sense_cd,
		"melee_charge": clampf(_melee_charge_time / 0.35, 0.0, 1.0) if _melee_charging else 0.0,
		"weapon_tier": weapon_tier,
	}
