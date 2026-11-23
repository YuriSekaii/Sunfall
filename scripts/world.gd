extends Node3D

const DAY_DURATION := 90.0
const NIGHT_DURATION := 60.0
const MAX_DAYS := 10

@export var run_seed: int = 0

var day: int = 1
var is_night: bool = false
var phase_timer: float = DAY_DURATION
var game_over: bool = false
var victory: bool = false
var paused: bool = false

var horde_to_spawn: int = 0
var horde_max_alive: int = 8
var _spawn_tick: float = 0.0
var _outdoors_tick: float = 1.0
var _next_container_id: int = 1

var _player: Player
var _sun: DirectionalLight3D
var _world_env: WorldEnvironment
var _sky_mat: ProceduralSkyMaterial
var _crash_fire: OmniLight3D

# HUD nodes
var _phase_label: Label
var _timer_label: Label
var _seed_label: Label
var _hp_bar: ProgressBar
var _fitness_bar: ProgressBar
var _stam_bar: ProgressBar
var _grapple_bar: ProgressBar
var _hunger_bar: ProgressBar
var _thirst_bar: ProgressBar
var _telemetry_panel: PanelContainer
var _telemetry_label: Label
var _hotbar_label: Label
var _inv_label: Label
var _prompt_label: Label
var _search_bar: ProgressBar
var _log_label: Label
var _overlay_panel: PanelContainer
var _overlay_title: Label
var _overlay_body: Label
var _resume_btn: Button
var _check_updates_btn: Button
var _restart_btn: Button
var _quit_btn: Button
var _update_section: VBoxContainer
var _build_label: Label
var _update_status_label: Label
var _changelog_label: Label
var _pull_btn: Button
var _force_pull_btn: Button
var _restart_after_update_btn: Button
var _force_armed: bool = false
var _damage_flash_rect: ColorRect
var _damage_left_rect: ColorRect
var _damage_right_rect: ColorRect
var _inv_counts: Dictionary = {}
var _slot_icons: Array[TextureRect] = []
var _night_ambient_player: AudioStreamPlayer
var _night_music_player: AudioStreamPlayer
var _log_lines: PackedStringArray = []


func _enter_tree() -> void:
	_register_inputs()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if run_seed == 0:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		run_seed = rng.randi_range(10000, 99999)

	_build_environment()
	_build_island()
	_spawn_player()
	_build_hud()
	_build_ambient_audio()
	_maintain_outdoor_zombies()
	_push_log("Plane crashed! Gather loot before sundown (Day 1/10).")
	var cap_dir := ""
	var playtest_port := 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--visual-capture="):
			cap_dir = arg.substr("--visual-capture=".length())
		elif arg.begins_with("--playtest-port="):
			playtest_port = int(arg.substr("--playtest-port=".length()))
	if playtest_port > 0:
		var bridge_script := load("res://scripts/debug/playtest_bridge.gd") as GDScript
		var bridge: Node = bridge_script.new()
		bridge.name = "PlaytestBridge"
		bridge.call("setup", self, _player, playtest_port)
		add_child(bridge)
	elif not cap_dir.is_empty():
		var harness_script := load("res://tests/live_visual_harness.gd") as GDScript
		var harness: Node = harness_script.new()
		harness.call("setup", self, _player, cap_dir)
		add_child(harness)
	else:
		call_deferred("_set_mouse_captured", true)


func _register_inputs() -> void:
	var key_map := {
		"move_forward": [KEY_W],
		"move_back": [KEY_S],
		"move_left": [KEY_A],
		"move_right": [KEY_D],
		"jump": [KEY_SPACE],
		"sprint": [KEY_SHIFT],
		"crouch": [KEY_CTRL, KEY_C],
		"dodge": [KEY_ALT],
		"kick": [KEY_Q],
		"interact": [KEY_E],
		"survivor_sense": [KEY_V],
		"grapple": [KEY_X],
		"lookback": [KEY_B],
		"debug_telemetry": [KEY_F3],
		"dump_telemetry": [KEY_F4],
		"flashlight": [KEY_F],
		"slot_1": [KEY_1],
		"slot_2": [KEY_2],
		"slot_3": [KEY_3],
		"use_heal": [KEY_H],
		"use_food": [KEY_G],
		"skip_phase": [KEY_T],
		"restart_run": [KEY_R],
	}
	for action in key_map.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			for kc in key_map[action]:
				var ev := InputEventKey.new()
				ev.keycode = kc
				InputMap.action_add_event(action, ev)

	var mouse_map := {
		"primary_action": MOUSE_BUTTON_LEFT,
		"secondary_action": MOUSE_BUTTON_RIGHT,
	}
	for action in mouse_map.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var ev := InputEventMouseButton.new()
			ev.button_index = mouse_map[action]
			InputMap.action_add_event(action, ev)

	var mmb := InputEventMouseButton.new()
	mmb.button_index = MOUSE_BUTTON_MIDDLE
	if InputMap.has_action("grapple"):
		InputMap.action_add_event("grapple", mmb)


func _set_mouse_captured(captured: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		if not paused and not game_over and not victory:
			call_deferred("_set_mouse_captured", true)
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_set_mouse_captured(false)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not paused and not game_over and not victory and DisplayServer.get_name() != "headless":
			if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
				_set_mouse_captured(true)
				if is_instance_valid(_player):
					_player.suppress_capture_click()
				get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not game_over and not victory:
		paused = not paused
		get_tree().paused = paused
		_set_mouse_captured(not paused)
		_update_overlay()
	elif Input.is_action_just_pressed("restart_run") and (game_over or victory):
		get_tree().paused = false
		get_tree().reload_current_scene()
	elif Input.is_action_just_pressed("skip_phase") and not game_over and not victory and not paused:
		phase_timer = 0.05
	elif Input.is_action_just_pressed("debug_telemetry") and _telemetry_panel != null:
		_telemetry_panel.visible = not _telemetry_panel.visible
	elif Input.is_action_just_pressed("dump_telemetry") and is_instance_valid(_player):
		if _player.telemetry.dump_json("user://dl_telemetry.json"):
			_push_log("Saved telemetry trace to user://dl_telemetry.json")


func _process(delta: float) -> void:
	if game_over or victory or paused:
		return

	phase_timer -= delta
	if phase_timer <= 0.0:
		_advance_phase()

	if is_night:
		_process_horde_spawner(delta)
	else:
		_outdoors_tick -= delta
		if _outdoors_tick <= 0.0:
			_outdoors_tick = 4.0
			_maintain_outdoor_zombies()

	if _crash_fire != null:
		_crash_fire.light_energy = 2.6 + sin(Time.get_ticks_msec() * 0.015) * 0.45

	_update_lighting(delta)
	_update_hud()


func _advance_phase() -> void:
	if not is_night:
		is_night = true
		phase_timer = NIGHT_DURATION
		horde_to_spawn = 8 + day * 5
		horde_max_alive = mini(6 + day * 2, 22)
		_spawn_tick = 0.5
		Sfx.play(self, "siren", -4.0, 0.9)
		_push_log("NIGHT %d BEGINS! %d infected incoming!" % [day, horde_to_spawn])
	else:
		if day >= MAX_DAYS:
			victory = true
			_set_mouse_captured(false)
			_update_overlay()
			return
		is_night = false
		day += 1
		if is_instance_valid(_player):
			_player.current_day = day
		phase_timer = DAY_DURATION
		horde_to_spawn = 0
		Sfx.play(self, "siren", -6.0, 1.35)
		_push_log("DAWN (Day %d/%d)! Sunlight weakens outdoor infected." % [day, MAX_DAYS])

	for z in get_tree().get_nodes_in_group("enemies"):
		if z is Zombie and is_instance_valid(z):
			(z as Zombie).set_night_state(is_night)
	_update_night_audio()


func start_night_horde_for_test() -> void:
	if not is_night:
		_advance_phase()


func _process_horde_spawner(delta: float) -> void:
	if horde_to_spawn <= 0:
		return
	_spawn_tick -= delta
	if _spawn_tick > 0.0:
		return
	_spawn_tick = 1.6

	var alive := 0
	for z in get_tree().get_nodes_in_group("enemies"):
		if z is Zombie and is_instance_valid(z) and not (z as Zombie).is_bunker_enemy:
			alive += 1
	if alive >= horde_max_alive:
		return

	var angle := randf_range(0.0, TAU)
	var dist := randf_range(24.0, 34.0)
	var pos := Vector3(cos(angle) * dist, 0.2, sin(angle) * dist)
	var is_brute := day >= 2 and randf() < 0.22
	var is_runner := not is_brute and randf() < 0.45
	_spawn_zombie(pos, false, is_brute, is_runner)
	horde_to_spawn -= 1


func _maintain_outdoor_zombies() -> void:
	if is_night:
		return
	var outdoor_count := 0
	for z in get_tree().get_nodes_in_group("enemies"):
		if z is Zombie and is_instance_valid(z) and not (z as Zombie).is_bunker_enemy:
			outdoor_count += 1
	var ref_pos := _player.global_position if is_instance_valid(_player) else Vector3(0.0, 0.4, 8.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed + day * 97 + outdoor_count
	while outdoor_count < 5:
		var spawn_pos := Vector3(-24.0, 0.2, -24.0)
		for _attempt in 24:
			var ang := rng.randf_range(0.0, TAU)
			var d := rng.randf_range(22.0, 38.0)
			var cand := Vector3(cos(ang) * d, 0.2, sin(ang) * d)
			var dist_to_player := Vector2(cand.x - ref_pos.x, cand.z - ref_pos.z).length()
			var in_bunker := cand.x >= 19.0 and cand.x <= 37.0 and absf(cand.z) <= 11.0
			if dist_to_player >= 20.0 and not in_bunker and absf(cand.x) <= 42.0 and absf(cand.z) <= 42.0:
				spawn_pos = cand
				break
		_spawn_zombie(spawn_pos, false, false)
		outdoor_count += 1


func _spawn_zombie(pos: Vector3, bunker: bool, brute: bool, night_runner: bool = false) -> Zombie:
	var z := Zombie.new()
	z.configure(bunker, brute, night_runner)
	add_child(z)
	z.global_position = pos
	z.set_night_state(is_night)
	return z


func _build_environment() -> void:
	_sun = DirectionalLight3D.new()
	_sun.shadow_enabled = true
	_sun.rotation_degrees = Vector3(-52.0, -35.0, 0.0)
	add_child(_sun)

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	_sky_mat = ProceduralSkyMaterial.new()
	sky.sky_material = _sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.65
	env.fog_enabled = true
	env.fog_light_color = Color(0.62, 0.74, 0.82)
	env.fog_density = 0.006

	_world_env = WorldEnvironment.new()
	_world_env.environment = env
	add_child(_world_env)


func _update_lighting(delta: float) -> void:
	var target_sun_e := 0.14 if is_night else 1.45
	var target_sun_col := Color(0.28, 0.36, 0.62) if is_night else Color(1.0, 0.95, 0.84)
	var target_amb := 0.12 if is_night else 0.72
	var target_sky_top := Color(0.03, 0.04, 0.09) if is_night else Color(0.22, 0.52, 0.85)
	var target_sky_hor := Color(0.05, 0.07, 0.12) if is_night else Color(0.68, 0.82, 0.92)

	_sun.light_energy = lerpf(_sun.light_energy, target_sun_e, delta * 2.5)
	_sun.light_color = _sun.light_color.lerp(target_sun_col, delta * 2.5)
	_world_env.environment.ambient_light_energy = lerpf(_world_env.environment.ambient_light_energy, target_amb, delta * 2.5)
	_sky_mat.sky_top_color = _sky_mat.sky_top_color.lerp(target_sky_top, delta * 2.5)
	_sky_mat.sky_horizon_color = _sky_mat.sky_horizon_color.lerp(target_sky_hor, delta * 2.5)
	_world_env.environment.fog_light_color = target_sky_hor


func _build_island() -> void:
	# Ocean plane
	_make_box(Vector3(0.0, -0.6, 0.0), Vector3(260.0, 0.4, 260.0), Color(0.08, 0.24, 0.36), false)
	# Island ground
	_make_box(Vector3(0.0, -0.25, 0.0), Vector3(92.0, 0.5, 92.0), Color(0.75, 0.85, 0.72), true, "grass")

	# Perimeter rock walls
	for pos_sz in [
		[Vector3(0, 1.5, -46), Vector3(92, 4, 2)],
		[Vector3(0, 1.5, 46), Vector3(92, 4, 2)],
		[Vector3(-46, 1.5, 0), Vector3(2, 4, 92)],
		[Vector3(46, 1.5, 0), Vector3(2, 4, 92)],
	]:
		_make_box(pos_sz[0], pos_sz[1], Color(0.72, 0.70, 0.68), true, "rock")

	# Plane Crash Site (South, z = +16)
	var ref_plane := RefAssets.create_normalized_model("plane", 0.0, 14.0, Color(0.88, 0.86, 0.84))
	if ref_plane != null:
		var plane_body := StaticBody3D.new()
		plane_body.position = Vector3(-2.5, 1.35, 17.5)
		plane_body.rotation_degrees = Vector3(5.0, 22.0, -8.0)
		plane_body.collision_layer = 1
		plane_body.collision_mask = 0
		var pcol := CollisionShape3D.new()
		var pshape := BoxShape3D.new()
		pshape.size = Vector3(11.0, 2.2, 3.2)
		pcol.shape = pshape
		plane_body.add_child(pcol)
		plane_body.add_child(ref_plane)
		add_child(plane_body)
	else:
		var fuselage := _make_box(Vector3(-3.0, 1.1, 18.0), Vector3(9.5, 2.1, 2.5), Color(0.72, 0.74, 0.76), true, "metal")
		fuselage.rotation_degrees = Vector3(4.0, 18.0, -7.0)
	# Climbable plane wing ramp up onto the crash fuselage
	var wing_ramp := _make_box(Vector3(1.8, 0.95, 15.2), Vector3(6.8, 0.35, 2.4), Color(0.74, 0.76, 0.78), true, "metal")
	wing_ramp.rotation_degrees = Vector3(0.0, -18.0, 18.0)

	_crash_fire = OmniLight3D.new()
	_crash_fire.position = Vector3(-1.0, 2.2, 16.0)
	_crash_fire.light_color = Color(1.0, 0.45, 0.12)
	_crash_fire.omni_range = 10.0
	add_child(_crash_fire)

	for p in [Vector3(-6.5, 0.0, 15.0), Vector3(1.5, 0.0, 19.5), Vector3(5.0, 0.0, 15.2), Vector3(-2.0, 0.0, 13.5)]:
		_spawn_container(p, "crash")

	# Tiered parkour shipping containers / rooftops (1.2m, 2.2m, 3.6m)
	_make_box(Vector3(-7.5, 0.6, -2.0), Vector3(2.8, 1.2, 2.6), Color(0.82, 0.72, 0.60), true, "wood") # 1.2m low vault
	_make_box(Vector3(-8.5, 1.1, -6.5), Vector3(4.2, 2.2, 2.8), Color(0.55, 0.68, 0.78), true, "metal") # 2.2m high ledge
	_make_box(Vector3(-8.5, 1.8, -11.5), Vector3(5.0, 3.6, 3.2), Color(0.72, 0.56, 0.46), true, "metal") # 3.6m rooftop
	_make_box(Vector3(6.0, 0.6, -10.0), Vector3(2.8, 1.2, 2.8), Color(0.82, 0.72, 0.60), true, "wood") # 1.2m vault block
	_make_box(Vector3(2.0, 1.1, -13.5), Vector3(4.0, 2.2, 2.6), Color(0.76, 0.74, 0.70), true, "concrete") # 2.2m ledge

	# Parallel Tic-Tac wall-run corridor (3.8m clear gap between inner faces: -17.2 and -13.4)
	_make_box(Vector3(-17.5, 2.1, -7.5), Vector3(0.6, 4.2, 12.0), Color(0.76, 0.74, 0.70), true, "concrete")
	_make_box(Vector3(-13.1, 2.1, -7.5), Vector3(0.6, 4.2, 12.0), Color(0.70, 0.76, 0.80), true, "metal")
	_make_box(Vector3(-15.3, 1.8, -15.5), Vector3(5.0, 3.6, 3.4), Color(0.68, 0.72, 0.66), true, "concrete") # 3.6m wall-run exit rooftop

	for p in [
		Vector3(-8.3, 1.2, -2.0),
		Vector3(-8.5, 2.2, -6.5),
		Vector3(-8.5, 3.6, -11.5),
		Vector3(-15.3, 3.6, -15.5),
		Vector3(6.0, 1.2, -10.0),
		Vector3(2.0, 2.2, -13.5),
		Vector3(-12.0, 0.0, 4.0),
	]:
		_spawn_container(p, "supply")

	# Dark Bio-Lab Bunker (East: x = 20..36, z = -10..10) + stepped roof access
	_make_box(Vector3(28.0, 3.6, 0.0), Vector3(16.0, 0.5, 20.0), Color(0.55, 0.56, 0.58), true, "concrete") # Roof top = 3.85m
	_make_box(Vector3(18.6, 0.65, -7.8), Vector3(2.2, 1.3, 2.2), Color(0.74, 0.68, 0.60), true, "wood") # 1.3m step
	_make_box(Vector3(18.6, 1.25, -4.5), Vector3(2.2, 2.5, 2.6), Color(0.68, 0.72, 0.76), true, "metal") # 2.5m step to 3.85m roof
	_spawn_container(Vector3(24.0, 3.85, -4.5), "supply")

	# Parkour Calibration Zone (additive, keeps verify_prototype coordinates untouched):
	# 1. Low Slide Tunnel (1.35m overhead clearance) at (4.5, 0, 2.0)
	_make_box(Vector3(3.2, 1.1, 2.0), Vector3(0.5, 2.2, 3.2), Color(0.68, 0.66, 0.62), true, "concrete")
	_make_box(Vector3(5.8, 1.1, 2.0), Vector3(0.5, 2.2, 3.2), Color(0.68, 0.66, 0.62), true, "concrete")
	_make_box(Vector3(4.5, 1.775, 2.0), Vector3(3.1, 0.85, 3.2), Color(0.75, 0.52, 0.36), true, "wood")

	# 2. 0.42m Step-Up Staircase at (-2.5, 0, -3.5)
	for si in 4:
		var step_h := 0.42 * float(si + 1)
		_make_box(Vector3(-2.5, step_h * 0.5, -3.5 - float(si) * 0.9), Vector3(2.2, step_h, 0.9), Color(0.72, 0.74, 0.76), true, "concrete")

	# 3. Vertical Wall-Run & Shimmy Tower (3.9m wall + 6m wide grab ledge + opposite 3.6m rooftop) at (-15.3, 0, -24.0)
	_make_box(Vector3(-15.3, 1.95, -24.0), Vector3(6.0, 3.9, 1.6), Color(0.62, 0.66, 0.72), true, "concrete")
	_make_box(Vector3(-15.3, 1.8, -19.2), Vector3(4.8, 3.6, 2.4), Color(0.58, 0.68, 0.74), true, "metal")

	# 4. 7.2m High Drop Tower & Grapple Anchor at (12.0, 0, -14.0)
	_make_box(Vector3(12.0, 3.6, -14.0), Vector3(3.6, 7.2, 3.6), Color(0.54, 0.58, 0.64), true, "metal")
	_make_box(Vector3(12.0, 7.5, -14.0), Vector3(1.2, 0.6, 1.2), Color(0.95, 0.62, 0.22), true, "metal")

	# 5. Soft Amortizer Landing Pads
	for amp_pos in [Vector3(-8.5, 0.18, -14.8), Vector3(18.6, 0.18, 4.0), Vector3(12.0, 0.18, -10.0)]:
		var pad := _make_box(amp_pos, Vector3(3.2, 0.36, 2.6), Color(0.24, 0.62, 0.78), true, "wood")
		pad.add_to_group("amortizer")
	_make_box(Vector3(35.5, 1.75, 0.0), Vector3(1.0, 3.5, 20.0), Color(0.65, 0.66, 0.68), true, "concrete") # Back
	_make_box(Vector3(28.0, 1.75, -9.5), Vector3(16.0, 3.5, 1.0), Color(0.65, 0.66, 0.68), true, "concrete") # North
	_make_box(Vector3(28.0, 1.75, 9.5), Vector3(16.0, 3.5, 1.0), Color(0.65, 0.66, 0.68), true, "concrete") # South
	_make_box(Vector3(20.5, 1.75, -6.0), Vector3(1.0, 3.5, 7.0), Color(0.65, 0.66, 0.68), true, "concrete") # Front left
	_make_box(Vector3(20.5, 1.75, 6.0), Vector3(1.0, 3.5, 7.0), Color(0.65, 0.66, 0.68), true, "concrete") # Front right

	var lab_light := OmniLight3D.new()
	lab_light.position = Vector3(28.0, 2.9, 0.0)
	lab_light.light_color = Color(0.95, 0.18, 0.15)
	lab_light.light_energy = 2.4
	lab_light.omni_range = 16.0
	add_child(lab_light)

	var door_beacon := OmniLight3D.new()
	door_beacon.position = Vector3(19.2, 3.3, 0.0)
	door_beacon.light_color = Color(1.0, 0.48, 0.18)
	door_beacon.light_energy = 2.0
	door_beacon.omni_range = 9.0
	add_child(door_beacon)

	var bunker_sign := Label3D.new()
	bunker_sign.text = "BIO-LAB BUNKER\n[DARK ZONE - INFECTED ACTIVE]"
	bunker_sign.position = Vector3(19.9, 3.05, 0.0)
	bunker_sign.rotation_degrees = Vector3(0.0, -90.0, 0.0)
	bunker_sign.font_size = 40
	bunker_sign.outline_size = 10
	bunker_sign.modulate = Color(1.0, 0.35, 0.25)
	add_child(bunker_sign)

	for p in [Vector3(32.5, 0.0, -6.0), Vector3(32.5, 0.0, 6.0), Vector3(26.0, 0.0, -6.5), Vector3(26.0, 0.0, 6.5)]:
		_spawn_container(p, "lab")

	for zp in [Vector3(25.0, 0.2, -3.0), Vector3(29.0, 0.2, 2.5), Vector3(31.0, 0.2, -4.5), Vector3(27.0, 0.2, 5.0)]:
		_spawn_zombie(zp, true, false)


func _make_box(pos: Vector3, size: Vector3, color: Color, has_collision: bool, tex_key: String = "") -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.collision_layer = 1 if has_collision else 0
	body.collision_mask = 0
	if has_collision:
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		col.shape = shape
		body.add_child(col)
	var mesh_inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_inst.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	if not tex_key.is_empty():
		var tex := RefAssets.get_texture(tex_key)
		if tex != null:
			mat.albedo_texture = tex
			mat.uv1_triplanar = true
			mat.uv1_scale = Vector3(0.28, 0.28, 0.28)
	mesh_inst.material_override = mat
	body.add_child(mesh_inst)
	add_child(body)
	return body


func _spawn_container(pos: Vector3, pool: String) -> void:
	var c := LootContainer.new()
	c.configure(_next_container_id, pool)
	_next_container_id += 1
	add_child(c)
	c.global_position = pos


func _spawn_player() -> void:
	_player = Player.new()
	_player.run_seed = run_seed
	_player.current_day = day
	add_child(_player)
	_player.global_position = Vector3(0.0, 0.4, 8.0)
	_player.died.connect(_on_player_died)
	_player.log_message.connect(_push_log)


func _on_player_died() -> void:
	game_over = true
	_set_mouse_captured(false)
	_update_overlay()


func _push_log(msg: String) -> void:
	_log_lines.append(msg)
	if _log_lines.size() > 5:
		_log_lines.remove_at(0)
	if _log_label != null:
		_log_label.text = "\n".join(_log_lines)


func _make_hud_panel(bg_alpha: float = 0.72) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.07, 0.10, bg_alpha)
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(1.0, 1.0, 1.0, 0.12)
	p.add_theme_stylebox_override("panel", sb)
	return p


func _set_ignore_mouse_recursive(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_set_ignore_mouse_recursive(child)


func _build_hud() -> void:
	var hud := CanvasLayer.new()
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(hud)

	# Fullscreen & directional red damage flash
	_damage_flash_rect = ColorRect.new()
	_damage_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_damage_flash_rect.color = Color(0.85, 0.08, 0.08, 0.0)
	hud.add_child(_damage_flash_rect)

	_damage_left_rect = ColorRect.new()
	_damage_left_rect.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	_damage_left_rect.offset_right = 70
	_damage_left_rect.color = Color(0.95, 0.10, 0.10, 0.0)
	hud.add_child(_damage_left_rect)

	_damage_right_rect = ColorRect.new()
	_damage_right_rect.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_damage_right_rect.offset_left = -70
	_damage_right_rect.color = Color(0.95, 0.10, 0.10, 0.0)
	hud.add_child(_damage_right_rect)

	# Crosshair
	var cross := ColorRect.new()
	cross.color = Color(1, 1, 1, 0.85)
	cross.size = Vector2(4, 4)
	cross.set_anchors_preset(Control.PRESET_CENTER)
	cross.offset_left = -2
	cross.offset_top = -2
	cross.offset_right = 2
	cross.offset_bottom = 2
	hud.add_child(cross)

	# Top bar
	var top_panel := _make_hud_panel(0.72)
	top_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	top_panel.offset_left = 14
	top_panel.offset_top = 12
	hud.add_child(top_panel)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 22)
	top_panel.add_child(top)

	_phase_label = Label.new()
	_phase_label.add_theme_font_size_override("font_size", 20)
	top.add_child(_phase_label)

	_timer_label = Label.new()
	_timer_label.add_theme_font_size_override("font_size", 20)
	top.add_child(_timer_label)

	_seed_label = Label.new()
	_seed_label.text = "Seed: #%d" % run_seed
	_seed_label.modulate = Color(0.75, 0.82, 0.88)
	top.add_child(_seed_label)

	# Controls + log (top right)
	var right_panel := _make_hud_panel(0.72)
	right_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	right_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right_panel.offset_left = -410
	right_panel.offset_top = 12
	right_panel.offset_right = -14
	hud.add_child(right_panel)

	var right_box := VBoxContainer.new()
	right_panel.add_child(right_box)

	var help := Label.new()
	help.text = "WASD Move | Shift Sprint | Space Jump/Vault | Alt+WASD Dodge | Ctrl Slide/Roll\nLMB Swing (Hold=Heavy/Air=Slam) | RMB Upgrade | Q Kick/Stomp | X/MMB Grapple | B Lookback\nE Loot | V Sense | F Light | H Heal | G Eat | T Skip | F3 Telemetry | F4 Dump"
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	help.modulate = Color(0.85, 0.88, 0.92, 0.92)
	help.add_theme_font_size_override("font_size", 12)
	right_box.add_child(help)

	_log_label = Label.new()
	_log_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_log_label.modulate = Color(1.0, 0.92, 0.65)
	_log_label.add_theme_font_size_override("font_size", 13)
	right_box.add_child(_log_label)

	# Center prompt & search bar
	var center_box := VBoxContainer.new()
	center_box.set_anchors_preset(Control.PRESET_CENTER)
	center_box.offset_left = -220
	center_box.offset_top = 28
	center_box.offset_right = 220
	center_box.offset_bottom = 90
	hud.add_child(center_box)

	_prompt_label = Label.new()
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.add_theme_font_size_override("font_size", 16)
	center_box.add_child(_prompt_label)

	_search_bar = ProgressBar.new()
	_search_bar.max_value = 1.0
	_search_bar.show_percentage = false
	_search_bar.custom_minimum_size = Vector2(220, 12)
	_search_bar.visible = false
	center_box.add_child(_search_bar)

	# Bottom-left survival bars
	var bars_panel := _make_hud_panel(0.74)
	bars_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bars_panel.offset_left = 14
	bars_panel.offset_top = -184
	bars_panel.offset_right = 264
	bars_panel.offset_bottom = -14
	hud.add_child(bars_panel)

	var bars := VBoxContainer.new()
	bars_panel.add_child(bars)

	_hp_bar = _add_stat_bar(bars, "HP", Color(0.88, 0.24, 0.24))
	_fitness_bar = _add_stat_bar(bars, "Fitness", Color(0.92, 0.80, 0.24))
	_stam_bar = _add_stat_bar(bars, "Combat", Color(0.28, 0.80, 0.45))
	_grapple_bar = _add_stat_bar(bars, "Grapple", Color(0.70, 0.52, 0.95))
	_hunger_bar = _add_stat_bar(bars, "Hunger", Color(0.88, 0.58, 0.20))
	_thirst_bar = _add_stat_bar(bars, "Thirst", Color(0.22, 0.65, 0.92))

	# F3 Live DL1 Movement & Parity Telemetry Panel (top-left under phase bar)
	_telemetry_panel = _make_hud_panel(0.84)
	_telemetry_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_telemetry_panel.offset_left = 14
	_telemetry_panel.offset_top = 62
	_telemetry_panel.visible = false
	hud.add_child(_telemetry_panel)

	_telemetry_label = Label.new()
	_telemetry_label.add_theme_font_size_override("font_size", 12)
	_telemetry_label.modulate = Color(0.82, 0.96, 0.88)
	_telemetry_panel.add_child(_telemetry_label)

	# Bottom-center hotbar & inventory
	var bot_panel := _make_hud_panel(0.74)
	bot_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bot_panel.offset_left = 280
	bot_panel.offset_top = -84
	bot_panel.offset_right = -280
	bot_panel.offset_bottom = -14
	hud.add_child(bot_panel)

	var bot := VBoxContainer.new()
	bot_panel.add_child(bot)

	var hotbar_row := HBoxContainer.new()
	hotbar_row.alignment = BoxContainer.ALIGNMENT_CENTER
	hotbar_row.add_theme_constant_override("separation", 10)
	bot.add_child(hotbar_row)

	for icon_key in ["pipe", "wall", "turret"]:
		var tr := TextureRect.new()
		tr.custom_minimum_size = Vector2(24, 24)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var tex := RefAssets.get_icon(icon_key)
		if tex != null:
			tr.texture = tex
		else:
			tr.visible = false
		hotbar_row.add_child(tr)
		_slot_icons.append(tr)

	_hotbar_label = Label.new()
	_hotbar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hotbar_label.add_theme_font_size_override("font_size", 16)
	hotbar_row.add_child(_hotbar_label)

	var inv_row := HBoxContainer.new()
	inv_row.alignment = BoxContainer.ALIGNMENT_CENTER
	inv_row.add_theme_constant_override("separation", 12)
	bot.add_child(inv_row)

	var has_any_icon := false
	for item_key in ["wood", "metal", "gunpowder", "food", "water", "medkit"]:
		var tex := RefAssets.get_icon(item_key)
		if tex != null:
			has_any_icon = true
			var pair := HBoxContainer.new()
			pair.add_theme_constant_override("separation", 4)
			var icon := TextureRect.new()
			icon.texture = tex
			icon.custom_minimum_size = Vector2(20, 20)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			pair.add_child(icon)
			var cnt := Label.new()
			cnt.add_theme_font_size_override("font_size", 13)
			cnt.modulate = Color(0.90, 0.94, 0.98)
			pair.add_child(cnt)
			inv_row.add_child(pair)
			_inv_counts[item_key] = cnt

	_inv_label = Label.new()
	_inv_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_inv_label.modulate = Color(0.86, 0.90, 0.94)
	_inv_label.add_theme_font_size_override("font_size", 14)
	_inv_label.visible = not has_any_icon
	bot.add_child(_inv_label)

	# Overlay (Pause / Death / Victory)
	_overlay_panel = _make_hud_panel(0.92)
	_overlay_panel.set_anchors_preset(Control.PRESET_CENTER)
	_overlay_panel.offset_left = -250
	_overlay_panel.offset_top = -210
	_overlay_panel.offset_right = 250
	_overlay_panel.offset_bottom = 210
	_overlay_panel.visible = false
	hud.add_child(_overlay_panel)

	var ov_box := VBoxContainer.new()
	ov_box.alignment = BoxContainer.ALIGNMENT_CENTER
	ov_box.add_theme_constant_override("separation", 8)
	_overlay_panel.add_child(ov_box)

	_overlay_title = Label.new()
	_overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_title.add_theme_font_size_override("font_size", 26)
	ov_box.add_child(_overlay_title)

	_overlay_body = Label.new()
	_overlay_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ov_box.add_child(_overlay_body)

	_resume_btn = Button.new()
	_resume_btn.text = "Resume"
	_resume_btn.pressed.connect(_on_resume_pressed)
	ov_box.add_child(_resume_btn)

	_check_updates_btn = Button.new()
	_check_updates_btn.text = "Check for Updates"
	_check_updates_btn.pressed.connect(_on_check_updates_pressed)
	ov_box.add_child(_check_updates_btn)

	_update_section = VBoxContainer.new()
	_update_section.add_theme_constant_override("separation", 6)
	_update_section.visible = false
	ov_box.add_child(_update_section)

	_build_label = Label.new()
	_build_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_build_label.add_theme_font_size_override("font_size", 12)
	_build_label.modulate = Color(0.75, 0.85, 0.92)
	_update_section.add_child(_build_label)

	_update_status_label = Label.new()
	_update_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_update_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_update_status_label.add_theme_font_size_override("font_size", 13)
	_update_section.add_child(_update_status_label)

	_changelog_label = Label.new()
	_changelog_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_changelog_label.add_theme_font_size_override("font_size", 12)
	_changelog_label.modulate = Color(1.0, 0.92, 0.65)
	_changelog_label.visible = false
	_update_section.add_child(_changelog_label)

	_pull_btn = Button.new()
	_pull_btn.text = "⬇ Update Now (git pull)"
	_pull_btn.visible = false
	_pull_btn.pressed.connect(_on_pull_pressed)
	_update_section.add_child(_pull_btn)

	_force_pull_btn = Button.new()
	_force_pull_btn.text = "⚠ Force Update (git reset --hard)"
	_force_pull_btn.visible = false
	_force_pull_btn.pressed.connect(_on_force_pull_pressed)
	_update_section.add_child(_force_pull_btn)

	_restart_after_update_btn = Button.new()
	_restart_after_update_btn.text = "🚀 Restart Game"
	_restart_after_update_btn.visible = false
	_restart_after_update_btn.pressed.connect(_on_restart_after_update_pressed)
	_update_section.add_child(_restart_after_update_btn)

	_restart_btn = Button.new()
	_restart_btn.text = "Restart Run"
	_restart_btn.pressed.connect(_on_restart_run_pressed)
	ov_box.add_child(_restart_btn)

	_quit_btn = Button.new()
	_quit_btn.text = "Quit"
	_quit_btn.pressed.connect(_on_quit_pressed)
	ov_box.add_child(_quit_btn)

	_set_ignore_mouse_recursive(hud)
	_overlay_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	for btn in [_resume_btn, _check_updates_btn, _pull_btn, _force_pull_btn, _restart_after_update_btn, _restart_btn, _quit_btn]:
		(btn as Button).mouse_filter = Control.MOUSE_FILTER_STOP

	_connect_update_manager()


func _add_stat_bar(parent: Control, label_text: String, tint: Color) -> ProgressBar:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(68, 0)
	row.add_child(lbl)
	var bar := ProgressBar.new()
	bar.max_value = 100.0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(150, 16)
	bar.modulate = tint
	row.add_child(bar)
	return bar


func _update_hud() -> void:
	if not is_instance_valid(_player):
		return
	var s := _player.get_hud_state()
	_phase_label.text = "DAY %d / %d — %s" % [day, MAX_DAYS, "NIGHT HORDE" if is_night else "DAYLIGHT"]
	_phase_label.modulate = Color(1.0, 0.35, 0.30) if is_night else Color(1.0, 0.92, 0.55)
	_timer_label.text = "Next phase: %ds" % int(ceil(phase_timer)) + (" | Incoming: %d" % horde_to_spawn if is_night else "")

	_hp_bar.value = s["hp"]
	_fitness_bar.value = float(s.get("fitness", 1.0)) * 100.0
	_fitness_bar.modulate = Color(0.95, 0.38, 0.22) if bool(s.get("sprint_exhausted", false)) else Color(0.92, 0.80, 0.24)
	_stam_bar.value = float(s["stamina"]) * 100.0
	_stam_bar.modulate = Color(0.9, 0.35, 0.2) if s["exhausted"] else Color(0.28, 0.80, 0.45)
	_grapple_bar.value = float(s.get("rope_energy", 1.0)) * 100.0
	_hunger_bar.value = s["hunger"]
	_thirst_bar.value = s["thirst"]

	if _telemetry_panel != null and _telemetry_panel.visible and _telemetry_label != null:
		_telemetry_label.text = _player.telemetry.format_overlay_text() + "\nHUD State: %s | Slide: %s | LandTier: %d" % [
			String(s.get("move_state", "IDLE")),
			String(s.get("slide_phase", "none")),
			int(s.get("landing_tier", 0)),
		]

	var slot := int(s["active_slot"])
	var w_name: String = s["weapon_name"]
	_hotbar_label.text = "%s[1] %s   %s[2] Wood Wall (3W)   %s[3] Turret (3W 2M 1G)" % [
		">" if slot == 1 else "", w_name,
		">" if slot == 2 else "",
		">" if slot == 3 else "",
	]

	var inv: Dictionary = s["inventory"]
	if _inv_counts.is_empty():
		_inv_label.text = "Wood: %d | Metal: %d | Gunpowder: %d | Food: %d | Water: %d | Medkit: %d" % [
			int(inv.get("wood", 0)),
			int(inv.get("metal", 0)),
			int(inv.get("gunpowder", 0)),
			int(inv.get("food", 0)),
			int(inv.get("water", 0)),
			int(inv.get("medkit", 0)),
		]
	else:
		for item_key in _inv_counts.keys():
			var lbl := _inv_counts[item_key] as Label
			if lbl != null:
				lbl.text = "%s:%d" % [String(item_key).capitalize(), int(inv.get(item_key, 0))]

	if _slot_icons.size() >= 1:
		var w_tier := int(s.get("weapon_tier", 1))
		var w_icon_key := "pipe" if w_tier == 1 else ("machete" if w_tier == 2 else "axe")
		var w_tex := RefAssets.get_icon(w_icon_key)
		if w_tex != null:
			_slot_icons[0].texture = w_tex
		for idx in _slot_icons.size():
			_slot_icons[idx].modulate = Color.WHITE if (idx + 1 == slot) else Color(0.55, 0.55, 0.55, 0.75)

	_prompt_label.text = s["prompt"]
	var prog := float(s["loot_progress"])
	_search_bar.visible = prog > 0.01
	_search_bar.value = prog

	var flash := float(s.get("damage_flash", 0.0))
	var dir_x := float(s.get("damage_dir_x", 0.0))
	if _damage_flash_rect != null:
		_damage_flash_rect.color.a = flash * 0.26
	if _damage_left_rect != null:
		_damage_left_rect.color.a = flash * clampf(0.45 - dir_x * 0.5, 0.0, 0.75)
	if _damage_right_rect != null:
		_damage_right_rect.color.a = flash * clampf(0.45 + dir_x * 0.5, 0.0, 0.75)


func _build_ambient_audio() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var amb := RefAssets.get_audio("ambient_night")
	if amb != null:
		_night_ambient_player = AudioStreamPlayer.new()
		_night_ambient_player.stream = amb
		_night_ambient_player.volume_db = -14.0
		_night_ambient_player.finished.connect(func() -> void:
			if is_night and is_instance_valid(_night_ambient_player):
				_night_ambient_player.play()
		)
		add_child(_night_ambient_player)
	var mus := RefAssets.get_audio("music_night")
	if mus != null:
		_night_music_player = AudioStreamPlayer.new()
		_night_music_player.stream = mus
		_night_music_player.volume_db = -18.0
		_night_music_player.finished.connect(func() -> void:
			if is_night and is_instance_valid(_night_music_player):
				_night_music_player.play()
		)
		add_child(_night_music_player)


func _update_night_audio() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if is_night:
		if _night_ambient_player != null and not _night_ambient_player.playing:
			_night_ambient_player.play()
		if _night_music_player != null and not _night_music_player.playing:
			_night_music_player.play()
	else:
		if _night_ambient_player != null and _night_ambient_player.playing:
			_night_ambient_player.stop()
		if _night_music_player != null and _night_music_player.playing:
			_night_music_player.stop()


func _get_update_manager() -> Node:
	return get_node_or_null("/root/UpdateManager")


func _connect_update_manager() -> void:
	var um := _get_update_manager()
	if um == null:
		return
	if not um.check_started.is_connected(_on_um_check_started):
		um.check_started.connect(_on_um_check_started)
	if not um.check_completed.is_connected(_on_um_check_completed):
		um.check_completed.connect(_on_um_check_completed)
	if not um.update_started.is_connected(_on_um_update_started):
		um.update_started.connect(_on_um_update_started)
	if not um.update_completed.is_connected(_on_um_update_completed):
		um.update_completed.connect(_on_um_update_completed)
	_refresh_build_label()


func _refresh_build_label() -> void:
	if _build_label == null:
		return
	var um := _get_update_manager()
	if um == null:
		_build_label.text = "Build: local"
		return
	_build_label.text = "Local build: %s @ %s" % [String(um.get("current_branch_name")), String(um.get("current_commit_hash"))]


func _on_resume_pressed() -> void:
	if game_over or victory:
		return
	paused = false
	get_tree().paused = false
	_set_mouse_captured(true)
	_update_overlay()


func _on_restart_run_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_check_updates_pressed() -> void:
	_update_section.visible = true
	_force_armed = false
	_force_pull_btn.text = "⚠ Force Update (git reset --hard)"
	_refresh_build_label()
	var um := _get_update_manager()
	if um == null:
		_update_status_label.text = "UpdateManager autoload not found."
		return
	um.call("check_for_updates")


func _on_pull_pressed() -> void:
	var um := _get_update_manager()
	if um != null:
		_force_armed = false
		_force_pull_btn.text = "⚠ Force Update (git reset --hard)"
		um.call("pull_updates", false)


func _on_force_pull_pressed() -> void:
	if not _force_armed:
		_force_armed = true
		_force_pull_btn.text = "Click Again to Confirm: Discard Local Changes"
		return
	_force_armed = false
	_force_pull_btn.text = "⚠ Force Update (git reset --hard)"
	var um := _get_update_manager()
	if um != null:
		um.call("pull_updates", true)


func _on_restart_after_update_pressed() -> void:
	var um := _get_update_manager()
	if um != null:
		um.call("restart_game")


func _on_um_check_started() -> void:
	_update_section.visible = true
	_update_status_label.text = "Checking GitHub for updates..."
	_changelog_label.visible = false
	_pull_btn.visible = false
	_force_pull_btn.visible = false
	_restart_after_update_btn.visible = false
	_check_updates_btn.disabled = true


func _on_um_check_completed(up_to_date: bool, behind_count: int, changelog: Array, error_msg: String) -> void:
	_check_updates_btn.disabled = false
	_refresh_build_label()
	if not error_msg.is_empty():
		_update_status_label.text = error_msg
		_changelog_label.visible = false
		_pull_btn.visible = false
		_force_pull_btn.visible = true
		return
	if up_to_date:
		_update_status_label.text = "✓ Game is up to date!"
		_changelog_label.visible = false
		_pull_btn.visible = false
		_force_pull_btn.visible = false
	else:
		_update_status_label.text = "Update available: %d commit(s) behind." % behind_count
		if not changelog.is_empty():
			var lines := PackedStringArray()
			for item in changelog:
				lines.append("• " + String(item))
			_changelog_label.text = "\n".join(lines)
			_changelog_label.visible = true
		_pull_btn.visible = true
		_force_pull_btn.visible = true


func _on_um_update_started() -> void:
	_update_status_label.text = "Updating from GitHub and re-importing assets..."
	_pull_btn.disabled = true
	_force_pull_btn.disabled = true
	_check_updates_btn.disabled = true


func _on_um_update_completed(success: bool, message: String) -> void:
	_pull_btn.disabled = false
	_force_pull_btn.disabled = false
	_check_updates_btn.disabled = false
	_refresh_build_label()
	_update_status_label.text = message
	if success:
		_pull_btn.visible = false
		_force_pull_btn.visible = false
		_changelog_label.visible = false
		_restart_after_update_btn.visible = true
	else:
		_force_pull_btn.visible = true


func _update_overlay() -> void:
	if game_over:
		_overlay_panel.visible = true
		_overlay_title.text = "YOU DIED"
		_overlay_body.text = "Survived to Day %d\nPress [R] to Restart" % day
		_resume_btn.visible = false
		_check_updates_btn.visible = false
		_update_section.visible = false
		_restart_btn.visible = true
		_quit_btn.visible = true
	elif victory:
		_overlay_panel.visible = true
		_overlay_title.text = "RESCUE ARRIVED!"
		_overlay_body.text = "You survived all 10 nights on the island.\nPress [R] to Play Again"
		_resume_btn.visible = false
		_check_updates_btn.visible = false
		_update_section.visible = false
		_restart_btn.visible = true
		_quit_btn.visible = true
	elif paused:
		_overlay_panel.visible = true
		_overlay_title.text = "PAUSED"
		_overlay_body.text = "Press [Esc] or Resume to continue"
		_resume_btn.visible = true
		_check_updates_btn.visible = true
		_restart_btn.visible = true
		_quit_btn.visible = true
		_refresh_build_label()
	else:
		_overlay_panel.visible = false
		_force_armed = false
