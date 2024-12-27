extends Node3D
class_name Main

#DEBUG
@export var d_vector : Array[DebugVector3D]

#ui
@export var b_drag : Button
@export var b_move : Button
@export var b_rotate : Button
@export var b_scale : Button
@export var b_color : Button
@export var b_material : Button
@export var b_lock : Button
@export var b_spawn : Button
@export var b_spawn_type : OptionButton
@export var msg_label : Label
@export var camera_speed_label : Label
@export var camera_zoom_label : Label

#dependencies
@export var cam : FreeLookCamera
@export var raycast_length : float = 128
@export var positional_snap_increment : float = 0.2
@export var rotational_snap_increment : float = 15

@export var transform_handle_root : Node3D
@export var workspace : Node

#for hovering
@export var no_drag_ui : Array[Control]
@export var hover_selection_box : SelectionBox
#if hovering over some block, hide regular selection box and store ref to it here
var hidden_selection_box : SelectionBox

enum SelectedTool {
	drag,
	drag_move,
	drag_rotate,
	drag_scale,
	material,
	color,
	lock
}

#dragging data------------------------------------------------------------------
#raw ray result
var ray_result : Dictionary

var dragged_part : Part
#for selected
var hovered_part : Part

#for selected
var hovered_handle : TransformHandle
#hovered handle from last input event
var last_hovered_handle : TransformHandle


#purely rotational basis set from start of drag as a reference for snapping
var initial_rotation : Basis

#bounding box of selected parts for positional snapping
var selected_parts_aabb : AABB = AABB()
#parallel arrays
var selected_parts : Array[Part] = []
#offset from the dragged parts position to the raycast hit position
var drag_offset : Vector3
#offset of each selected part from dragged part
var main_offset : Array[Vector3] = []
var selection_box_array : Array[SelectionBox] = []

#conditionals-------------------------------------------------------------------

var mouse_button_held : bool = false

#gets set in on_tool_selected
var selected_state : SelectedTool = SelectedTool.drag

#gets set in on_tool_selected
var is_drag_tool : bool = true

#this bool is meant for non drag tools which dont need selecting but still need hovering and clicking functionality
var is_hovering_allowed : bool = true

#this bool is meant for drag tools, if this is enabled then hovering_allowed is also enabled
var is_selecting_allowed : bool = true

# Called when the node enters the scene tree for the first time.
func _ready():
	OS.low_processor_usage_mode = true
	
	#connect all pressed signals to an event with a reference as their parameter
	b_drag.pressed.connect(on_tool_selected.bind(b_drag))
	b_move.pressed.connect(on_tool_selected.bind(b_move))
	b_rotate.pressed.connect(on_tool_selected.bind(b_rotate))
	b_scale.pressed.connect(on_tool_selected.bind(b_scale))
	b_color.pressed.connect(on_tool_selected.bind(b_color))
	b_material.pressed.connect(on_tool_selected.bind(b_material))
	b_lock.pressed.connect(on_tool_selected.bind(b_lock))
	b_spawn.pressed.connect(on_tool_selected.bind(b_spawn))


# Called every input event.
func _input(event):
#start by setting all control variables
	#check validity of selecting
	#is_drag_tool is set by func on_tool_selected
	is_selecting_allowed = is_drag_tool and not ui_hover_check(no_drag_ui)
	is_selecting_allowed = is_selecting_allowed and Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED
	
	#if selecting is allowed, hovering is allowed as well
	if is_selecting_allowed:
		is_hovering_allowed = true
	else:
		#hovering is not allowed if cursor is captured or over ui
		is_hovering_allowed = Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED
		is_hovering_allowed = is_hovering_allowed and not ui_hover_check(no_drag_ui)
	
	
#do raycasting, set hovered_handle
#if handle wasnt found, set hovered_part and render selectionbox around hovered_part
	if event is InputEventMouseMotion:
		if is_hovering_allowed:
			hovered_handle = handle_hover_check()
			print("handle: ", hovered_handle)
			if not safety_check(hovered_handle):
				if safety_check(last_hovered_handle):
					last_hovered_handle.visual_default()
				
				
				
				
				
				
				"TODO"#from last time
				#clean up this code, comment, make the arrows functional (add functions to make handles work on click and drag)
				#add and configure rest of transform tools
				#use aabb to position position and scale handles
				#use distance from camera for scale (this was what needed to be in _process(delta))
				#make it a REFINED SIMPLE and WELL ARCHITECTED system
				
				
				hovered_part = part_hover_check()
				print("part: ", hovered_part)
				part_hover_selection_box(hovered_part)
			else:
				hover_selection_box.visible = false
				hovered_handle.visual_drag()
				if hovered_handle != last_hovered_handle and safety_check(last_hovered_handle):
					last_hovered_handle.visual_default()
	
	
#set dragged_part, recalculate all main_offset vectors and bounding box on new click
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if safety_check(hovered_part):
					initial_rotation = hovered_part.basis
					dragged_part = hovered_part
					drag_offset = dragged_part.global_position - ray_result.position
					selected_parts_aabb = SnapUtils.calculate_extents(selected_parts_aabb, dragged_part, selected_parts)
					var i : int = 0
					main_offset.clear()
					while i < selected_parts.size():
						main_offset.append(selected_parts[i].global_position - dragged_part.global_position)
						i = i + 1
				mouse_button_held = true
			else:
				dragged_part = null
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
				if safety_check(hovered_part) and is_selecting_allowed:
				#hovered part is in selection
					if selected_parts.has(hovered_part):
					#shift is held
						if Input.is_key_pressed(KEY_SHIFT):
							delete_selection_box(hovered_part)
							#erase the same index as hovered_part
							main_offset.remove_at(selected_parts.find(hovered_part))
							selected_parts.erase(hovered_part)
				#hovered part is not in selection
					else:
					#shift is held
						if Input.is_key_pressed(KEY_SHIFT):
							selected_parts.append(hovered_part)
							part_instance_selection_box(hovered_part)
							main_offset.append(hovered_part.global_position - dragged_part.global_position)
					#shift is unheld
						else:
							selected_parts = [hovered_part]
							main_offset = [hovered_part.global_position - dragged_part.global_position]
							clear_all_selection_boxes()
							part_instance_selection_box(hovered_part)
					if selected_parts.size() > 0:
						selected_parts_aabb = SnapUtils.calculate_extents(selected_parts_aabb, selected_parts[0], selected_parts)
			#no parts hovered
				elif is_selecting_allowed:
					#shift is unheld
					if not Input.is_key_pressed(KEY_SHIFT):
						selected_parts.clear()
						clear_all_selection_boxes()
						main_offset.clear()
	#lmb up
			else:
				pass
	
	
#change initial_transform on r or t press
	#rotate clockwise around normal vector
	if Input.is_key_pressed(KEY_R) or Input.is_key_pressed(KEY_T):
		if event.is_pressed() and not event.is_echo() and not ray_result.is_empty():
			if safety_check(hovered_part) and safety_check(dragged_part) and is_selecting_allowed:
				if Input.is_key_pressed(KEY_R):
					initial_rotation = initial_rotation.rotated(ray_result.normal, PI * 0.5)
					update_snap()
					snap_position()
				if Input.is_key_pressed(KEY_T):
				#rotate around part vector which is closest to cam.basis.x
					var b_array : Array[Vector3] = [initial_rotation.x, initial_rotation.y, initial_rotation.z]
					var r_dict = SnapUtils.find_closest_vector_abs(b_array, cam.basis.x)
					if r_dict.vector.dot(cam.basis.x) < 0:
						r_dict.vector = -r_dict.vector
					initial_rotation = initial_rotation.rotated(r_dict.vector.normalized(), PI * 0.5)
					update_snap()
					snap_position()
	
	
	
#dragging happens here
	if event is InputEventMouseMotion:
		if mouse_button_held and safety_check(dragged_part) and not ray_result.is_empty() and is_selecting_allowed:
			if safety_check(hovered_part):
				if not SnapUtils.part_rectilinear_alignment_check(dragged_part, hovered_part):
					update_snap()
				
				snap_position()
				#set positions according to main_offset and where the selection is being dragged (ray_result.position)
	
	
	last_hovered_handle = hovered_handle


#set selected state and is_drag_tool
func on_tool_selected(button):
	match button:
		b_drag:
			selected_state = SelectedTool.drag
			is_drag_tool = true
		b_move:
			selected_state = SelectedTool.drag_move
			is_drag_tool = true
		b_rotate:
			selected_state = SelectedTool.drag_rotate
			is_drag_tool = true
		b_scale:
			selected_state = SelectedTool.drag_scale
			is_drag_tool = true
		b_material:
			selected_state = SelectedTool.material
			is_drag_tool = false
			selected_parts.clear()
			clear_all_selection_boxes()
			main_offset.clear()
		b_color:
			selected_state = SelectedTool.color
			is_drag_tool = false
			selected_parts.clear()
			clear_all_selection_boxes()
			main_offset.clear()
		b_lock:
			selected_state = SelectedTool.lock
			is_drag_tool = false
			selected_parts.clear()
			clear_all_selection_boxes()
			main_offset.clear()


#this stuff was ugly so i put them into functions
func raycast(from : Vector3, to : Vector3, exclude : Array[RID] = [], collision_mask : Array[int] = []):
	var ray_param : PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
	ray_param.from = from
	ray_param.to = to
	ray_param.exclude = exclude
	
	#if anybody is confused about this calculation
	#https://docs.godotengine.org/en/4.1/tutorials/physics/physics_introduction.html#code-example
	if not collision_mask.is_empty():
		var sum : int = 0
		for i in collision_mask:
			sum = int(sum + pow(2, i - 1))
		
		ray_param.collision_mask = sum
	return get_world_3d().direct_space_state.intersect_ray(ray_param)


#raycast from cam to where the mouse is pointing, works in ortho mode too
func raycast_mouse_pos(exclude : Array[RID] = [], collsion_mask : Array[int] = []):
	#project ray origin simply returns the camera position, EXCEPT,
	#when camera is set to orthogonal
	return raycast(
		cam.project_ray_origin(get_viewport().get_mouse_position()),
		cam.project_ray_origin(get_viewport().get_mouse_position()) + 
		cam.project_ray_normal(get_viewport().get_mouse_position()) * raycast_length,
		exclude, collsion_mask
	)


#returns true if hovering over visible ui
func ui_hover_check(ui_list : Array[Control]):
	for i in ui_list:
		if i.get_rect().has_point(get_viewport().get_mouse_position()) and i.visible:
			return true
	return false


#having 2 indents was ugly so i also put this in a function
#also checks for nulls
func safety_check(instance):
	if is_instance_valid(instance):
		if not instance.is_queued_for_deletion():
			return true
		return false
	return false


#returns null or any hovered handle
func handle_hover_check():
	ray_result = raycast_mouse_pos([], [2])
	
	if not ray_result.is_empty() and not mouse_button_held:
		if safety_check(ray_result.collider):
			return ray_result.collider
	return null


#returns null or any hovered part
func part_hover_check():
	if mouse_button_held and safety_check(dragged_part):
		#while dragging, exclude selection
		#exclude selection
		var rids : Array[RID] = []
		for i in selected_parts:
			if safety_check(i):
				rids.append(i.get_rid())
		ray_result = raycast_mouse_pos(rids, [1])
	else:
		#if not dragging, do not exclude selection
		ray_result = raycast_mouse_pos([], [1])
	
	if not ray_result.is_empty():
		if safety_check(ray_result.collider) and ray_result.collider is Part:
			return ray_result.collider
	return null


"TODO"#unit test and clean up
#assumes that the parts are already rectilinearly aligned
#this may become a shitshow when i add wedges
#the position of the aabb is relative to dragged part if dragged_parts transform is an identity
#perform the "normal vector bump" to make sure the parts dont phase through each other
func snap_position(is_planar_snap : bool = true):
	#just forget the aabb right now
	#what matters is figuring out the correct math here
	
	var normal = ray_result.normal
	
	#first find closest basis vectors to normal vector and use that to determine which side length to use
	var basis_vec_1 : Array[Vector3] = [dragged_part.basis.x, dragged_part.basis.y, dragged_part.basis.z]
	var r_dict_1 = SnapUtils.find_closest_vector_abs(basis_vec_1, normal)
	var side_length = dragged_part.part_scale[r_dict_1.index]
	
	#var planar_term
	var inverse = hovered_part.global_transform.inverse()
	var basis_vec_2 : Array[Vector3] = [Basis.IDENTITY.x, Basis.IDENTITY.y, Basis.IDENTITY.z]
	var ray_result_local_position : Vector3 = inverse * ray_result.position
	var normal_local : Vector3 = inverse.basis * normal
	var drag_offset_local : Vector3 = inverse.basis * drag_offset
	#normal "bump"
	drag_offset_local = normal_local * (side_length * 0.5) + (drag_offset_local - drag_offset_local.dot(normal_local) * normal_local)
	var result_local = ray_result_local_position + drag_offset_local
	var r_dict_2 = SnapUtils.find_closest_vector_abs(basis_vec_2, normal_local)
	
	
	#if one parts side length is even and one is odd
	#add half of a snap increment to offset it away
	var dragged_part_local : Basis = inverse.basis * dragged_part.basis
	var dragged_part_side_lengths_local : Vector3 = SnapUtils.get_side_lengths_local(dragged_part.part_scale, dragged_part_local)
	#print(dragged_part_side_lengths_local)
	var i : int = 0
	
	while i < 3:
		#dont snap normal direction, only planar directions
		if abs(normal_local.dot(Basis.IDENTITY[i])) > 0.9:
			i = i + 1
			continue
		
		result_local[i] = snapped(result_local[i], positional_snap_increment)
		var side_1_odd : bool = SnapUtils.is_odd_with_snap_size(hovered_part.part_scale[i], positional_snap_increment)
		var side_2_odd : bool = SnapUtils.is_odd_with_snap_size(dragged_part_side_lengths_local[i], positional_snap_increment)
		if side_1_odd != side_2_odd:
			result_local[i] = result_local[i] + positional_snap_increment * 0.5
		i = i + 1
	
	var result_global : Vector3 = hovered_part.global_transform * result_local
	dragged_part.global_position = result_global
	
	i = 0
	while i < selected_parts.size():
		selected_parts[i].global_position = dragged_part.global_position + main_offset[i]
		selection_box_array[i].global_transform = selected_parts[i].global_transform
		
		i = i + 1


"TODO"#create rotate data and unrotate data function for bounding box
#or data to local data to global
#or maybe use one of those premade functions of node3d
func update_snap():
	#use initial_rotation so that dragged_part doesnt continually rotate further 
	#from its init6ial rotation after being dragged over multiple off-grid parts
	var rotated_basis : Basis = SnapUtils.snap_rotation(initial_rotation, ray_result)
	#calculate difference between original basis and new basis
	var difference : Basis = rotated_basis * dragged_part.basis.inverse()
	
	drag_offset = difference * drag_offset
	
	
	#rotate the main_offset vector by the difference between the
	#original matrix and rotated matrix
	var i : int = 0
	while i < selected_parts.size():
		#rotate main_offset vector by the difference basis
		main_offset[i] = difference * main_offset[i]
		
		#move part to ray_result.position for easier pivoting
		selected_parts[i].global_position = ray_result.position
		
		#rotate this part
		selected_parts[i].basis = difference * selected_parts[i].basis
		
		#move it back out along the newly rotated main_offset vector
		if selected_parts[i] != dragged_part:
			selected_parts[i].global_position = dragged_part.global_position + main_offset[i]
		else:
			dragged_part.global_position = ray_result.position + drag_offset
		
		selection_box_array[i].global_transform = selected_parts[i].global_transform
		i = i + 1


"TODO"#unit test somehow?
func part_hover_selection_box(part : Part):
	if is_hovering_allowed and safety_check(part):
		hover_selection_box.visible = true
		hover_selection_box.global_transform = part.global_transform
		hover_selection_box.box_scale = part.part_scale
	else:
		hover_selection_box.visible = false


#might remove this
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
func clear_all_selection_boxes():
	for i in selection_box_array:
		if safety_check(i):
			i.queue_free()
	selection_box_array.clear()


#delete selection box whos assigned_node matches the parameter
func delete_selection_box(assigned_part : Node3D):
	for i in selection_box_array:
		if safety_check(i):
			if i.assigned_node == assigned_part:
				selection_box_array.erase(i)
				i.queue_free()
				return
