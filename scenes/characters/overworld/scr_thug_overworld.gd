extends OverworldCharacter

const TWERP_SYNONYMS := ["twerp", "twerp", "twerp", "nitwit", "nincompoop", "sucker", "moron", "nullity", "insect"]
const ENGAGE_SYNONYMS := ["engage", "engage", "engage", "feature", "be involved", "be engrossed", "lose",]
const TUSSLE_SYNONYMS := ["tussle", "tussle", "tussle", "struggle", "scuffle", "brawl", "scramble"]
@onready var random_battle_component: RandomBattleComponent = $RandomBattleComponent


func _ready() -> void:
	super._ready()
	SOL.dialogue_box.dial_concat("thug_catch_1", 0, [TWERP_SYNONYMS.pick_random(), ENGAGE_SYNONYMS.pick_random(), TUSSLE_SYNONYMS.pick_random()])
	random_battle_component.set_level(ResMan.get_character("greg").level)
	battle_info = random_battle_component.get_battle()


func interacted() -> void:
	super()
	if not RunFlags.thugs_battled_changed:
		DAT.incri("thugs_fought", battle_info.enemies.size())
		RunFlags.thugs_battled_changed = true


