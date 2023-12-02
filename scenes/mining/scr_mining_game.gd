class_name MiningGame extends Node2D

const TileDefinitions := preload("res://scenes/mining/resources/scr_tile_definitions.gd")

@onready var tiles := $Tiles
@onready var wall := $Wall
@onready var greg := $GregPlatform as PlatformerGreg
@onready var camera: Camera2D = $GregPlatform/Camera
@onready var update_timer: Timer = $UpdateTimer

var hole_noise := preload("res://scenes/mining/resources/hole_noise.tres")
var cave_noise_thin := preload("res://scenes/mining/resources/cave_noise_thin.tres")
var main_tunnel_noise := preload("res://scenes/mining/resources/main_tunnel_noise.tres")
var water_noise := preload("res://scenes/mining/resources/water_noise.tres")
var gas_noise := preload("res://scenes/mining/resources/gas_noise.tres")

# in tiles
var map_height := 200
var map_width := 20
var start_height := 15
const TSIZE := 8

# tile behaviour
const NEIGHBOURS : Array[Vector2i] = [
	Vector2i(0, 1),
	Vector2i(0, -1),
	Vector2i(1, 1),
	Vector2i(-1, 1),
	Vector2i(1, -1),
	Vector2i(-1, -1),
	Vector2i(1, 0),
	Vector2i(-1, 0),
]
const FLOW_LIQUID_DOWN : Array[Vector2i] = [
	Vector2i(0, 1),
	Vector2i(1, 0),
	Vector2i(-1, 0),
]
const FLOW_GAS_UP : Array[Vector2i] = [
	Vector2i(0, -1),
	Vector2i(1, 0),
	Vector2i(-1, 0),
]



func _ready() -> void:
	update_timer.timeout.connect(_update_timer)
	update_timer.start(0.1)
	mapgen()


func _physics_process(_delta: float) -> void:
	wall.global_position.y = greg.global_position.y


func mapgen() -> void:
	hole_noise.seed = randi()
	cave_noise_thin.seed = randi()
	main_tunnel_noise.seed = randi()
	water_noise.seed = randi()
	gas_noise.seed = randi()
	
	for yi in map_height:
		for xi in map_width:
			var y := yi + start_height
			var x := xi
			var pos := Vector2i(x, y)
			if not check_cave(x, y):
				if not check_dirt(x, y):
					set_cell(pos, TileDefinitions.STONE)
				else:
					set_cell_terrain(pos, 5)
			else:
				if water_noise.get_noise_2d(x, y) >= 0.8:
					set_cell(pos, TileDefinitions.WATER)
				elif gas_noise.get_noise_2d(x, y) >= 0.35 and y >= (map_height + start_height) * 0.65:
					set_cell(pos, TileDefinitions.GAS)
	camera.limit_bottom = map_height * TSIZE + 20 * TSIZE

	for x in 400:
		update_map()


func check_cave(x: int, y: int) -> bool:
	if x <= 0 or x >= map_width - 1: return false
	if y <= (-(x - map_width / 2)**2) / 4.0 + 30: return true
	if hole_noise.get_noise_2d(x, y) < -0.36: return true
	if Math.inrange(main_tunnel_noise.get_noise_1d(
		y * cave_noise_thin.get_noise_2d(x, y)) * TSIZE + map_width * 0.5, x - 2, x + 2): return true
	return false


func check_dirt(x: int, y: int) -> bool:
	if y < 30: return true
	return false


func update_map() -> void:
	var time := Time.get_ticks_msec()
	
#	for x in map_width:
#		for y in map_height:
#			x = x
#			y += start_height
#			var coord := Vector2i(x, y)
	
	for w in get_cells_by_definition(TileDefinitions.WATER):
		var pos := Vector2i(w)
		tile_flowing(pos, TileDefinitions.WATER, FLOW_LIQUID_DOWN, [3, 4])
	for w in get_cells_by_definition(TileDefinitions.GAS):
		var pos := Vector2i(w)
		tile_flowing(pos, TileDefinitions.GAS, FLOW_GAS_UP)
	for f in get_cells_by_definition(TileDefinitions.FIRE):
		var pos := Vector2i(f)
		fire_works(f)
	
	#print("finished map update: ", Time.get_ticks_msec() - time)


func tile_flowing(pos: Vector2i, definition: TileDefinitions.Tile, neighbors: Array[Vector2i], extra_air := []) -> void:
	if pos.y > map_height + start_height:
		tiles.erase_cell(0, pos)
		return
	if pos.y < 0:
		tiles.erase_cell(0, pos)
		return
	for n: Vector2i in neighbors:
		if is_air(pos + n, extra_air):
			tiles.erase_cell(0, pos)
			if randf() <= 0.01: return
			set_cell(pos + n, definition)
			return


func fire_works(pos: Vector2i) -> void:
	if randf() <= 0.5:
		set_cell(pos, TileDefinitions.FIRE)
	if randf() <= 0.05:
		tiles.erase_cell(0, pos)
		return
	var neigs := NEIGHBOURS.duplicate()
	neigs.shuffle()
	for n in neigs:
		var cell := get_cell(pos + n)
		if randf() < cell.flammability:
			set_cell(pos + n, TileDefinitions.FIRE)
			break
		if randf() <= 0.2 and cell == TileDefinitions.INVALID:
			set_cell(pos + n, TileDefinitions.FIRE)
			tiles.erase_cell(0, pos)
			break


func _update_timer() -> void:
	update_map()


func set_cell(coords: Vector2i, tile: TileDefinitions.Tile) -> void:
	tiles.set_cell(0, coords, 0, tile.atlas)


func set_cell_terrain(coords: Vector2i, terrain_id: int) -> void:
	tiles.set_cells_terrain_connect(0, [coords], 0, terrain_id)


func get_cell(pos: Vector2i) -> TileDefinitions.Tile:
	var tiledata := tiles.get_cell_tile_data(0, pos) as TileData
	var terrain := tiledata.terrain if tiledata else -1
	return TileDefinitions.tile(terrain)


func is_air(coords: Vector2i, extra_defs := []) -> bool:
	return (
		tiles.get_cell_tile_data(0, coords) == null or
		tiles.get_cell_tile_data(0, coords).terrain in extra_defs
	)


func get_cells_by_definition(tile: TileDefinitions.Tile) -> Array[Vector2i]:
	var arr : Array[Vector2i]
	for at in tile._random_atlases:
		arr.append_array(tiles.get_used_cells_by_id(0, 0, at))
	return arr
