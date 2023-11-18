extends Node2D
class_name BattleActor

# base class for battle actors

const WAIT_AFTER_ATTACK := 1.0
const WAIT_AFTER_SPIRIT := 1.0
const WAIT_AFTER_SPIRIT_MULTI_ATTACK := 0.1
const WAIT_AFTER_ITEM := 1.00
const WAIT_AFTER_FLEE := 1.0

signal message(msg: String)
signal act_requested(by_whom: BattleActor)
signal act_finished(by_whom: BattleActor)
signal player_input_requested(by_whom: BattleActor)
signal died(who: BattleActor)
signal fled(who: BattleActor)
signal teammate_requested(who: BattleActor, whom: String)
signal critically_hitted

enum States {IDLE = -1, COOLDOWN, ACTING, DEAD}
var state : States = States.IDLE : set = set_state

var turn := 0

var hurt_sound := preload("res://sounds/hurt.ogg")

var actor_name : StringName
@onready var character : Character

var accessible := true

var status_effects : Dictionary = {}

var reference_to_team_array : Array[BattleActor] = []
var reference_to_opposing_array : Array[BattleActor] = []
var reference_to_actor_array : Array[BattleActor] = []

var player_controlled := false

@export_group("Other")
@export var effect_immunities : Array[String] = []
@export_range(0.0, 1.0) var stat_multiplier: = 1.0
@export var wait := 1.0


# battle script accesses actors through the group
func _init() -> void:
	self.add_to_group("battle_actors")


# the character is loaded before _ready()
func _ready() -> void:
	if not is_instance_valid(character):
		character = Character.new()
	actor_name = character.name


func _physics_process(delta: float) -> void:
	if not character: return
	if SOL.dialogue_open: return # don't run logic if dialogue is open
	effect_visuals()
	match state:
		States.IDLE:
			pass
		States.COOLDOWN:
			# cooldown between 1 and 0 usually
			wait = maxf(wait - sqrt(delta * get_speed() * 0.1), 0.0)
			if wait == 0.0:
				if not has_effect("sleepy"):
					act_requested.emit(self)
					set_state(States.ACTING)
					wait = 1.0
				else:
					status_effect_update()
					SOL.vfx(
						"sleepy",
						global_position + Vector2(randf_range(-4, 4),
							randf_range(-16, 0)), {"parent": self})
					wait = 1.0
					if has_effect("sleepy"):
						message.emit("%s is sleeping..." % actor_name)
						SND.play_sound(preload("res://sounds/sleepy.ogg"),
						 {"volume": 3})
					else:
						message.emit("%s woke up." % actor_name)
		States.ACTING:
			pass
		States.DEAD:
			pass


func act() -> void:
	set_state(States.ACTING)
	if player_controlled:
		player_input_requested.emit(self)
		return


func set_state(to: States) -> void:
	if not state == States.DEAD:
		state = to


func heal(amount: float) -> void:
	if state == States.DEAD: return
	# limit healing to max health
	character.health = minf(character.health + absf(amount), character.max_health)
	SOL.vfx("damage_number", parentless_effcenter(self), {text = absf(roundi(amount)), color=Color.GREEN_YELLOW})


func hurt(amt: float) -> void:
	var amount := amt
	if state == States.DEAD: return
	if has_effect("sleepy"):
		status_effects["sleepy"] = {}
		message.emit("%s woke up!" % actor_name)
		amount *= 1.8
	if has_effect("sopping"):
		SND.play_sound(preload("res://sounds/spirit/fish_attack.ogg"),
			{"pitch": 1.3, "volume": 1.5})
		amount += amt * 0.5
		SOL.vfx(
			"sopping",
			global_position + Vector2(randf_range(-4, 4), -16),
			{"parent": self})
	amount = maxf(amount, 1.0)
	character.health = maxf(character.health - absf(amount), 0.0)
	if character.health <= 0.0:
		state = States.DEAD
		SND.play_sound(preload("res://sounds/hurt.ogg"), {"pitch": 0.5, "volume": 4})
		died.emit(self)
	else:
		# hurt sound
		SND.play_sound(
			preload("res://sounds/eek.ogg") if randf() < 0.0001 and actor_name == "greg" else hurt_sound,
			{"pitch": maxf(lerpf(2.0, 0.5, remap(amount, 1, 90, 0.1, 1)), 0.1),
			"volume": randi_range(-4, 1)})
	# damage number
	SOL.vfx(
		"damage_number",
		parentless_effcenter(self),
		{text = absf(roundi(amount)),
		color = Color.RED,
		})
	#SOL.vfx("airspace_violation", get_effect_center(self))
	# shake the screen (not visible unless high damage)
	SOL.shake(sqrt(amount)/15.0)


func flee() -> void:
	SND.play_sound(preload("res://sounds/flee.ogg"))
	SOL.vfx("damage_number", get_effect_center(self), {text = "bye!", color=Color.WHITE})
	# so that it won't be acting anymore
	set_state(States.DEAD)
	fled.emit(self)
	emit_message("%s vacates the scene" % [actor_name])
	await get_tree().create_timer(WAIT_AFTER_FLEE).timeout
	turn_finished()


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
	if has_effect("little"):
		x *= 0.25
	return maxf(x, 1) * stat_multiplier


static func calc_attack_damage(atk: float, random := true) -> float:
	var x := 0.0
	x += atk
	if random: x += randf() * 2
	# funny level-based damage calculation
	var y := roundf(Math.method_29193(x))
	return y


# the half of defense is subtracted from the attack damage
func account_defense(x: float) -> float:
	var def := get_defense()
	var result := maxf(abs(x) - (def**0.77), 0)
	return roundf(result)


func attack(subject: BattleActor) -> void:
	if not subject.accessible:
		SND.play_sound(preload("res://sounds/flee.ogg"))
		SOL.vfx("damage_number", get_effect_center(self), {text = "miss!", color=Color.WHITE})
		await get_tree().create_timer(WAIT_AFTER_ATTACK).timeout
		turn_finished()
		return
	# manual construction of payload
	var crit := randf() <= 0.05
	var pld := payload().set_health(-BattleActor.calc_attack_damage(get_attack()))
	if crit: pld.health *= 2.5
	var weapon : Item
	if character.weapon:
		# manually copy over stuff from the item's payload
		weapon = DAT.get_item(character.weapon)
		pld.set_defense_pierce(weapon.payload.pierce_defense)
		pld.effects = weapon.payload.effects
		pld.delay = weapon.payload.delay
		pld.animation_on_receive = weapon.payload.animation_on_receive
	subject.handle_payload(pld) # the actual attack
	if crit:
		SOL.vfx(
			"damage_number",
			parentless_effcenter(subject),
			{text = "crit!!!",
			color = Color(1.0, 0.3, 0.2),
		})
		SND.play_sound(preload("res://sounds/critical_hit.ogg"), {"volume": 5})
		critically_hitted.emit()
	# functions just in case
	if self.has_method("_attacked_%s" % subject.character.name_in_file):
		call("_attacked_%s" % subject.character.name_in_file)
	if subject.has_method("_hurt_by_%s" % character.name_in_file):
		call("_hurt_by_%s" % character.name_in_file)
	# animations
	if weapon != null and weapon.attack_animation.length() > 0:
		SOL.vfx(weapon.attack_animation, get_effect_center(subject), {parent = subject})
	else:
		blunt_visuals(subject)
	emit_message("%s attacked %s" % [actor_name, subject.actor_name])
	await get_tree().create_timer(WAIT_AFTER_ATTACK).timeout
	turn_finished()


func use_spirit(id: String, subject: BattleActor) -> void:
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
	# functions
	if self.has_method("_used_spirit_%s" % id):
		call("_used_spirit_%s" % id)
	# loop through all 
	for receiver in targets:
		if character.health <= 0: break
		if spirit.receive_animation:
			SOL.vfx(spirit.receive_animation, get_effect_center(receiver), {parent = receiver})
		for i in spirit.payload_reception_count:
			if character.health <= 0: break
			if receiver.character.health <= 0: break
			receiver.handle_payload(
				spirit.payload.set_sender(self).\
				set_defense_pierce(spirit.payload.pierce_defense if spirit.payload.pierce_defense else 1.0)\
				.set_type(BattlePayload.Types.SPIRIT)
			)
			# we wait a bit before applying the payload again
			await get_tree().create_timer(
				maxf((maxf(WAIT_AFTER_SPIRIT - 0.8, 0.2)) /
				float(spirit.payload_reception_count), 0.01)
			).timeout
		# function
		if receiver.has_method("_spirit_%s_used_on" % id):
			receiver.call("_spirit_%s_used_on" % id)
	
	await get_tree().create_timer(WAIT_AFTER_SPIRIT).timeout
	if SOL.dialogue_open:
		await SOL.dialogue_closed
	turn_finished()


func use_item(id: String, subject: BattleActor) -> void:
	if not subject.accessible:
		SND.play_sound(preload("res://sounds/flee.ogg"))
		SOL.vfx("damage_number", get_effect_center(self), {text = "miss!", color=Color.WHITE})
		await get_tree().create_timer(WAIT_AFTER_ITEM).timeout
		turn_finished()
		return
	var item : Item = DAT.get_item(id)
	if not (item.use == Item.Uses.WEAPON or item.use == Item.Uses.ARMOUR):
		subject.handle_payload(item.payload.set_sender(self).\
		set_type(BattlePayload.Types.ITEM)) # using the item
		SOL.vfx("use_item", get_effect_center(subject), {parent = subject, item_texture = item.texture, silent = item.play_sound != null})
		if item.play_sound:
			SND.play_sound(item.play_sound)
		
	else:
		# if it's weapon or armour, equip it
		subject.character.handle_item(id)
	if item.consume_on_use:
		character.inventory.erase(id)
	emit_message("%s used %s" % [actor_name, item.name] if subject == self else "%s used %s on %s" % [actor_name, item.name, subject.actor_name])
	# function
	if subject.has_method("_item_%s_used_on" % id):
		subject.call("_item_%s_used_on" % id)
	
	await get_tree().create_timer(WAIT_AFTER_ITEM).timeout
	turn_finished()


# squeeze empty the payload, copy everything over
func handle_payload(pld: BattlePayload) -> void:
	print(actor_name, " handling payload! (%s)" % BattlePayload.Types.find_key(pld.type))
	# this somehow fixes a battle end doubling bug. cool.
	await get_tree().process_frame
	if character.health <= 0: return
	if pld.delay: await get_tree().create_timer(pld.delay).timeout
	var health_change := 0.0
	health_change += pld.health
	health_change += (pld.health_percent / 100.0) * character.health
	health_change += (pld.max_health_percent / 100.0) * character.max_health
	if health_change:
		if health_change > 0:
			heal(health_change)
		else:
			health_change = absf(health_change)
			health_change = lerpf(account_defense(health_change), health_change, pld.pierce_defense)
			if has_effect("shield"):
				health_change *= 0.25
				SOL.vfx("ribbed_shield", get_effect_center(self), {parent = self})
			hurt(health_change)
			if pld.steal_health and is_instance_valid(pld.sender):
				pld.sender.heal(health_change * pld.steal_health)
			if pld.steal_magic and is_instance_valid(pld.sender):
				pld.sender.character.magic += pld.steal_magic
				character.magic = maxf(character.magic - pld.steal_magic, 0.0)
			if character.health <= 0:
				if is_instance_valid(pld.sender):
					pld.sender.character.add_defeated_character(character.name_in_file)
	
	character.magic += pld.magic + (pld.magic_percent / 100.0 * character.magic) + (pld.max_magic_percent / 100.0 * character.max_magic)
	
	for en in pld.effects:
		if en.name.length() and en.duration:
			introduce_status_effect(en.name, en.strength, en.duration + 1)
	
	if pld.summon_enemy:
		teammate_requested.emit(self, pld.summon_enemy)
	
	if pld.meta.get("reveal_enemy_info", false) and pld.sender.player_controlled:
		SOL.dialogue_box.dial_concat("battle_inspect", 1, [actor_name])
		SOL.dialogue_box.dial_concat("battle_inspect", 2, [character.level])
		SOL.dialogue_box.dial_concat("battle_inspect", 3, [get_attack(), get_defense(), get_speed()])
		SOL.dialogue_box.dial_concat("battle_inspect", 4, [character.info if character.info else "secretive one... nothing else could be found."])
		SOL.dialogue("battle_inspect")
	
	if pld.meta.get("skateboard", false):
		message.emit("woah! skateboard!! so cool!!")
	
	if pld.animation_on_receive:
		SOL.vfx(pld.animation_on_receive, get_effect_center(self), {parent = self})


func status_effect_update() -> void:
	for e in status_effects.keys():
		var effect : Dictionary = status_effects[e]
		# apply damage from damaging effects
		effect_action(e, effect)
		# remove if immune
		if is_immune_to(e):
			status_effects[e] = {}
		# effects run out
		effect[&"duration"] = effect.get(&"duration", 1) - 1
		if effect.get(&"duration", 1) < 1:
			status_effects[e] = {}
			if e == &"little":
				self.scale = Vector2.ONE


func introduce_status_effect(nomen: String, strength: float, duration: int) -> void:
	if not nomen.length():
		printerr("empty effect name")
		return
	if not nomen in status_effects.keys():
		status_effects[nomen] = {}
	var old_strength : float = status_effects[nomen].get(&"strength", 0)
	var old_duration : int = status_effects[nomen].get(&"duration", 0)
	# if the effect already existed, the new strength and length are the averages
	# between the old effect strength and length and the new effect -"-
	var new_strength : float = (old_strength + strength / 2.0) if old_strength != 0 else strength
	var new_duration : int = 0 if duration < 0 else roundi((old_duration + duration / 2.0)) if old_duration != 0 else duration
	# add immunity
	if duration < -1:
		introduce_status_effect(nomen + "_immunity", 1, absi(duration))
		return
	# if immune, don't apply the effect
	if is_immune_to(nomen) and duration > 0:
		SOL.vfx("damage_number", parentless_effcenter(), {text = "immune!", color = Color.YELLOW, speed = 0.5})
		return
	status_effects[nomen] = {
		&"strength": new_strength,
		&"duration": new_duration
	}
	if nomen == &"sopping" and on_fire():
		status_effects["fire"] = {}
	if nomen == &"little":
		self.scale = Vector2(0.25, 0.25)
	# notify of an effect with this
	if strength and duration and duration != -1:
		SOL.vfx("damage_number", parentless_effcenter(), {text = "%s%s %s" % [Math.sign_symbol(strength), str(absf(strength)) if strength != 1 else "", nomen.replace("_", " ")], color = Color.YELLOW, speed = 0.5})


func effect_action(nomen: String, effect: Dictionary) -> void:
	if nomen == &"coughing" and effect.get(&"duration", 0) > 0:
		# coughing damage is applied by a separate battle actor because why not
		var cougher := BattleActor.new()
		cougher.character = Character.new()
		cougher.character.attack = effect.get(&"strength", 1) * 2
		add_child(cougher)
		cougher.attack(self)
		SND.play_sound(preload("res://sounds/spirit/airspace_violation.ogg"), {"volume": -3})
		cougher.queue_free()
	if nomen == &"poison" and effect.get(&"duration", 0) > 0:
		hurt(effect.get(&"strength", 1) * 1.3)
	if nomen == &"fire" and effect.get(&"duration", 0) > 0:
		hurt(clampf(character.health * 0.08, 1, 25))
		SOL.vfx(&"battle_burning", global_position + SOL.SCREEN_SIZE / 2 + Vector2(randf_range(-2, 2), randf_range(-2, 2)), {"parent": self})
		SND.play_sound(preload("res://sounds/fire.ogg"), {pitch = 2.0})
	if nomen == &"regen" and effect.get(&"duration", 0) > 0:
		heal(effect.get(&"strength", 1) * 5)
	if nomen == &"inspiration" and effect.get(&"duration", 0) > 0:
		var mincrease : float = effect.get(&"strength", 1) * 2
		character.magic += mincrease


func turn_finished() -> void:
	act_finished.emit(self)
	status_effect_update()
	turn += 1


func load_character(id: StringName) -> void:
	var charc : Character = DAT.get_character(id).duplicate(true)
	character = charc
	charc.defeated_characters.clear()


# at the end of the fight, the party will update changes to their characters
# so that the health and other information will get saved between battles
func offload_character() -> void:
	character.health = maxf(character.health, 1.0)
	var basechar : Character = DAT.character_dict[character.name_in_file]
	basechar.health = character.health
	basechar.magic = clampf(character.magic, 0.0, basechar.max_magic)
	basechar.inventory = character.inventory
	basechar.weapon = character.weapon
	basechar.armour = character.armour
	basechar.add_defeated_characters(character.defeated_characters) 


func payload() -> BattlePayload:
	return BattlePayload.new().set_sender(self)


# for positioning visual effects
func get_effect_center(subject: BattleActor = self) -> Vector2:
	return Vector2(subject.effect_center) + Vector2(subject.global_position) if has_effcenter(subject) else subject.get_global_transform_with_canvas().origin
	#return subject.get_global_transform_with_canvas().origin


func has_effcenter(subject: BattleActor = self) -> bool:
	return "effect_center" in subject


# for properly positioning visual effects when not parenting to the actor
func parentless_effcenter(subject: BattleActor = self) -> Vector2:
	if has_effcenter(subject):
		return get_effect_center(subject)
	return get_effect_center(subject) - (SOL.HALF_SCREEN_SIZE)


func emit_message(msg: String) -> void:
	message.emit(msg)


func get_team() -> Array[BattleActor]:
	return reference_to_team_array


func is_confused() -> bool:
	if status_effects.get("confusion", {}):
		return status_effects.get("confusion", {}).get("duration", 0) > 0
	return false


func on_fire() -> bool:
	if status_effects.get("fire", {}):
		return status_effects.get("fire", {}).get("duration", 0) > 0
	return false


func has_effect(what: StringName) -> bool:
	if status_effects.get(what, {}):
		return status_effects.get(what, {}).get("duration", 0) > 0
	return false


func is_immune_to(what: StringName) -> bool:
	if has_effect("sopping") and what == "fire":
		return true
	return what in effect_immunities or has_effect(what + "_immunity")


func blunt_visuals(subject: BattleActor) -> void:
	SOL.vfx("dustpuff", get_effect_center(subject), {parent = subject})
	SOL.vfx("bangspark", get_effect_center(subject), {parent = subject, random_rotation = true})
	SND.play_sound(preload("res://sounds/attack_blunt.ogg"))


func effect_visuals() -> void:
	if randf() <= 0.02 and on_fire():
		SOL.vfx("battle_burning",
			global_position + Vector2(randf_range(-4, 4),
				randf_range(-8, 16)), {"parent": self})
		var tw := create_tween().set_trans(Tween.TRANS_QUINT)
		var rand := randf_range(0.5, 1.0)
		tw.tween_property(self, "modulate", 
			Color(randf_range(1.0, 1.5), rand, rand, 1.0), rand)
	if randf() <= 0.03 and has_effect("sleepy"):
		SOL.vfx(
			"sleepy",
			global_position + Vector2(randf_range(-4, 4),
				randf_range(-16, 0)), {"parent": self})
	if randf() <= 0.04 and has_effect("sopping"):
		SOL.vfx(
			"sopping",
			global_position + Vector2(randf_range(-4, 4),
				randf_range(-16, 0)), {"parent": self})


func _to_string() -> String:
	return actor_name
