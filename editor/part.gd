extends StaticBody3D
class_name Part

#exclude from export
@export var baseplate : bool = false

#make immovable
@export var locked : bool = false

@export_enum("Cuboid:0", "Wedge:1", "Cylinder:2", "Sphere:3") var part_shape = 0#:
	#set(value):
	#set the uhh collider and mesh to the corresponding shape
	
@export var part_scale : Vector3 = Vector3(0.4, 0.2, 0.8):
#size with setter
	set(value):
		part_scale = value
		#ugh im tired
		if part_collider_node != null:
			#implement the different shapes
			match part_shape:
			#cuboid
				0:
					var shape : BoxShape3D = part_collider_node.shape
					shape.size = part_scale
			#wedge
				1:
					pass
			#cylinder
				2:
					pass
			#sphere
				3:
					pass
				
		
		if part_mesh_node != null:
			#implement the different shapes
			match part_shape:
			#cuboid
				0:
					var mesh_res : BoxMesh = part_mesh_node.mesh
					mesh_res.size = part_scale
			#wedge
				1:
					pass
			#cylinder
				2:
					pass
			#sphere
				3:
					pass
				
		
		
		#if part_mesh_node != null:
			#implement the different shapes

#pivot vec3 local to the node
@export var part_pivot : Vector3 = Vector3.ZERO

#material setter
@export var part_material : StandardMaterial3D

#automatic assigning of collision shape
#make sure to set collision mask correctly so parts dont interact
var part_collider_node : CollisionShape3D
var part_mesh_node : MeshInstance3D

# Called when the node enters the scene tree for the first time.
func _ready():
	
#initialize
	#assign collider when added to scene tree
	part_collider_node = CollisionShape3D.new()
	part_collider_node.owner = get_tree().edited_scene_root
	self.add_child(part_collider_node)
	part_collider_node.shape = BoxShape3D.new()
	#set collision mask to not collide with other parts
	self.set_collision_mask_value(1, false)
	self.set_collision_mask_value(2, true)
	
	part_mesh_node = MeshInstance3D.new()
	part_mesh_node.owner = get_tree().edited_scene_root
	self.add_child(part_mesh_node)
	part_mesh_node.mesh = BoxMesh.new()

#only set this after its initialized lol
	"DEBUG"
	self.part_scale = self.part_scale
