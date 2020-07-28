extends Node2D

export (float) var rotation_speed=2.09

func _process(delta):
	$Polygon2D2.position=get_global_mouse_position()
	
	var rotation:=.0
	if Input.is_action_pressed("rotate_right"):
		rotation+=rotation_speed
	if Input.is_action_pressed("rotate_left"):
		rotation-=rotation_speed
	
	$Polygon2D2.rotate(rotation*delta)

func _unhandled_input(event):
	if event.is_action_pressed("debug_grid_toggle"):
		VerletEngine.debug_grid=VerletEngine.debug_grid!=true
