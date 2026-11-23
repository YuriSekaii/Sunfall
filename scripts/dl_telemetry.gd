class_name DLTelemetry
extends RefCounted

const MAX_FRAMES := 600
const MAX_TRANSITIONS := 20

var _inner: RustDLTelemetry = RustDLTelemetry.new()


func _init() -> void:
	_inner.reset()


func reset() -> void:
	_inner.reset()


func record_binary_event(key: String, val: Variant) -> void:
	_inner.record_binary_event(key, val)


func get_binary_event(key: String, default_val: Variant = null) -> Variant:
	return _inner.get_binary_event(key, default_val)


func record_frame(t: float, state: String, pos: Vector3, vel: Vector3, on_floor: bool, fitness: float, stamina: float, fov: float) -> void:
	_inner.record_frame(t, state, pos, vel, on_floor, fitness, stamina, fov)


func record_metric(key: String, val: float, take_max: bool = false) -> void:
	_inner.record_metric(key, val, take_max)


func get_metric(key: String) -> float:
	return _inner.get_metric(key)


func get_frame_count() -> int:
	return _inner.get_frame_count()


func get_transitions() -> Array[Dictionary]:
	return _inner.get_transitions()


func get_comparison_rows() -> Array[Dictionary]:
	return _inner.get_comparison_rows()


func format_overlay_text() -> String:
	return _inner.format_overlay_text()


func dump_json(path: String) -> bool:
	return _inner.dump_json(path)
