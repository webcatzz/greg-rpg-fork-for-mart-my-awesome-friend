extends Resource
class_name Character

# this will be interpreted by the battle system and dialogue system

const UPGRADE_MIN := {
	"attack": 1, "defense": 1, "speed": 1, "max_health": 100, "max_magic": 30
}

const UPGRADE_MAX := {
	"attack": 99, "defense": 99, "speed": 99, "max_health": 200, "max_magic": 200
}

@export var id_name : StringName = &""

@export_group("Appearance")
@export var name := ""
@export var voice_sound : AudioStream
@export var portrait : Texture

@export_group("Stats")
@export var max_health := 100.0
@export var health := 100.0
@export var max_magic := 30.0
@export var magic := 30.0

@export_range(1, 99) var level := 1
var experience := 0
@export_range(1.0, 99.0) var attack := 1.0
@export_range(1.0, 99.0) var defense := 1.0
@export_range(1.0, 99.0) var speed := 1.0

@export_group("Items and Spirits")
@export var inventory : Array[int] = []
@export var spirits : Array[int] = []
@export var unused_sprits: Array[int] = []
@export var armour : int = -1
@export var weapon : int = -1


func get_saveable_dict() -> Dictionary:
	return {
		"max_health": max_health,
		"health": health,
		"max_magic": max_magic,
		"magic": magic,
		"level": level,
		"experience": experience,
		"attack": attack,
		"defense": defense,
		"speed": speed,
		"inventory": inventory,
		"spirits": spirits,
		"unused_sprits": unused_sprits,
		"armour": armour,
		"weapon": weapon,
	}


func load_from_dict(dict: Dictionary) -> void:
	for k in dict.keys():
		set(k, dict[k])


func get_stat(nimi: String) -> int:
	return roundi(get(nimi) + (DAT.get_item(armour).payload.get("%s_increase" % nimi) if armour > -1 else 0) + (DAT.get_item(weapon).payload.get("%s_increase" % nimi) if weapon > -1 else 0))


func xp2lvl(lvl: int) -> float:
	var lvlpow := lvl**1.8
	var lvldiv := lvlpow/55.0
	return lvl * 1.3 + lvldiv


func add_experience(amount: int) -> void:
	for i in amount:
		experience += 1
		if experience >= xp2lvl(level):
			experience = 0
			level_up()


func level_up(by := 1, overflow := false) -> void:
	if by < 1: return
	for t in by:
		if level >= 99 and not overflow: return
		level += 1
		var upgrades := {
			"attack": 0, "defense": 0, "speed": 0, "max_health": 0, "max_magic": 0
		}
		var upgrade_chance := max(((99 - pow(level, 2)/167.0)/100.0) - randf()*0.33, 0)
		for k in upgrades:
			
			var perfect_inc : float = (UPGRADE_MAX[k]-UPGRADE_MIN[k])/99.0
			var perfect_stat : float = (
				(UPGRADE_MAX[k]-UPGRADE_MIN[k])/99.0 * level
			) + UPGRADE_MIN[k] - 1
			
			if level % 11 == 0:
				set(k, roundf(perfect_stat))
			else:
				set(k, roundf(get(k) + (perfect_inc * upgrade_chance)))
			if level == 99:
				set(k, roundf(UPGRADE_MAX[k]))
	
	for i in get_saveable_dict():
		print(i,": ", get(i))
	
	SOL.dialogue_box.adjust_line("levelup", 1, "%s leveled up to %s." % [name, level])
	SOL.dialogue("levelup")


func handle_payload(pld: BattlePayload) -> void:
	var health_change := 0.0
	health_change += pld.health
	health_change += pld.health_percent / 100.0 * health
	health_change += pld.max_health_percent / 100.0 * max_health
	if health_change:
		health = mini(health + health_change, max_health)
	
	magic = mini(magic + pld.magic + (pld.magic_percent / 100.0 * magic) + (pld.max_magic_percent / 100.0 * max_magic), max_magic)
	

