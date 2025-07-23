extends RefCounted
class_name SaveUtils


static func serialize_color(input : Color):
	return PackedStringArray([str(input.r8), str(input.g8), str(input.b8)])

static func deserialize_color(input : PackedStringArray):
	return Color8(int(input[0]), int(input[1]), int(input[2]))


static func serialize_material(input):
	#saving shadermaterial to file
	if input is ShaderMaterial:
		var result_line : PackedStringArray = []
		result_line.append("ShaderMaterial")
		result_line.append(AssetManager.get_asset_name(input.shader))
		result_line.append(AssetManager.get_asset_name(input))
		
		var properties : Array = input.shader.get_shader_uniform_list()
		
		var i : int = 0
		while i < properties.size():
			var parameter = input.get_shader_parameter(properties[i].name)
			print("parameter", parameter)
			if parameter is Texture2D:
				result_line.append(AssetManager.get_asset_name(parameter))
			elif parameter is float:
				result_line.append(str(parameter))
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
		
		result_line.append(AssetManager.get_asset_name(input))
		
		
		var properties = input.get_property_list()
		var i : int = 0
		while i < properties.size():
			var property = properties[i]
			#skip non-persistent/internal properties
			if property.usage & PROPERTY_USAGE_STORAGE == 0:
				i = i + 1
				continue
			
			var parameter = input.get(properties[i].name)
			if parameter is Texture2D:
				result_line.append(AssetManager.get_asset_name(parameter))
			elif parameter is float:
				result_line.append(str(parameter))
			elif parameter is Vector3:
				result_line.append_array([str(parameter.x), str(parameter.y), str(parameter.z)])
			elif parameter is Vector4:
				result_line.append_array([str(parameter.w), str(parameter.x), str(parameter.y), str(parameter.z)])
			elif parameter is Color:
				result_line.append_array([str(parameter.r8), str(parameter.g8), str(parameter.b8), str(parameter.a8)])
			elif parameter == null and property.type == TYPE_VECTOR3:
				result_line.append_array(["","",""])
			elif parameter == null and property.type == TYPE_VECTOR4 or properties[i].type == TYPE_COLOR:
				result_line.append_array(["","","",""])
			elif parameter == null and property.type == TYPE_FLOAT or properties[i].type == TYPE_INT or properties[i].type == TYPE_STRING:
				result_line.append("")
			else:
				push_error("unimplemented basematerial3d type: ", parameter.hint_string, " ", parameter)
				return
			i = i + 1
		return result_line


static func deserialize_material(input : PackedStringArray):
#loading shadermaterial from file
	if input[0] == "ShaderMaterial":
		#load material
		var result_asset : ShaderMaterial
		var asset_name : String = AssetManager.normalize_asset_name(input[2])
		result_asset = AssetManager.get_asset_by_name(asset_name)
		if result_asset != null:
			return result_asset
		else:
			result_asset = ShaderMaterial.new()
			result_asset.resource_path = asset_name
			AssetManager.register_asset(result_asset)
		
		#load shader code
		var shader : Shader
		asset_name = AssetManager.standardize_name(input[1])
		shader = AssetManager.get_asset_by_name(asset_name)
		if shader == null:
			push_error("shader loading failure")
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
				#check if this subresource is reused by any other material
				#AssetManager.get_asset_by_name(input[i_line])
				var image_texture : ImageTexture = AssetManager.get_asset_by_name(AssetManager.normalize_asset_name(input[i_line]))
				
				#if image texture still hasnt loaded, abort
				if image_texture == null:
					push_error("image texture loading failure")
					return
				
				parameter_output = image_texture
		#load float
			elif parameter.type == TYPE_FLOAT:
				parameter_output = float(input[i_line])
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
		var asset_name : String = AssetManager.normalize_asset_name(input[1])
		result_asset = AssetManager.get_asset_by_name(asset_name)
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
			#skip non-persistent/internal properties
			if parameter.usage & PROPERTY_USAGE_STORAGE == 0:
				i = i + 1
				continue
			
			var parameter_output
		#load image texture
			if parameter.type == TYPE_OBJECT and parameter.hint_string == "Texture2D":
				#check if this subresource is reused by any other material
				#AssetManager.get_asset_by_name(input[i_line])
				var image_texture : ImageTexture = AssetManager.get_asset_by_name(AssetManager.normalize_asset_name(input[i_line]))
				
				#if image texture still hasnt loaded, abort
				if image_texture == null:
					push_error("image texture loading failure")
					return
				
				parameter_output = image_texture
		#load float
			elif parameter.type == TYPE_FLOAT:
				parameter_output = float(input[i_line])
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
			else:
				push_error("unimplemented type ", parameter.hint_string, " ", parameter)
				return
			
			result_asset.set(properties[i].name, parameter_output)
			i_line = i_line + 1
			i = i + 1
		
		return result_asset


static func serialize_mesh(input : Mesh):
	return PackedStringArray([AssetManager.normalize_asset_name(input.resource_path)])

static func deserialize_mesh(input : PackedStringArray):
	return 


static func serialize_part(input, color_to_int_mapping : Dictionary, material_name_to_int_mapping : Dictionary, mesh_name_to_int_mapping : Dictionary):
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
	result_line.append(str(material_name_to_int_mapping[AssetManager.get_asset_name(input.part_material, false)]))
	#mesh
	result_line.append(str(mesh_name_to_int_mapping[AssetManager.get_asset_name(input.part_mesh_node.mesh)]))
	
	return result_line


static func deserialize_part(input, used_colors : Array, used_materials : Array, used_meshes : Array):
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

#loads resources from disk
static func load_assets(input : PackedStringArray):
	
	return

#saves various resources to disk
static func save_assets(input : Array):
	
	return

#if image_texture == null:
#	var image : Image = Image.new()
#	image.load_png_from_buffer(zip_reader.read_file(input[j_line]))
#	image.generate_mipmaps()
#	image_texture = ImageTexture.create_from_image(image)
#	result_asset.set_shader_parameter(properties[j].name, image_texture)
#	AssetManager.register_asset(image_texture)

#enter names of files that have to be zipped
static func zip_files(input : PackedStringArray):
	#zip up files at specific location
	#open zip packer
	#for i in input:
	#zip_packer.zip(i)
	#close zip packer
	"TODO"#not sure about this
	#should definitely centralize these variables as much as possible
	var file_access = FileAccess.open(filepath + name + "_data.csv", FileAccess.WRITE)
	var dir_access = DirAccess.open(filepath)
	var zip_packer = ZIPPacker.new()
	zip_packer.open(filepath + name + ".tmv")
	
	var data_file : String = filepath + name + "_data.csv"
	
	
	file_access.flush()
	i = 0
	while i < file.size():
		file_access.store_line(file[i])
		i = i + 1
	file_access.close()
	
	zip_packer.start_file(name + "_data.csv")
	zip_packer.write_file(FileAccess.get_file_as_bytes(data_file))
	zip_packer.close_file()
	
	i = 0
	#embed used assets in the zip file
	while i < assets_used.size():
		var r_name = assets_used[i].resource_path.get_file()
		if assets_used[i] is Texture2D:
			zip_packer.start_file(r_name)
			var img : Image = assets_used[i].get_image()
			zip_packer.write_file(img.save_png_to_buffer())
			zip_packer.close_file()
		elif assets_used[i] is Shader:
			zip_packer.start_file(r_name)
			zip_packer.write_file(assets_used[i].code.to_utf8_buffer())
			zip_packer.close_file()
		elif assets_used[i] is Mesh:
			ResourceSaver.save(assets_used[i], filepath + r_name)
			zip_packer.start_file(r_name)
			zip_packer.write_file(FileAccess.get_file_as_bytes(filepath + r_name))
			zip_packer.close_file()
			dir_access.remove(filepath + r_name)
		else:
			print("UNIMPLEMENTED ASSET TYPE: " + str(assets_used[i]))
		i = i + 1
	
	dir_access.remove(data_file)
	zip_packer.close()
	return


#enter names of files that have to be unzipped
static func unzip_files(input : PackedStringArray):
	#unzip files at specific location
	return






#not sure if i will extract the logic into here, we will see
