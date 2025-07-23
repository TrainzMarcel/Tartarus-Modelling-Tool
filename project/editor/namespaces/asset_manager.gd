extends RefCounted
class_name AssetManager
#formerly materialmanager, manages all 3d modelling related assets (not any ui assets)


#the central asset storage/tracker
static var name_to_asset_map : Dictionary = {}
static var debug_called : int = 0

#utility function: ensures keys stay consistent
static func get_asset_name(asset : Resource, include_color : bool = true):
	if asset == null:
		return
	
	var base_name : String
	if asset.resource_path == "":
		base_name = normalize_asset_name(asset.resource_name)
	else:
		base_name = normalize_asset_name(asset.resource_path)
	
	#add hex color to key to differentiate by color and to easily fetch a colored material if it exists already
	#i think i will not add the color to resource_name, only the key
	#so i can more easily find all instances of a material by looping through all asset dict values
	if base_name == "":
		push_error("get_asset_name(): asset added to database without resource_name set")
	
	if asset is BaseMaterial3D or asset is ShaderMaterial and include_color:
		base_name = base_name + "," + str(get_material_color(asset).to_html(false))
	
	
	return StringName(base_name)

"TODO"#make this less hacky and ugly
#this function is meant to have the resource_path or resource_name passed in
static func normalize_asset_name(name):
	return name.rsplit("/", true, 1)[-1].rsplit(",", true, 1)[0]

static func get_material_name_with_color(mat, color : Color):
	return get_asset_name(mat, false) + "," + str(color.to_html(false))


static func get_asset(asset : Resource):
	if asset == null:
		return
	return name_to_asset_map.get(get_asset_name(asset))


#this function takes both string and stringname
static func get_asset_by_name(asset_name):
	var result : Resource = name_to_asset_map.get(StringName(asset_name))
	if result != null:
		return result
	
	#special case: materials include their color in their key but not their resource name
	asset_name = normalize_asset_name(asset_name)
	for i in name_to_asset_map.values():
		if i.resource_name == asset_name:
			return i


#management methods
static func register_asset(asset : Resource):
	#add if material exists, otherwise do nothing
	var base_name : StringName = get_asset_name(asset)
	
	
	#only register if asset already exists
	if name_to_asset_map.get(base_name) != null:
		#debug
		#debug_pretty_print()
		#push_warning("asset already exists: ", base_name)
		return
	#assets must be named in a standard way
	asset.resource_name = base_name
	
	#register the asset
	name_to_asset_map[base_name] = asset


#recursive wrapper for register_asset()
#guards against cyclic dependencies
static func register_asset_with_subresources(asset : Resource, asset_history : Array = []):
	register_asset(asset)
	asset_history.append(asset)
	for property in asset.get_property_list():
		#skip non-persistent/internal properties
		if property.usage & PROPERTY_USAGE_STORAGE == 0:
			continue
		
		var param = asset.get(property.name)
		if param is Resource:
			if asset_history.has(param):
				push_error("cyclic resource dependency!")
				return
			register_asset_with_subresources(param, asset_history)
	return


#probably will not be used
static func unregister_asset(asset : Resource):
	#remove if material exists, otherwise do nothing
	#if base material is removed, remove all the combo materials too
	var base_name : StringName = get_asset_name(asset)
	if base_name != null:
		name_to_asset_map.erase(base_name)


static func refresh_all_storage(all_existing_assets : Array):
	#clear all
	name_to_asset_map = {}
	
	for i in all_existing_assets:
		if i is Resource:
			register_asset(i)


static func recolor_material(mat : Material, color : Color, automatic_register : bool):
	#first search if this material already exists
	var separate : Material = get_asset_by_name(get_material_name_with_color(mat, color))
	if separate != null:
		return separate
	
	separate = mat.duplicate()
	#set name to original material without any color
	separate.resource_name = get_asset_name(mat, false)
	
	if mat is ShaderMaterial:
		separate.set_shader_parameter("color", color)
	elif mat is BaseMaterial3D:
		separate.albedo_color = color
	
	if automatic_register:
		#color is added to name in here anyway
		register_asset(separate)
	
	return separate


static func get_material_color(mat : Material):
	if mat is ShaderMaterial:
		return mat.get_shader_parameter("color")
	elif mat is BaseMaterial3D:
		return mat.albedo_color


static func debug_pretty_print():
	var materials = name_to_asset_map.keys().filter(func(input): return name_to_asset_map[input] is Material)
	materials.sort()
	var meshes = name_to_asset_map.keys().filter(func(input): return name_to_asset_map[input] is Mesh)
	meshes.sort()
	var others = name_to_asset_map.keys().filter(func(input): return not name_to_asset_map[input] is Material and not name_to_asset_map[input] is Mesh)
	others.sort()
	var len0 = 0
	
	for i in name_to_asset_map.keys():
		len0 = max(str(name_to_asset_map[i]).length(), len0)
	len0 = len0 + 1
	
	debug_called = debug_called + 1
	print("debug_called ", debug_called)
	
	print("DATABASE DUMP")
	if materials.size() > 0:
		print("registered materials")
		print("-----------------------------------------------------------------")
		print("value".rpad(len0) + " | key")
		materials.map(func(input):
			print(str(name_to_asset_map[input]).rpad(len0)," | ", input)
			)
		print()
	
	if meshes.size() > 0:
		print("registered meshes")
		print("value".rpad(len0) + " | key")
		print("-----------------------------------------------------------------")
		meshes.map(func(input):
			print(str(name_to_asset_map[input]).rpad(len0)," | ", input)
			)
		print()
	
	if others.size() > 0:
		print("other registered assets")
		print("value".rpad(len0) + " | key")
		print("-----------------------------------------------------------------")
		others.map(func(input):
			print(str(name_to_asset_map[input]).rpad(len0)," | ", input)
			)
		print()

"TODO"#tool script
#keep for future use in import plugin
#for managing and automatically sharing materials in godot project
#static func file_save_material():
#	#if is editor hint()
#	return


#static func file_load_material():
#	return


#static func refresh_file_storage():
#	return

