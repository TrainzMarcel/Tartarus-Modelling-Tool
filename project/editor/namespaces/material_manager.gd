@tool
extends RefCounted
class_name MaterialManager
#manages all the material + color combinations


#materials with color 0,0,0
static var name_to_base_material_map : Dictionary = {}

#materials with other colors
#dependent on base material being registered first
static var name_to_combo_material_map : Dictionary = {}

static var l_debug : Label

#utility function: ensures keys stay consistent
static func get_material_name(mat : Material, color : Color = Color.WHITE):
	if mat == null:
		return
	
	var base_name : String
	if mat.resource_path == "":
		base_name = mat.resource_name
	else:
		base_name = mat.resource_path.rsplit("/", true, 1)[-1].rsplit(".", true, 1)[0]
	
	
	if color == Color.WHITE:
		return StringName(base_name)
	else:
		return StringName(base_name + "," + color.to_html(true))


static func get_material_name_from_res_name(mat : Material, color : Color = Color.WHITE):
	if mat == null:
		return
	
	var base_name : String = mat.resource_name.rsplit("/", true, 1)[-1].rsplit(".", true, 1)[0]
	if color == Color.WHITE:
		return StringName(base_name)
	else:
		return StringName(base_name + "," + color.to_html(true))


#if combo not available, create new and register, if base material not available, return null
static func get_material(mat : Material, color : Color = Color.WHITE):
	if mat == null:
		return
	
	if color == Color.WHITE:
		return name_to_base_material_map.get(get_material_name(mat))
	else:
		
		var name : StringName = get_material_name(mat, color)
		var index = name_to_combo_material_map.get(name)
		if index != null:
			return index
		#combo wasnt found, check if base material exists
		else:
			index = name_to_base_material_map.get(get_material_name(mat))
			if index != null:
				var result = recolor_material(index, color)
				register_material(result, color)
				return result
			else:
				return null


#management methods
static func register_material(mat : Material, color : Color = Color.WHITE):
	#add if material exists, otherwise do nothing
	var base_name : StringName = get_material_name(mat)
	var name : StringName = get_material_name(mat, color)
	
	#case: registering new materials which havent been named yet
	if mat.resource_name == "":
		mat.resource_name = get_material_name(mat)
	
	
	#first check if base material already exists
	var index = name_to_base_material_map.get(base_name)
	if index == null:
		name_to_base_material_map[base_name] = mat
	
	if color != Color.WHITE:
		index = name_to_combo_material_map.get(name)
		if index == null:
			name_to_combo_material_map[name] = recolor_material(mat, color)
	
	#print("|registered " + name + "\n|" + mat.resource_path)
	#if mat.resource_path == "":
	#	print("what the fuck")
	#	print(mat)
	#	print(color)
	#print(mat.resource_name.rsplit("/", true, 1)[-1].rsplit(".", true, 1)[0])
	#l_debug.text = str(name_to_combo_material_map) + "\n-------------------MAOW\n" + str(name_to_base_material_map)


static func unregister_material(mat : Material, color : Color = Color.WHITE):
	#remove if material exists, otherwise do nothing
	#if base material is removed, remove all the combo materials too
	var base_name : StringName = get_material_name(mat)
	var name : StringName = get_material_name(mat, color)
	
	#remove base material if possible and all color combinations using it
	if color == Color.WHITE:
		var index = name_to_base_material_map.get(base_name)
		if index != null:
			name_to_base_material_map.erase(base_name)
			
			#erase dependencies
			for key in name_to_combo_material_map.keys():
				if key.get_slice(",", 0) == base_name:
					name_to_combo_material_map.erase(key)
	
	
	#remove just the color combination if it exists
	elif color != Color.WHITE:
		var index = name_to_combo_material_map.get(name)
		if index != null:
			name_to_combo_material_map.erase(name)


static func refresh_all_storage(all_existing_materials : Array[Material]):
	#clear all
	name_to_base_material_map = {}
	name_to_combo_material_map = {}
	
	for i in all_existing_materials:
		if i is ShaderMaterial:
			register_material(i, i.get_shader_parameter("color"))
		elif i is StandardMaterial3D:
			register_material(i, i.albedo_color)


static func recolor_material(mat : Material, color : Color):
	var separate : Material = mat.duplicate()
	separate.resource_name = mat.resource_name
	if mat is ShaderMaterial:
		separate.set_shader_parameter("color", color)
	elif mat is StandardMaterial3D:
		separate.albedo_color = color
	return separate


"TODO"#tool script
static func file_save_material():
	#if is editor hint()
	return


static func file_load_material():
	return


static func refresh_file_storage():
	return
