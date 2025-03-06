@tool
class_name TorusCollider
extends Node3D

@export var node_to_use_as_parent : Node = self
@export var inner_radius : float = 0
@export var outer_radius : float = 0
@export var segments : int = 12

#perhaps
#@export var axial_vector : Vector3 = Vector3.UP
#@export var normalize : bool = false:
#	set(value):
#		axial_vector = axial_vector.normalized()

@export var update : bool = false:
	set(value):
		generate()

func generate():
	#get vector that points between inner and outer radius
	var radius_thickness : float = (outer_radius - inner_radius) * 0.5
	var radius_center : Vector3 = Vector3.RIGHT * (inner_radius + outer_radius) * 0.5
	var rotation_increment : float = 360.0 / segments
	
	#generate collisionshape
	var collision_shape : CylinderShape3D = CylinderShape3D.new()
	collision_shape.radius = radius_thickness
	collision_shape.height = tan(PI / segments) * (radius_center.length() + radius_thickness) * 2
	
	#clear existing collisionshapes
	for j in node_to_use_as_parent.get_children():
		if j is CollisionShape3D:
			j.queue_free()
	
	for i in segments:
		if node_to_use_as_parent == null:
			break
		
		#start adding segments to the ring
		var node : CollisionShape3D = CollisionShape3D.new()
		node.shape = collision_shape
		node_to_use_as_parent.add_child(node)
		node.owner = get_tree().edited_scene_root
		if i == 0:
			node.name = "CollisionShape3D"
		else:
			node.name = "CollisionShape3D" + str(i)
			
		
		radius_center = radius_center.rotated(Vector3.UP, deg_to_rad(rotation_increment))
		node.position = radius_center
		
		node.basis = node.basis.rotated(radius_center.normalized(), TAU * 0.25)
