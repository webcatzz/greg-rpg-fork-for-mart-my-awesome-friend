@tool
extends Node2D

@export var radius := 120.0
@export var arrange_us: bool: set = arrange


func arrange(_to := false) -> void:
	var amt := get_child_count()
	for i in amt:
		var child := get_child(i)
		var to: float = roundf(-radius/2.0 + radius/float(amt)*(i+1) - radius/float(amt)/2.0)
		child.position.x = to
