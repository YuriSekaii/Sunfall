extends Node

var _world: Node3D
var _player: Player
var _out_dir: String = ""
var _meta: Array[Dictionary] = []
var _test_cam: Camera3D


func setup(world: Node3D, player: Player, out_dir: String) -> void:
	_world = world
	_player = player
	_out_dir = out_dir


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(_out_dir)
	if is_instance_valid(_player):
		_player.allow_headless_mouse_look_for_test = true
	if _world.has_method("_set_mouse_captured"):
		_world.call("_set_mouse_captured", false)
	if _world.get("_telemetry_panel") != null:
		(_world.get("_telemetry_panel") as Control).visible = false
	call_deferred("_run_all_scenarios")


func _release_all_inputs() -> void:
	for act in [
		"move_forward", "move_back", "move_left", "move_right",
		"jump", "sprint", "crouch", "dodge", "kick",
		"primary_action", "secondary_action", "interact", "grapple", "lookback",
	]:
		if Input.is_action_pressed(act):
			Input.action_release(act)


func _clear_all_zombies() -> void:
	if get_tree() == null:
		return
	for node in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(node):
			node.queue_free()


func _reset_player(pos: Vector3, yaw_deg: float = 0.0, pitch_deg: float = 0.0) -> void:
	_release_all_inputs()
	_player.global_position = pos
	_player.velocity = Vector3.ZERO
	_player._yaw = deg_to_rad(yaw_deg)
	_player._pitch = deg_to_rad(pitch_deg)
	_player.rotation.y = _player._yaw
	_player._head.rotation.x = _player._pitch
	_player._head.rotation.y = 0.0
	_player.fitness = 1.0
	_player.sprint_exhausted = false
	_player.stamina = 1.0
	_player.exhausted = false
	_player.hp = _player.max_hp
	_player._is_crouching = false
	_player._slide_timer = 0.0
	_player._slide_cd = 0.0
	_player._vaulting = false
	_player._ledge_hanging = false
	_player._wall_running = false
	_player._dropkicking = false
	_player._ground_pounding = false
	_player._dodge_timer = 0.0
	_player._dodge_cd = 0.0
	_player._tackle_timer = 0.0
	_player._grappling = false
	_player._grabbed_by = null
	_player._grab_immunity = 999.0
	_player._attack_cd = 0.0
	_player._kick_cd = 0.0
	_player._fpp_action_lock_timer = 0.0
	_player.active_slot = 1
	_player._refresh_viewmodel()


func _step_frames(n: int) -> void:
	for _i in n:
		await get_tree().physics_frame


func _capture(scenario: String, idx: int, label: String, extra: Dictionary = {}) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var fname := "%s_%02d_%s.png" % [scenario, idx, label]
	img.save_png(_out_dir.path_join(fname))
	var entry := {
		"file": fname,
		"scenario": scenario,
		"idx": idx,
		"label": label,
		"t_ms": int(round(_player._elapsed_time * 1000.0)),
		"move_state": _player.move_state,
		"speed": snappedf(Vector2(_player.velocity.x, _player.velocity.z).length(), 0.01),
		"vel_y": snappedf(_player.velocity.y, 0.01),
		"fov": snappedf(_player._camera.fov, 0.1),
		"fpp_anim": _player._current_fpp_anim,
		"pitch_deg": snappedf(rad_to_deg(_player._pitch), 0.1),
		"pos": [snappedf(_player.global_position.x, 0.02), snappedf(_player.global_position.y, 0.02), snappedf(_player.global_position.z, 0.02)],
	}
	for k in extra.keys():
		entry[k] = extra[k]
	_meta.append(entry)


func _capture_burst(scenario: String, start_idx: int, label_prefix: String, count: int, interval_frames: int = 2, target_zombie: Zombie = null) -> int:
	var idx := start_idx
	for i in count:
		var extra: Dictionary = {}
		if is_instance_valid(target_zombie):
			extra["zombie_hp"] = snappedf(target_zombie.hp, 0.1)
			extra["downed"] = target_zombie.is_downed()
		await _capture(scenario, idx, "%s_%02d" % [label_prefix, i + 1], extra)
		idx += 1
		if i < count - 1:
			await _step_frames(interval_frames)
	return idx


func _spawn_test_zombie(pos: Vector3, face_pos: Vector3, is_brute: bool = false) -> Zombie:
	var z := Zombie.new()
	z.configure(false, is_brute, false)
	_world.add_child(z)
	z.global_position = pos
	var d := Vector3(face_pos.x - pos.x, 0.0, face_pos.z - pos.z)
	if d.length() > 0.05:
		z.rotation.y = atan2(-d.x, -d.z)
	return z


func _run_all_scenarios() -> void:
	await _step_frames(6)
	_clear_all_zombies()
	await _step_frames(2)

	# 01_fpp_framing: level, up, steep down, crouch
	_reset_player(Vector3(0.0, 0.05, 8.0), 0.0, 0.0)
	await _step_frames(4)
	await _capture("01_fpp_framing", 1, "idle_level")
	_player._pitch = deg_to_rad(40.0)
	_player._head.rotation.x = _player._pitch
	await _step_frames(3)
	await _capture("01_fpp_framing", 2, "look_up_40")
	_player._pitch = deg_to_rad(-65.0)
	_player._head.rotation.x = _player._pitch
	await _step_frames(3)
	await _capture("01_fpp_framing", 3, "look_down_65")
	_player._pitch = deg_to_rad(-88.0)
	_player._head.rotation.x = _player._pitch
	await _step_frames(3)
	await _capture("01_fpp_framing", 4, "look_down_88")
	_player._pitch = 0.0
	_player._head.rotation.x = 0.0
	Input.action_press("crouch")
	await _step_frames(8)
	await _capture("01_fpp_framing", 5, "crouch_level")
	_player._pitch = deg_to_rad(-55.0)
	_player._head.rotation.x = _player._pitch
	await _step_frames(4)
	await _capture("01_fpp_framing", 6, "crouch_down_55")
	_release_all_inputs()

	# 02_sprint_jump: 12-frame 30 FPS burst (sprint -> jump -> apex -> land -> sprint)
	_clear_all_zombies()
	_reset_player(Vector3(0.0, 0.05, 12.0), 0.0, -4.0)
	Input.action_press("sprint")
	Input.action_press("move_forward")
	await _step_frames(28)
	var s2 := await _capture_burst("02_sprint_jump", 1, "sprint", 2, 2)
	Input.action_press("jump")
	await _step_frames(2)
	Input.action_release("jump")
	await _capture_burst("02_sprint_jump", s2, "jump", 10, 3)
	_release_all_inputs()

	# 03_vault_climb: 12-frame 30 FPS burst of Sprint -> Low Vault over 1.2m box (-7.5, 0.6, -2.0)
	_clear_all_zombies()
	_reset_player(Vector3(-7.5, 0.05, 2.2), 0.0, -6.0)
	Input.action_press("sprint")
	Input.action_press("move_forward")
	await _step_frames(22)
	var s3 := await _capture_burst("03_vault_climb", 1, "app", 2, 2)
	Input.action_press("jump")
	await _step_frames(2)
	Input.action_release("jump")
	await _capture_burst("03_vault_climb", s3, "vault", 10, 2)
	_release_all_inputs()

	# 03b_high_mantle: 12-frame 30 FPS burst of Jump -> High Ledge Grab -> Climb Mantle (-8.5, 1.1, -6.5)
	_reset_player(Vector3(-8.5, 0.05, -2.8), 0.0, 10.0)
	Input.action_press("sprint")
	Input.action_press("move_forward")
	await _step_frames(18)
	Input.action_press("jump")
	var s3b := await _capture_burst("03b_high_mantle", 1, "catch", 6, 3)
	Input.action_release("jump")
	await _step_frames(2)
	Input.action_press("jump")
	await _step_frames(2)
	Input.action_release("jump")
	await _capture_burst("03b_high_mantle", s3b, "climb", 6, 3)
	_release_all_inputs()

	# 04_slide_dodge: 12-frame 30 FPS burst of Sprint -> SlideBegin -> SlideLoop -> SlideEnd
	_clear_all_zombies()
	_reset_player(Vector3(0.0, 0.05, 12.0), 0.0, -5.0)
	Input.action_press("sprint")
	Input.action_press("move_forward")
	await _step_frames(38)
	Input.action_press("crouch")
	await _capture_burst("04_slide_dodge", 1, "slide", 12, 3)
	_release_all_inputs()

	# 04b_dodge: 8-frame 30 FPS burst of Dodge Left
	_reset_player(Vector3(0.0, 0.05, 8.0), 0.0, -4.0)
	await _step_frames(4)
	Input.action_press("move_left")
	Input.action_press("dodge")
	await _capture_burst("04b_dodge", 1, "dodge_l", 8, 2)
	_release_all_inputs()

	# 05_melee_combat: 12-frame 30 FPS burst of Light RL -> Light LR on Zombie
	_clear_all_zombies()
	_reset_player(Vector3(0.0, 0.05, 6.0), 0.0, -6.0)
	var z_melee := _spawn_test_zombie(Vector3(0.0, 0.05, 4.2), Vector3(0.0, 0.05, 6.0), false)
	z_melee.hp = 200.0
	z_melee.max_hp = 200.0
	await _step_frames(4)
	Input.action_press("primary_action")
	await _step_frames(2)
	Input.action_release("primary_action")
	var s5 := await _capture_burst("05_melee_combat", 1, "rl", 6, 3, z_melee)
	await _step_frames(18)
	z_melee.global_position = Vector3(0.0, 0.05, 4.2)
	Input.action_press("primary_action")
	await _step_frames(2)
	Input.action_release("primary_action")
	await _capture_burst("05_melee_combat", s5, "lr", 6, 3, z_melee)
	_clear_all_zombies()

	# 06_kick_dropkick_stomp: 12-frame 30 FPS burst of Kick + Dropkick + Stomp
	_reset_player(Vector3(0.0, 0.05, 6.0), 0.0, -6.0)
	var z_kick := _spawn_test_zombie(Vector3(0.0, 0.05, 4.3), Vector3(0.0, 0.05, 6.0), false)
	z_kick.hp = 200.0
	z_kick.max_hp = 200.0
	await _step_frames(4)
	Input.action_press("kick")
	await _step_frames(2)
	Input.action_release("kick")
	var s6 := await _capture_burst("06_kick_dropkick_stomp", 1, "kick", 4, 3, z_kick)
	_reset_player(Vector3(0.0, 0.05, 8.8), 0.0, -5.0)
	z_kick.global_position = Vector3(0.0, 0.05, 4.3)
	z_kick.stagger_timer = 0.0
	Input.action_press("sprint")
	Input.action_press("move_forward")
	await _step_frames(24)
	Input.action_press("jump")
	await _step_frames(3)
	Input.action_release("jump")
	Input.action_press("kick")
	await _step_frames(2)
	Input.action_release("kick")
	s6 = await _capture_burst("06_kick_dropkick_stomp", s6, "dropkick", 5, 3, z_kick)
	_release_all_inputs()
	z_kick.apply_knockdown(3.0)
	_reset_player(z_kick.global_position + Vector3(0.0, 0.0, 1.3), 0.0, -35.0)
	await _step_frames(4)
	Input.action_press("kick")
	await _step_frames(2)
	Input.action_release("kick")
	await _capture_burst("06_kick_dropkick_stomp", s6, "stomp", 3, 4, z_kick)
	_clear_all_zombies()

	# 07_third_person_sanity: 4 side/front frames
	_reset_player(Vector3(0.0, 0.05, 6.0), 0.0, 0.0)
	var z_tp := _spawn_test_zombie(Vector3(0.3, 0.05, 4.2), Vector3(0.0, 0.05, 6.0), false)
	_test_cam = Camera3D.new()
	_test_cam.fov = 65.0
	_world.add_child(_test_cam)
	_test_cam.current = true
	_test_cam.global_position = Vector3(2.2, 1.35, 6.8)
	_test_cam.look_at(Vector3(0.1, 1.0, 5.2), Vector3.UP)
	await _step_frames(6)
	await _capture("07_third_person_sanity", 1, "side_idle", {"zombie_hp": snappedf(z_tp.hp, 0.1)})
	Input.action_press("primary_action")
	await _step_frames(2)
	Input.action_release("primary_action")
	await _step_frames(8)
	await _capture("07_third_person_sanity", 2, "side_melee", {"zombie_hp": snappedf(z_tp.hp, 0.1)})
	_test_cam.global_position = Vector3(-1.8, 1.45, 4.9)
	_test_cam.look_at(Vector3(0.0, 1.0, 6.0), Vector3.UP)
	await _step_frames(4)
	await _capture("07_third_person_sanity", 3, "front_fpp_rig")
	if is_instance_valid(_player._weapon_socket):
		var ws_p := _player._weapon_socket.global_position
		_test_cam.global_position = ws_p + Vector3(-0.32, 0.16, -0.34)
		_test_cam.look_at(ws_p + Vector3(0.0, 0.04, -0.02), Vector3.UP)
		await _step_frames(3)
		await _capture("07_third_person_sanity", 4, "hand_grip_closeup")
	Input.action_press("sprint")
	Input.action_press("move_forward")
	await _step_frames(24)
	Input.action_press("crouch")
	_test_cam.global_position = _player.global_position + Vector3(2.1, 0.85, 0.2)
	_test_cam.look_at(_player.global_position + Vector3(0.0, 0.55, -0.4), Vector3.UP)
	await _step_frames(5)
	await _capture("07_third_person_sanity", 5, "side_slide")
	_release_all_inputs()

	_test_cam.current = false
	_player._camera.current = true
	_test_cam.queue_free()
	_clear_all_zombies()

	var f := FileAccess.open(_out_dir.path_join("capture_meta.json"), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_meta, "\t"))
		f.close()

	print("VISUAL_HARNESS_DONE frames=%d out=%s" % [_meta.size(), _out_dir])
	get_tree().quit(0)
