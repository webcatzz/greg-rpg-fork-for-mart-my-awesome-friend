extends CharacterBody2D
class_name PlayerOverworld

enum States {FREE_MOVE, NOT_FREE_MOVE}
enum Rots {UP = -1, RIGHT, DOWN, LEFT}

const SPEED := 2600
const INTERACTION_LENGTH := 16
const ROTS = [&"up", &"right", &"down", &"left"]

var input := Vector2()
var state : int

@onready var raycast : RayCast2D = $InteractionRay
@onready var sprite : AnimatedSprite2D = $Sprite


func _ready() -> void:
	if DAT.gate_id == DAT.Gates.LOADING:
		position = DAT.A.get("player_position", position)


func _physics_process(delta: float) -> void:
	input = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	if state == States.FREE_MOVE:
		movement(delta)
		if input: direct_raycast()
		if Input.is_action_just_pressed("ui_accept"):
			interact()
	
	direct_animation()


func movement(delta: float) -> void:
	velocity = Vector2()
	
	velocity = input * SPEED * delta
	
	var _collided := move_and_slide()
	
	global_position.x = roundi(global_position.x)
	global_position.y = roundi(global_position.y)


func direct_raycast() -> void:
	raycast.target_position = input.normalized() * INTERACTION_LENGTH


func direct_animation() -> void:
	sprite.animation = str("walk_", ROTS[Math.dir_from_rot(raycast.target_position.angle()) + 1])
	sprite.speed_scale = velocity.length_squared() * 0.0006
	sprite.frame = 0 if is_zero_approx(velocity.length_squared()) else sprite.frame


func interact() -> void:
	var collider := raycast.get_collider()
	if is_instance_valid(collider) and collider.has_method("interacted"):
		collider.call("interacted")
	print("" if not collider else collider.name)


func _save_me() -> void:
	DAT.set_data("player_position", position)


