extends RefCounted
class_name MeshUtils


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
			var result : Mesh = st.commit()
			var prev_color : Color = part_array[i - 1].part_color
			var prev_mat : ShaderMaterial = part_array[i - 1].part_material
			#set metadata of previous parts color and material
			#omit embedding the material to save space anfd instead just embed the name
			result.set_meta("material_name", WorkspaceManager.get_resource_name(mat.resource_path))
			result.set_meta("color", prev_color)
			ResourceSaver.save(result, "user://exported_models/export" + str(prev_index_2) + ".res", ResourceSaver.FLAG_BUNDLE_RESOURCES)
			
			
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			prev_index_2 = index_2
		
		#st.append_from(mesh_array[i], index_2, part_array[i].transform)
		print(index_2)
		st.append_from(mesh_array[i], 0, part_array[i].part_mesh_node.global_transform)
		i = i + 1
	
	st.optimize_indices_for_cache()
	var result : Mesh = st.commit()
	result.set_meta("material_name", WorkspaceManager.get_resource_name(part_array[part_array.size() - 1].part_material.resource_path))
	result.set_meta("color", part_array[part_array.size() - 1].part_color)
	
	ResourceSaver.save(result, "/home/marci/Desktop/save testing/MAOW" + str(used_materials.size() - 1) + ".res", ResourceSaver.FLAG_BUNDLE_RESOURCES)


static func uv_box_projection():
	return


static func get_meshes_from_parts(part_array : Array):
	return part_array.map(func(input : Part):
		return input.part_mesh_node.mesh
		)









