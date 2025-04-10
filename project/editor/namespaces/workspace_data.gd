extends RefCounted
class_name WorkspaceData

"TODO"#eventually put filepath constants in here or in a dictionary in here

#currently selected palettes in the editor
static var selected_color_palette : ColorPalette
static var selected_material_palette : MaterialPalette
static var selected_part_type_palette : PartTypePalette

#arrays of palettes used in the model
static var used_color_palettes_array : Array[ColorPalette]
static var used_material_palette_array : Array[MaterialPalette]
static var used_part_type_palette_array : Array[PartTypePalette]

#arrays of all palettes available to select
static var available_color_palette_array : Array[ColorPalette]
static var available_material_palette_array : Array[MaterialPalette]
static var available_part_type_palette_array : Array[PartTypePalette]

#default
static var default_color : Color = Color.WHITE
static var default_material : StandardMaterial3D = StandardMaterial3D.new()
static var default_mesh : Mesh = BoxMesh.new()

#classes responsible for saving and loading data
class Model:
	var uuid : String
	var name : String
	var part_array : Array[Part]
	#on saving, AUTOMATICALLY detect which palettes were used in the model
	var color_palette_array : Array[ColorPalette]
	var material_palette_array : Array[MaterialPalette]
	var part_type_palette_array : Array[PartTypePalette]

class ColorPalette:
	var uuid : String
	var name : String
	#parallel arrays
	var color_array : Array[Color]
	var color_name_array : Array[String]

class MaterialPalette:
	var uuid : String
	var name : String
	#parallel arrays
	var material_array : Array[ShaderMaterial]
	var material_name_array : Array[String]

class PartTypePalette:
	var uuid : String
	var name : String
	#parallel arrays
	var mesh_array : Array[Mesh]
	var mesh_name_array : Array[String]


#returns null if reference doesnt exist
static func get_index_from_reference(reference : Object, input_array : Array):
	var i : int = 0
	while i < input_array.size():
		if input_array[i] == reference:
			return i
		i = i + 1
	#just to be explicit
	return null


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

#todo make data pairs telling a loading function
#what columns come after the csv section headers (::PART::, ::COLOR::,..)

#load file and turn it into objects
static func load_data_from_tmv():
	
	
	
	
	
	pass

#take objects in workspace and turn them into a file
static func save_data_to_tmv(filename : String, path : String, is_palette_file : bool = true, workspace : Node = null):
	#save model from parts in workspace node, generate uuid, add name
	var part_array : Array[Part]
	var workspace_node_array : Array[Node] = workspace.get_children()
	
	#palettes used in this model will get added at the top of the save file to reference indices from
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
	
	#save color palette from used color palette
	#save material palette from used material palette
	#save part type palette from used part type palette
	
	
	pass


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
			color_name_array.append(data[0])
			color_array.append(Color8(int(data[1]), int(data[2]), int(data[3])))
		i = i + 1
	
	var r_dict : Dictionary = {}
	r_dict.color_array = color_array
	r_dict.color_name_array = color_name_array
	return r_dict

"TODO"#add config read function, add material read function, add part model read function
"TODO"#also add all the filepaths in here
