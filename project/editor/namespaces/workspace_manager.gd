extends RefCounted
class_name WorkspaceManager

#was meant to handle saving and loading but i dropped that for now
#now handles selection logic, selection box logic and undo redo logic

#dependencies
static var hover_selection_box : SelectionBox
static var workspace : Node

#bounding box of selected parts for positional snapping
static var selected_parts_abb : ABB = ABB.new()

#asset data
#gets set in on_color_selected
static var selected_color : Color
#static var button_color_mapping : Dictionary
#static var available_colors : Array[Color]
#gets set in on_material_selected
static var selected_material : Material
static var button_material_mapping : Dictionary
static var available_materials : Array[Material]
#gets set in on_part_type_selected
static var selected_part_type : Part
static var button_part_type_mapping : Dictionary
static var available_part_types : Array[Part]


#!!!selected_parts_array, offset_dragged_to_selected_array and selection_box_array are parallel arrays!!!
static var offset_abb_to_selected_array : Array[Vector3] = []
#offset from the dragged parts position to the raycast hit position
static var selection_box_array : Array[SelectionBox] = []
static var selected_parts_array : Array[Part] = []:
	set(val):
		selected_parts_array = val
		refresh_bounding_box()

#for copy pasting
static var parts_clipboard : Array[Part] = []

#vector pointing from ray_result.position to selected_parts_abb
static var drag_offset : Vector3


static func initialize(workspace : Node, hover_selection_box : SelectionBox):
	WorkspaceManager.workspace = workspace
	WorkspaceManager.hover_selection_box = hover_selection_box
	
	#colors are stored in color buttons (self_modulate) but im not sure if thats a good thing
	#get part types and materials from .tres files
	var file_list = DirAccess.get_files_at(FilePathRegistry.data_folder_material)
	var materials_list : Array[Material] = []
	
	for path in file_list:
		materials_list.append(ResourceLoader.load(FilePathRegistry.data_folder_material + path, "Material"))
	WorkspaceManager.available_materials = materials_list
	
	
	
	file_list = DirAccess.get_files_at(FilePathRegistry.data_folder_part)
	var parts_list : Array[Part] = []
	
	for path in file_list:
		var new : Part = Part.new()
		new.part_mesh_node.mesh = ResourceLoader.load(FilePathRegistry.data_folder_part + path, "Mesh")
		
		parts_list.append(new)
	
	#set default scale
	#cylinder
	parts_list[1].part_scale = Vector3(0.4, 0.8, 0.4)
	#sphere
	parts_list[2].part_scale = Vector3(0.8, 0.8, 0.8)
	
	WorkspaceManager.available_part_types = parts_list
	if available_part_types.size() > 0:
		selected_part_type = available_part_types[0]
	
	#var r_dict : Dictionary = WorkspaceManager.load_data_from_tmv("res://editor/data_editor/default.tmvp")
	#WorkspaceManager.available_color_palette_array.append_array(r_dict.color_palette_array)
	#WorkspaceManager.available_material_palette_array.append_array(r_dict.material_palette_array)
	#WorkspaceManager.available_part_type_palette_array.append_array(r_dict.part_type_palette_array)
	#WorkspaceManager.selec


#part functions-----------------------------------------------------------------
#only meant for spawning a part from the part spawn button
static func part_spawn(selected_part_type : Part):
	var new_part : Part = selected_part_type.copy()
	workspace.add_child(new_part)
	var ray_result = Main.raycast(Main.cam, Main.cam.global_position, -Main.cam.basis.z * Main.raycast_length, [], [1])
	if ray_result.is_empty():
		new_part.transform.origin = Main.cam.global_position + Main.part_spawn_distance * -Main.cam.basis.z
	else:
		new_part.transform.origin = ray_result.position
	return new_part


static func part_delete(hovered_part : Part):
	hovered_part.queue_free()


static func part_copy(part : Part):
	var new_part : Part = selected_part_type.duplicate()
	new_part.part_mesh_node = selected_part_type.part_mesh_node.duplicate()
	new_part.part_collider_node = selected_part_type.part_collider_node.duplicate()


static func refresh_bounding_box():
	if not Main.safety_check(selected_parts_array[0]):
		return
	selected_parts_abb = SnapUtils.calculate_extents(selected_parts_abb, selected_parts_array[0], selected_parts_array)
	#debug
	var d_input = {}
	d_input.transform = WorkspaceManager.selected_parts_abb.transform
	d_input.extents = WorkspaceManager.selected_parts_abb.extents
	HyperDebug.actions.abb_visualize.do(d_input)
	
	
	#refresh offset abb to selected array
	#this array is used for transforming the whole selection with the position of the abb
	WorkspaceManager.refresh_offset_abb_to_selected_array()


#selection functions------------------------------------------------------------
static func selection_remove_part(hovered_part):
	selection_box_delete_on_part(hovered_part)
	#erase the same index as hovered_part
	offset_abb_to_selected_array.remove_at(selected_parts_array.find(hovered_part))
	selected_parts_array.erase(hovered_part)


static func selection_add_part(hovered_part : Part, abb_orientation : Part):
	selected_parts_array.append(hovered_part)
	selection_box_instance_on_part(hovered_part)
	offset_abb_to_selected_array.append(hovered_part.transform.origin - abb_orientation.transform.origin)


static func selection_set_to_workspace():
	selection_clear()
	var workspace_parts = workspace.get_children().filter(func(part):
		return part is Part
		)
	
	for i in workspace_parts:
		selection_add_part(i, workspace_parts[0])


static func selection_set_to_part(hovered_part : Part, abb_orientation : Part):
	selected_parts_array = [hovered_part]
	offset_abb_to_selected_array = [hovered_part.global_position]
	selection_boxes_clear_all()
	selection_box_instance_on_part(hovered_part)


#for undo operations
#warning untested
static func selection_set_to_part_array(input : Array[Part], abb_orientation : Part):
	selection_clear()
	
	for part in input:
		selection_add_part(part, abb_orientation)


static func selection_clear():
	selected_parts_array.clear()
	selection_boxes_clear_all()
	offset_abb_to_selected_array.clear()


"TODO"#work on ctrl+key functions
#shouldnt be hard
static func selection_delete():
	for i in selected_parts_array:
		i.queue_free()
	selection_clear()


#untested
static func selection_copy():
	parts_clipboard.clear()
	for i in selected_parts_array:
		parts_clipboard.append(i.copy())


static func selection_paste():
	"TODO"#add status message bottom bar
	if not parts_clipboard.is_empty():
		selection_clear()
		for i in parts_clipboard:
			var copy : Part = i.copy()
			workspace.add_child(copy)
			selection_add_part(copy, copy)
		refresh_bounding_box()
		Main.set_transform_handle_root_position(Main.transform_handle_root, selected_parts_abb.transform, Main.local_transform_active, Main.selected_tool_handle_array)


static func selection_duplicate():
	parts_clipboard.clear()
	for i in selected_parts_array:
		var copy : Part = i.copy()
		workspace.add_child(copy)


#position only
static func selection_move(input_absolute : Vector3):
	selected_parts_abb.transform.origin = input_absolute
	Main.transform_handle_root.transform.origin = input_absolute
	var d_input = {}
	d_input.transform = selected_parts_abb.transform
	d_input.extents = selected_parts_abb.extents
	HyperDebug.actions.abb_visualize.do(d_input)
	
	var i : int = 0
	while i < selected_parts_array.size():
		selected_parts_array[i].transform.origin = selected_parts_abb.transform.origin + offset_abb_to_selected_array[i]
		selection_box_array[i].transform.origin = selected_parts_array[i].transform.origin
		i = i + 1
	#move transform handles with selection
	Main.set_transform_handle_root_position(Main.transform_handle_root, selected_parts_abb.transform, Main.local_transform_active, Main.selected_tool_handle_array)


#rotation only
"TODO"#parameterize everything for clarity and to prevent bugs
static func selection_rotate(rotated_basis : Basis, original_basis : Basis):#TODO , point_local : Vector3 = Vector3.ZERO):
	
	#calculate difference between original basis and new basis
	var difference : Basis = rotated_basis * original_basis.inverse()
	drag_offset = difference * drag_offset
	
	#rotate the offset_abb_to_selected_array vector by the difference between the
	#original basis and rotated basis
	var i : int = 0
	while i < selected_parts_array.size():
		#rotate offset_dragged_to_selected_array vector by the difference basis
		offset_abb_to_selected_array[i] = difference * offset_abb_to_selected_array[i]
		#move part to ray_result.position for easier pivoting
		if not Main.ray_result.is_empty():
			selected_parts_array[i].global_position = Main.ray_result.position
		else:
			selected_parts_array[i].global_position = selected_parts_abb.transform.origin
		
		
		#rotate this part
		selected_parts_array[i].basis = difference * selected_parts_array[i].basis
		
		#move it back out along the newly rotated offset_dragged_to_selected_array vector
		selected_parts_array[i].global_position = selected_parts_abb.transform.origin + offset_abb_to_selected_array[i]
		#copy transform
		selection_box_array[i].global_transform = selected_parts_array[i].global_transform
		i = i + 1
	
	#rotate abb
	selected_parts_abb.transform.basis = difference * selected_parts_abb.transform.basis
	
	#move transform handles with selection
	Main.set_transform_handle_root_position(Main.transform_handle_root, selected_parts_abb.transform, Main.local_transform_active, Main.selected_tool_handle_array)


#scale_absolute meaning it will set the scale of the selection bounding box to this value
#must call selection_move after this function due to the updated offset_abb_to_selected_array
"TODO"#OPTIMIZE OPTIMIZE OPTIMIZE
#https://www.reddit.com/r/godot/comments/187npcd/how_to_increase_performance/
#https://docs.godotengine.org/en/4.1/classes/class_renderingserver.html
#
static func selection_scale(scale_absolute : Vector3):
	#dont do anything if scale is the same
	if scale_absolute == selected_parts_abb.extents:
		return
	
	#scaling singular parts is easy
	if selected_parts_array.size() == 1:
		selected_parts_array[0].part_scale = scale_absolute
		selected_parts_abb.extents = scale_absolute
		selection_boxes_redraw_all()
		Main.set_transform_handle_root_position(Main.transform_handle_root, selected_parts_abb.transform, Main.local_transform_active, Main.selected_tool_handle_array)
		return
	
	
	#!!scalable_parts and local_scales are parallel arrays!!
	var scalable_parts : Array[Part]
	var local_scales : PackedVector3Array = []
	#!!selected_parts_array, offset_abb_to_selected_array and local_offsets are parallel arrays!!
	#offset_abb_to_selected_array is in global space
	var local_offsets : PackedVector3Array = []
	var inverse : Basis = selected_parts_abb.transform.basis.inverse()
	#shorthand
	var ext : Vector3 = selected_parts_abb.extents
	#loop
	var i : int = 0
	var j : int = 0
	
	
	
	#parts can only be scaled along their basis vectors
	#so only work on parts that are rectilinearly aligned with the bounding box
	scalable_parts = selected_parts_array.filter(func(part):
		return SnapUtils.part_rectilinear_alignment_check(selected_parts_abb.transform.basis, part.basis)
	)
	
	
	#first get the local scale of each scalable part
	for i_a in scalable_parts:
		var abb_basis = selected_parts_abb.transform.basis
		var p = i_a.basis
		var s = i_a.part_scale
		
		#world space scale vector
		var world_scale = p * s
		
		#bounding box local vector
		var diff_forward = abb_basis.inverse()
		var local_scale_abb = diff_forward * world_scale
		
		#set any negative components to not be negative
		local_scale_abb.x = abs(local_scale_abb.x)
		local_scale_abb.y = abs(local_scale_abb.y)
		local_scale_abb.z = abs(local_scale_abb.z)
		local_scales.append(local_scale_abb)
		i = i + 1
	
	#then get the local offsets to the bounding box of each selected part
	for i_b in offset_abb_to_selected_array:
		var new : Vector3 = i_b * selected_parts_abb.transform.basis
		local_offsets.append(new)
	
	
	#work on each dimension individually
	i = 0
	while i < 3:
		#if this dimension is already scaled correctly, go to next iteration
		if scale_absolute[i] == ext[i]:
			i = i + 1
			continue
		
		#only scale scalable parts
		#scale each scalable part in relation to bounding box
		j = 0
		while j < scalable_parts.size():
			#get relative scale from 0 to 1 depending on how much space the part takes up in the bounding box
			var new_scale : float = local_scales[j][i] / ext[i]
			new_scale = lerp(0.0, scale_absolute[i], new_scale)
			local_scales[j][i] = new_scale
			j = j + 1
		
		
		
		j = 0
		#move all parts in relation to where they are in the bounding box
		while j < selected_parts_array.size():
			#get relative position from -1 to 1 depending on how close to the edge of the bounding box a part is
			var pos : float = local_offsets[j][i] / ext[i]
			pos = lerp(0.0, scale_absolute[i], pos)
			local_offsets[j][i] = pos
			j = j + 1
		
		selected_parts_abb.extents[i] = scale_absolute[i]
		i = i + 1
	
	
	#im sad to admit i needed chatgpt to figure this one out
	#reassign transformed local scales to part-space scales
	var i_d : int = 0
	while i_d < scalable_parts.size():
		var abb_basis = selected_parts_abb.transform.basis
		var p = scalable_parts[i_d].basis
		var s = scalable_parts[i_d].part_scale
		
		#abb local to world
		var world_scale_again = abb_basis * local_scales[i_d]
		
		#world space to part space
		var diff_reverse = p.inverse()
		var local_scale = diff_reverse * world_scale_again
		
		local_scale.x = abs(local_scale.x)
		local_scale.y = abs(local_scale.y)
		local_scale.z = abs(local_scale.z)
		scalable_parts[i_d].part_scale = local_scale
		i_d = i_d + 1
	
	
	#reassign transformed local offsets to global offset array
	offset_abb_to_selected_array.clear()
	for i_g in local_offsets:
		offset_abb_to_selected_array.append(i_g * inverse)
	
	selection_boxes_redraw_all()
	#move transform handles with selection
	Main.set_transform_handle_root_position(Main.transform_handle_root, selected_parts_abb.transform, Main.local_transform_active, Main.selected_tool_handle_array)


#undo redo system---------------------------------------------------------------
static func undo():
	print("UNDO")


static func redo():
	print("REDO")


#save load system---------------------------------------------------------------
static func save_model():
	selection_set_to_workspace()
	var used_colors : Array[Color] = []
	var used_materials : Array[ShaderMaterial] = []
	var used_meshes : Array[Mesh] = []
	var color_to_int_mapping : Dictionary
	var material_name_to_int_mapping : Dictionary
	var mesh_to_int_mapping : Dictionary
	var files_used : Array = []
	var line : PackedStringArray = []
	var line_debug : PackedStringArray = []
	var file : PackedStringArray = []
	
	#get used colors
	var i : int = 0
	while i < selected_parts_array.size():
		if not used_colors.has(selected_parts_array[i].part_color):
			used_colors.append(selected_parts_array[i].part_color)
		i = i + 1
	
	#get used materials
	i = 0
	
	used_materials.append(selected_parts_array[0].part_material)
	while i < selected_parts_array.size():
		var j : int = 0
		var has_material : bool = false
		
		while j < used_materials.size():
			var base_1 = used_materials[j].resource_path.get_file()
			var base_2 = selected_parts_array[i].part_material.resource_path.get_file()
			if base_2 == base_1:
				has_material = true
				break
			j = j + 1
		
		if not has_material:
			used_materials.append(selected_parts_array[i].part_material)
		i = i + 1
	
	#get used meshes
	i = 0
	used_meshes.append(selected_parts_array[0].part_mesh_node.mesh)
	while i < selected_parts_array.size():
		var j : int = 0
		var has_mesh : bool = false
		while j < used_meshes.size():
			if selected_parts_array[i].part_mesh_node.mesh.resource_path.get_file() == used_meshes[j].resource_path.get_file():
				has_mesh = true
				break
			j = j + 1
			
		if not has_mesh:
			used_meshes.append(selected_parts_array[i].part_mesh_node.mesh)
		i = i + 1
	
	#create mappings to quickly assign the used color and material ids
	color_to_int_mapping = create_mapping(used_colors)
	material_name_to_int_mapping = create_mapping(used_materials.map(func(input): return input.resource_path.get_file()))
	mesh_to_int_mapping = create_mapping(used_meshes.map(func(input): return input.resource_path.get_file()))
	
	
	
	#turn colors to vec3s and add to save object
	i = 0
	file.append("::COLOR::")
	while i < used_colors.size():
		file.append(",".join([str(used_colors[i].r8), str(used_colors[i].g8), str(used_colors[i].b8)]))
		i = i + 1
	
	#add materials to save object
	i = 0
	file.append("::MATERIAL::")
	while i < used_materials.size():
		files_used.append(used_materials[i].shader.resource_path)
		line.append(used_materials[i].shader.resource_path.get_file())
		var properties : Array = used_materials[i].shader.get_shader_uniform_list()
		var j : int = 0
		prints(i, "-------------------------------")
		while j < properties.size():
			var param = used_materials[i].get_shader_parameter(properties[j].name)
			line_debug.append(properties[j].name)
			if param is Texture2D:
				files_used.append(param.resource_path)
				line.append(param.resource_path.get_file())
			elif param is float:
				line.append(str(param))
			elif param is Vector3:
				line.append(str(param.x))
				line.append(str(param.y))
				line.append(str(param.z))
			elif param is Vector4:
				line.append(str(param.w))
				line.append(str(param.x))
				line.append(str(param.y))
				line.append(str(param.z))
			elif param == null:
				if properties[j].type == TYPE_VECTOR3:
					line.append("")
					line.append("")
					line.append("")
				elif properties[j].type == TYPE_VECTOR4:
					line.append("")
					line.append("")
					line.append("")
					line.append("")
				else:
					#push_warning("null saved in workspace_manager.save_model()")
					#print(j, "NULL SAVED")
					line.append("")
			else:
				print("UNIMPLEMENTED TYPE: ", param)
				return
			j = j + 1
		file.append(",".join(line))
		line.clear()
		i = i + 1
	
	#add meshes to save object
	i = 0
	file.append("::MESH::")
	while i < used_meshes.size():
		files_used.append(used_meshes[i].resource_path)
		file.append(used_meshes[i].resource_path.get_file())
		i = i + 1
	
	
	#part data (PARALLEL ARRAYS!!)
	i = 0
	file.append("::MODEL::")
	while i < selected_parts_array.size():
		#position
		line.append(str(selected_parts_array[i].transform.origin.x))
		line.append(str(selected_parts_array[i].transform.origin.y))
		line.append(str(selected_parts_array[i].transform.origin.z))
		#scale
		line.append(str(selected_parts_array[i].part_scale.x))
		line.append(str(selected_parts_array[i].part_scale.y))
		line.append(str(selected_parts_array[i].part_scale.z))
		#rotation (quaternion kept failing at certain angles)
		line.append(str(selected_parts_array[i].rotation_degrees.x))
		line.append(str(selected_parts_array[i].rotation_degrees.y))
		line.append(str(selected_parts_array[i].rotation_degrees.z))
		#color
		line.append(str(color_to_int_mapping[selected_parts_array[i].part_color]))
		#material
		line.append(str(material_name_to_int_mapping[selected_parts_array[i].part_material.resource_path.get_file()]))
		line.append(str(mesh_to_int_mapping[selected_parts_array[i].part_mesh_node.mesh.resource_path.get_file()]))
		file.append(",".join(line))
		line.clear()
		i = i + 1
	
	if not DirAccess.get_directories_at("user://").has("saved_models"):
		DirAccess.make_dir_absolute("user://saved_models")
	var file_access = FileAccess.open("user://saved_models/model_1.csv", FileAccess.WRITE)
	file_access.flush()
	var dir_access = DirAccess.open("user://saved_models/")
	var zip_packer = ZIPPacker.new()
	i = 0
	while i < file.size():
		file_access.store_line(file[i])
		i = i + 1
	file_access.close()
	
	files_used.append("user://saved_models/model_1.csv")
	var error = zip_packer.open("user://saved_models/model_1.tmv")
	"DEBUG"
	print(error)
	
	i = 0
	while i < files_used.size():
		zip_packer.start_file(files_used[i].get_file())
		zip_packer.write_file(FileAccess.get_file_as_bytes(files_used[i]))
		zip_packer.close_file()
		i = i + 1
	
	dir_access.remove("user://saved_models/model_1.csv")
	zip_packer.close()


static func load_model():
	#no mappings required as the indices are already stored
	var used_colors : Array[Color] = []
	var used_materials : Array[Material] = []
	var used_meshes : Array[Mesh] = []
	var file : PackedStringArray = []
	var file_bytes : PackedByteArray = []
	var zip_reader : ZIPReader = ZIPReader.new()
	var i : int = 0
	zip_reader.open("user://saved_models/model_1.tmv")
	file_bytes = zip_reader.read_file("model_1.csv")
	file = file_bytes.get_string_from_utf8().split("\n")
	
	#mode from headers
	var mode : String
	while i < file.size():
		if file[i] == "::COLOR::" or file[i] == "::MATERIAL::" or file[i] == "::MESH::" or file[i] == "::MODEL::":
			mode = file[i]
			i = i + 1
			continue
		
		if file[i] == "" or file[i] == null:
			i = i + 1
			continue
		
		#processing
		var line = file[i].split(",")
	#load color
		if mode == "::COLOR::":
			used_colors.append(Color8(int(line[0]), int(line[1]), int(line[2])))
			
	#load material
		elif mode == "::MATERIAL::":
			var new : ShaderMaterial = ShaderMaterial.new()
			var shader = Shader.new()
			shader.code = zip_reader.read_file(line[0]).get_string_from_utf8()
			new.shader = shader
			
			var properties : Array = shader.get_shader_uniform_list()
			var j : int = 0
			#start at 1 because line item 0 is the shader file name
			var j_line : int = 1
			
			print(i, "-------------------------------------------------------------")
			while j < properties.size():
				var param = properties[j]#new.get_shader_parameter(properties[j].name)
				if param.type == TYPE_OBJECT:
					if param.hint_string == "Texture2D":
						if zip_reader.get_files().has(line[j_line]):
							var img = Image.new()
							img.load_jpg_from_buffer(zip_reader.read_file(line[j_line]))
							img.generate_mipmaps()
							var texture : ImageTexture = ImageTexture.create_from_image(img)
							new.set_shader_parameter(properties[j].name, texture)
					
				elif param.type == TYPE_FLOAT:
					new.set_shader_parameter(properties[j].name, float(line[j_line]))
				#surprisingly does not need to be incremented by 2, the x y z are stored as separate floats
				elif param.type == TYPE_VECTOR3:
					#new.set_shader_parameter(properties[j].name, float(line[j_line]))
					var vec : Vector3 = Vector3()
					vec.x = float(line[j_line])
					vec.y = float(line[j_line + 1])
					vec.z = float(line[j_line + 2])
					new.set_shader_parameter(properties[j].name, vec)
					j_line = j_line + 2
				elif param.type == TYPE_VECTOR4:
					#new.set_shader_parameter(properties[j].name, float(line[j_line]))
					var vec : Vector4 = Vector4()
					vec.w = float(line[j_line])
					vec.x = float(line[j_line + 1])
					vec.y = float(line[j_line + 2])
					vec.z = float(line[j_line + 3])
					new.set_shader_parameter(properties[j].name, vec)
					j_line = j_line + 3
				else:
					print("UNIMPLEMENTED TYPE: ", param)
					return
				j_line = j_line + 1
				j = j + 1
			used_materials.append(new)
			
	#load mesh
		elif mode == "::MESH::":
			if line[0] != null or line[0] != "":
				var mesh_bytes = zip_reader.read_file(line[0])
				var f = FileAccess.open("user://saved_models/" + line[0], FileAccess.WRITE)
				f.store_buffer(mesh_bytes)
				f.close()
				used_meshes.append(ResourceLoader.load("user://saved_models/" + line[0]))
				DirAccess.remove_absolute("user://saved_models/" + line[0])
				
		elif mode == "::MODEL::":
			var new : Part = Part.new()
			#position
			new.transform.origin.x = float(line[0])
			new.transform.origin.y = float(line[1])
			new.transform.origin.z = float(line[2])
			#scale
			new.part_scale.x = float(line[3])
			new.part_scale.y = float(line[4])
			new.part_scale.z = float(line[5])
			#rotation
			new.rotation_degrees.x = float(line[6])
			new.rotation_degrees.y = float(line[7])
			new.rotation_degrees.z = float(line[8])
			#mesh
			new.part_mesh_node.mesh = used_meshes[int(line[11])]
			#material
			new.part_material = used_materials[int(line[10])]
			#color
			new.part_color = used_colors[int(line[9])]
			
			workspace.add_child(new)
		
		i = i + 1

#selection box functions--------------------------------------------------------
#instance and fit selection box to a part as child of workspace node and add it to the array
static func selection_box_instance_on_part(assigned_part : Part):
	var new : SelectionBox = SelectionBox.new()
	selection_box_array.append(new)
	workspace.add_child(new)
	new.assigned_node = assigned_part
	new.box_scale = assigned_part.part_scale
	new.transform = assigned_part.transform
	var mat : StandardMaterial3D = preload("res://editor/classes/selection_box/selection_box_mat.res")
	new.material_override = mat


#delete all selection boxes and clear 
static func selection_boxes_clear_all():
	for i in selection_box_array:
		if Main.safety_check(i):
			i.queue_free()
	selection_box_array.clear()


#only used for scale tool
static func selection_boxes_redraw_all():
	for i in selection_box_array:
		if Main.safety_check(i):
			if i.assigned_node is Part:
				i.box_scale = i.assigned_node.part_scale


#delete selection box whos assigned_node matches the parameter
static func selection_box_delete_on_part(assigned_part : Node3D):
	for i in selection_box_array:
		if Main.safety_check(i):
			if i.assigned_node == assigned_part:
				selection_box_array.erase(i)
				i.queue_free()
				return


"TODO"#unit test somehow?
static func selection_box_hover_on_part(part : Part, is_hovering_allowed : bool):
	if is_hovering_allowed and Main.safety_check(part):
		hover_selection_box.visible = true
		hover_selection_box.global_transform = part.global_transform
		hover_selection_box.box_scale = part.part_scale
	else:
		hover_selection_box.visible = false


#might remove this
#this function was meant to toggle the visibility of selectionboxes but it was unreliable
#func selection_box_toggle_visibility(part : Part, make_visible : bool):
#	if not safety_check(part):
#		return
#
#	if make_visible:
#		for i in selection_box_array:
#			if safety_check(i):
#				if i.assigned_node == part:
#					i.visible = false
#					break
#	else:
#		for i in selection_box_array:
#			if safety_check(i):
#				if i.assigned_node == part:
#					i.visible = true
#					break
#		hover_selection_box.visible = false


#utils
static func refresh_offset_abb_to_selected_array():
	var i : int = 0
	offset_abb_to_selected_array.clear()
	while i < selected_parts_array.size():
		offset_abb_to_selected_array.append(selected_parts_array[i].transform.origin - selected_parts_abb.transform.origin)
		i = i + 1


#did not know where to put this function
static func create_mapping(input_data : Array):
	var i : int = 0
	var map : Dictionary = {}
	
	while i < input_data.size():
		#reverse the keys with the values in input_data
		map[input_data[i]] = i
		i = i + 1
	
	return map


static func color_to_vec3(color : Color):
	return Vector3(color.r, color.g, color.b)


static func vec3_to_color(vec : Vector3):
	return Color(vec.x, vec.y, vec.z)

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






"""
#defaults for load/save error cases
#static var default_color : Color = Color.WHITE
#static var default_material : StandardMaterial3D = StandardMaterial3D.new()
#static var default_mesh : Mesh = BoxMesh.new()

#on startup, load these palettes
#const folder_startup_palettes : String = "user://palettes"
#const folder_saved_models : String = "user://models/"


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
		[WorkspaceManager.is_equal, WorkspaceManager.is_greater],
		[1, 1],
		[["uuid", "name", "description"], ["color_array", "color_name_array"]],
		[[DataType.t_string, DataType.t_string, DataType.t_string], [DataType.t_color, DataType.t_string]]
	),
	initialize_instruction(
		MaterialPalette.new(),
		section_header_dict.material_palette,
		[WorkspaceManager.is_equal, WorkspaceManager.is_greater],
		[1, 1],
		[["uuid", "name", "description"], ["material_array", "material_name_array"]],
		[[DataType.t_string, DataType.t_string, DataType.t_string], [DataType.t_material, DataType.t_string]]
	),
	initialize_instruction(
		PartTypePalette.new(),
		section_header_dict.part_type_palette,
		[WorkspaceManager.is_equal, WorkspaceManager.is_greater],
		[1, 1],
		[["uuid", "name", "description"], ["mesh_array", "mesh_name_array", "collider_type_array"]],
		[[DataType.t_string, DataType.t_string, DataType.t_string], [DataType.t_mesh, DataType.t_string, DataType.t_int]]
	),
	initialize_instruction(
		Model.new(),
		section_header_dict.model,
		[WorkspaceManager.is_equal, WorkspaceManager.is_greater],
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

"TODO"#add config read function, add material read function, add part model read function
"TODO"#also add all the filepaths in here
"""
