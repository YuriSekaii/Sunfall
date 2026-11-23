use std::collections::BTreeMap;

use godot::prelude::*;

struct SplitMix64(u64);

impl SplitMix64 {
    fn new(seed: u64) -> Self {
        Self(seed)
    }

    fn next_u64(&mut self) -> u64 {
        self.0 = self.0.wrapping_add(0x9E37_79B9_7F4A_7C15);
        let mut z = self.0;
        z = (z ^ (z >> 30)).wrapping_mul(0xBF58_476D_1CE4_E5B9);
        z = (z ^ (z >> 27)).wrapping_mul(0x94D0_49BB_1331_11EB);
        z ^ (z >> 31)
    }

    fn range_i32(&mut self, lo: i32, hi: i32) -> i32 {
        if hi <= lo {
            return lo;
        }
        let span = (hi - lo) as u64 + 1;
        lo + (self.next_u64() % span) as i32
    }

    fn next_f32(&mut self) -> f32 {
        ((self.next_u64() >> 40) as f32) * (1.0 / 16_777_216.0)
    }
}

struct LootEntry {
    item: &'static str,
    weight: i32,
    min: i32,
    max: i32,
}

struct PoolConfig {
    rolls_min: i32,
    rolls_max: i32,
    entries: &'static [LootEntry],
    weapon_chance: f32,
    max_weapon_tier: i32,
}

const CRASH_ENTRIES: &[LootEntry] = &[
    LootEntry { item: "wood", weight: 35, min: 2, max: 4 },
    LootEntry { item: "food", weight: 26, min: 1, max: 2 },
    LootEntry { item: "water", weight: 26, min: 1, max: 2 },
    LootEntry { item: "medkit", weight: 12, min: 1, max: 1 },
    LootEntry { item: "metal", weight: 10, min: 1, max: 2 },
];

const SUPPLY_ENTRIES: &[LootEntry] = &[
    LootEntry { item: "wood", weight: 34, min: 2, max: 5 },
    LootEntry { item: "metal", weight: 26, min: 1, max: 3 },
    LootEntry { item: "food", weight: 16, min: 1, max: 2 },
    LootEntry { item: "water", weight: 16, min: 1, max: 2 },
    LootEntry { item: "gunpowder", weight: 14, min: 1, max: 2 },
    LootEntry { item: "medkit", weight: 8, min: 1, max: 1 },
];

const LAB_ENTRIES: &[LootEntry] = &[
    LootEntry { item: "metal", weight: 34, min: 2, max: 5 },
    LootEntry { item: "gunpowder", weight: 30, min: 2, max: 4 },
    LootEntry { item: "medkit", weight: 20, min: 1, max: 2 },
    LootEntry { item: "wood", weight: 10, min: 2, max: 3 },
    LootEntry { item: "water", weight: 8, min: 1, max: 2 },
];

fn pool_config(pool: &str) -> PoolConfig {
    match pool {
        "crash" => PoolConfig {
            rolls_min: 2,
            rolls_max: 3,
            entries: CRASH_ENTRIES,
            weapon_chance: 0.18,
            max_weapon_tier: 2,
        },
        "lab" => PoolConfig {
            rolls_min: 3,
            rolls_max: 4,
            entries: LAB_ENTRIES,
            weapon_chance: 0.55,
            max_weapon_tier: 3,
        },
        _ => PoolConfig {
            rolls_min: 2,
            rolls_max: 4,
            entries: SUPPLY_ENTRIES,
            weapon_chance: 0.22,
            max_weapon_tier: 2,
        },
    }
}

pub fn roll_container_core(
    run_seed: i64,
    container_id: i64,
    pool: &str,
    day: i32,
) -> (BTreeMap<&'static str, i32>, i32) {
    let cfg = pool_config(pool);
    let mut pool_hash: i64 = 0;
    for ch in pool.chars() {
        pool_hash = pool_hash.wrapping_mul(31).wrapping_add(ch as i64);
    }
    let mixed = run_seed.wrapping_mul(73_856_093)
        ^ container_id.wrapping_mul(19_349_663)
        ^ (day as i64).wrapping_mul(83_492_791)
        ^ pool_hash;
    let mut rng = SplitMix64::new(mixed.unsigned_abs());

    let mut items: BTreeMap<&'static str, i32> = BTreeMap::new();
    let roll_count = rng.range_i32(cfg.rolls_min, cfg.rolls_max);
    let total_weight: i32 = cfg.entries.iter().map(|e| e.weight).sum();

    for _ in 0..roll_count {
        let pick = rng.range_i32(1, total_weight);
        let mut acc = 0;
        for entry in cfg.entries {
            acc += entry.weight;
            if pick <= acc {
                let qty = rng.range_i32(entry.min, entry.max);
                *items.entry(entry.item).or_insert(0) += qty;
                break;
            }
        }
    }

    let mut weapon_tier = 0;
    let bonus_chance = ((day - 1).max(0) as f32 * 0.03).min(0.20);
    if rng.next_f32() < cfg.weapon_chance + bonus_chance {
        if cfg.max_weapon_tier >= 3 && rng.next_f32() < if pool == "lab" { 0.45 } else { 0.15 } {
            weapon_tier = 3;
        } else {
            weapon_tier = 2;
        }
    }

    (items, weapon_tier)
}

#[derive(GodotClass)]
#[class(init, base=RefCounted)]
pub struct RustLootTable {
    base: Base<RefCounted>,
}

#[godot_api]
impl RustLootTable {
    #[func]
    pub fn weapon_stats(tier: i32) -> VarDictionary {
        let (name, damage, stamina_cost, reach, color) = match tier.clamp(1, 3) {
            2 => (
                "Salvaged Machete",
                38.0_f64,
                0.14_f64,
                2.6_f64,
                Color::from_rgb(0.75, 0.80, 0.86),
            ),
            3 => (
                "Lab Fire-Axe",
                58.0_f64,
                0.20_f64,
                2.85_f64,
                Color::from_rgb(0.86, 0.24, 0.20),
            ),
            _ => (
                "Rusty Pipe",
                24.0_f64,
                0.16_f64,
                2.4_f64,
                Color::from_rgb(0.58, 0.42, 0.32),
            ),
        };
        let mut d = VarDictionary::new();
        d.set("name", name);
        d.set("damage", damage);
        d.set("stamina_cost", stamina_cost);
        d.set("reach", reach);
        d.set("color", color);
        d
    }

    #[func]
    pub fn roll_container(
        run_seed: i64,
        container_id: i64,
        pool: GString,
        day: i32,
    ) -> VarDictionary {
        let pool_str = pool.to_string();
        let (items_map, weapon_tier) = roll_container_core(run_seed, container_id, &pool_str, day);

        let mut items = VarDictionary::new();
        for (k, v) in items_map {
            items.set(k, v);
        }

        let mut out = VarDictionary::new();
        out.set("items", &items);
        out.set("weapon_tier", weapon_tier);
        out
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rolls_are_deterministic_and_non_empty() {
        for pool in ["crash", "supply", "lab"] {
            let a = roll_container_core(42424, 7, pool, 1);
            let b = roll_container_core(42424, 7, pool, 1);
            assert_eq!(a, b);
            assert!(!a.0.is_empty());
        }
    }

    #[test]
    fn lab_pool_can_drop_tier_3_weapons() {
        let mut saw_t3 = false;
        for cid in 0..100 {
            let (_, tier) = roll_container_core(12345, cid, "lab", 5);
            if tier == 3 {
                saw_t3 = true;
                break;
            }
        }
        assert!(saw_t3);
    }
}
