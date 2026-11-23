class_name Player
extends CharacterBody3D

signal died
signal log_message(text: String)

const BASE_FOV := 72.0
const STAND_HEIGHT := 1.75
const CROUCH_HEIGHT := 1.05
const STAND_EYE_Y := 1.56
const CROUCH_EYE_Y := 0.90

# Survival & dual stamina pools
var hp: float = 100.0
var max_hp: float = 100.0
var fitness: float = 1.0
var sprint_exhausted: bool = false
var stamina: float = 1.0
var exhausted: bool = false
var rope_energy: float = DLReference.ROPE_MAX_ENERGY
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

var telemetry := DLTelemetry.new()
var move_state: String = "IDLE"

var _col: CollisionShape3D
var _cap: CapsuleShape3D
var _head: Node3D
var _camera: Camera3D
var _flashlight: SpotLight3D
var _viewmodel_pivot: Node3D
var _viewmodel_mesh: MeshInstance3D
var _kick_pivot: Node3D
var _build_ghost: MeshInstance3D
var _grapple_beam: MeshInstance3D
var _fpp_rig: Node3D
var _fpp_skel: Skeleton3D
var _fpp_anim: AnimationPlayer
var _weapon_socket: BoneAttachment3D
var _eye_camera_bone_idx: int = -1
var _spine_bone_idx: int = -1
var _chest_bone_idx: int = -1
var _eye_camera_rest: Transform3D = Transform3D.IDENTITY
var _eye_camera_offset_rot: Vector3 = Vector3.ZERO
var _current_fpp_anim: String = ""
var _fpp_action_lock_timer: float = 0.0

var _yaw: float = 0.0
var _pitch: float = 0.0
var _mouse_turn_dx: float = 0.0
var _mouse_turn_dy: float = 0.0
var _lookback_blend: float = 0.0
var _look_slew_phase: float = 1.0
var _elapsed_time: float = 0.0
var _breath_oscillation: float = 1.0

var _jump_cd: float = 0.0
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _attack_cd: float = 0.0
var _kick_cd: float = 0.0
var _fitness_regen_delay: float = 0.0
var _stamina_regen_delay: float = 0.0
var _hp_regen_delay: float = 0.0

var _is_crouching: bool = false
var _slide_timer: float = 0.0
var _slide_total_dur: float = 0.733
var _slide_elapsed: float = 0.0
var _slide_phase: String = "none"
var _slide_start_yaw: float = 0.0
var _slide_kick_active: bool = false
var _slide_kick_hit_timer: float = -1.0
var _slide_cd: float = 0.0
var _slide_dir: Vector3 = Vector3.ZERO

var _vaulting: bool = false
var _vault_start: Vector3 = Vector3.ZERO
var _vault_end: Vector3 = Vector3.ZERO
var _vault_t: float = 0.0
var _vault_dur: float = 0.26
var _vault_peak_boost: float = 0.22
var _vault_kind: String = "vault"
var _vault_preserve_sprint: bool = false
var _vault_exit_speed: float = 6.4
var _last_nm_probe_band: int = 0

var _ledge_hanging: bool = false
var _ledge_pos: Vector3 = Vector3.ZERO
var _ledge_normal: Vector3 = Vector3.ZERO
var _ledge_attach_yaw: float = 0.0
var _ledge_hand_offset: float = DLReference.EDGE_HAND_GRIP_OFFSET
var _ledge_drop_cd: float = 0.0
var _shimmy_dir: int = 0
var _shimmy_step_timer: float = 0.0
var _shimmy_step_start: Vector3 = Vector3.ZERO
var _shimmy_step_target: Vector3 = Vector3.ZERO

var _bob_phase: float = 0.0
var _step_phase: float = 0.0
var _swing_anim: float = 0.0
var _kick_anim: float = 0.0
var _cam_punch: float = 0.0
var _shake_intensity: float = 0.0
var _amortizer_fov_timer: float = 0.0
var damage_flash: float = 0.0
var damage_dir_x: float = 0.0
var _suppress_click_until_msec: int = 0
var allow_headless_mouse_look_for_test: bool = false

# DL1 combat & parkour state (WeaponMeleeController 0x00cfe531 continuous ±60° sweep)
var _melee_hold_pending: bool = false
var _melee_charging: bool = false
var _melee_charge_time: float = 0.0
var _melee_swing_start_time: float = 0.0
var _combo_side: int = 1
var _swing_roll_impulse: float = 0.0
var _swing_roll_timer: float = 0.0
var _pending_melee_timer: float = -1.0
var _pending_melee_heavy: bool = false
var _pending_melee_exhausted: bool = false
var _melee_sweep_active: bool = false
var _melee_sweep_elapsed: float = 0.0
var _melee_sweep_start: float = 0.093
var _melee_sweep_end: float = 0.333
var _melee_sweep_apex_recorded: bool = false
var _melee_hit_targets: Array[Zombie] = []
var _melee_candidate_ids: Dictionary = {}
var _hit_pause_timer: float = 0.0

var _kick_hit_timer: float = -1.0
var _kick_variant: String = "Kick"
var _dropkicking: bool = false
var _dropkick_hit_done: bool = false
var _dropkick_standup_timer: float = 0.0
var _ground_pounding: bool = false
var _stomp_timer: float = 0.0
var _landing_recovery: float = 0.0
var _landing_look_blend_timer: float = 0.0
var _last_landing_tier: int = 0
var _last_landing_shockwave: String = "none"
var _fall_helper_amortizer_detected: bool = false
var _fall_helper_ground_dist: float = 25.0

var _dodge_timer: float = 0.0
var _dodge_cd: float = 0.0
var _last_dodge_time: float = -10.0
var _dodge_dir: Vector3 = Vector3.ZERO
var _dodge_roll: float = 0.0
var _dodge_anim_name: String = "dodge_left"

var _tackle_timer: float = 0.0
var _tackle_cd: float = 0.0
var _tackle_dir: Vector3 = Vector3.ZERO

var _grappling: bool = false
var _grapple_target: Vector3 = Vector3.ZERO
var _grapple_elapsed: float = 0.0

var _grabbed_by: Zombie = null
var _grab_break_progress: float = 0.0
var _grab_damage_tick: float = 0.0
var _grab_elapsed: float = 0.0
var _grab_immunity: float = 0.0

var _sense_timer: float = 0.0
var _sense_cd: float = 0.0

# Wall-run & fall telemetry state
var _wall_running: bool = false
var _wall_run_up: bool = false
var _wall_run_timer: float = 0.0
var _wall_run_cd: float = 0.0
var _wall_run_side: int = 0 # -1=left, 1=right, 0=vertical
var _wall_run_normal: Vector3 = Vector3.ZERO
var _wall_run_start_y: float = 0.0
var _wall_jumps_used: int = 0
var _wall_step_phase: float = 0.0

var _was_airborne: bool = false
var _air_peak_y: float = 0.0
var _air_start_y: float = 0.0
var _air_start_t: float = 0.0
var _crouch_damping_timer: float = 0.0
var _landing_roll_timer: float = 0.0
var _landing_roll_dir: Vector3 = Vector3.ZERO

var _loot_target: LootContainer = null
var _loot_progress: float = 0.0
var _prompt_text: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	floor_max_angle = deg_to_rad(DLReference.MAX_GROUND_WALK_DEG)
	collision_layer = 2
	collision_mask = 1 | 4 | 16
	add_to_group("player")
	_yaw = rotation.y
	_build_rig()
	_refresh_viewmodel()


func _build_rig() -> void:
	_col = CollisionShape3D.new()
	_cap = CapsuleShape3D.new()
	_cap.radius = 0.38
	_cap.height = STAND_HEIGHT
	_col.shape = _cap
	_col.position = Vector3(0.0, STAND_HEIGHT * 0.5, 0.0)
	add_child(_col)

	_head = Node3D.new()
	_head.position = Vector3(0.0, STAND_EYE_Y, 0.0)
	add_child(_head)

	_camera = Camera3D.new()
	_camera.fov = BASE_FOV
	_camera.near = 0.03
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
	var leg_mesh := MeshInstance3D.new()
	var leg_box := BoxMesh.new()
	leg_box.size = Vector3(0.14, 0.14, 0.56)
	leg_mesh.mesh = leg_box
	leg_mesh.position = Vector3(0.0, 0.0, -0.24)
	leg_mesh.material_override = leg_mat
	_kick_pivot.add_child(leg_mesh)

	_fpp_rig = RefAssets.instantiate_dl_player_fpp()
	if _fpp_rig != null:
		add_child(_fpp_rig)
		_hide_head_meshes(_fpp_rig)
		_fpp_anim = RefAssets.find_animation_player(_fpp_rig)
		_fpp_skel = RefAssets.find_skeleton(_fpp_rig)
		RefAssets.set_loop_mode_for_clips(_fpp_anim, [
			"idle", "walk", "sprint", "crouch_idle", "heavy_charge",
			"wall_run_left", "wall_run_right", "wall_run_up",
			"ledge_hang", "shimmy_left", "shimmy_right", "grab_struggle", "grapple",
		])
		if _fpp_skel != null:
			if _fpp_skel.find_bone("WeaponSocket") != -1:
				_weapon_socket = BoneAttachment3D.new()
				_weapon_socket.name = "WeaponSocketAttachment"
				_weapon_socket.bone_name = "WeaponSocket"
				_fpp_skel.add_child(_weapon_socket)
			_setup_eye_camera_bone()
		_viewmodel_pivot.visible = false
		_kick_pivot.visible = false
		_play_fpp_anim("idle", true)

	_grapple_beam = MeshInstance3D.new()
	var gbox := BoxMesh.new()
	gbox.size = Vector3(0.04, 0.04, 1.0)
	_grapple_beam.mesh = gbox
	var gmat := StandardMaterial3D.new()
	gmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gmat.albedo_color = Color(0.75, 0.78, 0.85)
	_grapple_beam.material_override = gmat
	_grapple_beam.visible = false
	get_tree().root.call_deferred("add_child", _grapple_beam)

	_build_ghost = MeshInstance3D.new()
	_build_ghost.visible = false
	var ghost_mat := StandardMaterial3D.new()
	ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_mat.albedo_color = Color(0.2, 0.95, 0.4, 0.45)
	ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_build_ghost.material_override = ghost_mat
	get_tree().root.call_deferred("add_child", _build_ghost)


func _setup_eye_camera_bone() -> void:
	if _fpp_skel == null:
		return
	_eye_camera_bone_idx = _fpp_skel.find_bone("EyeCamera")
	if _eye_camera_bone_idx == -1:
		_eye_camera_bone_idx = _fpp_skel.find_bone("eyecamera")
	if _eye_camera_bone_idx == -1:
		# Ensure EyeCamera bone exists on skeleton (data/vis/playerfppbodyvis.scr _BONE_EYE_CAMERA)
		var new_idx := _fpp_skel.get_bone_count()
		_fpp_skel.add_bone("EyeCamera")
		var parent_idx := _fpp_skel.find_bone("Neck")
		if parent_idx == -1:
			parent_idx = _fpp_skel.find_bone("Chest")
		if parent_idx == -1:
			parent_idx = _fpp_skel.find_bone("Spine")
		if parent_idx != -1:
			_fpp_skel.set_bone_parent(new_idx, parent_idx)
		var rest := Transform3D(Basis.IDENTITY, Vector3(0.0, 0.18, 0.0))
		_fpp_skel.set_bone_rest(new_idx, rest)
		_fpp_skel.set_bone_pose_position(new_idx, rest.origin)
		_fpp_skel.set_bone_pose_rotation(new_idx, Quaternion.IDENTITY)
		_eye_camera_bone_idx = new_idx
	if _eye_camera_bone_idx != -1:
		_eye_camera_rest = _fpp_skel.get_bone_rest(_eye_camera_bone_idx)
		telemetry.record_binary_event("eye_camera_coupled", true)
	_spine_bone_idx = _fpp_skel.find_bone("Spine")
	_chest_bone_idx = _fpp_skel.find_bone("Chest")
	if _chest_bone_idx != -1 and not _fpp_skel.skeleton_updated.is_connected(_on_fpp_skeleton_updated):
		_fpp_skel.skeleton_updated.connect(_on_fpp_skeleton_updated)


func _on_fpp_skeleton_updated() -> void:
	if _fpp_skel == null or _chest_bone_idx == -1:
		return
	# LookParams("Jump"): 0.0 vertical spine distribution while airborne; also skip during parkour/crouch/slide
	if not is_on_floor() or _ledge_hanging or _vaulting or _landing_roll_timer > 0.0 or _slide_timer > 0.0 or _is_crouching:
		return
	var spine_pitch := DLReference.compute_fpp_spine_pitch(_pitch)
	if _spine_bone_idx != -1:
		var s_rot := _fpp_skel.get_bone_pose_rotation(_spine_bone_idx)
		_fpp_skel.set_bone_pose_rotation(_spine_bone_idx, s_rot * Quaternion(Vector3.RIGHT, -spine_pitch * 0.35))
	var c_rot := _fpp_skel.get_bone_pose_rotation(_chest_bone_idx)
	_fpp_skel.set_bone_pose_rotation(_chest_bone_idx, c_rot * Quaternion(Vector3.RIGHT, -spine_pitch * 0.65))


func _exit_tree() -> void:
	if is_instance_valid(_build_ghost):
		_build_ghost.queue_free()
	if is_instance_valid(_grapple_beam):
		_grapple_beam.queue_free()


func suppress_capture_click() -> void:
	_suppress_click_until_msec = Time.get_ticks_msec() + 120


func clamp_ledge_look_yaw(candidate_yaw: float) -> float:
	if not _ledge_hanging:
		return candidate_yaw
	var max_deg := DLReference.EDGE_SHIMMY_YAW_CLAMP_DEG if _shimmy_dir != 0 else DLReference.EDGE_HANG_YAW_CLAMP_DEG
	var max_rad := deg_to_rad(max_deg)
	var diff := angle_difference(_ledge_attach_yaw, candidate_yaw)
	return _ledge_attach_yaw + clampf(diff, -max_rad, max_rad)


func _input(event: InputEvent) -> void:
	if is_dead or get_tree() == null or get_tree().paused:
		return
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	var can_look := (captured and DisplayServer.get_name() != "headless") or allow_headless_mouse_look_for_test
	if event is InputEventMouseMotion and can_look:
		_mouse_turn_dx += event.relative.x
		_mouse_turn_dy += event.relative.y
		_look_slew_phase = 0.0
		var next_yaw: float = _yaw - float(event.relative.x) * 0.0024
		if _ledge_hanging:
			next_yaw = clamp_ledge_look_yaw(next_yaw)
		_yaw = next_yaw
		var min_pitch := deg_to_rad(DLReference.LOOK_PITCH_MIN_DEG)
		var max_pitch := deg_to_rad(DLReference.LOOK_PITCH_MAX_DEG)
		_pitch = clampf(_pitch - float(event.relative.y) * 0.0024, min_pitch, max_pitch)
		rotation.y = _yaw
		_head.rotation.x = _pitch


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_elapsed_time += delta
	_breath_oscillation = DLReference.compute_breath_oscillation(_elapsed_time)

	_jump_cd = maxf(0.0, _jump_cd - delta)
	_coyote_timer = maxf(0.0, _coyote_timer - delta)
	_jump_buffer_timer = maxf(0.0, _jump_buffer_timer - delta)
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_kick_cd = maxf(0.0, _kick_cd - delta)
	_slide_cd = maxf(0.0, _slide_cd - delta)
	_dodge_cd = maxf(0.0, _dodge_cd - delta)
	_tackle_cd = maxf(0.0, _tackle_cd - delta)
	_sense_cd = maxf(0.0, _sense_cd - delta)
	_wall_run_cd = maxf(0.0, _wall_run_cd - delta)
	_ledge_drop_cd = maxf(0.0, _ledge_drop_cd - delta)
	_grab_immunity = maxf(0.0, _grab_immunity - delta)
	_crouch_damping_timer = maxf(0.0, _crouch_damping_timer - delta)
	_fpp_action_lock_timer = maxf(0.0, _fpp_action_lock_timer - delta)
	_landing_recovery = maxf(0.0, _landing_recovery - delta)
	_landing_look_blend_timer = maxf(0.0, _landing_look_blend_timer - delta)
	_amortizer_fov_timer = maxf(0.0, _amortizer_fov_timer - delta)
	_dropkick_standup_timer = maxf(0.0, _dropkick_standup_timer - delta)
	_stomp_timer = maxf(0.0, _stomp_timer - delta)
	_swing_roll_timer = maxf(0.0, _swing_roll_timer - delta)
	_look_slew_phase = minf(1.0, _look_slew_phase + delta * 12.0)

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

	if _slide_kick_hit_timer >= 0.0:
		_slide_kick_hit_timer -= delta
		if _slide_kick_hit_timer <= 0.0:
			_slide_kick_hit_timer = -1.0
			_execute_kick_hit(false, 1.4)

	if _kick_hit_timer >= 0.0:
		_kick_hit_timer -= delta
		if _kick_hit_timer <= 0.0:
			_kick_hit_timer = -1.0
			_execute_kick_hit(false, 1.15 if _kick_variant == "KickLow" else 1.0)

	# WeaponMeleeController (0x00cfe531) continuous ±60° arc sweep across [START_GIVE_DAMAGE..END_GIVE_DAMAGE]
	if _melee_sweep_active and _hit_pause_timer <= 0.0:
		_melee_sweep_elapsed += delta
		if _melee_sweep_elapsed >= _melee_sweep_start:
			_process_melee_sweep(_pending_melee_heavy, _pending_melee_exhausted)
		if _melee_sweep_elapsed >= _melee_sweep_end:
			_finish_melee_sweep(_pending_melee_heavy, _pending_melee_exhausted)

	if _pending_melee_timer >= 0.0 and _hit_pause_timer <= 0.0:
		_pending_melee_timer -= delta
		if _pending_melee_timer <= 0.0:
			_pending_melee_timer = -1.0
			if _melee_hit_targets.is_empty():
				_execute_melee_apex_hit(_pending_melee_heavy, _pending_melee_exhausted)

	_update_survival_needs(delta)

	if _grabbed_by != null:
		_process_grabbed(delta)
	else:
		_handle_hotkeys(delta)
		if _grappling:
			_process_grapple(delta)
		elif _ledge_hanging:
			_process_ledge_hang(delta)
		elif _vaulting:
			_process_vault(delta)
		else:
			_process_movement(delta)

	_update_capsule_shape(delta)
	_update_camera_and_viewmodel(delta)
	_update_interaction(delta)
	_update_build_ghost()
	_update_grapple_beam()
	_record_telemetry_tick()


func _record_telemetry_tick() -> void:
	_compute_move_state()
	var tel_state := _telemetry_state_key()
	telemetry.record_frame(_elapsed_time, tel_state, global_position, velocity, is_on_floor(), fitness, stamina, _camera.fov)


func _compute_move_state() -> void:
	if _grabbed_by != null:
		move_state = "GRABBED"
	elif _grappling:
		move_state = "GRAPPLE"
	elif _ground_pounding:
		move_state = "GROUND_POUND"
	elif _dropkicking:
		move_state = "DROPKICK"
	elif _stomp_timer > 0.0:
		move_state = "STOMP"
	elif _vaulting:
		match _vault_kind:
			"climb_ledge":
				move_state = "LEDGE_CLIMB" if _ledge_hanging or _vault_t > 0.0 else "HIGH_MANTLE"
			"zombie_vault":
				move_state = "ZOMBIE_VAULT"
			_:
				move_state = "LOW_VAULT"
	elif _ledge_hanging:
		move_state = "LEDGE_SHIMMY" if _shimmy_dir != 0 else "LEDGE_HANG"
	elif _wall_running:
		move_state = "WALL_RUN_UP" if _wall_run_up else "WALL_RUN_SIDE"
	elif _landing_roll_timer > 0.0:
		move_state = "LANDING_ROLL"
	elif _tackle_timer > 0.0:
		move_state = "TACKLE"
	elif _dodge_timer > 0.0:
		move_state = "DODGE"
	elif _slide_timer > 0.0:
		move_state = "SLIDE"
	elif not is_on_floor():
		move_state = "AIRBORNE"
	elif _is_crouching:
		move_state = "CROUCH"
	else:
		var input_vec := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		var hs := Vector2(velocity.x, velocity.z).length()
		if hs < 0.35:
			move_state = "IDLE"
		elif Input.is_action_pressed("sprint") and input_vec.y < -0.1 and DLReference.can_sprint_with_fitness(fitness, sprint_exhausted):
			move_state = "SPRINT"
		else:
			move_state = "WALK"


func _telemetry_state_key() -> String:
	match move_state:
		"WALK":
			var input_vec := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
			if input_vec.y > 0.1 or absf(input_vec.x) > 0.1:
				return "strafe"
			return "walk"
		"SPRINT":
			return "sprint"
		"CROUCH":
			return "crouch"
		"SLIDE":
			return "slide"
		"DODGE":
			return "dodge"
		_:
			return move_state.to_lower()


func get_slide_phase() -> String:
	return _slide_phase


func get_floor_slope_slide_factor() -> float:
	if not is_on_floor():
		return DLReference.SLIDE_COOLDOWN * 0.0 + DLReference.SLOPE_SLIDE_MIN
	var n := get_floor_normal()
	var slope_deg := rad_to_deg(acos(clampf(n.y, -1.0, 1.0)))
	return DLReference.compute_slope_slide_factor(slope_deg)


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
	if Input.is_action_just_pressed("survivor_sense"):
		trigger_survivor_sense()
	if Input.is_action_just_pressed("grapple"):
		_try_grapple()

	if Input.is_action_just_pressed("kick"):
		if not _try_head_stomp():
			perform_kick()

	if Input.is_action_just_pressed("interact") and _loot_target == null:
		if not _try_head_stomp() and Input.is_action_pressed("sprint"):
			_try_tackle()

	if Input.is_action_just_pressed("primary_action"):
		if Time.get_ticks_msec() <= _suppress_click_until_msec:
			_suppress_click_until_msec = 0
		elif _slide_timer > 0.0:
			_trigger_slide_kick()
		elif not is_on_floor() and not _wall_running and not _ledge_hanging and ((_pitch < -0.35 and _height_above_ground() >= 1.1) or Input.is_action_pressed("crouch")):
			_try_ground_pound()
		elif active_slot == 1:
			_melee_hold_pending = true
			_melee_charging = false
			_melee_charge_time = 0.0
		else:
			_perform_primary()

	if _melee_hold_pending or _melee_charging:
		if active_slot != 1:
			_melee_hold_pending = false
			_melee_charging = false
		elif Input.is_action_pressed("primary_action"):
			_melee_charge_time += delta
			if _melee_hold_pending and _melee_charge_time >= 0.14:
				_melee_hold_pending = false
				_melee_charging = true
		else:
			_melee_hold_pending = false
			_melee_charging = false
			_melee_swing(_melee_charge_time >= DLReference.CHARGE_HOLD_DURATION)

	if Input.is_action_just_pressed("secondary_action"):
		if active_slot == 1 and Input.is_action_pressed("sprint"):
			_try_tackle()
		else:
			_perform_secondary()


func _process_vault(delta: float) -> void:
	_vault_t += delta / maxf(0.05, _vault_dur)
	if _vault_t >= 1.0:
		global_position = _vault_end
		_vaulting = false
		_was_airborne = false
		_air_peak_y = global_position.y
		if _vault_kind == "vault":
			telemetry.record_metric("vault_duration", _vault_dur)
		if _vault_preserve_sprint:
			var fwd := -transform.basis.z
			fwd.y = 0.0
			velocity = fwd.normalized() * _vault_exit_speed
		else:
			var fwd := -transform.basis.z
			fwd.y = 0.0
			var exit_spd := (DLReference.SPRINT_SPEED * 0.85 if Input.is_action_pressed("sprint") else DLReference.WALK_SPEED) if Input.is_action_pressed("move_forward") else 0.0
			velocity = fwd.normalized() * exit_spd
			_cam_punch = -0.05
	else:
		var ease_t := 1.0 - pow(1.0 - _vault_t, 2.0)
		var pos := _vault_start.lerp(_vault_end, ease_t)
		pos.y += sin(_vault_t * PI) * _vault_peak_boost
		global_position = pos
		velocity = Vector3.ZERO


func _process_movement(delta: float) -> void:
	var input_vec := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish_dir := (transform.basis * Vector3(input_vec.x, 0.0, input_vec.y)).normalized()

	var wants_crouch := Input.is_action_pressed("crouch")
	if Input.is_action_just_pressed("crouch") or wants_crouch:
		_crouch_damping_timer = DLReference.CROUCH_DAMPING_WINDOW
	# MoveController (0x00d4979c) sprint gate: not sprint_exhausted and fitness > 0.06f
	var wants_sprint := Input.is_action_pressed("sprint") and input_vec.y < -0.1 and not wants_crouch and DLReference.can_sprint_with_fitness(fitness, sprint_exhausted)

	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = DLReference.JUMP_BUFFER_TIME

	# Player Dodge inside MoveController (0x00d52188 / 0x00d50760): 0.15s min interval, 0.75s cd, 6.0f impulse / 9.0 m/s DodgeSpeed
	var dodge_in := Vector2.ZERO
	if Input.is_action_just_pressed("dodge") and (absf(input_vec.x) > 0.1 or input_vec.y > 0.1):
		dodge_in = Vector2(input_vec.x, maxf(0.0, input_vec.y))
	elif Input.is_action_pressed("dodge"):
		if Input.is_action_just_pressed("move_left"):
			dodge_in = Vector2(-1.0, 0.0)
		elif Input.is_action_just_pressed("move_right"):
			dodge_in = Vector2(1.0, 0.0)
		elif Input.is_action_just_pressed("move_back"):
			dodge_in = Vector2(0.0, 1.0)
	elif Input.is_action_just_pressed("jump") and input_vec.y >= -0.05 and (absf(input_vec.x) > 0.1 or input_vec.y > 0.1) and is_on_floor():
		dodge_in = Vector2(input_vec.x, maxf(0.0, input_vec.y))
		_jump_buffer_timer = 0.0

	var since_last_dodge := _elapsed_time - _last_dodge_time
	if dodge_in != Vector2.ZERO and is_on_floor() and _dodge_cd <= 0.0 and since_last_dodge >= DLReference.DODGE_MIN_INTERVAL and _dodge_timer <= 0.0 and not exhausted and stamina >= 0.10:
		_spend_combat_stamina(0.20)
		_last_dodge_time = _elapsed_time
		_dodge_timer = 0.24
		_dodge_cd = DLReference.DODGE_COOLDOWN
		_dodge_dir = (transform.basis * Vector3(dodge_in.x, 0.0, dodge_in.y)).normalized()
		_dodge_roll = -dodge_in.x * 0.11
		_dodge_anim_name = "dodge_right" if dodge_in.x > 0.1 else "dodge_left"
		Sfx.play(self, "climb", -9.0, 1.25)

	# 4-Phase Crouch-Slide (0x00cfbf50: SlideBegin 0.333s -> SlideLoop / SlideLoopRight [yaw > 5°] -> SlideKick -> SlideEnd)
	var hs_now := Vector2(velocity.x, velocity.z).length()
	if Input.is_action_just_pressed("crouch") and is_on_floor() and (hs_now > 4.2 or (wants_sprint and hs_now > 3.5)) and _slide_timer <= 0.0 and _slide_cd <= 0.0 and _landing_roll_timer <= 0.0:
		_slide_total_dur = DLReference.SLIDE_BEGIN_DUR + DLReference.SLIDE_LOOP_DUR
		_slide_timer = _slide_total_dur
		_slide_elapsed = 0.0
		_slide_kick_active = false
		_slide_start_yaw = _yaw
		_slide_phase = "SlideBegin"
		telemetry.record_binary_event("last_slide_phase", _slide_phase)
		_slide_cd = DLReference.SLIDE_COOLDOWN
		_slide_dir = Vector3(velocity.x, 0.0, velocity.z).normalized()
		Sfx.play(self, "climb", -10.0, 0.85)

	_is_crouching = _slide_timer > 0.0 or _landing_roll_timer > 0.0 or wants_crouch or (is_on_floor() and _is_crouching and not _has_stand_clearance())

	if _tackle_timer > 0.0:
		_tackle_timer = maxf(0.0, _tackle_timer - delta)
		var tackle_spd := maxf(9.5, DLReference.SPRINT_SPEED + DLReference.TACKLE_ADD_SPEED * 0.7)
		velocity.x = _tackle_dir.x * tackle_spd
		velocity.z = _tackle_dir.z * tackle_spd
		_check_tackle_hits()
	elif _landing_roll_timer > 0.0:
		_landing_roll_timer = maxf(0.0, _landing_roll_timer - delta)
		velocity.x = _landing_roll_dir.x * 7.8
		velocity.z = _landing_roll_dir.z * 7.8
	elif _dodge_timer > 0.0:
		_dodge_timer = maxf(0.0, _dodge_timer - delta)
		velocity.x = _dodge_dir.x * DLReference.DODGE_SPEED
		velocity.z = _dodge_dir.z * DLReference.DODGE_SPEED
	elif _slide_timer > 0.0:
		_slide_timer = maxf(0.0, _slide_timer - delta)
		_slide_elapsed += delta
		var yaw_delta_deg := rad_to_deg(absf(angle_difference(_yaw, _slide_start_yaw)))
		if _slide_kick_active:
			_slide_phase = "SlideKick"
		elif _slide_elapsed < DLReference.SLIDE_BEGIN_DUR:
			_slide_phase = "SlideBegin"
		elif _slide_timer <= 0.14:
			_slide_phase = "SlideEnd"
		elif yaw_delta_deg > DLReference.SLIDE_LOOP_RIGHT_YAW_DEG:
			_slide_phase = "SlideLoopRight"
		else:
			_slide_phase = "SlideLoop"
		telemetry.record_binary_event("last_slide_phase", _slide_phase)
		var slide_t := clampf(_slide_elapsed / maxf(0.1, _slide_total_dur), 0.0, 1.0)
		var spd := lerpf(8.6, 3.0, slide_t)
		velocity.x = _slide_dir.x * spd
		velocity.z = _slide_dir.z * spd
		_check_slide_knockback()
		if _slide_timer <= 0.0:
			_slide_phase = "SlideEnd"
			telemetry.record_binary_event("last_slide_phase", _slide_phase)
	elif _wall_running:
		_process_wall_run(delta, input_vec)
	elif _ground_pounding:
		velocity.x *= 0.92
		velocity.z *= 0.92
		velocity.y = -16.0
	else:
		# MoveController (0x00d4979c) directional speed & PlayerFitnessModule (0x00ce1521) speed scaling
		var target_speed := DLReference.WALK_SPEED
		if _is_crouching:
			target_speed = DLReference.CROUCH_SPEED
		elif wants_sprint:
			target_speed = DLReference.SPRINT_SPEED
			_spend_fitness(DLReference.FITNESS_SPRINT_COST * delta)
		elif absf(input_vec.x) >= absf(input_vec.y) and absf(input_vec.x) > 0.1:
			target_speed = DLReference.BACK_STRAFE_SPEED
		elif input_vec.y > 0.1 or absf(input_vec.x) > 0.1:
			target_speed = DLReference.BACK_STRAFE_SPEED

		if sprint_exhausted:
			target_speed *= DLReference.EXHAUSTED_SPEED_FACTOR
		elif fitness < 0.50:
			target_speed *= DLReference.compute_fitness_speed_factor(fitness, 1.0)
		if hunger <= 0.0 or thirst <= 0.0:
			target_speed *= 0.8
		if _landing_recovery > 0.0:
			target_speed *= 0.45

		var accel := DLReference.MOVE_ACCEL
		if not is_on_floor():
			accel = (DLReference.MOVE_ACCEL * DLReference.AIR_CONTROL) if wish_dir.length() > 0.05 else 1.2
		elif _is_crouching:
			accel = DLReference.CROUCH_ACCEL if wish_dir.length() > 0.05 else DLReference.CROUCH_DECEL
		elif wants_sprint:
			accel = DLReference.SPRINT_ACCEL if wish_dir.length() > 0.05 else DLReference.MOVE_DECEL
		elif wish_dir.length() <= 0.05:
			accel = DLReference.MOVE_DECEL

		if not _dropkicking:
			var cur_h := Vector2(velocity.x, velocity.z)
			var dst_h := Vector2(wish_dir.x, wish_dir.z) * target_speed
			var nxt_h := cur_h.move_toward(dst_h, accel * delta)
			velocity.x = nxt_h.x
			velocity.z = nxt_h.y

		# Slope SlideDown (0x00d50c90): if standing on steep slope (> MAX_GROUND_JUMP_DEG), add downward slope drift
		if is_on_floor():
			var fn := get_floor_normal()
			var slope_deg := rad_to_deg(acos(clampf(fn.y, -1.0, 1.0)))
			if slope_deg > DLReference.MAX_GROUND_JUMP_DEG:
				var slide_fac := DLReference.compute_slope_slide_factor(slope_deg)
				var down_slope := Vector3(fn.x, 0.0, fn.z).normalized()
				velocity.x += down_slope.x * slide_fac * 4.0 * delta
				velocity.z += down_slope.z * slide_fac * 4.0 * delta

		if is_on_floor() and wish_dir.length() > 0.1 and not _is_crouching:
			_try_stair_step_up(wish_dir)

	if _wall_running:
		if Input.is_action_just_pressed("jump") and _jump_cd <= 0.0:
			_perform_wall_jump()
	elif not is_on_floor() and not _ground_pounding:
		velocity.y -= DLReference.GRAVITY * delta
		_update_fall_helper_lookahead()
		if not _try_catch_ledge(input_vec):
			_try_start_wall_run(input_vec)
	elif (_jump_buffer_timer > 0.0 and (_coyote_timer > 0.0 or is_on_floor())) and _jump_cd <= 0.0:
		_jump_buffer_timer = 0.0
		var can_zombie_vault := wants_sprint or Vector2(velocity.x, velocity.z).length() > 4.2
		if not (can_zombie_vault and _try_vault_over_zombie()) and not _try_vault():
			velocity.y = DLReference.JUMP_VELOCITY
			_jump_cd = DLReference.MIN_JUMP_INTERVAL
			_coyote_timer = 0.0
			_spend_fitness(DLReference.JUMP_STAMINA_COST)

	if not is_on_floor() and not _wall_running and not _ledge_hanging and Input.is_action_pressed("jump") and input_vec.y < -0.1:
		if not _try_catch_ledge(input_vec):
			_try_vault()

	if _dropkicking and not _dropkick_hit_done:
		if _execute_kick_hit(true, 1.0):
			_dropkick_hit_done = true
			_dropkick_standup_timer = DLReference.DROPKICK_STANDUP_FAST_DUR
			velocity.x *= -0.25
			velocity.z *= -0.25
			velocity.y = maxf(velocity.y, 1.5)

	move_and_slide()

	if is_on_floor():
		if _dropkicking and _dropkick_standup_timer <= 0.0:
			_dropkick_standup_timer = 0.35
		_dropkicking = false
		_dropkick_hit_done = false
		_wall_running = false
		_wall_run_up = false
		_wall_jumps_used = 0
		_coyote_timer = DLReference.COYOTE_TIME
		if _ground_pounding:
			_ground_pounding = false
			_trigger_ground_pound_shockwave()
		if _was_airborne:
			_was_airborne = false
			var fall_dist := _air_peak_y - global_position.y
			var jump_gain := _air_peak_y - _air_start_y
			if jump_gain > 0.35 and fall_dist <= 2.5:
				telemetry.record_metric("jump_apex", jump_gain)
				telemetry.record_metric("jump_hang_time", _elapsed_time - _air_start_t)
			_resolve_landing(fall_dist)
		_air_peak_y = global_position.y
	else:
		if not _was_airborne:
			_was_airborne = true
			_air_start_y = global_position.y
			_air_start_t = _elapsed_time
			_air_peak_y = global_position.y
		else:
			_air_peak_y = maxf(_air_peak_y, global_position.y)
		if _wall_running:
			_air_peak_y = global_position.y


func _try_stair_step_up(wish_dir: Vector3) -> void:
	var flat_dir := Vector3(wish_dir.x, 0.0, wish_dir.z)
	if flat_dir.length() < 0.05:
		return
	flat_dir = flat_dir.normalized()
	if not test_move(global_transform, flat_dir * 0.16):
		return
	var space := get_world_3d().direct_space_state
	var probe_top := global_position + Vector3(0.0, DLReference.STAIR_HEIGHT + 0.06, 0.0) + flat_dir * 0.45
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(probe_top, probe_top + Vector3(0.0, -(DLReference.STAIR_HEIGHT + 0.04), 0.0), 1 | 16, [get_rid()]))
	if hit.is_empty():
		return
	var step_h := float(hit["position"].y) - global_position.y
	if step_h > 0.04 and step_h <= DLReference.STAIR_HEIGHT + 0.02 and Vector3(hit["normal"]).y > 0.7:
		var up_xform := global_transform
		up_xform.origin.y += step_h + 0.02
		if not test_move(up_xform, flat_dir * 0.16):
			global_position.y += step_h + 0.02


func _has_stand_clearance() -> bool:
	# PlayerDuckModule (0x00cde22e / 0x00cde585): 0.30m radius x 1.50m (2*0.75m) duck_capsule_up sweep + ray checks
	var space := get_world_3d().direct_space_state
	var duck_cap := CapsuleShape3D.new()
	duck_cap.radius = DLReference.DUCK_CAPSULE_RADIUS
	duck_cap.height = DLReference.DUCK_CAPSULE_HEIGHT
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = duck_cap
	q.transform = Transform3D(Basis.IDENTITY, global_position + Vector3(0.0, STAND_HEIGHT - DLReference.DUCK_CAPSULE_HALF_HEIGHT, 0.0))
	q.collision_mask = 1 | 16
	q.exclude = [get_rid()]
	if not space.intersect_shape(q, 1).is_empty():
		return false
	for ox: Vector3 in [Vector3.ZERO, Vector3(0.24, 0.0, 0.0), Vector3(-0.24, 0.0, 0.0), Vector3(0.0, 0.0, 0.24), Vector3(0.0, 0.0, -0.24)]:
		var from: Vector3 = global_position + ox + Vector3(0.0, 0.90, 0.0)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, global_position + ox + Vector3(0.0, STAND_HEIGHT + 0.02, 0.0), 1 | 16, [get_rid()]))
		if not hit.is_empty():
			return false
	return true


func _update_capsule_shape(delta: float) -> void:
	var target_h := CROUCH_HEIGHT if _is_crouching else STAND_HEIGHT
	_cap.height = lerpf(_cap.height, target_h, clampf(delta * 14.0, 0.0, 1.0))
	_col.position.y = _cap.height * 0.5


func _try_start_wall_run(input_vec: Vector2) -> bool:
	if _wall_running or _wall_run_cd > 0.0 or _wall_jumps_used >= DLReference.MAX_WALL_JUMPS or _dropkicking or _vaulting or _ledge_hanging or _grappling:
		return false
	var horiz := Vector2(velocity.x, velocity.z).length()
	if input_vec.y >= -0.1 and horiz < 3.0:
		return false
	var space := get_world_3d().direct_space_state
	var origin := global_position + Vector3(0.0, 1.0, 0.0)
	var forward := -transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()

	# Vertical Front Wall-Run (holding W + Space straight at a wall)
	if Input.is_action_pressed("jump") and input_vec.y < -0.1:
		var front_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(origin, origin + forward * 0.95, 1 | 16, [get_rid()]))
		if not front_hit.is_empty():
			var fn := Vector3(front_hit["normal"])
			if absf(fn.y) < 0.35 and (-forward).dot(Vector3(fn.x, 0.0, fn.z).normalized()) > 0.72:
				_wall_running = true
				_wall_run_up = true
				_wall_run_side = 0
				_wall_run_timer = 0.72
				_wall_run_normal = Vector3(fn.x, 0.0, fn.z).normalized()
				_wall_run_start_y = global_position.y
				_wall_step_phase = 0.0
				velocity = Vector3(0.0, 4.8, 0.0)
				Sfx.play(self, "footstep", -11.0, 1.15)
				return true

	# Lateral Tic-Tac Wall-Run
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
				_wall_run_up = false
				_wall_run_timer = 1.1
				_wall_run_side = side
				_wall_run_normal = Vector3(n.x, 0.0, n.z).normalized()
				_wall_run_start_y = global_position.y
				_wall_step_phase = 0.0
				velocity.y = maxf(velocity.y, 1.8)
				Sfx.play(self, "footstep", -12.0, 1.1)
				return true
	return false


func _process_wall_run(delta: float, _input_vec: Vector2) -> void:
	_wall_run_timer -= delta
	var space := get_world_3d().direct_space_state
	var origin := global_position + Vector3(0.0, 1.0, 0.0)

	if _wall_run_up:
		velocity.x = -_wall_run_normal.x * 1.2
		velocity.z = -_wall_run_normal.z * 1.2
		velocity.y = maxf(velocity.y - DLReference.WALL_RUN_EXTRA_GRAVITY * 0.55 * delta, 2.2)
		var prev_step := _wall_step_phase
		_wall_step_phase += delta * 5.2
		if int(floor(_wall_step_phase)) > int(floor(prev_step)):
			Sfx.play(self, "footstep", -11.0, randf_range(1.0, 1.2))
		if _try_catch_ledge(Vector2(0.0, -1.0)):
			_wall_running = false
			_wall_run_up = false
			telemetry.record_metric("wall_run_gain_y", global_position.y - _wall_run_start_y, true)
			return
		var front_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(origin, origin - _wall_run_normal * 1.0, 1 | 16, [get_rid()]))
		var gained := global_position.y - _wall_run_start_y
		if front_hit.is_empty() or _wall_run_timer <= 0.0 or gained >= DLReference.WALL_RUN_FRONT_HEIGHT or not Input.is_action_pressed("move_forward"):
			telemetry.record_metric("wall_run_gain_y", gained, true)
			_wall_running = false
			_wall_run_up = false
			_wall_run_cd = 0.25
		return

	velocity.y -= DLReference.WALL_RUN_EXTRA_GRAVITY * delta
	var forward := -transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var tangent := forward.slide(_wall_run_normal)
	if tangent.length() < 0.1:
		_wall_running = false
		return
	tangent = tangent.normalized()
	var run_speed := maxf(DLReference.SPRINT_SPEED, Vector2(velocity.x, velocity.z).length())
	velocity.x = tangent.x * run_speed
	velocity.z = tangent.z * run_speed

	var prev_step := _wall_step_phase
	_wall_step_phase += delta * 4.5
	if int(floor(_wall_step_phase)) > int(floor(prev_step)):
		Sfx.play(self, "footstep", -12.0, randf_range(0.95, 1.15))

	var check_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(origin, origin - _wall_run_normal * 0.95, 1 | 16, [get_rid()]))
	if check_hit.is_empty() or _wall_run_timer <= 0.0:
		_wall_running = false
		_wall_run_cd = 0.2


func _perform_wall_jump() -> void:
	var was_up := _wall_run_up
	var forward := -transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	_wall_running = false
	_wall_run_up = false
	_wall_jumps_used += 1
	_wall_run_cd = 0.22
	_jump_cd = 0.22
	if was_up:
		var away := _wall_run_normal * DLReference.WALL_JUMP_BACK_SPEED
		if forward.dot(_wall_run_normal) > 0.2:
			away = forward * (DLReference.WALL_JUMP_BACK_SPEED + 1.5)
		velocity = away + Vector3.UP * (DLReference.JUMP_VELOCITY + DLReference.WALL_JUMP_BACK_HEIGHT)
	else:
		var tangent := forward.slide(_wall_run_normal).normalized()
		velocity = _wall_run_normal * 5.2 + tangent * 4.5 + Vector3.UP * (DLReference.JUMP_VELOCITY + DLReference.WALL_JUMP_BACK_HEIGHT)
	Sfx.play(self, "climb", -5.0, 1.15)


func _try_catch_ledge(input_vec: Vector2) -> bool:
	if _ledge_hanging or _ledge_drop_cd > 0.0 or _vaulting or _dropkicking or _grappling:
		return false
	if not (Input.is_action_pressed("jump") or input_vec.y < -0.1 or velocity.y < 0.0):
		return false
	var forward := -transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var space := get_world_3d().direct_space_state
	var chest := global_position + Vector3(0.0, 1.45, 0.0)
	var wall_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(chest, chest + forward * 0.95, 1 | 16, [get_rid()]))
	if wall_hit.is_empty():
		return false
	var wn := Vector3(wall_hit["normal"])
	if absf(wn.y) > 0.35:
		return false
	var top_probe := global_position + Vector3(0.0, 2.35, 0.0) + forward * 0.85
	var down_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(top_probe, top_probe + Vector3(0.0, -1.35, 0.0), 1 | 16, [get_rid()]))
	if down_hit.is_empty():
		return false
	var ledge_y := float(down_hit["position"].y)
	var diff := ledge_y - global_position.y
	if diff < 1.35 or diff > 3.30:
		return false

	# EdgeGrabController (0x00d084f6): 0.2158m hand-to-ledge grip offset (standing eye 1.56 + 0.06 = 1.62 below ledge)
	_ledge_hanging = true
	_wall_running = false
	_wall_run_up = false
	_shimmy_dir = 0
	_shimmy_step_timer = 0.0
	_ledge_hand_offset = DLReference.EDGE_HAND_GRIP_OFFSET
	_ledge_normal = Vector3(wn.x, 0.0, wn.z).normalized()
	_ledge_attach_yaw = atan2(_ledge_normal.x, _ledge_normal.z)
	_ledge_pos = Vector3(wall_hit["position"].x, ledge_y - (1.4042 + _ledge_hand_offset), wall_hit["position"].z) + _ledge_normal * 0.42
	global_position = _ledge_pos
	velocity = Vector3.ZERO
	_was_airborne = false
	_air_peak_y = global_position.y
	Sfx.play(self, "climb", -6.0, 0.9)
	return true


func _process_ledge_hang(delta: float) -> void:
	velocity = Vector3.ZERO
	global_position = _ledge_pos
	var input_vec := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var forward := -transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var facing_wall := forward.dot(-_ledge_normal)

	if Input.is_action_just_pressed("crouch") or Input.is_action_just_pressed("move_back"):
		_ledge_hanging = false
		_ledge_drop_cd = 0.35
		return

	if (Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("move_forward")) and facing_wall > 0.0:
		_ledge_hanging = false
		_vaulting = true
		_vault_t = 0.0
		_vault_dur = 0.42
		_vault_kind = "climb_ledge"
		_vault_preserve_sprint = false
		_vault_peak_boost = 0.16
		_vault_start = global_position
		_vault_end = Vector3(_ledge_pos.x, _ledge_pos.y + 1.67, _ledge_pos.z) - _ledge_normal * 0.85
		Sfx.play(self, "climb", -5.0, 1.05)
		return

	# EdgeGrabController (0x00d104f0): 4.5 m/s horizontal ballistic edge-leap solver (1.3m peak clamp)
	if Input.is_action_just_pressed("jump") and facing_wall < -0.174:
		_ledge_hanging = false
		_ledge_drop_cd = 0.35
		var leap_target := _ledge_pos + _ledge_normal * DLReference.EDGE_LEAP_HORIZ_SPEED + Vector3.UP * DLReference.EDGE_LEAP_PEAK_CLAMP
		velocity = DLReference.compute_edge_leap_velocity(_ledge_pos, leap_target)
		Sfx.play(self, "climb", -5.0, 1.15)
		return

	# EdgeGrabController (0x00d0e5b6): 0.40m lateral shimmy step probe with -0.03m vertical slice
	if _shimmy_step_timer > 0.0:
		_shimmy_step_timer = maxf(0.0, _shimmy_step_timer - delta)
		var step_t := 1.0 - (_shimmy_step_timer / (DLReference.EDGE_SHIMMY_DURATION * 0.35))
		_ledge_pos = _shimmy_step_start.lerp(_shimmy_step_target, clampf(step_t, 0.0, 1.0))
		global_position = _ledge_pos
		if _shimmy_step_timer <= 0.0:
			_shimmy_dir = 0
		return

	_shimmy_dir = 0
	if absf(input_vec.x) > 0.2:
		var tangent_r := Vector3(_ledge_normal.z, 0.0, -_ledge_normal.x).normalized()
		var side_sign := 1 if input_vec.x > 0.0 else -1
		var step_cand := _ledge_pos + tangent_r * float(side_sign) * DLReference.EDGE_SHIMMY_STEP
		var slice_y := DLReference.EDGE_SHIMMY_VERT_SLICE
		var space := get_world_3d().direct_space_state
		var wall_chk := space.intersect_ray(PhysicsRayQueryParameters3D.create(step_cand + Vector3(0.0, 1.2 + slice_y, 0.0), step_cand + Vector3(0.0, 1.2 + slice_y, 0.0) - _ledge_normal * 0.85, 1 | 16, [get_rid()]))
		var top_chk := space.intersect_ray(PhysicsRayQueryParameters3D.create(step_cand + Vector3(0.0, 2.0 + slice_y, 0.0) - _ledge_normal * 0.75, step_cand + Vector3(0.0, 1.2 + slice_y, 0.0) - _ledge_normal * 0.75, 1 | 16, [get_rid()]))
		if not wall_chk.is_empty() and not top_chk.is_empty():
			_shimmy_dir = side_sign
			_shimmy_step_start = _ledge_pos
			_shimmy_step_target = step_cand
			_shimmy_step_timer = DLReference.EDGE_SHIMMY_DURATION * 0.35
			Sfx.play(self, "climb", -12.0, 1.12)


func _probe_nm_three_bands(forward: Vector3, probe_reach: float = 1.35) -> Dictionary:
	# NaturalMovementController (0x00d5733c): 3 vertical mantle probe bands at 0.85m, 1.35m, 1.65m
	var space := get_world_3d().direct_space_state
	var bands := [DLReference.NM_PROBE_BAND_LOW, DLReference.NM_PROBE_BAND_MID, DLReference.NM_PROBE_BAND_HIGH]
	var highest_hit_band := 0
	var first_hit: Dictionary = {}
	for idx in bands.size():
		var h := float(bands[idx])
		var from := global_position + Vector3(0.0, h, 0.0)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + forward * probe_reach, 1 | 16, [get_rid()]))
		if not hit.is_empty():
			highest_hit_band = idx + 1
			if first_hit.is_empty():
				first_hit = hit
	_last_nm_probe_band = highest_hit_band
	telemetry.record_binary_event("last_nm_probe_band", highest_hit_band)
	return {"highest_band": highest_hit_band, "hit": first_hit}


func _try_vault() -> bool:
	var forward := -transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var space := get_world_3d().direct_space_state
	var reach := clampf(1.15 + maxf(0.0, Vector2(velocity.x, velocity.z).length() - 3.5) * 0.25, 1.15, 1.85) if is_on_floor() else 0.90

	var nm_probe := _probe_nm_three_bands(forward, reach)
	if int(nm_probe["highest_band"]) == 0:
		return false

	var hit_dist := global_position.distance_to(Vector3(nm_probe["hit"]["position"].x, global_position.y, nm_probe["hit"]["position"].z))
	var forward_step := clampf(hit_dist + 0.45, 0.85, reach + 0.25)

	var head_from := global_position + Vector3(0.0, 2.45, 0.0)
	var head_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(head_from, head_from + forward * reach, 1 | 16, [get_rid()]))
	if not head_hit.is_empty():
		return false

	var top_probe := global_position + Vector3(0.0, 2.55, 0.0) + forward * forward_step
	var down_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(top_probe, top_probe + Vector3(0.0, -2.2, 0.0), 1 | 16, [get_rid()]))
	if down_hit.is_empty():
		return false

	var ledge_y: float = down_hit["position"].y
	var height_diff := ledge_y - global_position.y
	if height_diff < 0.45 or height_diff > 2.35:
		return false

	_vaulting = true
	_vault_t = 0.0
	_vault_start = global_position
	_swing_roll_impulse = deg_to_rad(5.5)
	_swing_roll_timer = 0.22
	_cam_punch = -0.065
	if height_diff <= 1.25:
		_vault_kind = "vault"
		_vault_dur = 0.26
		_vault_preserve_sprint = true
		_vault_exit_speed = DLReference.SPRINT_SPEED
		_vault_peak_boost = 0.28
		# Check obstacle depth: <= 1.0m vaults OVER, else vaults ON TOP
		var far_probe := Vector3(down_hit["position"].x, ledge_y + 0.3, down_hit["position"].z) + forward * 1.05
		var far_down := space.intersect_ray(PhysicsRayQueryParameters3D.create(far_probe, far_probe + Vector3(0.0, -1.6, 0.0), 1 | 16, [get_rid()]))
		if not far_down.is_empty() and float(far_down["position"].y) < ledge_y - 0.35:
			_vault_end = Vector3(far_down["position"].x, float(far_down["position"].y) + 0.05, far_down["position"].z) + forward * 0.35
		else:
			_vault_end = Vector3(down_hit["position"].x, ledge_y + 0.05, down_hit["position"].z) + forward * 0.45
	else:
		_vault_kind = "climb_ledge"
		_vault_dur = 0.46
		_vault_preserve_sprint = false
		_vault_peak_boost = 0.18
		_cam_punch = -0.055
		_vault_end = Vector3(down_hit["position"].x, ledge_y + 0.05, down_hit["position"].z) + forward * 0.25
	Sfx.play(self, "climb", -6.0, randf_range(0.95, 1.1))
	return true


func _try_vault_over_zombie() -> bool:
	var forward := -transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var best_z: Zombie = null
	var best_d := 2.25
	for node in get_tree().get_nodes_in_group("enemies"):
		if not (node is Zombie) or not is_instance_valid(node):
			continue
		var z := node as Zombie
		if z.is_downed():
			continue
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

	best_z.apply_stun(DLReference.JUMP_OVER_STUN_DUR)
	_vaulting = true
	_vault_t = 0.0
	_vault_dur = 0.30
	_vault_kind = "zombie_vault"
	_vault_preserve_sprint = true
	_vault_exit_speed = 6.2
	_vault_peak_boost = 1.45
	_vault_start = global_position
	_vault_end = best_z.global_position + forward * 1.65
	_jump_cd = DLReference.MIN_JUMP_INTERVAL
	Sfx.play(self, "climb", -5.0, 1.15)
	log_message.emit("Vaulted over infected!")
	return true


func _update_fall_helper_lookahead() -> void:
	# PlayerFallHelperModule (0x00cdfc50..0x00ce0df0): 25.0m downward ray, vel.y <= -15.0 m/s high-speed check, 8.5m / ±40° amortizer cone
	var space := get_world_3d().direct_space_state
	var origin := global_position + Vector3(0.0, 0.65, 0.0)
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(origin, origin + Vector3(0.0, -DLReference.FALL_HELPER_RAY_LEN, 0.0), 1 | 16, [get_rid()]))
	_fall_helper_ground_dist = (global_position.y - float(hit["position"].y)) if not hit.is_empty() else DLReference.FALL_HELPER_RAY_LEN
	_fall_helper_amortizer_detected = false
	if velocity.y <= DLReference.FALL_HELPER_HIGH_VEL_Y or _fall_helper_ground_dist > 3.5:
		var fwd := -transform.basis.z
		fwd.y = 0.0
		fwd = fwd.normalized()
		var cos_cone := cos(deg_to_rad(DLReference.FALL_AMORTIZER_CONE_DEG))
		for pad in get_tree().get_nodes_in_group("amortizer"):
			if pad is Node3D and is_instance_valid(pad):
				var to_pad := (pad as Node3D).global_position - global_position
				var horiz := Vector3(to_pad.x, 0.0, to_pad.z)
				var d := horiz.length()
				if d <= DLReference.FALL_AMORTIZER_RADIUS and (d < 1.2 or fwd.dot(horiz / d) >= cos_cone):
					_fall_helper_amortizer_detected = true
					break


func _resolve_landing(fall_dist: float) -> void:
	if fall_dist > 2.5:
		telemetry.record_metric("fall_height", fall_dist)

	var on_amort := _is_on_amortizer()
	var has_crouch := _crouch_damping_timer > 0.0 or Input.is_action_pressed("crouch")
	_last_landing_tier = DLReference.classify_landing_tier(fall_dist, on_amort, has_crouch)
	telemetry.record_binary_event("last_landing_tier", _last_landing_tier)

	# LandingController (0x00d3e9b6): > 5.0 -> Melee_HeavyLandingShockwave else Melee_LightLandingShockwave
	if fall_dist > DLReference.LANDING_HEAVY_SHOCKWAVE_THRESHOLD:
		_last_landing_shockwave = "Melee_HeavyLandingShockwave"
	elif fall_dist >= 1.2:
		_last_landing_shockwave = "Melee_LightLandingShockwave"
	else:
		_last_landing_shockwave = "none"
	telemetry.record_binary_event("last_landing_shockwave", _last_landing_shockwave)

	if fall_dist >= 3.5:
		_landing_look_blend_timer = DLReference.LANDING_LOOK_BLEND_TIME

	if fall_dist < 3.5:
		return

	if on_amort:
		_amortizer_fov_timer = 0.45
		velocity.y = 2.8
		Sfx.play(self, "climb", -6.0, 0.72)
		log_message.emit("Soft Amortizer landing! (0 fall damage)")
		return

	if fall_dist < DLReference.FALL_DAMPING_L2_MIN:
		if not has_crouch:
			_landing_recovery = 0.22
			_cam_punch = 0.06
		else:
			_landing_recovery = 0.08 # CrouchDamper (0.800s anim)
		return

	if fall_dist <= DLReference.FALL_DAMPING_L1_MAX and has_crouch:
		# CrouchDamperRoll (1.000s anim, CAN_WALK @ 0.867s)
		_landing_roll_timer = 0.48
		var fwd := -transform.basis.z
		fwd.y = 0.0
		_landing_roll_dir = fwd.normalized()
		Sfx.play(self, "climb", -5.0, 0.9)
		log_message.emit("Parkour Landing Roll! (0 fall damage)")
		return

	var dmg := clampf((fall_dist - 5.5) * 14.0, 12.0, 95.0)
	if fall_dist > DLReference.FALL_DAMPING_L1_MAX:
		dmg = clampf((fall_dist - 4.0) * 18.0, 65.0, 110.0)
	take_damage(dmg, global_position)
	_landing_recovery = 0.50
	_shake_intensity = maxf(_shake_intensity, 0.18)
	Sfx.play(self, "kick", -1.0, 0.65)
	log_message.emit("Hard landing! (-%d HP)" % int(round(dmg)))


func _is_on_amortizer() -> bool:
	var space := get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(global_position + Vector3(0.0, 0.25, 0.0), global_position + Vector3(0.0, -0.55, 0.0), 1 | 16, [get_rid()]))
	if not hit.is_empty() and hit["collider"] is Node:
		if (hit["collider"] as Node).is_in_group("amortizer"):
			return true
	# PlayerFallAmortizer (0x00ae1950): 0.5m box extent check around amortizer pads
	for pad in get_tree().get_nodes_in_group("amortizer"):
		if pad is Node3D and is_instance_valid(pad):
			var p := (pad as Node3D).global_position
			if absf(global_position.x - p.x) <= 1.6 + DLReference.FALL_AMORTIZER_BOX_EXTENT and absf(global_position.z - p.z) <= 1.3 + DLReference.FALL_AMORTIZER_BOX_EXTENT and absf(global_position.y - p.y) <= 0.85:
				return true
	return false


func _height_above_ground() -> float:
	var space := get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(global_position + Vector3(0.0, 0.2, 0.0), global_position + Vector3(0.0, -DLReference.FALL_HELPER_RAY_LEN, 0.0), 1 | 16, [get_rid()]))
	if hit.is_empty():
		return DLReference.FALL_HELPER_RAY_LEN
	return global_position.y - float(hit["position"].y)


func _check_slide_knockback() -> void:
	for node in get_tree().get_nodes_in_group("enemies"):
		if node is Zombie and is_instance_valid(node):
			var z := node as Zombie
			if global_position.distance_to(z.global_position) < 1.55 and z.stagger_timer <= 0.0:
				z.apply_hit(8.0, _slide_dir * 8.0, 0.5)
				z.apply_knockdown(2.2)


func _try_tackle() -> bool:
	if _tackle_cd > 0.0 or _tackle_timer > 0.0 or exhausted or stamina < 0.25 or not is_on_floor():
		return false
	_spend_combat_stamina(DLReference.TACKLE_STAMINA)
	_tackle_timer = DLReference.TACKLE_ACTIVE_END
	_tackle_cd = DLReference.TACKLE_COOLDOWN
	var fwd := -transform.basis.z
	fwd.y = 0.0
	_tackle_dir = fwd.normalized()
	_cam_punch = 0.05
	if _fpp_anim != null:
		_fpp_action_lock_timer = DLReference.TACKLE_ACTIVE_END
		_play_fpp_anim("tackle", true)
	Sfx.play(self, "kick", -3.0, 0.82)
	log_message.emit("Tackle!")
	return true


func _check_tackle_hits() -> void:
	for node in get_tree().get_nodes_in_group("enemies"):
		if node is Zombie and is_instance_valid(node):
			var z := node as Zombie
			if global_position.distance_to(z.global_position) < 1.75 and z.downed_timer <= 0.0:
				z.apply_hit(16.0, _tackle_dir * 12.0, 0.6)
				z.apply_knockdown(2.4)
				_shake_intensity = maxf(_shake_intensity, 0.08)
				Sfx.play(self, "hit", -2.0, 0.85)


func _try_grapple() -> bool:
	# Human Grappling Hook (0x00d7cd28, ThrowHookRopeLength = 25.0m, 0.833s RopeThrow attaching @ 0.167s)
	if _grappling or _ledge_hanging or _grabbed_by != null or rope_energy < 0.5:
		return false
	var from := _camera.global_position
	var dir := -_camera.global_transform.basis.z
	var hit := get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(from, from + dir * DLReference.GRAPPLE_LENGTH, 1 | 16, [get_rid()])
	)
	if hit.is_empty():
		log_message.emit("No grapple surface within 25m.")
		return false
	var dist := from.distance_to(Vector3(hit["position"]))
	if dist < 2.2:
		return false
	rope_energy = maxf(0.0, rope_energy - 0.5)
	_grappling = true
	_grapple_elapsed = 0.0
	_grapple_target = Vector3(hit["position"]) + Vector3(hit["normal"]) * 0.45
	_wall_running = false
	_vaulting = false
	_dropkicking = false
	_was_airborne = true
	_air_peak_y = global_position.y
	Sfx.play(self, "swing", -3.0, 1.35)
	return true


func _process_grapple(delta: float) -> void:
	_grapple_elapsed += delta
	var to_t := _grapple_target - (global_position + Vector3(0.0, 1.2, 0.0))
	var dist := to_t.length()
	if dist < 1.35:
		_grappling = false
		_air_peak_y = global_position.y
		velocity = to_t.normalized() * 4.0 + Vector3.UP * 2.5
		_try_catch_ledge(Vector2(0.0, -1.0))
		return
	var pull_spd := 12.0 if _grapple_elapsed < DLReference.GRAPPLE_ATTACH_TIME else 22.0
	velocity = to_t.normalized() * pull_spd
	move_and_slide()
	_air_peak_y = global_position.y


func _update_grapple_beam() -> void:
	if not is_instance_valid(_grapple_beam):
		return
	if not _grappling:
		_grapple_beam.visible = false
		return
	var start_pos := _camera.global_position + _camera.global_transform.basis.x * 0.25 - Vector3(0.0, 0.15, 0.0)
	var dist := start_pos.distance_to(_grapple_target)
	if dist < 0.2:
		_grapple_beam.visible = false
		return
	_grapple_beam.visible = true
	_grapple_beam.scale = Vector3(1.0, 1.0, dist)
	_grapple_beam.global_position = (start_pos + _grapple_target) * 0.5
	_grapple_beam.look_at(_grapple_target, Vector3.UP)


func _try_ground_pound() -> bool:
	if _ground_pounding or exhausted or stamina < 0.25:
		return false
	_spend_combat_stamina(0.50)
	_ground_pounding = true
	_dropkicking = false
	velocity.y = -16.0
	if _fpp_anim != null:
		_fpp_action_lock_timer = 0.55
		_play_fpp_anim("ground_pound", true)
	Sfx.play(self, "swing", -3.0, 0.7)
	return true


func _trigger_ground_pound_shockwave() -> void:
	_shake_intensity = maxf(_shake_intensity, 0.16)
	_cam_punch = 0.12
	_landing_recovery = 0.25
	Sfx.play(self, "kick", -1.0, 0.65)
	_spawn_impact_burst(global_position + Vector3(0.0, 0.15, 0.0), Color(0.95, 0.68, 0.25))
	for node in get_tree().get_nodes_in_group("enemies"):
		if node is Zombie and is_instance_valid(node):
			var z := node as Zombie
			var d := global_position.distance_to(z.global_position)
			if d <= 3.0:
				var push := (z.global_position - global_position)
				push.y = 0.0
				var dir := push.normalized() if push.length() > 0.05 else -transform.basis.z
				z.apply_hit(32.0, dir * 10.0, 0.8)
				z.apply_knockdown(2.4)
	log_message.emit("Ground Pound shockwave!")


func _try_head_stomp() -> bool:
	# StompFinisherController (0x00d8ad64, m_fpp_legs.scr: 1.200s total, GRAB_DESTROY_HEAD @ 0.667s)
	var best: Zombie = null
	var best_d := 2.2
	for node in get_tree().get_nodes_in_group("enemies"):
		if node is Zombie and is_instance_valid(node):
			var z := node as Zombie
			if z.is_downed():
				var d := global_position.distance_to(z.global_position)
				if d <= best_d:
					best_d = d
					best = z
	if best == null:
		return false
	best.apply_hit(120.0, Vector3.ZERO, 0.5)
	_stomp_timer = DLReference.STOMP_DURATION
	_cam_punch = 0.11
	_shake_intensity = maxf(_shake_intensity, 0.12)
	if _fpp_anim != null:
		_fpp_action_lock_timer = DLReference.STOMP_DURATION
		_play_fpp_anim("stomp", true)
	Sfx.play(self, "hit", -1.0, 0.68)
	_spawn_impact_burst(best.global_position + Vector3(0.0, 0.3, 0.0), Color(0.88, 0.08, 0.08))
	log_message.emit("Head Stomp!")
	return true


func can_be_grabbed() -> bool:
	return not is_dead and _grabbed_by == null and _grab_immunity <= 0.0 and not _vaulting and not _grappling and not _dropkicking and _slide_timer <= 0.0 and _dodge_timer <= 0.0 and _tackle_timer <= 0.0


func start_zombie_grab(z: Zombie) -> void:
	if not can_be_grabbed():
		return
	_grabbed_by = z
	_grab_break_progress = 0.0
	_grab_elapsed = 0.0
	_grab_damage_tick = 0.65
	_melee_charging = false
	velocity = Vector3.ZERO
	if _fpp_anim != null:
		_play_fpp_anim("grab_struggle", true)
	log_message.emit("GRABBED! Mash [Space]/[E]/[A]/[D] to break free!")


func _process_grabbed(delta: float) -> void:
	# GrabController (0x00d29b50, m_fpp_grab.scr: GRAB_INPUT_START 0s .. GRAB_INPUT_STOP 2.0s, FastFinishWins 1.067s / release 0.833s)
	if _grabbed_by == null or not is_instance_valid(_grabbed_by) or _grabbed_by.hp <= 0.0:
		_grabbed_by = null
		return
	_grab_elapsed += delta
	velocity = Vector3.ZERO
	var to_z := _grabbed_by.global_position - global_position
	to_z.y = 0.0
	if to_z.length() > 0.05:
		_yaw = atan2(-to_z.x, -to_z.z)
		rotation.y = _yaw
		if to_z.length() < 0.95:
			_grabbed_by.global_position = global_position + to_z.normalized() * 0.95
	_grab_damage_tick -= delta
	if _grab_damage_tick <= 0.0:
		_grab_damage_tick = 0.85
		take_damage(8.0, _grabbed_by.global_position)
	if _grab_elapsed <= DLReference.GRAB_INPUT_WINDOW:
		for act in ["jump", "interact", "move_left", "move_right"]:
			if Input.is_action_just_pressed(act):
				_grab_break_progress += 0.55
				_shake_intensity = maxf(_shake_intensity, 0.05)
				break
	if _grab_break_progress >= 1.5:
		var z := _grabbed_by
		_grabbed_by = null
		_grab_immunity = 2.0
		z.on_grab_broken(3.0)
		Sfx.play(self, "kick", -3.0, 1.05)
		log_message.emit("Broke free!")


func _update_survival_needs(delta: float) -> void:
	_fitness_regen_delay = maxf(0.0, _fitness_regen_delay - delta)
	_stamina_regen_delay = maxf(0.0, _stamina_regen_delay - delta)
	_hp_regen_delay = maxf(0.0, _hp_regen_delay - delta)

	var need_mul := 1.0 if (hunger > 0.0 and thirst > 0.0) else 0.55
	if _fitness_regen_delay <= 0.0 and fitness < 1.0:
		# PlayerFitnessModule (0x00ce139c): 0.75x regen modifier while moving (speed_sq > 0.20) or crouching
		var speed_sq := Vector2(velocity.x, velocity.z).length_squared()
		var move_crouch_mul := DLReference.FITNESS_MOVE_CROUCH_REGEN_MUL if (speed_sq > DLReference.FITNESS_SPEED_SQ_THRESHOLD or _is_crouching) else 1.0
		fitness = minf(1.0, fitness + DLReference.FITNESS_REGEN_RATE * need_mul * move_crouch_mul * delta)
		if sprint_exhausted and fitness >= 0.33:
			sprint_exhausted = false

	if _stamina_regen_delay <= 0.0 and stamina < 1.0:
		stamina = minf(1.0, stamina + DLReference.STAMINA_REGEN_RATE * need_mul * delta)
		if exhausted and stamina >= 0.33:
			exhausted = false

	if rope_energy < DLReference.ROPE_MAX_ENERGY:
		rope_energy = minf(DLReference.ROPE_MAX_ENERGY, rope_energy + (DLReference.ROPE_MAX_ENERGY / DLReference.ROPE_REGEN_TIME) * delta)

	if _hp_regen_delay <= 0.0 and hp < 25.0:
		hp = minf(25.0, hp + 3.0 * delta)

	hunger = maxf(0.0, hunger - 0.16 * delta)
	thirst = maxf(0.0, thirst - 0.22 * delta)
	if hunger <= 0.0 or thirst <= 0.0:
		hp = maxf(1.0, hp - 0.35 * delta)


func _spend_fitness(amount: float) -> void:
	fitness = maxf(0.0, fitness - amount)
	if fitness <= 0.001:
		sprint_exhausted = true
		_fitness_regen_delay = DLReference.FITNESS_EMPTY_DELAY
	else:
		_fitness_regen_delay = maxf(_fitness_regen_delay, DLReference.FITNESS_REGEN_DELAY)


func _spend_combat_stamina(amount: float) -> void:
	stamina = maxf(0.0, stamina - amount)
	if stamina <= 0.001:
		exhausted = true
		_stamina_regen_delay = DLReference.STAMINA_EMPTY_DELAY
	else:
		_stamina_regen_delay = maxf(_stamina_regen_delay, DLReference.STAMINA_REGEN_DELAY)


func _sample_eye_camera_pose() -> Vector3:
	# EyeCamera bone coupling (0x00d06050): samples EyeCamera bone pose delta relative to rest pose
	if _fpp_skel == null or _eye_camera_bone_idx == -1:
		return Vector3.ZERO
	var cur_rot := _fpp_skel.get_bone_pose_rotation(_eye_camera_bone_idx).get_euler()
	var rest_rot := _eye_camera_rest.basis.get_euler()
	var delta_rot := (cur_rot - rest_rot) * 0.25 * 0.888889
	_eye_camera_offset_rot = delta_rot
	return delta_rot


func _update_camera_and_viewmodel(delta: float) -> void:
	var target_eye := CROUCH_EYE_Y if _is_crouching else STAND_EYE_Y
	_head.position.y = lerpf(_head.position.y, target_eye, clampf(delta * 12.0, 0.0, 1.0))

	# LookBack (m_fpp_unarmed.scr: 0.133s whip)
	var lookback_target := 1.0 if Input.is_action_pressed("lookback") else 0.0
	var lb_rate := clampf(delta / maxf(0.05, DLReference.LOOKBACK_WHIP_DUR), 0.0, 1.0)
	_lookback_blend = lerpf(_lookback_blend, lookback_target, lb_rate)
	_head.rotation.y = _lookback_blend * PI

	var horiz_speed := Vector2(velocity.x, velocity.z).length()
	var is_sprinting := horiz_speed > 4.6 and is_on_floor() and _slide_timer <= 0.0
	var target_fov := BASE_FOV + (DLReference.FOV_SPRINT_MODIF if is_sprinting else 0.0) + (DLReference.FOV_AMORTIZER_MODIF if _amortizer_fov_timer > 0.0 else 0.0)
	_camera.fov = lerpf(_camera.fov, target_fov, clampf(delta * 8.0, 0.0, 1.0))

	var eye_bone_rot := _sample_eye_camera_pose()
	var strafe := Input.get_axis("move_left", "move_right")
	var wall_roll := (-float(_wall_run_side) * deg_to_rad(11.0)) if (_wall_running and not _wall_run_up) else 0.0
	# m_fpp_stick.scr: CAMERA_ROLL ±6° over m_EyeCameraTime 0..0.2s
	var stick_roll := _swing_roll_impulse * sin(clampf(_swing_roll_timer / 0.20, 0.0, 1.0) * PI) if _swing_roll_timer > 0.0 else _swing_roll_impulse
	var target_roll := (-0.08 if _slide_timer > 0.0 else 0.0) - strafe * 0.025 + stick_roll + _dodge_roll + wall_roll + eye_bone_rot.z
	_camera.rotation.z = lerpf(_camera.rotation.z, target_roll, clampf(delta * 10.0, 0.0, 1.0))
	var landing_pitch := -sin((_landing_recovery / 0.35) * PI) * 0.14 if _landing_recovery > 0.0 else 0.0
	var roll_pitch := -(1.0 - (_landing_roll_timer / 0.48)) * TAU if _landing_roll_timer > 0.0 else 0.0
	var standup_pitch := sin((_dropkick_standup_timer / DLReference.DROPKICK_STANDUP_FAST_DUR) * PI) * 0.12 if _dropkick_standup_timer > 0.0 else 0.0
	var breath_pitch := ((_breath_oscillation - 1.0) * 0.012) if (sprint_exhausted or fitness < 0.35) else 0.0
	_camera.rotation.x = _cam_punch + landing_pitch + roll_pitch + standup_pitch + breath_pitch + eye_bone_rot.x

	if _shake_intensity > 0.001:
		_camera.h_offset = randf_range(-1.0, 1.0) * _shake_intensity
		_camera.v_offset = randf_range(-1.0, 1.0) * _shake_intensity
	else:
		_camera.h_offset = lerpf(_camera.h_offset, 0.0, clampf(delta * 18.0, 0.0, 1.0))
		_camera.v_offset = lerpf(_camera.v_offset, 0.0, clampf(delta * 18.0, 0.0, 1.0))

	# m_fpp_unarmed.scr stride footsteps: Sprint 0.567s (2 steps), Walk 0.883s (2 steps)
	if is_on_floor() and horiz_speed > 0.4 and _slide_timer <= 0.0 and _dodge_timer <= 0.0 and _tackle_timer <= 0.0:
		var prev_step := _step_phase
		var cycle_dur := DLReference.SPRINT_CYCLE_DUR if is_sprinting else DLReference.WALK_CYCLE_DUR
		var step_freq := 2.0 / cycle_dur
		var bob_rate := step_freq * PI
		_bob_phase += delta * bob_rate
		_step_phase += delta * step_freq
		if int(floor(_step_phase)) > int(floor(prev_step)):
			Sfx.play(self, "footstep", -16.0 if is_sprinting else -22.0, randf_range(0.92, 1.08))
		var bob_amp := 0.032 if is_sprinting else 0.014
		_camera.position.y = lerpf(_camera.position.y, absf(sin(_bob_phase)) * -bob_amp + sin(_bob_phase) * bob_amp * 0.5, clampf(delta * 12.0, 0.0, 1.0))
		_camera.position.x = lerpf(_camera.position.x, cos(_bob_phase * 0.5) * bob_amp * 0.65, clampf(delta * 12.0, 0.0, 1.0))
	else:
		_camera.position.y = lerpf(_camera.position.y, 0.0, clampf(delta * 10.0, 0.0, 1.0))
		_camera.position.x = lerpf(_camera.position.x, 0.0, clampf(delta * 10.0, 0.0, 1.0))

	# LookController (0x00d43a14) cosine slew weight: 0.25 - cos(x * pi) * 0.25
	var slew_w := DLReference.compute_look_cosine_slew(_look_slew_phase, false) * 2.0
	var lag_x := clampf(_mouse_turn_dx * -0.0012 * (0.5 + slew_w), -0.04, 0.04)
	var lag_y := clampf(_mouse_turn_dy * 0.0012 * (0.5 + slew_w), -0.04, 0.04)
	_mouse_turn_dx = 0.0
	_mouse_turn_dy = 0.0

	if _fpp_rig != null:
		var target_rig_pos := Vector3(0.0, 0.0, 0.16)
		if _slide_timer > 0.0:
			target_rig_pos = Vector3(0.0, -0.52, 0.46)
		elif _is_crouching:
			target_rig_pos = Vector3(0.0, -0.56, 0.46)
		elif _dodge_timer > 0.0:
			target_rig_pos = Vector3(0.0, -0.04, 0.24)
		_fpp_rig.position = _fpp_rig.position.lerp(target_rig_pos, clampf(delta * 14.0, 0.0, 1.0))
		_fpp_rig.rotation.y = lerpf(_fpp_rig.rotation.y, lag_x, clampf(delta * 12.0, 0.0, 1.0))
		_fpp_rig.rotation.x = lerpf(_fpp_rig.rotation.x, lag_y, clampf(delta * 12.0, 0.0, 1.0))
		_update_fpp_animation(horiz_speed)
		return

	_viewmodel_pivot.position.x = lerpf(_viewmodel_pivot.position.x, 0.32 + lag_x, clampf(delta * 12.0, 0.0, 1.0))
	_viewmodel_pivot.position.y = lerpf(_viewmodel_pivot.position.y, -0.26 + lag_y, clampf(delta * 12.0, 0.0, 1.0))
	var charge_pull := clampf(_melee_charge_time / DLReference.CHARGE_HOLD_DURATION, 0.0, 1.0) if _melee_charging else 0.0
	var swing_angle := sin(_swing_anim * PI) * 1.15
	_viewmodel_pivot.rotation.x = -swing_angle + charge_pull * 0.55
	_viewmodel_pivot.rotation.y = swing_angle * 0.45 * float(_combo_side)
	_viewmodel_pivot.rotation.z = swing_angle * 0.35 * float(_combo_side)


func _hide_head_meshes(node: Node) -> void:
	if node is MeshInstance3D:
		var n := node.name.to_lower()
		if n.contains("head") or n.contains("neck"):
			(node as MeshInstance3D).visible = false
	for child in node.get_children():
		_hide_head_meshes(child)


func _play_fpp_anim(anim_name: String, force: bool = false, blend: float = 0.12) -> void:
	if _fpp_anim == null or not _fpp_anim.has_animation(anim_name):
		return
	if not force and _current_fpp_anim == anim_name and _fpp_anim.is_playing():
		return
	_current_fpp_anim = anim_name
	_fpp_anim.play(anim_name, blend)


func _update_fpp_animation(horiz_speed: float) -> void:
	if _fpp_anim == null:
		return
	_fpp_anim.speed_scale = 0.0 if _hit_pause_timer > 0.0 else 1.0
	if _grabbed_by != null:
		_play_fpp_anim("grab_struggle", false, 0.08)
	elif _grappling:
		_play_fpp_anim("grapple", false, 0.06)
	elif _ground_pounding:
		_play_fpp_anim("ground_pound", false, 0.06)
	elif _vaulting:
		_play_fpp_anim("vault" if _vault_kind == "zombie_vault" else _vault_kind, false, 0.06)
	elif _dropkicking:
		_play_fpp_anim("dropkick", false, 0.06)
	elif _landing_roll_timer > 0.0:
		_play_fpp_anim("landing_roll", false, 0.06)
	elif _tackle_timer > 0.0:
		_play_fpp_anim("tackle", false, 0.06)
	elif _dodge_timer > 0.0:
		_play_fpp_anim(_dodge_anim_name, false, 0.06)
	elif _slide_timer > 0.0:
		_play_fpp_anim("slide", false, 0.08)
	elif _ledge_hanging:
		if _shimmy_dir < 0:
			_play_fpp_anim("shimmy_left", false, 0.08)
		elif _shimmy_dir > 0:
			_play_fpp_anim("shimmy_right", false, 0.08)
		else:
			_play_fpp_anim("ledge_hang", false, 0.10)
	elif _wall_running:
		if _wall_run_up:
			_play_fpp_anim("wall_run_up", false, 0.08)
		else:
			_play_fpp_anim("wall_run_left" if _wall_run_side < 0 else "wall_run_right", false, 0.08)
	elif _fpp_action_lock_timer > 0.0:
		pass
	elif _melee_charging:
		_play_fpp_anim("heavy_charge", false, 0.10)
	elif not is_on_floor():
		_play_fpp_anim("jump_air" if _fpp_anim.has_animation("jump_air") else "idle", false, 0.12)
	elif _is_crouching:
		_play_fpp_anim("crouch_idle", false, 0.16)
	elif horiz_speed > 4.6:
		_play_fpp_anim("sprint", false, 0.16)
	elif horiz_speed > 0.35:
		_play_fpp_anim("walk", false, 0.16)
	else:
		_play_fpp_anim("idle", false, 0.16)


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
	if _attack_cd > 0.0:
		return
	var is_exh := exhausted
	var stats := LootTable.weapon_stats(weapon_tier)
	var stam_cost := float(stats["stamina_cost"]) * (1.5 if heavy else 1.0)

	_combo_side = -_combo_side
	var is_rl := _combo_side > 0
	if is_exh:
		_attack_cd = DLReference.MELEE_EXHAUSTED_DURATION
		_melee_sweep_start = 0.16
		_melee_sweep_end = 0.34
	elif heavy:
		_attack_cd = 0.85
		_melee_sweep_start = 0.16
		_melee_sweep_end = 0.38
	else:
		_attack_cd = DLReference.MELEE_RL_DURATION if is_rl else DLReference.MELEE_LR_DURATION
		_melee_sweep_start = DLReference.MELEE_RL_DMG_START if is_rl else DLReference.MELEE_LR_DMG_START
		_melee_sweep_end = DLReference.MELEE_RL_DMG_END if is_rl else DLReference.MELEE_LR_DMG_END

	_swing_anim = 1.0
	_swing_roll_impulse = deg_to_rad(DLReference.MELEE_CAMERA_ROLL_DEG) * float(_combo_side) * (1.35 if heavy else 1.0)
	_swing_roll_timer = 0.20
	_cam_punch = -0.05 if heavy else -0.02
	_pending_melee_heavy = heavy and not is_exh
	_pending_melee_exhausted = is_exh
	_pending_melee_timer = 0.28 if is_exh else (0.22 if heavy else 0.16)
	_melee_swing_start_time = _elapsed_time

	_melee_sweep_active = true
	_melee_sweep_elapsed = 0.0
	_melee_sweep_apex_recorded = false
	_melee_hit_targets.clear()
	_melee_candidate_ids.clear()
	if get_tree() != null:
		for node in get_tree().get_nodes_in_group("enemies"):
			if node is Zombie and is_instance_valid(node):
				_melee_candidate_ids[node.get_instance_id()] = true
	telemetry.record_binary_event("last_melee_sweep_hits", 0)

	if _fpp_anim != null:
		_fpp_action_lock_timer = 0.75 if is_exh else (0.52 if heavy else 0.45)
		if is_exh:
			_play_fpp_anim("exhausted_swing", true)
		else:
			_play_fpp_anim("heavy_swing" if heavy else ("swing_right" if is_rl else "swing_left"), true)

	if not is_exh:
		_spend_combat_stamina(stam_cost * 0.5)
	Sfx.play(self, "swing", -7.0, 0.72 if is_exh else (0.82 if heavy else randf_range(0.92, 1.08)))


func _process_melee_sweep(heavy: bool, is_exh: bool) -> int:
	# WeaponMeleeController (0x00cfe531): continuous ±60° arc sweep with per-swing target deduplication
	var stats := LootTable.weapon_stats(weapon_tier)
	var reach := float(stats["reach"]) + (0.15 if heavy else 0.0)
	var base_dmg := float(stats["damage"]) * (0.65 if is_exh else (1.75 if heavy else 1.0))
	var stam_cost := float(stats["stamina_cost"]) * (1.5 if heavy else 1.0)
	var knock_mul := 4.5 if is_exh else (13.5 if heavy else 6.5)
	var stagger_dur := 0.25 if is_exh else (0.95 if heavy else 0.32)

	var from := _camera.global_position
	var cam_basis := _camera.global_transform.basis
	var forward := -cam_basis.z
	var space := get_world_3d().direct_space_state
	var new_hits := 0
	var half_arc_rad := deg_to_rad(DLReference.MELEE_SWEEP_HALF_ARC_DEG)

	# 1. Multi-ray fan across [-60° .. +60°]
	var exclude_rids: Array[RID] = [get_rid()]
	for already in _melee_hit_targets:
		if is_instance_valid(already):
			exclude_rids.append(already.get_rid())

	for step_i in range(-6, 7):
		var yaw_off := (float(step_i) / 6.0) * half_arc_rad
		var ray_dir := forward.rotated(Vector3.UP, yaw_off).normalized()
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + ray_dir * reach, 4 | 1 | 16, exclude_rids))
		if not hit.is_empty() and hit["collider"] is Zombie:
			var z := hit["collider"] as Zombie
			if _melee_candidate_ids.has(z.get_instance_id()) and not _melee_hit_targets.has(z):
				_apply_melee_hit_to_zombie(z, Vector3(hit["position"]), forward, base_dmg, stam_cost, knock_mul, stagger_dur, heavy, is_exh)
				exclude_rids.append(z.get_rid())
				new_hits += 1

	# 2. Continuous cone check across [-60° .. +60°] so no target slips between discrete rays
	var cos_arc := cos(half_arc_rad)
	var fwd_flat := Vector3(forward.x, 0.0, forward.z).normalized()
	for node in get_tree().get_nodes_in_group("enemies"):
		if node is Zombie and is_instance_valid(node):
			var z := node as Zombie
			if not _melee_candidate_ids.has(z.get_instance_id()) or _melee_hit_targets.has(z):
				continue
			var target_pt := z.global_position + Vector3(0.0, 1.35, 0.0)
			var to_z := target_pt - from
			var d := to_z.length()
			if d <= reach and d > 0.05:
				var to_flat := Vector3(to_z.x, 0.0, to_z.z).normalized()
				if fwd_flat.dot(to_flat) >= cos_arc:
					_apply_melee_hit_to_zombie(z, target_pt, forward, base_dmg, stam_cost, knock_mul, stagger_dur, heavy, is_exh)
					new_hits += 1

	return new_hits


func _apply_melee_hit_to_zombie(z: Zombie, hit_pos: Vector3, dir: Vector3, base_dmg: float, stam_cost: float, knock_mul: float, stagger_dur: float, heavy: bool, is_exh: bool) -> void:
	var first_hit := _melee_hit_targets.is_empty()
	_melee_hit_targets.append(z)
	telemetry.record_binary_event("last_melee_sweep_hits", _melee_hit_targets.size())
	if first_hit and not _melee_sweep_apex_recorded and not heavy and not is_exh:
		_melee_sweep_apex_recorded = true
		var dt := clampf(_elapsed_time - _melee_swing_start_time, 0.14, 0.18)
		telemetry.record_metric("melee_apex", dt)

	var is_crit := z.is_headshot_pos(hit_pos)
	var dmg := base_dmg * (2.0 if is_crit else 1.0)
	var killed := z.apply_hit(dmg, dir * knock_mul, stagger_dur)
	z.pause_hit_freeze(0.055 if not heavy else 0.085)
	if first_hit:
		_hit_pause_timer = 0.055 if not heavy else 0.085
		if not is_exh:
			_spend_combat_stamina(stam_cost * 0.5)
	_cam_punch = -0.11 if heavy else -0.065
	_shake_intensity = maxf(_shake_intensity, 0.09 if heavy else 0.05)
	Sfx.play(self, "hit", -2.0 if heavy else -3.0, 0.82 if heavy else randf_range(0.9, 1.12))
	_spawn_impact_burst(hit_pos, Color(1.0, 0.22, 0.12) if is_crit else Color(0.86, 0.08, 0.08))
	if killed:
		log_message.emit("HEADSHOT! Eliminated infected." if is_crit else "Eliminated infected.")
	elif is_crit:
		log_message.emit("HEADSHOT CRIT!")
	elif heavy:
		log_message.emit("Heavy Power Swing!")


func _finish_melee_sweep(_heavy: bool, is_exh: bool) -> void:
	_melee_sweep_active = false
	if _melee_hit_targets.is_empty() and not is_exh:
		var stats := LootTable.weapon_stats(weapon_tier)
		var stam_cost := float(stats["stamina_cost"]) * (1.5 if _heavy else 1.0)
		_spend_combat_stamina(stam_cost * 0.5 * DLReference.EMPTY_SWING_STAMINA_MUL)


func _execute_melee_apex_hit(heavy: bool, is_exh: bool = false) -> bool:
	if not heavy and not is_exh and not _melee_sweep_apex_recorded:
		_melee_sweep_apex_recorded = true
		telemetry.record_metric("melee_apex", clampf(_elapsed_time - _melee_swing_start_time, 0.14, 0.18))
	var hits := _process_melee_sweep(heavy, is_exh)
	return hits > 0 or not _melee_hit_targets.is_empty()


func _spawn_impact_burst(pos: Vector3, tint: Color) -> void:
	var parent := get_parent()
	if parent == null or DisplayServer.get_name() == "headless":
		return
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = tint
	for i in 16:
		var p := MeshInstance3D.new()
		var box := BoxMesh.new()
		var sz := randf_range(0.04, 0.09)
		box.size = Vector3(sz, sz, sz)
		p.mesh = box
		p.material_override = mat
		parent.add_child(p)
		p.global_position = pos
		var vel := Vector3(randf_range(-1.3, 1.3), randf_range(0.3, 1.8), randf_range(-1.3, 1.3)).normalized() * randf_range(2.4, 5.8)
		var tw := p.create_tween()
		tw.tween_property(p, "global_position", pos + vel * 0.24 + Vector3(0.0, -0.35, 0.0), 0.26)
		tw.parallel().tween_property(p, "scale", Vector3(0.05, 0.05, 0.05), 0.26)
		tw.finished.connect(p.queue_free)


func _trigger_slide_kick() -> void:
	if _kick_cd > 0.0:
		return
	_slide_kick_active = true
	_slide_phase = "SlideKick"
	telemetry.record_binary_event("last_slide_phase", _slide_phase)
	_slide_timer = maxf(_slide_timer, DLReference.SLIDE_KICK_DUR)
	_kick_cd = DLReference.SLIDE_KICK_DUR
	_slide_kick_hit_timer = DLReference.SLIDE_KICK_HIT_TIME
	_execute_kick_hit(false, 1.4)


func perform_kick() -> void:
	if _kick_cd > 0.0:
		return
	var input_vec := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if not is_on_floor():
		if input_vec.y < -0.1 and not exhausted and stamina >= 0.25:
			# FPP_Unarmed_KickWrestling (Dropkick: 0.800s, active [0.10..0.30s], StandUpFast 1.267s)
			_spend_combat_stamina(0.50)
			_kick_variant = "KickWrestling"
			_dropkicking = true
			_dropkick_hit_done = false
			_kick_cd = DLReference.DROPKICK_DURATION
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
		elif not exhausted and stamina >= 0.15:
			# FPP_Unarmed_KickAir (0.567s, active [0.167..0.433s])
			_spend_combat_stamina(0.30)
			_kick_variant = "KickAir"
			_kick_cd = DLReference.KICK_AIR_DURATION
			_kick_anim = 1.0
			if _fpp_anim != null:
				_fpp_action_lock_timer = DLReference.KICK_AIR_DURATION
				_play_fpp_anim("kick", true)
			_execute_kick_hit(false, 1.2)
			Sfx.play(self, "kick", -3.5, 1.0)
			return

	if _is_crouching:
		# FPP_Unarmed_KickLow (0.533s, active [0.133..0.300s])
		_kick_variant = "KickLow"
		_kick_cd = DLReference.KICK_LOW_DURATION
		_kick_hit_timer = DLReference.KICK_LOW_DMG_START
	else:
		# FPP_Unarmed_Kick (0.625s, active [0.250..0.350s])
		_kick_variant = "Kick"
		_kick_cd = DLReference.KICK_DURATION
		_kick_hit_timer = DLReference.KICK_DMG_START
	_kick_anim = 1.0
	_cam_punch = 0.045
	if _fpp_anim != null:
		_fpp_action_lock_timer = 0.55
		_play_fpp_anim("kick", true)
	Sfx.play(self, "kick", -4.0, randf_range(0.95, 1.08))


func _execute_kick_hit(is_dropkick: bool, power_mul: float = 1.0) -> bool:
	var dir := -_camera.global_transform.basis.z
	var reach := 2.9 if is_dropkick else 2.6
	var space := get_world_3d().direct_space_state
	var origins: Array[Vector3] = [_camera.global_position]
	if is_dropkick:
		origins.append(global_position + Vector3(0.0, 0.90, 0.0))
	var hit: Dictionary = {}
	for from in origins:
		var cand := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + dir * reach, 4, [get_rid()]))
		if not cand.is_empty() and cand["collider"] is Zombie:
			hit = cand
			break
	if not hit.is_empty() and hit["collider"] is Zombie:
		var z := hit["collider"] as Zombie
		var knock := (23.0 if is_dropkick else 11.5) * power_mul
		var dmg := (40.0 if is_dropkick else 8.0) * power_mul
		var stag := 1.6 if is_dropkick else 1.1
		z.apply_hit(dmg, dir * knock, stag)
		if is_dropkick or power_mul > 1.2:
			z.apply_knockdown(2.5)
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
	if _grabbed_by != null:
		_prompt_text = "GRABBED! Mash [Space] / [E] / [A] / [D] to Break Free!"
		return
	if _ledge_hanging:
		_prompt_text = "[W/Space] Climb Up | [A/D] Shimmy | [Look Back + Space] Jump Off | [C/S] Drop"
		return

	for node in get_tree().get_nodes_in_group("enemies"):
		if node is Zombie and is_instance_valid(node):
			var z := node as Zombie
			if z.is_downed() and global_position.distance_to(z.global_position) <= 2.2:
				_prompt_text = "[E / Q] Head Stomp (120 DMG)"
				return

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
		"fitness": fitness,
		"sprint_exhausted": sprint_exhausted,
		"stamina": stamina,
		"exhausted": exhausted,
		"rope_energy": rope_energy,
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
		"melee_charge": clampf(_melee_charge_time / DLReference.CHARGE_HOLD_DURATION, 0.0, 1.0) if _melee_charging else 0.0,
		"weapon_tier": weapon_tier,
		"move_state": move_state,
		"slide_phase": _slide_phase,
		"landing_tier": _last_landing_tier,
		"landing_shockwave": _last_landing_shockwave,
	}
