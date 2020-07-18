# VerletEngine

Physics engine based on Verlet integration.

## Dependencies

Godot 3.2.1

## Properties
 
You can use following godot project properties:

* physics/Verlet/default_gravity: Vector2 Default gravity for vertexes. If not specyfied Vector2(.0,9.8) used.
* physics/Verlet/debug_grid: bool Draw vertexes and connections on screen. false by default.
* physics/Verlet/debug_statistics: bool Print amount of vertexes, connections and their process time on screen.

## Usage

Add VerletEngin.gd script as singleton to project to use.
This script does nothing by itself, it's only responsible for Verlet integration phisics simulataion. Check other project to test(e.g. Cloth Simulator)