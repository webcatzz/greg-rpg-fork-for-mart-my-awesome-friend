extends Node2D
class_name BattleActor

const WAIT_AFTER_ATTACK := 1.0
const WAIT_AFTER_SPIRIT := 1.0
const WAIT_AFTER_SPIRIT_MULTI_ATTACK := 0.1
const WAIT_AFTER_ITEM := 1.00

signal message(msg: String)
signal act_requested(by_whom: BattleActor)
signal act_finished(by_whom: BattleActor)
signal player_input_requested(by_whom: BattleActor)
signal died(who: BattleActor)

enum States {IDLE = -1, COOLDOWN, ACTING, DEAD}
var state : States = States.IDLE : set = set_state

@export var character_id : int = -1
var actor_name : StringName
@onready var character : Character

var status_effects : Dictionary = {}

var reference_to_team_array : Array[BattleActor] = []
var reference_to_opposing_array : Array[BattleActor] = []
var reference_to_actor_array : Array[BattleActor] = []

var player_controlled := false

var wait := 1.0

@export_group("Other")
@export_range(0.0, 1.0) var stat_multiplier: = 1.0


func _ready() -> void:
	print(self, " character loaded")
	character = load_character(character_id)
	actor_name = character.name


func _physics_process(delta: float) -> void:
	if SOL.dialogue_open: return
	match state:
		States.IDLE:
			pass
		States.COOLDOWN:
			wait = maxf(wait - sqrt(delta * get_speed() * 0.1), 0.0)
			if wait == 0.0:
				act_requested.emit(self)
				set_state(States.ACTING)
		States.ACTING:
			pass
		States.DEAD:
			pass


func act() -> void:
	set_state(States.ACTING)
	wait = 1.0
	print(actor_name, " is acting!")
	if player_controlled:
		player_input_requested.emit(self)
		return


func set_state(to: States) -> void:
	if not state == States.DEAD:
		state = to


func heal(amount: float) -> void:
	character.health = minf(character.health + amount, character.max_health)


func hurt(amount: float) -> void:
	character.health = maxf(character.health - absf(amount), 0.0)
	if character.health <= 0.0:
		state = States.DEAD
		global_position.y += 2
		SND.play_sound(preload("res://sounds/snd_hurt.ogg"), {"pitch": 0.5})
		died.emit(self)
	else:
		SND.play_sound(preload("res://sounds/snd_hurt.ogg"), {"pitch": lerpf(2.0, 0.5, remap(amount, 1, 90, 0, 1)), "volume": randi_range(-10, 0)})


func get_attack() -> float:
	var x := 0.0
	x += character.get_stat("attack")
	if status_effects.get("attack", {}):
		x += status_effects.get("attack").get("strength")
	return maxf(x, 1) * stat_multiplier


func get_defense() -> float:
	var x := 0.0
	x += character.get_stat("defense")
	if status_effects.get("defense", {}):
		x += status_effects.get("defense").get("strength")
	return maxf(x, 1) * stat_multiplier


func get_speed() -> float:
	var x := 0.0
	x += character.get_stat("speed")
	if status_effects.get("speed", {}):
		x += status_effects.get("speed").get("strength")
	return maxf(x, 1) * stat_multiplier


static func calc_attack_damage(atk: float, random := true) -> float:
	var x := 0.0
	x += atk
	if random: x += randf() * 2
	var y := roundf(Math.method_29193(x))
	return y


func account_defense(x: float) -> float:
	var def := get_defense()
	var result := maxf(abs(x) - sqrt(def), 1)
	return roundf(result)


func attack(subject: BattleActor) -> void:
	var pld := payload().set_health(-BattleActor.calc_attack_damage(get_attack()))
	subject.handle_payload(pld)
	SOL.vfx("dustpuff", get_effect_center(subject), {parent = subject, free_time = 1.0})
	SOL.vfx("bangspark", get_effect_center(subject), {parent = subject, random_rotation = true})
	SND.play_sound(preload("res://sounds/snd_attack_blunt.ogg"))
	emit_message("%s attacked %s" % [actor_name, subject.actor_name])
	
	await get_tree().create_timer(WAIT_AFTER_ATTACK).timeout
	turn_finished()


func use_spirit(id: int, subject: BattleActor) -> void:
	var spirit : Spirit = DAT.get_spirit(id)
	character.magic = max(character.magic - spirit.cost, 0)
	emit_message("%s: %s!" % [actor_name, spirit.name])
	# animating
	if spirit.animation:
		SOL.vfx(spirit.animation, Vector2())
	if spirit.use_animation:
		SOL.vfx(spirit.use_animation, get_effect_center(self))
	# who should be targeted by the spirit
	var targets : Array[BattleActor]
	if spirit.reach == Spirit.Reach.TEAM:
		targets = subject.get_team().duplicate()
	elif spirit.reach == Spirit.Reach.ALL:
		targets = reference_to_actor_array.duplicate()
	else:
		targets = [subject]
	print(targets)
	# all targets
	for receiver in targets:
		if spirit.receive_animation:
			SOL.vfx(spirit.receive_animation, get_effect_center(receiver), {parent = receiver})
		for i in spirit.payload_reception_count:
			receiver.handle_payload(spirit.payload.set_sender(self))
			# we wait a bit before applying the payload again
			await get_tree().create_timer(
					(maxf(WAIT_AFTER_SPIRIT - 0.8, 0.2)) / float(spirit.payload_reception_count)
			).timeout
	
	await get_tree().create_timer(WAIT_AFTER_SPIRIT).timeout
	turn_finished()


func use_item(id: int, subject: BattleActor) -> void:
	var item : Item = DAT.get_item(id)
	if not id in item.USES_EQUIPABLE:
		subject.handle_payload(item.payload.set_sender(self))
		SOL.vfx("use_item", get_effect_center(subject), {parent = subject, item_texture = item.texture})
	else:
		subject.character.handle_item(id)
	if item.consume_on_use:
		character.inventory.erase(id)
	emit_message("%s used %s" % [actor_name, item.name] if subject == self else "%s used %s on %s" % [actor_name, item.name, subject.actor_name])
	
	await get_tree().create_timer(WAIT_AFTER_ITEM).timeout
	turn_finished()


func handle_payload(pld: BattlePayload) -> void:
	await get_tree().process_frame
	if character.health <= 0: return
	print(actor_name, ": payload received from %s! " % pld.sender)
	
	var health_change := 0.0
	health_change += pld.health
	health_change += pld.health_percent / 100.0 * character.health
	health_change += pld.max_health_percent / 100.0 * character.max_health
	if health_change:
		if health_change > 0:
			heal(health_change)
		else:
			health_change = lerpf(account_defense(health_change), health_change, pld.pierce_defense)
			hurt(health_change)
	
	character.magic += pld.magic + (pld.magic_percent / 100.0 * character.magic) + (pld.max_magic_percent / 100.0 * character.max_magic)
	
	introduce_status_effect("attack", pld.attack_increase, pld.attack_increase_time)
	introduce_status_effect("defense", pld.defense_increase, pld.defense_increase_time)
	introduce_status_effect("speed", pld.speed_increase, pld.speed_increase_time)


func status_effect_update() -> void:
	for e in status_effects.keys():
		var effect : Dictionary = status_effects[e]
		effect["duration"] = effect.get("duration", 1) - 1
		if effect.get("duration", 1) < 1:
			status_effects[e] = {}


func introduce_status_effect(nomen: String, strength: float, duration: int) -> void:
	if not nomen in status_effects.keys():
		status_effects[nomen] = {}
	status_effects[nomen] = {
		"strength": strength + status_effects[nomen].get("strength", 0),
		"duration": duration + status_effects[nomen].get("duration", 0)
	}


func turn_finished() -> void:
	act_finished.emit(self)
	status_effect_update()


func load_character(id: int) -> Character:
	var char : Character = DAT.get_character(id).duplicate(false) # will crash if using deep copy here
	print("printing char ", char.name)
	for i in char.get_saveable_dict():
		print(i, " ", char.get(i))
	return char


func offload_character() -> void:
	character.health = maxf(character.health, 1.0)
	DAT.character_list[character_id] = character


func payload() -> BattlePayload:
	return BattlePayload.new().set_sender(self)


func get_effect_center(subject: BattleActor) -> Vector2i:
	return subject.effect_center + Vector2i(subject.global_position) if "effect_center" in subject else Vector2i(subject.global_position)


func emit_message(msg: String) -> void:
	message.emit(msg)


func get_team() -> Array[BattleActor]:
	return reference_to_team_array
