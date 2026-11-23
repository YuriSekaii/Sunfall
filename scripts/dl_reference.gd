class_name DLReference
extends RefCounted

# Gravity & Jump (Dying Light 1 Data0.pak + odephysicswalkfly.phx: -9.8 + -7.0 = -16.8)
const GRAVITY := 16.80
const JUMP_MAX_HEIGHT := 1.01
const JUMP_VELOCITY := 5.825
const MIN_JUMP_INTERVAL := 0.40
const JUMP_STAMINA_COST := 0.10
const COYOTE_TIME := 0.12
const JUMP_BUFFER_TIME := 0.15

# Slopes & Stairs (walk_player.phx + MoveController 0x00d50c90)
const MAX_GROUND_WALK_DEG := 50.0
const MAX_GROUND_JUMP_DEG := 45.0
const STAIR_HEIGHT := 0.51
const SLOPE_SLIDE_MIN := 0.01
const SLOPE_SLIDE_MAX := 0.80
const SLOPE_SLIDE_COEFF := 0.0175556

# PlayerDuckModuleSweeps (0x00cde22e / 0x00cde585)
const DUCK_CAPSULE_RADIUS := 0.30
const DUCK_CAPSULE_HALF_HEIGHT := 0.75
const DUCK_CAPSULE_HEIGHT := 1.50

# Speeds & Accel/Decel (default_levels.xml + MoveController 0x00d4979c)
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

# Dual Stamina: PlayerFitnessModule (0x00ce1521, 0x00d4979c) & PlayerStaminaModule (0x00cf0560)
const FITNESS_SPRINT_COST := 0.10
const FITNESS_SPRINT_GATE := 0.06
const FITNESS_REGEN_DELAY := 0.75
const FITNESS_EMPTY_DELAY := 5.0
const FITNESS_REGEN_RATE := 2.0
const FITNESS_MOVE_CROUCH_REGEN_MUL := 0.75
const FITNESS_SPEED_SQ_THRESHOLD := 0.20
const FITNESS_BREATH_DEG_PER_SEC := 300.0
const FITNESS_BREATH_AMP := 0.90
const EXHAUSTED_SPEED_FACTOR := 0.6
const STAMINA_REGEN_DELAY := 2.5
const STAMINA_EMPTY_DELAY := 4.0
const STAMINA_REGEN_RATE := 1.5
const EMPTY_SWING_STAMINA_MUL := 0.6

# NaturalMovementController 3-Band Probes (0x00d5733c) & EdgeGrabController (0x00d084f6..0x00d104f0)
const NM_PROBE_BAND_LOW := 0.85
const NM_PROBE_BAND_MID := 1.35
const NM_PROBE_BAND_HIGH := 1.65
const NM_VAULT_TIMING := 0.500
const NM_CLIMB_LEDGE_TIMING := 0.725
const EDGE_HAND_GRIP_OFFSET := 0.2158
const EDGE_SHIMMY_STEP := 0.40
const EDGE_SHIMMY_VERT_SLICE := -0.03
const EDGE_SHIMMY_DURATION := 0.629
const EDGE_HANG_YAW_CLAMP_DEG := 75.0
const EDGE_SHIMMY_YAW_CLAMP_DEG := 62.0
const EDGE_LEAP_HORIZ_SPEED := 4.5
const EDGE_LEAP_PEAK_CLAMP := 1.30

# Wall-Run, Fall/LandingController (0x00d3e890..0x00d3e9b6) & PlayerFallHelperModule (0x00ce0df0)
const WALL_RUN_EXTRA_GRAVITY := 9.5
const WALL_RUN_FRONT_HEIGHT := 1.8
const WALL_JUMP_BACK_HEIGHT := 0.8
const WALL_JUMP_BACK_SPEED := 3.0
const MAX_WALL_JUMPS := 2
const CROUCH_DAMPING_WINDOW := 1.0
const CROUCH_DAMPER_DUR := 0.800
const CROUCH_DAMPER_ROLL_DUR := 1.000
const CROUCH_DAMPER_ROLL_CAN_WALK := 0.867
const FALL_DAMPING_L2_MIN := 6.5
const FALL_DAMPING_L1_MAX := 9.0
const FALL_HELPER_RAY_LEN := 25.0
const FALL_HELPER_HIGH_VEL_Y := -15.0
const FALL_AMORTIZER_RADIUS := 8.5
const FALL_AMORTIZER_CONE_DEG := 40.0
const FALL_AMORTIZER_BOX_EXTENT := 0.5
const LANDING_TIER_COUNT := 6
const LANDING_YAW_CLAMP_DEG := 90.0
const LANDING_LOOK_BLEND_TIME := 0.30
const LANDING_HEAVY_SHOCKWAVE_THRESHOLD := 5.0

# 4-Phase Slide (0x00cfbf50, m_fpp_legs.scr) & Player Dodge (0x00d52188, 0x00d50760)
const SLIDE_COOLDOWN := 0.5
const SLIDE_BEGIN_DUR := 0.333
const SLIDE_LOOP_DUR := 0.400
const SLIDE_KICK_DUR := 0.567
const SLIDE_KICK_HIT_TIME := 0.233
const SLIDE_END_DUR := 0.481
const SLIDE_LOOP_RIGHT_YAW_DEG := 5.0
const DODGE_SPEED := 9.0
const DODGE_IMPULSE := 6.0
const DODGE_MIN_INTERVAL := 0.15
const DODGE_LOOK_LOCK := 0.50
const DODGE_COOLDOWN := 0.75

# Tackle, Grapple (0x00d7cd28), Combat Sweep (0x00cfe531) & Anim Timelines (m_fpp_stick.scr, m_fpp_legs.scr)
const TACKLE_ADD_SPEED := 6.0
const TACKLE_STAMINA := 0.40
const TACKLE_COOLDOWN := 1.0
const TACKLE_DURATION := 1.120
const TACKLE_ACTIVE_END := 0.600
const GRAPPLE_LENGTH := 25.0
const GRAPPLE_THROW_DURATION := 0.833
const GRAPPLE_ATTACH_TIME := 0.167
const ROPE_MAX_ENERGY := 1.0
const ROPE_REGEN_TIME := 10.0
const JUMP_OVER_STUN_DUR := 5.0
const CHARGE_HOLD_DURATION := 0.50
const MELEE_SWEEP_HALF_ARC_DEG := 60.0
const MELEE_CAMERA_ROLL_DEG := 6.0
const MELEE_RL_DURATION := 0.600
const MELEE_RL_DMG_START := 0.093
const MELEE_RL_DMG_END := 0.333
const MELEE_LR_DURATION := 0.500
const MELEE_LR_DMG_START := 0.083
const MELEE_LR_DMG_END := 0.333
const MELEE_HEAVY_DURATION := 1.667
const MELEE_HEAVY_DMG_START := 0.667
const MELEE_HEAVY_DMG_END := 0.879
const MELEE_EXHAUSTED_DURATION := 1.567
const MELEE_EXHAUSTED_DMG_START := 0.467
const MELEE_EXHAUSTED_DMG_END := 0.667
const KICK_DURATION := 0.625
const KICK_DMG_START := 0.250
const KICK_DMG_END := 0.350
const KICK_LOW_DURATION := 0.533
const KICK_LOW_DMG_START := 0.133
const KICK_LOW_DMG_END := 0.300
const KICK_AIR_DURATION := 0.567
const KICK_AIR_DMG_START := 0.167
const KICK_AIR_DMG_END := 0.433
const DROPKICK_DURATION := 0.800
const DROPKICK_DMG_START := 0.100
const DROPKICK_DMG_END := 0.300
const DROPKICK_STANDUP_FAST_DUR := 1.267
const STOMP_DURATION := 1.200
const STOMP_CRUSH_TIME := 0.667
const GRAB_INPUT_WINDOW := 2.000
const GRAB_FAST_FINISH_DUR := 1.067
const GRAB_RELEASE_TIME := 0.833

# LookParams("Normal"), LookController (0x00d43a14), EyeCamera & Stride Cadence (m_fpp_unarmed.scr)
const LOOK_PITCH_MIN_DEG := -89.0
const LOOK_PITCH_MAX_DEG := 70.0
const LOOK_HORZ_MAX_DEG := 179.0
const LOOKBACK_WHIP_DUR := 0.133
const WALK_CYCLE_DUR := 0.883
const SPRINT_CYCLE_DUR := 0.567
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


static func compute_slope_slide_factor(slope_deg: float) -> float:
	if slope_deg <= 0.0:
		return SLOPE_SLIDE_MIN
	if slope_deg >= 45.0:
		return SLOPE_SLIDE_MAX
	return clampf(slope_deg * SLOPE_SLIDE_COEFF + SLOPE_SLIDE_MIN, SLOPE_SLIDE_MIN, SLOPE_SLIDE_MAX)


static func compute_fitness_speed_factor(cur_fitness: float, max_fitness: float = 1.0) -> float:
	var denom := maxf(0.001, 0.3 * max_fitness)
	return 0.8 + 0.2 * clampf((cur_fitness - 0.2 * max_fitness) / denom, 0.0, 1.0)


static func can_sprint_with_fitness(cur_fitness: float, is_sprint_exhausted: bool) -> bool:
	return not is_sprint_exhausted and cur_fitness > FITNESS_SPRINT_GATE


static func compute_breath_oscillation(t: float) -> float:
	return sin(deg_to_rad(t * FITNESS_BREATH_DEG_PER_SEC)) * FITNESS_BREATH_AMP + 1.0


static func compute_look_cosine_slew(norm_t: float, branch_b: bool = false) -> float:
	var w := 0.30 if branch_b else 0.25
	return w - cos(clampf(norm_t, 0.0, 1.0) * PI) * w


static func compute_edge_leap_velocity(from_pos: Vector3, target_pos: Vector3) -> Vector3:
	var delta := target_pos - from_pos
	var horiz := Vector2(delta.x, delta.z)
	var horiz_len := horiz.length()
	var dir2 := (horiz / horiz_len) if horiz_len > 0.0001 else Vector2(0.0, -1.0)
	var flight_t := maxf(0.18, horiz_len * 0.222222) # 1.0 / 4.5 m/s (0x00d104f0)
	var clamped_dy := minf(delta.y, EDGE_LEAP_PEAK_CLAMP)
	var vy := clampf((clamped_dy + 0.5 * GRAVITY * flight_t * flight_t) / flight_t, JUMP_VELOCITY * 0.85, JUMP_VELOCITY * 1.25)
	return Vector3(dir2.x * EDGE_LEAP_HORIZ_SPEED, vy, dir2.y * EDGE_LEAP_HORIZ_SPEED)


static func classify_landing_tier(fall_dist: float, on_amortizer: bool, has_crouch_damping: bool) -> int:
	if fall_dist < 1.2:
		return 0 # Tier 0: Soft step/hop
	if on_amortizer:
		return 1 # Tier 1: Amortizer cushion landing
	if fall_dist < 3.5:
		return 2 # Tier 2: Light landing (CrouchDamper if crouched)
	if fall_dist < FALL_DAMPING_L2_MIN:
		return 3 # Tier 3: Medium landing (> 5.0m emits heavy shockwave)
	if fall_dist <= FALL_DAMPING_L1_MAX and has_crouch_damping:
		return 4 # Tier 4: CrouchDamperRoll (360° parkour roll)
	return 5 # Tier 5: Heavy/lethal impact landing


# FPP Look/Aim pitch distribution (data/scripts/playeraimlookparamsfpp.scr)
const LOOK_DIST_VERT_UP := 1.0
const LOOK_DIST_VERT_DOWN := 0.5
const LOOK_DIST_VERT_DOWN_PARAM := 1.2

# Exact m_fpp_*.scr animation blend-ins & early-exit ratios
const BLEND_JUMP := 0.30
const BLEND_VAULT := 0.10
const BLEND_LAND := 0.10
const BLEND_CLIMB_FAST := 0.00
const BLEND_DODGE := 0.10
const BLEND_MELEE := 0.06
const BLEND_LOCOMOTION := 0.16
const LAND_ROLL_CAN_WALK_RATIO := 26.0 / 30.0


static func compute_fpp_spine_pitch(pitch_rad: float) -> float:
	# playeraimlookparamsfpp.scr: 100% spine pitch looking up (+70°), 50% pow 1.2 looking down (-89°)
	if pitch_rad >= 0.0:
		return pitch_rad * LOOK_DIST_VERT_UP
	var max_down := deg_to_rad(absf(LOOK_PITCH_MIN_DEG))
	var norm := clampf(absf(pitch_rad) / max_down, 0.0, 1.0)
	return -pow(norm, LOOK_DIST_VERT_DOWN_PARAM) * max_down * LOOK_DIST_VERT_DOWN


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
