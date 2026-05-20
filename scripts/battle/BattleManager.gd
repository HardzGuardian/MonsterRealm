extends Node
class_name BattleManager

# Speed sets the PROBABILITY of going first — faster = more likely, never guaranteed
static func determine_turn_order(player: Monster, enemy: Monster) -> Array:
	var ps: int = maxi(player.speed + player.speed_buff - player.speed_debuff, 1)
	var es: int = maxi(enemy.speed  + enemy.speed_buff  - enemy.speed_debuff,  1)
	var player_goes_first: bool = randf() < float(ps) / float(ps + es)
	return [player, enemy] if player_goes_first else [enemy, player]


static func select_enemy_move(enemy: Monster, player: Monster) -> String:
	var moves: Array = enemy.moves
	if moves.is_empty(): return "basic_attack"

	var enemy_hp_pct: float  = float(enemy.current_hp) / float(enemy.max_hp)
	var player_hp_pct: float = float(player.current_hp) / float(player.max_hp)
	var difficulty: int      = enemy.level

	# Easy (level <= 5): fully random
	if difficulty <= 5:
		return moves[randi() % moves.size()]

	# 1. Heal self if HP critical
	if enemy_hp_pct < 0.3:
		for mid in moves:
			var mv: Dictionary = GameData.get_move(mid)
			if mv.get("kind","") == "buff" and mv.get("stat","") == "hp":
				return mid

	# 2. Hard (level 16+): use debuffs and status strategically
	if difficulty >= 16:
		if player.poison_turns == 0 and player_hp_pct > 0.6:
			for mid in moves:
				var mv: Dictionary = GameData.get_move(mid)
				if mv.get("status_effect","") == "poison":
					return mid

		# Apply paralysis if player is faster
		var p_eff_spd := player.speed + player.speed_buff - player.speed_debuff
		var e_eff_spd := enemy.speed  + enemy.speed_buff  - enemy.speed_debuff
		if player.paralysis_turns == 0 and p_eff_spd > e_eff_spd:
			for mid in moves:
				var mv: Dictionary = GameData.get_move(mid)
				if mv.get("status_effect","") == "paralysis":
					return mid

		if player_hp_pct > 0.7 and player.attack_debuff_turns == 0:
			for mid in moves:
				var mv: Dictionary = GameData.get_move(mid)
				if mv.get("kind","") == "debuff" and mv.get("stat","") == "attack":
					return mid

		if enemy.attack_buff_turns == 0 and enemy_hp_pct > 0.5:
			for mid in moves:
				var mv: Dictionary = GameData.get_move(mid)
				if mv.get("kind","") == "buff" and mv.get("stat","") == "attack":
					return mid

	# 3. Use super-effective damage move
	var player_element: String = player.monster_data.get("element","none")
	for mid in moves:
		var mv: Dictionary = GameData.get_move(mid)
		if mv.get("kind","") == "damage":
			var move_elem: String = mv.get("element", enemy.monster_data.get("element","none"))
			if GameData.get_effectiveness(move_elem, player_element) > 1.0:
				return mid

	# 4. Use signature move if available
	var sig: String = enemy.monster_data.get("signature_move","")
	if sig != "" and sig in moves and enemy.moves.has(sig):
		return sig

	# 5. Fallback random
	return moves[randi() % moves.size()]
