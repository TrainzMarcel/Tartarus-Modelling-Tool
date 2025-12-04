extends RefCounted
class_name SelectionManager

"TODO"
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


#EXTRA: pivot edit tool data
#global vector pointing of the rotation pivot when pivot mode is active
#this vector stays where it is no matter what is selected, but it does move with the selection
static var pivot_custom_mode_active : bool = false
static var pivot_mesh : MeshInstance3D
#transform local to bounding box which gets recalculated when the selection changes and pivot_custom_mode_active is true
#calculated by using abb.transform.inverse() * pivot_transform
static var pivot_local_transform : Transform3D
#global transform as a global reference point for the pivot and only counts when pivot_custom_mode_active is true
static var pivot_transform : Transform3D
#initial transform which is set each time transform_handle_prepare is called
static var pivot_initial_transform : Transform3D

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

#program_data.json file
static var data_dict_default : Dictionary = {
	"directory_on_last_launch" = "",
	"filenames_of_updated_filepaths" = []
}


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
			first_part_selection_rect = result_parts[-1]
			Main.initial_rotation = result_parts[-1].basis
		
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
	#recalculate pivot offset on selection move
	if WorkspaceManager.pivot_custom_mode_active:
		WorkspaceManager.pivot_transform.origin = WorkspaceManager.pivot_transform.origin + input_absolute - selected_parts_abb.transform.origin
	
	selected_parts_abb.transform.origin = input_absolute 
	var i : int = 0
	while i < selected_parts_array.size():
		selected_parts_array[i].transform.origin = selected_parts_abb.transform.origin + offset_abb_to_selected_array[i]
		selection_box_array[i].transform.origin = selected_parts_array[i].transform.origin
		i = i + 1
	
	#move transform handles with selection
	selection_moved = true
	


#rotation only
"TODO"#parameterize everything for clarity and to prevent bugs
"TODO"#check and ensure numerical stability
#pivot point is local to the selection bounding box (x 0.5 means 0.5 to the right of the abb)
static func selection_rotate(rotated_basis : Basis, local_pivot_point : Vector3 = Vector3.ZERO):
	var original_basis : Basis = Basis(selected_parts_abb.transform.basis)
	#calculate difference between original basis and new basis
	var difference : Basis = rotated_basis * original_basis.inverse()
	var global_pivot_point = selected_parts_abb.transform.basis * local_pivot_point
	#rotate pivot vector
	var global_pivot_point_rotated = difference * global_pivot_point 
	drag_offset = difference * drag_offset
	
	#rotate abb
	if WorkspaceManager.pivot_custom_mode_active:
		selected_parts_abb.transform.origin = selected_parts_abb.transform.origin + global_pivot_point
		selected_parts_abb.transform.basis = difference * selected_parts_abb.transform.basis
		selected_parts_abb.transform.origin = selected_parts_abb.transform.origin - global_pivot_point_rotated
		#recalculate local pivot transform
		WorkspaceManager.pivot_transform = WorkspaceManager.selected_parts_abb.transform * WorkspaceManager.pivot_local_transform
	else:
		selected_parts_abb.transform.basis = difference * selected_parts_abb.transform.basis
	
	#rotate the offset_abb_to_selected_array vector by the difference between the
	#original basis and rotated basis
	var i : int = 0
	while i < selected_parts_array.size():
		#rotate offset_dragged_to_selected_array vector by the difference basis
		offset_abb_to_selected_array[i] = difference * offset_abb_to_selected_array[i]
		#move part to ray_result.position for easier pivoting (drag-specific functionality)
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
"TODO"# move both functions to DataUtils
static func refresh_offset_abb_to_selected_array():
	var i : int = 0
	offset_abb_to_selected_array.clear()
	while i < selected_parts_array.size():
		offset_abb_to_selected_array.append(selected_parts_array[i].transform.origin - selected_parts_abb.transform.origin)
		i = i + 1
