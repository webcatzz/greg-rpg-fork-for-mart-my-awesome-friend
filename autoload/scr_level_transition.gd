extends Node


func change_scene_to(path: String, options := {}) -> void:
	get_tree().root.get_child(-1).queue_free()
	var free_us := get_tree().get_nodes_in_group("free_on_scene_change")
	if options.get("free_those_nodes", true):
		for node in free_us:
			node.call_deferred("queue_free")
	var new_scene : PackedScene = load(path)
	get_tree().root.add_child(new_scene.instantiate())


func level_transition(path: String, options := {}) -> void:
	var fadetime : float = options.get("fade_time", 1.0)
	SOL.fade_screen(Color(0, 0, 0, 0), Color(0, 0, 0, 1), fadetime)
	await SOL.fade_finished
	DAT.save_nodes_data()
	change_scene_to(path)
	SOL.fade_screen(Color(0, 0, 0, 1), Color(0, 0, 0, 0), fadetime)
