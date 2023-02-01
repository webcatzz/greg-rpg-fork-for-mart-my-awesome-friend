extends Node

# handles data, saving and loading it

const CHAR_PATH := "res://resources/characters/res_%s."
const ITEM_PATH := "res://resources/items/res_%s."
const SPIRIT_PATH := "res://resources/spirits/res_%s."

# DATA
var A : Dictionary

@export_multiline var character_list : String = ""
var character_dict := {}
@export_multiline var item_list : String = ""
var item_dict := {}
@export_multiline var spirit_list : String = ""
var spirit_dict := {}
const MAX_SPIRITS := 3


func _init() -> void:
	print("DAT init")


func _ready() -> void:
	load_characters()
	load_items()
	load_spirits()
	print(character_dict)
	print(item_dict)
	print(spirit_dict)


func load_characters() -> void:
	for s in character_list.split("\n"):
		if DIR.file_exists(get_char_path(s), true):
			character_dict[s] = load(get_char_path(s)) as Character
			character_dict[s].name_in_file = s
			print("loaded character ", s)


func load_items() -> void:
	for s in item_list.split("\n"):
		if DIR.file_exists(get_item_path(s), true):
			item_dict[s] = load(get_item_path(s)) as Item
			item_dict[s].name_in_file = s
			print("loaded item ", s)


func load_spirits() -> void:
	for s in spirit_list.split("\n"):
		if DIR.file_exists(get_spirit_path(s), true):
			spirit_dict[s] = load(get_spirit_path(s)) as Spirit
			spirit_dict[s].name_in_file = s
			print("loaded spirit ", s)


# entry point for a new game.
func start_game() -> void:
	set_data("party", [0])
	LTS.level_transition("res://scenes/rooms/scn_room_test.tscn")


func set_data(key, value) -> void:
	A[key] = value


func get_data(key: String, default = null):
	return A.get(key, default)


func save_data(filename := "save.grs") -> void:
	save_nodes_data()
	save_chars_to_data()
	
	var stuff := DIR.get_dict_from_file(filename)
	for k in A.keys():
		stuff[k] = A[k]
	
	DIR.write_dict_to_file(stuff, filename)


func force_data(key: String, value: Variant, filename := "save.grs") -> void:
	var stuff := DIR.get_dict_from_file(filename)
	
	stuff[key] = value
	DIR.write_dict_to_file(stuff, filename)
	
	print("forced key %s and value %s to file %s" % [key, value, filename])


func save_nodes_data() -> void:
	print("saving nodes...")
	var saveables := get_tree().get_nodes_in_group("save_me")
	for node in saveables:
		if is_instance_valid(node) and node.has_method("_save_me"):
			node._save_me()
	print("node saving end.")


func load_data(filename := "save.grs") -> void:
	var loaded := DIR.get_dict_from_file(filename)
	if loaded.size() < 1: print("no data to load!"); return
	
	print("overwriting data...")
	for k in loaded.keys():
		A[k] = loaded[k]
	print("finished overwriting data.")
	
	load_chars_from_data()
	
	var room_to_load : String = loaded.get("current_room", "test")
	LTS.gate_id = LTS.GATE_LOADING
	LTS.change_scene_to(LTS.ROOM_SCENE_PATH % room_to_load)
	SOL.fade_screen(Color(0, 0, 0, 1), Color(0, 0, 0, 0), 0.5)


func print_data() -> void:
	print(A)


func capture_player() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		players[0].state = PlayerOverworld.States.NOT_FREE_MOVE
		print(players[0].name, " captured")


func free_player() -> void:
	var players : Array = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		players[0].state = PlayerOverworld.States.FREE_MOVE
		print(players[0].name, " freed")


func get_current_scene() -> Node:
	return get_tree().root.get_child(-1)


func get_character(key: String) -> Character:
	if not key in character_dict:
		return load("res://resources/characters/res_default_character.tres")
	return character_dict[key]


func char_save_string_key(which: int, key: String) -> String:
	return str("char_", which, "_", key)


func save_chars_to_data() -> void:
	print("saving characters...")
	for c in character_dict:
		var charc : Character = character_dict[c]
		set_data(char_save_string_key(c, "save"), charc.get_saveable_dict())
	print("finished saving characters.")


func load_chars_from_data() -> void:
	print("loading characters...")
	for c in character_dict:
		var charc : Character = character_dict[c]
		charc.load_from_dict(get_data(char_save_string_key(c, "save"), {}))
	print("finished loading characters.")


func get_item(id: String) -> Item:
	if not id in item_dict: return preload("res://resources/items/res_default_item.tres")
	return item_dict[id]


func get_spirit(id: String) -> Spirit:
	if not id in spirit_dict: return preload("res://resources/res_default_spirit.tres")
	return spirit_dict[id]


func get_char_path(charname : String) -> String:
	if DIR.standalone():
		return CHAR_PATH % charname + "tres.remap"
	return CHAR_PATH % charname + "tres"


func get_item_path(itemname : String) -> String:
	if DIR.standalone():
		return ITEM_PATH % itemname + "tres.remap"
	return ITEM_PATH % itemname + "tres"


func get_spirit_path(spiritname : String) -> String:
	if DIR.standalone():
		return SPIRIT_PATH % spiritname + "tres.remap"
	return SPIRIT_PATH % spiritname + "tres"
