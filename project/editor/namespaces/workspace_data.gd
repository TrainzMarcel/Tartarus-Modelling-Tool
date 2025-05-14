extends RefCounted
class_name WorkspaceData

"TODO"#eventually put filepath constants in here or in a dictionary in here
"TODO"#make data pairs telling a loading function
#what columns come after the csv section headers (::PART::, ::COLOR::,..)

#on startup, load these palettes
const folder_startup_palettes : String = "user://palettes"

const folder_saved_models : String = "user://settings/"

const filepath_startup_palettes : String = ""

#currently selected palettes in the editor
#make the setters into ui events to reload x panel uis
#or manually call a function after setting these
static var equipped_color_palette : ColorPalette
static var equipped_material_palette : MaterialPalette
static var equipped_part_type_palette : PartTypePalette

#arrays of all palettes available to select
static var available_color_palette_array : Array[ColorPalette]
static var available_material_palette_array : Array[MaterialPalette]
static var available_part_type_palette_array : Array[PartTypePalette]

#defaults for error cases
static var default_color : Color = Color.WHITE
static var default_material : StandardMaterial3D = StandardMaterial3D.new()
static var default_mesh : Mesh = BoxMesh.new()

#used to tell functions what datatype to convert a string to (see data_to_csv_line())
#there is a datatype enum in globalscope but it doesnt include material mesh or part types
enum DataType {t_int, t_float, t_string, t_color, t_material, t_mesh, t_part}

#section headers in an attempt to make functions more flexible
const section_header_dict : Dictionary = {
	color_palette = "::COLORPALETTE::",
	material_palette = "::MATERIALPALETTE::",
	part_type_palette = "::PARTTYPEPALETTE::",
	model = "::MODEL::"
}

#instructions to load and save each data object
static var persist_instruction_array : Array[PersistInstruction] = [
	initialize_instruction(
		ColorPalette.new(),
		section_header_dict.color_palette,
		[WorkspaceData.is_equal, WorkspaceData.is_greater],
		[1, 1],
		[["uuid", "name", "description"], ["color_array", "color_name_array"]],
		[[DataType.t_string, DataType.t_string, DataType.t_string], [DataType.t_color, DataType.t_string]]
	),
	initialize_instruction(
		MaterialPalette.new(),
		section_header_dict.material_palette,
		[WorkspaceData.is_equal, WorkspaceData.is_greater],
		[1, 1],
		[["uuid", "name", "description"], ["material_array", "material_name_array"]],
		[[DataType.t_string, DataType.t_string, DataType.t_string], [DataType.t_material, DataType.t_string]]
	),
	initialize_instruction(
		PartTypePalette.new(),
		section_header_dict.part_type_palette,
		[WorkspaceData.is_equal, WorkspaceData.is_greater],
		[1, 1],
		[["uuid", "name", "description"], ["mesh_array", "mesh_name_array", "collider_type_array"]],
		[[DataType.t_string, DataType.t_string, DataType.t_string], [DataType.t_mesh, DataType.t_string, DataType.t_int]]
	),
	initialize_instruction(
		Model.new(),
		section_header_dict.model,
		[WorkspaceData.is_equal, WorkspaceData.is_greater],
		[1, 1],
		[["uuid", "name", "description", "part_count"], ["part_array"]],
		[[DataType.t_string, DataType.t_string, DataType.t_string, DataType.t_int], [DataType.t_part]]
	)
]

#tell functions how to load and save each section header
class PersistInstruction:
	var section_header : String
	
	#object type to move file data into (loading) or out of (saving)
	var data_object : Object
	
	#these are the condition for which lines to trigger which loading routines
	#an example would be [line == 1, line > 1]
	#to return index 0 for when the line == 1 and index 1 for when the line is greater than 1
	#MUST only return true or false
	var line_condition : Array[Callable]
	#second argument for each line instruction
	#also serves as number to subtract from line_relative when an array is being read from and saved
	#because the actual data starts at line 1 and so value[0] would be missed
	var line_condition_second_arg : Array[int]
	
	#stringname of properties to set and get
	#if a property is of type array, use .append instead of set()
	var line_data_name : Array[Array]
	# = [["uuid", "name", "description"], ["color","color_name"]]
	
	#color should automatically know that it uses 3 columns instead of 1
	#DataType.Mesh or .Material should automatically know to load a resource instead
	#(resource loading should be done in its own function)
	#[[DataType.t_string, DataType.t_string, DataType.String], [DataType.Color, DataType.String]]
	var line_data_type : Array[Array]

static func initialize_instruction(
	data_object : Object,
	section_header : String,
	line_condition : Array[Callable],
	line_condition_second_arg : Array[int],
	line_data_name : Array[Array],
	line_data_type : Array[Array]
	):
	
	var new : PersistInstruction = PersistInstruction.new()
	new.data_object = data_object
	new.section_header = section_header
	new.line_condition = line_condition
	new.line_condition_second_arg = line_condition_second_arg
	new.line_data_name = line_data_name
	new.line_data_type = line_data_type
	return new


#i have to make these operations into callables for class above
static func is_greater(a : int, b : int):
	return a > b

static func is_equal(a : int, b : int):
	return a == b

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


static func initialize():
	#var r_dict : Dictionary = WorkspaceData.load_data_from_tmv("res://editor/data_editor/default.tmvp")
	#WorkspaceData.available_color_palette_array.append_array(r_dict.color_palette_array)
	#WorkspaceData.available_material_palette_array.append_array(r_dict.material_palette_array)
	#WorkspaceData.available_part_type_palette_array.append_array(r_dict.part_type_palette_array)
	#WorkspaceData.selec
	
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


#feed correct instruction object according to section header
static func data_to_tmv_line(data_object : Object, line_relative : int, instruction : PersistInstruction, delimiter : String, extra_data : Dictionary):
	#select which instructions to use depending on the condition in line_instruction and line_
	var selected : int = get_index_of_line_instruction(instruction, line_relative)
	var line_output : PackedStringArray = []
	var i : int = 0
	var j : int = 0
	
	while i < instruction.line_data_name[selected].size():
		
		#get property from its name
		var property = data_object.get(instruction.line_data_name[line_relative][i])
		var property_get
		
		#get the property
		if property is Array:
			#find array index by subtracting line_relative by the second arg of the line condition
			#that way, greater_than(line_relative, 5) for example will also be subtracted by 5 if theres 5 lines of other data
			"CAUTION"#probably should make this its own array instead of using line_condition_second_arg
			property_get = property[line_relative - instruction.line_condition_second_arg[selected]]
		else:
			property_get = property
		
		#convert the property
		#do nothing
		if instruction.line_data_type[selected][i] == DataType.t_string:
			line_output.append(property_get)
		#leverage str()
		elif instruction.line_data_type[selected][i] == DataType.t_int or instruction.data_type == DataType.t_float:
			line_output.append(str(property_get))
		#leverage str() but over 3 columns/indices
		elif instruction.line_data_type[selected][i] == DataType.t_color:
			#skip 2 more indices because a color takes up 3 columns
			i = i + 2
			line_output.append(str(property_get.r))
			line_output.append(str(property_get.g))
			line_output.append(str(property_get.b))
		elif instruction.line_data_type[selected][i] == DataType.t_material:
			pass
			"TODO"#save material resource function
			#add the materials filenames to save folder and add the resource filename in here
		elif instruction.line_data_type[selected][i] == DataType.t_mesh:
			pass
			"TODO"#save mesh resource function
		elif instruction.line_data_type[selected][i] == DataType.t_part:
			#skip 15 more indices because a part takes up 16 columns
			i = i + 15
			line_output.append(str(property_get.part_scale.x))
			line_output.append(str(property_get.part_scale.y))
			line_output.append(str(property_get.part_scale.z))
			
			line_output.append(str(property_get.global_position.x))
			line_output.append(str(property_get.global_position.y))
			line_output.append(str(property_get.global_position.z))
			
			line_output.append(str(property_get.quaternion.w))
			line_output.append(str(property_get.quaternion.x))
			line_output.append(str(property_get.quaternion.y))
			line_output.append(str(property_get.quaternion.z))
			
			
			#create mappings to avoid using .find() 6 times when parsing a part
			extra_data = create_palette_mappings(extra_data)
			
			#write ids for used palettes and used assets in said palettes
			var prev_index : int = 0
			var index : int = 0
			
			#get index of used color palette
			index = extra_data.color_palette_array[extra_data.color_palette_mapping[property_get.used_color_palette]]
			line_output.append(str(index))
			prev_index = index
			index = extra_data.color_palette_array[prev_index].color_array[extra_data.color_palette_entry_mapping_array[property_get.part_color]]
			line_output.append(str(index))
			
			
			#get index of used material palette
			index = extra_data.material_palette_array[extra_data.material_palette_mapping[property_get.used_material_palette]]
			line_output.append(str(index))
			prev_index = index
			index = extra_data.material_palette_array[prev_index].material_array[extra_data.material_palette_entry_mapping_array[property_get.part_material]]
			line_output.append(str(index))
			
			
			#get index of used part palette
			index = extra_data.part_type_palette_array[extra_data.part_type_palette_mapping_array[property_get.used_part_type_palette]]
			line_output.append(str(index))
			prev_index = index
			index = extra_data.part_type_palette_array[prev_index].mesh_array[extra_data.part_type_palette_entry_mapping_array[property_get.part_mesh_node.mesh]]
		
		i = i + 1
	
	return delimiter.join(line_output)


#this tells the program how to read every line after section header
static func tmv_line_to_data(data_object : Object, line_relative : int, instruction : PersistInstruction, delimiter : String, line : String):
	#start at the line after the section_header as mode needs to be set from outside
	var data : PackedStringArray = line.split(delimiter)
	var i : int = 0
	
	
	
	#{t_int, t_float, t_string, t_color, t_material, t_mesh}
	if instruction.data_type == DataType.t_int or instruction.data_type == DataType.t_float:
		pass
	
	if instruction.data_type == DataType.t_string:
		pass
	
	while i < data.size():
		
		
		pass
		
		
	
	
	
	
	#duplicate object from instruction
	if data_object == null:
		data_object = ClassDB.instantiate(instruction.data_object.get_class())
	
	
	
	
	
	
	
	return data_object
	#or possibly an array of data which can be assigned to a class based on the last section header?


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
	#return file names (not paths)


static func unbundle_tmv():
	pass


#helper functions
static func validate_section_header(line : String):
	return section_header_dict.values().has(line)

static func get_index_of_line_instruction(instruction : PersistInstruction, line_relative : int):
	var i : int = 0
	while i < instruction.line_instruction.size():
		if instruction.line_instruction[line_relative].call(line_relative, instruction.line_instruction_second_arg[i]):
			return i
		i = i + 1


static func create_mapping(input_data : Array):
	var i : int = 0
	var map : Dictionary = {}
	
	while i < input_data.size():
		#reverse the keys with the values in input_data
		map[input_data[i]] = i
		i = i + 1
	
	return map


static func create_palette_mappings(input_dict : Dictionary):
	#assigning palette ids and asset ids
	#if input_dict doesnt have mappings, make them
	#mappings are used to convert references to ids faster
	if not input_dict.keys().has("color_palette_array"):
		#parallel arrays
		input_dict.color_palette_mapping = create_mapping(input_dict.color_palette_array)
		input_dict.color_entry_mapping_array = []
		for i in input_dict.color_palette_array:
			input_dict.color_entry_mapping_array.append(create_mapping(i.color_array))
	
	
	if not input_dict.keys().has("material_palette_array"):
		#parallel arrays
		input_dict.material_palette_mapping = create_mapping(input_dict.material_palette_array)
		input_dict.material_entry_mapping_array = []
		for j in input_dict.material_palette_array:
			input_dict.material_entry_mapping_array.append(create_mapping(j.material_array))
	
	
	if not input_dict.keys().has("part_type_palette_array"):
		#parallel arrays
		input_dict.part_type_palette_mapping = create_mapping(input_dict.part_type_palette_array)
		input_dict.part_type_entry_mapping_array = []
		for k in input_dict.part_type_palette_array:
			input_dict.part_type_entry_mapping_array.append(create_mapping(k.mesh_array))
	
	return input_dict


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


static func dispatch_instruction(section_header : String):
	for i in persist_instruction_array:
		if i.section_header == section_header:
			return i


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
