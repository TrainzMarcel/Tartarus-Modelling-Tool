extends RefCounted
class_name AssetManager
#formerly materialmanager, manages all 3d modelling related assets (not any ui assets)
"TODO"#this things api has become convoluted with duplicated code in some places
#rework the api and plan out specific pipelines or ways for the functions to be combined


#the central asset storage/tracker
static var name_to_asset_map : Dictionary = {}

#utility function: ensures keys stay consistent
static func get_name_of_asset(asset : Resource, include_color : bool = true, add_file_ending : bool = false):
	if asset == null:
		return
	
	var base_name : String
	if asset.resource_path == "":
		base_name = normalize_asset_name(asset.resource_name, add_file_ending)
	else:
		base_name = normalize_asset_name(asset.resource_path, add_file_ending)
	
	#add hex color to key to differentiate by color and to easily fetch a colored material if it exists already
	#i think i will not add the color to resource_name, only the key
	#so i can more easily find all instances of a material by looping through all asset dict values
	if base_name == "":
		push_error("asset " + str(asset) + " has no resource_name and no resource_path set")
	
	if (asset is BaseMaterial3D or asset is ShaderMaterial) and include_color:
		base_name = base_name + "," + str(get_material_color(asset).to_html(false))
	elif not include_color:
		base_name = base_name.get_slice(",", 0)
	
	return StringName(base_name)


#this function is meant to have the resource_path or resource_name passed in
#if custom color suffix is set, any original color suffix will be stripped away
#set keep_file_ending to false for key related things, set to true for saving to file
static func normalize_asset_name(name : String, keep_file_ending : bool, custom_color_suffix : Color = Color.WHITE):
	#strip filepath
	var result : PackedStringArray = name.rsplit("/", true, 1)
	name = result[result.size() - 1]
	
	#strip file ending
	if not keep_file_ending:
		name = name.get_slice(".", 0)
	
	if custom_color_suffix != Color.WHITE:
		#strip color suffix if there is one
		name = name.get_slice(",", 0)
		#add the custom color
		name = name + "," + str(custom_color_suffix.to_html(false))
	else:
		#simply strip color suffix anyway if this is set to no color
		name = name.get_slice(",", 0)
	
	
	if name == "":
		push_error("invalid (empty) asset name")
	
	return name


static func get_asset(asset : Resource):
	if asset == null:
		return
	return name_to_asset_map.get(get_name_of_asset(asset))


#this function takes both string and stringname
static func get_asset_by_name(asset_name, any_material_color : bool = true):
	var result : Resource = name_to_asset_map.get(StringName(asset_name))
	if result != null or not any_material_color:
		return result
	
	#special case: materials include their color in their key but not their resource name
	asset_name = normalize_asset_name(asset_name, false)
	for i in name_to_asset_map.values():
		if i.resource_name == asset_name:
			return i


#custom function for the loading process
static func get_material_by_name_any_color(asset_name : String):
	for i in name_to_asset_map.keys():
		if i.get_slice(",", 0) == asset_name:
			return name_to_asset_map.get(i)


#required by DataUtils to save all the imagetextures used by materials among other subresources
static func get_subresources(asset : Resource, subresources : Array = []):
	#loop through all properties
	for property in asset.get_property_list():
		#skip non-persistent/internal properties
		if property.usage & PROPERTY_USAGE_STORAGE == 0:
			continue
		
		var parameter = asset.get(property.name)
		#check each parameter
		if parameter is Resource:
			if subresources.has(parameter):
				push_error("cyclic resource dependency!")
				return subresources
			#add every resource type parameter
			subresources.append(parameter)
			#get subresources for the parameter and add them back
			subresources.append_array(get_subresources(parameter, subresources))
	#finally return after the loop
	return subresources


#management methods
static func register_asset(asset : Resource):
	#add if asset exists, otherwise do nothing
	var base_name : StringName = get_name_of_asset(asset)
	
	#only register if asset already exists
	if name_to_asset_map.get(base_name) != null:
		#debug
		#debug_pretty_print()
		#push_warning("asset already exists: ", base_name)
		return
	
	#safety check
	if base_name == null or base_name == "":
		push_error("attempted to register asset with unnamed key, aborting")
		return
	
	#assets must be named in a standard way
	asset.resource_name = normalize_asset_name(base_name, false)
	
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
		
		var parameter = asset.get(property.name)
		if parameter is Resource:
			if asset_history.has(parameter):
				push_error("cyclic resource dependency!")
				return
			register_asset_with_subresources(parameter, asset_history)
	return


#probably will not be used
static func unregister_asset(asset : Resource):
	#remove if material exists, otherwise do nothing
	#if base material is removed, remove all the combo materials too
	var base_name : StringName = get_name_of_asset(asset)
	if base_name != null:
		name_to_asset_map.erase(base_name)


#run asset name through normalization first
static func is_asset_key_taken(asset_name : String):
	if name_to_asset_map.get(asset_name) != null:
		return true
	return false


static func refresh_all_storage(all_existing_assets : Array):
	#clear all
	name_to_asset_map = {}
	
	for i in all_existing_assets:
		if i is Resource:
			register_asset(i)


static func recolor_material(mat : Material, color : Color, automatic_register : bool):
	#first search if this material already exists
	var separate : Material = get_asset_by_name(normalize_asset_name(get_name_of_asset(mat), false, color), false)
	if separate != null:
		return separate
	
	#otherwise recolor this material
	separate = mat.duplicate()
	#set name to original material without any color
	separate.resource_name = get_name_of_asset(mat, false)
	
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
		var attempt = mat.get_shader_parameter("color")
		if attempt == null:
			return Color.WHITE
		return attempt
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
