class_name BattleState extends RefCounted

var battle_over:           bool       = false
var is_player_turn:        bool       = false
var team_hp:               Dictionary = {}
var monster_moves_pp:      Dictionary = {}
var participated_monsters: Array      = []
var exp_boost_active:      bool       = false


func reset():
	battle_over           = false
	is_player_turn        = false
	exp_boost_active      = false
	team_hp.clear()
	monster_moves_pp.clear()
	participated_monsters.clear()


# Loads PP from SaveData so PP persists between battles
func init_pp(monster_id: String):
	if monster_moves_pp.has(monster_id):
		return
	var md: Dictionary    = GameData.get_monster(monster_id)
	var signature: String = md.get("signature_move", "")
	var active: Array     = SaveData.get_active_moves(monster_id)
	var saved: Dictionary = SaveData.get_instance_pp(monster_id)
	var pp: Dictionary    = {}
	for move_id in active:
		if saved.has(move_id):
			pp[move_id] = int(saved[move_id])
		else:
			var kind: String = GameData.get_move(move_id).get("kind", "")
			var is_sig: bool = (move_id == signature)
			if is_sig:                          pp[move_id] = 6
			elif kind in ["buff", "debuff"]:    pp[move_id] = 5
			else:                               pp[move_id] = 10
	monster_moves_pp[monster_id] = pp


func get_pp(monster_id: String, move_id: String, default_val: int = 10) -> int:
	return monster_moves_pp.get(monster_id, {}).get(move_id, default_val)


func use_pp(monster_id: String, move_id: String) -> int:
	var pp_dict: Dictionary = monster_moves_pp.get(monster_id, {})
	var cur: int            = pp_dict.get(move_id, 0)
	var next: int           = max(cur - 1, 0)
	pp_dict[move_id]                  = next
	monster_moves_pp[monster_id]      = pp_dict
	return next


func has_pp(monster_id: String, move_id: String) -> bool:
	return get_pp(monster_id, move_id) > 0


func mark_participated(monster_id: String):
	if monster_id not in participated_monsters:
		participated_monsters.append(monster_id)


func save_hp(monster_id: String, hp: int):
	team_hp[monster_id] = hp


# Returns -1 if HP was never saved (treat as full HP)
func saved_hp(monster_id: String) -> int:
	return team_hp.get(monster_id, -1)


func is_fainted(monster_id: String) -> bool:
	return team_hp.get(monster_id, -1) == 0
