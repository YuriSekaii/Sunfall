use std::collections::{BTreeMap, VecDeque};

use godot::classes::{FileAccess, Json, file_access::ModeFlags};
use godot::prelude::*;

use crate::dl_reference::{METRIC_SPECS, evaluate_metric_core};

pub const MAX_FRAMES: usize = 600;
pub const MAX_TRANSITIONS: usize = 20;

#[derive(Clone)]
struct FrameSample {
    t: f64,
    state: String,
    pos: [f64; 3],
    vel: [f64; 3],
    horiz_speed: f64,
    vert_speed: f64,
    on_floor: bool,
    fitness: f64,
    stamina: f64,
    fov: f64,
}

impl FrameSample {
    fn to_dict(&self) -> VarDictionary {
        let mut d = VarDictionary::new();
        d.set("t", self.t);
        d.set("state", self.state.as_str());
        let mut pos_arr = VarArray::new();
        pos_arr.push(&self.pos[0].to_variant());
        pos_arr.push(&self.pos[1].to_variant());
        pos_arr.push(&self.pos[2].to_variant());
        d.set("pos", &pos_arr);
        let mut vel_arr = VarArray::new();
        vel_arr.push(&self.vel[0].to_variant());
        vel_arr.push(&self.vel[1].to_variant());
        vel_arr.push(&self.vel[2].to_variant());
        d.set("vel", &vel_arr);
        d.set("horiz_speed", self.horiz_speed);
        d.set("vert_speed", self.vert_speed);
        d.set("on_floor", self.on_floor);
        d.set("fitness", self.fitness);
        d.set("stamina", self.stamina);
        d.set("fov", self.fov);
        d
    }
}

#[derive(Clone)]
struct Transition {
    t: f64,
    from: String,
    to: String,
}

impl Transition {
    fn to_dict(&self) -> VarDictionary {
        let mut d = VarDictionary::new();
        d.set("t", self.t);
        d.set("from", self.from.as_str());
        d.set("to", self.to.as_str());
        d
    }
}

fn snap(val: f64, step: f64) -> f64 {
    (val / step).round() * step
}

#[derive(GodotClass)]
#[class(base=RefCounted)]
pub struct RustDLTelemetry {
    frames: VecDeque<FrameSample>,
    transitions: VecDeque<Transition>,
    metrics: BTreeMap<String, f64>,
    binary_events: VarDictionary,
    last_state: String,
    base: Base<RefCounted>,
}

#[godot_api]
impl IRefCounted for RustDLTelemetry {
    fn init(base: Base<RefCounted>) -> Self {
        let mut this = Self {
            frames: VecDeque::with_capacity(MAX_FRAMES),
            transitions: VecDeque::with_capacity(MAX_TRANSITIONS),
            metrics: BTreeMap::new(),
            binary_events: VarDictionary::new(),
            last_state: String::new(),
            base,
        };
        this.reset();
        this
    }
}

#[godot_api]
impl RustDLTelemetry {
    #[func]
    pub fn reset(&mut self) {
        self.frames.clear();
        self.transitions.clear();
        self.metrics.clear();
        self.binary_events = VarDictionary::new();
        self.binary_events.set("last_landing_tier", 0_i64);
        self.binary_events.set("last_landing_shockwave", "none");
        self.binary_events.set("last_slide_phase", "none");
        self.binary_events.set("last_melee_sweep_hits", 0_i64);
        self.binary_events.set("last_nm_probe_band", 0_i64);
        self.binary_events.set("eye_camera_coupled", false);
        self.last_state.clear();
        for spec in METRIC_SPECS {
            self.metrics.insert(spec.key.to_string(), -1.0);
        }
    }

    #[func]
    pub fn record_binary_event(&mut self, key: GString, val: Variant) {
        self.binary_events.set(&key, &val);
    }

    #[func]
    pub fn get_binary_event(&self, key: GString, default_val: Variant) -> Variant {
        self.binary_events.get(&key).unwrap_or(default_val)
    }

    #[func]
    #[allow(clippy::too_many_arguments)]
    pub fn record_frame(
        &mut self,
        t: f64,
        state: GString,
        pos: Vector3,
        vel: Vector3,
        on_floor: bool,
        fitness: f64,
        stamina: f64,
        fov: f64,
    ) {
        let state_str = state.to_string();
        let horiz_speed = ((vel.x as f64).hypot(vel.z as f64)) as f64;
        let vert_speed = vel.y as f64;
        let sample = FrameSample {
            t: snap(t, 0.001),
            state: state_str.clone(),
            pos: [
                snap(pos.x as f64, 0.001),
                snap(pos.y as f64, 0.001),
                snap(pos.z as f64, 0.001),
            ],
            vel: [
                snap(vel.x as f64, 0.001),
                snap(vel.y as f64, 0.001),
                snap(vel.z as f64, 0.001),
            ],
            horiz_speed: snap(horiz_speed, 0.001),
            vert_speed: snap(vert_speed, 0.001),
            on_floor,
            fitness: snap(fitness, 0.001),
            stamina: snap(stamina, 0.001),
            fov: snap(fov, 0.01),
        };

        if self.frames.len() >= MAX_FRAMES {
            self.frames.pop_front();
        }
        self.frames.push_back(sample);

        if !self.last_state.is_empty() && state_str != self.last_state {
            if self.transitions.len() >= MAX_TRANSITIONS {
                self.transitions.pop_front();
            }
            self.transitions.push_back(Transition {
                t: snap(t, 0.001),
                from: self.last_state.clone(),
                to: state_str.clone(),
            });
        }
        self.last_state = state_str.clone();

        match state_str.as_str() {
            "walk" if horiz_speed > 0.5 && horiz_speed <= 3.7 => {
                self.record_metric_str("walk_speed", horiz_speed, true);
            }
            "sprint" if horiz_speed > 0.5 => {
                self.record_metric_str("sprint_speed", horiz_speed, true);
            }
            "strafe" | "back" if horiz_speed > 0.5 && horiz_speed <= 2.7 => {
                self.record_metric_str("strafe_speed", horiz_speed, true);
            }
            "crouch" if horiz_speed > 0.3 && horiz_speed <= 1.7 => {
                self.record_metric_str("crouch_speed", horiz_speed, true);
            }
            "slide" => {
                self.record_metric_str("slide_peak", horiz_speed, true);
            }
            "dodge" => {
                self.record_metric_str("dodge_speed", horiz_speed, true);
            }
            _ => {}
        }
    }

    #[func]
    pub fn record_metric(&mut self, key: GString, val: f64, take_max: bool) {
        self.record_metric_str(&key.to_string(), val, take_max);
    }

    #[func]
    pub fn get_metric(&self, key: GString) -> f64 {
        *self.metrics.get(&key.to_string()).unwrap_or(&-1.0)
    }

    #[func]
    pub fn get_frame_count(&self) -> i64 {
        self.frames.len() as i64
    }

    #[func]
    pub fn get_transitions(&self) -> Array<VarDictionary> {
        let mut arr = Array::new();
        for tr in &self.transitions {
            arr.push(&tr.to_dict());
        }
        arr
    }

    #[func]
    pub fn get_comparison_rows(&self) -> Array<VarDictionary> {
        let mut rows = Array::new();
        for spec in METRIC_SPECS {
            let actual = *self.metrics.get(spec.key).unwrap_or(&-1.0);
            rows.push(&evaluate_metric_core(spec.key, actual).to_dict());
        }
        rows
    }

    #[func]
    pub fn format_overlay_text(&self) -> GString {
        let mut lines: Vec<String> = Vec::with_capacity(24);
        if let Some(last) = self.frames.back() {
            lines.push(format!(
                "DL1 TELEMETRY | State: {} | Vh: {:.2} m/s | Vy: {:.2} | Floor: {}",
                last.state,
                last.horiz_speed,
                last.vert_speed,
                if last.on_floor { "Y" } else { "N" },
            ));
            lines.push(format!(
                "Fit: {:.2} | Stam: {:.2} | FOV: {:.1} | Frames: {}/{}",
                last.fitness,
                last.stamina,
                last.fov,
                self.frames.len(),
                MAX_FRAMES,
            ));
            let slide_phase = self
                .binary_events
                .get("last_slide_phase")
                .map(|v| v.to_string())
                .unwrap_or_else(|| "none".to_string());
            let land_tier = self
                .binary_events
                .get("last_landing_tier")
                .and_then(|v| v.try_to::<i64>().ok())
                .unwrap_or(0);
            let shockwave = self
                .binary_events
                .get("last_landing_shockwave")
                .map(|v| v.to_string())
                .unwrap_or_else(|| "none".to_string());
            let sweep_hits = self
                .binary_events
                .get("last_melee_sweep_hits")
                .and_then(|v| v.try_to::<i64>().ok())
                .unwrap_or(0);
            let eye_cam = self
                .binary_events
                .get("eye_camera_coupled")
                .and_then(|v| v.try_to::<bool>().ok())
                .unwrap_or(false);
            lines.push(format!(
                "Slide: {} | LandTier: {} ({}) | SweepHits: {} | EyeCam: {}",
                slide_phase,
                land_tier,
                shockwave,
                sweep_hits,
                if eye_cam { "ON" } else { "PROC" },
            ));
        } else {
            lines.push("DL1 TELEMETRY | Waiting for frames...".to_string());
        }

        lines.push("--------------------------------------------------".to_string());
        lines.push(format!(
            "{:<13} {:>7} {:>7}  {}",
            "METRIC", "SPEC", "ACTUAL", "STATUS"
        ));
        for spec in METRIC_SPECS {
            let actual = *self.metrics.get(spec.key).unwrap_or(&-1.0);
            let row = evaluate_metric_core(spec.key, actual);
            let act_str = if row.status == "N/A" {
                "  --".to_string()
            } else {
                format!("{:6.2}", row.actual)
            };
            lines.push(format!(
                "{:<13} {:6.2}  {}  [{}]",
                row.label, row.spec, act_str, row.status
            ));
        }

        if !self.transitions.is_empty() {
            lines.push("--------------------------------------------------".to_string());
            let start = self.transitions.len().saturating_sub(4);
            let tr_strs: Vec<String> = self
                .transitions
                .iter()
                .skip(start)
                .map(|tr| format!("{:.1}s:{}->{}", tr.t, tr.from, tr.to))
                .collect();
            lines.push(format!("Transitions: {}", tr_strs.join(" | ")));
        }

        GString::from(lines.join("\n").as_str())
    }

    #[func]
    pub fn dump_json(&self, path: GString) -> bool {
        let mut frames_arr: Array<VarDictionary> = Array::new();
        for f in &self.frames {
            frames_arr.push(&f.to_dict());
        }
        let mut metrics_dict = VarDictionary::new();
        for (k, v) in &self.metrics {
            metrics_dict.set(k.as_str(), *v);
        }

        let mut payload = VarDictionary::new();
        payload.set("frames", &frames_arr);
        payload.set("transitions", &self.get_transitions());
        payload.set("metrics", &metrics_dict);
        payload.set("binary_events", &self.binary_events);
        payload.set("comparison", &self.get_comparison_rows());

        let Some(mut f) = FileAccess::open(&path, ModeFlags::WRITE) else {
            return false;
        };
        let text = Json::stringify_ex(&payload.to_variant()).indent("  ").done();
        f.store_string(&text);
        f.close();
        true
    }
}

impl RustDLTelemetry {
    fn record_metric_str(&mut self, key: &str, val: f64, take_max: bool) {
        if take_max {
            if let Some(prev) = self.metrics.get(key)
                && *prev >= 0.0
            {
                self.metrics.insert(key.to_string(), prev.max(val));
                return;
            }
        }
        self.metrics.insert(key.to_string(), val);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn snap_rounds_to_millisecond_and_ring_constants_hold() {
        assert!((snap(1.2346, 0.001) - 1.235).abs() < 1e-9);
        assert_eq!(MAX_FRAMES, 600);
        assert_eq!(MAX_TRANSITIONS, 20);
    }
}
