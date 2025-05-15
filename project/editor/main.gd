extends Node3D
class_name Main

"TODO"#decide whether the word "is" should be a standard part of naming bools

"TODO"#find a good way to group variables
"TODO"#rework snap_utils.snap_position to snap x and y by closest corner

#future idea: put selection box around selected_parts_abb as a visual cue (still keeping the selectionboxes of individual parts)
#future idea 2: recolor selection box to red if 2 selected parts are overlapping perfectly

"TODO"#for tomorrow 15.5.: implement all ctrl + key functions
#including undo and redo
#that OR fix snapping, scaling and rest of transform code
#pivot move tool
#also implement selection box coloring depending on tool
#delete tool
#add events to open document displays
"TODO"#add is_hover_tool
"TODO"#put all the things one has to edit to add a new tool to transformhandleroot into one file (if possible)
#this would involve creating a centralized data object array to hold the properties of each tool
#as well as making a mapping for ui buttons -> tool data object


"TODO" #CONTROL F TODO

#all related todos eliminated (for the time being)
#   Main
# x EditorUI
#   SnapUtils
#   HyperDebug
# x ABB
# x TransformHandle
# x TransformHandleRoot
#   TransformHandleUtils


@export_category("Debug")
@export var debug_active : bool = false

#dependencies
@export_category("Dependencies")
@export var e_cam : FreeLookCamera
static var cam : FreeLookCamera
@export var second_cam : Camera3D
@export var e_workspace : Node
@export var e_transform_handle_root : TransformHandleRoot
static var transform_handle_root : TransformHandleRoot
@export var hover_selection_box : SelectionBox
@export var ui_node : EditorUI


#overlapping data (used by both dragging and handles)--------------------------------
static var positional_snap_increment : float = 0.1
static var rotational_snap_increment : float = 15
static var snapping_active : bool = true
#
static var drag_confirmed : bool = false
var initial_drag_event : InputEvent

#bounding box of selected parts for positional snapping
static var selected_parts_abb : ABB = ABB.new()
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
	t_delete,
	t_lock
}
#gets set in MainUIEvents.select_tool
static var selected_tool : SelectedToolEnum = SelectedToolEnum.none


#dragging data------------------------------------------------------------------
#raw ray result
var ray_result : Dictionary
var dragged_part : Part
var hovered_part : Part
#purely rotational basis set from start of drag as a reference for snapping
var initial_rotation : Basis


#@export_category("Tweakables")
#how many units away a part spawns if theres no parts in front of the raycast
static var part_spawn_distance : float = 4
#length of raycast for dragging
static var raycast_length : float = 1024
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
var initial_handle_event : InputEvent
#determines if transform axes will be local to the selection or global
static var local_transform_active : bool = false
#fixed distance of camera to transformhandleroot
@export var transform_handle_scale : float = 8
#contains the transformhandles of any currently selected tool
static var selected_tool_handle_array : Array[TransformHandle]


#conditionals-------------------------------------------------------------------
#main override for when ui like a document view or an asset menu or a file explorer is open
static var is_input_active : bool = true

var mouse_button_held : bool = false
#gets set in on_tool_selected
static var is_drag_tool : bool = false
#this bool is meant for non drag tools which dont need selecting but still need hovering and clicking functionality
var is_hovering_allowed : bool = false
#this bool is meant for drag tools, if this is enabled then hovering_allowed is also enabled
var is_selecting_allowed : bool = false


# Called when the node enters the scene tree for the first time.
func _ready():
	OS.low_processor_usage_mode = true
	
	WorkspaceManager.initialize(e_workspace, hover_selection_box)
	transform_handle_root = e_transform_handle_root
	cam = e_cam
	
	#parameterized signals to make them more explicit and visible
	ui_node.initialize(
	WorkspaceManager.part_spawn,
	MainUIEvents.select_tool,
	MainUIEvents.on_snap_button_pressed,
	MainUIEvents.on_snap_text_changed,
	MainUIEvents.on_local_transform_active_set,
	MainUIEvents.on_snapping_active_set,
	MainUIEvents.on_color_selected,
	MainUIEvents.on_material_selected,
	MainUIEvents.on_part_type_selected,
	MainUIEvents.on_top_bar_id_pressed
	)
	
	cam.initialize(EditorUI.l_camera_speed)
	TransformHandleUtils.initialize_transform_handle_root(transform_handle_root)
	
	HyperDebug.initialize(debug_active, e_workspace)
	#for convenience sakes so my console isnt covered up every time i start the software
	get_window().position = Vector2(1920*0.5 - 1152 * 0.3, 0)


# Called every input event.
func _input(event):
	if ui_menu_block_check(EditorUI.ui_menu) or not is_input_active:
		return
#start by setting all control variables
	#check validity of selecting
	#is_drag_tool is set by func on_tool_selected
	var is_ui_hovered : bool = ui_hover_check(EditorUI.ui_no_drag)
	is_selecting_allowed = is_drag_tool and not is_ui_hovered
	is_selecting_allowed = is_selecting_allowed and Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED
	
	#if selecting is not allowed, hovering can still be allowed
	#hovering is not allowed if cursor is captured or over ui
	#is_hovering_allowed = is_selecting_allowed
	is_hovering_allowed = Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED
	is_hovering_allowed = is_hovering_allowed and not is_ui_hovered
	print(is_hovering_allowed)
	
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
				WorkspaceManager.selection_box_hover_on_part(hovered_part, is_hovering_allowed)
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
				#important control variable
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
					initial_handle_event = event
					TransformHandleUtils.set_transform_handle_highlight(dragged_handle, true, false)
					#hide hover selection_box because it does not move with transforms
					hover_selection_box.visible = false
				
			else:
				dragged_part = null
				if Main.safety_check(dragged_handle):
					TransformHandleUtils.set_transform_handle_highlight(dragged_handle, false, false)
				if Main.safety_check(hovered_handle):
					TransformHandleUtils.set_transform_handle_highlight(hovered_handle, false, true)
					
				dragged_handle = null
				mouse_button_held = false
				#drag has a tolerance of a few pixels before it starts
				drag_confirmed = false
	
	
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
					if WorkspaceManager.selected_parts_array.has(hovered_part):
					#shift is held
						if Input.is_key_pressed(KEY_SHIFT):
							#patch to stop dragging when holding shift and
							#dragging on an already selected part
							if WorkspaceManager.selected_parts_array.has(hovered_part) and hovered_part == dragged_part:
								dragged_part = null
							WorkspaceManager.selection_remove_part(hovered_part)
				#hovered part is not in selection
					else:
					#shift is held
						if Input.is_key_pressed(KEY_SHIFT):
							WorkspaceManager.selection_add_part(hovered_part, dragged_part)
						else:
							WorkspaceManager.selection_set_to_part(hovered_part, dragged_part)
		#no parts hovered
				elif is_selecting_allowed:
					#shift is unheld
					if not Input.is_key_pressed(KEY_SHIFT):
						if not Main.safety_check(hovered_handle):
							WorkspaceManager.selection_clear()
				
		#parts hovered but selecting not allowed
		#handle hover-only tools
				elif is_part_hovered and not is_selecting_allowed:
					
					if selected_tool == SelectedToolEnum.t_material:
						hovered_part.part_material = WorkspaceManager.selected_material
					
					if selected_tool == SelectedToolEnum.t_color:
						hovered_part.part_color = WorkspaceManager.selected_color
					
					if selected_tool == SelectedToolEnum.t_delete:
						hovered_part.queue_free()
				
	#lmb up
			else:
				pass
			
	#post click checks
			"TODO"#preceding part of program needs to be restructured to eliminate redundancies
			#mainly as the selection array needs to be updated before abb gets updated, as calculate_extents depends on the selection array
			#
			if WorkspaceManager.selected_parts_array.size() > 0 and is_selecting_allowed:
				
				#refresh bounding box
				selected_parts_abb = SnapUtils.calculate_extents(selected_parts_abb, WorkspaceManager.selected_parts_array[0], WorkspaceManager.selected_parts_array)
				
				#debug
				var d_input = {}
				d_input.transform = selected_parts_abb.transform
				d_input.extents = selected_parts_abb.extents
				HyperDebug.actions.abb_visualize.do(d_input)
				
				#refresh offset abb to selected array
				WorkspaceManager.refresh_offset_abb_to_selected_array(selected_parts_abb)
				
				if not ray_result.is_empty():
					drag_offset = selected_parts_abb.transform.origin - ray_result.position
				
				Main.set_transform_handle_root_position(transform_handle_root, selected_parts_abb.transform, local_transform_active, selected_tool_handle_array)
				TransformHandleUtils.set_tool_handle_array_active(selected_tool_handle_array, true)
			
			if WorkspaceManager.selected_parts_array.size() == 0 and is_selecting_allowed:
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
					WorkspaceManager.apply_snap_position(SnapUtils.snap_position(
						ray_result,
						dragged_part,
						hovered_part,
						selected_parts_abb,
						drag_offset,
						positional_snap_increment,
						snapping_active
					), selected_parts_abb, transform_handle_root)
				
				#rotate around part vector which is closest to cam.basis.x
				if Input.is_key_pressed(KEY_T):
					var r_dict = SnapUtils.find_closest_vector_abs(initial_rotation, cam.basis.x, true)
					#flip vector if they are opposed
					if r_dict.vector.dot(cam.basis.x) < 0:
						r_dict.vector = -r_dict.vector
					initial_rotation = initial_rotation.rotated(r_dict.vector.normalized(), PI * 0.5)
					#use initial_rotation so that dragged_part doesnt continually rotate further 
					#from its initial rotation after being dragged over multiple off-grid parts
					var rotated_basis : Basis = SnapUtils.snap_rotation(initial_rotation, ray_result)
					apply_snap_rotation(rotated_basis, dragged_part.basis)
					WorkspaceManager.apply_snap_position(SnapUtils.snap_position(
						ray_result,
						dragged_part,
						hovered_part,
						selected_parts_abb,
						drag_offset,
						positional_snap_increment,
						snapping_active
					), selected_parts_abb, transform_handle_root)
	
	
#dragging (parts AND transform handles) happens here
	if event is InputEventMouseMotion:
		#parts dragging under this if
		"TODO TODO TODO"
		if mouse_button_held and not ray_result.is_empty() and is_selecting_allowed:# and (initial_handle_event.position - event.position.length()) > 10:
			if initial_drag_event == null:
				initial_drag_event = event
			
			if Main.safety_check(dragged_part):
				if Main.safety_check(hovered_part):
					if not SnapUtils.part_rectilinear_alignment_check(dragged_part, hovered_part):
						#use initial_rotation so that dragged_part doesnt continually rotate further 
						#from its initial rotation after being dragged over multiple off-grid parts
						var rotated_basis : Basis = SnapUtils.snap_rotation(initial_rotation, ray_result)
						
						apply_snap_rotation(rotated_basis, dragged_part.basis)
					
					#set positions according to offset_dragged_to_selected_array and where the selection is being dragged (ray_result.position)
					WorkspaceManager.apply_snap_position(SnapUtils.snap_position(
						ray_result,
						dragged_part,
						hovered_part,
						selected_parts_abb,
						drag_offset,
						positional_snap_increment,
						snapping_active
					), selected_parts_abb, transform_handle_root)
		
		"TODO"#get done today: refactor this a little, add backward movement limit for scaling, add relative local transform msg
		#transform handle dragging under this if
		#handles do not need a "canvas" collider to be dragged over
		#so theres no check of hovered_part or hovered_handle
		"TODO"#this abstraction fucking sucks
		if mouse_button_held and is_selecting_allowed:
			if Main.safety_check(dragged_handle):
				var result : Dictionary = TransformHandleUtils.transform(
					dragged_handle,
					transform_handle_root,
					abb_initial_extents,
					abb_initial_transform,
					initial_handle_event,
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
					WorkspaceManager.selected_parts_array[0].part_scale = result.part_scale
					selected_parts_abb.extents = result.part_scale
					WorkspaceManager.selection_boxes_redraw_all()
					EditorUI.l_message.text = "Scale: " + str(WorkspaceManager.selected_parts_array[0].part_scale)
					
				if result.modify_position:
					WorkspaceManager.apply_snap_position(result.transform.origin, selected_parts_abb, transform_handle_root)
					if not result.modify_scale:
						EditorUI.l_message.text = "Translation: " + str(result.scalar * dragged_handle.direction_vector)
					
				if result.modify_rotation:
					if local_transform_active:
						apply_snap_rotation(result.transform.basis, selected_parts_abb.transform.basis)
					else:
						var global_direction_vector : Vector3 = transform_handle_root.basis * dragged_handle.direction_vector
						apply_snap_rotation(abb_initial_transform.basis.rotated(global_direction_vector, result.angle_relative), selected_parts_abb.transform.basis)
					EditorUI.l_message.text = "Angle: " + str(rad_to_deg(result.angle_relative))
				
				Main.set_transform_handle_root_position(transform_handle_root, result.transform, local_transform_active, selected_tool_handle_array)
	
	#set previous hovered handle for next input frame
	prev_hovered_handle = hovered_handle
	
	#camera controls
	cam.cam_input(event, second_cam, WorkspaceManager.selected_parts_array, selected_parts_abb, EditorUI.l_message, EditorUI.l_camera_speed)


func _process(delta : float):
	if ui_menu_block_check(EditorUI.ui_menu) or not is_input_active:
		return
	cam.cam_process(delta, second_cam, transform_handle_root, transform_handle_scale, selected_tool_handle_array, selected_parts_abb)


#returns true if hovering over visible ui
func ui_hover_check(ui_list : Array[Control]):
	for i in ui_list:
		if Rect2(i.global_position, i.size).has_point(get_viewport().get_mouse_position()) and i.visible:
			return true
	return false


#returns true if any menus are open
func ui_menu_block_check(menu_list : Array[Control]):
	for i in menu_list:
		if i.visible:
			return true
	return false


#this stuff was ugly so i put them into functions
#collision mask is no longer needed but ill keep it just in case
static func raycast(node : Node3D, from : Vector3, to : Vector3, exclude : Array[RID] = [], collision_mask : Array[int] = [1]):
	var ray_param : PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
	ray_param.from = from
	ray_param.to = to
	ray_param.exclude = exclude
	
	ray_param.collision_mask = SnapUtils.calculate_collision_layer(collision_mask)
	return node.get_world_3d().direct_space_state.intersect_ray(ray_param)


#raycast from cam to where the mouse is pointing, works in ortho mode too
static func raycast_mouse_pos(
	cam : Camera3D,
	raycast_length : float,
	exclude : Array[RID] = [],
	collision_mask : Array[int] = [1]
	):
	#project ray origin simply returns the camera position, EXCEPT,
	#when camera is set to orthogonal
	return raycast(
		cam,
		cam.project_ray_origin(cam.get_viewport().get_mouse_position()),
		cam.project_ray_origin(cam.get_viewport().get_mouse_position()) + 
		cam.project_ray_normal(cam.get_viewport().get_mouse_position()) * raycast_length,
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


#returns null or any hovered handle
func handle_hover_check():
	ray_result = Main.raycast_mouse_pos(second_cam, raycast_length, [], [1])
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
		for i in WorkspaceManager.selected_parts_array:
			if Main.safety_check(i):
				rids.append(i.get_rid())
		ray_result = Main.raycast_mouse_pos(cam, raycast_length, rids, [1])
	else:
		#if not dragging, do not exclude selection
		ray_result = Main.raycast_mouse_pos(cam, raycast_length, [], [1])
	
	if not ray_result.is_empty():
		if Main.safety_check(ray_result.collider) and ray_result.collider is Part:
			return ray_result.collider
	return null


#rotation only
"TODO"#parameterize everything for clarity and to prevent bugs
func apply_snap_rotation(rotated_basis : Basis,
	original_basis : Basis):
	
	#calculate difference between original basis and new basis
	var difference : Basis = rotated_basis * original_basis.inverse()
	drag_offset = difference * drag_offset
	
	#rotate the offset_abb_to_selected_array vector by the difference between the
	#original matrix and rotated matrix
	"TODO"#rename
	WorkspaceManager.selection_apply_rotation(difference, ray_result, selected_parts_abb)
	
	#rotate abb
	selected_parts_abb.transform.basis = difference * selected_parts_abb.transform.basis
	
	
	Main.set_transform_handle_root_position(transform_handle_root, selected_parts_abb.transform, local_transform_active, selected_tool_handle_array)


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


static func set_transform_handle_root_position(root : TransformHandleRoot, new_transform : Transform3D, local_transform_active : bool, selected_tool_handle_array):
	var must_stay_aligned_to_part : bool = false
	if not selected_tool_handle_array.is_empty():
		must_stay_aligned_to_part = selected_tool_handle_array[0].handle_force_follow_abb_surface
	
	if local_transform_active or must_stay_aligned_to_part:
		root.transform = new_transform
	else:
		root.transform.origin = new_transform.origin
		root.transform.basis = Basis.IDENTITY
