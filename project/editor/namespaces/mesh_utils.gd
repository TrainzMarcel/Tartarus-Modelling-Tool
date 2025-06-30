extends RefCounted
class_name MeshUtils


"TODO"#add resource name to these meshes
"TODO"#integrate file manager
"TODO"#clean up this code
"TODO"#add obj export
"TODO"#add gltf export
"TODO"#add obj import(
"TODO"#add gltf import

static func group_parts_by_material_and_color(part_array : Array[Part]):
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
		
		i = i + 1
	
	return result_part_groupings


static func create_mesh_from_part_groupings(part_array : Array[Array]):
	var st : SurfaceTool = SurfaceTool.new()
	
	
	
	
	
	
	
	return


"TODO"#possibly figure out a class name for a class which takes care of file operations like saving loading importing and exporting
#or simply throw the export function into workspace manager again x3

#i really want to add metadata for the previous color and material name of each surface for .res/.tres exports
#then when i pull the resources into godot, i can have a plugin automatically assign the intended colors and materials



static func combine_meshes(part_array : Array):
	var st : SurfaceTool = SurfaceTool.new()
	var mesh_array : Array = get_meshes_from_parts(part_array)
	var used_materials : Array[ShaderMaterial] = []
	var used_materials_to_int_mapping : Dictionary = {}
	var used_colors_per_material : Array[Array] = []
	var used_colors_per_material_to_int_mapping : Array[Dictionary] = []
	
	var i : int = 0
	var j : int = 0
	
	
	#get used materials
	used_materials.append(part_array[0].part_material)
	used_colors_per_material.append([])
	
	while i < part_array.size():
		j = 0
		var has_material : bool = false
		
		while j < used_materials.size():
			var base_1 = used_materials[j].resource_path.get_file()
			var base_2 = part_array[i].part_material.resource_path.get_file()
			if base_2 == base_1:
				has_material = true
				break
			j = j + 1
		
		if not has_material:
			used_materials.append(part_array[i].part_material)
			#add an empty array for the colors
			#for each material used
			used_colors_per_material.append([])
		i = i + 1
	
	used_materials_to_int_mapping = WorkspaceManager.create_mapping(used_materials)
	
	
	#get used colors
	i = 0
	while i < part_array.size():
		#get index of used material
		var index : int = used_materials_to_int_mapping[part_array[i].part_material]
		#check if this material-color combination has been added yet
		#if not, add it
		if not used_colors_per_material[index].has(part_array[i].part_color):
			used_colors_per_material[i].append(part_array[i].part_color)
		i = i + 1
	
	
	#create a direct mapping from the 2d array to a 1d surface index
	var accumulator : int = 0
	i = 0
	while i < used_colors_per_material.size():
		used_colors_per_material_to_int_mapping.append(WorkspaceManager.create_mapping_offset(used_colors_per_material[i], accumulator))
		
		accumulator = accumulator + used_colors_per_material[i].size()
		i = i + 1
	
	
	#finally begin putting the meshes together
	var resulting_mesh : ArrayMesh = ArrayMesh.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	i = 0
	var prev_index_2 : int = 0
	while i < mesh_array.size():
		var mat : ShaderMaterial = part_array[i].part_material
		var color : Color = part_array[i].part_color
		var index_1 : int = used_materials_to_int_mapping[mat]
		var index_2 : int = used_colors_per_material_to_int_mapping[index_1][color]
		
		if index_2 != prev_index_2:
			st.optimize_indices_for_cache()
			st.commit(resulting_mesh)
			#var prev_color : Color = part_array[i - 1].part_color
			#var prev_mat : ShaderMaterial = part_array[i - 1].part_material
			#set metadata of previous parts color and material
			#omit embedding the material to save space anfd instead just embed the name
			prev_index_2 = index_2
		
		#st.append_from(mesh_array[i], index_2, part_array[i].transform)
		print(index_2)
		st.append_from(mesh_array[i], 0, part_array[i].part_mesh_node.global_transform)
		i = i + 1
	
	st.optimize_indices_for_cache()
	#var result : Mesh =  
	st.commit(resulting_mesh)
	#result.set_meta("material_names", used_materials.map(func(input): WorkspaceManager.get_resource_name(input.resource_path)))
	#result.set_meta("colors", used[part_array.size() - 1].part_color)
	
	ResourceSaver.save(resulting_mesh, "/home/marci/Desktop/save testing/MAOW.res", ResourceSaver.FLAG_BUNDLE_RESOURCES)


#for obj and gltf export and also for anyone who doesnt wanna use triplanar materials
static func uv_box_projection():
	return


static func get_meshes_from_parts(part_array : Array):
	return part_array.map(func(input : Part):
		return input.part_mesh_node.mesh
		)









