extends Node2D

func _process(delta):
	$Polygon2D2.position=get_global_mouse_position()

func _unhandled_input(event):
	if event.is_action_pressed("debug_grid_toggle"):
		VerletEngine.debug_grid=VerletEngine.debug_grid!=true
