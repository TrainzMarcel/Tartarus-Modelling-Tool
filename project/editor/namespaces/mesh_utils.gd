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
	var index_mesh : bool = false
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
		MeshUtils._add_metadata_to_mesh(combinations, mesh_result)
	
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
		if combinations[i].size() != 0:
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
	var metadata_material_names = mesh.get_meta("material_names")
	var metadata_colors = mesh.get_meta("colors")
	for surface in surfaces:
		var count = mesh.surface_get_arrays(surface)[0].size()
		var material_name : String
		var color_name : String
		
		if metadata_material_names != null and metadata_material_names.size() - 1 > surface:
			material_name = metadata_material_names[surface]
		else:
			material_name = "no metadata available"
		
		if metadata_colors != null and metadata_colors.size() - 1 > surface:
			color_name = metadata_colors[surface]
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
	surface_result.resize(Mesh.ARRAY_MAX)
	
	
	@warning_ignore("confusable_local_declaration")
	var _append_to_data_array : Callable = func(surface_result : Array, surface_addition : Array, mesh_transform : Transform3D):
		var k : int = 0
		var transform_rotation : Basis = mesh_transform.basis.orthonormalized().inverse()
		while k < surface_addition.size():
			if surface_result[k] == null and surface_addition[k] != null:
				if surface_addition[k] is PackedVector3Array:
					surface_result[k] = PackedVector3Array()
				elif surface_addition[k] is PackedVector2Array:
					surface_result[k] = PackedVector2Array()
				elif surface_addition[k] is PackedInt32Array:
					surface_result[k] = PackedInt32Array()
				elif surface_addition[k] is PackedFloat32Array:
					surface_result[k] = PackedFloat32Array()
				elif surface_addition[k] is PackedColorArray:
					surface_result[k] = PackedColorArray()
				elif surface_addition[k] is PackedByteArray:
					surface_result[k] = PackedByteArray()
			
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
			
			elif k == Mesh.ARRAY_INDEX:
				pass
				#if not surface_addition[k] is PackedInt32Array:
				#	surface_addition[k] = PackedInt32Array()
				#	surface_addition[k].resize(surface_addition[Mesh.ARRAY_VERTEX].size())
				#	for index in surface_addition[Mesh.ARRAY_INDEX].size():
				#		surface_addition[Mesh.ARRAY_INDEX][index] = index
				#if not surface_result[k] is PackedInt32Array:
				#	surface_result[k] = PackedInt32Array()
				
				#var l : int = 0
				#while l < surface_addition[Mesh.ARRAY_VERTEX].size():
				#	surface_addition[k][l] = surface_addition[k][l] + surface_result[Mesh.ARRAY_INDEX].size()
				#	l = l + 1
				
			
			
			if surface_addition[k] != null:
				surface_result[k].append_array(surface_addition[k])
			
			k = k + 1
	
	
	#add all parts into one mesh
	#for every part:
	var i : int = 0
	while i < part_array.size():
		var st : SurfaceTool = SurfaceTool.new()
		var mesh_node : MeshInstance3D = part_array[i].part_mesh_node
		#TODO var surface_count : int = mesh_node.mesh.get_surface_count()
		st.create_from(mesh_node.mesh, 0)
		st.deindex()
		var indexed_mesh : Mesh = st.commit()
		#for every data array of that surface:
		var surface_addition : Array = indexed_mesh.surface_get_arrays(0)
		#add surface_addition to surface_result
		_append_to_data_array.call(surface_result, surface_addition, mesh_node.global_transform)
		i = i + 1
	
	#finish surface
	resulting_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_result)
	return resulting_mesh


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
		material_name_array.append(AssetManager.get_name_of_asset(material, false) + "," + i[0].part_color.to_html(false))
	
	return material_name_array


static func _add_metadata_to_mesh(part_array : Array[Array], mesh : ArrayMesh):
	var material_names : Array[String] = _get_material_name_array_from_part_combinations(part_array)
	mesh.set_meta("material_names", material_names)
	mesh.set_meta("colors", _get_color_array_from_part_combinations(part_array))
	for i in mesh.get_surface_count():
		#material names and hex colors are included
		mesh.surface_set_name(i, str(i) + "_" + material_names[i])


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


static func _classify_surface_array_indices_by_normal(surface_array : Array, normal_vector : Vector3, dot_tolerance : float):
	var result : PackedInt32Array = []
	for i in surface_array[Mesh.ARRAY_NORMAL].size():
		if surface_array[Mesh.ARRAY_NORMAL][i]:
			return
	
	return result


static func _get_mesh_aabb(mesh : ArrayMesh):
	mesh.get_aabb()


static func _get_meshes_from_parts(part_array : Array):
	return part_array.map(func(input : Part):
		return input.part_mesh_node.mesh
		)
