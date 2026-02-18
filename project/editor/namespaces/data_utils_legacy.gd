extends RefCounted
class_name DataUtilsLegacy


#legacy csv functions
static func csv_color_deserialize(input : PackedStringArray):
	return Color.from_rgba8(int(input[0]), int(input[1]), int(input[2]))


static func csv_material_deserialize(input : PackedStringArray):
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
				#if no filename is set here, im assuming the material was not assigned a texture
				if input[i_line] == "":
					parameter_output = null
					i = i + 1
					i_line = i_line + 1
					continue
				
				var image_texture : ImageTexture = AssetManager.get_asset_by_name(AssetManager.normalize_asset_name(input[i_line], false))
				
				#if image texture still hasnt loaded error but continue loading
				if image_texture == null:
					push_error("image texture loading failure: ", input[i_line], " at line index: ", i_line, " at property index: ", i, ", property name: ", parameter.name)
				
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
				parameter_output = Color.from_rgba8(int(input[i_line]), int(input[i_line + 1]), int(input[i_line + 2]), int(input[i_line + 3]))
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
				parameter_output = Color.from_rgba8(int(input[i_line]), int(input[i_line + 1]), int(input[i_line + 2]), int(input[i_line + 3]))
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


static func csv_mesh_serialize(input : Mesh):
	return PackedStringArray([AssetManager.normalize_asset_name(input.resource_path, true)])


static func csv_mesh_deserialize(input : PackedStringArray):
	return AssetManager.get_asset_by_name(AssetManager.normalize_asset_name(input[0], false))




static func csv_part_deserialize(input, used_colors : Array, used_materials : Array, used_meshes : Array):
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
	new.part_mesh = used_meshes[int(input[11])]
	#material
	new.part_material = used_materials[int(input[10])]
	#color
	new.part_color = used_colors[int(input[9])]
	return new


#adds newline to each packedstringarray entry and turns it into a byte array
static func csv_to_bytes(input_csv_file):
	#quick conversion
	var byte_array : PackedByteArray = []
	for line in input_csv_file:
		byte_array.append_array((line + "\n").to_utf8_buffer())
	return byte_array
