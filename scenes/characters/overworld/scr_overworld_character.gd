extends CharacterBody2D
class_name OverworldCharacter

# this is the overworld npcs class
# they can walk around, chase you, you can talk to them if they have dialogue

signal target_reached
signal inspected
signal cannot_reach_target

enum Rots {UP = -1, RIGHT, DOWN, LEFT}
const ROTS := [&"up", &"right", &"down", &"left"]
enum States {IDLE, TALKING, WANDER, CHASE, PATH}
var state := States.IDLE

@export_group("Nodes")
@export var animated_sprite: AnimatedSprite2D
@export var collision_shape: CollisionShape2D
@export var collision_extents := Vector2i(8, 3): set = _set_collision_extents
@export var collision_detection_area: Area2D
@export var detection_area: Area2D
@export var detection_raycast: RayCast2D

@export_group("Movement")
@export var speed := 3500
@export var movement_wait := 5.0:
	set(to):
		movement_wait = to
		time_between_chase_updates = to * 0.05
@export var random_movement := false
var time_between_chase_updates := 0.25
@export var random_movement_distance := 64
var idle_timer: Timer
var random_movement_timer: Timer
const RANDOM_MOVEMENT_TRIES := 16
var chase_timer: Timer
var time_moved := 0.0
var time_moved_limit := 2.5
@export var chase_target: Node2D
@export var chase_distance := 32
@export var chase_closeness := 6
@export var path_container: Node2D
var path_timer: Timer

@export_group("Interaction")
@export var action_right_after_dialogue := false
@export var interact_on_touch := false
var convo_progress := 0
@export var default_lines: Array[StringName]
@export var battle_info: BattleInfo
@export var transport_to_scene := ""
var interactions := 0
# collision disabling
var player_colliding := false
var player_collision_timer := Timer.new()

@export_group("Save Information")
@export var save := true
@export var save_position: bool = false
@export var save_convo_progess: bool = false

var target: Vector2: set = set_target


func _ready() -> void:
	# load stuff
	if LTS.gate_id == LTS.GATE_LOADING:
		pass
	if save_position:
		set_position(DAT.get_data(get_save_key("position"), global_position))
	if save_convo_progess:
		convo_progress = DAT.get_data(get_save_key("convo_progress"), 0)
	# setup
	random_movement_timer = Timer.new()
	add_child(random_movement_timer)
	random_movement_timer.timeout.connect(_on_random_movement_timer_timeout)
	if random_movement:
		random_movement_timer.start(movement_wait)
	chase_timer = Timer.new()
	add_child(chase_timer)
	time_between_chase_updates = movement_wait * 0.05
	chase_timer.timeout.connect(_on_chase_timer_timeout)
	if chase_target:
		chase_timer.start(time_between_chase_updates)
	path_timer = Timer.new()
	add_child(path_timer)
	path_timer.one_shot = true
	path_timer.timeout.connect(_on_path_target_reached)
	if path_container:
		path_timer.start(movement_wait)
	idle_timer = Timer.new()
	add_child(idle_timer)
	idle_timer.timeout.connect(_on_idle_timer_timeout)
	idle_timer.start(8)
	collision_detection_area.on_interact.connect(interacted)
	collision_detection_area.body_entered.connect(_on_collision)
	collision_detection_area.body_exited.connect(_on_collision_ended)
	add_child(player_collision_timer)
	player_collision_timer.timeout.connect(_on_collision_timer_timeout)
	player_collision_timer.one_shot = true
	if detection_area:
		detection_area.get_child(0).shape.radius = chase_distance
		detection_area.body_entered.connect(_on_detection_area_body_entered)
	detection_raycast.add_exception(detection_area)
	detection_raycast.add_exception(collision_detection_area)


func _physics_process(delta: float) -> void:
	match state:
		States.IDLE:
			velocity = Vector2()
		States.TALKING:
			# idle if no longer talking
			if not is_instance_valid(SOL.dialogue_box.loaded_dialogue) or SOL.dialogue_box.loaded_dialogue.size() < 1:
				set_state(States.IDLE)
		States.CHASE:
			velocity = global_position.direction_to(target) * delta * speed
			# move as long as distance > 6 and hasn't moved for too long
			if global_position.distance_squared_to(target) > chase_closeness and time_moved < time_moved_limit:
				time_moved += delta
				var _collided := move_and_slide()
			else:
				if time_moved >= time_moved_limit:
					cannot_reach_target.emit()
				set_state(States.IDLE)
			# make diagonal movement faster to catch up with the player
			global_position.x = roundi(global_position.x)
			global_position.y = roundi(global_position.y)
		# moving towards target
		States.WANDER:
			velocity = global_position.direction_to(target) * delta * speed * 0.75
			if global_position.distance_squared_to(target) > 4 and time_moved < time_moved_limit:
				time_moved += delta
				var _collided := move_and_slide()
			else:
				if time_moved >= time_moved_limit:
					cannot_reach_target.emit()
				target_reached.emit()
				set_state(States.IDLE)
		# moving along a path
		States.PATH:
			velocity = global_position.direction_to(target) * delta * speed * 0.75
			if global_position.distance_squared_to(target) > 4 and time_moved < time_moved_limit:
				time_moved += delta
				var _collided := move_and_slide()
			else:
				target_reached.emit()
				path_timer.start(movement_wait)
				set_state(States.IDLE)
	if player_colliding:
		if interact_on_touch: interacted()
	direct_walking_animation(velocity)


# this is also called when "interact on collide" is turned on
func interacted() -> void:
	if DAT.player_capturers.size() > 0:
		if battle_info:
			set_collision_layer_value(4, false)
		return
	interactions += 1
	inspected.emit()
	if detection_area:
		var bods := detection_area.get_overlapping_bodies()
		bods.erase(self)
		bods.sort_custom(func(a, b):
			return (global_position.distance_squared_to(a.global_position) < 
					global_position.distance_squared_to(b.global_position))
			)
		direct_walking_animation(bods[0].global_position - global_position)
	if default_lines.size() > 0 or battle_info or len(transport_to_scene):
		set_state(States.TALKING)
		velocity = Vector2()
	if default_lines.size() > 0:
		var continuing := true
		if convo_progress >= default_lines.size():
			if battle_info != null or transport_to_scene != "":
				continuing = false
			else:
				convo_progress -= 1
		if continuing:
			SOL.dialogue(default_lines[convo_progress])
			if not SOL.dialogue_closed.is_connected(_on_talking_finished):
				SOL.dialogue_closed.connect(_on_talking_finished)
			convo_progress = mini(convo_progress + 1, default_lines.size())
			return
	if battle_info:
		if convo_progress + 1 >= default_lines.size() or default_lines.size() < 1:
			LTS.enter_battle(battle_info, {"sbcheck": true})
			set_physics_process(false)
			return
	if transport_to_scene:
		LTS.level_transition(transport_to_scene)
		set_physics_process(false)
		return


func _on_talking_finished() -> void:
	if path_container:
		set_state(States.PATH)
		path_timer.paused = false
	SOL.dialogue_closed.disconnect(_on_talking_finished)
	if action_right_after_dialogue:
		if battle_info:
			if convo_progress + 1 >= default_lines.size() or default_lines.size() < 1:
				LTS.enter_battle(battle_info, {"sbcheck": true})
				set_physics_process(false)
		if transport_to_scene:
			LTS.level_transition(transport_to_scene)
	_on_idle_timer_timeout()


func _on_random_movement_timer_timeout() -> void:
	if not state == States.IDLE: return
	if not random_movement: return
	# test if random target position is reachable
	for i in RANDOM_MOVEMENT_TRIES:
		set_target(global_position + Vector2(randi_range(-random_movement_distance, random_movement_distance), randi_range(-random_movement_distance, random_movement_distance)))
		detection_raycast.target_position = to_local(target)
		detection_raycast.force_raycast_update()
		var collider := detection_raycast.get_collider()
		if collider:
			target = detection_raycast.get_collision_point()
			break
		else: break
	set_state(States.WANDER)
	random_movement_timer.start(randfn(movement_wait, movement_wait * 0.25))


func _on_path_target_reached() -> void:
	if not state == States.IDLE: return
	if not path_container: return
	var path_points := path_container.get_children()
	if path_points:
		var current := at_which_path_point()
		var current_index := path_points.find(current)
		var next_index := wrapi(current_index + 1, 0, path_points.size())
		set_target(path_points[next_index].global_position)
		set_state(States.PATH)


func at_which_path_point() -> Node2D:
	var path_points := path_container.get_children()
	if path_points:
		path_points.sort_custom(sort_by_distance)
		return path_points.front()
	return null


func set_state(to: States) -> void:
	state = to
	if to == States.CHASE:
		chase_timer.start(time_between_chase_updates)
	if to == States.IDLE:
		time_moved = 0.0
	if to == States.TALKING:
		if path_timer:
			path_timer.paused = true


func direct_walking_animation(direction: Vector2) -> void:
	if not is_instance_valid(animated_sprite): return
	if is_zero_approx(direction.length_squared()):
		animated_sprite.stop()
		return
	idle_timer.start(randfn(8, 3))
	var animation_name := str("walk_", ROTS[Math.dir_from_rot(direction.angle()) + 1])
	if not animated_sprite.sprite_frames.has_animation(animation_name):
		return
	animated_sprite.play(animation_name)
	animated_sprite.speed_scale = velocity.length() * 0.04
	if is_zero_approx(velocity.length_squared()):
		animated_sprite.stop()


func _set_collision_extents(to: Vector2i) -> void:
	collision_extents = to
	if collision_shape:
		collision_shape.shape.size = to
	if collision_detection_area:
		if collision_detection_area.get_child_count() > 0:
			var interaction_collision: CollisionShape2D = collision_detection_area.get_child(0)
			interaction_collision.shape.size.x = to.x + 6
			interaction_collision.shape.size.y = to.x + 6


func _on_collision(_body: Node2D) -> void:
	if interact_on_touch:
		interacted()
	player_colliding = true
	player_collision_timer.start(2.0)


func _on_collision_ended(_body: Node2D) -> void:
	player_colliding = false
	player_collision_timer.stop()
	set_collision_layer_value(4, true)


func _on_collision_timer_timeout() -> void:
	set_collision_layer_value(4, not player_colliding)
	if interact_on_touch and player_colliding: interacted()


func _on_idle_timer_timeout() -> void:
	idle_timer.start(randfn(8, 3))
	if animated_sprite:
		if animated_sprite.animation != &"walk_down":
			direct_walking_animation(Vector2.DOWN)
		elif randf() < 0.33:
			direct_walking_animation(Vector2(randf_range(-1, 1), randf_range(-1, 1)))


func set_target(to: Vector2) -> void:
	target = to


# setting target with a randomised offset
func set_target_offset(to: Vector2, random := 5) -> void:
	target = to + Vector2(randf_range(-random, random), randf_range(-random, random))


func move_to(to: Vector2) -> void:
	set_target(to)
	set_state(States.WANDER)


func _on_detection_area_body_entered(body: Node2D) -> void:
	if chase_target == body:
		chase(body)


func chase(body: Node2D) -> void:
	# test if raycast can reach the target
	detection_raycast.target_position = to_local(body.global_position)
	detection_raycast.force_raycast_update()
	var collider := detection_raycast.get_collider()
	var collider_is_target := collider == chase_target
	
	# test if the raycast is colliding with another npc who is chasing the same target
	var same_target_as_collider_condition := false
	same_target_as_collider_condition = (is_instance_valid(collider) and "chase_target" in collider and collider.chase_target == chase_target)
	if not collider_is_target and not same_target_as_collider_condition:
		cannot_reach_target.emit()
		return
	time_moved = 0.0
	set_target_offset(body.global_position, 24 if same_target_as_collider_condition else 4) # if a bunch of npcs are chasing the same target, this will help make them not clump up together
	set_state(States.CHASE) # this also restarts the timer
	chase_timer.start(time_between_chase_updates)


func _on_chase_timer_timeout() -> void:
	var bodies := detection_area.get_overlapping_bodies()
	bodies.erase(self)
	for b in bodies:
		if b == chase_target:
			chase(b)
	if bodies.size() < 1:
		chase_timer.stop()


func debprint(msg) -> void:
	print("npc %s: " % name, msg)


func _save_me() -> void:
	if not save: return
	debprint("saving!")
	if save_position:
		DAT.set_data(get_save_key("position"), global_position)
	if save_convo_progess:
		DAT.set_data(get_save_key("convo_progress"), convo_progress)


func get_save_key(key: String) -> StringName:
	return StringName(
		str("npc_", name, "_in_",
		LTS.get_current_scene().name.to_snake_case(), "_", key))


func sort_by_distance(a: Node2D, b: Node2D) -> bool:
	return global_position.distance_squared_to(a.global_position) < global_position.distance_squared_to(b.global_position)




