extends Node3D
class_name Main

"TODO"#decide whether the word "is" should be a standard part of naming bools
"TODO"#move all transformhandle configuration code into one place

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
#local vector pointing from bounding box to rotation pivot
var selected_parts_abb_pivot : Vector3 = Vector3.ZERO

#centralized tool identifier
enum SelectedToolEnum
{
	none,
	t_drag,
	t_move,
	t_rotate,
	t_scale,
	t_color,
	t_material,
	t_lock
}
#gets set in on_tool_selected
var selected_tool : SelectedToolEnum = SelectedToolEnum.none
#gets set in on_color_selected
var selected_color : Color

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
@export var part_spawn_distance : float = 4
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
#contains the transformhandles of any currently selected tool
var selected_tool_handle_array : Array[TransformHandle]


#conditionals-------------------------------------------------------------------
var mouse_button_held : bool = false
#gets set in on_tool_selected
#gets set in on_tool_selected
var is_drag_tool : bool = false
#this bool is meant for non drag tools which dont need selecting but still need hovering and clicking functionality
var is_hovering_allowed : bool = false
#this bool is meant for drag tools, if this is enabled then hovering_allowed is also enabled
var is_selecting_allowed : bool = false


# Called when the node enters the scene tree for the first time.
func _ready():
	OS.low_processor_usage_mode = true
	ui_node.initialize(
		on_spawn_pressed,
		on_tool_selected,
		on_snap_increment_set,
		on_snap_increment_doubled_or_halved,
		on_local_transform_active_set,
		on_snapping_active_set,
		on_color_selected
		)
	
	cam.initialize(UI.camera_speed_label, UI.camera_zoom_label)
	TransformHandleUtils.initialize_transform_handle_root(transform_handle_root)
	
	
	HyperDebug.initialize(debug_active, workspace)
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
	#hovering is not allowed if cursor is captured or over ui
	is_hovering_allowed = is_selecting_allowed
	is_hovering_allowed = is_hovering_allowed and Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED
	is_hovering_allowed = is_hovering_allowed and not is_ui_hovered
	
	
#do raycasting, set hovered_handle
#if handle wasnt found, raycast and set hovered_part, render selectionbox around hovered_part
#transform handles take priority over parts
	if event is InputEventMouseMotion:
		if is_hovering_allowed:
			print("is_hovering_allowed   ", is_hovering_allowed)
			print("is_selecting_allowed  ", is_selecting_allowed)
			print("is_drag_tool          ", is_drag_tool)
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
#selection and non-drag-tool logic (to be put in another function maybe)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
		#lmb down
			if event.pressed:
				var is_part_hovered : bool = Main.safety_check(hovered_part)
		#if part is hovered
				if is_part_hovered and is_selecting_allowed:
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
				
		#parts hovered but selecting not allowed
				elif is_part_hovered and not is_selecting_allowed:
					
					if selected_tool == SelectedToolEnum.t_material:
						hovered_part.part_material = preload("res://editor/data_editor/materials/mat_1.tres")
					
					if selected_tool == SelectedToolEnum.t_color:
						hovered_part.part_color = selected_color
				
				
	#lmb up
			else:
				pass
			
	#post click checks
			"TODO"#preceding part of program needs to be restructured to eliminate redundancies
			#mainly as the selection needs to be updated before abb gets updated, as calculate_extents depends on the selection
			if selected_parts_array.size() > 0 and is_selecting_allowed:
				
				selected_parts_abb = SnapUtils.calculate_extents(selected_parts_abb, selected_parts_array[0], selected_parts_array)
				
				var d_input = {}
				d_input.transform = selected_parts_abb.transform
				d_input.extents = selected_parts_abb.extents
				HyperDebug.actions.abb_visualize.do(d_input)
				
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
				"TODO"#for some reason with some multi selections the bounding box gets resized, investigate this bug
				if Input.is_key_pressed(KEY_R):
					initial_rotation = initial_rotation.rotated(ray_result.normal, PI * 0.5)
					#use initial_rotation so that dragged_part doesnt continually rotate further 
					#from its initial rotation after being dragged over multiple off-grid parts
					var rotated_basis : Basis = SnapUtils.snap_rotation(initial_rotation, ray_result)
					
					HyperDebug.actions.basis_print.do("------------------------------------------------------------------")
					HyperDebug.actions.basis_print.do("basis before snap " + str(selected_parts_abb.transform.basis))
					HyperDebug.actions.basis_print.do("rotated_basis     " + str(rotated_basis))
					apply_snap_rotation(rotated_basis, dragged_part.basis)
					HyperDebug.actions.basis_print.do("basis after snap  " + str(selected_parts_abb.transform.basis))
					
					#somehow, selected_parts_abb.transform.basis changes from here to the ------- in the next iteration
					apply_snap_position(SnapUtils.snap_position(
						ray_result,
						dragged_part,
						hovered_part,
						selected_parts_abb,
						drag_offset,
						positional_snap_increment,
						snapping_active
					))
				
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
					apply_snap_position(SnapUtils.snap_position(
						ray_result,
						dragged_part,
						hovered_part,
						selected_parts_abb,
						drag_offset,
						positional_snap_increment,
						snapping_active
					))
	
	
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
					apply_snap_position(SnapUtils.snap_position(
						ray_result,
						dragged_part,
						hovered_part,
						selected_parts_abb,
						drag_offset,
						positional_snap_increment,
						snapping_active
					))
		
		"TODO"#get done today: refactor this a little, add backward movement limit for scaling, add relative local transform msg
		#transform handle dragging under this if
		#handles do not need a "canvas" collider to be dragged over
		#so theres no check of hovered_part or hovered_handle
		if mouse_button_held and is_selecting_allowed:
			if Main.safety_check(dragged_handle):
				var result : Dictionary = TransformHandleUtils.transform(
					dragged_handle,
					transform_handle_root,
					abb_initial_extents,
					abb_initial_transform,
					initial_event,
					event,
					cam,
					positional_snap_increment,
					rotational_snap_increment,
					snapping_active,
					Input.is_key_pressed(KEY_CTRL),
					Input.is_key_pressed(KEY_SHIFT)
					)
				
				
				"TODO"#figure out correct positioning direction and move this code into TransformHandleUtils.transform()
				if result.modify_scale:
					selected_parts_array[0].part_scale = result.part_scale
					selected_parts_abb.extents = result.part_scale
					Main.redraw_all_selection_boxes(selection_box_array)
					UI.msg_label.text = "Scale: " + str(selected_parts_array[0].part_scale)
					
				if result.modify_position:
					apply_snap_position(result.transform.origin)
					if not result.modify_scale:
						UI.msg_label.text = "Translation: " + str(result.scalar * dragged_handle.direction_vector)
					
				if result.modify_rotation:
					if local_transform_active:
						apply_snap_rotation(result.transform.basis, selected_parts_abb.transform.basis)
					else:
						var global_direction_vector : Vector3 = transform_handle_root.basis * dragged_handle.direction_vector
						apply_snap_rotation(abb_initial_transform.basis.rotated(global_direction_vector, result.angle_relative), selected_parts_abb.transform.basis)
					UI.msg_label.text = "Angle: " + str(rad_to_deg(result.angle_relative))
				
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
func apply_snap_position(input_absolute : Vector3):
	selected_parts_abb.transform.origin = input_absolute
	transform_handle_root.transform.origin = selected_parts_abb.transform.origin
	
	var d_input = {}
	d_input.transform = selected_parts_abb.transform
	d_input.extents = selected_parts_abb.extents
	HyperDebug.actions.abb_visualize.do(d_input)
	
	var i : int = 0
	while i < selected_parts_array.size():
		selected_parts_array[i].global_position = selected_parts_abb.transform.origin + offset_abb_to_selected_array[i]
		selection_box_array[i].global_transform = selected_parts_array[i].global_transform
		i = i + 1


#rotation only
"TODO"#parameterize everything for clarity and to prevent bugs
func apply_snap_rotation(
		rotated_basis : Basis,
		original_basis : Basis):#,
#		offset_abb_to_selected_array : Array[Vector3],
#		selected_parts_array : Array[Part],
#		selection_box_array : Array[SelectionBox]
#	):
	
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
		if not ray_result.is_empty():
			selected_parts_array[i].global_position = ray_result.position
		else:
			selected_parts_array[i].global_position = selected_parts_abb.transform.origin
		
		
		#rotate this part
		selected_parts_array[i].basis = difference * selected_parts_array[i].basis
		
		#move it back out along the newly rotated offset_dragged_to_selected_array vector
		#dragged_part is always first entry in the selected_parts_array
		selected_parts_array[i].global_position = selected_parts_abb.transform.origin + offset_abb_to_selected_array[i]
		
		selection_box_array[i].global_transform = selected_parts_array[i].global_transform
		i = i + 1
	
	
	
	#rotate abb
	selected_parts_abb.transform.basis = difference * selected_parts_abb.transform.basis
	
	
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
	var mat : StandardMaterial3D = preload("res://editor/classes/selection_box/selection_box_mat.res")
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
		selected_tool,
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
	selected_tool = r_dict.selected_tool
	selected_parts_array = r_dict.selected_parts_array
	offset_abb_to_selected_array = r_dict.offset_abb_to_selected_array


func on_spawn_pressed(button):
	var new_part : Part = Part.new()
	workspace.add_child(new_part)
	new_part.global_position = cam.global_position + part_spawn_distance * -cam.basis.z


func on_color_selected(button):
	selected_color = button.modulate


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
