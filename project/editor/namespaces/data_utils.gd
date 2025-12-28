extends RefCounted
class_name DataUtils

"TODO"#move saving to sqlite
#https://github.com/2shady4u/godot-sqlite
static func color_serialize(input : Color):
	return PackedStringArray([str(input.r8), str(input.g8), str(input.b8)])


static func color_deserialize(input : PackedStringArray):
	return Color8(int(input[0]), int(input[1]), int(input[2]))


static func material_serialize(input):
	#saving shadermaterial to file
	if input is ShaderMaterial:
		var result_line : PackedStringArray = []
		result_line.append("ShaderMaterial")
		result_line.append(AssetManager.get_name_of_asset(input.shader))
		#DONT include colors during serialization, causes huge problems
		#and there is already a color header anyway
		result_line.append(AssetManager.get_name_of_asset(input, false))
		
		var properties : Array = input.shader.get_shader_uniform_list()
		
		var i : int = 0
		while i < properties.size():
			var parameter = input.get_shader_parameter(properties[i].name)
			#print("parameter", parameter)
			if parameter is Texture2D:
				result_line.append(AssetManager.get_name_of_asset(parameter, false, true))
			elif parameter is String:
				result_line.append(parameter)
			elif parameter is float or parameter is int:
				result_line.append(str(parameter))
			elif parameter is bool:
				if parameter:
					result_line.append("t")
				else:
					result_line.append("f")
			elif parameter is Vector3:
				result_line.append_array([str(parameter.x), str(parameter.y), str(parameter.z)])
			elif parameter is Vector4:
				result_line.append_array([str(parameter.w), str(parameter.x), str(parameter.y), str(parameter.z)])
			elif parameter is Color:
				result_line.append_array([str(parameter.r8), str(parameter.g8), str(parameter.b8), str(parameter.a8)])
			elif parameter == null and properties[i].type == TYPE_VECTOR3:
				result_line.append_array(["","",""])
			elif parameter == null and properties[i].type == TYPE_VECTOR4 or properties[i].type == TYPE_COLOR:
				result_line.append_array(["","","",""])
			elif parameter == null and properties[i].type == TYPE_FLOAT or properties[i].type == TYPE_INT or properties[i].type == TYPE_STRING or properties[i].hint_string == "Texture2D":
				result_line.append("")
			else:
				push_error("unimplemented shadermaterial type: ", properties[i].hint_string, " ", properties[i])
				return
			i = i + 1
		return result_line
		
	#saving standardmaterial to file
	elif input is StandardMaterial3D or input is ORMMaterial3D:
		var result_line : PackedStringArray = []
		if input is StandardMaterial3D:
			result_line.append("StandardMaterial3D")
		else:
			result_line.append("ORMMaterial3D")
		
		#DONT include colors during serialization, causes huge problems
		#and there is already a color header anyway
		#so just call AssetManager.recolor_material() instead when loading
		result_line.append(AssetManager.normalize_asset_name(AssetManager.get_name_of_asset(input, false), false))
		
		
		var properties = input.get_property_list()
		var i : int = 0
		#print("START SERIALIZE-----------------------------------------------------------")
		while i < properties.size():
			var property = properties[i]
			#skip non-persistent/internal properties
			if property.usage & PROPERTY_USAGE_STORAGE == 0:
				i = i + 1
				continue
			"DEBUG"
			#print(property.name)
			
			var parameter = input.get(properties[i].name)
			if parameter is Texture2D:
				result_line.append(AssetManager.normalize_asset_name(AssetManager.get_name_of_asset(parameter, false, true), true))
			elif parameter is Material:
				result_line.append("")#recursive use of materials not supported
			elif parameter is String:
				result_line.append(parameter)
			elif parameter is float or parameter is int:
				result_line.append(str(parameter))
			elif parameter is bool:
				if parameter:
					result_line.append("t")
				else:
					result_line.append("f")
			elif parameter is Vector3:
				result_line.append_array([str(parameter.x), str(parameter.y), str(parameter.z)])
			elif parameter is Vector4:
				result_line.append_array([str(parameter.w), str(parameter.x), str(parameter.y), str(parameter.z)])
			elif parameter is Color:
				result_line.append_array([str(parameter.r8), str(parameter.g8), str(parameter.b8), str(parameter.a8)])
			elif parameter == null and property.type == TYPE_VECTOR3:
				result_line.append_array(["","",""])
			elif parameter == null and property.type == TYPE_VECTOR4 or property.type == TYPE_COLOR:
				result_line.append_array(["","","",""])
			elif parameter == null:
				result_line.append("")
			else:
				push_error("unimplemented basematerial3d type: ", property.hint_string, " ", parameter)
				return
			i = i + 1
		return result_line


static func material_deserialize(input : PackedStringArray):
#loading shadermaterial from file
	if input[0] == "ShaderMaterial":
		#load material
		var result_asset : ShaderMaterial
		var asset_name : String = AssetManager.normalize_asset_name(input[2], false)
		#recolor during part deserialization instead
		result_asset = AssetManager.get_material_by_name_any_color(asset_name)
		if result_asset != null:
			return result_asset
		else:
			result_asset = ShaderMaterial.new()
			result_asset.resource_path = asset_name
			AssetManager.register_asset(result_asset)
		
		#load shader code
		var shader : Shader
		asset_name = AssetManager.normalize_asset_name(input[1], false)
		shader = AssetManager.get_asset_by_name(asset_name)
		if shader == null:
			push_error("shader loading failure, name in save file: " + input[1])
			return
		
		result_asset.shader = shader
		
		var properties : Array = shader.get_shader_uniform_list()
		var i : int = 0
		#start at 3 because line item 0, 1 and 2 are the material type, shader name and material name respectively
		var i_line : int = 3
		
		while i < properties.size():
			var parameter = properties[i]
			var parameter_output
		#load image texture
			if parameter.type == TYPE_OBJECT and parameter.hint_string == "Texture2D":
				var image_texture : ImageTexture = AssetManager.get_asset_by_name(AssetManager.normalize_asset_name(input[i_line], false))
				
				#if image texture still hasnt loaded, abort
				if image_texture == null:
					push_error("image texture loading failure: ", input[i_line], " at line index: ", i_line, " at property index: ", i)
					return
				
				parameter_output = image_texture
		#load bool
			elif parameter.type == TYPE_BOOL:
				if input[i_line] == "t":
					parameter_output = true
				if input[i_line] == "f":
					parameter_output = false
				else:
					push_error("unexpected value: ", input[i_line], " | only true or false allowed")
		#load int
			elif parameter.type == TYPE_INT:
				parameter_output = int(input[i_line])
		#load float
			elif parameter.type == TYPE_FLOAT:
				parameter_output = float(input[i_line])
		#load string
			elif parameter.type == TYPE_STRING:
				parameter_output = input[i_line]
		#load vector3
			elif parameter.type == TYPE_VECTOR3:
				parameter_output = Vector3(float(input[i_line]), float(input[i_line + 1]), float(input[i_line + 2]))
				#needs to be incremented by 2, the x y z are stored as separate floats
				i_line = i_line + 2
		#load vector4
			elif parameter.type == TYPE_VECTOR4:
				parameter_output = Vector4(float(input[i_line]), float(input[i_line + 1]), float(input[i_line + 2]), float(input[i_line + 3]))
				#needs to be incremented by 3, the x y z w are stored as separate floats
				i_line = i_line + 3
		#load color
			elif parameter.type == TYPE_COLOR:
				parameter_output = Color8(int(input[i_line]), int(input[i_line + 1]), int(input[i_line + 2]), int(input[i_line + 3]))
				#needs to be incremented by 3, the r g b a are stored as separate ints
				i_line = i_line + 3
			else:
				push_error("unimplemented type ", parameter.hint_string, " ", parameter)
				return
			
			result_asset.set_shader_parameter(properties[i].name, parameter_output)
			i_line = i_line + 1
			i = i + 1
		
		return result_asset
	
#loading basematerial3d from file
	elif input[0] == "StandardMaterial3D" or input[0] == "ORMMaterial3D":
		#load material
		var result_asset : BaseMaterial3D
		var asset_name : String = AssetManager.normalize_asset_name(input[1], false)
		#recolor during part deserialization instead
		result_asset = AssetManager.get_material_by_name_any_color(asset_name)
		if result_asset != null:
			return result_asset
		else:
			result_asset = StandardMaterial3D.new()
			result_asset.resource_path = asset_name
			AssetManager.register_asset(result_asset)
		
		var properties : Array = result_asset.get_property_list()
		var i : int = 0
		#start at 2 because line item 0 and 1 are the material type and material name respectively
		var i_line : int = 2
		
		while i < properties.size():
			var parameter = properties[i]
			
			if i_line > input.size() - 1:
				return result_asset
			
			#skip non-persistent/internal properties
			if parameter.usage & PROPERTY_USAGE_STORAGE == 0 or input[i_line] == "":
				#omitting this line caused a nasty desynchronization bug between the two counters
				if input[i_line] == "":
					i_line = i_line + 1
				i = i + 1
				continue
			
			"DEBUG DESERIALIZE"
			#print(parameter.name)
			
			var parameter_output
		#load image texture
			if parameter.type == TYPE_OBJECT and parameter.hint_string == "Texture2D":
				#check if this subresource is reused by any other material
				#AssetManager.get_asset_by_name(input[i_line])
				var image_texture : ImageTexture = AssetManager.get_asset_by_name(AssetManager.normalize_asset_name(input[i_line], false))
				
				#if image texture still hasnt loaded, abort
				if image_texture == null:
					push_error("image texture loading failure: ", input[i_line], " at line index: ", i_line, " at property index: ", i)
					return
				
				parameter_output = image_texture
			elif parameter.type == TYPE_OBJECT and parameter.hint_string == "Material":
				#recursive usage of materials not supported
				
				parameter_output = null
		#load bool
			elif parameter.type == TYPE_BOOL:
				if input[i_line] == "t":
					parameter_output = true
				elif input[i_line] == "f":
					parameter_output = false
				else:
					push_error("unexpected value: ", input[i_line], " at line index: ", i_line, " at property index: ", i, " | only t (true) or f (false) allowed")
		#load int
			elif parameter.type == TYPE_INT:
				parameter_output = int(input[i_line])
		#load float
			elif parameter.type == TYPE_FLOAT:
				parameter_output = float(input[i_line])
		#load string
			elif parameter.type == TYPE_STRING:
				#strip " on both sides
				parameter_output = input[i_line]
		#load vector3
			elif parameter.type == TYPE_VECTOR3:
				parameter_output = Vector3(float(input[i_line]), float(input[i_line + 1]), float(input[i_line + 2]))
				#needs to be incremented by 2, the x y z are stored as separate floats
				i_line = i_line + 2
		#load vector4
			elif parameter.type == TYPE_VECTOR4:
				parameter_output = Vector4(float(input[i_line]), float(input[i_line + 1]), float(input[i_line + 2]), float(input[i_line + 3]))
				#needs to be incremented by 3, the x y z w are stored as separate floats
				i_line = i_line + 3
		#load colors
			elif parameter.type == TYPE_COLOR:
				parameter_output = Color8(int(input[i_line]), int(input[i_line + 1]), int(input[i_line + 2]), int(input[i_line + 3]))
				#needs to be incremented by 3, the r g b a are stored as separate ints
				i_line = i_line + 3
			elif parameter.type == TYPE_OBJECT and parameter.hint_string == "Material":
				parameter_output = null
			else:
				push_error("unimplemented type ", parameter)
				return
			
			result_asset.set(properties[i].name, parameter_output)
			i_line = i_line + 1
			i = i + 1
		
		return result_asset


static func mesh_serialize(input : Mesh):
	return PackedStringArray([AssetManager.normalize_asset_name(input.resource_path, true)])


static func mesh_deserialize(input : PackedStringArray):
	return AssetManager.get_asset_by_name(AssetManager.normalize_asset_name(input[0], false))


static func part_serialize(input, color_to_int_mapping : Dictionary, material_name_to_int_mapping : Dictionary, mesh_name_to_int_mapping : Dictionary):
	var result_line : PackedStringArray = []
	#position
	result_line.append(str(input.transform.origin.x))
	result_line.append(str(input.transform.origin.y))
	result_line.append(str(input.transform.origin.z))
	#scale
	result_line.append(str(input.part_scale.x))
	result_line.append(str(input.part_scale.y))
	result_line.append(str(input.part_scale.z))
	#rotation (quaternion kept failing at certain angles)
	result_line.append(str(input.rotation_degrees.x))
	result_line.append(str(input.rotation_degrees.y))
	result_line.append(str(input.rotation_degrees.z))
	#color
	result_line.append(str(color_to_int_mapping[input.part_color]))
	#material
	result_line.append(str(material_name_to_int_mapping[AssetManager.get_name_of_asset(input.part_material, false)]))
	#mesh
	result_line.append(str(mesh_name_to_int_mapping[AssetManager.get_name_of_asset(input.part_mesh_node.mesh)]))
	
	return result_line


static func part_deserialize(input, used_colors : Array, used_materials : Array, used_meshes : Array):
	var new : Part = Part.new()
	#position
	new.transform.origin.x = float(input[0])
	new.transform.origin.y = float(input[1])
	new.transform.origin.z = float(input[2])
	#scale
	new.part_scale.x = float(input[3])
	new.part_scale.y = float(input[4])
	new.part_scale.z = float(input[5])
	#rotation
	new.rotation_degrees.x = float(input[6])
	new.rotation_degrees.y = float(input[7])
	new.rotation_degrees.z = float(input[8])
	#mesh
	new.part_mesh_node.mesh = used_meshes[int(input[11])]
	#material
	new.part_material = used_materials[int(input[10])]
	#color
	new.part_color = used_colors[int(input[9])]
	return new


#saves everything to disk
static func data_zip(input_assets : Array[Resource], input_save_file : PackedStringArray, filepath : String, filename : String):
	#get all of the subresources which arent saved in the csv
	#includes: shader code, image textures, mesh dat
	var zip_packer : ZIPPacker = ZIPPacker.new()
	var dir_access : DirAccess = DirAccess.open(filepath)
	var subresources : Array = []
	var total : Array[Resource] = []
	var filenames : PackedStringArray = []
	var i : int = 0
	
	#get all subresources
	while i < input_assets.size():
		if input_assets[i] is Resource:
			subresources.append_array(AssetManager.get_subresources(input_assets[i]))
		i = i + 1
	
	#deduplicate and exclude material types as they are already serialized in data.csv
	input_assets.append_array(subresources)
	i = 0
	while i < input_assets.size():
		var resource_already_listed : bool = false
		
		for j in total:
			if AssetManager.get_name_of_asset(j) == AssetManager.get_name_of_asset(input_assets[i]):
				"DEBUG"
				#print(j.resource_path)
				#print(j.resource_name)
				#print(input_assets[i].resource_path)
				#print(input_assets[i].resource_name)
				resource_already_listed = true
				break
		
		if not resource_already_listed and not input_assets[i] is BaseMaterial3D and not input_assets[i] is ShaderMaterial:
			total.append(input_assets[i])
		
		i = i + 1
	
	
	
	
	zip_packer.open(filepath + filename + ".tmv")
	
	#start with serialized data file
	zip_packer.start_file(filename + "_data.csv")
	
	#quick conversion
	var byte_array : PackedByteArray = []
	for line in input_save_file:
		byte_array.append_array((line + "\n").to_utf8_buffer())
	
	
	zip_packer.write_file(byte_array)
	zip_packer.close_file()
	
	#save each subresource to disk
	#print("asset save start")
	i = 0
	while i < total.size():
		#print("iteration ", i, "-----------------------------------------------")
		var asset : Resource = total[i]
		var asset_name = AssetManager.get_name_of_asset(asset, false, true)
		var debug_asset_saved : bool = false
		
		if asset is Texture2D:
			zip_packer.start_file(asset_name)
			var image : Image = asset.get_image()
			zip_packer.write_file(image.save_png_to_buffer())
			zip_packer.close_file()
			debug_asset_saved = true
		elif asset is Shader:
			zip_packer.start_file(asset_name)
			zip_packer.write_file(asset.code.to_utf8_buffer())
			zip_packer.close_file()
			debug_asset_saved = true
		elif asset is Mesh:
			"TODO"#use obj instead of resource file
			ResourceSaver.save(asset, filepath + asset_name)
			zip_packer.start_file(asset_name)
			zip_packer.write_file(FileAccess.get_file_as_bytes(filepath + asset_name))
			zip_packer.close_file()
			dir_access.remove(filepath + asset_name)
			debug_asset_saved = true
		else:
			push_error("unimplemented asset type: " + str(asset))
		
		#if debug_asset_saved:
		#	print("asset saved:     ", asset)
		#else:
		#	print("asset not saved: ", asset)
		
		i = i + 1
	
	zip_packer.close()


#loads resources from disk
"TODO"#consider adding automated renaming function to assetmanager to further prevent name collisions
#using uuid.gd but shortened uuid to like 5 numbers
static func data_unzip(filepath : String, filename : String):
	var zip_reader : ZIPReader = ZIPReader.new()
	var dir_access : DirAccess = DirAccess.open(filepath)
	
	
	#serialized data file will be stored here
	var file : PackedStringArray = []
	#names of files contained in save
	var file_names : PackedStringArray = []
	zip_reader.open(filepath + filename + ".tmv")
	file_names = zip_reader.get_files()
	
	
	#load each subresource from disk depending on the name
	#print("asset load start")
	var i : int = 0
	while i < file_names.size():
		#print("iteration ", i, "-----------------------------------------------")
		var asset : Resource
		var file_name = file_names[i]
		var extension = file_name.get_extension().to_lower()
		var load_subresource : bool = false
		
		#in case it is not available, load subresource (like an image texture or a mesh)
		load_subresource = not AssetManager.is_asset_key_taken(AssetManager.normalize_asset_name(file_name, false))
		
		#print("RESOURCE KEY CHECK: ", file_name, " | ", AssetManager.normalize_asset_name(file_name, false))
		if not load_subresource:
			i = i + 1
			#print("subresource already available")
			continue
		#else:
			#print("loading subresource")
		
	#resource file
		if extension == "tres" or extension == "res":
			var resource_bytes : PackedByteArray = zip_reader.read_file(file_name)
			var file_access = FileAccess.open(filepath + file_name, FileAccess.WRITE)
			file_access.store_buffer(resource_bytes)
			file_access.close()
			var resource_result = ResourceLoader.load(filepath + file_name)
			DirAccess.remove_absolute(filepath + file_name)
			resource_result.resource_path = filepath + file_name
			AssetManager.register_asset(resource_result)
	#data file
		elif extension == "csv":
			var data_bytes : PackedByteArray = zip_reader.read_file(file_name)
			file = data_bytes.get_string_from_utf8().split("\n")
			
	#image file
		elif extension == "png" or extension == "jpg" or extension == "jpeg":
			var image : Image = Image.new()
			"TODO"#stupid code but whatever i will fix it later in a major refactoring
			if extension != "png":
				image.load_jpg_from_buffer(zip_reader.read_file(file_name))
				if image.is_empty():
					image.load_png_from_buffer(zip_reader.read_file(file_name))
			else:
				image.load_png_from_buffer(zip_reader.read_file(file_name))
				if image.is_empty():
					image.load_jpg_from_buffer(zip_reader.read_file(file_name))
			
			image.generate_mipmaps()
			var image_texture : ImageTexture = ImageTexture.create_from_image(image)
			image_texture.resource_path = filepath + file_name
			print(image_texture.resource_path)
			AssetManager.register_asset(image_texture)
	#shader code
		elif extension == "gdshader":
			var data_bytes : PackedByteArray = zip_reader.read_file(file_name)
			var shader_result : Shader = Shader.new()
			shader_result.code = data_bytes.get_string_from_utf8()
			shader_result.resource_path = filepath + file_name
			
			AssetManager.register_asset(shader_result)
		else:
			push_error("unimplemented filetype, aborting")
			return
		
		i = i + 1
	
	zip_reader.close()
	
	
	return file


static func get_colors_from_parts(input_parts : Array):
	var used_colors : Array[Color] = []
	var i : int = 0
	while i < input_parts.size():
		if not used_colors.has(input_parts[i].part_color):
			used_colors.append(input_parts[i].part_color)
		i = i + 1
	
	return used_colors

static func get_materials_from_parts(input_parts : Array):
	var used_materials : Array[Material] = []
	var i : int = 0
	
	used_materials.append(input_parts[0].part_material)
	while i < input_parts.size():
		var j : int = 0
		var has_material : bool = false
		
		while j < used_materials.size():
			var base_1 = AssetManager.get_name_of_asset(used_materials[j], false)
			var base_2 = AssetManager.get_name_of_asset(input_parts[i].part_material, false)
			if base_2 == base_1:
				has_material = true
				break
			j = j + 1
		
		if not has_material:
			used_materials.append(input_parts[i].part_material)
		i = i + 1
	return used_materials


static func get_meshes_from_parts(input_parts : Array):
	var i : int = 0
	var used_meshes : Array[Mesh] = []
	
	used_meshes.append(input_parts[0].part_mesh_node.mesh)
	while i < input_parts.size():
		var j : int = 0
		var has_mesh : bool = false
		while j < used_meshes.size():
			if AssetManager.get_name_of_asset(input_parts[i].part_mesh_node.mesh) == AssetManager.get_name_of_asset(used_meshes[j]):
				has_mesh = true
				break
			j = j + 1
			
		if not has_mesh:
			used_meshes.append(input_parts[i].part_mesh_node.mesh)
		i = i + 1
	
	return used_meshes


#surprisingly godot did not have recursive functions for getting files or reading files recursively
static func get_files_recursive(filepath : String, file_names : PackedStringArray = []):
	file_names.append_array(DirAccess.get_files_at(filepath))
	for i in DirAccess.get_directories_at(filepath):
		var inner_file_names : PackedStringArray = get_files_recursive(filepath.path_join(i))
		for j in inner_file_names:
			#add path to lower level
			file_names.append(i.path_join(j))
	
	return file_names


#https://www.reddit.com/r/godot/comments/19f0mf2/deleted_by_user/
static func copy_dir_recursively(source: String, destination: String):
	DirAccess.make_dir_recursive_absolute(destination)
	
	var source_dir = DirAccess.open(source);
	
	for filename in source_dir.get_files():
		#OS.alert(source + filename, 'Datei erkannt')
		source_dir.copy(source + filename, destination + filename)
		
	for dir in source_dir.get_directories():
		copy_dir_recursively(source + dir + "/", destination + dir + "/")


#experimental
"TODO"#test
static func replace_tres_filepaths(filepath : String, filename : String, dependency_filename_mapping : Dictionary):
	var combined_path : String = filepath.path_join(filename)
	var file : String = FileAccess.get_file_as_string(combined_path)
	var lines : PackedStringArray = file.split("\n")
	var lines_new : String = ""
	for i in lines:
		var result : String = ""
		var sections : PackedStringArray = []
		var index_first : int = i.find("path=\"")
		var index_last : int = i.find("\" id=", index_first)
		var ext_resource_true : bool = i.begins_with("[ext_resource")
		#replace everything between index_first
		#found a path to a dependency
		if index_first != -1 and index_last != -1 and ext_resource_true:
			#+6 because i need the index of the last char, not the first
			index_first = index_first + 6
			#before the filepath begins
			sections.append(i.substr(0, index_first))
			#dependency filepath
			sections.append(i.substr(index_first, (index_last) - index_first))
			#after the filepath
			sections.append(i.substr(index_last))
			
			#get the dependency file name and
			var dependency_file_new_path : String = dependency_filename_mapping.get(sections[1].get_file())
			
			if dependency_file_new_path.is_empty():
				push_error("no file found in filenames for", filename, ", at line:\n", i, "\nskipping line")
				lines_new = i + "\n"
				continue
			
			#replace the problematic dependency path
			result = sections[0] + filepath.path_join(dependency_file_new_path) + sections[2]
		#no dependency path found 
		else:
			result = i
			
			if ext_resource_true:
				push_error("no path to dependency found at:", filepath.path_join(filename), ", at line:\n", i, "\nskipping line")
		
		lines_new = lines_new + result + "\n"
	
	var file_access : FileAccess = FileAccess.open(combined_path, FileAccess.WRITE)
	file_access.store_string(lines_new)
	file_access.close()
