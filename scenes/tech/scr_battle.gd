extends Node2D
class_name Battle

# the battle screen. what did you expect?
# battles consist of actors lowering their cooldown based on their speed
# (speedier = faster cooldown) and then acting, during which time
# others cannot act. once one team is defeated, the battle ends.

signal player_finished_acting

# this is the default for testing
@export var load_options: BattleInfo = null

var stop_music_before_end := true
var play_victory_music := true

const SCREEN_SIZE := Vector2i(160, 120)
const MAX_PARTY_MEMBERS := 3
const MAX_ENEMIES := 6

const BACK_PITCH := 0.75

enum Teams {PARTY, ENEMIES}

# states of the battle
enum Doings {
	NOTHING = -1, WAITING, ATTACK,
	SPIRIT, SPIRIT_NAME, ITEM_MENU,
	ITEM, END, DONE, DANCE_BATTLE
}
var doing := Doings.NOTHING:
	set(to):
		doing = to
var action_history := []

var loading_battle := true

# many nodes

@onready var camera: Camera2D = $Camera
@onready var ui := $UI

@onready var panel: Panel = $UI/Panel
@onready var reference_button := preload("res://scenes/tech/scn_reference_button.tscn")
@onready var description_text: RichTextLabel = $%DescriptionText
@onready var list_containers: Array = [$UI/Panel/ScreenListSelect/ScrollContainer/ListContainer/Left, $UI/Panel/ScreenListSelect/ScrollContainer/ListContainer/Right]
@onready var item_list_container: Array = [$UI/Panel/ScreenItemSelect/ScrollContainer/List]
@onready var enemies_node: Node2D = $Enemies
@onready var party_node: Node2D = $Party
@onready var update_timer: Timer = $SlowUpdateTimer
@onready var background_container: Node2D = $Background

@onready var screen_main_actions := %ScreenMainActions
@onready var screen_list_select := %ScreenListSelect
@onready var screen_item_select := %ScreenItemSelect
@onready var item_info_label := $UI/Panel/ScreenItemSelect/ItemInfoLabel

@onready var screen_party_info := %ScreenPartyInfo
@onready var screen_spirit_name := %ScreenSpiritName
@onready var screen_dance_battle := $UI/Panel/ScreenDanceBattle as ScreenDanceBattle
@onready var screen_end := %ScreenEnd
@onready var current_info := %CurrentInfo as PartyMemberInfoPanel
@onready var status_effects_list := $UI/Panel/ScreenMainActions/StatusEffectsList
@onready var victory_text := %VictoryText
@onready var defeat_text := %DefeatText
@onready var attack_button := %AttackButton
@onready var spirit_button := %SpiritButton
@onready var item_button := %ItemButton
@onready var selected_guy_display := %SelectedGuy
@onready var log_text := %MessageContainer as MessageContainer
@onready var spirit_name := %SpiritName
@onready var spirit_speak_timer := %SpiritSpeakTimer
@onready var spirit_speak_timer_progress := %SpiritSpeakTimerProgress
var spirit_speak_timer_wait := 2.0

@onready var party_member_panel_container := $UI/Panel/ScreenPartyInfo/Container

var held_item_id: StringName = &""

# storing battle members
var actors: Array[BattleActor]
var dead_actors: Array[BattleActor]
var party: Array[BattleActor]
var dead_party: Array[BattleActor]
var ever_has_been_party: Array[BattleActor]
var enemies: Array[BattleActor]
var dead_enemies: Array[BattleActor]

var xp_pool := 0:
	set(to):
		xp_pool = to

var listening_to_player_input := false
var current_guy: BattleActor
var loaded_spirits := {}
var current_target: BattleActor

var death_reason := "default"
var battle_rewards: BattleRewards


func _ready() -> void:
	update_timer.timeout.connect(_on_update_timer_timeout)
	update_timer.start(0.08)
	for e in enemies_node.get_children():
		e.queue_free()
	for a in party_node.get_children():
		a.queue_free()
	attack_button.selected.connect(set_description)
	attack_button.pressed.connect(_on_attack_pressed)
	spirit_button.selected.connect(set_description)
	spirit_button.pressed.connect(_on_spirit_pressed)
	item_button.selected.connect(set_description)
	item_button.pressed.connect(_on_item_pressed)
	spirit_name.text_changed.connect(_on_spirit_name_changed)
	spirit_name.text_submitted.connect(_on_spirit_name_submitted)
	spirit_speak_timer.timeout.connect(_on_spirit_speak_timer_timeout)
	screen_dance_battle.end.connect(_dance_battle_ended)
	OPT.battle_text_opacity_changed.connect(func():
		log_text.modulate.a = OPT.get_opt("battle_text_opacity")
	)
	log_text.modulate.a = OPT.get_opt("battle_text_opacity")
	remove_child(ui)
	SOL.add_ui_child(ui)
	remove_child(party_node)
	SOL.add_ui_child(party_node)
	await get_tree().process_frame
	load_battle(load_options)
	set_actor_states(BattleActor.States.COOLDOWN, true)
	open_party_info_screen()
	check_end()
	DAT.death_reason = death_reason
	SOL.dialogue_low_position()


func _physics_process(_delta: float) -> void:
	match doing:
		Doings.SPIRIT_NAME:
			# match the timer with the progress bar
			spirit_speak_timer_progress.value = remap(
					spirit_speak_timer.time_left, 0.0,
					spirit_speak_timer_wait, 0.0, 100.0)
	if screen_party_info.visible:
		update_party()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action("hide_battle_ui"):
		ui.visible = not event.is_pressed()
		if not event.is_pressed():
			attack_button.grab_focus()
	if not listening_to_player_input:
		return
	if is_ui_locked():
		return
	if event.is_action_pressed("cancel"):
		go_back_a_menu()
	if event.is_action_pressed("menu") and doing == Doings.NOTHING:
		for e: BattleStatusEffect in current_guy.status_effects.values():
			var cont := HBoxContainer.new()
			cont.add_theme_constant_override("separation", 0)
			var tex := TextureRect.new()
			tex.stretch_mode = TextureRect.STRETCH_KEEP
			tex.texture = e.type.icon
			tex.flip_v = e.strength < 0
			var lab := Label.new()
			lab.text = "%s lvl %s for %s turns" % [
					e.type.name, e.strength, e.duration]
			cont.add_child(tex)
			cont.add_child(lab)
			status_effects_list.add_child(cont)
		resize_panel(112)
		set_description("status effect info")
	if event.is_action_released("menu") and doing == Doings.NOTHING:
		open_main_actions_screen()
	if event.is_action_pressed("ui_accept") and doing == Doings.DONE:
		# leave the battle
		LTS.gate_id = LTS.GATE_EXIT_BATTLE
		var looper: Array[BattleActor] = []
		looper.append_array(party)
		looper.append_array(dead_party)
		for p in looper:
			p.offload_character()
		LTS.level_transition(LTS.ROOM_SCENE_PATH %
				DAT.get_data("current_room", "test_room"))
		set_process_unhandled_input(false)


func load_battle(info: BattleInfo) -> void:
	# second argument of info.get_ is the default value
	set_background(info.background)
	for m in info.get_("party", DAT.get_data("party", ["greg"])):
		add_party_member(m)
	current_guy = party.front()
	for e in info.enemies:
		add_enemy(e)
	death_reason = info.death_reason
	SND.play_song(info.music, 1.0, {start_volume = 0, play_from_beginning = true})
	battle_rewards = info.get_("rewards",
			preload("res://resources/rewards/res_default_reward.tres"
			)).duplicate(true)
	message(info.get_("start_text",
			("%s lunges at you!" % enemies.front().actor_name)
			if enemies.size() else "no one is here."
	) + "\n", {"alignment": HORIZONTAL_ALIGNMENT_CENTER})
	play_victory_music = info.victory_music
	stop_music_before_end = info.stop_music_before_end
	set_greg_speed()
	loading_battle = false


func set_actor_states(to: BattleActor.States, only_party := false) -> void:
	if only_party:
		for i in get_tree().get_nodes_in_group("battle_actors"):
			if i in party:
				i.call("set_state", to)
	else:
		get_tree().call_group("battle_actors", "set_state", to)


func add_actor(node: BattleActor, team: Teams) -> void:
	if team == Teams.PARTY:
		if party.size() > MAX_PARTY_MEMBERS:
			push_error("too many party members")
			return
	node.reference_to_actor_array = actors
	node.message.connect(message)
	node.act_requested.connect(_on_act_requested)
	node.act_finished.connect(_on_act_finished)
	node.died.connect(_on_actor_died)
	node.fled.connect(_on_actor_fled)
	node.teammate_requested.connect(request_new_enemy)
	node.critically_hitted.connect(_on_crit_received)
	if node is EnemyAnimal:
		node.dance_battle_requested.connect(_on_dance_battle_requested)
	actors.append(node)
	match team:
		Teams.PARTY:
			party.append(node)
			ever_has_been_party.append(node)
			node.player_controlled = true
			node.player_input_requested.connect(_on_player_input_requested)
			node.reference_to_team_array = party
			node.reference_to_opposing_array = enemies
			party_node.add_child(node)
		Teams.ENEMIES:
			enemies.append(node)
			node.reference_to_team_array = enemies
			node.reference_to_opposing_array = party
			enemies_node.add_child(node)


func add_enemy(character_id: StringName, ally := false) -> void:
	var character: Character = ResMan.get_character(character_id)
	var node: BattleActor
	if DIR.enemy_scene_exists(character.name_in_file) and not ally:
		node = load(DIR.enemy_scene_path(character.name_in_file)).instantiate()
		node.load_character(character_id)
	else:
		node = preload("res://scenes/tech/scn_battle_enemy.tscn").instantiate()
		node.load_character(character_id)
		node.xp_multiplier = 1.0 if not loading_battle else 0.25
		if not ally:
			var sprite_new := Sprite2D.new()
			node.add_child(sprite_new)
			sprite_new.texture = preload(
					"res://sprites/characters/battle/spr_enemy_battle.png")
			node.effect_center = Vector2i(0, -20)

	add_actor(node, Teams.ENEMIES if not ally else Teams.PARTY)

	arrange_enemies()


func add_party_member(id: String) -> void:
	var party_member: BattleActor = preload(
			"res://scenes/tech/scn_battle_actor.tscn").instantiate()
	party_member.load_character(id)
	DAT.save_char_to_data(id)

	add_actor(party_member, Teams.PARTY)

	update_party()


func arrange_enemies():
	if enemies.is_empty():
		return
	enemies_node.arrange()


func set_background(id: String) -> void:
	var path := DIR.battle_background_scene_path(id)
	if DIR.battle_background_scene_exists(id):
		background_container.add_child(load(path).instantiate())
	else:
		background_container.add_child(
			load("res://scenes/battle_backgrounds/scn_town.tscn").instantiate())


# update the panel visuals
func update_party() -> void:
	for child in party_member_panel_container.get_children():
		child.hide()
	for i in ever_has_been_party.size():
		var member: BattleActor = ever_has_been_party[i]
		party_member_panel_container.get_child(i).update(member)
		party_member_panel_container.get_child(i).show()


func go_back_a_menu() -> void:
	match doing:
		Doings.NOTHING:
			attack_button.grab_focus()
		Doings.ATTACK:
			open_main_actions_screen()
			SND.menusound(BACK_PITCH)
		Doings.ITEM_MENU:
			open_main_actions_screen()
			SND.menusound(BACK_PITCH)
		Doings.ITEM:
			doing = Doings.ITEM_MENU
			open_list_screen()
			SND.menusound(BACK_PITCH)
		Doings.SPIRIT:
			open_main_actions_screen()
			SND.menusound(BACK_PITCH)
		Doings.SPIRIT_NAME:
			doing = Doings.SPIRIT
			open_list_screen()
			SND.menusound(BACK_PITCH)
	highlight_selected_enemy()
	erase_floating_spirits()


# something is selected
func _reference_button_pressed(reference) -> void:
	if is_ui_locked() or is_end():
		return
	match doing:
		Doings.ATTACK:
			current_guy.attack(reference)
			listening_to_player_input = false
			append_action_history("attack", {"target": reference})
			open_party_info_screen()
		Doings.SPIRIT:
			current_target = reference
			open_spirit_name_screen()
			SND.play_sound(preload("res://sounds/gui.ogg"),
					{"bus": "ECHO", "pitch_scale": 0.8})
		Doings.ITEM_MENU:
			doing = Doings.ITEM
			held_item_id = reference
			open_list_screen()
		Doings.ITEM:
			listening_to_player_input = false
			current_guy.use_item(held_item_id, reference)
			append_action_history("item",
					{"target": reference, "item": held_item_id})
			open_party_info_screen()


# descriptions for items and such
func _on_button_reference_received(reference) -> void:
	if doing == Doings.ATTACK or doing == Doings.SPIRIT or doing == Doings.ITEM:
		selected_guy_display.update(reference)
		highlight_selected_enemy(reference)
	if doing == Doings.ITEM_MENU:
		item_info_label.text = str(
				ResMan.get_item(reference).get_effect_description(),
				"\n[color=#888888]", ResMan.get_item(reference).description)


# some actor wants to act!
func _on_act_requested(actor: BattleActor) -> void:
	if is_end():
		return
	print(actor, " requested act")
	open_party_info_screen()
	set_actor_states(BattleActor.States.IDLE)
	actor.act()


# some actor has finished their act
func _on_act_finished(actor: BattleActor) -> void:
	if is_end():
		return
	if actor.player_controlled:
		player_finished_acting.emit()
	open_party_info_screen()
	check_end()
	await get_tree().create_timer(0.25).timeout
	if not doing == Doings.DANCE_BATTLE:
		set_actor_states(BattleActor.States.COOLDOWN)


# some actor has been killed
func _on_actor_died(actor: BattleActor) -> void:
	if is_end():
		return
	if actor in party:
		dead_party.append(party.pop_at(party.find(actor)))
	if actor in enemies:
		actor = actor as BattleEnemy
		dead_enemies.append(enemies.pop_at(enemies.find(actor)))
		xp_pool += actor.character.level * actor.xp_multiplier
	# delete from enemies' vendetta lists
	# (because they can still attack dead people technically)
	for enemy: BattleEnemy in enemies:
		enemy.extra_targets.erase(actor)
	dead_actors.append(actors.pop_at(actors.find(actor)))
	arrange_enemies()
	check_end()
	await get_tree().process_frame
	update_party()


# some actor has fled the fight
func _on_actor_fled(actor: BattleActor) -> void:
	if is_end():
		return
	if actor in party:
		pass
	if actor in enemies:
		dead_enemies.append(enemies.pop_at(enemies.find(actor)))
		xp_pool += roundi(actor.character.level * 0.5)
	dead_actors.append(actors.pop_at(actors.find(actor)))
	arrange_enemies()
	check_end()
	await get_tree().process_frame
	update_party()


# more enemies are requested by a spirit perhaps
func request_new_enemy(actor: BattleActor, req: String) -> void:
	if actor in enemies:
		if enemies.size() < MAX_ENEMIES:
			add_enemy(req)
			message("%s joined the fight" %
					ResMan.get_character(req).name,
					{"alignment": HORIZONTAL_ALIGNMENT_CENTER})
		else:
			message("%s did not fit into the fight." %
					ResMan.get_character(req).name,
					{"alignment": HORIZONTAL_ALIGNMENT_CENTER})
	else:
		if party.size() < MAX_PARTY_MEMBERS:
			add_party_member(req)
			message("%s joined the fight" %
					ResMan.get_character(req).name,
					{"alignment": HORIZONTAL_ALIGNMENT_CENTER})
		else:
			message("%s did not fit into the fight." %
					ResMan.get_character(req).name,
					{"alignment": HORIZONTAL_ALIGNMENT_CENTER})


func check_end(force := false) -> void:
	if is_end(): return
	var end_condition := party.size() < 1 or enemies.size() < 1
	if end_condition or force:
		doing = Doings.END
		if stop_music_before_end:
			SND.play_song("")
		open_end_screen(party.size() > 0)


func message(msg: String, options := {}) -> void:
	log_text.push_message(msg, options)


# when a player-controllect character requests act
func _on_player_input_requested(actor: BattleActor) -> void:
	current_guy = actor
	open_main_actions_screen()
	listening_to_player_input = true


# choice between fighting, spirits and items
func open_main_actions_screen() -> void:
	var inf1 := screen_main_actions.get_child(-2)
	var inf2 := screen_main_actions.get_child(-1)
	held_item_id = ""
	current_target = null
	hide_screens()
	resize_panel(44)
	# sparkle on, it's wednesday! don't forget to be yourself!
	if Time.get_date_dict_from_system().weekday == \
			Time.WEEKDAY_WEDNESDAY and randf() <= 0.02:
		attack_button.text = "slay"
	else:
		attack_button.text = "tussle"
	current_info.update(current_guy)
	inf1.text = str("%s\nlvl %s" %
			[current_guy.character.name, current_guy.character.level])
	inf2.text = str("atk: %s\ndef: %s\nspd: %s\nhp: %s/%s\nsp: %s/%s" %
			[roundi(current_guy.get_attack()),
			roundi(current_guy.get_defense()),
			roundi(current_guy.get_speed()),
			roundi(current_guy.character.health),
			roundi(current_guy.character.max_health),
			roundi(current_guy.character.magic),
			roundi(current_guy.character.max_magic)])
	screen_main_actions.show()
	attack_button.grab_focus()
	erase_floating_spirits()
	for c in status_effects_list.get_children():
		c.hide()
		c.queue_free()
	match doing:
		Doings.NOTHING:
			attack_button.grab_focus()
		Doings.ATTACK:
			attack_button.grab_focus()
		Doings.ITEM_MENU:
			item_button.grab_focus()
		Doings.SPIRIT:
			spirit_button.grab_focus()
	doing = Doings.NOTHING
	remote_transforms(false)
	#await get_tree().process_frame
	current_info.remote_transform.remote_path = current_guy.get_path()
	#current_info.remote_transform.force_update_cache()
	#current_guy.global_position = current_info.remote_transform.get_global_transform_with_canvas().origin


# item/actor listing screens
func open_list_screen() -> void:
	hide_screens()
	set_greg_speed()
	match doing:
		Doings.ATTACK:
			var array := []
			array.append_array(enemies)
			array.append_array(party)
			Math.load_reference_buttons(
					array, list_containers,
					_reference_button_pressed,
					_on_button_reference_received)
			screen_list_select.show()
		Doings.ITEM_MENU:
			var items := current_guy.character.inventory.duplicate()
			items.sort()
			Math.load_reference_buttons_groups(
					items, item_list_container,
					_reference_button_pressed,
					_on_button_reference_received,
					{"item": true, "custom_pass_function": item_names})
			screen_item_select.show()
		Doings.ITEM:
			var array := []
			var item := ResMan.get_item(held_item_id) as Item
			if item.use in Item.USES_POSITIVE:
				array.append_array(party)
				array.append_array(enemies)
			else:
				array.append_array(enemies)
				array.append_array(party)
			Math.load_reference_buttons(
					array, list_containers,
					_reference_button_pressed,
					_on_button_reference_received)
			screen_list_select.show()
		Doings.SPIRIT:
			Math.load_reference_buttons(
					actors, list_containers,
					_reference_button_pressed,
					_on_button_reference_received)
			screen_list_select.show()
			load_floating_spirits()
	resize_panel(60)
	await get_tree().process_frame # <---- of course this needs to be here
	var deferred: int = OPT.get_opt("list_button_focus_deferred")
	if screen_list_select.visible:
		if list_containers[0].get_children().size() > 0:
			if deferred: list_containers[0].get_child(0).call_deferred("grab_focus")
			else: list_containers[0].get_child(0).grab_focus()
	elif screen_item_select.visible:
		if item_list_container[0].get_children().size() > 0:
			if deferred: item_list_container[0].get_child(0).call_deferred("grab_focus")
			else: item_list_container[0].get_child(0).grab_focus()


# the one between player acts
func open_party_info_screen() -> void:
	listening_to_player_input = false
	for i in party_member_panel_container.get_children():
		i.remote_transform.update_position = true
	doing = Doings.NOTHING
	held_item_id = ""
	hide_screens()
	screen_party_info.show()
	resize_panel(25)
	update_party()
	highlight_selected_enemy()
	erase_floating_spirits()
	current_info.remote_transform.remote_path = NodePath()
	remote_transforms(true)


func open_spirit_name_screen() -> void:
	spirit_name.add_theme_font_size_override("font_size", 16)
	doing = Doings.SPIRIT_NAME
	held_item_id = ""
	resize_panel(4, 0.1)
	spirit_name.text = ""
	spirit_name.editable = true
	hide_screens()
	screen_spirit_name.show()
	spirit_speak_timer.paused = false
	spirit_speak_timer.start(spirit_speak_timer_wait)
	for i in current_guy.character.spirits:
		var spirit: Spirit = ResMan.get_spirit(i)
		loaded_spirits[spirit.name] = i
	spirit_name.grab_focus()


# you didn't type the spirit name fast enough
func _on_spirit_speak_timer_timeout() -> void:
	listening_to_player_input = false
	SND.play_sound(
			preload("res://sounds/error.ogg"),
			{pitch_scale = 0.7, bus = "ECHO"})
	spirit_name.text = "moment passed"
	spirit_name.modulate = Color(2, 0.2, 0.4)
	spirit_name.editable = false
	append_action_history("spirit_fail")
	await get_tree().create_timer(0.5).timeout
	current_guy.turn_finished()
	open_party_info_screen()


func _on_spirit_name_changed(to: String) -> void:
	to = to.to_lower() # no uppercase
	spirit_name.text = to
	spirit_name.caret_column = to.length()
	spirit_name.add_theme_font_size_override("font_size", 16)
	if to.length() > 12:
		spirit_name.add_theme_font_size_override("font_size", 8)
	if to in loaded_spirits.keys():
		_on_spirit_name_submitted(to)
		return

	SND.play_sound(
			preload("res://sounds/gui.ogg"),
			{"bus": "ECHO", "pitch_scale":
				[1.0, 1.0, 1.18921, 1.7818].pick_random()})
	var tw := create_tween().set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(spirit_name, "modulate", Color(0.8, 0.8, 8.0, 2.0), 0.1)
	tw.tween_property(spirit_name, "modulate", Color(1, 1, 1, 1), 0.3)


func _on_spirit_name_submitted(submission: String) -> void:
	listening_to_player_input = false
	get_viewport().gui_release_focus()
	spirit_speak_timer.paused = true
	if submission in loaded_spirits.keys():
		spirit_name.editable = false
		var spirit_id = loaded_spirits[submission]
		var spirit := ResMan.get_spirit(spirit_id)
		if spirit.cost <= current_guy.character.magic:
			SND.play_sound(preload("res://sounds/spirit/spirit_name_found.ogg"))
			var tw := create_tween().set_trans(Tween.TRANS_QUART)
			tw.tween_property(spirit_name, "modulate", Color(2, 2, 2, 10), 1.5)

			await get_tree().create_timer(1.5).timeout
			current_guy.use_spirit(spirit_id, current_target)
			append_action_history(
					"spirit", {"spirit":
						spirit_id, "target": current_target})
			open_party_info_screen()
			return
		else:
			spirit_name.text = "not enough sp!"

	SND.play_sound(preload("res://sounds/error.ogg"), {bus = "ECHO"})
	append_action_history("spirit_fail")
	await get_tree().create_timer(0.5).timeout
	current_guy.turn_finished()
	open_party_info_screen()
	erase_floating_spirits()


# horrible function
func open_end_screen(victory: bool) -> void:
	SOL.dialogue_low_position()
	if screen_end.visible:
		return
	set_actor_states(BattleActor.States.IDLE)
	hide_screens()
	screen_end.show()
	victory_text.visible = victory
	defeat_text.visible = !victory
	await get_tree().create_timer(1.0).timeout
	screen_party_info.show()
	victory_text.speak_text()
	if victory:
		resize_panel(60)
		if play_victory_music:
			SND.play_song(
					"victory", 10,
					{start_volume = 0.0,
					play_from_beginning = true})
		var xp_reward := Reward.new()
		xp_reward.type = BattleRewards.Types.EXP
		xp_reward.property = str(xp_pool)
		battle_rewards.add(xp_reward)
		if battle_rewards.rewards.size() > 0:
			_grant_rewards()
			#await battle_rewards.granted
		await SOL.dialogue_closed
		doing = Doings.DONE
		listening_to_player_input = true
	else:
		if DAT.death_reason == "default":
			DAT.death_reason = death_reason
		await get_tree().create_timer(1.0).timeout
		SOL.clear_vfx()
		LTS.to_game_over_screen()


func _grant_rewards() -> void:
	var BRT := BattleRewards.Types
	var magnet := 0.0
	for i in party:
		if i.has_status_effect("magnet"):
			if not magnet:
				magnet = 1.0
			magnet = (i.get_status_effect("magnet").strength + magnet)
	magnet = minf(magnet, 3.5)
	if magnet:
		SOL.dialogue("magnet_used")
		for reward in battle_rewards.rewards:
			if reward.type == BRT.EXP or reward.type == BRT.SILVER:
				reward.property = str(float(reward.property) * (magnet + 1.0))
	await get_tree().process_frame
	battle_rewards.grant()


# main screen buttons wired to these
func _on_attack_pressed() -> void:
	if is_ui_locked():
		return
	doing = Doings.ATTACK
	open_list_screen()
	SND.menusound()


func _on_spirit_pressed() -> void:
	if is_ui_locked():
		return
	if current_guy.character.spirits.size() < 1:
		SND.menusound(0.3)
		set_description("this one has no spirits.")
		return
	doing = Doings.SPIRIT
	open_list_screen()
	SND.menusound()
	spirit_name.modulate = Color(1, 1, 1, 1)


func _on_item_pressed() -> void:
	if is_ui_locked():
		return
	doing = Doings.ITEM_MENU
	open_list_screen()
	SND.menusound()


func open_dance_battle_screen(actor: EnemyAnimal, target: BattleActor) -> void:
	doing = Doings.DANCE_BATTLE
	listening_to_player_input = true
	hide_screens()
	screen_dance_battle.reset()
	screen_dance_battle.show()
	resize_panel(44)
	screen_dance_battle.active = true
	screen_dance_battle.enemy_level = actor.character.attack as int
	screen_dance_battle.target_level = target.character.attack as int
	screen_dance_battle.enemy_reference = actor
	screen_dance_battle.target_reference = target
	if is_instance_valid(SND.current_song_player):
		var bpm := screen_dance_battle.mbc.bpm
		var stream := SND.current_song_player.stream
		var calculated_pitch := bpm / float(stream.bpm)
		create_tween().tween_property(
			SND.current_song_player,
			"pitch_scale",
			calculated_pitch,
			0.5
		)


func _dance_battle_ended(data: Dictionary) -> void:
	var actor: EnemyAnimal = data.get("enemy_reference")
	var player := data.get("player_reference") as BattleActor
	var pscore := data.get("player_score") as float
	var enscore := data.get("enemy_score") as float
	var pwin := pscore > enscore
	var wscore := pscore if pwin else enscore
	var lscore := enscore if pwin else pscore
	var winner := (player if pwin else actor) as BattleActor
	var loser := (actor if pwin else player) as BattleActor
	if is_instance_valid(SND.current_song_player):
		create_tween().tween_property(
				SND.current_song_player,
				"pitch_scale",
				1.0,
				0.5
		)
	loser.handle_payload(BattlePayload.new().set_sender(
				actor).set_health(-(wscore - 0.333 * lscore
		)).set_defense_pierce(1).set_effects(
				[StatusEffect.new().set_effect_name("defense"
				).set_duration(8).set_strength(-55)]))
	message("%s punished %s" %
			[winner.character.name, loser.character.name],
			{"alignment": HORIZONTAL_ALIGNMENT_CENTER})
	open_party_info_screen()
	get_tree().create_timer(0.5).timeout.connect(func(): winner.turn_finished())
	if pwin and player in party:
		xp_pool += ceili((pscore - enscore) / 3.0)


func set_description(text: String) -> void:
	description_text.text = text
	if text.ends_with("%s"):
		description_text.text = text % "hands"
		if current_guy.character.weapon:
			description_text.text = text % ResMan.get_item(
					current_guy.character.weapon).name


func highlight_selected_enemy(enemy: BattleActor = null) -> void:
	for e in enemies:
		e.modulate = Color(1, 1, 1, 1)
		e.position.y = 0
	if not (enemy and enemy is BattleEnemy):
		return
	enemy.modulate = Color(1.2, 1.2, 1.2, 1.3)
	var tw := create_tween()
	tw.tween_property(enemy, "position:y", -2, 0.1)


func resize_panel(new_y: int, wait := 0.2) -> void:
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	tw.tween_property(panel, "size:y", new_y, wait)
	tw.tween_property(panel, "position:y", SCREEN_SIZE.y - new_y, wait)


# update the party faces not every frame
func _on_update_timer_timeout() -> void:
	pass


func hide_screens() -> void:
	screen_dance_battle.hide()
	screen_end.hide()
	screen_item_select.hide()
	screen_list_select.hide()
	screen_main_actions.hide()
	screen_party_info.hide()
	screen_spirit_name.hide()


# load info from battle info
func _option_init(options := {}) -> void:
	load_options = options.get("battle_info")


# woh
func append_action_history(type: String, parameters := {}) -> void:
	var dict := {}
	dict["type"] = type
	dict["parameters"] = parameters
	dict["time"] = Time.get_time_string_from_system()
	action_history.append(dict)


func is_end() -> bool:
	return doing == Doings.END or doing == Doings.DONE


func load_floating_spirits() -> void:
	for i in current_guy.character.spirits:
		var s := SOL.vfx("spirit_name_hint", Vector2(), {spirit = i}) as Node
		s.add_to_group("floating_spirits")


func erase_floating_spirits() -> void:
	for i in get_tree().get_nodes_in_group("floating_spirits"):
		i.del()


func item_names(opt := {}) -> void:
	var count: int = current_guy.character.inventory.count(opt.reference)
	opt.button.text = str(
		str(count, "x ") if count > 1 else "",
		ResMan.get_item(opt.reference).name
		).left(15)


func remote_transforms(yes: bool) -> void:
	for i in party_node.get_child_count():
		var node := party_node.get_child(i) as BattleActor
		var inf := screen_party_info.get_child(0).get_child(i) as PartyMemberInfoPanel
		inf.remote_transform.remote_path = node.get_path() if yes else NodePath()
		inf.remote_transform.set_physics_process(yes)
		inf.remote_transform.force_update_cache()
		if not yes: node.global_position.y += 100


func _on_crit_received() -> void:
	var tw := create_tween().set_trans(Tween.TRANS_BOUNCE)
	tw.tween_property(background_container, "modulate", Color(2, 2, 2), 0.5)
	tw.tween_property(background_container, "modulate", Color(1, 1, 1), 0.5)


func _on_dance_battle_requested(actor: EnemyAnimal, target: BattleActor) -> void:
	message("dance battle!!")
	if target in party:
		set_actor_states(BattleActor.States.IDLE, true)
		open_dance_battle_screen(actor, target)
	else:
		_dance_battle_ended({
			"enemy_reference": actor,
			"player_reference": target,
			"enemy_score": ceilf(randf() * actor.get_attack() * 3),
			"player_score": ceilf(randf() * target.get_attack() * 3),
		})


func set_greg_speed() -> void:
	BattleActor.player_speed_modifier = 5.0 / float(party.map(func(a):
		return a.character.speed).max())


func is_ui_locked() -> bool:
	return SOL.dialogue_open or not ui.visible or ui.modulate.a < 1.0
