class_name LootTable
extends RefCounted

const WEAPONS := {
	1: {
		"name": "Rusty Pipe",
		"damage": 24.0,
		"stamina_cost": 0.16,
		"reach": 2.4,
		"color": Color(0.58, 0.42, 0.32),
	},
	2: {
		"name": "Salvaged Machete",
		"damage": 38.0,
		"stamina_cost": 0.14,
		"reach": 2.6,
		"color": Color(0.75, 0.80, 0.86),
	},
	3: {
		"name": "Lab Fire-Axe",
		"damage": 58.0,
		"stamina_cost": 0.20,
		"reach": 2.85,
		"color": Color(0.86, 0.24, 0.20),
	},
}

const POOLS := {
	"crash": {
		"rolls": [2, 3],
		"entries": [
			{"item": "wood", "weight": 35, "min": 2, "max": 4},
			{"item": "food", "weight": 26, "min": 1, "max": 2},
			{"item": "water", "weight": 26, "min": 1, "max": 2},
			{"item": "medkit", "weight": 12, "min": 1, "max": 1},
			{"item": "metal", "weight": 10, "min": 1, "max": 2},
		],
		"weapon_chance": 0.18,
		"max_weapon_tier": 2,
	},
	"supply": {
		"rolls": [2, 4],
		"entries": [
			{"item": "wood", "weight": 34, "min": 2, "max": 5},
			{"item": "metal", "weight": 26, "min": 1, "max": 3},
			{"item": "food", "weight": 16, "min": 1, "max": 2},
			{"item": "water", "weight": 16, "min": 1, "max": 2},
			{"item": "gunpowder", "weight": 14, "min": 1, "max": 2},
			{"item": "medkit", "weight": 8, "min": 1, "max": 1},
		],
		"weapon_chance": 0.22,
		"max_weapon_tier": 2,
	},
	"lab": {
		"rolls": [3, 4],
		"entries": [
			{"item": "metal", "weight": 34, "min": 2, "max": 5},
			{"item": "gunpowder", "weight": 30, "min": 2, "max": 4},
			{"item": "medkit", "weight": 20, "min": 1, "max": 2},
			{"item": "wood", "weight": 10, "min": 2, "max": 3},
			{"item": "water", "weight": 8, "min": 1, "max": 2},
		],
		"weapon_chance": 0.55,
		"max_weapon_tier": 3,
	},
}


static func weapon_stats(tier: int) -> Dictionary:
	return WEAPONS.get(clampi(tier, 1, 3), WEAPONS[1])


static func roll_container(run_seed: int, container_id: int, pool: String, day: int) -> Dictionary:
	var cfg: Dictionary = POOLS.get(pool, POOLS["supply"])
	var rng := RandomNumberGenerator.new()
	var pool_hash := 0
	for i in pool.length():
		pool_hash = pool_hash * 31 + pool.unicode_at(i)
	rng.seed = abs(run_seed * 73856093 ^ container_id * 19349663 ^ day * 83492791 ^ pool_hash)

	var items: Dictionary = {}
	var roll_range: Array = cfg["rolls"]
	var roll_count := rng.randi_range(roll_range[0], roll_range[1])
	var entries: Array = cfg["entries"]
	var total_weight := 0
	for entry in entries:
		total_weight += int(entry["weight"])

	for _r in roll_count:
		var pick := rng.randi_range(1, total_weight)
		var acc := 0
		for entry in entries:
			acc += int(entry["weight"])
			if pick <= acc:
				var item_name: String = entry["item"]
				var qty := rng.randi_range(int(entry["min"]), int(entry["max"]))
				items[item_name] = int(items.get(item_name, 0)) + qty
				break

	var weapon_tier := 0
	var bonus_chance := minf(0.20, float(maxi(0, day - 1)) * 0.03)
	if rng.randf() < float(cfg["weapon_chance"]) + bonus_chance:
		var max_t := int(cfg["max_weapon_tier"])
		if max_t >= 3 and rng.randf() < (0.45 if pool == "lab" else 0.15):
			weapon_tier = 3
		else:
			weapon_tier = 2

	return {
		"items": items,
		"weapon_tier": weapon_tier,
	}
