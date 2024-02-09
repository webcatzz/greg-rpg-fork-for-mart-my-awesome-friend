extends OverworldCharacter

var difficulty := 0.0

@onready var random_battle_component: RandomBattleComponent = $RandomBattleComponent


func _ready() -> void:
	super._ready()
	battle_info.set_start_text(["ravenous.", "hungry.", "wild.", "rampaging.",
	"found you.", "life."].pick_random())


func interacted() -> void:
	if DAT.player_capturers.size() > 0: return
	interactions += 1
	inspected.emit()
	LTS.enter_battle(battle_info, {"wait_time": 2.0, "play_fanfare": false, "kill_music": false})
	set_physics_process(false)

