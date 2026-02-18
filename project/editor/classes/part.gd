extends StaticBody3D
class_name Part

"TODO"#for scaling custom meshes correctly, add a function that gets the meshes aabb while it is un-rotated
#set the parts scale to the meshes aabb and save that scale
#use that mesh scale value to keep the mesh in the parts bounds
#for the time being custom part meshes will just have a box collider

#exclude from export
#not sure if i will keep this, u can already exclude by exporting/saving the selected things only
#perhaps integrate it in a future qol update
#@export var exclude : bool = false

#make unselectable
@export var locked : bool = false

#material setter
@export var part_material : Material:
	set(value):
		if not mesh_node_safety_check("part material"):
			return
		
		#if material is invalid, set part_material to null and display error material
		if not Main.safety_check(value):
			part_material = null
			push_warning("attempted to set part_material to invalid value: ", value, ", setting material to fallback ", FilePathRegistry.data_fallback_material.get_file())
			part_mesh_node.material_override = preload(FilePathRegistry.data_fallback_material)
			return
		
		#otherwise, proceed as normal
		part_material = value
		part_mesh_node.material_override = AssetManager.recolor_material(value, part_color, true)


#color setter
@export var part_color : Color = Color.WHITE:
	set(value):
		if value == part_color:
			return
		
		part_color = value
		if not mesh_node_safety_check("part color"):
			return
		
		if part_mesh_node.material_override == null:
			part_mesh_node.material_override = StandardMaterial3D.new()#AssetManager.recolor_material(load(FilePathRegistry.data_default_material), part_color, true)
		else:
			part_mesh_node.material_override = AssetManager.recolor_material(part_mesh_node.material_override, part_color, true)


#size with setter
#@export var part_scale : Vector3 = Vector3(0.4, 0.2, 0.8):
@export var part_scale : Vector3 = Vector3(1.0, 1.0, 1.0):
	set(value):
		if value == part_scale:
			return
		
		value.x = max(value.x, 0)
		value.y = max(value.y, 0)
		value.z = max(value.z, 0)
		part_scale = value
		
		
		#do both checks regardless of whether one fails
		#that way both errors will be printed
		var success : bool = collision_node_safety_check("part scale")
		success = success and mesh_node_safety_check("part scale")
		
		if not success:
			return
		
		var shape : BoxShape3D = part_collider_node.shape
		shape.size = part_scale
		
		"TODO"#implement the different shapes
		#with this match statement and also with a polygon resizer
		#match collider_type:
		#cuboid
		#	0:
		#wedge
		#	1:
		#		var shape : ConvexPolygonShape3D = ConvexPolygonShape3D.new()
		#		shape.points = scale_wedge_collider(p_scale, wedge_collider_points)
		
		part_mesh_node.scale = part_scale


@export var part_mesh : Mesh:
	set(value):
		if value == part_mesh:
			return
		
		if not mesh_node_safety_check("part type"):
			return
		
		if not Main.safety_check(value):
			part_mesh_node.mesh = preload(FilePathRegistry.data_fallback_part)
			part_mesh = null
			return
		
		part_mesh_node.mesh = value
		part_mesh = value


func mesh_node_safety_check(property_name : String):
	if not Main.safety_check(part_mesh_node):
		push_error("reference to part mesh node lost on part ", self.name, ", unable to set ", property_name)
		return false
	return true


func collision_node_safety_check(property_name : String):
	if not Main.safety_check(part_collider_node):
		push_error("reference to part collider node lost on part ", self.name, ", unable to set ", property_name)
		return false
	
	if not Main.safety_check(part_collider_node.shape):
		push_error("reference to part collision node shape property lost on part ", self.name, ", unable to set ", property_name)
		return false
	
	return true


#automatic assigning of collision shape
#make sure to set collision mask correctly so parts dont interact
var part_collider_node : CollisionShape3D
var part_mesh_node : MeshInstance3D


#on new instance created
func _init():
	part_collider_node = CollisionShape3D.new()
	part_mesh_node = MeshInstance3D.new()
	
	#for now, all parts have box/cuboid colliders
	if part_collider_node.shape == null:
		part_collider_node.shape = BoxShape3D.new()
	
	#set collision mask to not collide with other parts
	set_collision_mask_value(1, false)
	set_collision_mask_value(2, true)


#call manually
func initialize():
	#must be added to node tree first to ensure everything works
	assert(get_parent() != null)
	
	#trigger setters
	part_mesh = part_mesh
	part_material = part_material
	part_color = part_color
	
	
	add_child(part_collider_node)
	part_collider_node.owner = get_tree().edited_scene_root
	
	add_child(part_mesh_node)
	part_mesh_node.owner = get_tree().edited_scene_root


#"TODO"
#var wedge_collider_points : PackedVector3Array = [
#	Vector3(-0.5, -0.5, -0.5),
#	Vector3(-0.5, -0.5, 0.5),
#	Vector3(-0.5, 0.5, -0.5),
#	Vector3(-0.5, 0.5, 0.5),
#	Vector3(0.5, -0.5, -0.5),
#	Vector3(0.5, -0.5, 0.5)
#]


#"TODO"
#func scale_wedge_collider(scale_to : Vector3, wedge_collider_points : PackedVector3Array):
#	for i in wedge_collider_points:
#		i = i * scale_to
#	
#	return wedge_collider_points


func copy():
	var new : Part = Part.new()
	new.part_mesh_node = part_mesh_node.duplicate()
	new.part_collider_node = part_collider_node.duplicate()
	
	#do not share the collider
	#TODO implement different colliders
	new.part_collider_node.shape = BoxShape3D.new()
	new.part_collider_node.shape.size = part_scale
	new.transform = transform
	
	#not implemented yet
	#new.locked = locked
	
	#setters automatically reapply
	#optimization (shared meshes and material) scale still differs because they are set on the meshinstance node that contains them
	new.part_mesh = part_mesh
	new.part_scale = part_scale
	new.part_material = part_material
	#this is passed by value and not by reference
	#setters automatically reapply
	new.part_color = part_color
	return new
