#ClothSimulation

Cloth simulation for Godot. Created to make realistic cloaks in my project.
Sadly not very user friendly, I'm quite new and dunno how to integrate some feauters with editor. There are settuped as Script variables

##Dependencies

Godot 3.2.1

##Usage

###Demo
Download reposity and launch it as godot project. Load scene Test1 and run.

###In project use
1. Add VerletEngine/VerletEngin.gd as singleton to your project

2. Add cloth node
  1. Add Polygon2d to scene, and att VerletPolygon.gd script to it.
  2. In Polygon2D uv editor setup points and add Polygons, Script will automaticly setup desired Verlet simulation and update polygon points position with simulation resoults.
  3. Set up Static verticles script variable to anchor desired points. (check index of desired vertexes e.g in data/uv of polygon and add to parameter list)

##Script Variables

###Data Source
Polygon: Vertex settuped as seen in Polygon2D uv editor  
UV: Lenght and connection grid form uv, final vertex positions from polygon vertexes position
###Static verticles
List of static(archoned verticles) there are not moved by vertex simulation, but are archoned to Polygon, moves with it's global position change.  
You have to check index(eg in Polygon2D/data/uv) of vertices you want to anchor and put them there.
###Interpolation steps
How many times interpolate polygon for more simulation details.  
Each step doubles vertex count, and triples connections number.  
1 should be enought for most cases, use 2 for bigger elements(half of screen or more).
###x sort, y sort
Sort polygon faces to ensure right draw order.  
None: Distable sorting by this coordinate  
Forward: Left/Upper site last(drawed at top)  
Reversed: Right/Bottom site last(drawed at top).
###Default connection strength
Strength of connection, affect how fast connections go back to it's orginal length. Smaller values are more rubbery.
###Additional connections
Array of lists of vetices indexes(lookup static vertices) beetwen wich you want to add extra connections.  
Each entry is treated as polygon so [1,4] add connection beetwen 1-4, and [3,7,1] adds 3-7, 1-7 and 1-3.

##TODO
Add option to interpolate only edges- smaller amunt of vertices is barery visible on places with lesser amount, making so will increase performace by decreasing number of vertices and connections  
Add weight to simulated vertices  
Add non linear force connections, compressing cloth should requaire way less force than streaching