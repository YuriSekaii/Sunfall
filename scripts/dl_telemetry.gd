class_name DLTelemetry
extends RefCounted

const MAX_FRAMES := 600
const MAX_TRANSITIONS := 20

var _frames: Array[Dictionary] = []
var _transitions: Array[Dictionary] = []
var _metrics: Dictionary = {}
var _binary_events: Dictionary = {}
var _last_state: String = ""
var _last_frame: Dictionary = {}


func _init() -> void:
	reset()


func reset() -> void:
	_frames.clear()
	_transitions.clear()
	_metrics.clear()
	_binary_events = {
		"last_landing_tier": 0,
		"last_landing_shockwave": "none",
		"last_slide_phase": "none",
		"last_melee_sweep_hits": 0,
		"last_nm_probe_band": 0,
		"eye_camera_coupled": false,
	}
	_last_state = ""
	_last_frame = {}
	for key in DLReference.get_metric_keys():
		_metrics[key] = -1.0


func record_binary_event(key: String, val: Variant) -> void:
	_binary_events[key] = val


func get_binary_event(key: String, default_val: Variant = null) -> Variant:
	return _binary_events.get(key, default_val)


func record_frame(t: float, state: String, pos: Vector3, vel: Vector3, on_floor: bool, fitness: float, stamina: float, fov: float) -> void:
	var horiz_speed := Vector2(vel.x, vel.z).length()
	var vert_speed := vel.y
	var sample := {
		"t": snappedf(t, 0.001),
		"state": state,
		"pos": [snappedf(pos.x, 0.001), snappedf(pos.y, 0.001), snappedf(pos.z, 0.001)],
		"vel": [snappedf(vel.x, 0.001), snappedf(vel.y, 0.001), snappedf(vel.z, 0.001)],
		"horiz_speed": snappedf(horiz_speed, 0.001),
		"vert_speed": snappedf(vert_speed, 0.001),
		"on_floor": on_floor,
		"fitness": snappedf(fitness, 0.001),
		"stamina": snappedf(stamina, 0.001),
		"fov": snappedf(fov, 0.01),
	}

	if _frames.size() >= MAX_FRAMES:
		_frames.remove_at(0)
	_frames.append(sample)
	_last_frame = sample

	if not _last_state.is_empty() and state != _last_state:
		if _transitions.size() >= MAX_TRANSITIONS:
			_transitions.remove_at(0)
		_transitions.append({
			"t": snappedf(t, 0.001),
			"from": _last_state,
			"to": state,
		})
	_last_state = state

	match state:
		"walk":
			if horiz_speed > 0.5 and horiz_speed <= 3.7:
				record_metric("walk_speed", horiz_speed, true)
		"sprint":
			if horiz_speed > 0.5:
				record_metric("sprint_speed", horiz_speed, true)
		"strafe", "back":
			if horiz_speed > 0.5 and horiz_speed <= 2.7:
				record_metric("strafe_speed", horiz_speed, true)
		"crouch":
			if horiz_speed > 0.3 and horiz_speed <= 1.7:
				record_metric("crouch_speed", horiz_speed, true)
		"slide":
			record_metric("slide_peak", horiz_speed, true)
		"dodge":
			record_metric("dodge_speed", horiz_speed, true)


func record_metric(key: String, val: float, take_max: bool = false) -> void:
	if take_max and _metrics.has(key) and float(_metrics[key]) >= 0.0:
		_metrics[key] = maxf(float(_metrics[key]), val)
	else:
		_metrics[key] = val


func get_metric(key: String) -> float:
	return float(_metrics.get(key, -1.0))


func get_frame_count() -> int:
	return _frames.size()


func get_transitions() -> Array[Dictionary]:
	return _transitions


func get_comparison_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for key in DLReference.get_metric_keys():
		rows.append(DLReference.evaluate_metric(key, float(_metrics.get(key, -1.0))))
	return rows


func format_overlay_text() -> String:
	var lines := PackedStringArray()
	if not _last_frame.is_empty():
		lines.append("DL1 TELEMETRY | State: %s | Vh: %.2f m/s | Vy: %.2f | Floor: %s" % [
			String(_last_frame["state"]),
			float(_last_frame["horiz_speed"]),
			float(_last_frame["vert_speed"]),
			"Y" if bool(_last_frame["on_floor"]) else "N",
		])
		lines.append("Fit: %.2f | Stam: %.2f | FOV: %.1f | Frames: %d/%d" % [
			float(_last_frame["fitness"]),
			float(_last_frame["stamina"]),
			float(_last_frame["fov"]),
			_frames.size(),
			MAX_FRAMES,
		])
		lines.append("Slide: %s | LandTier: %d (%s) | SweepHits: %d | EyeCam: %s" % [
			String(_binary_events.get("last_slide_phase", "none")),
			int(_binary_events.get("last_landing_tier", 0)),
			String(_binary_events.get("last_landing_shockwave", "none")),
			int(_binary_events.get("last_melee_sweep_hits", 0)),
			"ON" if bool(_binary_events.get("eye_camera_coupled", false)) else "PROC",
		])
	else:
		lines.append("DL1 TELEMETRY | Waiting for frames...")

	lines.append("--------------------------------------------------")
	lines.append("%-13s %7s %7s  %s" % ["METRIC", "SPEC", "ACTUAL", "STATUS"])
	for row in get_comparison_rows():
		var act_str := "  --" if String(row["status"]) == "N/A" else ("%6.2f" % float(row["actual"]))
		lines.append("%-13s %6.2f  %s  [%s]" % [
			String(row["label"]),
			float(row["spec"]),
			act_str,
			String(row["status"]),
		])

	if not _transitions.is_empty():
		lines.append("--------------------------------------------------")
		var start_idx := maxi(0, _transitions.size() - 4)
		var tr_strs := PackedStringArray()
		for i in range(start_idx, _transitions.size()):
			var tr := _transitions[i]
			tr_strs.append("%.1fs:%s->%s" % [float(tr["t"]), String(tr["from"]), String(tr["to"])])
		lines.append("Transitions: " + " | ".join(tr_strs))

	return "\n".join(lines)


func dump_json(path: String) -> bool:
	var payload := {
		"frames": _frames,
		"transitions": _transitions,
		"metrics": _metrics,
		"binary_events": _binary_events,
		"comparison": get_comparison_rows(),
	}
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(payload, "  "))
	f.close()
	return true
