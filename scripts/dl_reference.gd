class_name DLReference
extends RefCounted

# Gravity & Jump (Dying Light 1 Data0.pak)
const GRAVITY := 16.80
const JUMP_MAX_HEIGHT := 1.01
const JUMP_VELOCITY := 5.825
const MIN_JUMP_INTERVAL := 0.40
const JUMP_STAMINA_COST := 0.10
const COYOTE_TIME := 0.12
const JUMP_BUFFER_TIME := 0.15

# Slopes & Stairs
const MAX_GROUND_WALK_DEG := 50.0
const MAX_GROUND_JUMP_DEG := 45.0
const STAIR_HEIGHT := 0.51

# Speeds & Accel/Decel
const WALK_SPEED := 3.5
const BACK_STRAFE_SPEED := 2.5
const SPRINT_SPEED := 6.0
const CROUCH_SPEED := 1.5
const MOVE_ACCEL := 40.0
const MOVE_DECEL := 40.0
const SPRINT_ACCEL := 10.0
const CROUCH_ACCEL := 4.0
const CROUCH_DECEL := 10.0
const AIR_CONTROL := 0.22

# Dual Stamina (Fitness vs Combat)
const FITNESS_SPRINT_COST := 0.10
const FITNESS_REGEN_DELAY := 0.75
const FITNESS_EMPTY_DELAY := 5.0
const FITNESS_REGEN_RATE := 2.0
const EXHAUSTED_SPEED_FACTOR := 0.6
const STAMINA_REGEN_DELAY := 2.5
const STAMINA_EMPTY_DELAY := 4.0
const STAMINA_REGEN_RATE := 1.5
const EMPTY_SWING_STAMINA_MUL := 0.6

# Wall-Run, Fall, Slide, Dodge, Tackle, Grapple, Combat
const WALL_RUN_EXTRA_GRAVITY := 9.5
const WALL_RUN_FRONT_HEIGHT := 1.8
const WALL_JUMP_BACK_HEIGHT := 0.8
const WALL_JUMP_BACK_SPEED := 3.0
const MAX_WALL_JUMPS := 2
const CROUCH_DAMPING_WINDOW := 1.0
const FALL_DAMPING_L2_MIN := 6.5
const FALL_DAMPING_L1_MAX := 9.0
const SLIDE_COOLDOWN := 0.5
const DODGE_SPEED := 9.0
const DODGE_COOLDOWN := 0.75
const TACKLE_ADD_SPEED := 6.0
const TACKLE_STAMINA := 0.40
const TACKLE_COOLDOWN := 1.0
const GRAPPLE_LENGTH := 25.0
const ROPE_MAX_ENERGY := 1.0
const ROPE_REGEN_TIME := 10.0
const JUMP_OVER_STUN_DUR := 5.0
const CHARGE_HOLD_DURATION := 0.50
const FOV_SPRINT_MODIF := 4.5
const FOV_AMORTIZER_MODIF := -3.0

const METRIC_ORDER := [
	"walk_speed",
	"sprint_speed",
	"strafe_speed",
	"crouch_speed",
	"jump_apex",
	"jump_hang_time",
	"vault_duration",
	"wall_run_gain_y",
	"slide_peak",
	"dodge_speed",
	"fall_height",
	"melee_apex",
]

const SPECS := {
	"walk_speed": {"label": "Walk Speed", "spec": WALK_SPEED, "tol": 0.25, "unit": "m/s"},
	"sprint_speed": {"label": "Sprint Speed", "spec": SPRINT_SPEED, "tol": 0.35, "unit": "m/s"},
	"strafe_speed": {"label": "Strafe/Back", "spec": BACK_STRAFE_SPEED, "tol": 0.25, "unit": "m/s"},
	"crouch_speed": {"label": "Crouch Speed", "spec": CROUCH_SPEED, "tol": 0.20, "unit": "m/s"},
	"jump_apex": {"label": "Jump Apex", "spec": JUMP_MAX_HEIGHT, "tol": 0.12, "unit": "m"},
	"jump_hang_time": {"label": "Jump Hang", "spec": 0.693, "tol": 0.08, "unit": "s"},
	"vault_duration": {"label": "Vault Time", "spec": 0.22, "tol": 0.12, "unit": "s"},
	"wall_run_gain_y": {"label": "WallRun Gain", "spec": WALL_RUN_FRONT_HEIGHT, "tol": 0.65, "unit": "m"},
	"slide_peak": {"label": "Slide Peak", "spec": 8.4, "tol": 0.80, "unit": "m/s"},
	"dodge_speed": {"label": "Dodge Speed", "spec": DODGE_SPEED, "tol": 0.90, "unit": "m/s"},
	"fall_height": {"label": "Fall Damping", "spec": FALL_DAMPING_L2_MIN, "tol": 2.50, "unit": "m"},
	"melee_apex": {"label": "Melee Apex", "spec": 0.16, "tol": 0.06, "unit": "s"},
}


static func get_metric_keys() -> PackedStringArray:
	return PackedStringArray(METRIC_ORDER)


static func evaluate_metric(key: String, actual: float) -> Dictionary:
	var cfg: Dictionary = SPECS.get(key, {})
	var label := String(cfg.get("label", key))
	var spec := float(cfg.get("spec", 0.0))
	var tol := float(cfg.get("tol", 0.1))
	var unit := String(cfg.get("unit", ""))

	if cfg.is_empty() or actual < 0.0 or is_nan(actual):
		return {
			"key": key,
			"label": label,
			"spec": spec,
			"tol": tol,
			"actual": actual,
			"unit": unit,
			"status": "N/A",
		}

	var ok := absf(actual - spec) <= tol
	return {
		"key": key,
		"label": label,
		"spec": spec,
		"tol": tol,
		"actual": actual,
		"unit": unit,
		"status": "PASS" if ok else "FAIL",
	}
