extends Node3D
class_name Main

#features (from most important to least)
"TODO"#implement import export
"TODO"#implement undo redo
"TODO"#implement asset import export
"TODO"#implement csg
#badly implemented but will clean up associated logic later (workspacemanager.selection_rect_handle()) "TODO"#implement click and drag rect selecting
"TODO"#implement selection grouping
"TODO"#implement pivot move tool


#performance
"TODO"#WorkspaceManager.selection_scale() is also very slow
"TODO"#WorkspaceManager.selection_add_part() is also a bit slow
#could benefit from changing second parameter to a mere vector3
"TODO"#use meshdatatool and edit existing vertices instead of clearing and reconstructing them each time
"TODO"#selectionbox script is very slow, box_update() took 170.5ms for 192 calls on my machine
#draw_frame() had 1152 calls for 130.97ms
#draw_quad() had 9216 calls for 113.18ms
#itd be best if i precomputed the vertex coordinates of the selection box and just moved them or scaled them
#instead of regenerating them every time
#itd also be better perhaps to group a number of selectionboxes into one node.
#same with part meshes and part colliders.
#another fix could be to only use one selectionbox to denote selections but this might be too vague looking


#architecture
"TECH DEBT"#selecting logic has become too unclear and decentralized with regards to
#how the bounding box functions and when it should be reset
#clean up all the bounding box code
#find a better way to determine what orientation the bounding box should have
#simplify API for the transform handles in preparation for pivot edit tool
#maybe? refine selection system to work with normal godot assets because it would be fun to use this as a level editor

"TODO"#decide whether the word "is" should be a standard part of naming bools
"TODO"#find a good way to group variables
"TODO"#put all the things one has to edit to add a new tool to transformhandleroot into one file (if possible)
#this would involve creating a centralized data object array to hold the properties of each tool
#as well as making a mapping for ui buttons -> tool data object

#future idea: put selection box around selected_parts_abb as a visual cue (still keeping the selectionboxes of individual parts)
#future idea 2: recolor selection box to red if 2 selected parts are overlapping perfectly


#dependencies
@export_category("Dependencies")
@export var e_cam : FreeLookCamera
static var cam : FreeLookCamera
@export var second_cam : Camera3D
@export var e_workspace : Node
@export var e_transform_handle_root : TransformHandleRoot
static var transform_handle_root : TransformHandleRoot
@export var e_hover_selection_box : SelectionBox
static var hover_selection_box : SelectionBox
@export var ui_node : EditorUI

static var panel_selection_rect : Panel
@export var e_panel_selection_rect : Panel


#overlapping data (used by both dragging and handles)--------------------------------
static var positional_snap_increment : float = 0.1
static var rotational_snap_increment : float = 15
static var snapping_active : bool = true


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
static var ray_result : Dictionary
static var dragged_part : Part
static var hovered_part : Part
#purely rotational basis set from start of drag as a reference for snapping
static var initial_rotation : Basis



#@export_category("Tweakables")
#drag tolerance
#this makes sure when the user is selecting with shift
#that parts dont get moved when the user accidentally moves their mouse a tiny bit
static var drag_tolerance : float = 10

#how many units away a part spawns if theres no parts in front of the raycast
"TODO"#add "normal bump" like with dragging
static var part_spawn_distance : float = 4
#length of raycast for dragging
static var raycast_length : float = 1024


#transform handle data----------------------------------------------------------
#store handle which is being dragged, in case mouse moves off handle while dragging
var dragged_handle : TransformHandle
#hovered handle to set dragged handle when the user clicks
var hovered_handle : TransformHandle
#hovered handle from last input frame
var prev_hovered_handle : TransformHandle

#determines if transform axes will be local to the selection or global
static var local_transform_active : bool = false
#fixed distance of camera to transformhandleroot
@export var transform_handle_scale : float = 12
#contains the transformhandles of any currently selected tool
static var selected_tool_handle_array : Array[TransformHandle]


#conditionals-------------------------------------------------------------------
#main override for when ui like a document view or an asset menu or a file explorer is open
static var is_input_active : bool = true

static var is_mouse_button_held : bool = false

#bool for tools that need to detect hovered parts
#gets set in MainUIEvents.select_tool
static var is_hover_tool : bool = false
#bool for tools whose base functionality includes dragging
#gets set in MainUIEvents.select_tool
static var is_drag_tool : bool = false
#this bool is meant for non drag tools which dont need selecting but still need hovering and clicking functionality
static var is_hovering_allowed : bool = false
#this bool is meant for drag tools, if this is enabled then hovering_allowed is also enabled
static var is_selecting_allowed : bool = false


# Called when the node enters the scene tree for the first time.
func _ready():
	OS.low_processor_usage_mode = true
	DisplayServer.set_icon(preload("res://editor/data_ui/assets/program_icon_v1E2_CHOSEN.png").get_image())
	DisplayServer.window_set_title("Tartarus Modelling Tool")
	#get exports from instance variables and assign to static variable
	transform_handle_root = e_transform_handle_root
	cam = e_cam
	hover_selection_box = e_hover_selection_box
	panel_selection_rect = e_panel_selection_rect
	WorkspaceManager.initialize(e_workspace, hover_selection_box)
	
	#parameterized signals to make them more explicit and visible
	ui_node.initialize(
	MainUIEvents.on_spawn_pressed,
	MainUIEvents.select_tool,
	MainUIEvents.on_snap_button_pressed,
	MainUIEvents.on_snap_text_changed,
	MainUIEvents.on_local_transform_active_set,
	MainUIEvents.on_snapping_active_set,
	MainUIEvents.on_color_selected,
	MainUIEvents.on_material_selected,
	MainUIEvents.on_part_type_selected,
	MainUIEvents.on_top_bar_id_pressed,
	MainUIEvents.on_file_manager_accept_pressed
	)
	
	cam.initialize(EditorUI.l_camera_speed)
	TransformHandleUtils.initialize_transform_handle_root(transform_handle_root)
	
	"TODO"#fix this damn class its broken again
	HyperDebug.initialize(false, get_tree().root)
	
	#for convenience sakes so my console isnt covered up every time i start the software
	get_window().position = Vector2(1920*0.5 - 1152 * 0.3, 0)


# Called every input event.
func _input(event : InputEvent):
#if any menus are open, stop processing
	if ui_menu_block_check(EditorUI.ui_menu) or not is_input_active:
		return
#start by setting all control variables
	#check validity of selecting
	#is_drag_tool is set by func main_ui_events.on_tool_selected
	var is_ui_hovered : bool = ui_hover_check(EditorUI.ui_no_drag)
	is_selecting_allowed = is_drag_tool and not is_ui_hovered
	is_selecting_allowed = is_selecting_allowed and Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED
	
	#if selecting is not allowed, hovering can still be allowed
	#hovering is not allowed if cursor is captured or over ui
	is_hovering_allowed = is_hover_tool and not is_ui_hovered
	is_hovering_allowed = is_hovering_allowed and Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED
	
	
#do raycasting, set hovered_handle
#if handle wasnt found, raycast and set hovered_part, render selectionbox around hovered_part
#transform handles take priority over parts
	if event is InputEventMouseMotion:
		if is_hovering_allowed:
			#print("is_hovering_allowed   ", is_hovering_allowed)
			#print("is_selecting_allowed  ", is_selecting_allowed)
			#print("is_drag_tool          ", is_drag_tool)
			hovered_handle = handle_hover_check()
			#handle wasnt detected
			if not Main.safety_check(hovered_handle) and not Main.safety_check(dragged_handle):
				
				if Main.safety_check(prev_hovered_handle):
					TransformHandleUtils.set_transform_handle_highlight(prev_hovered_handle, false, false)
				
				hovered_part = part_hover_check()
				WorkspaceManager.selection_box_hover_on_part(hovered_part, is_hovering_allowed)
			#handle was detected
			else:
				if not is_mouse_button_held:
					TransformHandleUtils.set_transform_handle_highlight(hovered_handle, false, true)
				
				#fix: when moving mouse from one handle to another, sometimes the non hovered one stayed highlighted
				if hovered_handle != prev_hovered_handle and Main.safety_check(prev_hovered_handle):
					TransformHandleUtils.set_transform_handle_highlight(prev_hovered_handle, false, false)
				
				#set hovered_part to null as mouse is no longer hovering over a part
				hovered_part = null
		else:
			#hide selection box
			WorkspaceManager.selection_box_hover_on_part(null, is_hovering_allowed)
	
	
#set dragged_part and dragged_handle
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				#important control variable
				is_mouse_button_held = true
				#if there is a mouse click off ui, release focus
				if not is_ui_hovered:
					var ui_focus = get_viewport().gui_get_focus_owner()
					if Main.safety_check(ui_focus):
						ui_focus.release_focus()
				
				
				#part detected
				if Main.safety_check(hovered_part):
					#if mouse was pressed down over a hovered part, we know the user is most likely starting a drag
					#drag has a tolerance before it actually starts
					WorkspaceManager.drag_prepare(event)
				#if handle is detected, set dragged_handle
				elif Main.safety_check(hovered_handle):
					dragged_handle = hovered_handle
					#get initial data on click, for calculating transforms performed by transformhandle
					
					WorkspaceManager.initial_transform_handle_root_transform = transform_handle_root.transform
					WorkspaceManager.initial_abb_state.transform = WorkspaceManager.selected_parts_abb.transform
					WorkspaceManager.initial_abb_state.extents = WorkspaceManager.selected_parts_abb.extents
					WorkspaceManager.initial_handle_event = event
					TransformHandleUtils.set_transform_handle_highlight(dragged_handle, true, false)
					#hide hover selection_box because it does not move with transforms
					hover_selection_box.visible = false
				else:
					WorkspaceManager.selection_rect_prepare(event, panel_selection_rect)
			
		#lmb release
			else:
				dragged_part = null
				
				if Main.safety_check(dragged_handle):
					TransformHandleUtils.set_transform_handle_highlight(dragged_handle, false, false)
				
				if Main.safety_check(hovered_handle):
					TransformHandleUtils.set_transform_handle_highlight(hovered_handle, false, true)
				
				dragged_handle = null
				is_mouse_button_held = false
				#drag has a tolerance of a few pixels before it starts
				WorkspaceManager.drag_end()
				WorkspaceManager.selection_rect_end(panel_selection_rect)
	
	
#selection handling
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
				elif is_part_hovered and not is_selecting_allowed and is_hovering_allowed:
					
					if selected_tool == SelectedToolEnum.t_material:
						hovered_part.part_material = WorkspaceManager.selected_material
					
					if selected_tool == SelectedToolEnum.t_color:
						hovered_part.part_color = WorkspaceManager.selected_color
					
					if selected_tool == SelectedToolEnum.t_delete:
						hovered_part.free()
						#hide selection box
						hover_selection_box.visible = false
						#immediately update hovered_part in case theres another part behind the deleted one
						hovered_part = part_hover_check()
						WorkspaceManager.selection_box_hover_on_part(hovered_part, true)
	#lmb up
			else:
				pass
	
#handle editing related keyboard inputs
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
#change initial_transform on r or t press
			#rotate clockwise around normal vector
		if event.keycode == KEY_R:
			if Main.safety_check(hovered_part) and Main.safety_check(dragged_part) and is_selecting_allowed and not ray_result.is_empty():
				initial_rotation = initial_rotation.rotated(ray_result.normal, PI * 0.5)
				#use initial_rotation so that dragged_part doesnt continually rotate further 
				#from its initial rotation after being dragged over multiple off-grid parts
				WorkspaceManager.selection_rotate(SnapUtils.drag_snap_rotation_to_hovered(initial_rotation, ray_result))
				WorkspaceManager.selection_move(SnapUtils.drag_snap_position_to_hovered(
					ray_result,
					dragged_part,
					WorkspaceManager.selected_parts_abb,
					WorkspaceManager.drag_offset,
					positional_snap_increment,
					snapping_active
				))
				#print(WorkspaceManager.selected_parts_abb.transform.basis)
			
			#rotate around part vector which is closest to cam.basis.x
		elif event.keycode == KEY_T:
			if Main.safety_check(hovered_part) and Main.safety_check(dragged_part) and is_selecting_allowed and not ray_result.is_empty():
				var r_dict = SnapUtils.find_closest_vector(initial_rotation, cam.basis.x, true)
				
				initial_rotation = initial_rotation.rotated(r_dict.vector.normalized(), PI * 0.5)
				#use initial_rotation so that dragged_part doesnt continually rotate further 
				#from its initial rotation after being dragged over multiple off-grid parts
				
				WorkspaceManager.selection_rotate(SnapUtils.drag_snap_rotation_to_hovered(initial_rotation, ray_result))
				WorkspaceManager.selection_move(SnapUtils.drag_snap_position_to_hovered(
					ray_result,
					dragged_part,
					WorkspaceManager.selected_parts_abb,
					WorkspaceManager.drag_offset,
					positional_snap_increment,
					snapping_active
				))
		elif event.keycode == KEY_DELETE:
			if is_selecting_allowed:
				EditorUI.l_message.text = "deleted " + str(WorkspaceManager.selected_parts_array.size()) + " parts"
				WorkspaceManager.selection_delete()
		#save as
		elif event.keycode == KEY_S and event.ctrl_pressed and event.shift_pressed:
			WorkspaceManager.request_save_as()
		#save
		elif event.keycode == KEY_S and event.ctrl_pressed:
			WorkspaceManager.request_save()
		#deselect all
		elif event.keycode == KEY_A and event.ctrl_pressed and event.shift_pressed:
			if is_selecting_allowed:
				WorkspaceManager.selection_clear()
				EditorUI.l_message.text = "cleared selection"
		#select all
		elif event.keycode == KEY_A and event.ctrl_pressed:
			if is_selecting_allowed:
				WorkspaceManager.selection_set_to_workspace()
		#cut
		elif event.keycode == KEY_X and event.ctrl_pressed:
			WorkspaceManager.selection_copy()
			WorkspaceManager.selection_delete()
			EditorUI.l_message.text = "cut " + str(WorkspaceManager.parts_clipboard.size()) + " parts"
		#copy
		elif event.keycode == KEY_C and event.ctrl_pressed:
			WorkspaceManager.selection_copy()
			EditorUI.l_message.text = "copied " + str(WorkspaceManager.parts_clipboard.size()) + " parts"
		#paste
		elif event.keycode == KEY_V and event.ctrl_pressed:
			WorkspaceManager.selection_paste()
			EditorUI.l_message.text = "pasted " + str(WorkspaceManager.parts_clipboard.size()) + " parts"
		#duplicate
		elif event.keycode == KEY_D and event.ctrl_pressed:
			WorkspaceManager.selection_duplicate()
			EditorUI.l_message.text = "duplicated " + str(WorkspaceManager.selected_parts_array.size()) + " parts"
		#undo
		elif event.keycode == KEY_Z and event.ctrl_pressed:
			"TODO"
			WorkspaceManager.undo()
		#redo
		elif event.keycode == KEY_Y and event.ctrl_pressed:
			"TODO"
			WorkspaceManager.redo()
	
#dragging parts + transform handles + selection rect handling happens here
	if event is InputEventMouseMotion:
		#parts dragging
		WorkspaceManager.drag_handle(event)
		WorkspaceManager.selection_rect_handle(event, panel_selection_rect, cam)
		
		#transform handle dragging
		#handles do not need a "canvas" collider to be dragged over
		#so theres no check of hovered_part or hovered_handle
		if is_mouse_button_held and is_selecting_allowed:
			if Main.safety_check(dragged_handle):
				var global_vector : Vector3 = (transform_handle_root.basis * dragged_handle.direction_vector).normalized()
				var global_vector_initial : Vector3 = (WorkspaceManager.initial_transform_handle_root_transform.basis * dragged_handle.direction_vector).normalized()
				var cam_normal : Vector3 = cam.project_ray_normal(event.position)
				var cam_normal_initial : Vector3 = cam.project_ray_normal(WorkspaceManager.initial_handle_event.position)
				
			#movement single axis
				if selected_tool == SelectedToolEnum.t_move and dragged_handle.direction_type == TransformHandle.DirectionTypeEnum.axis_move:
					#process mouse drag on handle into a single value
					var delta : float = TransformHandleUtils.input_linear_move(cam, dragged_handle, global_vector, cam_normal, cam_normal_initial)
					#take value and convert to vector3, then apply it to selection
					WorkspaceManager.selection_move(SnapUtils.transform_handle_snap_position(
						delta,
						global_vector,
						WorkspaceManager.initial_abb_state.transform.origin,
						positional_snap_increment,
						snapping_active
					))
					EditorUI.l_message.text = "Translation: " + str(snapped(delta, positional_snap_increment) * dragged_handle.direction_vector)
					
					
			#rotation
				elif selected_tool == SelectedToolEnum.t_rotate and dragged_handle.direction_type == TransformHandle.DirectionTypeEnum.axis_rotate:
					#process mouse drag on handle into a single value
					var angle : float = TransformHandleUtils.input_rotation(cam, dragged_handle, global_vector_initial, cam_normal, cam_normal_initial)
					#turn value into a basis and feed it into workspacemanager to process selection
					WorkspaceManager.selection_rotate(SnapUtils.transform_handle_snap_rotation(
						angle,
						WorkspaceManager.initial_abb_state.transform.basis,
						global_vector_initial,
						deg_to_rad(rotational_snap_increment),
						snapping_active
					))
					EditorUI.l_message.text = "Angle: " + str(snapped(rad_to_deg(angle), rotational_snap_increment) * dragged_handle.direction_vector)
			#scaling
				elif selected_tool == SelectedToolEnum.t_scale and dragged_handle.direction_type == TransformHandle.DirectionTypeEnum.axis_scale:
					var delta_scale : float = TransformHandleUtils.input_linear_move(cam, dragged_handle, global_vector, cam_normal, cam_normal_initial)
					#process mouse drag on handle into a single value
					var result : Vector3 = SnapUtils.transform_handle_snap_scale(
						delta_scale,
						dragged_handle.direction_vector,
						WorkspaceManager.initial_abb_state.extents,
						positional_snap_increment,
						snapping_active,
						Input.is_key_pressed(KEY_CTRL),
						Input.is_key_pressed(KEY_SHIFT)
					)
					
					WorkspaceManager.selection_scale(result)
					
					#do the same for the movement portion
					#turn value into a vector and feed it into workspacemanager to process selection
					var delta_move : float = TransformHandleUtils.input_scale_linear_move(cam, dragged_handle, global_vector, cam_normal, cam_normal_initial, Input.is_key_pressed(KEY_CTRL))
					
					delta_move = SnapUtils.scaling_clamp(delta_move, dragged_handle.direction_vector, WorkspaceManager.initial_abb_state.extents, positional_snap_increment, snapping_active)
					
					#use half delta and half increment because pulling by one face means only half the movement at the part center
					var result_move : Vector3 = SnapUtils.transform_handle_snap_position(
						delta_move * 0.5,
						global_vector,
						WorkspaceManager.initial_abb_state.transform.origin,
						positional_snap_increment * 0.5,
						snapping_active
					)
					
					WorkspaceManager.selection_move(result_move)
					
					EditorUI.l_message.text = "Scale: " + str(result)
	
	
	#post input updates
	if WorkspaceManager.selected_parts_array.size() > 0 and is_selecting_allowed:
		#refresh bounding box on possible selection change
		#automatically refreshes abb offset array
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed or event is InputEventMouseMotion and is_mouse_button_held:
			"ARCHITECTURE NOTE"#this needs to be called anytime the selection changes
			WorkspaceManager.refresh_bounding_box()
		
		
		#important: only execute this on LEFT CLICK and NOT every input frame
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if not ray_result.is_empty():
				WorkspaceManager.drag_offset = WorkspaceManager.selected_parts_abb.transform.origin - Main.ray_result.position	
			
			#move transform handles with selection
			"ARCHITECTURE NOTE"#this needs to be called anytime the selection moves or changes (after refresh bounding box)
			Main.set_transform_handle_root_position(
				transform_handle_root,
				WorkspaceManager.selected_parts_abb.transform,
				local_transform_active,
				selected_tool_handle_array
			)
			TransformHandleUtils.set_tool_handle_array_active(selected_tool_handle_array, true)
			
	if WorkspaceManager.selected_parts_array.size() == 0 and is_selecting_allowed:
		TransformHandleUtils.set_tool_handle_array_active(selected_tool_handle_array, false)
	
	
	#set previous hovered handle for next input frame
	prev_hovered_handle = hovered_handle
	
	#camera controls
	cam.cam_input(event, second_cam, WorkspaceManager.selected_parts_array, WorkspaceManager.selected_parts_abb, EditorUI.l_message, EditorUI.l_camera_speed)


func _process(delta : float):
	if ui_menu_block_check(EditorUI.ui_menu) or not is_input_active:
		return
	cam.cam_process(delta, second_cam, transform_handle_root, transform_handle_scale, selected_tool_handle_array, WorkspaceManager.selected_parts_abb)


#returns true if hovering over visible ui
func ui_hover_check(ui_list : Array[Control]):
	for i in ui_list:
		if Rect2(i.global_position, i.size).has_point(get_viewport().get_mouse_position()) and i.visible:
			return true
	return false


#returns true if any menus are open
func ui_menu_block_check(menu_list : Array):
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
	if is_mouse_button_held and Main.safety_check(dragged_part):
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


static func set_transform_handle_root_position(root : TransformHandleRoot, new_transform : Transform3D, local_transform_active : bool, selected_tool_handle_array):
	var must_stay_aligned_to_part : bool = false
	if not selected_tool_handle_array.is_empty():
		must_stay_aligned_to_part = selected_tool_handle_array[0].handle_force_follow_abb_surface
	
	if local_transform_active or must_stay_aligned_to_part:
		root.transform = new_transform
	else:
		root.transform.origin = new_transform.origin
		root.transform.basis = Basis.IDENTITY
