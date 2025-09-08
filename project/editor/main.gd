extends Node3D
class_name Main

#features (from most important to least)
"TODO"#implement model import export
"TODO"#implement undo redo
"TODO"#implement asset import export
"TODO"#implement csg
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
#simplify API for the transform handles in preparation for pivot edit tool
#(maybe?) refine selection system to work with normal godot assets because it would be fun to use this as a level editor

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

@export_category("Current Version")
@export var version_number : String = "v0.1"

#overlapping data (used by both dragging and handles)--------------------------------
static var positional_snap_increment : float = 0.1
static var rotational_snap_increment : float = 15
static var snapping_active : bool = true


#last input event for cam.cam_process() to call drag_handle()
static var last_mouse_event : InputEventMouse

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
static var dragged_handle : TransformHandle
#hovered handle to set dragged handle when the user clicks
static var hovered_handle : TransformHandle
#hovered handle from last input frame
static var prev_hovered_handle : TransformHandle

#determines if transform axes will be local to the selection or global
static var local_transform_active : bool = false

#fixed distance of camera to transformhandleroot
@export_category("Tweakables")
@export var transform_handle_scale : float = 12

#contains the transformhandles of any currently selected tool
"TODO"#abstract this variable out of main and into toolmanager
static var selected_tool_handle_array : Array[TransformHandle]

#conditionals-------------------------------------------------------------------
#main override for when ui like a document view or an asset menu or a file explorer is open
static var is_input_active : bool = true
static var is_ui_hovered : bool = false

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
	DisplayServer.window_set_title("Tartarus Modelling Tool " + version_number)
	#get exports from instance variables and assign to static variable
	transform_handle_root = e_transform_handle_root
	cam = e_cam
	hover_selection_box = e_hover_selection_box
	panel_selection_rect = e_panel_selection_rect
	
	
	#parameterized signals to make them more explicit and visible
	ui_node.initialize(
	MainUIEvents.on_spawn_pressed,
	MainUIEvents.select_tool,
	MainUIEvents.on_pivot_reset_pressed,
	MainUIEvents.on_snap_button_pressed,
	MainUIEvents.on_snap_text_changed,
	MainUIEvents.on_local_transform_active_set,
	MainUIEvents.on_snapping_active_set,
	MainUIEvents.on_top_bar_id_pressed,
	MainUIEvents.on_file_manager_accept_pressed,
	version_number
	)
	
	WorkspaceManager.initialize(
		e_workspace,
		hover_selection_box,
		MainUIEvents.on_color_selected,
		MainUIEvents.on_material_selected,
		MainUIEvents.on_part_type_selected
	)
	
	cam.initialize(EditorUI.l_camera_speed)
	ToolManager.initialize(transform_handle_root)
	
	"TODO"#fix this damn class its broken again
	HyperDebug.initialize(false, get_tree().root)
	
	#for convenience sakes so my console isnt covered up every time i start the software
	get_window().position = Vector2(1920*0.5 - 1152 * 0.3, 40)


# Called every input event.
func _input(event : InputEvent):
#if any menus are open, stop processing
	if ui_menu_block_check(EditorUI.ui_menu) or not is_input_active:
		return
#start by setting all control variables
	#check validity of selecting
	#is_drag_tool is set by func main_ui lovei_events.on_tool_selected
	is_ui_hovered = ui_hover_check(EditorUI.ui_no_drag)
	is_selecting_allowed = is_drag_tool and not is_ui_hovered
	is_selecting_allowed = is_selecting_allowed and Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED
	
	#if selecting is not allowed, hovering can still be allowed
	#hovering is not allowed if cursor is captured or over ui
	is_hovering_allowed = is_hover_tool and not is_ui_hovered
	is_hovering_allowed = is_hovering_allowed and Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED
	
	#reset each frame
	WorkspaceManager.selection_changed = false
	WorkspaceManager.selection_moved = false
	#set previous hovered handle for this input frame
	prev_hovered_handle = hovered_handle
	
	#set last/newest event for camera
	if event is InputEventMouse:
		last_mouse_event = event
	
#do raycasting, set hovered_handle
#if handle wasnt found, raycast and set hovered_part, render selectionbox around hovered_part
#transform handles take priority over parts
	if event is InputEventMouseMotion:
		hovered_handle = handle_hover_check()
		
		if not is_mouse_button_held and Main.safety_check(hovered_handle):
			ToolManager.handle_set_highlight(hovered_handle, hovered_handle.color_hover)
			
			#fix: when moving mouse from one handle to another, sometimes the previous one stayed highlighted
			if hovered_handle != prev_hovered_handle and Main.safety_check(prev_hovered_handle):
				ToolManager.handle_set_highlight(prev_hovered_handle, prev_hovered_handle.color_default)
			
			#set hovered_part to null as mouse is no longer hovering over a part
			hovered_part = null
		else:
			if not Main.safety_check(hovered_handle) and not Main.safety_check(dragged_handle):
				if Main.safety_check(prev_hovered_handle):
					ToolManager.handle_set_highlight(prev_hovered_handle, prev_hovered_handle.color_default)
		
		
		if is_hovering_allowed and not Main.safety_check(hovered_handle):
			#handle wasnt detected
				hovered_part = Main.part_hover_check()
				WorkspaceManager.selection_box_hover_on_part(hovered_part, is_hovering_allowed)
		else:
			#hide selection box
			WorkspaceManager.selection_box_hover_on_part(null, is_hovering_allowed)
	
	
#set dragged_part and dragged_handle--------------------------------------------
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
					WorkspaceManager.transform_handle_prepare(event)
				else:
					WorkspaceManager.selection_rect_prepare(event, panel_selection_rect)
			
		#lmb release
			else:
				is_mouse_button_held = false
				#drag has a tolerance of a few pixels before it starts
				WorkspaceManager.drag_terminate()
				WorkspaceManager.selection_rect_terminate(panel_selection_rect)
				WorkspaceManager.transform_handle_terminate()
	
	
#selection handling and non-drag-tool logic-------------------------------------
#if click on unselected part, set it as the selection (array with only that part, discard any prior selection)
#if click on unselected part while shift is held, append to selection
#if click on part in selection while shift is held, remove from selection
#if click on nothing, clear selection array
#if click on nothing while shift is held, do nothing
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
				elif is_part_hovered and not is_selecting_allowed and is_hovering_allowed:# is_part_hovered and not is_drag_tool:
					
					if ToolManager.selected_tool == ToolManager.SelectedToolEnum.t_material:
						hovered_part.part_material = WorkspaceManager.selected_material
					
					if ToolManager.selected_tool == ToolManager.SelectedToolEnum.t_paint:
						"TODO"#call recolor_material on selecting color/material if possible, not on part
						hovered_part.part_color = WorkspaceManager.selected_color
					
					if ToolManager.selected_tool == ToolManager.SelectedToolEnum.t_delete:
						hovered_part.free()
						#hide selection box
						hover_selection_box.visible = false
						#immediately update hovered_part in case theres another part behind the deleted one
						hovered_part = Main.part_hover_check()
						WorkspaceManager.selection_box_hover_on_part(hovered_part, true)
	#lmb up
			else:
				pass
	
	#selection rect/marquee select handling
	if event is InputEventMouseMotion:
		WorkspaceManager.selection_rect_handle(event, panel_selection_rect, cam)
	
	
#handle editing related keyboard inputs-----------------------------------------
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
				#immediately update hovered_part in case theres another part behind the deleted one(s)
				hovered_part = Main.part_hover_check()
				WorkspaceManager.selection_box_hover_on_part(hovered_part, is_hovering_allowed)
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
		elif event.keycode == KEY_F1:
			EditorUI.dd_manual.popup()
	
#dragging parts + transform handle calculations---------------------------------
	if event is InputEventMouseMotion:
		#parts dragging
		WorkspaceManager.drag_handle(event)
		
		#transform handle dragging
		#handles do not need a "canvas" collider to be dragged over
		#so theres no check of hovered_part or hovered_handle
		if is_mouse_button_held and (is_selecting_allowed or ToolManager.selected_tool == ToolManager.SelectedToolEnum.t_pivot):
			WorkspaceManager.transform_handle_handle(event)
	
	
#post input updates-------------------------------------------------------------
	if WorkspaceManager.selected_parts_array.size() > 0 and (is_selecting_allowed or ToolManager.selected_tool == ToolManager.SelectedToolEnum.t_pivot):
		#refresh bounding box on definitive selection change
		#automatically refreshes abb offset array
		if WorkspaceManager.selection_changed:
			WorkspaceManager.refresh_bounding_box()
			#this only actually needs to be called when the selection changes from size 0 to size > 0
			#but i didnt feel like tracking that
			ToolManager.handle_set_active(selected_tool_handle_array, true)
		
		
		if WorkspaceManager.selection_changed or WorkspaceManager.selection_moved:
			#recalculate local pivot transform on selection change
			if WorkspaceManager.pivot_custom_mode_active:
				WorkspaceManager.pivot_local_transform = WorkspaceManager.selected_parts_abb.transform.inverse() * WorkspaceManager.pivot_transform
			
			ToolManager.handle_set_root_position(
				transform_handle_root,
				WorkspaceManager.selected_parts_abb,
				WorkspaceManager.pivot_transform,
				WorkspaceManager.pivot_custom_mode_active,
				local_transform_active,
				selected_tool_handle_array
			)
		
		#this definitively tells us a drag motion has started
		if not ray_result.is_empty() and Main.safety_check(dragged_part) and dragged_part == hovered_part:
			WorkspaceManager.drag_offset = WorkspaceManager.selected_parts_abb.transform.origin - Main.ray_result.position
		
	elif WorkspaceManager.selected_parts_array.size() == 0 and WorkspaceManager.selection_changed and ToolManager.selected_tool != ToolManager.SelectedToolEnum.t_pivot:
		ToolManager.handle_set_active(selected_tool_handle_array, false)
	
	
	#camera controls
	cam.cam_input(event, second_cam, WorkspaceManager.selected_parts_array, WorkspaceManager.selected_parts_abb, EditorUI.l_message, EditorUI.l_camera_speed)


func _process(delta : float):
	if ui_menu_block_check(EditorUI.ui_menu) or not is_input_active:
		return
	cam.cam_process(delta, second_cam, transform_handle_root, transform_handle_scale, selected_tool_handle_array, WorkspaceManager.selected_parts_abb, last_mouse_event)


#utility functions
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
static func part_hover_check():
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
