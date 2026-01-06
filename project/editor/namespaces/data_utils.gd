extends RefCounted
class_name DataUtils

"TODO"#improve error handling
"TODO"#automated load function dispatch based on version number
#(2d array of callables and 2d array of their parameters), one inner array per save file version number
#add file for keeping legacy loading functions
"TODO"#unify all saving and loading operations into this file
#that also means settings loading and tres path rewriting

class SQLDefinitions:
	const version_table_name : String = "version"
	const version_table : Dictionary = {
		"save_version": {"data_type":"int"},
		"engine_version": {"data_type":"text"}
	}
	const version_data : Dictionary = {"save_version": 1, "engine_version": "v4.5.stable"}
	
	const color_table_name : String = "colors"
	const color_table : Dictionary = {
		"id": {"data_type":"int", "primary_key": true, "not_null": true, "auto_increment": true},
		"r": {"data_type":"int"},
		"g": {"data_type":"int"},
		"b": {"data_type":"int"}
	}
	
	const material_table_name : String = "materials"
	const material_table : Dictionary = {
		"id": {"data_type":"int", "primary_key": true, "not_null": true, "auto_increment": true},
		"csv_type_information": {"data_type":"text"},
		"csv_headers": {"data_type":"text"},
		"csv_values": {"data_type":"text"}
	}
	
	const mesh_table_name : String = "meshes"
	const mesh_table : Dictionary = {
		"id": {"data_type":"int", "primary_key": true, "not_null": true, "auto_increment": true},
		"mesh_filename": {"data_type":"text"},
	}
	
	const part_table_name : String = "parts"
	const part_table : Dictionary = {
		"id": {"data_type":"int", "primary_key": true, "not_null": true, "auto_increment": true},
		"position": {"data_type":"blob"},
		"rotation": {"data_type":"blob"},
		"scale": {"data_type":"blob"},
		"color_id": {"data_type":"int"},
		"material_id": {"data_type":"int"},
		"mesh_id": {"data_type":"int"}
	}
	
	const group_table_name : String = "groups"
	const group_table : Dictionary = {
		"id": {"data_type":"int", "primary_key": true, "not_null": true, "auto_increment": true},
		"parent_group_id": {"data_type":"int"}
	}
	
	const group_part_table_name : String = "groups_parts"
	const group_part_table : Dictionary = {
		"id": {"data_type":"int", "primary_key": true, "not_null": true, "auto_increment": true},
		"group_id": {"data_type":"int"},
		"part_id": {"data_type":"int"}
	}

static var sql_def : SQLDefinitions = SQLDefinitions.new()


static func initialize_sql_db(filepath : String, filename : String, verbosity : SQLite.VerbosityLevel = SQLite.VerbosityLevel.NORMAL):
	if not filename.is_valid_filename():
		push_error("invalid filename!!")
		return
	
	var sql : SQLite = SQLite.new()
	sql.path = filepath.path_join(filename)
	sql.open_db()
	sql.create_table(sql_def.color_table_name, sql_def.color_table)
	sql.create_table(sql_def.material_table_name, sql_def.material_table)
	sql.create_table(sql_def.mesh_table_name, sql_def.mesh_table)
	sql.create_table(sql_def.part_table_name, sql_def.part_table)
	sql.create_table(sql_def.group_part_table_name, sql_def.group_part_table)
	sql.create_table(sql_def.group_table_name, sql_def.group_table)
	
	sql.create_table(sql_def.version_table_name, sql_def.version_table)
	sql.insert_row(sql_def.version_table_name, sql_def.version_data)
	
	return sql


static func sql_color_serialize(color : Color, sql : SQLite):
	return sql.insert_row(sql_def.color_table_name, {"r": color.r8, "g": color.g8, "b": color.b8})

static func sql_color_deserialize(row : Dictionary):
	return Color.from_rgba8(row["r"], row["g"], row["b"])


static func sql_material_serialize(input : Material, sql : SQLite):
	#saving shadermaterial to file
	var result_csv_headers : PackedStringArray = []
	var result_csv_values : PackedStringArray = []
	var result_csv_type_information : PackedStringArray = []
	
#first, type information
	if input is ShaderMaterial:
		#include material type
		result_csv_type_information.append("ShaderMaterial")
		#include shader code file name
		result_csv_type_information.append(AssetManager.get_name_of_asset(input.shader))
		#DONT include colors during serialization, causes huge problems
		#and there is already a color header anyway
		#include shader material name without color
		result_csv_type_information.append(AssetManager.get_name_of_asset(input, false))
	elif input is StandardMaterial3D:
		result_csv_type_information.append("StandardMaterial3D")
		#DONT include colors during serialization, causes huge problems
		#and there is already a color header anyway
		#just set the part color on load and it will automatically recolor the required material
		result_csv_type_information.append(AssetManager.normalize_asset_name(AssetManager.get_name_of_asset(input, false), false))
	elif input is ORMMaterial3D:
		result_csv_type_information.append("ORMMaterial3D")
		result_csv_type_information.append(AssetManager.normalize_asset_name(AssetManager.get_name_of_asset(input, false), false))
	else:
		push_error("invalid type: ", input)
		return false
	
#second, property serializing
	if input is ShaderMaterial:
		var properties : Array = input.shader.get_shader_uniform_list()
		
		#save all csv values and their headers for maximum reliability
		var i : int = 0
		while i < properties.size():
			var parameter = input.get_shader_parameter(properties[i].name)
			result_csv_headers.append(properties[i].name)
			result_csv_values.append_array(material_property_serialize(parameter, properties[i]))
			i = i + 1
		
	elif input is StandardMaterial3D or input is ORMMaterial3D:
		var properties = input.get_property_list()
		var i : int = 0
		
		while i < properties.size():
			var property = properties[i]
			#skip non-persistent/internal properties
			if property.usage & PROPERTY_USAGE_STORAGE == 0:
				i = i + 1
				continue
			
			var parameter = input.get(properties[i].name)
			result_csv_headers.append(properties[i].name)
			result_csv_values.append_array(material_property_serialize(parameter, property))
			
			i = i + 1
	
	return sql.insert_row(sql_def.material_table_name, {
		"csv_type_information": ",".join(result_csv_type_information),
		"csv_headers": ",".join(result_csv_headers),
		"csv_values": ",".join(result_csv_values)
		})


static func sql_material_deserialize(row : Dictionary):
	#loading shadermaterial from sql row
	var csv_type_information : PackedStringArray = row["csv_type_information"].split(",")
	var csv_headers : PackedStringArray = row["csv_headers"].split(",")
	var csv_values : PackedStringArray = row["csv_values"].split(",")
	
	if csv_type_information[0] == "ShaderMaterial":
		#load material
		var result_asset : ShaderMaterial
		var asset_name : String = AssetManager.normalize_asset_name(csv_type_information[2], false)
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
		asset_name = AssetManager.normalize_asset_name(csv_type_information[1], false)
		shader = AssetManager.get_asset_by_name(asset_name)
		if shader == null:
			push_error("shader loading failure, name in save file: " + csv_type_information[1])
			return
		#assign shader
		result_asset.shader = shader
		
		var properties : Array = shader.get_shader_uniform_list()
		var i : int = 0
		#start at 3 because line item 0, 1 and 2 are the material type, shader name and material name respectively
		var i_line : int = 3
		
		while i < properties.size():
			var parameter = properties[i]
			var parameter_output = material_property_deserialize(csv_values, parameter, i_line)
			
			result_asset.set_shader_parameter(properties[i].name, parameter_output)
			
			#skip past vectors and colors
			if csv_values[i_line].begins_with("["):
				var starting_index : int = i_line
				while not csv_values[i_line].ends_with("]"):
					if i_line == csv_values.size() - 1:
						push_error("malformed csv, missing closed bracket starting at item ", starting_index)
						return result_asset
					i_line = i_line + 1
			
			i_line = i_line + 1
			i = i + 1
		
		return result_asset
	
	
#loading basematerial3d from file
	elif csv_type_information[0] == "StandardMaterial3D" or csv_type_information[0] == "ORMMaterial3D":
		#load material
		var result_asset : BaseMaterial3D
		var asset_name : String = AssetManager.normalize_asset_name(csv_type_information[1], false)
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
			
			if i_line > csv_values.size() - 1:
				return result_asset
			
			#skip non-persistent/internal properties
			if parameter.usage & PROPERTY_USAGE_STORAGE == 0 or csv_values[i_line] == "":
				#omitting this line caused a nasty desynchronization bug between the two counters
				if csv_values[i_line] == "":
					i_line = i_line + 1
				i = i + 1
				continue
			
			var parameter_output = material_property_deserialize(csv_values, parameter, i_line)
			
			#skip past vectors and colors
			if csv_values[i_line].begins_with("["):
				var starting_index : int = i_line
				while not csv_values[i_line].ends_with("]"):
					if i_line == csv_values.size() - 1:
						push_error("malformed csv, missing closed bracket starting at item ", starting_index)
						return
					i_line = i_line + 1
			
			result_asset.set(properties[i].name, parameter_output)
			i_line = i_line + 1
			i = i + 1
		
		return result_asset


static func sql_mesh_serialize(input : Mesh, sql : SQLite):
	return sql.insert_row(sql_def.mesh_table_name, {"mesh_filename": AssetManager.normalize_asset_name(input.resource_path, true)})


static func sql_mesh_deserialize(row : Dictionary):
	return AssetManager.get_asset_by_name(AssetManager.normalize_asset_name(row["mesh_filename"], false))


static func sql_part_serialize(input : Part, color_to_int_mapping : Dictionary, material_name_to_int_mapping : Dictionary, mesh_name_to_int_mapping : Dictionary, sql : SQLite):
	var part_table : Dictionary = {}
	
	part_table["position"] = var_to_bytes(input.transform.origin)
	part_table["rotation"] = var_to_bytes(input.rotation_degrees)
	part_table["scale"] = var_to_bytes(input.part_scale)
	part_table["color_id"] = color_to_int_mapping[input.part_color]
	part_table["material_id"] = material_name_to_int_mapping[AssetManager.get_name_of_asset(input.part_material, false)]
	part_table["mesh_id"] = mesh_name_to_int_mapping[AssetManager.get_name_of_asset(input.part_mesh_node.mesh)]
	
	return sql.insert_row(sql_def.part_table_name, part_table)


static func sql_part_deserialize(row : Dictionary, used_colors : Array[Color], used_materials : Array[Material], used_meshes : Array[Mesh]):
	var new : Part = Part.new()
	#position
	new.transform.origin = bytes_to_var(row["position"])
	#rotation
	new.rotation_degrees = bytes_to_var(row["rotation"])
	#scale
	new.part_scale = bytes_to_var(row["scale"])
	#mesh
	new.part_mesh_node.mesh = used_meshes[row["material_id"]]
	#material
	new.part_material = used_materials[row["material_id"]]
	#color
	new.part_color = used_colors[row["color_id"]]
	
	return new


#legacy csv functions ----------------------------------------------------------
static func csv_color_serialize(input : Color):
	return PackedStringArray([str(input.r8), str(input.g8), str(input.b8)])


static func csv_color_deserialize(input : PackedStringArray):
	return Color.from_rgba8(int(input[0]), int(input[1]), int(input[2]))


static func csv_material_serialize(input : Material):
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
			result_line.append_array(material_property_serialize(parameter, properties[i]))
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
		#just set the part color on load and it will automatically recolor the required material
		result_line.append(AssetManager.normalize_asset_name(AssetManager.get_name_of_asset(input, false), false))
		var properties = input.get_property_list()
		var i : int = 0
		
		while i < properties.size():
			var property = properties[i]
			#skip non-persistent/internal properties
			if property.usage & PROPERTY_USAGE_STORAGE == 0:
				i = i + 1
				continue
			
			var parameter = input.get(properties[i].name)
			result_line.append_array(material_property_serialize(parameter, property))
			
			i = i + 1
		return result_line


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


static func csv_part_serialize(input, color_to_int_mapping : Dictionary, material_name_to_int_mapping : Dictionary, mesh_name_to_int_mapping : Dictionary):
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
	new.part_mesh_node.mesh = used_meshes[int(input[11])]
	#material
	new.part_material = used_materials[int(input[10])]
	#color
	new.part_color = used_colors[int(input[9])]
	return new


"TODO"#i need:
#zip_add_data_csv
#zip_read_data_csv
#zip_add_data_sql
#zip_read_data_sql
#zip_add_assets
#zip_read_assets
#zip_determine_save_version
#saves everything to disk
static func zip_start(filepath : String, filename : String):
	var zip_packer : ZIPPacker = ZIPPacker.new()
	var error : int = zip_packer.open(filepath.path_join(filename) + ".tmv")
	if error != OK:
		push_error("opening zip packer failed, error code: ", error, " error name: ", error_string(error))
		return null
	return zip_packer


static func zip_end(zip_packer : ZIPPacker, filepath : String, files_to_clean_up : PackedStringArray):
	var error : int
	for file in files_to_clean_up:
		error = DirAccess.remove_absolute(filepath.path_join(file))
		if error != OK:
			push_error("cleaning file ", file, " after zip failed, error code: ", error, " error name: ", error_string(error))
	
	error = zip_packer.close()
	if error != OK:
		push_error("closing zip packer failed, error code: ", error, " error name: ", error_string(error),"\nattempting to end zip operation")
		zip_packer.call_deferred("free")


static func unzip_start(filepath : String, filename : String):
	var zip_reader : ZIPReader = ZIPReader.new()
	var error : int = zip_reader.open(filepath.path_join(filename) + ".tmv")
	if error != OK:
		push_error("opening zip reader failed, error code: ", error, " error name: ", error_string(error))
		return null
	return zip_reader


static func unzip_end(zip_reader : ZIPReader, filepath : String, files_to_clean_up : PackedStringArray):
	var error : int
	for file in files_to_clean_up:
		error = DirAccess.remove_absolute(filepath.path_join(file))
		if error != OK:
			push_error("cleaning file ", file, " after zip failed, error code: ", error, " error name: ", error_string(error))
	
	error = zip_reader.close()
	if error != OK:
		push_error("closing zip reader failed, error code: ", error, " error name: ", error_string(error),"\nattempting to end zip operation")
		zip_reader.call_deferred("free")


static func zip_check_save_version(zip_reader : ZIPReader):
	var files : PackedStringArray = zip_reader.get_files()
	var version_number : int = 0
	
	for file in files:
		if file.get_extension() == "csv":
			return 0
		elif file.get_extension() == "db":
			return 1


#for copying sql db file out of zip
static func zip_copy_to_filesystem(zip_reader : ZIPReader, filepath_origin : String, filename : String, filepath_destination : String):
	var error : int
	
	var buffer : PackedByteArray = zip_reader.read_file(filepath_origin.path_join(filename))
	var file_access : FileAccess = FileAccess.open(filepath_origin.path_join(filename), FileAccess.WRITE)
	error = file_access.store_buffer(buffer)
	if error != OK:
		push_error("copying file ", filename, " from ", filepath_origin, " to ", filepath_destination)
	
	file_access.close()


#zip serialized (csv or sql) data file
static func zip_data_file(zip_packer : ZIPPacker, data_file_as_bytes : PackedByteArray, filepath : String, filename : String, file_ending : String):
	var error : Error 
	error = zip_packer.start_file(filename + "_data" + file_ending)
	if error != OK:
		push_error("starting database file in zip failed, error code: ", error, " error name: ", error_string(error))
	
	error = zip_packer.write_file(data_file_as_bytes)
	if error != OK:
		push_error("writing database file to zip failed, error code: ", error, " error name: ", error_string(error))
	
	error = zip_packer.close_file()
	if error != OK:
		push_error("closing database file in zip failed, error code: ", error, " error name: ", error_string(error))


static func unzip_data_file(zip_reader : ZIPReader, filename : String):
	#data file
	var data_bytes : PackedByteArray = zip_reader.read_file(filename)
	return data_bytes.get_string_from_utf8().split("\n")


#adds newline to each packedstringarray entry and turns it into a byte array
static func csv_to_bytes(input_csv_file):
	#quick conversion
	var byte_array : PackedByteArray = []
	for line in input_csv_file:
		byte_array.append_array((line + "\n").to_utf8_buffer())
	return byte_array

#saves resources to disk
static func zip_assets(input_assets : Array[Resource], filepath : String, zip_packer : ZIPPacker):
	#get all of the subresources which arent saved in the sql file
	#includes: shader code, image textures, mesh data
	var subresources : Array = []
	var total : Array[Resource] = []
	var filenames : PackedStringArray = []
	var error : int
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
	
	
	#save each subresource to disk
	#print("asset save start")
	i = 0
	while i < total.size():
		#print("iteration ", i, "-----------------------------------------------")
		var asset : Resource = total[i]
		var asset_name = AssetManager.get_name_of_asset(asset, false, true)
		#var debug_asset_saved : bool = false
		
		if asset is Texture2D:
			error = zip_packer.start_file(asset_name)
			if error != OK: push_error("starting image file in zip failed, error code: ", error, " error name: ", error_string(error))
			var image : Image = asset.get_image()
			error = zip_packer.write_file(image.save_png_to_buffer())
			if error != OK: push_error("writing image file to zip failed, error code: ", error, " error name: ", error_string(error))
			error = zip_packer.close_file()
			if error != OK: push_error("finalizing image file in zip failed, error code: ", error, " error name: ", error_string(error))
		#	debug_asset_saved = true
		elif asset is Shader:
			error = zip_packer.start_file(asset_name)
			if error != OK: push_error("starting shader file in zip failed, error code: ", error, " error name: ", error_string(error))
			error = zip_packer.write_file(asset.code.to_utf8_buffer())
			if error != OK: push_error("writing shader file to zip failed, error code: ", error, " error name: ", error_string(error))
			error = zip_packer.close_file()
			if error != OK: push_error("finalizing shader file in zip failed, error code: ", error, " error name: ", error_string(error))
		#	debug_asset_saved = true
		elif asset is Mesh:
			"TODO"#implement obj loading
			error = ResourceSaver.save(asset, filepath + asset_name)
			error = zip_packer.start_file(asset_name)
			error = zip_packer.write_file(FileAccess.get_file_as_bytes(filepath + asset_name))
			error = zip_packer.close_file()
			error = DirAccess.remove_absolute(filepath + asset_name)
		#	debug_asset_saved = true
		else:
			push_error("unimplemented asset type: " + str(asset))
		
		#if debug_asset_saved:
		#	print("asset saved:     ", asset)
		#else:
		#	print("asset not saved: ", asset)
		
		i = i + 1


#loads resources from disk
"TODO"#consider adding automated renaming function to assetmanager to further prevent name collisions
#using uuids but shortened to like 5 numbers
static func unzip_assets(zip_reader : ZIPReader, filepath : String, filename : String):
	#serialized data file will be stored here
	var file : PackedStringArray = []
	#names of files contained in save
	var file_names : PackedStringArray = []
	
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
		#subresource already available
		if not load_subresource:
			i = i + 1
			continue
		#otherwise, load subresource
		
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
			AssetManager.register_asset(image_texture)
	#shader code
		elif extension == "gdshader":
			var data_bytes : PackedByteArray = zip_reader.read_file(file_name)
			var shader_result : Shader = Shader.new()
			shader_result.code = data_bytes.get_string_from_utf8()
			shader_result.resource_path = filepath + file_name
			
			AssetManager.register_asset(shader_result)
		else:
			push_error("unimplemented filetype: ", extension)
		
		i = i + 1


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

#utility functions -------------------------------------------------------------
static func material_property_serialize(parameter, property : Dictionary):
	const l_bracket : String = "["
	const r_bracket : String = "]"
	if parameter is Texture2D:
		return [AssetManager.get_name_of_asset(parameter, false, true)]
	elif parameter is Material:
		push_error("recursive use of materials is not supported")
		return [""]
	elif parameter is String:
		return [parameter]
	elif parameter is float or parameter is int:
		return [str(parameter)]
	elif parameter is bool:
		if parameter:
			return ["t"]
		else:
			return ["f"]
	elif parameter is Vector3:
		return [l_bracket + str(parameter.x), str(parameter.y), str(parameter.z) + r_bracket]
	elif parameter is Vector4:
		return [l_bracket + str(parameter.w), str(parameter.x), str(parameter.y), str(parameter.z) + r_bracket]
	elif parameter is Color:
		return [l_bracket + str(parameter.r8), str(parameter.g8), str(parameter.b8), str(parameter.a8) + r_bracket]
	#if parameter is null, infer type from dictionary
	elif parameter == null and property.type == TYPE_VECTOR3:
		return [l_bracket,"",r_bracket]
	elif parameter == null and property.type == TYPE_VECTOR4 or property.type == TYPE_COLOR:
		return [l_bracket,"","",r_bracket]
	elif parameter == null:
		return [""]
	else:
		push_error("unimplemented type: ", property.hint_string, " ", property)
		return


static func material_property_deserialize(csv_values : PackedStringArray, parameter : Dictionary, i_line : int):
	const l_bracket : String = "["
	const r_bracket : String = "]"
	if parameter.type == TYPE_OBJECT and parameter.hint_string == "Material":
		push_error("recursive usage of materials not supported")
		return
	elif parameter.type == TYPE_OBJECT and parameter.hint_string == "Texture2D":
		#check if this subresource is reused by any other material
		var image_texture : ImageTexture = AssetManager.get_asset_by_name(AssetManager.normalize_asset_name(csv_values[i_line], false))
		
		#if image texture still hasnt loaded, abort
		if image_texture == null:
			push_error("image texture loading failure: ", csv_values[i_line], ", at line index: ", i_line, ", at property: ", parameter)
			return
		
		return image_texture
#load bool
	elif parameter.type == TYPE_BOOL:
		if csv_values[i_line] == "t":
			return true
		if csv_values[i_line] == "f":
			return false
		else:
			push_error("unexpected value: ", csv_values[i_line], ", at property: ", parameter, ", only t (true) or f (false) allowed.")
#load int
	elif parameter.type == TYPE_INT:
		return int(csv_values[i_line])
#load float
	elif parameter.type == TYPE_FLOAT:
		return float(csv_values[i_line])
#load string
	elif parameter.type == TYPE_STRING:
		return csv_values[i_line]
#load vector3
	elif parameter.type == TYPE_VECTOR3:
		if not csv_values[i_line].begins_with(l_bracket) or not csv_values[i_line + 2].ends_with(r_bracket):
			push_error("malformed csv at item: ", i_line, ", aborting deserialization.")
			return
		return Vector3(float(csv_values[i_line].trim_prefix(l_bracket)), float(csv_values[i_line + 1]), float(csv_values[i_line + 2].trim_suffix(r_bracket)))
		#needs to be incremented by 2, the x y z are stored as separate floats
		#i_line = i_line + 2
#load vector4
	elif parameter.type == TYPE_VECTOR4:
		if not csv_values[i_line].begins_with(l_bracket) or not csv_values[i_line + 3].ends_with(r_bracket):
			push_error("malformed csv at item: ", i_line, ", aborting deserialization.")
			return
		return Vector4(float(csv_values[i_line].trim_prefix(l_bracket)), float(csv_values[i_line + 1]), float(csv_values[i_line + 2]), float(csv_values[i_line + 3].trim_suffix(r_bracket)))
		#needs to be incremented by 3, the x y z w are stored as separate floats
		#i_line = i_line + 3
#load color
	elif parameter.type == TYPE_COLOR:
		if not csv_values[i_line].begins_with(l_bracket) or not csv_values[i_line + 3].ends_with(r_bracket):
			push_error("malformed csv at item: ", i_line, ", aborting deserialization.")
			return
		return Color.from_rgba8(int(csv_values[i_line].trim_prefix(l_bracket)), int(csv_values[i_line + 1]), int(csv_values[i_line + 2]), int(csv_values[i_line + 3].trim_suffix(r_bracket)))
		#needs to be incremented by 3, the r g b a are stored as separate ints
		#i_line = i_line + 3
	else:
		push_error("unimplemented type: ", parameter.hint_string, ", ", parameter)
		return


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
"TODO"#write test
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
