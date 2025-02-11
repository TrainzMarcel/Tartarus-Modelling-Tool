extends Node3D
class_name Main

"TODO"#decide whether the word "is" should be a standard part of naming bools
"TODO"#move all transformhandle configuration code into one place
#including the second camera (maybe?)
#theres string identifiers, enums for what action a handle does (possibly redundant but possibly not)
#and then theres also transform_handle_root.tool_handle_array.rotate scale move blablabla 

#maybe reorganize transformhandleroot structure
"TODO"#find a good way to group variables
"TODO"#rework snap_utils.snap_position to snap x and y by closest corner

					#future idea: put selection box around selected_parts_abb as a visual cue (still keeping the selectionboxes of individual parts)
					#future idea 2: recolor selection box to red if 2 selected parts are overlapping perfectly

"TODO"#once transform_tools gets merged, work on hyperdebug.gd
#which will dynamically bind all the debug functions to minimize overhead
#when debugging isnt active

"TODO" #CONTROL F TODO

#all related todos eliminated (for the time being)
#   Main
# x UI
#   SnapUtils
#   HyperDebug
#   ABB
#   TransformHandle
#   TransformHandleRoot
#   TransformHandleUtils


@export_category("Debug")
@export var debug_active : bool = false
@export var d_vector : Array[DebugVector3D]

#dependencies
@export_category("Dependencies")
@export var cam : FreeLookCamera
@export var second_cam : Camera3D
@export var workspace : Node
@export var transform_handle_root : TransformHandleRoot
@export var hover_selection_box : SelectionBox
@export var ui_node : UI

#overlapping data (used by both dragging and handles)--------------------------------
var positional_snap_increment : float = 0.1
var rotational_snap_increment : float = 15
var snapping_active : bool = true
#bounding box of selected parts for positional snapping
var selected_parts_abb : ABB = ABB.new()


#dragging data------------------------------------------------------------------
#raw ray result
var ray_result : Dictionary
var dragged_part : Part
var hovered_part : Part
#purely rotational basis set from start of drag as a reference for snapping
var initial_rotation : Basis
#!!!selected_parts_array, offset_dragged_to_selected_array and selection_box_array are parallel arrays!!!
var selected_parts_array : Array[Part] = []
var offset_abb_to_selected_array : Array[Vector3] = []
#offset from the dragged parts position to the raycast hit position
var selection_box_array : Array[SelectionBox] = []
@export_category("Tweakables")
#length of raycast for dragging
@export var raycast_length : float = 1024
#vector pointing from ray_result.position to selected_parts_abb
var drag_offset : Vector3


#transform handle data----------------------------------------------------------
#store handle which is being dragged, in case mouse moves off handle while dragging
var dragged_handle : TransformHandle
#hovered handle to set dragged handle when the user clicks
var hovered_handle : TransformHandle
#hovered handle from last input frame
var prev_hovered_handle : TransformHandle
#initial transform to make snapping work with transformhandles
var abb_initial_transform : Transform3D
var abb_initial_extents : Vector3
var initial_event : InputEvent
#determines if transform axes will be local to the selection or global
var local_transform_active : bool = false
#fixed distance of camera to transformhandleroot
@export var transform_handle_scale : float = 8


#conditionals-------------------------------------------------------------------
var mouse_button_held : bool = false
#gets set in on_tool_selected
#contains the transformhandles of any currently selected tool
var selected_tool_handle_array : Array[TransformHandle]
#gets set in on_tool_selected
var is_drag_tool : bool = true
#this bool is meant for non drag tools which dont need selecting but still need hovering and clicking functionality
var is_hovering_allowed : bool = true
#this bool is meant for drag tools, if this is enabled then hovering_allowed is also enabled
var is_selecting_allowed : bool = true


# Called when the node enters the scene tree for the first time.
func _ready():
	OS.low_processor_usage_mode = true
	#HyperDebug.initialize()
	ui_node.initialize(on_tool_selected, on_snap_increment_set, on_snap_increment_doubled_or_halved, on_local_transform_active_set, on_snapping_active_set)
	cam.initialize(UI.camera_speed_label, UI.camera_zoom_label)
	TransformHandleUtils.initialize_transform_handle_root(transform_handle_root)
	
	"DEBUG"
	selected_parts_abb.debug_mesh = $MeshInstance3D
	#for convienience sakes so my console isnt covered up every time i start the software
	get_window().position = Vector2(1920*0.5 - 1152 * 0.3, 0)


# Called every input event.
func _input(event):
#start by setting all control variables
	#check validity of selecting
	#is_drag_tool is set by func on_tool_selected
	var is_ui_hovered : bool = ui_hover_check(UI.no_drag_ui)
	is_selecting_allowed = is_drag_tool and not is_ui_hovered
	is_selecting_allowed = is_selecting_allowed and Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED
	
	#if selecting is allowed, hovering is allowed as well
	if is_selecting_allowed:
		is_hovering_allowed = true
	else:
		#hovering is not allowed if cursor is captured or over ui
		is_hovering_allowed = Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED
		is_hovering_allowed = is_hovering_allowed and not is_ui_hovered
	
	
#do raycasting, set hovered_handle
#if handle wasnt found, raycast and set hovered_part, render selectionbox around hovered_part
#transform handles take priority over parts
	if event is InputEventMouseMotion:
		if is_hovering_allowed:
			hovered_handle = handle_hover_check()
			#handle wasnt detected
			if not Main.safety_check(hovered_handle) and not Main.safety_check(dragged_handle):
				
				if Main.safety_check(prev_hovered_handle):
					TransformHandleUtils.set_transform_handle_highlight(prev_hovered_handle, false, false)
				
				
				
				hovered_part = part_hover_check()
				part_hover_selection_box(hovered_part)
			#handle was detected
			else:
				
				if not mouse_button_held:
					TransformHandleUtils.set_transform_handle_highlight(hovered_handle, false, true)
				
				
				#set hovered_part to null as mouse is no longer hovering over a part
				hovered_part = null
	
	
#set dragged_part, recalculate all offset_dragged_to_selected_array vectors and bounding box on new click
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				mouse_button_held = true
				#if there is a mouse click off ui, release focus
				if not is_ui_hovered:
					var ui_focus = get_viewport().gui_get_focus_owner()
					if Main.safety_check(ui_focus):
						ui_focus.release_focus()
				
				
				if Main.safety_check(hovered_part):
					initial_rotation = hovered_part.basis
					dragged_part = hovered_part
					#selected_parts_abb = SnapUtils.calculate_extents(selected_parts_abb, dragged_part, selected_parts_array)
					#Main.set_transform_handle_root_position(transform_handle_root, selected_parts_abb.transform, local_transform_active, selected_tool_handle_array)
					#var i : int = 0
					#offset_abb_to_selected_array.clear()
					#while i < selected_parts_array.size():
					#	offset_abb_to_selected_array.append(selected_parts_array[i].global_position - selected_parts_abb.transform.origin)
					#	i = i + 1
				
				
				#if handle is detected, try setting dragged_handle
				if Main.safety_check(hovered_handle):
					#ONLY set dragged_handle if its null
					#if not Main.safety_check(dragged_handle):
						dragged_handle = hovered_handle
						abb_initial_transform = selected_parts_abb.transform
						abb_initial_extents = selected_parts_abb.extents
						initial_event = event
						TransformHandleUtils.set_transform_handle_highlight(dragged_handle, true)
						#hide hover selection_box because it does not move with transforms
						hover_selection_box.visible = false
				
			else:
				dragged_part = null
				if Main.safety_check(dragged_handle):
					TransformHandleUtils.set_transform_handle_highlight(dragged_handle, false)
				if Main.safety_check(hovered_handle):
					TransformHandleUtils.set_transform_handle_highlight(hovered_handle, false, true)
					
				dragged_handle = null
				mouse_button_held = false
	
	
#selection behavior:
#if click on unselected part, set it as the selection (array with only that part, discard any prior selection)
#if click on unselected part while shift is held, append to selection
#if click on part in selection while shift is held, remove from selection
#if click on nothing, clear selection array
#selection logic (to be put in another function maybe)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
		#lmb down
			if event.pressed:
		#if part is hovered
				if Main.safety_check(hovered_part) and is_selecting_allowed:
				#hovered part is in selection
					if selected_parts_array.has(hovered_part):
					#shift is held
						if Input.is_key_pressed(KEY_SHIFT):
							#patch to stop dragging when holding shift and
							#dragging on an already selected part
							if selected_parts_array[selected_parts_array.find(hovered_part)] == dragged_part:
								dragged_part = null
							delete_selection_box(hovered_part)
							#erase the same index as hovered_part
							offset_abb_to_selected_array.remove_at(selected_parts_array.find(hovered_part))
							selected_parts_array.erase(hovered_part)
				#hovered part is not in selection
					else:
					#shift is held
						if Input.is_key_pressed(KEY_SHIFT):
							selected_parts_array.append(hovered_part)
							part_instance_selection_box(hovered_part)
							offset_abb_to_selected_array.append(hovered_part.global_position - dragged_part.global_position)
					#shift is unheld
						else:
							selected_parts_array = [hovered_part]
							offset_abb_to_selected_array = [hovered_part.global_position - dragged_part.global_position]
							Main.clear_all_selection_boxes(selection_box_array)
							part_instance_selection_box(hovered_part)
		#no parts hovered
				elif is_selecting_allowed:
					#shift is unheld
					if not Input.is_key_pressed(KEY_SHIFT):
						if not Main.safety_check(hovered_handle):
							selected_parts_array.clear()
							Main.clear_all_selection_boxes(selection_box_array)
							offset_abb_to_selected_array.clear()
					
					
	#lmb up
			else:
				pass
			
	#post click checks
			"TODO"#preceding part of program needs to be restructured to eliminate redundancies
			#mainly as the selection needs to be updated before abb gets updated, as calculate_extents depends on the selection
			if selected_parts_array.size() > 0 and is_selecting_allowed:
				
				selected_parts_abb = SnapUtils.calculate_extents(selected_parts_abb, selected_parts_array[0], selected_parts_array)
				var i : int = 0
				offset_abb_to_selected_array.clear()
				while i < selected_parts_array.size():
					offset_abb_to_selected_array.append(selected_parts_array[i].global_position - selected_parts_abb.transform.origin)
					i = i + 1
				
				if not ray_result.is_empty():
					drag_offset = selected_parts_abb.transform.origin - ray_result.position
				
				Main.set_transform_handle_root_position(transform_handle_root, selected_parts_abb.transform, local_transform_active, selected_tool_handle_array)
				TransformHandleUtils.set_tool_handle_array_active(selected_tool_handle_array, true)
			
			if selected_parts_array.size() == 0 and is_selecting_allowed:
				TransformHandleUtils.set_tool_handle_array_active(selected_tool_handle_array, false)
	
	
#change initial_transform on r or t press
	if Input.is_key_pressed(KEY_R) or Input.is_key_pressed(KEY_T):
		if event.is_pressed() and not event.is_echo() and not ray_result.is_empty():
			if Main.safety_check(hovered_part) and Main.safety_check(dragged_part) and is_selecting_allowed:
				#rotate clockwise around normal vector
				if Input.is_key_pressed(KEY_R):
					initial_rotation = initial_rotation.rotated(ray_result.normal, PI * 0.5)
					#use initial_rotation so that dragged_part doesnt continually rotate further 
					#from its initial rotation after being dragged over multiple off-grid parts
					var rotated_basis : Basis = SnapUtils.snap_rotation(initial_rotation, ray_result)
					apply_snap_rotation(rotated_basis, dragged_part.basis)
					var result = SnapUtils.snap_position(ray_result, dragged_part, hovered_part, selected_parts_abb, drag_offset, positional_snap_increment, snapping_active)
					apply_snap_position(result.absolute, result.relative)
					
				#rotate around part vector which is closest to cam.basis.x
				if Input.is_key_pressed(KEY_T):
					var r_dict = SnapUtils.find_closest_vector_abs(initial_rotation, cam.basis.x, true)
					if r_dict.vector.dot(cam.basis.x) < 0:
						r_dict.vector = -r_dict.vector
					initial_rotation = initial_rotation.rotated(r_dict.vector.normalized(), PI * 0.5)
					#use initial_rotation so that dragged_part doesnt continually rotate further 
					#from its initial rotation after being dragged over multiple off-grid parts
					var rotated_basis : Basis = SnapUtils.snap_rotation(initial_rotation, ray_result)
					apply_snap_rotation(rotated_basis, dragged_part.basis)
					var result = SnapUtils.snap_position(ray_result, dragged_part, hovered_part, selected_parts_abb, drag_offset, positional_snap_increment, snapping_active)
					apply_snap_position(result.absolute, result.relative)
	
	
#dragging (parts AND transform handles) happens here
	if event is InputEventMouseMotion:
		#parts dragging under this if
		if mouse_button_held and not ray_result.is_empty() and is_selecting_allowed:
			if Main.safety_check(dragged_part):
				if Main.safety_check(hovered_part):
					if not SnapUtils.part_rectilinear_alignment_check(dragged_part, hovered_part):
						#use initial_rotation so that dragged_part doesnt continually rotate further 
						#from its initial rotation after being dragged over multiple off-grid parts
						var rotated_basis : Basis = SnapUtils.snap_rotation(initial_rotation, ray_result)
						apply_snap_rotation(rotated_basis, dragged_part.basis)
					
					#set positions according to offset_dragged_to_selected_array and where the selection is being dragged (ray_result.position)
					var result = SnapUtils.snap_position(ray_result, dragged_part, hovered_part, selected_parts_abb, drag_offset, positional_snap_increment, snapping_active)
					apply_snap_position(result.absolute, result.relative)
		
		#transform handle dragging under this if
		#handles do not need a "canvas" collider to be dragged over
		#so theres no check of hovered_part or hovered_handle
		if mouse_button_held and is_selecting_allowed:
			if Main.safety_check(dragged_handle):
				var result : Dictionary = TransformHandleUtils.transform(
					dragged_handle,
					transform_handle_root,
					abb_initial_transform,
					initial_event,
					event,
					cam,
					[$DebugVector3D3, $DebugVector3D4],
					positional_snap_increment,
					rotational_snap_increment,
					snapping_active
					)
				
				
				if result.modify_scale:
					var global_direction_vector : Vector3 = abb_initial_transform.basis * dragged_handle.direction_vector
					
					#set this with ctrl and shift
					var multiplier = 0.5
					if Input.is_key_pressed(KEY_CTRL):
						multiplier = 0
						result.scalar = result.scalar * 2
					
					
					#result.part_scale = result.scalar * dragged_handle.direction_vector
					
					var local : Vector3 = dragged_handle.direction_vector
					var i = 0
					while i < 3:
						if local[i] < 0 and not Input.is_key_pressed(KEY_SHIFT):
							result.scalar = -result.scalar
						i = i + 1
					
					"TODO"#figure out correct positioning direction and move this code into TransformHandleUtils.transform()
					"TODO"
					var scale_min : Vector3 = abb_initial_extents + result.scalar * local
					var scale_diff : Vector3 = result.scalar * local
					if Input.is_key_pressed(KEY_SHIFT):
						scale_min = abb_initial_extents + abb_initial_extents * result.scalar
						scale_diff = abb_initial_extents * result.scalar
						
					
					i = 0
					while i < 3:
						scale_min[i] = max(scale_min[i], positional_snap_increment)
						i = i + 1
					
					selected_parts_array[0].part_scale = scale_min
					selected_parts_abb.extents = scale_min
					Main.redraw_all_selection_boxes(selection_box_array)
					var scale_diff_global = abb_initial_transform.basis * scale_diff
					
					result.transform.origin = abb_initial_transform.origin + abb_initial_transform.basis * (scale_diff * local * multiplier)
					#control: makes part not move and scale toward both directions
					#shift: makes part scale toward all directions proportionally
					#shift + control: makes part not move and scale toward all directions proportionally
					#if Input.is_key_pressed(KEY_CTRL):
					#	difference_local = difference_local * 2
					#if Input.is_key_pressed(KEY_SHIFT):
					#	pass
					
				if result.modify_position:
					apply_snap_position(result.transform.origin, result.transform.origin)
					
				if result.modify_rotation:
					if local_transform_active:
						apply_snap_rotation(result.transform.basis, selected_parts_abb.transform.basis)
					else:
						var global_direction_vector : Vector3 = transform_handle_root.basis * dragged_handle.direction_vector
						apply_snap_rotation(abb_initial_transform.basis.rotated(global_direction_vector, result.basis_relative), selected_parts_abb.transform.basis)
				
				Main.set_transform_handle_root_position(transform_handle_root, result.transform, local_transform_active, selected_tool_handle_array)
	
	#set previous hovered handle for next input frame
	prev_hovered_handle = hovered_handle
	
	#camera controls
	cam.cam_input(event, second_cam, selected_parts_array, selected_parts_abb, UI.msg_label, UI.camera_zoom_label, UI.camera_speed_label)


func _process(delta : float):
	cam.cam_process(delta, second_cam, transform_handle_root, transform_handle_scale, selected_tool_handle_array, selected_parts_abb)


#returns true if hovering over visible ui
func ui_hover_check(ui_list : Array[Control]):
	for i in ui_list:
		if Rect2(i.global_position, i.size).has_point(get_viewport().get_mouse_position()) and i.visible:
			return true
	return false


#this stuff was ugly so i put them into functions
#collision mask is no longer needed but ill keep it just in case
func raycast(node : Node3D, from : Vector3, to : Vector3, exclude : Array[RID] = [], collision_mask : Array[int] = []):
	var ray_param : PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
	ray_param.from = from
	ray_param.to = to
	ray_param.exclude = exclude
	
	ray_param.collision_mask = SnapUtils.calculate_collision_layer(collision_mask)
	return node.get_world_3d().direct_space_state.intersect_ray(ray_param)


#raycast from cam to where the mouse is pointing, works in ortho mode too
func raycast_mouse_pos(cam : Camera3D, exclude : Array[RID] = [], collision_mask : Array[int] = []):
	#project ray origin simply returns the camera position, EXCEPT,
	#when camera is set to orthogonal
	return raycast(
		cam,
		cam.project_ray_origin(get_viewport().get_mouse_position()),
		cam.project_ray_origin(get_viewport().get_mouse_position()) + 
		cam.project_ray_normal(get_viewport().get_mouse_position()) * raycast_length,
		exclude, collision_mask
	)


#having 2 indents was ugly so i also put this in a function
#also checks for nulls
static func safety_check(instance):
	if is_instance_valid(instance):
		if not instance.is_queued_for_deletion():
			return true
		return false
	return false
#

#returns null or any hovered handle
func handle_hover_check():
	ray_result = raycast_mouse_pos(second_cam, [], [1])
	#make sure were not dragging a part before detecting a handle
	if not ray_result.is_empty() and not Main.safety_check(dragged_part):
		if Main.safety_check(ray_result.collider):
			return ray_result.collider
	return null


#returns null or any hovered part
func part_hover_check():
	#while dragging, exclude selection
	if mouse_button_held and Main.safety_check(dragged_part):
		#exclude selection
		var rids : Array[RID] = []
		for i in selected_parts_array:
			if Main.safety_check(i):
				rids.append(i.get_rid())
		ray_result = raycast_mouse_pos(cam, rids, [1])
	else:
		#if not dragging, do not exclude selection
		ray_result = raycast_mouse_pos(cam, [], [1])
	
	if not ray_result.is_empty():
		if Main.safety_check(ray_result.collider) and ray_result.collider is Part:
			return ray_result.collider
	return null


#position only
func apply_snap_position(absolute : Vector3, relative : Vector3):
	selected_parts_abb.transform.origin = absolute
	transform_handle_root.transform.origin = selected_parts_abb.transform.origin
	
	
	var i : int = 0
	while i < selected_parts_array.size():
		selected_parts_array[i].global_position = selected_parts_abb.transform.origin + offset_abb_to_selected_array[i]
		selection_box_array[i].global_transform = selected_parts_array[i].global_transform
		i = i + 1


#rotation only
func apply_snap_rotation(rotated_basis : Basis, original_basis : Basis):
	#calculate difference between original basis and new basis
	var difference : Basis = rotated_basis * original_basis.inverse()
	drag_offset = difference * drag_offset
	
	#rotate the offset_abb_to_selected_array vector by the difference between the
	#original matrix and rotated matrix
	var i : int = 0
	while i < selected_parts_array.size():
		#rotate offset_dragged_to_selected_array vector by the difference basis
		offset_abb_to_selected_array[i] = difference * offset_abb_to_selected_array[i]
		#move part to ray_result.position for easier pivoting
		if ray_result.is_empty():
			selected_parts_array[i].global_position = selected_parts_abb.transform.origin
		else:
			selected_parts_array[i].global_position = ray_result.position
		
		#rotate this part
		selected_parts_array[i].basis = difference * selected_parts_array[i].basis
		
		#move it back out along the newly rotated offset_dragged_to_selected_array vector
		#dragged_part is always first entry in the selected_parts_array
		selected_parts_array[i].global_position = selected_parts_abb.transform.origin + offset_abb_to_selected_array[i]
		
		selection_box_array[i].global_transform = selected_parts_array[i].global_transform
		i = i + 1
	
	
	
	#the below section takes care of the abb which needs to move with the selection
	#rotate abb
	selected_parts_abb.transform.basis = rotated_basis#difference * selected_parts_abb.transform.basis
	
	#move abb to vector
	#selected_parts_abb.transform.origin = offset_abb_dragged_part + dragged_part.position
	Main.set_transform_handle_root_position(transform_handle_root, selected_parts_abb.transform, local_transform_active, selected_tool_handle_array)


"TODO"#unit test somehow?
func part_hover_selection_box(part : Part):
	if is_hovering_allowed and Main.safety_check(part):
		hover_selection_box.visible = true
		hover_selection_box.global_transform = part.global_transform
		hover_selection_box.box_scale = part.part_scale
	else:
		hover_selection_box.visible = false


#might remove this
#this function was meant to toggle the visibility of selectionboxes but it was unreliable
#func toggle_visibility_selection_box(part : Part, make_visible : bool):
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


#instance and fit selection box to a part as child of part container and add it to the array
func part_instance_selection_box(assigned_part : Part):
	var new : SelectionBox = SelectionBox.new()
	selection_box_array.append(new)
	workspace.add_child(new)
	new.assigned_node = assigned_part
	new.box_scale = assigned_part.part_scale
	new.global_transform = assigned_part.global_transform
	var mat : StandardMaterial3D = preload("res://editor/selection_box/selection_box_mat.res")
	new.material_override = mat


#delete all selection boxes and clear 
static func clear_all_selection_boxes(selection_box_array : Array[SelectionBox]):
	for i in selection_box_array:
		if Main.safety_check(i):
			i.queue_free()
	selection_box_array.clear()


#only used for scale tool
static func redraw_all_selection_boxes(selection_box_array : Array[SelectionBox]):
	for i in selection_box_array:
		if Main.safety_check(i):
			if i.assigned_node is Part:
				i.box_scale = i.assigned_node.part_scale
				i.box_update()


#delete selection box whos assigned_node matches the parameter
func delete_selection_box(assigned_part : Node3D):
	for i in selection_box_array:
		if Main.safety_check(i):
			if i.assigned_node == assigned_part:
				selection_box_array.erase(i)
				i.queue_free()
				return


static func set_transform_handle_root_position(root : TransformHandleRoot, new_transform : Transform3D, local_transform_active : bool, selected_tool_handle_array):
	var must_stay_aligned_to_part : bool = false
	if not selected_tool_handle_array.is_empty():
		must_stay_aligned_to_part = selected_tool_handle_array[0].handle_force_follow_abb_surface
	
	if local_transform_active or must_stay_aligned_to_part:
		root.transform = new_transform
	else:
		root.transform.origin = new_transform.origin
		root.transform.basis = Basis.IDENTITY


#ui events------------------------------------------------------------------------------------------
#set selected state and is_drag_tool
"TODO"#put all the things one has to edit to add a new tool to transformhandleroot, into one file
func on_tool_selected(button):
	var r_dict = UI.select_tool(
		button,
		selected_tool_handle_array,
		is_drag_tool,
		transform_handle_root,
		selected_parts_abb,
		local_transform_active,
		selected_parts_array,
		selection_box_array,
		offset_abb_to_selected_array
		)
	
	selected_tool_handle_array = r_dict.selected_tool_handle_array
	is_drag_tool = r_dict.is_drag_tool
	selected_parts_array = r_dict.selected_parts_array
	offset_abb_to_selected_array = r_dict.offset_abb_to_selected_array


func on_snap_increment_set(new, line_edit):
	if line_edit == UI.l_positional_snap_increment:
		positional_snap_increment = float(line_edit.text)
	elif line_edit == UI.l_rotational_snap_increment:
		rotational_snap_increment = float(line_edit.text)
	line_edit.release_focus()


func on_snap_increment_doubled_or_halved(button):
	if button == UI.b_position_snap_double:
		positional_snap_increment = positional_snap_increment * 2
	else:
		positional_snap_increment = positional_snap_increment * 0.5
	
	UI.l_positional_snap_increment.text = str(positional_snap_increment)


func on_local_transform_active_set(active):
	local_transform_active = active
	Main.set_transform_handle_root_position(transform_handle_root, selected_parts_abb.transform, local_transform_active, selected_tool_handle_array)


func on_snapping_active_set(active):
	snapping_active = active
