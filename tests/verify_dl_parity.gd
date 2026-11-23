extends SceneTree

var _checks: Array[Dictionary] = []
var _failed: bool = false


func _record(label: String, ok: bool, detail: String = "") -> void:
	_checks.append({"label": label, "ok": ok, "detail": detail})
	if not ok:
		_failed = true


func _release_all() -> void:
	for act in [
		"move_forward", "move_back", "move_left", "move_right",
		"jump", "sprint", "crouch", "dodge", "kick", "interact",
		"primary_action", "secondary_action", "grapple", "lookback",
	]:
		if InputMap.has_action(act) and Input.is_action_pressed(act):
			Input.action_release(act)


func _reset_player(player: Player, pos: Vector3, yaw: float = 0.0, pitch: float = 0.0) -> void:
	_release_all()
	player.velocity = Vector3.ZERO
	player.global_position = pos
	player.rotation.y = yaw
	player._yaw = yaw
	player._pitch = pitch
	player._head.rotation.x = pitch
	player._head.rotation.y = 0.0
	player._lookback_blend = 0.0
	player.hp = 100.0
	player.fitness = 1.0
	player.sprint_exhausted = false
	player.stamina = 1.0
	player.exhausted = false
	player.rope_energy = DLReference.ROPE_MAX_ENERGY
	player._is_crouching = false
	player._vaulting = false
	player._ledge_hanging = false
	player._wall_running = false
	player._wall_run_up = false
	player._wall_jumps_used = 0
	player._grappling = false
	player._dropkicking = false
	player._ground_pounding = false
	player._slide_timer = 0.0
	player._dodge_timer = 0.0
	player._tackle_timer = 0.0
	player._landing_roll_timer = 0.0
	player._landing_recovery = 0.0
	player._grabbed_by = null
	player._grab_immunity = 0.0
	player._jump_cd = 0.0
	player._coyote_timer = 0.0
	player._jump_buffer_timer = 0.0
	player._kick_cd = 0.0
	player._attack_cd = 0.0
	player._pending_melee_timer = -1.0
	player._melee_sweep_active = false
	player._slide_phase = "none"
	player._dodge_cd = 0.0
	player._slide_cd = 0.0
	player._tackle_cd = 0.0
	player._wall_run_cd = 0.0
	player._ledge_drop_cd = 0.0
	player._crouch_damping_timer = 0.0
	player._amortizer_fov_timer = 0.0
	player._was_airborne = false
	player._air_peak_y = pos.y
	player._cap.height = Player.STAND_HEIGHT
	player._col.position.y = Player.STAND_HEIGHT * 0.5
	await physics_frame
	await process_frame


func _tap_action(act: String) -> void:
	await process_frame
	Input.action_press(act)
	await physics_frame
	await process_frame
	Input.action_release(act)


func _initialize() -> void:
	call_deferred("_run_parity")


func _run_parity() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	if scene == null:
		printerr("Failed to load res://scenes/main.tscn")
		quit(1)
		return

	var world := scene.instantiate()
	world.set("run_seed", 77777)
	root.add_child(world)
	await process_frame
	await physics_frame

	var player := get_first_node_in_group("player") as Player
	if player == null:
		printerr("Player not found")
		quit(1)
		return

	# Move ambient zombies out of the calibration clearing so locomotion checks are clean
	var amb_idx := 0
	for z in get_nodes_in_group("enemies"):
		if z is Node3D:
			(z as Node3D).global_position = Vector3(32.0 + float(amb_idx) * 2.0, 0.2, 40.0)
			z.set_physics_process(false)
			amb_idx += 1

	# --- 1. Base Locomotion Speeds ---
	await _reset_player(player, Vector3(0.0, 0.0, 32.0))
	Input.action_press("move_forward")
	for _i in 30:
		await physics_frame
	var walk_spd := Vector2(player.velocity.x, player.velocity.z).length()
	player.telemetry.record_metric("walk_speed", walk_spd)
	Input.action_release("move_forward")

	await _reset_player(player, Vector3(0.0, 0.0, 32.0))
	Input.action_press("move_left")
	for _i in 30:
		await physics_frame
	var strafe_spd := Vector2(player.velocity.x, player.velocity.z).length()
	player.telemetry.record_metric("strafe_speed", strafe_spd)
	Input.action_release("move_left")

	await _reset_player(player, Vector3(0.0, 0.0, 34.0))
	Input.action_press("move_forward")
	Input.action_press("sprint")
	for _i in 50:
		await physics_frame
	var sprint_spd := Vector2(player.velocity.x, player.velocity.z).length()
	player.telemetry.record_metric("sprint_speed", sprint_spd)
	Input.action_release("sprint")
	Input.action_release("move_forward")

	await _reset_player(player, Vector3(0.0, 0.0, 32.0))
	Input.action_press("move_forward")
	Input.action_press("crouch")
	for _i in 55:
		await physics_frame
	var crouch_spd := Vector2(player.velocity.x, player.velocity.z).length()
	player.telemetry.record_metric("crouch_speed", crouch_spd)
	Input.action_release("crouch")
	Input.action_release("move_forward")

	# --- 2. Jump Kinematics ---
	await _reset_player(player, Vector3(0.0, 0.0, 32.0))
	var jump_start_y := player.global_position.y
	var jump_peak_y := jump_start_y
	var air_frames := 0
	await _tap_action("jump")
	for _i in 70:
		await physics_frame
		jump_peak_y = maxf(jump_peak_y, player.global_position.y)
		if not player.is_on_floor():
			air_frames += 1
		elif air_frames > 3:
			break
	var apex := jump_peak_y - jump_start_y
	var hang_t := float(air_frames) / 60.0
	player.telemetry.record_metric("jump_apex", apex)
	player.telemetry.record_metric("jump_hang_time", hang_t)
	_record("Jump interval >= 0.40s", DLReference.MIN_JUMP_INTERVAL >= 0.40, "MIN_JUMP_INTERVAL=%.2fs" % DLReference.MIN_JUMP_INTERVAL)

	# --- 3. Stair Step-Up (<= 0.51m) & Crouch Tunnel (1.35m) ---
	await _reset_player(player, Vector3(-2.5, 0.0, -2.0))
	Input.action_press("move_forward")
	for _i in 75:
		await physics_frame
	Input.action_release("move_forward")
	_record("Stair step-up (0.42m steps)", player.global_position.y >= 0.80, "y=%.2fm" % player.global_position.y)

	await _reset_player(player, Vector3(4.5, 0.0, 5.5))
	Input.action_press("move_forward")
	Input.action_press("sprint")
	for _i in 24:
		await physics_frame
	Input.action_release("sprint")
	Input.action_press("crouch")
	for _i in 18:
		await physics_frame
	var under_height := player._cap.height
	Input.action_release("crouch")
	for _i in 10:
		await physics_frame
	var stayed_crouched_under := player._is_crouching
	Input.action_release("move_forward")
	_record("Low Slide Tunnel (1.35m clearance)", under_height < 1.30 and stayed_crouched_under, "cap_h=%.2f stayed_crouched=%s" % [under_height, stayed_crouched_under])

	# --- 4. Low Vault & High Mantle ---
	await _reset_player(player, Vector3(-7.5, 0.0, 0.15))
	Input.action_press("move_forward")
	Input.action_press("sprint")
	for _i in 8:
		await physics_frame
	await _tap_action("jump")
	var low_vault_ok := player._vaulting and player._vault_kind == "vault"
	var lv_dbg := "st=%s v=%s k=%s" % [player.move_state, player._vaulting, player._vault_kind]
	var vault_t0 := player._elapsed_time
	for _i in 30:
		await physics_frame
		if not player._vaulting:
			break
	var vault_dur := player._elapsed_time - vault_t0
	var exit_spd := Vector2(player.velocity.x, player.velocity.z).length()
	_release_all()
	_record("Low Vault (0.51-1.25m) + sprint exit", low_vault_ok and exit_spd >= 5.5, "%s dur=%.2fs exit=%.2f m/s" % [lv_dbg, vault_dur, exit_spd])

	await _reset_player(player, Vector3(-8.5, 0.0, -4.2))
	Input.action_press("move_forward")
	await _tap_action("jump")
	var high_ok := player._vaulting and player._vault_kind == "climb_ledge"
	var hm_dbg := "st=%s v=%s k=%s" % [player.move_state, player._vaulting, player._vault_kind]
	for _i in 45:
		await physics_frame
		if not player._vaulting:
			break
	_release_all()
	_record("High Mantle (1.25-2.35m)", high_ok and player.global_position.y >= 2.15, "%s y=%.2fm" % [hm_dbg, player.global_position.y])

	# --- 5. Ledge Hang, Shimmy & 180° Jump-Off ---
	await _reset_player(player, Vector3(-15.3, 2.1, -22.0))
	Input.action_press("move_forward")
	Input.action_press("jump")
	for _i in 24:
		await physics_frame
		if player._ledge_hanging:
			break
	var hung := player._ledge_hanging
	Input.action_release("move_forward")
	Input.action_release("jump")
	var x_before_shimmy := player.global_position.x
	Input.action_press("move_right")
	for _i in 22:
		await physics_frame
	Input.action_release("move_right")
	var shimmied := player.global_position.x > x_before_shimmy + 0.25
	var x_after_shimmy := player.global_position.x
	player.rotation.y = PI
	player._yaw = PI
	await _tap_action("jump")
	var jumped_off := not player._ledge_hanging and player.velocity.z > 3.0 and player.velocity.y > 4.0
	_record("Ledge Hang + Shimmy + 180° Jump-Off", hung and shimmied and jumped_off, "hung=%s dx=%.2f jumpoff=%s vz=%.2f vy=%.2f" % [hung, x_after_shimmy - x_before_shimmy, jumped_off, player.velocity.z, player.velocity.y])

	# --- 6. Vertical Front Wall-Run & Lateral Tic-Tac ---
	await _reset_player(player, Vector3(-15.3, 0.0, -21.8))
	Input.action_press("move_forward")
	Input.action_press("sprint")
	for _i in 22:
		await physics_frame
	Input.action_release("sprint")
	Input.action_press("jump")
	var front_wr_started := false
	var wr_start_y := player.global_position.y
	var wr_peak_y := wr_start_y
	for _i in 45:
		await physics_frame
		if player._wall_running and player._wall_run_up:
			front_wr_started = true
		wr_peak_y = maxf(wr_peak_y, player.global_position.y)
	_release_all()
	var front_gain := wr_peak_y - wr_start_y
	player.telemetry.record_metric("wall_run_gain_y", front_gain)
	_record("Vertical Front Wall-Run", front_wr_started and front_gain >= 1.2, "started=%s gain=%.2fm" % [front_wr_started, front_gain])

	await _reset_player(player, Vector3(-13.9, 1.5, -7.5))
	player.velocity = Vector3(0.0, 0.8, -6.0)
	var wr1 := player._try_start_wall_run(Vector2(0.0, -1.0))
	if wr1:
		player._perform_wall_jump()
	var wj1 := player._wall_jumps_used == 1
	for _i in 65:
		await physics_frame
		if not player._wall_running and player._try_start_wall_run(Vector2(0.0, -1.0)):
			player._perform_wall_jump()
			break
	var wj2 := player._wall_jumps_used == 2
	_record("Lateral Tic-Tac 2x Wall-Jump", wr1 and wj1 and wj2, "wr1=%s wj1=%s wj2=%s" % [wr1, wj1, wj2])

	# --- 7. Fall Damage, 360° Landing Roll & Soft Amortizer ---
	await _reset_player(player, Vector3(0.0, 8.0, 32.0))
	player._was_airborne = true
	player._air_peak_y = 8.0
	for _i in 90:
		await physics_frame
		if player.is_on_floor():
			break
	var hp_after_hard_fall := player.hp
	_record("Fall > 6.5m deals damage", hp_after_hard_fall < 100.0, "hp=%.1f" % hp_after_hard_fall)

	await _reset_player(player, Vector3(0.0, 8.0, 32.0))
	player._was_airborne = true
	player._air_peak_y = 8.0
	for _i in 90:
		await physics_frame
		if player.global_position.y < 3.0:
			Input.action_press("crouch")
		if player.is_on_floor():
			break
	var roll_hp := player.hp
	var rolled := player._landing_roll_timer > 0.0
	Input.action_release("crouch")
	_record("360° Landing Roll (0 fall damage)", is_equal_approx(roll_hp, 100.0) and rolled, "hp=%.1f rolled=%s" % [roll_hp, rolled])

	await _reset_player(player, Vector3(12.0, 7.6, -10.0))
	player._was_airborne = true
	player._air_peak_y = 7.6
	for _i in 90:
		await physics_frame
		if player.is_on_floor():
			break
	_record("Soft Amortizer landing (0 dmg + FOV dip)", is_equal_approx(player.hp, 100.0) and player._amortizer_fov_timer > 0.0, "hp=%.1f fov_t=%.2f" % [player.hp, player._amortizer_fov_timer])

	# --- 8. Slide, Dodge, Tackle & Grapple ---
	var z_slide := Zombie.new()
	z_slide.configure(false, false)
	world.add_child(z_slide)
	await _reset_player(player, Vector3(0.0, 0.0, 34.0))
	z_slide.global_position = Vector3(0.0, 0.0, 29.2)
	z_slide.velocity = Vector3.ZERO
	Input.action_press("move_forward")
	Input.action_press("sprint")
	for _i in 36:
		await physics_frame
	Input.action_release("sprint")
	await _tap_action("crouch")
	var slide_peak := 0.0
	for _i in 30:
		await physics_frame
		slide_peak = maxf(slide_peak, Vector2(player.velocity.x, player.velocity.z).length())
	Input.action_release("move_forward")
	player.telemetry.record_metric("slide_peak", slide_peak)
	_record("Slide knockdown", z_slide.is_downed(), "peak=%.2f downed=%s" % [slide_peak, z_slide.is_downed()])
	z_slide.queue_free()

	await _reset_player(player, Vector3(0.0, 0.0, 32.0))
	Input.action_press("move_left")
	await _tap_action("dodge")
	var dodge_peak := Vector2(player.velocity.x, player.velocity.z).length()
	Input.action_release("move_left")
	player.telemetry.record_metric("dodge_speed", dodge_peak)

	var z_tack := Zombie.new()
	z_tack.configure(true, false)
	world.add_child(z_tack)
	await _reset_player(player, Vector3(0.0, 0.0, 32.0))
	z_tack.global_position = Vector3(0.0, 0.0, 29.5)
	Input.action_press("sprint")
	await _tap_action("secondary_action")
	var tackle_spd := 0.0
	for _i in 22:
		await physics_frame
		tackle_spd = maxf(tackle_spd, Vector2(player.velocity.x, player.velocity.z).length())
	Input.action_release("sprint")
	_record("Tackle (+6.0 m/s + knockdown)", tackle_spd >= 9.0 and z_tack.is_downed(), "spd=%.2f downed=%s" % [tackle_spd, z_tack.is_downed()])
	z_tack.queue_free()

	await _reset_player(player, Vector3(12.0, 0.0, -2.0), 0.0, 0.42)
	var rope_before := player.rope_energy
	await _tap_action("grapple")
	var grappled := player._grappling and player.rope_energy < rope_before
	for _i in 30:
		await physics_frame
	var zipped := player.global_position.z < -6.0
	_record("Grappling Hook (25m + rope_energy + zip)", grappled and zipped, "grappled=%s z=%.2f rope=%.2f" % [grappled, player.global_position.z, player.rope_energy])

	# --- 9. Combat Kit ---
	var z_c := Zombie.new()
	z_c.configure(true, false)
	world.add_child(z_c)
	await _reset_player(player, Vector3(0.0, 0.0, 32.0))
	z_c.global_position = Vector3(0.22, 0.0, 30.4) # Off-center for 5-ray arc
	z_c.velocity = Vector3.ZERO
	var hp_arc := z_c.hp
	player._melee_swing(false)
	for _i in 14:
		await physics_frame
	_record("Swept 5-ray melee arc hits off-center", z_c.hp < hp_arc, "hp %.1f->%.1f" % [hp_arc, z_c.hp])

	await _reset_player(player, Vector3(0.0, 0.0, 32.0))
	z_c.hp = 100.0
	z_c.max_hp = 100.0
	z_c.stagger_timer = 0.0
	z_c.global_position = Vector3(0.0, 0.0, 30.5)
	player._melee_swing(false)
	for _i in 14:
		await physics_frame
	_record("2.0x Headshot Crit", is_equal_approx(100.0 - z_c.hp, 48.0), "dmg=%.1f" % (100.0 - z_c.hp))

	await _reset_player(player, Vector3(0.0, 0.0, 32.0))
	player.stamina = 0.0
	player.exhausted = true
	z_c.hp = 100.0
	z_c.stagger_timer = 0.0
	z_c.global_position = Vector3(0.0, 0.0, 30.5)
	player._melee_swing(false)
	var exh_cd := player._attack_cd
	for _i in 22:
		await physics_frame
	_record("Exhausted Swing executes (0.65x dmg)", exh_cd >= 0.90 and z_c.hp < 100.0, "cd=%.2f hp=%.1f" % [exh_cd, z_c.hp])

	await _reset_player(player, Vector3(0.0, 0.8, 32.0))
	z_c.hp = 100.0
	z_c.stagger_timer = 0.0
	z_c.downed_timer = 0.0
	z_c.global_position = Vector3(0.0, 0.0, 30.2)
	Input.action_press("move_forward")
	await _tap_action("kick")
	var dk_started := player._dropkicking
	for _i in 15:
		await physics_frame
	Input.action_release("move_forward")
	_record("Dropkick (40 dmg + knockdown)", dk_started and z_c.hp <= 60.0 and z_c.is_downed(), "hp=%.1f downed=%s" % [z_c.hp, z_c.is_downed()])

	await _reset_player(player, Vector3(0.0, 3.0, 32.0), 0.0, -0.7)
	z_c.hp = 100.0
	z_c.downed_timer = 0.0
	z_c.stagger_timer = 0.0
	z_c.global_position = Vector3(1.5, 0.0, 32.0)
	await _tap_action("primary_action")
	var gp_started := player._ground_pounding
	for _i in 30:
		await physics_frame
		if player.is_on_floor():
			break
	_record("Ground Pound (3.0m shockwave)", gp_started and z_c.hp <= 68.0 and z_c.is_downed(), "hp=%.1f downed=%s" % [z_c.hp, z_c.is_downed()])

	await _reset_player(player, Vector3(0.0, 0.0, 32.0))
	z_c.hp = 100.0
	z_c.knockback_vel = Vector3.ZERO
	z_c.global_position = player.global_position + Vector3(0.0, 0.0, -1.0)
	z_c.apply_knockdown(3.0)
	await _tap_action("kick")
	_record("Head Stomp finishes downed zombie (120 dmg)", z_c.hp <= 0.0, "hp=%.1f" % z_c.hp)
	z_c.queue_free()

	# --- 10. Zombie Grab & Fast Break + Quick Lookback + Telemetry Dump ---
	var z_g := Zombie.new()
	z_g.configure(true, false)
	world.add_child(z_g)
	await _reset_player(player, Vector3(0.0, 0.0, 32.0))
	z_g.global_position = Vector3(0.0, 0.0, 31.0)
	player.start_zombie_grab(z_g)
	var grabbed_ok := player._grabbed_by == z_g
	await physics_frame
	await process_frame
	grabbed_ok = grabbed_ok and player.move_state == "GRABBED"
	for act in ["jump", "interact", "move_left"]:
		await _tap_action(act)
	var broke_free := player._grabbed_by == null and z_g.stagger_timer >= 2.5
	_record("Zombie Grab & Fast Break (3.0s stun)", grabbed_ok and broke_free, "grabbed=%s broke=%s stun=%.2f" % [grabbed_ok, broke_free, z_g.stagger_timer])
	z_g.queue_free()

	await _reset_player(player, Vector3(0.0, 0.0, 34.0))
	Input.action_press("move_forward")
	Input.action_press("sprint")
	Input.action_press("lookback")
	for _i in 44:
		await physics_frame
	var lb_yaw := player._head.rotation.y
	var lb_vz := player.velocity.z
	_release_all()
	_record("Quick Lookback (B) rotates 180° + keeps sprint", lb_yaw > 2.6 and lb_vz < -4.5, "head_y=%.2f vz=%.2f" % [lb_yaw, lb_vz])

	var dumped := player.telemetry.dump_json("user://dl_parity_trace.json")
	_record("Telemetry JSON dump", dumped and FileAccess.file_exists("user://dl_parity_trace.json"), "dumped=%s" % dumped)

	# --- 11. Stage B Reverse-Engineered Binary Contracts (gamedll_x64_rwdi.dll) ---
	# 11a. WeaponMeleeController (0x00cfe531) continuous ±60° multi-target arc sweep
	await _reset_player(player, Vector3(0.0, 0.0, 32.0))
	var z_sw1 := Zombie.new()
	z_sw1.configure(true, false)
	z_sw1.position = Vector3(-0.75, 0.0, 30.6)
	world.add_child(z_sw1)
	var z_sw2 := Zombie.new()
	z_sw2.configure(true, false)
	z_sw2.position = Vector3(0.75, 0.0, 30.6)
	world.add_child(z_sw2)
	z_sw1._attack_timer = 2.0
	z_sw2._attack_timer = 2.0
	await physics_frame
	var sw1_hp0 := z_sw1.hp
	var sw2_hp0 := z_sw2.hp
	player._melee_swing(false)
	for _i in 15:
		await physics_frame
	var sweep_hits := int(player.telemetry.get_binary_event("last_melee_sweep_hits", 0))
	_record("Binary: ±60° Multi-Target Melee Sweep", z_sw1.hp < sw1_hp0 and z_sw2.hp < sw2_hp0 and sweep_hits >= 2, "hits=%d hp1=%.1f hp2=%.1f" % [sweep_hits, z_sw1.hp, z_sw2.hp])
	z_sw1.queue_free()
	z_sw2.queue_free()

	# 11b. PlayerFitnessModule (0x00ce1521, 0x00d4979c) curve & >0.06 sprint gate & 0.75x regen modifier
	var fit_curve_ok := is_equal_approx(DLReference.compute_fitness_speed_factor(0.20), 0.80) and is_equal_approx(DLReference.compute_fitness_speed_factor(0.35), 0.90) and is_equal_approx(DLReference.compute_fitness_speed_factor(0.50), 1.00)
	var fit_gate_ok := not DLReference.can_sprint_with_fitness(0.05, false) and DLReference.can_sprint_with_fitness(0.07, false) and not DLReference.can_sprint_with_fitness(0.50, true)
	var fit_regen_ok := is_equal_approx(DLReference.FITNESS_MOVE_CROUCH_REGEN_MUL, 0.75)
	_record("Binary: PlayerFitnessModule curve & >0.06 gate", fit_curve_ok and fit_gate_ok and fit_regen_ok, "curve=%s gate=%s regen0.75=%s" % [fit_curve_ok, fit_gate_ok, fit_regen_ok])

	# 11c. MoveController Slope Slide-Down (0x00d50c90) & PlayerDuckModule 0.30m x 1.50m capsule (0x00cde585)
	var slope_ok := is_equal_approx(DLReference.compute_slope_slide_factor(0.0), 0.01) and is_equal_approx(DLReference.compute_slope_slide_factor(45.0), 0.80) and is_equal_approx(DLReference.compute_slope_slide_factor(20.0), 20.0 * 0.0175556 + 0.01)
	var duck_ok := is_equal_approx(DLReference.DUCK_CAPSULE_RADIUS, 0.30) and is_equal_approx(DLReference.DUCK_CAPSULE_HEIGHT, 1.50)
	_record("Binary: Slope SlideDown & 0.30x1.50m DuckCapsule", slope_ok and duck_ok, "slope=%s duck=%s" % [slope_ok, duck_ok])

	# 11d. NaturalMovementController (0x00d5733c) 3-band probes (0.85m / 1.35m / 1.65m)
	await _reset_player(player, Vector3(-7.5, 0.0, 0.15))
	var band_low := int(player._probe_nm_three_bands(Vector3(0.0, 0.0, -1.0))["highest_band"])
	await _reset_player(player, Vector3(-8.5, 0.0, -4.2))
	var band_high := int(player._probe_nm_three_bands(Vector3(0.0, 0.0, -1.0))["highest_band"])
	_record("Binary: 3-Band NM Probes (0.85/1.35/1.65m)", band_low == 1 and band_high == 3, "low_box_band=%d high_box_band=%d" % [band_low, band_high])

	# 11e. EdgeGrabController (0x00d084f6..0x00d104f0): 0.2158m offset, 0.40m shimmy, ±75°/±62° clamps, 4.5 m/s leap
	player._ledge_hanging = true
	player._ledge_attach_yaw = 0.0
	player._shimmy_dir = 0
	var clamped_hang_deg := rad_to_deg(absf(player.clamp_ledge_look_yaw(2.2)))
	player._shimmy_dir = 1
	var clamped_shimmy_deg := rad_to_deg(absf(player.clamp_ledge_look_yaw(2.2)))
	player._ledge_hanging = false
	var leap_v := DLReference.compute_edge_leap_velocity(Vector3.ZERO, Vector3(0.0, 1.0, -4.5))
	var leap_h_spd := Vector2(leap_v.x, leap_v.z).length()
	var edge_ok := is_equal_approx(DLReference.EDGE_HAND_GRIP_OFFSET, 0.2158) and is_equal_approx(DLReference.EDGE_SHIMMY_STEP, 0.40) and is_equal_approx(clamped_hang_deg, 75.0) and is_equal_approx(clamped_shimmy_deg, 62.0) and is_equal_approx(leap_h_spd, 4.5)
	_record("Binary: EdgeGrab 0.2158m / ±75° & ±62° / 4.5m/s", edge_ok, "hang=%.1f° shimmy=%.1f° leap_vh=%.2f" % [clamped_hang_deg, clamped_shimmy_deg, leap_h_spd])

	# 11f. 4-Phase Slide (0x00cfbf50: SlideBegin -> SlideLoop/SlideLoopRight -> SlideKick -> SlideEnd)
	await _reset_player(player, Vector3(0.0, 0.0, 34.0))
	Input.action_press("move_forward")
	Input.action_press("sprint")
	for _i in 36:
		await physics_frame
	Input.action_release("sprint")
	await _tap_action("crouch")
	var ph_begin := player.get_slide_phase()
	player._yaw += deg_to_rad(8.0)
	for _i in 24:
		await physics_frame
	var ph_loop_r := player.get_slide_phase()
	player._trigger_slide_kick()
	var ph_kick := player.get_slide_phase()
	Input.action_release("move_forward")
	_record("Binary: 4-Phase Slide & SlideLoopRight (>5°)", ph_begin == "SlideBegin" and ph_loop_r == "SlideLoopRight" and ph_kick == "SlideKick", "begin=%s loop=%s kick=%s" % [ph_begin, ph_loop_r, ph_kick])

	# 11g. LandingController (0x00d3e890, 0x00d3e9b6) 6 tiers (0..5) & >5.0m shockwave threshold
	var tiers_ok := DLReference.classify_landing_tier(0.5, false, false) == 0 and DLReference.classify_landing_tier(7.0, true, false) == 1 and DLReference.classify_landing_tier(2.2, false, false) == 2 and DLReference.classify_landing_tier(4.5, false, false) == 3 and DLReference.classify_landing_tier(7.5, false, true) == 4 and DLReference.classify_landing_tier(10.0, false, false) == 5
	player.hp = 100.0
	player._resolve_landing(4.0)
	var sw_light := String(player.telemetry.get_binary_event("last_landing_shockwave", ""))
	player._crouch_damping_timer = 0.8
	player._resolve_landing(7.5)
	var sw_heavy := String(player.telemetry.get_binary_event("last_landing_shockwave", ""))
	player.hp = 100.0
	_record("Binary: LandingController 6 tiers & shockwave", tiers_ok and sw_light == "Melee_LightLandingShockwave" and sw_heavy == "Melee_HeavyLandingShockwave", "tiers=%s light=%s heavy=%s" % [tiers_ok, sw_light, sw_heavy])

	# 11h. EyeCamera Bone Coupling (0x00d06050) & LookParams("Normal") [-89°, +70°] & Cosine Slew (0x00d43a14)
	var eye_ok := player._eye_camera_bone_idx != -1 and bool(player.telemetry.get_binary_event("eye_camera_coupled", false))
	var look_ok := is_equal_approx(DLReference.LOOK_PITCH_MIN_DEG, -89.0) and is_equal_approx(DLReference.LOOK_PITCH_MAX_DEG, 70.0) and is_equal_approx(DLReference.compute_look_cosine_slew(1.0), 0.50)
	_record("Binary: EyeCamera bone + LookParams [-89°,+70°]", eye_ok and look_ok, "eye_idx=%d look_ok=%s" % [player._eye_camera_bone_idx, look_ok])

	# --- Evaluate DLReference Parity Scorecard ---
	print("\n================ DYING LIGHT 1 PARITY SCORECARD ================")
	var rows := player.telemetry.get_comparison_rows()
	for row in rows:
		var status := String(row["status"])
		var act_str := "--" if status == "N/A" else ("%.3f" % float(row["actual"]))
		print("%-14s | SPEC: %6.3f +/- %4.2f %-4s | ACTUAL: %7s | [%s]" % [
			String(row["label"]),
			float(row["spec"]),
			float(row["tol"]),
			String(row["unit"]),
			act_str,
			status,
		])
		if status != "PASS":
			_failed = true

	print("---------------- FUNCTIONAL PARITY CHECKS ----------------------")
	for chk in _checks:
		var tag := "PASS" if bool(chk["ok"]) else "FAIL"
		print("[%s] %-42s (%s)" % [tag, String(chk["label"]), String(chk["detail"])])
	print("================================================================\n")

	world.queue_free()
	await process_frame

	if _failed:
		quit(1)
	else:
		print("DL1 PARITY PASSED")
		quit(0)
