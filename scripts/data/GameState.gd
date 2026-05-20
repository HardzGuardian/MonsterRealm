extends Node

const HOME_SCENE := "res://scenes/home/Home.tscn"
const WORLD_MAP_SCENE := "res://scenes/map/WorldMap.tscn"
const BATTLE_SCENE := "res://scenes/battle/battle.tscn"

var selected_level_id := "level_1"


func go_home():
	get_tree().change_scene_to_file(HOME_SCENE)


func go_world_map():
	get_tree().change_scene_to_file(WORLD_MAP_SCENE)


func start_level(level_id: String):
	selected_level_id = level_id
	get_tree().change_scene_to_file(BATTLE_SCENE)


func finish_level():
	SaveData.complete_level(selected_level_id)
	go_world_map()
