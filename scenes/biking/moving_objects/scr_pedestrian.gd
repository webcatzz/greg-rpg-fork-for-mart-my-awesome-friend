extends BikingObstacle


func _ready():
	randomise_position()
	
	var sprites: PackedStringArray = DirAccess.get_files_at("res://sprites/characters/overworld/")
	$Sprite2D.texture = sprites[randi() % sprites.size()]
	
	
	if randf() > 0.5: # cross downward
		position.y = 64
		await get_tree().create_timer(randfn(1.5, 0.5)).timeout
		get_tree().create_tween().tween_property(self, "position:y", 124, randf_range(0.1, 10))
	else: # cross upward
		position.y = 124
		await get_tree().create_timer(randfn(1.5, 0.5)).timeout
		get_tree().create_tween().tween_property(self, "position:y", 64, randf_range(0.1, 10))
		
		if $Sprite2D.texture.get_height() == 64: # facing upward if upward sprite exists
			$Sprite2D.region.y = 48


func _on_walk_anim_timer_timeout() -> void:
	$Sprite2D.region.x = ($Sprite2D.region.x + 16) % $Sprite2D.texture.get_width()
