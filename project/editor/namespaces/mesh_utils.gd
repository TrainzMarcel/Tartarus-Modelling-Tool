extends RefCounted
class_name MeshUtils


"TODO"#add resource name to these meshes
"TODO"#clean up this code
"TODO"#add obj export (mesh only)
"TODO"#add gltf export (mesh only)
"TODO"#add obj import
"TODO"#add gltf import
"TODO"#add tres import
"TODO"#add res import

#i really want to add metadata for the previous color and material name of each surface for .res/.tres exports
#then when i pull the resources into godot, i can have a plugin automatically assign the intended colors and materials

#mini task list
#mesh uv box projection
#mesh indexing by matching vertex pos vector, normal vector, uv "vector" for each mesh surface (either color-mat combination or whole mesh)
#mesh centering

#https://docs.godotengine.org/en/stable/classes/class_gltfdocument.html
#https://docs.godotengine.org/en/stable/classes/class_gltfstate.html#class-gltfstate

class EntityToMeshOptions:
	enum UVOptionEnum
	{
		Unchanged,
		BoxProjectMesh,
		BoxProjectVariable
	}
	var uv_option : UVOptionEnum = UVOptionEnum.Unchanged
	var uv_box_project_scale : float = 0.0
	#add indexing enabled by default
	var index_mesh : bool = true
	var center_mesh : bool = false
	#mesh metadata (of combinations) can only be added if split into combinations first
	var include_metadata : bool = false
	var split_mesh_by_combinations : bool = false
	var embed_assets : bool = false


static func convert_entities_to_mesh(options : EntityToMeshOptions, entities : Array, filename : String):
	var mesh_result : Mesh = null
	var combinations : Array[Array]
	
	if options.include_metadata or options.split_mesh_by_combinations:
		combinations = _classify_parts_by_material_and_color_combination(WorkspaceManager.workspace.get_children().filter(func(input): return input is Part))
	
	
	if options.split_mesh_by_combinations:
		mesh_result = _create_mesh_from_part_combinations(combinations)
	else:
		mesh_result = _create_mesh_from_parts(entities)
	
	
	if options.include_metadata:
		_add_metadata_to_mesh(combinations, mesh_result)
	
	#last step
	if not options.index_mesh:
		mesh_result = _deindex_mesh(mesh_result)
	
	debug_print_part_combinations(combinations)
	debug_print_mesh_surfaces(mesh_result)
	
	
	mesh_result.resource_name = filename
	return mesh_result


static func debug_print_part_combinations(combinations : Array[Array]):
	var i : int = 0
	var sum : int = 0
	while i < combinations.size():
		var count : int = 0
		var color : Color
		var color_name : String
		var material : Material
		var material_name : String
		if combinations[i].size() > 0 and combinations[i][0].part_material != null and combinations[i][0].part_color != null:
			color = combinations[i][0].part_color
			color_name = str(color)
			material = combinations[i][0].part_material
			material_name = AssetManager.get_name_of_asset(material, false)
		else:
			material_name = "no metadata available"
			color_name = "no metadata available"
		
		
		for part in combinations[i]:
			var mesh : Mesh = part.part_mesh_node.mesh
			count = count + mesh.surface_get_arrays(0)[0].size()
		sum = sum + count
		
		print("surface " + str(i) + " vert count: ", count, "   mats: ", material_name, " color: ", color_name)
		i = i + 1
	print("total: ", str(sum))


static func debug_print_mesh_surfaces(mesh : Mesh):
	var surfaces : int = mesh.get_surface_count()
	var sum : int = 0
	var metadata_material_names = null
	var metadata_colors = null
	if mesh.has_meta("material_names"): metadata_material_names = mesh.get_meta("material_names")
	if mesh.has_meta("colors"): metadata_colors = mesh.get_meta("colors")
	
	for surface in surfaces:
		var count = mesh.surface_get_arrays(surface)[0].size()
		var material_name : String
		var color_name : String
		
		if metadata_material_names != null and metadata_material_names.size() - 1 > surface:
			material_name = metadata_material_names[surface]
		else:
			material_name = "no metadata available"
		
		if metadata_colors != null and metadata_colors.size() - 1 > surface:
			color_name = str(metadata_colors[surface])
		else:
			color_name = "no metadata available"
		
		print("surface " + str(surface) + " vert count: ", count, "   mats: ", material_name, " color: ", color_name)
		sum = sum + count
	
	print("total: ", str(sum))


static func import_obj():
	return


static func export_obj(mesh : Mesh, filepath : String, filename : String):
	OBJExporter.save_mesh_to_files(mesh, filepath, filename)


static func import_resource():
	return# ResourceLoader.load()


static func export_resource(mesh : Mesh, binary_encoding : bool, embed_assets : bool, filepath : String, filename : String):
	var file_type : String
	if binary_encoding:
		file_type = ".res"
	else:
		file_type = ".tres"
	
	var flags : int = 0
	if embed_assets:
		flags = flags | ResourceSaver.FLAG_BUNDLE_RESOURCES
	
	return ResourceSaver.save(mesh, filepath.path_join(filename) + file_type, flags)


static func import_gltf():
	return

static func export_gltf(mesh : Mesh, filepath : String, filename : String):
	return

"TODO"#replace complex logic with calls to assetmanager
static func _classify_parts_by_material_and_color_combination(part_array : Array):
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


static func _create_mesh_from_part_combinations(part_array : Array[Array]):
	var resulting_mesh : ArrayMesh = ArrayMesh.new()
	
	#every surface
	var i : int = 0
	while i < part_array.size():
		resulting_mesh = _append_surface_to_mesh_from_parts(part_array[i], resulting_mesh)
		i = i + 1
	
	return resulting_mesh


static func _create_mesh_from_parts(part_array : Array):
	return _append_surface_to_mesh_from_parts(part_array, ArrayMesh.new())


"TODO"
static func _append_surface_to_mesh_from_parts(part_array : Array, resulting_mesh : ArrayMesh):
	var surface_result : Array
	@warning_ignore("confusable_local_declaration")
	var _append_to_data_array : Callable = func(surface_result : Array, surface_addition : Array, mesh_transform : Transform3D):
		surface_result = _initialize_mesh_array_from_mesh_array(surface_addition, surface_result)
		
		#iterate over all data
		var k : int = 0
		var transform_rotation : Basis = mesh_transform.basis.orthonormalized().inverse()
		while k < surface_addition.size():
			
			if k == Mesh.ARRAY_VERTEX:
				var l : int = 0
				while l < surface_addition[k].size():
					surface_addition[k][l] = mesh_transform * surface_addition[k][l]
					l = l + 1
			
			elif k == Mesh.ARRAY_NORMAL:
				var l : int = 0
				while l < surface_addition[k].size():
					surface_addition[k][l] = surface_addition[k][l] * transform_rotation
					l = l + 1
			
			if surface_addition[k] != null:
				surface_result[k].append_array(surface_addition[k])
			
			k = k + 1
	
	
	#to recap: shared vertices are connected into tris by sets of three vertex indices in the index array
	var _add_indexing_to_mesh_array : Callable = func(surface_input : Array):
		var surface_result_indexed : Array = _initialize_mesh_array_from_mesh_array(surface_input)
		
		#hold the index of every first index that is being mapped to
		#if there is no match, then just append the original vertex's index (j)
		var indices_mapping : PackedInt32Array = []
		#indices of vertices that will be added to the new data array
		var indices_unique : PackedInt32Array = []
		
		#sanity check
		assert(surface_input[Mesh.ARRAY_TEX_UV] != null and surface_input[Mesh.ARRAY_TEX_UV].size() != 0)
		assert(surface_input[Mesh.ARRAY_NORMAL] != null and surface_input[Mesh.ARRAY_NORMAL].size() != 0)
		
		"TODO"#use a dictionary to speed up the process
		#"target" vertex: original vertex for which a matching vertex is being searched for
		var index_target : int = 0
		while index_target < surface_input[Mesh.ARRAY_VERTEX].size():
			#"query" vertex: vertex which is being compared to the target vertex to see if its a match
			var index_query : int = 0
			while index_query < index_target:
				var vertex_match : bool = surface_input[Mesh.ARRAY_VERTEX][index_query] == surface_input[Mesh.ARRAY_VERTEX][index_target]
				var normal_match : bool = surface_input[Mesh.ARRAY_NORMAL][index_query] == surface_input[Mesh.ARRAY_NORMAL][index_target]
				var uv_match : bool = surface_input[Mesh.ARRAY_TEX_UV][index_query] == surface_input[Mesh.ARRAY_TEX_UV][index_target]
				if vertex_match and normal_match and uv_match:
					#append the first matching index
					indices_mapping.append(indices_unique.find(index_query))
					break
				index_query = index_query + 1
			
			#if all vertices before the target vertex have been searched through and no match
			#has been found for the target, then add it as a new unique vertex
			if index_query == index_target:
				indices_mapping.append(indices_unique.size())
				indices_unique.append(index_target)
			
			index_target = index_target + 1
		
		
		#reduce the array to the unique indices
		var j : int = 0
		while j < indices_unique.size():
			var copy_index : int = indices_unique[j]
			var array : int = 0
			while array < Mesh.ARRAY_MAX:
				
				if surface_input[array] != null:
					if array != Mesh.ARRAY_TANGENT:
						surface_result_indexed[array].append(surface_input[array][copy_index])
					else:
						var quadruple : int = copy_index * 4
						surface_result_indexed[array].append(surface_input[array][quadruple])
						surface_result_indexed[array].append(surface_input[array][quadruple + 1])
						surface_result_indexed[array].append(surface_input[array][quadruple + 2])
						surface_result_indexed[array].append(surface_input[array][quadruple + 3])
				
				
				array = array + 1
			j = j + 1
		
		#finally, set the mesh to index mode
		surface_result_indexed[Mesh.ARRAY_INDEX] = indices_mapping
		return surface_result_indexed
	
	
	#cache deindexed meshes such as cuboids
	var deindexed_meshes : Dictionary = {}
	
	#add all parts into one mesh
	#for every part:
	var i : int = 0
	while i < part_array.size():
		var st : SurfaceTool = SurfaceTool.new()
		var mesh_node : MeshInstance3D = part_array[i].part_mesh_node
		var deindexed_mesh : Mesh = deindexed_meshes.get(AssetManager.get_name_of_asset(mesh_node.mesh, false, true))
		#deindex the part first because combining indexed meshes does not bring enough benefit vs the complexity
		#combining indexed meshes would mean vertices are only shared within the same parts and not between separate parts
		if deindexed_mesh == null:
			deindexed_mesh = _deindex_mesh(mesh_node.mesh)
			#cache deindexed meshes
			deindexed_meshes[AssetManager.get_name_of_asset(mesh_node.mesh, false, true)] = deindexed_mesh
		
		assert(deindexed_mesh != null)
		var surface_count : int = deindexed_mesh.get_surface_count()
		var l : int = 0
		while l < surface_count:
			var surface_addition : Array = deindexed_mesh.surface_get_arrays(l)
			#add surface_addition to surface_result
			#for every data array of that surface, append it to the surface_result
			_append_to_data_array.call(surface_result, surface_addition, mesh_node.global_transform)
			l = l + 1
		
		i = i + 1
	
	#add indexing
	surface_result = _add_indexing_to_mesh_array.call(surface_result)
	
	
	#finish surface
	resulting_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_result, [], {}, Mesh.ARRAY_FORMAT_INDEX)
	return resulting_mesh


static func _deindex_mesh(mesh_input : Mesh):
	var st : SurfaceTool = SurfaceTool.new()
	var mesh_result : ArrayMesh = ArrayMesh.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var i : int = 0
	while i < mesh_input.get_surface_count():
		st.append_from(mesh_input, i, Transform3D.IDENTITY)
		st.deindex()
		mesh_result = st.commit(mesh_result)
		i = i + 1
	
	return mesh_result


static func _get_color_array_from_part_combinations(part_array : Array[Array]):
	var color_array : Array[Color] = []
	#loop through every first item in inner array
	for i in part_array:
		#part array is guaranteed to have at least 1 item
		color_array.append(i[0].part_color)
	
	return color_array


static func _get_material_name_array_from_part_combinations(part_array : Array[Array]):
	var material_name_array : Array[String] = []
	for i in part_array:
		#part array is guaranteed to have at least 1 item
		var material : Material = i[0].part_material
		#get_name_of
		if material != null:
			material_name_array.append(AssetManager.get_name_of_asset(material, false) + "," + i[0].part_color.to_html(false))
		else:
			material_name_array.append("NULL")
	
	return material_name_array


static func _add_metadata_to_mesh(part_array : Array[Array], mesh : ArrayMesh):
	var material_names : Array[String] = _get_material_name_array_from_part_combinations(part_array)
	mesh.set_meta("material_names", material_names)
	mesh.set_meta("colors", _get_color_array_from_part_combinations(part_array))
	for i in mesh.get_surface_count():
		#material names and hex colors are included
		mesh.surface_set_name(i, str(i) + "_" + material_names[i])


"TODO TEST"
#for obj and gltf export and also for anyone who doesnt wanna use triplanar materials
static func _uv_box_projection(surface_array : Array, scale : float):
	assert(scale > 0.0)
	var sides : PackedVector3Array = [
		Vector3.RIGHT,
		Vector3.LEFT,
		Vector3.UP,
		Vector3.DOWN,
		Vector3.BACK,
		Vector3.FORWARD
		]
	
	#45 degrees tolerance from normal vector for every side
	var dot_tolerance : float = cos(deg_to_rad(45))
	for side in sides:
		_uv_plane_projection(surface_array, scale, side, dot_tolerance)


"TODO TEST"
static func _uv_plane_projection(surface_array : Array, scale : float, normal_vector : Vector3, dot_tolerance : float):
	assert(scale > 0.0)
	assert(dot_tolerance != 0.0)
	assert(normal_vector.length() == 1.0)
	
	#getting the planar vectors from normal vector
	#1. find the vector closest to UP from normal vector
	#create the cross product between normal vector and an up vector with defaults for up and down
	var cross_product : Vector3 = Vector3()
	if normal_vector == Vector3.UP:
		cross_product = Vector3.RIGHT
	elif normal_vector == Vector3.DOWN:
		cross_product = Vector3.LEFT
	else:
		cross_product = normal_vector.cross(Vector3.UP)
	
	#create the planar up vector by rotating 90 degrees
	var normal_vector_up : Vector3 = cross_product.normalized().rotated(normal_vector, -deg_to_rad(90))
	#sanity check by creating the planar right vector using a second cross product
	var normal_vector_right : Vector3 = normal_vector.cross(normal_vector_up)
	assert(normal_vector_right.is_normalized())
	
	var matching_surface_indices : PackedInt32Array = _classify_surface_array_indices_by_normal(surface_array, normal_vector, dot_tolerance)
	var i : int = 0
	while i < matching_surface_indices.size():
		var vertex_position : Vector3 = surface_array[Mesh.ARRAY_VERTEX][i]
		var uv_coordinate_u : float = vertex_position.dot(normal_vector_right)
		var uv_coordinate_v : float = vertex_position.dot(normal_vector_up)
		surface_array[Mesh.ARRAY_TEX_UV][i] = Vector2(uv_coordinate_u, uv_coordinate_v)
		
		i = i + 1
	
	return


"TODO TEST"
static func _classify_surface_array_indices_by_normal(surface_array : Array, normal_vector : Vector3, dot_tolerance : float):
	var result : PackedInt32Array = []
	for i in surface_array[Mesh.ARRAY_NORMAL].size():
		if surface_array[Mesh.ARRAY_NORMAL][i].dot(normal_vector) <= dot_tolerance:
			result.append(i)
	
	return result


static func _get_mesh_aabb(mesh : ArrayMesh):
	mesh.get_aabb()


static func _get_meshes_from_parts(part_array : Array):
	return part_array.map(func(input : Part):
		return input.part_mesh_node.mesh
		)


#ensure a new or existing_array has all the data arrays that the given mesh_array has
static func _initialize_mesh_array_from_mesh_array(mesh_array : Array, existing_array : Array = []):
	var result : Array = existing_array
	result.resize(Mesh.ARRAY_MAX)
	
	var i : int = 0
	while i < Mesh.ARRAY_MAX:
		if result[i] == null and mesh_array[i] != null:
			if mesh_array[i] is PackedVector3Array:
				result[i] = PackedVector3Array()
			elif mesh_array[i] is PackedVector2Array:
				result[i] = PackedVector2Array()
			elif mesh_array[i] is PackedInt32Array:
				result[i] = PackedInt32Array()
			elif mesh_array[i] is PackedFloat32Array:
				result[i] = PackedFloat32Array()
			elif mesh_array[i] is PackedColorArray:
				result[i] = PackedColorArray()
			elif mesh_array[i] is PackedByteArray:
				result[i] = PackedByteArray()
			
			#make sure the array got initialized correctly if mesh_array 
			assert(result[i] != null or mesh_array[i] == null)
			if result[i] != null and mesh_array[i] == null:
				push_error("the given mesh array is missing a data array")
			
		i = i + 1
	
	return result


#
static func _copy_mesh_array_data(mesh_array : Array, ):
	
	return
