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
enum DataType {t_integer, t_float, t_string, t_color}

#section headers in an attempt to make functions more flexible
const section_header_dict : Dictionary = {
	color_palette = "::COLORPALETTE::",
	material_palette = "::MATERIALPALETTE::",
	part_type_palette = "::PARTTYPEPALETTE::",
	model = "::MODEL::"
}


#tell functions how to load and save each section header
class DataLoadInstruction:
	var section_header : String
	#object to move file data into or out of
	#nvm
	#var data_object : Object
	
	#line relative to last section header
	var line : int = 0
	#these are the condition for which lines to trigger which loading routines
	#an example would be [line == 1, line > 1]
	#to have index 0 for when the line == 1 and index 1 for when the line is greater than 1
	var line_instruction : Array[bool]
	
	#stringname of properties to set and get
	#if a property is of type array, use .append instead of set()
	var line_data : Array[Array]
	# = [["uuid", "name", "description"], ["color","color_name"]]
	
	#color should automatically know that it uses 3 columns instead of 1
	#DataType.Mesh or .Material should automatically know to load a resource instead
	#(resource loading should be done in its own function)
	#[[DataType.t_string, DataType.t_string, DataType.String], [DataType.Color, DataType.String]]
	var line_data_type : Array[Array]
	
	
	

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


"TODO"
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
	#return (local? absolute?) file names

static func unbundle_tmv():
	pass

static func load_data_file(file_path : String):
	#unbundle_tmv()
	#for i in returned file names
	#i.get_file_as_lines.split("\n")
		#for j in lines:
			
			
			
			
	#graow
	#GRAOW
	
	return#return above classes as dict

#take objects in workspace and turn them into a file
static func save_data_file(file_path : String, file_as_string_array : PackedStringArray):
	pass

static func data_to_tmv_line(data : Array):
	return#return packedstringarray

static func validate_section_header(line : String):
	return section_header_dict.values().has(line)

#this tells the program how to read every line after section header
static func tmv_line_to_data(existing_data, mode : String, line : String, delimiter : String, section_header_line : int, i : int):
	#start at the line after the section_header as mode needs to be set from outside
	var i_relative : int = i - section_header_line
	var data : PackedStringArray = line.split(delimiter)
	var new_data : Object
	if mode == section_header_dict.color_palette:
		#read second header, construct class
		if i_relative == 1:
			new_data = ColorPalette.new()
			new_data.uuid = data[0]
			new_data.name = data[1]
			new_data.description = data[2]
		elif i_relative > 1 and existing_data is ColorPalette:
			var color : Color = Color()
			color.r8 = int(data[0])
			color.g8 = int(data[1])
			color.b8 = int(data[2])
			existing_data.color_array.append(color)
			existing_data.color_name_array.append(data[3])
	elif mode == section_header_dict.material_palette:
		if i_relative == 1:
			new_data = MaterialPalette.new()
			new_data.uuid = data[0]
			new_data.name = data[1]
			new_data.description = data[2]
		elif i_relative > 1 and existing_data is MaterialPalette:
			
			"TODO"#save data to see if this approach works and then read it in
			#see: Shader.get_shader_uniform_list()
			existing_data.material_array.append()#data[0])
			existing_data.material_name_array.append(data[1])
			
			"TODO"#figure this process out for meshes
			#var image = Image.load_from_file("res://square.png")
			#$TextureRect.texture = ImageTexture.create_from_image(image)
			
	elif mode == section_header_dict.part_type_palette:
		if i_relative == 1:
			new_data = PartTypePalette.new()
			new_data.name = data[1]
			new_data.description = data[2]
			
	elif mode == section_header_dict.model:
		if i_relative == 1:
			new_data = Model.new()
		
		pass
	return new_data
	#or possibly an array of data which can be assigned to a class based on the last section header?


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
