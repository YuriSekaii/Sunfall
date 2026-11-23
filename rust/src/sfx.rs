use std::f32::consts::TAU;

use godot::prelude::*;

/// Fast deterministic SplitMix64 PRNG for procedural audio noise.
fn next_noise_sample(state: &mut u64) -> f32 {
    *state = state.wrapping_add(0x9E37_79B9_7F4A_7C15);
    let mut z = *state;
    z = (z ^ (z >> 30)).wrapping_mul(0xBF58_476D_1CE4_E5B9);
    z = (z ^ (z >> 27)).wrapping_mul(0x94D0_49BB_1331_11EB);
    z ^= z >> 31;
    // Map upper 24 bits to [-1.0, 1.0].
    let unit = ((z >> 40) as f32) * (1.0 / 16_777_216.0);
    unit * 2.0 - 1.0
}

pub fn synth_pcm16_bytes(
    duration: f32,
    f0: f32,
    f1: f32,
    amp: f32,
    noise_mix: f32,
    mix_rate: i32,
) -> Vec<u8> {
    let rate = mix_rate.max(1) as f32;
    let count = ((duration * rate) as usize).max(1);
    let mut bytes = Vec::with_capacity(count * 2);
    let mut phase: f32 = 0.0;
    let mut rng_state: u64 = ((f0 * 100.0 + f1) as i64 as u64) ^ 0xA5A5_5A5A_1234_5678;
    let inv_count = 1.0 / (count as f32);

    for i in 0..count {
        let t = (i as f32) * inv_count;
        let env = (1.0 - t) * (1.0 - t);
        let freq = f0 + (f1 - f0) * t;
        phase += TAU * freq / rate;
        let tone = phase.sin();
        let noise = next_noise_sample(&mut rng_state);
        let sample = ((tone * (1.0 - noise_mix) + noise * noise_mix) * amp * env).clamp(-1.0, 1.0);
        let s16 = (sample * 32767.0) as i16;
        bytes.extend_from_slice(&s16.to_le_bytes());
    }
    bytes
}

#[derive(GodotClass)]
#[class(init, base=RefCounted)]
pub struct RustSfxSynth {
    base: Base<RefCounted>,
}

#[godot_api]
impl RustSfxSynth {
    #[func]
    pub fn synth_pcm16(
        duration: f32,
        f0: f32,
        f1: f32,
        amp: f32,
        noise_mix: f32,
        mix_rate: i32,
    ) -> PackedByteArray {
        let bytes = synth_pcm16_bytes(duration, f0, f1, amp, noise_mix, mix_rate);
        PackedByteArray::from(bytes.as_slice())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn synth_produces_expected_byte_length_and_determinism() {
        let a = synth_pcm16_bytes(0.14, 340.0, 120.0, 0.35, 0.45, 22050);
        let b = synth_pcm16_bytes(0.14, 340.0, 120.0, 0.35, 0.45, 22050);
        assert_eq!(a.len(), ((0.14_f32 * 22050.0) as usize) * 2);
        assert_eq!(a, b);
        assert!(a.iter().any(|&v| v != 0));
    }
}
