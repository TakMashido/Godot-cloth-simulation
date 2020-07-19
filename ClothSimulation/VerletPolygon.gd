extends Polygon2D

enum SortType{
	NONE=0,						#No sorting
	FORWARD=1,					#Left/Upper site last(drawed at top)
	REVERSED=-1					#Right/Bottom site last(drawed at top)
}
enum DataSource{
	POLYGON,					#vertexes and connections from polygon
	UV							#connection from uv(lenght), vertexes position from polygon
}

export (DataSource) var data_source=DataSource.POLYGON
#Vertices and connections data source.
export (Array, int) var static_vertices=[]
export (int, 10) var interpolation_steps=1				#Waring each step increase computation time ~4 times
#Sort polygons
export (SortType) var x_sort=SortType.FORWARD
export (SortType) var y_sort=SortType.FORWARD
export (float,0,1.1) var connection_compress_elasticity=.05
export (float,0,1.1) var connection_strech_elasticity=.8
export (float,0,2) var connection_strech_treshold=1.1
#Subarray used in chained way - for [[1,2],[3,4,5]] adds 1,2 connections and 3,4 4,5 5,3 
export (Array, Array, int) var additional_connections=[]

var default_vertex_friction:=.999

var vertexes=[]
var connections=[]

func _ready():
	for _i in range(0,interpolation_steps):
		__interpolate_polygons()
	
	var vertex_source
	match data_source:
		DataSource.POLYGON:
			vertex_source=polygon
		DataSource.UV:
			vertex_source=uv
	
	#Discard empty polygons
	if vertex_source.size()==0||polygons.size()==0:
		assert(false,"Invalid polygon2d you have to define vertexes/polygons")
		return
	
	#Vertexes from polygon
	for vertex in vertex_source:
		vertexes.push_back(VerletEngine.add_vertex(vertex+global_position,default_vertex_friction))
	
	#sort polygons
	if x_sort!=SortType.NONE or y_sort!=SortType.NONE:
		#Calculate polygon centers(vertexes position avarage) for sorting
		var polygons_center=PoolVector2Array()
		for poly in polygons:
			var pos=Vector2()
			for vertex in poly:
				pos+=VerletEngine.vertex_position[vertexes[vertex]]
			pos.x/=poly.size()
			pos.y/=poly.size()
			polygons_center.append(pos)
		
		var ready=false
		while !ready:								#Double way bubble sort
			ready=true
			for i in range(1,polygons.size()):
				if __sort_compare(polygons_center[i],polygons_center[i-1])<0:
					ready=false
					
					var swap=polygons_center[i]
					polygons_center[i]=polygons_center[i-1]
					polygons_center[i-1]=swap
					
					swap=polygons[i]
					polygons[i]=polygons[i-1]
					polygons[i-1]=swap
			for i in range(polygons.size()-1,0):
				if __sort_compare(polygons_center[i],polygons_center[i+1])>0:
					ready=false
					
					var swap=polygons_center[i]
					polygons_center[i]=polygons_center[i+1]
					polygons_center[i+1]=swap
					
					swap=polygons[i]
					polygons[i]=polygons[i+1]
					polygons[i+1]=swap
	
	#Connections from polygon
	var known_connections=[]				#TODO change to dictionary
	for poly in polygons:
		if known_connections.find([poly[0],poly[poly.size()-1]])==-1:
			known_connections.push_back([poly[0],poly[poly.size()-1]])
#			connections.push_back(VerletEngine.add_linear_connection(vertexes[poly[0]], vertexes[poly[poly.size()-1]],default_connection_strength))
			connections.push_back(VerletEngine.add_double_linear_connection(vertexes[poly[0]], vertexes[poly[poly.size()-1]], connection_compress_elasticity, connection_strech_elasticity, connection_strech_treshold))
		for i in range(1,poly.size()):
			if known_connections.find([poly[i],poly[i-1]])==-1:
				known_connections.push_back([poly[i],poly[i-1]])
#				connections.push_back(VerletEngine.add_linear_connection(vertexes[poly[i-1]], vertexes[poly[i]], default_connection_strength))
				connections.push_back(VerletEngine.add_double_linear_connection(vertexes[poly[i-1]], vertexes[poly[i]], connection_compress_elasticity, connection_strech_elasticity, connection_strech_treshold))
	
	#Custom connections
	for poly in additional_connections:
		if known_connections.find([poly[0],poly[poly.size()-1]])==-1:
			known_connections.push_back([poly[0],poly[poly.size()-1]])
			connections.push_back(VerletEngine.add_double_linear_connection(vertexes[poly[0]], vertexes[poly[poly.size()-1]], connection_compress_elasticity, connection_strech_elasticity, connection_strech_treshold))
		for i in range(1,poly.size()):
			if known_connections.find([poly[i],poly[i-1]])==-1:
				known_connections.push_back([poly[i],poly[i-1]])
				connections.push_back(VerletEngine.add_double_linear_connection(vertexes[poly[i-1]], vertexes[poly[i]], connection_compress_elasticity, connection_strech_elasticity, connection_strech_treshold))
	
	#Change pointed vertices to static
	for vertex in static_vertices:
		VerletEngine.vertex_friction[vertexes[vertex]]=.0
	
	#Calculate verticles "weight" based on local point density
	var neighborhood_weight=PoolRealArray()
	for vertex in vertexes:
		var weight=1.0
		for vertex2 in vertexes:
			var distance=VerletEngine.vertex_position[vertex].distance_to(VerletEngine.vertex_position[vertex2])
			if distance==0:
				continue
			weight+=1.0/distance
		neighborhood_weight.append(weight*2.0)
	var min_weight=neighborhood_weight[0]
	for weight in neighborhood_weight:
		if weight<min_weight:
			min_weight=weight
	for i in range(neighborhood_weight.size()):
		neighborhood_weight[i]/=min_weight
		VerletEngine.vertex_gravity[vertexes[i]]/=Vector2(neighborhood_weight[i],neighborhood_weight[i])
	
	#Data source fixes
	if data_source==DataSource.UV:
		for i in range(0,vertexes.size()):
			var pos=polygon[i]+global_position
			VerletEngine.vertex_position[vertexes[i]]=pos
			VerletEngine.vertex_previous_position[vertexes[i]]=pos
	
#	displace_vertexes(32)

#Interpolate polygons, generate additional vertexes and polygons for better simalation details.
#Increases vertexes number ~2 times, polygons >4 times and connections for VerletEngine 3 times in each pass
#Details:
#traingle polygons: add new vertex in sites centers and from new triangle from them
#n-gon: add new vertex in sites centers and n-gon center(points avarage), from new 4-gon from corner, center, 2-sitescenters
func __interpolate_polygons():
	var new_polygons=[]
	var new_polygon=polygon
	var new_uv=uv
	
	var added_vertexes={}						#[pre_ver1,pre_ver2]:new_ver			pre_ver1<pre_ver2
	for i in range(0,polygons.size()):
		var poly=polygons[i]
		
		match poly.size():
			3:
				var new_ver=[]
				for con in __get_polygon_connections(poly):
					var vertex_id=added_vertexes.get(con)
					if vertex_id!=null:
						new_ver.push_back(vertex_id)
					else:
						var vertex=(polygon[con[0]]+polygon[con[1]])/Vector2(2,2)
						
						added_vertexes[con]=new_polygon.size()
						new_ver.push_back(new_polygon.size())
						
						new_polygon.append(vertex)
						new_uv.append((uv[con[0]]+uv[con[1]])/Vector2(2,2))
				
				new_polygons.push_back([poly[0],new_ver[1],new_ver[0]])
				new_polygons.push_back([poly[1],new_ver[2],new_ver[1]])
				new_polygons.push_back([poly[2],new_ver[0],new_ver[2]])
				new_polygons.push_back([new_ver[0],new_ver[1],new_ver[2]])
			_:
				var size=poly.size()
				var new_ver=[]
				
				var polygon_center=Vector2()
				var uv_center=Vector2()
				for vertex in poly:
					polygon_center+=polygon[vertex]
					uv_center+=uv[vertex]
				polygon_center/=Vector2(size,size)
				uv_center/=Vector2(size,size)
				
				var center=new_polygon.size()
				
				new_polygon.append(polygon_center)
				new_uv.append(uv_center)
				
				for con in __get_polygon_connections(poly):
					if con[0]>con[1]:
						var swap=con[0]
						con[0]=con[1]
						con[1]=swap
					
					var vertex_id=added_vertexes.get(con)
					if vertex_id!=null:
						new_ver.push_back(vertex_id)
					else:
						var vertex=(polygon[con[0]]+polygon[con[1]])/Vector2(2,2)
						
						added_vertexes[con]=new_polygon.size()
						new_ver.push_back(new_polygon.size())
						
						new_polygon.append(vertex)
						new_uv.append((uv[con[0]]+uv[con[1]])/Vector2(2,2))
				
				for i in range(size):
					new_polygons.push_back([poly[i],new_ver[(i+1)%size],center,new_ver[i]])
	
	#Make vertexes beetwen 2 static vertexes static
	for key in added_vertexes.keys():
		if key[0]>key[1]:
			print(key)
		if static_vertices.find(key[0])!=-1 and static_vertices.find(key[1])!=-1:
			static_vertices.append(added_vertexes[key])
	
	polygons=new_polygons
	polygon=new_polygon
	uv=new_uv

#shourtcut for getting connections in polygons
func __get_polygon_connections(polygon)->Array:
	var ret=[]
	
	ret.push_back([polygon[0],polygon[polygon.size()-1]])
	for i in range(1,polygon.size()):
		ret.push_back([polygon[i-1],polygon[i]])
	
	for i in range(0,ret.size()):
		if ret[i][0]>ret[i][1]:
			var swap=ret[i][0]
			ret[i][0]=ret[i][1]
			ret[i][1]=swap
	
	return ret

#returns inner id of connection beetwen points or -1 if not found
func __get_connection(vertex1,vertex2)->int:
	vertex1=vertexes[vertex1]
	vertex2=vertexes[vertex2]
	
	if vertex1>vertex2:
		var swap=vertex1
		vertex1=vertex2
		vertex2=swap
	
	for i in range(0,connections.size()):
		var connection=connections[i]
		
		var ver1=VerletEngine.connection_vertex1[connection]
		var ver2=VerletEngine.connection_vertex2[connection]
		
		if vertex1==ver1 and vertex2==ver2:
			return i
		
	return -1

#returns: ret==0: pos1==pos2 ret>0: pos1>pos2 ret<0: pos1<pos2. Comparision done according to setted sort rules
func __sort_compare(var pos1, var pos2)->float:
	return (pos2.x-pos1.x)*x_sort+(pos2.y-pos1.y)*y_sort

func displace_vertexes(displacement):
	for vertex in vertexes:
		if VerletEngine.vertex_friction[vertex]!=0:
			VerletEngine.vertex_position[vertex]+=Vector2(rand_range(-displacement,displacement),rand_range(-displacement,displacement))
			VerletEngine.vertex_previous_position[vertex]+=Vector2(rand_range(-displacement,displacement),rand_range(-displacement,displacement))

onready var previus_global_position:=global_position
func _physics_process(_delta):
	for vertex in static_vertices:
		VerletEngine.vertex_previous_position[vertexes[vertex]]+=global_position-previus_global_position
	previus_global_position=global_position
	
	for i in range(vertexes.size()):
		polygon[i]=VerletEngine.vertex_position[vertexes[i]]-global_position
