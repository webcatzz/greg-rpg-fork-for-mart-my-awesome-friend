extends BattleEnemy


func _ready() -> void:
	super._ready()


func act() -> void:
	var greg: BattleActor = reference_to_opposing_array[0]
	message.emit("grandma attacked greg!")
	for i in 400:
		greg.hurt(1, Genders.VAST)
		await get_tree().process_frame
		if greg.character.health_perc() < 0.1:
			break
	SND.play_song("")
	DAT.set_data("fought_grandma", true)
	DAT.set_data("intro_progress", 2)
	LTS.gate_id = LTS.GATE_EXIT_BATTLE
	await get_tree().create_timer(2.5).timeout
	LTS.level_transition(LTS.ROOM_SCENE_PATH % "grandma_house_inside")


func _item_diploma_used_on() -> void:
	SOL.dialogue("grandma_diploma_use")
