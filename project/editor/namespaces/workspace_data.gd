extends RefCounted
class_name WorkspaceData

"TODO"#eventually put filepath constants in here or in a dictionary in here
"TODO"#make data pairs telling a loading function
#what columns come after the csv section headers (::PART::, ::COLOR::,..)

#currently selected palettes in the editor
#make the setters into ui events to reload x panel uis
#or manually call a function after setting these
static var selected_color_palette : ColorPalette
static var selected_material_palette : MaterialPalette
static var selected_part_type_palette : PartTypePalette

#arrays of all palettes available to select
static var available_color_palette_array : Array[ColorPalette]
static var available_material_palette_array : Array[MaterialPalette]
static var available_part_type_palette_array : Array[PartTypePalette]

#defaults for error cases
static var default_color : Color = Color.WHITE
static var default_material : StandardMaterial3D = StandardMaterial3D.new()
static var default_mesh : Mesh = BoxMesh.new()

#used to tell functions what datatype to convert a string to (see data_to_csv_line())
enum DataType {t_integer, t_float, t_string}

#section headers in an attempt to make functions more flexible
const section_header_dict : Dictionary = {
	color_palette = "::COLORPALETTE::",
	material_palette = "::MATERIALPALETTE::",
	part_type_palette = "::PARTTYPEPALETTE::",
	model = "::MODEL::"
}





#classes responsible for storing data
class Model:
	var uuid : String
	var name : String
	var description : String
	var part_count : int
	#on saving, AUTOMATICALLY detect which palettes were used in the model
	#(by the parts references to which palettes were used in it)
	var color_palette_array : Array[ColorPalette]
	var material_palette_array : Array[MaterialPalette]
	var part_type_palette_array : Array[PartTypePalette]
	var part_array : Array[Part]


class ColorPalette:
	var uuid : String
	var name : String
	var description : String
	#parallel arrays
	var color_array : Array[Color]
	var color_name_array : Array[String]


class MaterialPalette:
	var uuid : String
	var name : String
	var description : String
	#parallel arrays
	var material_array : Array[BaseMaterial3D]
	var material_name_array : Array[String]


class PartTypePalette:
	var uuid : String
	var name : String
	var description : String
	#parallel arrays
	var mesh_array : Array[Mesh]
	var mesh_name_array : Array[String]
	var collider_type_array : Array[int]


#returns null if no match
static func get_index_according_to_uuid(input_uuid : String, input_array : Array):
	var i : int = 0
	while i < input_array.size():
		if input_array[i].uuid == input_uuid:
			return i
		i = i + 1
	return null


#returns null if invalid index
static func get_uuid_according_to_index(input_index : int, input_array : Array):
	if input_array.size() > input_index:
		return input_array[input_index].uuid
	return null


static func string_array_to_data(lines : PackedStringArray):
	var i : int = 0
	var mode : String
	var second_header : bool = false
	var terminate_data_block : bool = false
	var data : Object
	#configure return dictionary
	var r_dict : Dictionary = {}
	r_dict.color_palette_array = []
	r_dict.material_palette_array = []
	r_dict.part_type_palette_array = []
	r_dict.model = null
	
	#start to iterate through the lines
	while i < lines.size():
		var line : String = lines[i]
		var line_split : PackedStringArray = line.split(",")
		var is_header = line_split.size() == 1
		
	#terminate previous data block and add it to the return dictionary
		if is_header:
			if mode == section_header_dict.color_palette:
				r_dict.color_palette_array.append(data)
			elif mode == section_header_dict.material_palette:
				r_dict.material_palette_array.append(data)
			elif mode == section_header_dict.part_type_palette:
				r_dict.part_type_palette_array.append(data)
			elif mode == section_header_dict.model:
				r_dict.model = data
			
		#start next data block
			if line == section_header_dict.color_palette:
				mode = line
				second_header = true
				data = ColorPalette.new()
				continue
			elif line == section_header_dict.material_palette:
				mode = line
				second_header = true
				data = MaterialPalette.new()
				continue
			elif line == section_header_dict.part_type_palette:
				mode = line
				second_header = true
				data = PartTypePalette.new()
				continue
			elif line == section_header_dict.model:
				mode = line
				second_header = true
				data = Model.new()
		
		
		#fill data
	#color palette loading
		if mode == section_header_dict.color_palette:
			if second_header:
				data.uuid = line_split[0]
				data.name = line_split[1]
				data.description = line_split[2]
				second_header = false
			else:
				var color : Color = Color8(int(line_split[0]), int(line_split[1]), int(line_split[2]))
				data.color_array.append(color)
				data.color_name_array.append(line_split[3])
	#material palette loading
		elif mode == section_header_dict.material_palette:
			if second_header:
				data.uuid = line_split[0]
				data.name = line_split[1]
				data.description = line_split[2]
				second_header = false
			else:
				data.material_array.append(ResourceLoader.load(line_split[0]))
				data.material_name_array.append(line_split[1])
	#part type palette loading
		elif mode == section_header_dict.part_type_palette:
			if second_header:
				data.uuid = line_split[0]
				data.name = line_split[1]
				data.description = line_split[2]
				second_header = false
			else:
				data.mesh_array.append(ResourceLoader.load(line_split[0]))
				data.mesh_name_array.append(line_split[1])
				data.collider_type_array.append(int(line_split[2]))
		#model loading
		elif mode == section_header_dict.model:
			if second_header:
				data.uuid = line_split[0]
				data.name = line_split[1]
				data.description = line_split[2]
				data.part_count = int(line_split[3])
				second_header = false
			else:
				var new : Part = Part.new()
				new.part_scale.x = float(line_split[0])
				new.part_scale.y = float(line_split[1])
				new.part_scale.z = float(line_split[2])
				
				new.global_position.x = float(line_split[3])
				new.global_position.y = float(line_split[4])
				new.global_position.z = float(line_split[5])
				
				new.quaternion.w = float(line_split[6])
				new.quaternion.x = float(line_split[7])
				new.quaternion.y = float(line_split[8])
				new.quaternion.z = float(line_split[9])
				
			#assign color palette data
				new.used_color_palette = r_dict.color_palette_array[int(line_split[10])]
				new.part_color = new.used_color_palette.color_array[int(line_split[11])]
				
			#assign material palette data
				new.used_material_palette = r_dict.material_palette_array[int(line_split[12])]
				new.part_material = new.used_material_palette_array.material_array[int(line_split[13])]
				
			#assign part type palette data
				new.used_part_type_palette = r_dict.part_type_palette_array[int(line_split[14])]
				new.part_mesh_node.mesh = new.used_part_type_palette.mesh_array[int(line_split[15])]
				
				data.part_array.append(new)
		
		
		
		i = i + 1
	
	#finally, return the dictionary after the loop
	return r_dict

static func data_to_string_array(section_header : String, header_data : Array[String], data_blocks : Array[Array]):
	var lines : PackedStringArray = []
	var header_data_as_line : String = ""
	var data_blocks_as_lines : PackedStringArray = []
	var i : int = 0
	var j : int = 0
	
	while i < header_data.size():
		header_data_as_line = header_data_as_line + str(header_data[i])
		i = i + 1
		#if this is not the last unit of data, add a comma
		if i < header_data.size():
			header_data_as_line = header_data_as_line + ","
	
	while j < data_blocks.size():
		i = 0
		var line : String = ""
		while i < data_blocks[j].size():
			line = line + data_blocks[j][i]
			i = i + 1
			#if this is not the last unit of data, add a comma
			if i < header_data.size():
				line = line + ","
		data_blocks_as_lines.append(line)
		j = j + 1
	
	
	lines.append(section_header)
	lines.append(header_data_as_line)
	lines.append_array(data_blocks_as_lines)
	return lines

#unfinished
static func bundle_tmv(save_name : String, save_filepath : String, file_names : Array[String]):
	var writer : ZIPPacker = ZIPPacker.new()
	
	
	var err := writer.open(save_filepath + save_name)
	if err != OK:
		return err
	writer.start_file(save_name)
	for file in file_names:
		writer.write_file(FileAccess.get_file_as_bytes(save_filepath + save_name))
	writer.close_file()
	
	writer.close()

#unfinished
static func unbundle_tmv():
	
	pass

#load file and turn it into objects
static func load_data_from_tmv(file_path : String, is_palette_file : bool):
	
	var file = FileAccess.get_file_as_string(file_path)
	var lines = file.split("\\n")
	return string_array_to_data(lines)



static func get_used_palettes_from_workspace(workspace : Node):
	var workspace_node_array : Array[Node] = workspace.get_children()
	var used_color_palette_array : Array[ColorPalette] = []
	var used_material_palette_array : Array[MaterialPalette] = []
	var used_part_type_palette_array : Array[PartTypePalette] = []
#iterate all parts and check which palettes were used
	var i : int = 0
	while i < workspace_node_array.size():
		if workspace_node_array[i] is Part:
			#if any "used palette" variables are null, just set default value
			var part : Part = workspace_node_array[i]
			
			if not used_color_palette_array.has(part.used_color_palette):
				used_color_palette_array.append(part.used_color_palette)
			
			if not used_material_palette_array.has(part.used_material_palette):
				used_material_palette_array.append(part.used_material_palette)
			
			if not used_part_type_palette_array.has(part.used_part_type_palette):
				used_part_type_palette_array.append(part.used_part_type_palette)
		i = i + 1
	
	var r_dict : Dictionary = {}
	r_dict.used_color_palette_array = used_color_palette_array
	r_dict.used_material_palette_array = used_material_palette_array
	r_dict.used_part_type_palette_array = used_part_type_palette_array
	return r_dict



#take objects in workspace and turn them into a file
static func save_data_to_tmv(
	save_name : String,
	filepath : String,
	file_names : PackedStringArray,
	save_color_palette_array : Array[ColorPalette],
	save_material_palette_array : Array[MaterialPalette],
	save_part_type_palette_array : Array[PartTypePalette],
	save_model : Model
	):
	
#this will be data.csv
	var lines : PackedStringArray = []
#file_names keeps track of all references to bundle in the zip later
#that means all tres files and their and data.csv
	
	
	#embed the palettes used into the save file
	#for each color palette
	for j in save_color_palette_array:
		#unpack rgb into individual arrays
		var r_values : PackedInt32Array = j.color_array.map(func(color): return color.r8)
		var g_values : PackedInt32Array = j.color_array.map(func(color): return color.g8)
		var b_values : PackedInt32Array = j.color_array.map(func(color): return color.b8)
		lines.append_array(data_to_string_array(
			section_header_dict.color_palette, 
			[j.uuid, j.name, j.description], 
			[r_values, g_values, b_values, j.color_name_array]
			))
	
	for k in save_material_palette_array:
		var resource_path_array : PackedStringArray = k.material_array.map(func(material): return material.resource_path)
		file_names.append_array(resource_path_array)
		lines.append_array(data_to_string_array(
			section_header_dict.material_palette,
			[k.uuid, k.name, k.description],
			[resource_path_array, k.material_name_array]
		))
	
	for l in save_part_type_palette_array:
		var resource_path_array : PackedStringArray = l.mesh_array.map(func(mesh): return mesh.resource_path)
		file_names.append_array(resource_path_array)
		lines.append_array(data_to_string_array(
			section_header_dict.part_type_palette,
			[l.uuid, l.name, l.description],
			[resource_path_array, l.mesh_name_array, l.collider_type]
			))
	
	#if saving a model
	#pack EVERYTHING
	if save_model != null:
		var size_x : PackedStringArray = save_model.part_array.map(func(part): return str(part.part_scale.x))
		var size_y : PackedStringArray = save_model.part_array.map(func(part): return str(part.part_scale.y))
		var size_z : PackedStringArray = save_model.part_array.map(func(part): return str(part.part_scale.z))
		var pos_x : PackedStringArray = save_model.part_array.map(func(part): return str(part.global_position.x))
		var pos_y : PackedStringArray = save_model.part_array.map(func(part): return str(part.global_position.y))
		var pos_z : PackedStringArray = save_model.part_array.map(func(part): return str(part.global_position.z))
		var quat_w : PackedStringArray = save_model.part_array.map(func(part): return str(part.quaternion.w))
		var quat_x : PackedStringArray = save_model.part_array.map(func(part): return str(part.quaternion.x))
		var quat_y : PackedStringArray = save_model.part_array.map(func(part): return str(part.quaternion.y))
		var quat_z : PackedStringArray = save_model.part_array.map(func(part): return str(part.quaternion.z))
		var c_p_id : PackedStringArray = save_model.part_array.map(func(part):return str(save_color_palette_array.find(part.used_color_palette)))
		var c_id : PackedStringArray = save_model.part_array.map(func(part): return str(part.used_color_palette.color_array.find(part.part_color)))
		var m_p_id : PackedStringArray = save_model.part_array.map(func(part): return str(save_material_palette_array.find(part.used_material_palette)))
		var m_id : PackedStringArray = save_model.part_array.map(func(part): return str(part.used_material_palette.material_array.find(part.part_material)))
		var p_t_p_id : PackedStringArray = save_model.part_array.map(func(part): return str(save_part_type_palette_array.find(part.used_part_type_palette)))
		var p_t_id : PackedStringArray = save_model.part_array.map(func(part): return str(part.used_part_type_palette.mesh_array.find(part.part_mesh)))
		
		lines.append_array(data_to_string_array(
			section_header_dict.model,
			[str(UUID.v4()), save_model.name, save_model.description],
			[size_x, size_y, size_z, pos_x, pos_y, pos_z, quat_w, quat_x, quat_y, quat_z, c_p_id, c_id, m_p_id, m_id, p_t_p_id, p_t_id]
			
		))
	
	file_names.append(filepath + "data.csv")
	#create data.csv file
	var file = FileAccess.open(filepath + "data.csv", FileAccess.WRITE)
	for line in lines:
		file.store_line(line)
	file.close()
	
	return file_names


#old function
#read colors from file
static func read_colors_and_create_colors(file_as_string : String):
	var lines : PackedStringArray = file_as_string.split("\n")
	var color_array : Array[Color] = []
	var color_name_array : Array[String] = []
	var i : int = 0
	
	#read data
	#iterate through each line
	while i < lines.size():
		#get data in each line
		var data : PackedStringArray = lines[i].split(",")
		
		"DEBUG"
		if data[0] == "#":
			continue
		
		#strip spaces that come after commas
		for j in data:
			j.lstrip(" ")
		
		#configure arrays
		if data.size() == 4:
			color_name_array.append(data[3])
			color_array.append(Color8(int(data[0]), int(data[1]), int(data[2])))
		i = i + 1
	
	var r_dict : Dictionary = {}
	r_dict.color_array = color_array
	r_dict.color_name_array = color_name_array
	return r_dict

"TODO"#add config read function, add material read function, add part model read function
"TODO"#also add all the filepaths in here
