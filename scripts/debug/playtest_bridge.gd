extends Node

var _world: Node3D
var _player: Player
var _server := TCPServer.new()
var _peer: StreamPeerTCP = null
var _buf: String = ""
var _step_remaining: int = 0
var _step_wait_peer: bool = false

var _rec_active: bool = false
var _rec_dir: String = ""
var _rec_every_n: int = 2
var _rec_tick: int = 0
var _rec_frame_idx: int = 0
var _events: Array[Dictionary] = []


func setup(world: Node3D, player: Player, port: int) -> void:
	_world = world
	_player = player
	var err := _server.listen(port, "127.0.0.1")
	if err != OK:
		push_error("PlaytestBridge failed to listen on port %d: %d" % [port, err])


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if is_instance_valid(_player):
		_player.allow_headless_mouse_look_for_test = true
		_player._grab_immunity = 0.0
	if _world.has_method("_set_mouse_captured"):
		_world.call("_set_mouse_captured", false)
	if _world.get("_telemetry_panel") != null:
		(_world.get("_telemetry_panel") as Control).visible = false


func push_event(kind: String, data: Dictionary = {}) -> void:
	var ev := {"t": snappedf(_player._elapsed_time, 0.001) if is_instance_valid(_player) else 0.0, "kind": kind}
	for k in data.keys():
		ev[k] = data[k]
	_events.append(ev)
	if _events.size() > 64:
		_events.pop_front()


func _physics_process(_delta: float) -> void:
	if _server.is_connection_available():
		_peer = _server.take_connection()
		_buf = ""

	if _rec_active:
		_rec_tick += 1
		if (_rec_tick % _rec_every_n) == 0:
			_grab_rec_frame()

	if _step_remaining > 0:
		_step_remaining -= 1
		if _step_remaining == 0 and _step_wait_peer:
			_step_wait_peer = false
			_send_json({"ok": true, "state": _collect_state()})
		return

	_poll_commands()


func _grab_rec_frame() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var tex := get_viewport().get_texture()
	if tex == null:
		return
	var img := tex.get_image()
	if img == null or img.is_empty():
		return
	_rec_frame_idx += 1
	img.save_png(_rec_dir.path_join("f_%05d.png" % _rec_frame_idx))


func _poll_commands() -> void:
	if _peer == null:
		return
	_peer.poll()
	var st := _peer.get_status()
	if st != StreamPeerTCP.STATUS_CONNECTED:
		_peer = null
		return
	var avail := _peer.get_available_bytes()
	if avail > 0:
		_buf += _peer.get_utf8_string(avail)
	while true:
		var nl := _buf.find("\n")
		if nl == -1:
			break
		var line := _buf.substr(0, nl).strip_edges()
		_buf = _buf.substr(nl + 1)
		if not line.is_empty():
			_handle_line(line)


func _send_json(obj: Dictionary) -> void:
	if _peer != null and _peer.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		_peer.put_data((JSON.stringify(obj) + "\n").to_utf8_buffer())


func _handle_line(line: String) -> void:
	var parsed: Variant = JSON.parse_string(line)
	if not (parsed is Dictionary):
		_send_json({"ok": false, "err": "bad_json"})
		return
	var cmd_d := parsed as Dictionary
	var cmd := String(cmd_d.get("cmd", ""))
	match cmd:
		"state":
			_send_json({"ok": true, "state": _collect_state()})
		"input":
			for a in cmd_d.get("press", []):
				Input.action_press(String(a))
			for a in cmd_d.get("release", []):
				Input.action_release(String(a))
			if cmd_d.has("yaw_deg"):
				_player._yaw = deg_to_rad(float(cmd_d["yaw_deg"]))
				_player.rotation.y = _player._yaw
			if cmd_d.has("pitch_deg"):
				_player._pitch = deg_to_rad(float(cmd_d["pitch_deg"]))
				_player._head.rotation.x = _player._pitch
			if cmd_d.has("look_at"):
				var la: Array = cmd_d["look_at"]
				var target := Vector3(float(la[0]), float(la[1]), float(la[2]))
				var delta_v := target - _player._camera.global_position
				var horiz := Vector2(delta_v.x, delta_v.z).length()
				if horiz > 0.01:
					_player._yaw = atan2(-delta_v.x, -delta_v.z)
					_player.rotation.y = _player._yaw
					_player._pitch = clampf(atan2(delta_v.y, horiz), deg_to_rad(-89.0), deg_to_rad(70.0))
					_player._head.rotation.x = _player._pitch
			_send_json({"ok": true})
		"step":
			var n := maxi(1, int(cmd_d.get("frames", 1)))
			_step_remaining = n
			_step_wait_peer = true
		"record_start":
			_rec_dir = String(cmd_d.get("dir", ""))
			_rec_every_n = maxi(1, int(cmd_d.get("every_n", 2)))
			DirAccess.make_dir_recursive_absolute(_rec_dir)
			_rec_frame_idx = 0
			_rec_tick = 0
			_rec_active = true
			_send_json({"ok": true, "dir": _rec_dir})
		"record_stop":
			_rec_active = false
			_send_json({"ok": true, "frames": _rec_frame_idx})
		"spawn_zombie":
			var p_arr: Array = cmd_d.get("pos", [0.0, 0.05, 4.0])
			var z := Zombie.new()
			z.configure(bool(cmd_d.get("active", false)), bool(cmd_d.get("brute", false)), false)
			_world.add_child(z)
			z.global_position = Vector3(float(p_arr[0]), float(p_arr[1]), float(p_arr[2]))
			var d := _player.global_position - z.global_position
			d.y = 0.0
			if d.length() > 0.05:
				z.rotation.y = atan2(-d.x, -d.z)
			_send_json({"ok": true, "id": z.get_instance_id()})
		"clear_zombies":
			for node in get_tree().get_nodes_in_group("enemies"):
				if is_instance_valid(node):
					node.queue_free()
			_send_json({"ok": true})
		"teleport":
			var tp: Array = cmd_d.get("pos", [0.0, 0.05, 8.0])
			_player.global_position = Vector3(float(tp[0]), float(tp[1]), float(tp[2]))
			_player.velocity = Vector3.ZERO
			if cmd_d.has("yaw_deg"):
				_player._yaw = deg_to_rad(float(cmd_d["yaw_deg"]))
				_player.rotation.y = _player._yaw
			if cmd_d.has("pitch_deg"):
				_player._pitch = deg_to_rad(float(cmd_d["pitch_deg"]))
				_player._head.rotation.x = _player._pitch
			_player._is_crouching = false
			_player._slide_timer = 0.0
			_player._vaulting = false
			_player._ledge_hanging = false
			_player._wall_running = false
			_player._dropkicking = false
			_player._grabbed_by = null
			_send_json({"ok": true})
		"quit":
			_rec_active = false
			_send_json({"ok": true})
			get_tree().quit(0)
		_:
			_send_json({"ok": false, "err": "unknown_cmd"})


func _collect_state() -> Dictionary:
	var zombies_out: Array[Dictionary] = []
	for node in get_tree().get_nodes_in_group("enemies"):
		if node is Zombie and is_instance_valid(node):
			var z := node as Zombie
			zombies_out.append({
				"id": z.get_instance_id(),
				"pos": [snappedf(z.global_position.x, 0.02), snappedf(z.global_position.y, 0.02), snappedf(z.global_position.z, 0.02)],
				"vel": [snappedf(z.velocity.x, 0.02), snappedf(z.velocity.y, 0.02), snappedf(z.velocity.z, 0.02)],
				"hp": snappedf(z.hp, 0.1),
				"downed": z.is_downed(),
				"stagger": snappedf(z.stagger_timer, 0.02),
				"anim": z._current_anim,
				"dist": snappedf(_player.global_position.distance_to(z.global_position), 0.02),
			})
	var evs := _events.duplicate()
	_events.clear()
	return {
		"pos": [snappedf(_player.global_position.x, 0.02), snappedf(_player.global_position.y, 0.02), snappedf(_player.global_position.z, 0.02)],
		"vel": [snappedf(_player.velocity.x, 0.02), snappedf(_player.velocity.y, 0.02), snappedf(_player.velocity.z, 0.02)],
		"speed": snappedf(Vector2(_player.velocity.x, _player.velocity.z).length(), 0.02),
		"yaw_deg": snappedf(rad_to_deg(_player._yaw), 0.1),
		"pitch_deg": snappedf(rad_to_deg(_player._pitch), 0.1),
		"move_state": _player.move_state,
		"fpp_anim": _player._current_fpp_anim,
		"hp": snappedf(_player.hp, 0.1),
		"fitness": snappedf(_player.fitness, 0.02),
		"stamina": snappedf(_player.stamina, 0.02),
		"slot": _player.active_slot,
		"inv": _player.inventory.duplicate(),
		"prompt": _player._prompt_text,
		"is_night": bool(_world.get("is_night")),
		"day": int(_world.get("day")),
		"zombies": zombies_out,
		"events": evs,
	}
