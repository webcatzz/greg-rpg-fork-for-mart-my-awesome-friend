extends Node

# handles access to files

var R := ResourceLoader

const GREG_USER_FOLDER_PATH := "user://greg_rpg"
const ENEMY_SCENE_PATH := "res://scenes/characters/battle_enemies/scn_enemy_%s.tscn"
const ROOM_SCENE_PATH := "res://scenes/rooms/scn_room_%s.tscn"
const BATTLE_BACKGROUND_SCENE_PATH := "res://scenes/battle_backgrounds/scn_%s.tscn"
const TSCN := ".tscn"

# absolute file path constants
const CHAR_PATH := "res://resources/characters/res_%s"
const ITEM_PATH := "res://resources/items/res_%s"
const SPIRIT_PATH := "res://resources/spirits/res_%s"


func _init() -> void:
	print("project is standalone" if standalone() else "project is editor version")
	# assure that a greg_rpg folder exists in user data
	if not DirAccess.dir_exists_absolute(GREG_USER_FOLDER_PATH):
		DirAccess.make_dir_absolute(GREG_USER_FOLDER_PATH)
	if not FileAccess.file_exists(GREG_USER_FOLDER_PATH + "/pers"):
		write_dict_to_file({}, "pers")


func standalone() -> bool:
	return not OS.has_feature("editor")


# dicts are stored to file in the format provided by var2bytes
# rather unreadable
func write_dict_to_file(data: Dictionary, filename: String) -> void:
	var file := FileAccess.open(str(GREG_USER_FOLDER_PATH, "/", filename), FileAccess.WRITE)
	file.store_var(var_to_bytes(data))
	file.flush()


func get_dict_from_file(filename: String) -> Dictionary:
	if not FileAccess.file_exists(str(GREG_USER_FOLDER_PATH, "/", filename)):
		printerr("no %s file exists" % filename)
		return {}
	var file := FileAccess.open(str(GREG_USER_FOLDER_PATH, "/", filename), FileAccess.READ)
	var returnable: Dictionary = bytes_to_var(file.get_var())
	return returnable


func enemy_scene_exists(name_in_file: String) -> bool:
	var dir := get_dir_contents("res://scenes/characters/battle_enemies/", "scn_enemy_")
	return name_in_file in dir


func spirit_hint_exists(name_in_file: String) -> bool:
	var dir := get_dir_contents("res://scenes/vfx/", "sfr_spirit_")
	return name_in_file in dir


# this feels a bit redundant but the complain functionality might be useful
func file_exists(path, complain := false) -> bool:
	if FileAccess.file_exists(path):
		return true
	if complain: printerr("path %s does not exist" % path)
	return false


# these are all shorter than calling DIR.CHAR_PATH % charname. I think.
func get_char_path(charname: String) -> String:
	return CHAR_PATH % charname + ".tres"


func get_item_path(itemname: String) -> String:
	return ITEM_PATH % itemname + ".tres"


func get_spirit_path(spiritname: String) -> String:
	return SPIRIT_PATH % spiritname + ".tres"


func enemy_scene_path(name_in_file: String) -> String:
	return str(ENEMY_SCENE_PATH % name_in_file)


func room_scene_path(id: String) -> String:
	return ROOM_SCENE_PATH % id


func battle_background_scene_path(id: String) -> String:
	return BATTLE_BACKGROUND_SCENE_PATH % id


func battle_background_scene_exists(id: String) -> bool:
	return R.exists(battle_background_scene_path(id), "PackedScene")


func room_exists(id: String) -> bool:
	return R.exists(ROOM_SCENE_PATH % id, "PackedScene")


func get_dialogue_file() -> String:
	var file := FileAccess.open("res://resources/res_dialogue.txt", FileAccess.READ)
	return file.get_as_text()


func portrait_exists(id: String) -> bool:
	return R.exists("res://sprites/characters/portraits/spr_portrait_%s.png" % id)


# copied from somewhere and adjusted a bit
func get_dir_contents(path: String, trim: String = "") -> Array[String]:
	var contents: Array[String] = []
	var dir := DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				pass
			else:
				# fuck you and your file suffix
				contents.append(file_name.get_basename().get_basename().get_basename().get_basename().trim_prefix(trim))
			file_name = dir.get_next()
		return contents
	else:
		printerr("path %s not good!" % path)
		return contents


# custom cat names can be loaded from user://greg/custom/cats.txt
func load_cat_names() -> Array:
	var path_internal = "res://resources/res_cats.txt"
	var path_external = "user://greg_rpg/cats.txt"
	var F := FileAccess
	var fail: FileAccess
	if F.file_exists(path_external):
		print_debug("custom cats.txt exists")
		fail = F.open(path_external, FileAccess.READ)
	else: # if cats.txt in custom doesn't exist, create it
		print_debug("custom cats.txt does not exist")
		if not F.file_exists(path_internal):
			printerr("cat names file does not exist")
			return []
		fail = F.open(path_internal, FileAccess.READ)
		var string := fail.get_as_text()
		fail = F.open(path_external, FileAccess.WRITE)
		print(error_string(F.get_open_error()))
		fail.store_string(string)
		fail = F.open(path_external, FileAccess.READ)
	var list := []
	while not fail.eof_reached():
		list.append(fail.get_line().replace("\t", "").replace("\n", ""))
	if len(list) < 1:
		print_debug("no cat names available.")
		return []
	print_debug("found %s cat names" % list.size())
	return Array(list)


func gej(k: int,
d: Variant = null) \
-> Variant: return\
get_dict_from_file("pers")\
.get(k, d)


func sej(
k: int, t: Variant) -> void: var o :\
= get_dict_from_file("pers"); o\
[k] = t; write_dict_to_file(o, "pers")


func incj(k: int, a: int
) -> void:
	var o:\
	= get_dict_from_file("pers"); o[k] = o.get(k, 0) + a\
	; write_dict_to_file(o, "pers")


func appj(k: int, t: Variant)\
 ->void:var o := get_dict_from_file("pers");\
			o\
	[k] = Math.reaap(
			o.get(k, []),
	t);write_dict_to_file(
			o,
	"pers")


func screenshot() -> void:
	if not DirAccess.dir_exists_absolute("user://greg_rpg/screenshots"):
		DirAccess.make_dir_absolute("user://greg_rpg/screenshots")
	var img := get_viewport().get_texture().get_image()
	img.save_png(
		"user://greg_rpg/screenshots/" + str(hash(img)) + ".png"
	)
