use std::f32::consts::PI;

use godot::prelude::*;

pub const GRAVITY: f32 = 16.80;
pub const JUMP_MAX_HEIGHT: f32 = 1.01;
pub const JUMP_VELOCITY: f32 = 5.825;
pub const SLOPE_SLIDE_MIN: f32 = 0.01;
pub const SLOPE_SLIDE_MAX: f32 = 0.80;
pub const SLOPE_SLIDE_COEFF: f32 = 0.0175556;
pub const WALK_SPEED: f32 = 3.5;
pub const BACK_STRAFE_SPEED: f32 = 2.5;
pub const SPRINT_SPEED: f32 = 6.0;
pub const CROUCH_SPEED: f32 = 1.5;
pub const FITNESS_SPRINT_GATE: f32 = 0.06;
pub const FITNESS_BREATH_DEG_PER_SEC: f32 = 300.0;
pub const FITNESS_BREATH_AMP: f32 = 0.90;
pub const EDGE_LEAP_HORIZ_SPEED: f32 = 4.5;
pub const EDGE_LEAP_PEAK_CLAMP: f32 = 1.30;
pub const WALL_RUN_FRONT_HEIGHT: f32 = 1.8;
pub const FALL_DAMPING_L2_MIN: f32 = 6.5;
pub const FALL_DAMPING_L1_MAX: f32 = 9.0;
pub const DODGE_SPEED: f32 = 9.0;
pub const LOOK_PITCH_MIN_DEG: f32 = -89.0;
pub const LOOK_DIST_VERT_UP: f32 = 1.0;
pub const LOOK_DIST_VERT_DOWN: f32 = 0.5;
pub const LOOK_DIST_VERT_DOWN_PARAM: f32 = 1.2;

pub struct MetricSpec {
    pub key: &'static str,
    pub label: &'static str,
    pub spec: f64,
    pub tol: f64,
    pub unit: &'static str,
}

pub const METRIC_SPECS: &[MetricSpec] = &[
    MetricSpec { key: "walk_speed", label: "Walk Speed", spec: WALK_SPEED as f64, tol: 0.25, unit: "m/s" },
    MetricSpec { key: "sprint_speed", label: "Sprint Speed", spec: SPRINT_SPEED as f64, tol: 0.35, unit: "m/s" },
    MetricSpec { key: "strafe_speed", label: "Strafe/Back", spec: BACK_STRAFE_SPEED as f64, tol: 0.25, unit: "m/s" },
    MetricSpec { key: "crouch_speed", label: "Crouch Speed", spec: CROUCH_SPEED as f64, tol: 0.20, unit: "m/s" },
    MetricSpec { key: "jump_apex", label: "Jump Apex", spec: JUMP_MAX_HEIGHT as f64, tol: 0.12, unit: "m" },
    MetricSpec { key: "jump_hang_time", label: "Jump Hang", spec: 0.693, tol: 0.08, unit: "s" },
    MetricSpec { key: "vault_duration", label: "Vault Time", spec: 0.22, tol: 0.12, unit: "s" },
    MetricSpec { key: "wall_run_gain_y", label: "WallRun Gain", spec: WALL_RUN_FRONT_HEIGHT as f64, tol: 0.65, unit: "m" },
    MetricSpec { key: "slide_peak", label: "Slide Peak", spec: 8.4, tol: 0.80, unit: "m/s" },
    MetricSpec { key: "dodge_speed", label: "Dodge Speed", spec: DODGE_SPEED as f64, tol: 0.90, unit: "m/s" },
    MetricSpec { key: "fall_height", label: "Fall Damping", spec: FALL_DAMPING_L2_MIN as f64, tol: 2.50, unit: "m" },
    MetricSpec { key: "melee_apex", label: "Melee Apex", spec: 0.16, tol: 0.06, unit: "s" },
];

pub struct EvaluatedMetric {
    pub key: String,
    pub label: String,
    pub spec: f64,
    pub tol: f64,
    pub actual: f64,
    pub unit: String,
    pub status: &'static str,
}

impl EvaluatedMetric {
    pub fn to_dict(&self) -> VarDictionary {
        let mut d = VarDictionary::new();
        d.set("key", self.key.as_str());
        d.set("label", self.label.as_str());
        d.set("spec", self.spec);
        d.set("tol", self.tol);
        d.set("actual", self.actual);
        d.set("unit", self.unit.as_str());
        d.set("status", self.status);
        d
    }
}

pub fn evaluate_metric_core(key: &str, actual: f64) -> EvaluatedMetric {
    let found = METRIC_SPECS.iter().find(|m| m.key == key);
    let Some(cfg) = found else {
        return EvaluatedMetric {
            key: key.to_string(),
            label: key.to_string(),
            spec: 0.0,
            tol: 0.1,
            actual,
            unit: String::new(),
            status: "N/A",
        };
    };

    if actual < 0.0 || actual.is_nan() {
        return EvaluatedMetric {
            key: cfg.key.to_string(),
            label: cfg.label.to_string(),
            spec: cfg.spec,
            tol: cfg.tol,
            actual,
            unit: cfg.unit.to_string(),
            status: "N/A",
        };
    }

    let ok = (actual - cfg.spec).abs() <= cfg.tol;
    EvaluatedMetric {
        key: cfg.key.to_string(),
        label: cfg.label.to_string(),
        spec: cfg.spec,
        tol: cfg.tol,
        actual,
        unit: cfg.unit.to_string(),
        status: if ok { "PASS" } else { "FAIL" },
    }
}

pub fn slope_slide_factor(slope_deg: f32) -> f32 {
    if slope_deg <= 0.0 {
        return SLOPE_SLIDE_MIN;
    }
    if slope_deg >= 45.0 {
        return SLOPE_SLIDE_MAX;
    }
    (slope_deg * SLOPE_SLIDE_COEFF + SLOPE_SLIDE_MIN).clamp(SLOPE_SLIDE_MIN, SLOPE_SLIDE_MAX)
}

pub fn fitness_speed_factor(cur_fitness: f32, max_fitness: f32) -> f32 {
    let denom = (0.3 * max_fitness).max(0.001);
    0.8 + 0.2 * ((cur_fitness - 0.2 * max_fitness) / denom).clamp(0.0, 1.0)
}

pub fn can_sprint(cur_fitness: f32, is_sprint_exhausted: bool) -> bool {
    !is_sprint_exhausted && cur_fitness > FITNESS_SPRINT_GATE
}

pub fn breath_oscillation(t: f32) -> f32 {
    (t * FITNESS_BREATH_DEG_PER_SEC).to_radians().sin() * FITNESS_BREATH_AMP + 1.0
}

pub fn look_cosine_slew(norm_t: f32, branch_b: bool) -> f32 {
    let w = if branch_b { 0.30 } else { 0.25 };
    w - (norm_t.clamp(0.0, 1.0) * PI).cos() * w
}

pub fn edge_leap_velocity(from_pos: Vector3, target_pos: Vector3) -> Vector3 {
    let delta = target_pos - from_pos;
    let horiz = Vector2::new(delta.x, delta.z);
    let horiz_len = horiz.length();
    let dir2 = if horiz_len > 0.0001 {
        horiz / horiz_len
    } else {
        Vector2::new(0.0, -1.0)
    };
    let flight_t = (horiz_len * 0.222222).max(0.18);
    let clamped_dy = delta.y.min(EDGE_LEAP_PEAK_CLAMP);
    let vy = ((clamped_dy + 0.5 * GRAVITY * flight_t * flight_t) / flight_t)
        .clamp(JUMP_VELOCITY * 0.85, JUMP_VELOCITY * 1.25);
    Vector3::new(dir2.x * EDGE_LEAP_HORIZ_SPEED, vy, dir2.y * EDGE_LEAP_HORIZ_SPEED)
}

pub fn landing_tier(fall_dist: f32, on_amortizer: bool, has_crouch_damping: bool) -> i32 {
    if fall_dist < 1.2 {
        return 0;
    }
    if on_amortizer {
        return 1;
    }
    if fall_dist < 3.5 {
        return 2;
    }
    if fall_dist < FALL_DAMPING_L2_MIN {
        return 3;
    }
    if fall_dist <= FALL_DAMPING_L1_MAX && has_crouch_damping {
        return 4;
    }
    5
}

pub fn fpp_spine_pitch(pitch_rad: f32) -> f32 {
    if pitch_rad >= 0.0 {
        return pitch_rad * LOOK_DIST_VERT_UP;
    }
    let max_down = LOOK_PITCH_MIN_DEG.abs().to_radians();
    let norm = (pitch_rad.abs() / max_down).clamp(0.0, 1.0);
    -norm.powf(LOOK_DIST_VERT_DOWN_PARAM) * max_down * LOOK_DIST_VERT_DOWN
}

#[derive(GodotClass)]
#[class(init, base=RefCounted)]
pub struct RustDLReference {
    base: Base<RefCounted>,
}

#[godot_api]
impl RustDLReference {
    #[func]
    pub fn compute_slope_slide_factor(slope_deg: f32) -> f32 {
        slope_slide_factor(slope_deg)
    }

    #[func]
    pub fn compute_fitness_speed_factor(cur_fitness: f32, max_fitness: f32) -> f32 {
        fitness_speed_factor(cur_fitness, max_fitness)
    }

    #[func]
    pub fn can_sprint_with_fitness(cur_fitness: f32, is_sprint_exhausted: bool) -> bool {
        can_sprint(cur_fitness, is_sprint_exhausted)
    }

    #[func]
    pub fn compute_breath_oscillation(t: f32) -> f32 {
        breath_oscillation(t)
    }

    #[func]
    pub fn compute_look_cosine_slew(norm_t: f32, branch_b: bool) -> f32 {
        look_cosine_slew(norm_t, branch_b)
    }

    #[func]
    pub fn compute_edge_leap_velocity(from_pos: Vector3, target_pos: Vector3) -> Vector3 {
        edge_leap_velocity(from_pos, target_pos)
    }

    #[func]
    pub fn classify_landing_tier(
        fall_dist: f32,
        on_amortizer: bool,
        has_crouch_damping: bool,
    ) -> i32 {
        landing_tier(fall_dist, on_amortizer, has_crouch_damping)
    }

    #[func]
    pub fn compute_fpp_spine_pitch(pitch_rad: f32) -> f32 {
        fpp_spine_pitch(pitch_rad)
    }

    #[func]
    pub fn get_metric_keys() -> PackedStringArray {
        let mut arr = PackedStringArray::new();
        for spec in METRIC_SPECS {
            arr.push(spec.key);
        }
        arr
    }

    #[func]
    pub fn evaluate_metric(key: GString, actual: f64) -> VarDictionary {
        evaluate_metric_core(&key.to_string(), actual).to_dict()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn dl1_reference_math_matches_specs() {
        assert!((slope_slide_factor(0.0) - 0.01).abs() < 1e-6);
        assert!((slope_slide_factor(45.0) - 0.80).abs() < 1e-6);
        assert!((fitness_speed_factor(0.20, 1.0) - 0.80).abs() < 1e-6);
        assert!((fitness_speed_factor(0.50, 1.0) - 1.00).abs() < 1e-6);
        assert!(!can_sprint(0.05, false));
        assert!(can_sprint(0.10, false));
        assert!(!can_sprint(0.50, true));
        assert_eq!(landing_tier(0.5, false, false), 0);
        assert_eq!(landing_tier(8.0, true, false), 1);
        assert_eq!(landing_tier(2.5, false, false), 2);
        assert_eq!(landing_tier(5.0, false, false), 3);
        assert_eq!(landing_tier(8.0, false, true), 4);
        assert_eq!(landing_tier(8.0, false, false), 5);
        assert_eq!(evaluate_metric_core("walk_speed", 3.5).status, "PASS");
        assert_eq!(evaluate_metric_core("walk_speed", -1.0).status, "N/A");
    }
}
