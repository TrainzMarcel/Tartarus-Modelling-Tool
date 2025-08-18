extends RefCounted
class_name MeshUtils


"TODO"#add resource name to these meshes
"TODO"#integrate file manager
"TODO"#clean up this code
"TODO"#add obj export
"TODO"#add gltf export
"TODO"#add obj import
"TODO"#add gltf import

#https://docs.godotengine.org/en/stable/classes/class_gltfdocument.html
#https://docs.godotengine.org/en/stable/classes/class_gltfstate.html#class-gltfstate


static func group_parts_by_material_and_color(part_array : Array):
	#parallel arrays
	#the same material will occupy one item for every color used with it
	var material_combination_array : Array[Material] = []
	var color_combination_array : Array[Color] = []
	
	#what part data is currently checked against
	var sort_material : Material
	var sort_color : Color
	
	#return
	var result_part_groupings : Array[Array] = []
	
	#first run: get all combinations
	var i : int = 0
	var j : int = 0
	while i < part_array.size():
		var match_found : bool = false
		var part : Part = part_array[i]
		
		#search if there are existing matching combos
		j = 0
		while j < material_combination_array.size():
			var check_1 : bool = part.part_color == color_combination_array[j]
			#i made sure to not duplicate material resources in the workspace, so this should work
			#but keep on a lookout in case it does count the same material and color as different combinations
			#just because the resource instance counts as a different object
			var check_2 : bool = part.part_material == material_combination_array[j]
			
			#break out if matching combination already exists
			if check_1 and check_2:
				match_found = true
				break
			
			j = j + 1
		
		if not match_found:
			color_combination_array.append(part.part_color)
			material_combination_array.append(part.part_material)
		
		i = i + 1
	
	
	#second run: filter parts into the found combinations
	i = 0
	while i < material_combination_array.size():
		sort_material = material_combination_array[i]
		sort_color = color_combination_array[i]
		#add a new 2nd dimension for each combination
		result_part_groupings.append([])
		
		j = 0
		while j < part_array.size():
			var part : Part = part_array[j]
			"TODO"#use mappings and abstract the grouping code out for metadata purposes
			if part.part_color == sort_color and part.part_material == sort_material:
				result_part_groupings[i].append(part)
			j = j + 1
		
		i = i + 1
	
	return result_part_groupings


static func create_mesh_from_part_groupings(part_array : Array[Array]):
	var st : SurfaceTool = SurfaceTool.new()
	var resulting_mesh : ArrayMesh = ArrayMesh.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	
	#every surface
	var i : int = 0
	var j : int = 0
	while i < part_array.size():
		j = 0
		#add all parts of group to mesh
		while j < part_array[i].size():
			st.append_from(part_array[i][j].part_mesh_node.mesh, 0, part_array[i][j].part_mesh_node.global_transform)
			j = j + 1
		
		#finish surface
		#too bad the materials dont work correctly when indices are added
		#(at least automatically, maybe theres a way to add them manually without breaking the mesh surfaces)
		st.deindex()
		st.commit(resulting_mesh)
		i = i + 1
	
	return resulting_mesh


static func get_color_array_from_part_groupings(part_array : Array[Array]):
	var color_array : Array[Color] = []
	for i in part_array:
		#part array is guaranteed to have at least 1 item
		color_array.append(i[0].part_color)
	
	return color_array


static func get_material_name_array_from_part_groupings(part_array : Array[Array]):
	var material_name_array : Array[String] = []
	for i in part_array:
		#part array is guaranteed to have at least 1 item
		var material : Material = i[0].part_material
		material_name_array.append(AssetManager.get_name_of_asset(material))
	
	return material_name_array


static func add_metadata_to_mesh(part_array : Array[Array], mesh : Resource):
	mesh.set_meta("material_names", get_material_name_array_from_part_groupings(part_array))
	mesh.set_meta("colors", get_color_array_from_part_groupings(part_array))


static func export_as_obj(mesh, filepath, filename):
	OBJExporter.save_mesh_to_files(mesh, filepath, filename)
	
	return

static func import_obj():
	return

"TODO"#possibly figure out a class name for a class which takes care of file operations like saving loading importing and exporting
#or simply throw the export function into workspace manager again x3

#i really want to add metadata for the previous color and material name of each surface for .res/.tres exports
#then when i pull the resources into godot, i can have a plugin automatically assign the intended colors and materials


#for obj and gltf export and also for anyone who doesnt wanna use triplanar materials
static func uv_box_projection():
	return


static func get_meshes_from_parts(part_array : Array):
	return part_array.map(func(input : Part):
		return input.part_mesh_node.mesh
		)









