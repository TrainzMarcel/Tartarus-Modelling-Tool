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


static var available_colors : Array[Color] = []
static var available_color_names : PackedStringArray = []


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
#static var saving_thread : Thread

"TODO"#move into file explorer ui class and make it modular
enum FileOperation {
	save,
	save_as,
	load
}
static var file_operation : FileOperation
static var last_save_location : String = ""
static var last_save_name : String = ""

"TODO"#do something about this
const data_headers : Array = [
	"::COLOR::",
	"::MATERIAL::",
	"::MESH::",
	"::MODEL::"
]

#so far only used for checking if default assets have been moved to the user folder before
static var settings_dict_default : Dictionary = {
	"default_assets_copied_to_user_folder" = true
}


static func initialize(
		workspace : Node,
		hover_selection_box : SelectionBox,
		on_color_selected : Callable,
		on_material_selected : Callable,
		on_part_type_selected : Callable
	):
	
	WorkspaceManager.workspace = workspace
	WorkspaceManager.hover_selection_box = hover_selection_box
	
	
	#if settings.json is not there or is not set to true "default_assets_copied_to_user_folder" = true
	var file_access : FileAccess = FileAccess.open(FilePathRegistry.data_user_settings, FileAccess.READ)
	if file_access != null:
		#get settings and compare with default
		var settings = JSON.parse_string(file_access.get_as_text())
		file_access.close()
		
		if settings is Dictionary and not settings.default_assets_copied_to_user_folder:
			initialize_user_folder()
	else:
		initialize_user_folder()
	
	
	#get part types and materials from .tres files, get colors and names from .csv file
	var materials_list : Array[Material] = []
	var parts_list : Array[Part] = []
	var color_list : Array[Color] = []
	var color_names_list : Array[String] = []
	
	"DEBUG"#testing the loading of materials and meshes that are not there
	var load_directory : String = FilePathRegistry.data_folder_user_assets
	#var load_directory : String = FilePathRegistry.data_folder_default_assets
	
	var file_list = SaveUtils.get_files_recursive(load_directory)
	
	
	const color_autosort_enabled : String = "autosort = true"
	
	
	for file_name in file_list:
		var extension : String = file_name.get_extension().to_lower()
		
		#load an asset
		if extension == "res" or extension == "tres":
			var asset : Resource = ResourceLoader.load(load_directory + file_name)
			
			if asset is BaseMaterial3D or asset is ShaderMaterial:
				materials_list.append(asset)
				AssetManager.register_asset_with_subresources(asset)
			elif asset is Mesh:
				var new : Part = Part.new()
				new.part_mesh_node.mesh = asset
				parts_list.append(new)
				
				#set default scale (this must be refactored and not hardcoded!!)
				#cylinder
				if file_name == "cylinder.tres":
					new.part_scale = Vector3(0.4, 0.8, 0.4)
				#quarter cylinde
				elif file_name == "quarter.tres":
					new.part_scale = Vector3(0.2, 0.8, 0.2)
				#quarter inverse
				elif file_name == "quarter_inv.tres":
					new.part_scale = Vector3(0.2, 0.8, 0.2)
				#sphere
				elif file_name == "sphere.tres":
					new.part_scale = Vector3(0.8, 0.8, 0.8)
				
				
				
				#mesh types usually dont have any subresources
				AssetManager.register_asset(asset)
		
				"TODO"#i need to centralize csv parsing better
		#load colors with names and set autosort
		elif extension == "txt":
			var color_data : PackedStringArray = FileAccess.get_file_as_string(load_directory + file_name).split("\n")
			var color_autosort : bool = true
			#valid format
			if color_data.size() > 2 and color_data[0] == "::COLOR::":
				color_autosort = color_data[1] == color_autosort_enabled
			
			var r_dict : Dictionary = WorkspaceManager.read_colors_and_create_colors(color_data)
			if color_autosort:
				r_dict = AutomatedColorPalette.full_color_sort(EditorUI.gc_paint_panel, r_dict.color_array, r_dict.color_name_array)
			
			#in case someone wants to specify multiple color files im using append_array
			WorkspaceManager.available_colors.append_array(r_dict.color_array)
			WorkspaceManager.available_color_names.append_array(r_dict.color_name_array)
			EditorUI.create_color_buttons(EditorUI.gc_paint_panel, on_color_selected, r_dict.color_array, r_dict.color_name_array)
			
	AssetManager.debug_pretty_print()
	
	WorkspaceManager.available_materials = materials_list
	WorkspaceManager.available_part_types = parts_list
	
	if available_part_types.size() > 0:
		selected_part_type = available_part_types[0]
	
	
	EditorUI.create_material_buttons(on_material_selected, materials_list)
	EditorUI.create_part_type_buttons(on_part_type_selected, parts_list)
	
	
	
	
	#_ready was getting called in the parts before main and before textures loaded so this is done manually now
	#this line is only required for the manually placed parts in the main scene
	workspace.get_children().map(func(input): if input is Part: input.initialize())


static func initialize_user_folder():
	#copy default assets to user folder
	DirAccess.make_dir_recursive_absolute(FilePathRegistry.data_folder_user_assets)
	for file in SaveUtils.get_files_recursive(FilePathRegistry.data_folder_default_assets):
		
		if file.get_extension().to_lower() != "import":
			if not DirAccess.dir_exists_absolute(FilePathRegistry.data_folder_user_assets.path_join(file.get_base_dir())):
				DirAccess.make_dir_absolute(FilePathRegistry.data_folder_user_assets.path_join(file.get_base_dir()))
			
			DirAccess.copy_absolute(FilePathRegistry.data_folder_default_assets + file, FilePathRegistry.data_folder_user_assets + file)
			#print("copied ", FilePathRegistry.data_folder_default_assets + file, " to ", FilePathRegistry.data_folder_user_assets + file) 
	
	#write settings.json
	var file_access : FileAccess = FileAccess.open(FilePathRegistry.data_user_settings, FileAccess.WRITE)
	file_access.store_string(JSON.stringify(settings_dict_default, "\t"))
	file_access.close()


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

"TODO"#theres a second copy function in part.gd, decide on which function to keep!!
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
		if Main.safety_check(Main.dragged_part) and Main.safety_check(Main.hovered_part):
			if not SnapUtils.part_rectilinear_alignment_check(Main.dragged_part.basis, Main.hovered_part.basis):
				#use initial_rotation so that dragged_part doesnt continually rotate further 
				#from its initial rotation after being dragged over multiple off-grid parts
				var rotated_basis : Basis = SnapUtils.drag_snap_rotation_to_hovered(Main.initial_rotation, Main.ray_result)
				
				WorkspaceManager.selection_rotate(rotated_basis)
			
			var snap_output : Vector3 = SnapUtils.drag_snap_position_to_hovered(
				Main.ray_result,
				Main.dragged_part,
				selected_parts_abb,
				WorkspaceManager.drag_offset,
				Main.positional_snap_increment,
				Main.snapping_active
			)
			
			
			#set positions according to offset_dragged_to_selected_array and where the selection is being dragged (ray_result.position)
			WorkspaceManager.selection_move(snap_output)


static func drag_terminate():
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


static func selection_rect_terminate(selection_rect : Panel):
	selection_rect.visible = false
	initial_selection_rect_event = null
	first_part_selection_rect = null
	initial_selected_parts = []
	selection_changed = true


static func refresh_bounding_box():
	if not Main.safety_check(selected_parts_array[0]) and not selection_changed:
		return
	selected_parts_abb = SnapUtils.calculate_extents(selected_parts_abb, selected_parts_array[-1], selected_parts_array)
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
"TODO"#check and ensure numerical stability
static func selection_move(input_absolute : Vector3):
	selected_parts_abb.transform.origin = input_absolute 
	
	var i : int = 0
	while i < selected_parts_array.size():
		selected_parts_array[i].transform.origin = selected_parts_abb.transform.origin + offset_abb_to_selected_array[i]
		selection_box_array[i].transform.origin = selected_parts_array[i].transform.origin
		i = i + 1
	
	"TODO"#below line must be abstracted out
	Main.transform_handle_root.transform.origin = input_absolute
	#move transform handles with selection
	selection_moved = true


#rotation only
"TODO"#parameterize everything for clarity and to prevent bugs
"TODO"#check and ensure numerical stability
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
"TODO"#add variables that remember the original scale and part positions from when the scaling handle drag started
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
	return
	#print("UNDO")


static func redo():
	return
	#print("REDO")


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
	EditorUI.c_loading_message.visible = true
	#one await wasnt enough for the loading message to show up
	await EditorUI.c_loading_message.get_tree().process_frame
	await EditorUI.c_loading_message.get_tree().process_frame
	if file_operation == FileOperation.save or file_operation == FileOperation.save_as:
		EditorUI.l_message.text = "saving..."
		save_model(filepath + "/", name)
		last_save_location = filepath
		last_save_name = name
		EditorUI.l_message.text = "successfully saved " + name + " at " + filepath + "!"
	elif file_operation == FileOperation.load:
		EditorUI.l_message.text = "loading..."
		"TODO"#add return 
		load_model(filepath + "/", name)
		EditorUI.l_message.text = "successfully loaded " + name + " at " + filepath + "!"
	EditorUI.c_loading_message.visible = false


#actual save and load functions
"TODO"#add error handling here and at load()
static func save_model(filepath : String, name : String):
	"TODO"#probably add some setting for how much of the model to save
	#plus add exclude functionality
	#plus add part lock functionality
	#i think saving a group of parts would also be simple with something like a ::GROUP:: header which has the part ids under it
	#storing the ids horizontally per part would probably be cheaper than vertically
	#also maybe add comment feature that adds a line describing each column of every header
	AssetManager.debug_pretty_print()
	selection_set_to_workspace()
	var used_colors : Array[Color] = []
	var used_materials : Array[Material] = []
	var used_meshes : Array[Mesh] = []
	var color_to_int_mapping : Dictionary
	var material_name_to_int_mapping : Dictionary
	var mesh_to_int_mapping : Dictionary
	var assets_used : Array[Resource] = []
	var line : PackedStringArray = []
	var line_debug : PackedStringArray = []
	var file : PackedStringArray = []
	const separator : String = ","
	
	#get used colors, materials and meshes
	used_colors = SaveUtils.get_colors_from_parts(selected_parts_array)
	used_materials = SaveUtils.get_materials_from_parts(selected_parts_array)
	used_meshes = SaveUtils.get_meshes_from_parts(selected_parts_array)
	
	#create mappings to quickly assign the used color and material ids
	color_to_int_mapping = create_mapping(used_colors)
	material_name_to_int_mapping = create_mapping(used_materials.map(func(input): return AssetManager.get_name_of_asset(input, false)))
	mesh_to_int_mapping = create_mapping(used_meshes.map(func(input): return AssetManager.get_name_of_asset(input)))
	
	#add colors to save
	var i : int = 0
	"TODO"#make this a safer operation (string variable or const instead of hardcoded)
	#and/or use a function dispatch for each header type
	file.append("::COLOR::")
	while i < used_colors.size():
		file.append(separator.join(SaveUtils.color_serialize(used_colors[i])))
		i = i + 1
	
	#add materials to save
	i = 0
	file.append("::MATERIAL::")
	while i < used_materials.size():
		if not assets_used.has(used_materials[i]):
			assets_used.append(used_materials[i])
		file.append(separator.join(SaveUtils.material_serialize(used_materials[i])))
		i = i + 1
	
	#add meshes to save
	"TODO"#stop using resource files here
	i = 0
	file.append("::MESH::")
	while i < used_meshes.size():
		if not assets_used.has(used_meshes[i]):
			assets_used.append(used_meshes[i])
		file.append(separator.join(SaveUtils.mesh_serialize(used_meshes[i])))
		i = i + 1
	
	
	#part data
	i = 0
	file.append("::MODEL::")
	while i < selected_parts_array.size():
		file.append(separator.join(SaveUtils.part_serialize(selected_parts_array[i], color_to_int_mapping, material_name_to_int_mapping, mesh_to_int_mapping)))
		i = i + 1
	
	
	#package everything up
	SaveUtils.data_zip(assets_used, file, filepath, name)


static func load_model(filepath : String, name : String):
	#no mappings required as the indices are already stored
	var used_colors : Array[Color] = []
	var used_materials : Array[Material] = []
	var used_meshes : Array[Mesh] = []
	var file : PackedStringArray = []
	var i : int = 0
	
	file = SaveUtils.data_unzip(filepath, name)
	
	#mode from headers
	var mode : String
	while i < file.size():
		if data_headers.has(file[i]):
			mode = file[i]
			i = i + 1
			continue
		
		if file[i] == "" or file[i] == null or file[i].begins_with("#"):
			i = i + 1
			continue
		
		#processing
		var line = file[i].split(",")
	#load color
		if mode == data_headers[0]:
			used_colors.append(SaveUtils.color_deserialize(line))
			
	#load material
		elif mode == data_headers[1]:
			used_materials.append(SaveUtils.material_deserialize(line))
	#load mesh
		elif mode == data_headers[2]:
			used_meshes.append(SaveUtils.mesh_deserialize(line))
	#load parts
		elif mode == data_headers[3]:
			var new : Part = SaveUtils.part_deserialize(line, used_colors, used_materials, used_meshes)
			
			workspace.add_child(new)
			new.initialize()
		
		i = i + 1


static func export_model():
	
	return


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


#old function
#read colors from file
static func read_colors_and_create_colors(lines : PackedStringArray):
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
		elif data.size() == 3:
			color_array.append(Color8(int(data[0]), int(data[1]), int(data[2])))
		
		i = i + 1
	
	var r_dict : Dictionary = {}
	r_dict.color_array = color_array
	r_dict.color_name_array = color_name_array
	return r_dict
