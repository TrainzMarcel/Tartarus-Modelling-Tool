extends StaticBody3D
class_name Part

"TODO"#for scaling custom meshes correctly, add a function that gets the meshes aabb while it is un-rotated
#set the parts scale to the meshes aabb and save that scale
#use that mesh scale value to keep the mesh in the parts bounds
#for the time being custom part meshes will just have a box collider

#exclude from export
@export var exclude : bool = false
#make unselectable
@export var locked : bool = false

var collider_type : int = 0

#material setter
@export var part_material : Material:
	set(value):
		part_material = value
		reapply_part_material(value)

#color setter
@export var part_color : Color = Color.WHITE:
	set(value):
		part_color = value
		reapply_part_color(value)

@export var part_scale : Vector3 = Vector3(0.4, 0.2, 0.8):
#size with setter
	set(value):
		value.x = max(value.x, 0)
		value.y = max(value.y, 0)
		value.z = max(value.z, 0)
		part_scale = value
		
		reapply_part_scale(value)


#automatic assigning of collision shape
#make sure to set collision mask correctly so parts dont interact
var part_collider_node : CollisionShape3D
var part_mesh_node : MeshInstance3D


func reapply_part_scale(p_scale : Vector3):
		if part_collider_node == null or part_mesh_node == null:
			return
		
		if part_collider_node.shape == null:
			return
		
		#implement the different shapes
		match collider_type:
		#cuboid
			0:
				var shape : BoxShape3D = part_collider_node.shape
				shape.size = p_scale
		#wedge
			1:
				var shape : ConvexPolygonShape3D = ConvexPolygonShape3D.new()
				shape.points = scale_wedge_collider(p_scale, wedge_collider_points)
		
		part_mesh_node.scale = p_scale


func reapply_part_material(material : Material):
	if part_mesh_node != null and material != null:
		part_mesh_node.material_override = AssetManager.recolor_material(material, part_color, true)


func reapply_part_color(color : Color):
	if part_mesh_node != null:
		if part_mesh_node.material_override == null:
			part_mesh_node.material_override = StandardMaterial3D.new()#AssetManager.recolor_material(load(FilePathRegistry.data_default_material), part_color, true)
		else:
			part_mesh_node.material_override = AssetManager.recolor_material(part_mesh_node.material_override, part_color, true)


func _init():
	part_collider_node = CollisionShape3D.new()
	part_mesh_node = MeshInstance3D.new()
	
	#set collision mask to not collide with other parts
	set_collision_mask_value(1, false)
	set_collision_mask_value(2, true)



func initialize():
	if part_collider_node.shape == null:
		part_collider_node.shape = BoxShape3D.new()
	
	
	if part_mesh_node.mesh == null:
		part_mesh_node.mesh = preload(FilePathRegistry.data_fallback_part)
	
	if part_material == null:
		part_material = load(FilePathRegistry.data_fallback_material)
	
	
	if part_color != Color.WHITE:
		reapply_part_color(part_color)
	
	add_child(part_collider_node)
	part_collider_node.owner = get_tree().edited_scene_root
	
	add_child(part_mesh_node)
	part_mesh_node.owner = get_tree().edited_scene_root
	
#outdated comment, not sure if this still applies
#only set this after its initialized (does not run through setter if mesh or collider are null)
	reapply_part_scale(part_scale)

var wedge_collider_points : PackedVector3Array = [
	Vector3(-0.5, -0.5, -0.5),
	Vector3(-0.5, -0.5, 0.5),
	Vector3(-0.5, 0.5, -0.5),
	Vector3(-0.5, 0.5, 0.5),
	Vector3(0.5, -0.5, -0.5),
	Vector3(0.5, -0.5, 0.5)
]

func scale_wedge_collider(scale_to : Vector3, wedge_collider_points : PackedVector3Array):
	for i in wedge_collider_points:
		i = i * scale_to
	
	return wedge_collider_points


func copy():
	var new : Part = Part.new()
	new.part_mesh_node = part_mesh_node.duplicate()
	#optimization
	new.part_mesh_node.mesh = part_mesh_node.mesh
	new.part_collider_node = part_collider_node.duplicate()
	#do not share the collider
	if collider_type == 0:
		new.part_collider_node.shape = BoxShape3D.new()
		new.part_collider_node.shape.size = part_scale
	#warning: untested
	elif collider_type == 1:
		new.part_collider_node.shape = ConvexPolygonShape3D.new()
		new.scale_wedge_collider(part_scale, wedge_collider_points)
	
	new.transform = transform
	new.exclude = exclude
	new.locked = locked
	new.collider_type = collider_type
	new.part_scale = part_scale
	#shouldnt require duplicating
	#setter automatically calls reapply function
	new.part_material = part_material
	#i assume (hope) this is passed by value and not by reference
	#setter automatically calls reapply function
	new.part_color = part_color
	return new

