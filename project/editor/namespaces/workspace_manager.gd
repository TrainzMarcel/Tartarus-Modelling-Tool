extends RefCounted
class_name WorkspaceManager

#was meant to handle saving and loading but i dropped that for now
#now handles selection logic, selection box logic and undo redo logic

#dependencies
static var hover_selection_box : SelectionBox
static var workspace : Node

#bounding box of selected parts for positional snapping
static var selected_parts_abb : ABB = ABB.new()
static var initial_abb_state : ABB = ABB.new()


#initial transform to make snapping work with transformhandles
static var initial_transform_handle_root_transform : Transform3D
static var initial_handle_event : InputEvent


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

#for tracking all loaded assets
static var loaded_assets : Array[Resource]
static var name_loaded_asset_mapping : Dictionary


#!!!selected_parts_array, offset_dragged_to_selected_array and selection_box_array are parallel arrays!!!
static var offset_abb_to_selected_array : Array[Vector3] = []
#offset from the dragged parts position to the raycast hit position
static var selection_box_array : Array[SelectionBox] = []
static var selected_parts_array : Array[Part] = []

#set this on selection change, this tells the bounding box to recalculate itself
#between selection handling and selection transform operations
static var selection_changed : bool = false

#call set_transform_handle_root at end of input frame
static var selection_moved : bool = false

#for copy pasting
static var parts_clipboard : Array[Part] = []

#vector pointing from ray_result.position to selected_parts_abb
static var drag_offset : Vector3

#initial drag event to check if user exceeded 10 pixel drag tolerance
#this makes sure when the user is selecting with shift
#that parts dont get moved when the user accidentally moves their mouse a tiny bit
static var initial_drag_event : InputEvent
#once the drag tolerance is exceeded this is set to true and dragging starts
static var drag_confirmed : bool

#initial selection rect event where the user starts dragging while not hovered over anything draggable
static var initial_selection_rect_event : InputEvent
#keep track of first selected part to guarantee bounding box orientation
static var first_part_selection_rect : Part
#for shift-selecting, i need to keep track of the initial selection
static var initial_selected_parts : Array[Part]

#saving and loading related variables
enum FileOperation {
	save,
	save_as,
	load
}
static var file_operation : FileOperation
static var last_save_location : String = ""
static var last_save_name : String = ""

"TODO"
const data_header_value : PackedStringArray = [
	"::COLOR::",
	"::MATERIAL::",
	"::MESH::",
	"::MODEL::",
]
enum DataHeaderKey {
	color,
	material,
	mesh,
	model
}

static func initialize(workspace : Node, hover_selection_box : SelectionBox):
	WorkspaceManager.workspace = workspace
	WorkspaceManager.hover_selection_box = hover_selection_box
	
	#colors are stored in color buttons (self_modulate) but im not sure if thats a good thing
	#color buttons are loaded in the ui.initialize() function
	
	#get part types and materials from .tres files
	var file_list = DirAccess.get_files_at(FilePathRegistry.data_folder_material)
	var materials_list : Array[Material] = []
	
	"DEBUG"
	MaterialManager.l_debug = workspace.get_parent().get_node("DebugLabel")
	
	for path in file_list:
		materials_list.append(ResourceLoader.load(FilePathRegistry.data_folder_material + path, "Material"))
	WorkspaceManager.available_materials = materials_list
	for mat in materials_list:
		MaterialManager.register_material(mat)
	
	
	
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
	
	
	loaded_assets.append_array(available_materials)
	loaded_assets.append_array(available_part_types.map(func(input): return input.part_mesh_node.mesh))
	name_loaded_asset_mapping = create_mapping(loaded_assets.map(func(input): return get_resource_name(input.resource_path)))
	
	#_ready was getting called in the parts before main and before textures loaded so this is done manually now
	workspace.get_children().map(func(input): if input is Part: input.initialize())


#part functions-----------------------------------------------------------------
#only meant for spawning a part from the part spawn button
static func part_spawn(selected_part_type : Part):
	var ray_result = Main.raycast(Main.cam, Main.cam.global_position, -Main.cam.basis.z * Main.raycast_length, [], [1])
	var new_part : Part = selected_part_type.copy()
	workspace.add_child(new_part)
	new_part.initialize()
	
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
	#optimization
	new_part.part_mesh_node.mesh = selected_part_type.part_mesh_node.mesh
	new_part.part_collider_node = selected_part_type.part_collider_node.duplicate()


#called when user clicks on a part and drags
#at this point ray_result shouldnt be empty
static func drag_prepare(event : InputEvent):
	Main.initial_rotation = WorkspaceManager.selected_parts_abb.transform.basis
	Main.dragged_part = Main.hovered_part
	initial_drag_event = event
	


static func drag_handle(event : InputEvent):
	#first make sure the user actually wants to start a drag
	if initial_drag_event != null:
		if (event.position - initial_drag_event.position).length() > Main.drag_tolerance: 
			drag_confirmed = true
	
	if Main.is_mouse_button_held and not Main.ray_result.is_empty() and Main.is_selecting_allowed and drag_confirmed:
		if Main.safety_check(Main.dragged_part):
			if Main.safety_check(Main.hovered_part):
				if not SnapUtils.part_rectilinear_alignment_check(Main.dragged_part.basis, Main.hovered_part.basis):
					#use initial_rotation so that dragged_part doesnt continually rotate further 
					#from its initial rotation after being dragged over multiple off-grid parts
					var rotated_basis : Basis = SnapUtils.drag_snap_rotation_to_hovered(Main.initial_rotation, Main.ray_result)
					
					WorkspaceManager.selection_rotate(rotated_basis)
				
				#set positions according to offset_dragged_to_selected_array and where the selection is being dragged (ray_result.position)
				WorkspaceManager.selection_move(SnapUtils.drag_snap_position_to_hovered(
					Main.ray_result,
					Main.dragged_part,
					selected_parts_abb,
					WorkspaceManager.drag_offset,
					Main.positional_snap_increment,
					Main.snapping_active
				))


static func drag_end():
	drag_confirmed = false
	initial_drag_event = null


"TODO"#add logic for appending to selection when shift is held
static func selection_rect_prepare(event : InputEvent, selection_rect : Panel):
	initial_selection_rect_event = event
	#duplicate to avoid mutation
	initial_selected_parts = selected_parts_array.duplicate()
	selection_rect.position = initial_selection_rect_event.position
	selection_rect.size = Vector2.ZERO
	selection_rect.visible = true


#this function has not yet been tested for orthographic view
static func selection_rect_handle(event : InputEvent, selection_rect : Panel, cam : Camera3D):
	if Main.is_mouse_button_held and Main.is_selecting_allowed and initial_selection_rect_event != null and event is InputEventMouse:
		var physics : PhysicsDirectSpaceState3D = cam.get_world_3d().direct_space_state
		
		
		#render the selection rect
		var scaling : Vector2 = event.position - initial_selection_rect_event.position
		selection_rect.size = scaling.abs()
		if scaling.x < 0:
			selection_rect.position.x = initial_selection_rect_event.position.x + scaling.x
		
		if scaling.y < 0:
			selection_rect.position.y = initial_selection_rect_event.position.y + scaling.y
		
		
		var rect : Rect2 = selection_rect.get_rect()
		var a : Vector2 = rect.position
		var b : Vector2 = Vector2(rect.position.x + rect.size.x, rect.position.y)
		var c : Vector2 = rect.position + rect.size
		var d : Vector2 = Vector2(rect.position.x, rect.position.y + rect.size.y)
		var rect_points : PackedVector2Array = [a,b,c,d]
		
		#collision checks
		var collider_points : PackedVector3Array = []
		var a1 = cam.project_position(a, Main.raycast_length)
		var b1 = cam.project_position(b, Main.raycast_length)
		var c1 = cam.project_position(c, Main.raycast_length)
		var d1 = cam.project_position(d, Main.raycast_length)
		
		var e1 = cam.position
		
		var frustum_collider : ConvexPolygonShape3D = ConvexPolygonShape3D.new()
		frustum_collider.points = [a1, b1, c1, d1, e1]
		
		var params : PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
		params.shape = frustum_collider
		var result = physics.intersect_shape(params, 2048)
		
		var result_colliders = result.map(func(input): return input.collider)
		var result_parts : Array[Part] = []
		
		for i in result_colliders:
			if i is Part:
				result_parts.append(i)
		
		"TODO"#there has to be a better way to do this
		#guarantee the first selected part is always at the start of the array
		#so that the bounding box orientation doesnt change
		if result_parts.size() > 0 and first_part_selection_rect == null:
			first_part_selection_rect = result_parts[0]
			Main.initial_rotation = result_parts[0].basis
		
		if first_part_selection_rect != null and result_parts.size() > 1:
			result_parts.erase(first_part_selection_rect)
			result_parts.push_front(first_part_selection_rect)
		
		
		if result_parts.size() > 0:
			if first_part_selection_rect != null:
				if Input.is_key_pressed(KEY_SHIFT):
					for part in initial_selected_parts:
						if result_parts.has(part):
							result_parts.erase(part)
						else:
							result_parts.append(part)
				
				WorkspaceManager.selection_set_to_part_array(result_parts, first_part_selection_rect)
		else:
			if Input.is_key_pressed(KEY_SHIFT) and initial_selected_parts.size() > 0:
				WorkspaceManager.selection_set_to_part_array(initial_selected_parts, initial_selected_parts[0])
			else:
				WorkspaceManager.selection_clear()
			first_part_selection_rect = null


static func selection_rect_end(selection_rect : Panel):
	selection_rect.visible = false
	initial_selection_rect_event = null
	first_part_selection_rect = null
	initial_selected_parts = []
	selection_changed = true


static func refresh_bounding_box():
	if not Main.safety_check(selected_parts_array[0]) and not selection_changed:
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
	selection_changed = true


static func selection_add_part(hovered_part : Part, abb_orientation : Part):
	selected_parts_array.append(hovered_part)
	selection_box_instance_on_part(hovered_part)
	offset_abb_to_selected_array.append(hovered_part.transform.origin - abb_orientation.transform.origin)
	selection_changed = true


static func selection_set_to_workspace():
	selection_clear()
	var workspace_parts = workspace.get_children().filter(func(part):
		return part is Part
		)
	
	for i in workspace_parts:
		selection_add_part(i, workspace_parts[0])
	selection_changed = true


static func selection_set_to_part(hovered_part : Part, abb_orientation : Part):
	selected_parts_array = [hovered_part]
	offset_abb_to_selected_array = [hovered_part.global_position]
	selection_boxes_clear_all()
	selection_box_instance_on_part(hovered_part)
	selection_changed = true


#for undo operations
static func selection_set_to_part_array(input : Array[Part], abb_orientation : Part):
	selection_clear()
	
	for part in input:
		if not selected_parts_array.has(part):
			selection_add_part(part, abb_orientation)
	selection_changed = true


static func selection_clear():
	selected_parts_array.clear()
	selection_boxes_clear_all()
	offset_abb_to_selected_array.clear()
	selection_changed = true
	#does not need to call selection_changed as the bounding box doesnt matter when nothing is selected


static func selection_delete():
	for i in selected_parts_array:
		i.queue_free()
	selection_clear()


static func selection_copy():
	parts_clipboard.clear()
	for i in selected_parts_array:
		parts_clipboard.append(i.copy())

static func selection_paste():
	if not parts_clipboard.is_empty():
		selection_clear()
		for i in parts_clipboard:
			var copy : Part = i.copy()
			workspace.add_child(copy)
			copy.initialize()
			selection_add_part(copy, copy)
		refresh_bounding_box()
		selection_moved = true


static func selection_duplicate():
	for i in selected_parts_array:
		var copy : Part = i.copy()
		workspace.add_child(copy)
		copy.initialize()


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
	selection_moved = true


#rotation only
"TODO"#parameterize everything for clarity and to prevent bugs
static func selection_rotate(rotated_basis : Basis):#TODO , point_local : Vector3 = Vector3.ZERO):
	var original_basis : Basis = Basis(selected_parts_abb.transform.basis)
	
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
	selection_moved = true


#scale_absolute meaning it will set the scale of the selection bounding box to this value
#must call selection_move after this function due to the updated offset_abb_to_selected_array
"TODO"#OPTIMIZE OPTIMIZE OPTIMIZE
#https://www.reddit.com/r/godot/comments/187npcd/how_to_increase_performance/
#https://docs.godotengine.org/en/4.1/classes/class_renderingserver.html
"TODO"#this function is not very stable mathematically
static func selection_scale(scale_absolute : Vector3):
	#dont do anything if scale is the same
	if scale_absolute == selected_parts_abb.extents:
		return
	
	#scaling singular parts is easy
	if selected_parts_array.size() == 1:
		selected_parts_array[0].part_scale = scale_absolute
		selected_parts_abb.extents = scale_absolute
		selection_boxes_redraw_all()
		selection_moved = true
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
	selection_moved = true


#undo redo system---------------------------------------------------------------
static func undo():
	print("UNDO")


static func redo():
	print("REDO")


#save load system---------------------------------------------------------------
#event methods
static func validate_filepath(filepath : String):
	var valid : bool = filepath.is_absolute_path()
	return valid and filepath != null and filepath != ""


static func validate_filename(filename : String):
	var valid : bool = filename.is_valid_filename()
	return valid and filename != null and filename != ""


static func request_save():
	file_operation = FileOperation.save
	if validate_filepath(last_save_location) and validate_filename(last_save_name):
		confirm_save_load(last_save_location, last_save_name)
	else:
		EditorUI.fm_file.popup(FileManager.FileMode.save_file)


static func request_save_as():
	file_operation = FileOperation.save_as
	EditorUI.fm_file.popup(FileManager.FileMode.save_file)


static func request_load():
	file_operation = FileOperation.load
	EditorUI.fm_file.popup(FileManager.FileMode.open_file)


static func confirm_save_load(filepath : String, name : String):
	if file_operation == FileOperation.save or file_operation == FileOperation.save_as:
		EditorUI.l_message.text = "saving..."
		save_model(filepath + "/", name)
		last_save_location = filepath
		last_save_name = name
		EditorUI.l_message.text = "successfully saved " + name + " at " + filepath + "!"
	elif file_operation == FileOperation.load:
		EditorUI.l_message.text = "loading..."
		load_model(filepath + "/", name)
		EditorUI.l_message.text = "successfully loaded " + name + " at " + filepath + "!"


#actual save and load functions
"TODO"#add error handling here and at load()
"TODO URGENT"#centralize logic for asset "database" system
static func save_model(filepath : String, name : String):
	"TODO"#probably add some setting for how much of the model to save
	#plus add exclude functionality
	#plus add part lock functionality
	#i think saving a group of parts would also be simple with something like a ::GROUP:: header which has the part ids under it
	#storing the ids horizontally per part would probably be cheaper than vertically
	#also maybe add comment feature
	selection_set_to_workspace()
	var used_colors : Array[Color] = []
	var used_materials : Array[ShaderMaterial] = []
	var used_meshes : Array[Mesh] = []
	var color_to_int_mapping : Dictionary
	var material_name_to_int_mapping : Dictionary
	var mesh_to_int_mapping : Dictionary
	var assets_used : Array[Resource] = []
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
	
	
	
	#add colors to save
	i = 0
	"TODO"#make this a safer operation (string variable or const instead of hardcoded)
	#and/or use a function dispatch for each header type
	file.append("::COLOR::")
	while i < used_colors.size():
		file.append(",".join([str(used_colors[i].r8), str(used_colors[i].g8), str(used_colors[i].b8)]))
		i = i + 1
	
	#add materials to save
	i = 0
	file.append("::MATERIAL::")
	while i < used_materials.size():
		if not assets_used.has(used_materials[i].shader):
			assets_used.append(used_materials[i].shader)
		line.append(get_resource_name(used_materials[i].shader.resource_path))
		line.append(get_resource_name(used_materials[i].resource_path))
		var properties : Array = used_materials[i].shader.get_shader_uniform_list()
		var j : int = 0
		
		while j < properties.size():
			var param = used_materials[i].get_shader_parameter(properties[j].name)
			line_debug.append(properties[j].name)
			if param is Texture2D:
				if not assets_used.has(param):
					assets_used.append(param)
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
	
	#add meshes to save
	"TODO"#stop using resource files here
	i = 0
	file.append("::MESH::")
	while i < used_meshes.size():
		if not assets_used.has(used_meshes[i]):
			assets_used.append(used_meshes[i])
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
		#mesh
		line.append(str(mesh_to_int_mapping[selected_parts_array[i].part_mesh_node.mesh.resource_path.get_file()]))
		file.append(",".join(line))
		line.clear()
		i = i + 1
	
	
	var r_names = assets_used.map(func(input): return get_resource_name(input.resource_path))
	
	
	"TODO"#not sure about this
	#should definitely centralize these variables as much as possible
	var file_access = FileAccess.open(filepath + name + "_data.csv", FileAccess.WRITE)
	var dir_access = DirAccess.open(filepath)
	var zip_packer = ZIPPacker.new()
	zip_packer.open(filepath + name + ".tmv")
	
	var data_file : String = filepath + name + "_data.csv"
	
	
	file_access.flush()
	i = 0
	while i < file.size():
		file_access.store_line(file[i])
		i = i + 1
	file_access.close()
	
	zip_packer.start_file(name + "_data.csv")
	zip_packer.write_file(FileAccess.get_file_as_bytes(data_file))
	zip_packer.close_file()
	
	i = 0
	#embed used assets in the zip file
	while i < assets_used.size():
		var r_name = get_resource_name(assets_used[i].resource_path)
		if assets_used[i] is Texture2D:
			zip_packer.start_file(r_name)
			var img : Image = assets_used[i].get_image()
			
			zip_packer.write_file(img.save_png_to_buffer())
			zip_packer.close_file()
		elif assets_used[i] is Shader:
			zip_packer.start_file(r_name)
			zip_packer.write_file(assets_used[i].code.to_utf8_buffer())
			zip_packer.close_file()
		elif assets_used[i] is Mesh:
			ResourceSaver.save(assets_used[i], filepath + r_name)
			zip_packer.start_file(r_name)
			zip_packer.write_file(FileAccess.get_file_as_bytes(filepath + r_name))
			zip_packer.close_file()
			dir_access.remove(filepath + r_name)
		else:
			print("UNIMPLEMENTED TYPE: " + str(assets_used[i]))
		i = i + 1
	
	dir_access.remove(data_file)
	zip_packer.close()


static func load_model(filepath : String, name : String):
	#no mappings required as the indices are already stored
	var used_colors : Array[Color] = []
	var used_materials : Array[Material] = []
	var used_meshes : Array[Mesh] = []
	var file : PackedStringArray = []
	var file_bytes : PackedByteArray = []
	var zip_reader : ZIPReader = ZIPReader.new()
	var i : int = 0
	zip_reader.open(filepath + name + ".tmv")
	file_bytes = zip_reader.read_file(name + "_data.csv")
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
			#only load if required
			var new : ShaderMaterial
			var r_name : String = get_resource_name(line[1])
			if name_loaded_asset_mapping.has(r_name):
				new = loaded_assets[name_loaded_asset_mapping[r_name]]
				used_materials.append(new)
				i = i + 1
				continue
			else:
				new = ShaderMaterial.new()
				new.resource_path = r_name
				loaded_assets.append(new)
				name_loaded_asset_mapping[new] = name_loaded_asset_mapping.keys().size() - 1
			
			#only load if required
			var shader : Shader
			r_name = get_resource_name(line[0])
			if name_loaded_asset_mapping.has(r_name):
				shader = loaded_assets[name_loaded_asset_mapping[r_name]]
			else:
				shader = Shader.new()
				shader.code = zip_reader.read_file(line[0]).get_string_from_utf8()
				shader.resource_path = r_name
				loaded_assets.append(shader)
				name_loaded_asset_mapping[shader] = name_loaded_asset_mapping.keys().size() - 1
			
			new.shader = shader
			
			var properties : Array = shader.get_shader_uniform_list()
			var j : int = 0
			#start at 2 because line item 0 and 1 are the shader and material names respectively
			var j_line : int = 2
			
			#print(i, "-------------------------------------------------------------")
			while j < properties.size():
				var param = properties[j]#new.get_shader_parameter(properties[j].name)
				if param.type == TYPE_OBJECT:
					if param.hint_string == "Texture2D":
						"TODO"#probably should also only load this if required
						if zip_reader.get_files().has(line[j_line]):
							var img = Image.new()
							img.load_png_from_buffer(zip_reader.read_file(line[j_line]))
							img.generate_mipmaps()
							var texture : ImageTexture = ImageTexture.create_from_image(img)
							new.set_shader_parameter(properties[j].name, texture)
							#important for resaving a material
							texture.resource_path = filepath + get_resource_name(line[j_line])
							loaded_assets.append(texture)
					else:
						prints("UNIMPLEMENTED TYPE: ", param.hint_string, param)
				
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
				var f = FileAccess.open(filepath + line[0], FileAccess.WRITE)
				f.store_buffer(mesh_bytes)
				f.close()
				var new = ResourceLoader.load(filepath + line[0])
				new.resource_path = filepath + line[0]
				used_meshes.append(new)
				DirAccess.remove_absolute(filepath + line[0])
				
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
			new.initialize()
		
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
	"TODO"#probably add this to filepathregistry
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


#same as above but an offset can be added for 2d array situations
static func create_mapping_offset(input_data : Array, offset : int):
	var i : int = 0
	var map : Dictionary = {}
	
	while i < input_data.size():
		#reverse the keys with the values in input_data
		map[input_data[i]] = i + offset
		i = i + 1
	
	return map


static func get_resource_name(name : String):
	"TODO"#clarify this
	return name.rsplit("/", true, 1)[-1].rsplit(".", true, 1)[0]


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
