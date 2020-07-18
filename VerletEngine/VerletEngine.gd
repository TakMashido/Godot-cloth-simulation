extends Node2D

var debug_grid:=false
var debug_statistics:=false setget set_debug_statistics, get_debug_statistics
var __debug_hud
var vertex_process_time:=0
var connection_process_time:=0

var vertex_position:=PoolVector2Array()
var vertex_previous_position:=PoolVector2Array()
var vertex_friction:=PoolRealArray()					#-1.0 indicates no existing
var vertex_gravity:=PoolVector2Array()

var connection_vertex1:=PoolIntArray()					#first vertex always have smaller id then corresponding second vertex. Speed up connection searching
var connection_vertex2:=PoolIntArray()
var connection_length:=PoolRealArray()					#-1.0 indicates no existing
var connection_length_fix_multiplier:=PoolRealArray()

var free_vertexes=[]
var free_connections=[]

var default_gravity=Vector2(.0,9.8)

func _ready():
	z_index=1
	
	__debug_hud=CanvasLayer.new()
	__debug_hud.name="HUD"
	var label=Label.new()
	label.name="Label"
	__debug_hud.add_child(label)
	
	if debug_statistics:
		add_child(__debug_hud)
	
	var prop=ProjectSettings.get_setting("physics/Verlet/default_gravity")
	if prop is Vector2:
		default_gravity=prop
	prop=ProjectSettings.get_setting("physics/Verlet/debug_grid")
	if prop is bool:
		debug_grid=prop
	prop=ProjectSettings.get_setting("physics/Verlet/debug_statistics")
	if prop is bool:
		set_debug_statistics(prop)

#Add new vertex in given position. returns id of new vertex
#@param gravity Constant adder to vertex move formula. type: float: multiplier for default physics 2d gravity, Vector2: final gravity vector
#Warning not async
func add_vertex(position,friction:=1.0,gravity=1.0):
	if typeof(gravity)==TYPE_REAL:
		gravity=default_gravity*gravity
	
	var id
	if free_vertexes.empty():
		id=vertex_position.size()
		
		vertex_position.append(position)
		vertex_previous_position.append(position)
		vertex_friction.push_back(friction)
		vertex_gravity.push_back(gravity)
	else:
		id=free_vertexes.pop_back()
		
		vertex_position[id]=position
		vertex_previous_position[id]=position
		vertex_friction[id]=friction
		vertex_gravity[id]=gravity
	
	return id

#Remove vertex with given id
func remove_vertex(id):
	vertex_friction[id]=-1.0
	free_vertexes.push_back(id)

#Add connection beetwen vertexes. Returns id of added connection
#Warning not async
func add_connection(vertex_id,vertex2_id,length_fix_multiplier=1.0,length:=-1.0):
	if length==-1.0:
		length=vertex_position[vertex_id].distance_to(vertex_position[vertex2_id])
	
	if vertex_id>vertex2_id:
		var swap=vertex_id
		vertex_id=vertex2_id
		vertex2_id=swap
	
	var id
	if free_vertexes.empty():
		id=connection_vertex1.size()
		
		connection_vertex1.append(vertex_id)
		connection_vertex2.append(vertex2_id)
		connection_length.push_back(length)
		connection_length_fix_multiplier.push_back(length_fix_multiplier)
	else:
		id=free_connections.pop_back()
		
		connection_vertex1[id]=vertex_id
		connection_vertex2[id]=vertex2_id
		connection_length[id]=length
		connection_length_fix_multiplier[id]=length_fix_multiplier
	
	return id

#Remove connection with given id
func remove_connection(id):
	connection_length[id]=-1.0
	free_connections.push_back(id)

var accum_delta:=.0
var delta_treshold=.5
func _physics_process(delta):
#	accum_delta+=delta
#	if accum_delta<delta_treshold:
#		return
#	accum_delta-=delta_treshold
	var time=OS.get_system_time_msecs()
	__process_vertex(delta)
	var time2=OS.get_system_time_msecs()
	vertex_process_time=time2-time
	__process_connection(delta)
	connection_process_time=OS.get_system_time_msecs()-time2
	pass

func __process_vertex(delta):
	for id in range(0,vertex_position.size()):
		if vertex_friction[id]==-1:
			continue
		
		if vertex_friction[id]==0.0:				#static vertex
			vertex_position[id]=vertex_previous_position[id]
		else:
			var dis=vertex_position[id]-vertex_previous_position[id]
			vertex_previous_position[id]=vertex_position[id]
			var grav=vertex_gravity[id]
			grav.x*=delta
			grav.y*=delta
#			vertex_position[id]+=dis*vertex_friction[id]+grav
			vertex_position[id]+=(dis+grav)*vertex_friction[id]

func __process_connection(_delta):
	for id in range(0,connection_vertex1.size()):
		if connection_length[id]==-1.0:
			continue
		
		var pos1=vertex_position[connection_vertex1[id]]
		var pos2=vertex_position[connection_vertex2[id]]
		
		var distance_vec=pos1-pos2
		if distance_vec.x!=0:			#TODO very small x can lead to big rounding error. Some ditortion visible on simulation dunno if it's this
			var length_delta=distance_vec.length()
			var sinn=distance_vec.x/length_delta
			var tangent=distance_vec.y/distance_vec.x
			
			length_delta=(length_delta-connection_length[id])/2.0*connection_length_fix_multiplier[id]
			
			var dx=sinn*length_delta
			var pos_delta=Vector2(dx,dx*tangent)
			
			vertex_position[connection_vertex1[id]]-=pos_delta
			vertex_position[connection_vertex2[id]]+=pos_delta
		else:
			var length_delta=(distance_vec.y-connection_length[id])/2.0*connection_length_fix_multiplier[id]
			
			vertex_position[connection_vertex1[id]].y-=length_delta
			vertex_position[connection_vertex2[id]].y+=length_delta

func _process(_delta):
	update()
	
	if debug_statistics:
		$HUD/Label.text="vertices: %d \t%dms\nconnections: %d \t%dms\nmouse position: %s"%[vertex_position.size()-free_vertexes.size(),vertex_process_time,connection_vertex1.size()-free_vertexes.size(),connection_process_time,get_global_mouse_position()]

func set_debug_statistics(val):
	if debug_statistics==val:
		return
	debug_statistics=val
	if val:
		add_child(__debug_hud)
	else:
		remove_child(__debug_hud)
func get_debug_statistics():
	return debug_statistics

func _draw():
	if !debug_grid:
		return
	
	var rect=Rect2(.0,.0,4.0,4.0)
	
	for connection in range(connection_vertex1.size()):
		draw_line(vertex_position[connection_vertex1[connection]], vertex_position[connection_vertex2[connection]], Color.green)
	
	for vertex in vertex_position:
		rect.position=vertex-Vector2(2.0,2.0)
		draw_rect(rect,Color.red)
