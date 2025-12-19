extends RefCounted
class_name ToolManager

#centralized tool logic and transformhandle utilities
#gets set in MainUIEvents.select_tool
#these 3 variables are all that is required to select tools
static var selected_tool : SelectedToolEnum = SelectedToolEnum.none
static var button_to_tool_data_mapping : Dictionary = {}
static var tool_data_to_transform_handle_mapping : Dictionary = {}

#contains the transformhandles of any currently selected tool
static var selected_tool_handle_array : Array[TransformHandle]

#tool identifier
enum SelectedToolEnum
{
	none,
	t_drag,
	t_move,
	t_rotate,
	t_scale,
	t_paint,
	t_material,
	t_delete,
#	t_lock,
	t_pivot
}


"TODO"#better name
#this just tells the select_tool function how to color the selectionbox
#i couldnt dodge this because Main.selected_color is a changing value
#and i didnt want to reach into the tool data array to sync it each time
#the user selects a different color
enum SelectionBoxColorAction
{
	use_default,
	use_selected_color,
	use_custom_color
}


#struct
class ToolData:
	var tool_type : SelectedToolEnum = SelectedToolEnum.none
	var associated_button : Button
	var has_associated_transform_handles : bool = false
	#only set this to true if also has associated transform handles
	var show_transform_handles_disregarding_selection : bool = false
	var is_drag_tool : bool = false
	var is_hover_tool : bool = false
	var selection_box_color_action : SelectionBoxColorAction = SelectionBoxColorAction.use_default
	var custom_selection_box_color : Color


static func initialize(transform_handle_root : TransformHandleRoot):
	#i felt that there arent enough tools
	#or frequent enough changes to the tools
	#to justify using a dedicated data file here
	
	#configure button to tool data mapping
	var tool_data_array : Array[ToolData] = []
	var new : ToolData = ToolData.new()
	
	#none (when none of the tool buttons are pressed
	tool_data_array.append(new)
	
	#drag tool
	new = ToolData.new()
	new.tool_type = SelectedToolEnum.t_drag
	new.associated_button = EditorUI.b_drag_tool
	new.is_drag_tool = true
	new.is_hover_tool = true
	tool_data_array.append(new)
	
	#move tool
	new = ToolData.new()
	new.tool_type = SelectedToolEnum.t_move
	new.associated_button = EditorUI.b_move_tool
	new.is_drag_tool = true
	new.is_hover_tool = true
	new.has_associated_transform_handles = true
	tool_data_array.append(new)
	
	#rotate tool
	new = ToolData.new()
	new.tool_type = SelectedToolEnum.t_rotate
	new.associated_button = EditorUI.b_rotate_tool
	new.is_drag_tool = true
	new.is_hover_tool = true
	new.has_associated_transform_handles = true
	tool_data_array.append(new)
	
	#scale tool
	new = ToolData.new()
	new.tool_type = SelectedToolEnum.t_scale
	new.associated_button = EditorUI.b_scale_tool
	new.is_drag_tool = true
	new.is_hover_tool = true
	new.has_associated_transform_handles = true
	tool_data_array.append(new)
	
	#color tool
	new = ToolData.new()
	new.tool_type = SelectedToolEnum.t_paint
	new.associated_button = EditorUI.b_paint_tool
	new.is_hover_tool = true
	new.selection_box_color_action = SelectionBoxColorAction.use_selected_color
	tool_data_array.append(new)
	
	#material tool
	new = ToolData.new()
	new.tool_type = SelectedToolEnum.t_material
	new.associated_button = EditorUI.b_material_tool
	new.is_hover_tool = true
	new.selection_box_color_action = SelectionBoxColorAction.use_custom_color
	new.custom_selection_box_color = Color.ORANGE
	tool_data_array.append(new)
	
	#delete tool
	new = ToolData.new()
	new.tool_type = SelectedToolEnum.t_delete
	new.associated_button = EditorUI.b_delete_tool
	new.is_hover_tool = true
	new.selection_box_color_action = SelectionBoxColorAction.use_custom_color
	new.custom_selection_box_color = Color.RED
	tool_data_array.append(new)
	
	#lock tool (to be implemented)
	#new = ToolData.new()
	#new.tool_type = SelectedToolEnum.t_delete
	#new.associated_button = EditorUI.b__tool
	#new.is_hover_tool = true
	#new.selection_box_color_action = SelectionBoxColorAction.use_custom_color
	#new.custom_selection_box_color = Color.RED
	#tool_data_array.append(new)
	
	#pivot edit tool
	new = ToolData.new()
	new.tool_type = SelectedToolEnum.t_pivot
	new.associated_button = EditorUI.b_pivot_tool
	new.has_associated_transform_handles = true
	"TODO"#maybe remove this again not sure if i will use it
	new.show_transform_handles_disregarding_selection = true
	tool_data_array.append(new)
	
	#get the mesh sphere for the pivot marker
	WorkspaceManager.pivot_mesh = transform_handle_root.get_children().filter(func(input): return input is MeshInstance3D and input.name == "MeshInstance3DPivot")[0]
	
	#create mapping 1
	for i in tool_data_array:
		ToolManager.button_to_tool_data_mapping[i.associated_button] = i
	
	#create mapping 2
	#loop through all tool data structs
	#if a tooldata struct says it has associated transform handles
	#loop through all transformhandles to form an array of all the 
	#transformhandles that have the tool assigned to them
	
	#i wish i could make this simpler somehow instead of a dict with arrays of transformhandles in it
	var transform_handles : Array = transform_handle_root.get_children()
	for j in tool_data_array:
		if j.has_associated_transform_handles:
			var array_typed : Array[TransformHandle] = []
			ToolManager.tool_data_to_transform_handle_mapping[j] = array_typed
			for k in transform_handles:
				if k is TransformHandle and k.associated_tools.has(j.tool_type):
					ToolManager.tool_data_to_transform_handle_mapping[j].append(k)


static func select_tool(button : Button):
	#disable transform handles of the previously active tool
	if not selected_tool_handle_array.is_empty():
		ToolManager.handle_set_active(selected_tool_handle_array, false)
	
	if button.button_pressed:
		var data : ToolData = ToolManager.button_to_tool_data_mapping.get(button)
		if data == null:
			return
		ToolManager.selected_tool = data.tool_type
		Main.is_drag_tool = data.is_drag_tool
		Main.is_hover_tool = data.is_hover_tool
		
		#activate transform handles
		if data.has_associated_transform_handles:
			var associated_transform_handles : Array = ToolManager.tool_data_to_transform_handle_mapping[data]
			selected_tool_handle_array = associated_transform_handles
			
			if Main.is_drag_tool:
				ToolManager.handle_set_root_position(
					Main.transform_handle_root,
					SelectionManager.selected_parts_abb,
					WorkspaceManager.pivot_transform,
					WorkspaceManager.pivot_custom_mode_active,
					Main.local_transform_active,
					selected_tool_handle_array
				)
				if SelectionManager.selected_parts_array.size() > 0:
					ToolManager.handle_set_active(selected_tool_handle_array, true)
			#special case
			elif ToolManager.selected_tool == ToolManager.SelectedToolEnum.t_pivot:
				
				if not WorkspaceManager.pivot_custom_mode_active:
					WorkspaceManager.pivot_custom_mode_active = true
					WorkspaceManager.pivot_mesh.visible = true
					"TODO"
					#only move the pivot transform when something is selected
					#otherwise, the pivot stays in the same place
					if SelectionManager.selected_parts_array.size() != 0:
						WorkspaceManager.pivot_transform = SelectionManager.selected_parts_abb.transform
				
				ToolManager.handle_set_active(selected_tool_handle_array, true)
				ToolManager.handle_set_root_position(
					Main.transform_handle_root,
					SelectionManager.selected_parts_abb,
					WorkspaceManager.pivot_transform,
					WorkspaceManager.pivot_custom_mode_active,
					Main.local_transform_active,
					selected_tool_handle_array
				)
		else:
			selected_tool_handle_array = []
		
		#set hover selection box color
		if data.selection_box_color_action == SelectionBoxColorAction.use_default:
			SelectionManager.hover_selection_box.material_highlighter()
		elif data.selection_box_color_action == SelectionBoxColorAction.use_custom_color:
			SelectionManager.hover_selection_box.material_regular_color(data.custom_selection_box_color)
		elif data.selection_box_color_action == SelectionBoxColorAction.use_selected_color:
			SelectionManager.hover_selection_box.material_regular_color(WorkspaceManager.selected_color)
		
	else:
		ToolManager.selected_tool = ToolManager.SelectedToolEnum.none
		Main.is_drag_tool = false
		Main.is_hover_tool = false


#return delta of how far to move depending on if ctrl is held
static func handle_input_scale_linear_move(
		cam : Camera3D,
		active_handle : TransformHandle,
		global_vector : Vector3,
		cam_normal : Vector3,
		cam_normal_initial : Vector3,
		is_ctrl_pressed : bool,
	):
	
	#ctrl: scale both sides, no movement
	if is_ctrl_pressed:
		return 0.0
	return handle_input_linear_move(cam, active_handle, global_vector, cam_normal, cam_normal_initial)


#process input for transform handles that rotate
static func handle_input_rotation(
		cam : Camera3D,
		active_handle : TransformHandle,
		global_vector : Vector3,
		cam_normal : Vector3,
		cam_normal_initial : Vector3
	):
	#need a plane which is placed right on the ring
	#get distance from origin point (and with the dot product whether the plane is in
	#negative space or not, to flip plane_cam_d)
	var plane_cam_d = active_handle.global_position.dot(global_vector)
	
	#create plane which cursor would land on if it was put in 3d space
	var plane_ring : Plane = Plane(global_vector, plane_cam_d)
	var cam_normal_initial_plane = plane_ring.intersects_ray(cam.global_position, cam_normal_initial)
	var cam_normal_plane = plane_ring.intersects_ray(cam.global_position, cam_normal)
	
	HyperDebug.actions.transform_handle_rotation_visualize.do({
		origin_position = plane_ring.d * plane_ring.normal,
		input_vector = plane_ring.normal
		})
	
	#fallback value if intersects_ray fails
	var term_1 = Vector3.ZERO
	var term_2 = Vector3.ZERO
	if cam_normal_initial_plane != null and cam_normal_plane != null:
		term_1 = cam_normal_initial_plane - active_handle.global_position
		term_2 = cam_normal_plane - active_handle.global_position
	
	var angle = term_1.angle_to(term_2)
	#figure out direction of angle and return
	return angle * sign(term_1.cross(term_2).dot(global_vector))


#process input for transform handles that move linearly
#that includes scaling handles
static func handle_input_linear_move(
		cam : Camera3D,
		active_handle : TransformHandle,
		global_vector : Vector3,
		cam_normal : Vector3,
		cam_normal_initial : Vector3
	):
	#need a plane which acts like a sprite that rotates around the handles direction_vector
	#vector pointing from handle to camera.global_position
	var vec : Vector3 = cam.global_position - active_handle.global_position
	#project this vector onto the transform_handles direction vector
	#to only get the part of the vector that is pointing along that direction vector
	var vec_2 : Vector3 = vec.dot(global_vector.normalized()) * global_vector.normalized()
	#flatten vector along transform handle
	#imagine a disc around the transform handles vector and flattening the vector onto the disc
	#like now taking away the component that vec_2 had
	vec = (vec - vec_2).normalized()
	
	#get length (and with the dot product also whether the camera is facing away or not, to flip plane_cam_d)
	var plane_cam_d = active_handle.global_position.dot(vec)
	
	#create plane which cursor would land on if it was put in 3d space
	var plane_cam : Plane = Plane(vec, plane_cam_d)
	
	#vector pointing to mouse position projected onto the plane
	var cam_normal_plane = plane_cam.intersects_ray(cam.global_position, cam_normal)
	var cam_normal_plane_initial = plane_cam.intersects_ray(cam.global_position, cam_normal_initial)
	
	HyperDebug.actions.transform_handle_linear_visualize.do({
		input_vector = plane_cam.normal,
		origin_position = plane_cam.d * plane_cam.normal
		})
	
	
	#fallback value if intersects_ray fails
	var term_1 : float = 0
	if cam_normal_plane != null:
		#get the difference between (current projected mouse position) and (initial projected mouse position)
		term_1 = cam_normal_plane.dot(global_vector) - cam_normal_plane_initial.dot(global_vector)
	return term_1


"TODO"
static func handle_input_planar_move():
	
	
	
	pass


static func handle_set_active(handles : Array, input : bool):
	for i in handles:
		i.visible = input
		for j in i.collider_array:
			j.disabled = not input


static func handle_set_highlight(handle : TransformHandle, color : Color):
		for i in handle.mesh_array:
			i.material_override.albedo_color = color


static func handle_set_root_position(
	root : TransformHandleRoot,
	selected_parts_abb : ABB,
	pivot_transform : Transform3D,
	pivot_custom_mode_active : bool,
	local_transform_active : bool,
	selected_tool_handle_array
	):
	
	var must_stay_aligned_to_part : bool = false
	if not selected_tool_handle_array.is_empty():
		must_stay_aligned_to_part = selected_tool_handle_array[0].handle_force_follow_abb_surface
	
	#bool override hierarchy
	#must_stay_aligned_to_part
	#pivot_custom_mode_active
	#local_transform_active
	
	if must_stay_aligned_to_part:
		root.transform = selected_parts_abb.transform
	elif pivot_custom_mode_active:
		root.transform = selected_parts_abb.transform * WorkspaceManager.pivot_local_transform
	elif local_transform_active:
		root.transform = selected_parts_abb.transform
	#global transformed
	else:
		root.transform.origin = selected_parts_abb.transform.origin
		root.transform.basis = Basis.IDENTITY
