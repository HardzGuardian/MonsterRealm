extends Node
class_name CombatCalculator

static func calculate_damage(attacker: Monster, defender: Monster, move_data: Dictionary) -> Dictionary:
	var accuracy: int = int(move_data.get("accuracy", 100))
	if randf() * 100.0 >= float(accuracy):
		return {"damage": 0, "is_crit": false, "multiplier": 1.0, "element": "", "missed": true}

	var base_power:   int    = attacker.get_attack_power() + int(move_data.get("power", 0))
	var move_element: String = move_data.get("element", attacker.monster_data.get("element", "none"))
	var def_element:  String = defender.monster_data.get("element", "none")
	var multiplier:   float  = GameData.get_effectiveness(move_element, def_element)

	var crit_chance: float = float(GameData.battle_cfg("crit_chance", 0.10))
	var crit_mult:   float = float(GameData.battle_cfg("crit_multiplier", 1.5))
	var is_crit:     bool  = randf() < crit_chance

	return {
		"damage":     int(base_power * multiplier * (crit_mult if is_crit else 1.0)),
		"is_crit":    is_crit,
		"multiplier": multiplier,
		"element":    move_element,
		"missed":     false
	}


static func calculate_capture_chance(enemy: Monster) -> float:
	var hp_pct:  float  = float(enemy.current_hp) / float(enemy.max_hp)
	var bonus:   float  = float(GameData.battle_cfg("capture_hp_bonus", 0.10))
	var cap_min: float  = float(GameData.battle_cfg("capture_min",       0.05))
	var cap_max: float  = float(GameData.battle_cfg("capture_max",       0.95))
	var base:    float  = clamp(1.0 - hp_pct + bonus, cap_min, cap_max)
	var rarity:  String = enemy.monster_data.get("rarity", "common")
	var rate:    float  = float(GameData.rarity_cfg(rarity).get("capture_rate", 1.0))
	return clamp(base * rate, cap_min, cap_max)
