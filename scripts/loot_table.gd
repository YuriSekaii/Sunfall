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
	return RustLootTable.weapon_stats(tier)


static func roll_container(run_seed: int, container_id: int, pool: String, day: int) -> Dictionary:
	return RustLootTable.roll_container(run_seed, container_id, pool, day)
