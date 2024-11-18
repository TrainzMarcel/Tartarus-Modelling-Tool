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

@export var cam : FreeLookCamera
@export var raycast_length : float = 128
@export var positional_snap_increment : float = 0.1
@export var rotational_snap_increment : float = 15
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
	is_selecting_allowed = is_drag_tool
	is_selecting_allowed = is_selecting_allowed and not ui_hover_check(no_drag_ui)
	is_selecting_allowed = is_selecting_allowed and Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED
	
	#if selecting is allowed, hovering is allowed as well
	if is_selecting_allowed:
		is_hovering_allowed = true
	else:
		#hovering is not allowed if cursor is captured or over ui
		is_hovering_allowed = Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED
		is_hovering_allowed = is_hovering_allowed and not ui_hover_check(no_drag_ui)
	
	
#do raycasting, set hovered_part, render selectionbox around hovered_part
	if event is InputEventMouseMotion:
		hovered_part = part_hover_check()
		part_hover_selection_box(hovered_part)
	
	
#set dragged_part, recalculate all main_offset vectors and bounding box on new click
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if safety_check(hovered_part):
					initial_rotation = hovered_part.basis
					dragged_part = hovered_part
					drag_offset = dragged_part.global_position - ray_result.position
					selected_parts_aabb = calculate_extents(selected_parts_aabb, dragged_part, selected_parts)
					
					var i : int = 0
					main_offset.clear()
					while i < selected_parts.size():
						main_offset.append(selected_parts[i].global_position - dragged_part.global_position)
						i = i + 1
				
				
				mouse_button_held = true
			else:
				dragged_part = null
				mouse_button_held = false
		
#selection logic (to be put in another function maybe)
		
		if event.button_index == MOUSE_BUTTON_LEFT:
		#lmb down
			if event.pressed:
	#if part is hovered
				if safety_check(hovered_part) and is_selecting_allowed:
#-------------------------------------------------------------------------------
		#hovered part is in selection
					if selected_parts.has(hovered_part):
				#shift is held
						if Input.is_key_pressed(KEY_SHIFT):
							delete_selection_box(hovered_part)
							#erase the same index as hovered_part
							main_offset.remove_at(selected_parts.find(hovered_part))
							selected_parts.erase(hovered_part)
				#shift is unheld
						else:
							pass
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
#-------------------------------------------------------------------------------
		#no parts hovered
				else:
				#shift is unheld
					if not Input.is_key_pressed(KEY_SHIFT):
						selected_parts.clear()
						clear_all_selection_boxes()
						main_offset.clear()
	#lmb up
			else:
				pass
	
	
		#selection behavior:
		#if click on unselected part, set it as the selection (array with only that part, discard any prior selection)
		#if click on unselected part while shift is held, append to selection
		#if click on part in selection while shift is held, remove from selection
		#if click on nothing, clear selection array
		#if drag on part, figure this next part about dragging out
	
#change initial_transform on r or t press
	#rotate clockwise around normal vector
	if Input.is_key_pressed(KEY_R) and event.is_pressed() and not event.is_echo() and not ray_result.is_empty():
		initial_rotation = initial_rotation.rotated(ray_result.normal, PI * 0.5)
		update_snap()
	
	#rotate around part vector which is closest to cam.basis.x
	if Input.is_key_pressed(KEY_T) and event.is_pressed() and not event.is_echo() and not ray_result.is_empty():
		var b_array : Array[Vector3] = [initial_rotation.x, initial_rotation.y, initial_rotation.z]
		var r_dict = find_closest_vector_abs(b_array, cam.basis.x)
		if r_dict.vector.dot(cam.basis.x) < 0:
			r_dict.vector = -r_dict.vector
		initial_rotation = initial_rotation.rotated(r_dict.vector.normalized(), PI * 0.5)
		update_snap()
	
	
#dragging happens here
	if event is InputEventMouseMotion:
		if mouse_button_held and safety_check(dragged_part) and not ray_result.is_empty():
			if safety_check(hovered_part):
				if not part_rectilinear_alignment_check(dragged_part, hovered_part):
					update_snap()
				
				
				snap_position()
				#set positions according to main_offset and where the selection is being dragged (ray_result.position)
				
				


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
		b_color:
			selected_state = SelectedTool.color
			is_drag_tool = false
		b_lock:
			selected_state = SelectedTool.lock
			is_drag_tool = false

#this stuff was ugly so i put them into functions
func raycast(from : Vector3, to : Vector3, exclude : Array[RID] = []):
	var ray_param : PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
	ray_param.from = from
	ray_param.to = to
	ray_param.exclude = exclude
	return get_world_3d().direct_space_state.intersect_ray(ray_param)

#raycast from cam to where the mouse is pointing, works in ortho mode too
func raycast_mouse_pos(exclude : Array[RID] = []):
	#project ray origin simply returns the camera position, EXCEPT,
	#when camera is set to orthogonal
	return raycast(
		cam.project_ray_origin(get_viewport().get_mouse_position()),
		cam.project_ray_origin(get_viewport().get_mouse_position()) + 
		cam.project_ray_normal(get_viewport().get_mouse_position()) * raycast_length,
		exclude
	)

#returns true if hovering over visible ui
"TODO"#unit test
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

#returns null or any hovered part
func part_hover_check():
	if not is_hovering_allowed:
		return null
	
	if mouse_button_held and safety_check(dragged_part):
		#while dragging, exclude selection
		#exclude selection
		var rids : Array[RID] = []
		for i in selected_parts:
			if safety_check(i):
				rids.append(i.get_rid())
		ray_result = raycast_mouse_pos(rids)
	else:
		#if not dragging, do not exclude selection
		ray_result = raycast_mouse_pos()
	
	if not ray_result.is_empty():
		if safety_check(ray_result.collider):
			return ray_result.collider
	return null

#input is meant to be the part-to-be-rotated's basis
"TODO"#unit test and make above comment better
#res://editor/debug_and_unit_tests/unit_test.gd
func snap_rotation(input : Basis, ray_result : Dictionary):
	
#find closest matching basis vector of dragged_part to normal vector using absolute dot product
#(the result farthest from 0)
	var b_array : Array[Vector3] = [input.x, input.y, input.z]
	var b_array_2 : Array[Vector3] = [ray_result.collider.basis.x, ray_result.collider.basis.y, ray_result.collider.basis.z]
	var i : int = 0
	var closest_vector_1 : Vector3
	var closest_vector_2 : Vector3
	var highest_dot : float = 0
	while i < b_array.size():
		var j : int = 0
		while j < b_array_2.size():
			#remember, 1 = parallel vectors, 0 = perpendicular, -1 = opposing vectors
			if abs(b_array[i].dot(b_array_2[j])) > abs(highest_dot):
				highest_dot = b_array[i].dot(b_array_2[j])
				closest_vector_1 = b_array[i]
				closest_vector_2 = b_array_2[j]
			j = j + 1
		i = i + 1
	
	if highest_dot == 0:
		return input
	
#use angle_to between these two vectors as amount to rotate
#cross product as axis to rotate around
	
	var dot_1 = closest_vector_1.dot(closest_vector_2)
	
	#if vectors are opposed, flip closest_vector_1
	var angle = (closest_vector_1 * sign(dot_1)).angle_to(closest_vector_2)
	var cr_p : Vector3 = (closest_vector_1 * sign(dot_1)).cross(closest_vector_2)
	
	#if cross product returns empty vector, return unmodified basis
	if cr_p.length() == 0:
		return input
	
	var rotated_basis : Basis = input.rotated(cr_p.normalized(), angle).orthonormalized()
	
	
#find basis vector on canvas part which is not equal to closest_vector_2 or inverted closest_vector_2
#use x vector, else use y vector
	var vec_1 : Vector3
		#remember, 1 = parallel vectors, 0 = perpendicular, -1 = opposing vectors
		#the closer to 0 the better in this case
	if abs(ray_result.collider.basis.x.dot(closest_vector_2)) < abs(ray_result.collider.basis.y.dot(closest_vector_2)):
		#canvas.basis.x is closer to 0
		vec_1 = ray_result.collider.basis.x
	else:
		#canvas.basis.y is closer to 0
		vec_1 = ray_result.collider.basis.y
	
	
	#iterate over all 3 vectors and again find closest absolute dot product
	#find signed angle between that and the closest vector and rotate accordingly
	b_array = [rotated_basis.x, rotated_basis.y, rotated_basis.z]
	var closest_vec : Vector3
	highest_dot = 0
	i = 0
	while i < b_array.size():
		if abs(vec_1.dot(b_array[i])) > abs(highest_dot):
			highest_dot = vec_1.dot(b_array[i])
			closest_vec = b_array[i]
		i = i + 1
	
	angle = (closest_vec * sign(highest_dot)).angle_to(vec_1)
	cr_p = (closest_vec * sign(highest_dot)).cross(vec_1)
	
	if cr_p.length() == 0:
		return input
	
	#the part should now hopefully be aligned and ready for linearly translating
	#attempt exact alignment (assigning basis vectors of collider to d_part)
	#and return
	#return part_exact_alignment(rotated_basis, ray_result.collider.basis)
	return rotated_basis.rotated(cr_p.normalized(), angle).orthonormalized()

"TODO"#clean up
func calculate_extents(aabb : AABB, rotation_origin_part : Part, parts : Array[Part]):
	var transformed_parts : Array[Transform3D] = []
	var origin_part_offsets : Array[Vector3] = []
	
	#vector pointing from origin to part position and rotated by inverse basis of origin part
	for i in parts:
		var offset = rotation_origin_part.global_position - i.global_position
		offset = rotation_origin_part.global_transform.basis.inverse() * offset
		origin_part_offsets.append(offset)
	
	"TODO"#comment better
	#rotate parts
	for i in parts:
		var part_transform = i.global_transform
		#their offsets/positions will be taken care of in the next loop
		part_transform.origin = Vector3.ZERO
		part_transform.basis = part_transform.basis * rotation_origin_part.global_transform.basis.inverse()
		transformed_parts.append(part_transform)
	
	#move parts back
	var i : int = 0
	while i < transformed_parts.size():
		transformed_parts[i].origin = origin_part_offsets[i]
		i = i + 1
	
	
	#then resize bounding box
	aabb.size = Vector3.ZERO
	aabb.position = Vector3.ZERO
	
	
	i = 0
	while i < transformed_parts.size():
		var corners : Array[Vector3] = []
		for x in [-0.5, 0.5]:
			for y in [-0.5, 0.5]:
				for z in [-0.5, 0.5]:
					var corner = transformed_parts[i].origin
					corner = corner + transformed_parts[i].basis * (Vector3(x, y, z) * parts[i].part_scale)
					corners.append(corner)
		
		for j in corners:
			if not aabb.has_point(j):
				aabb = aabb.expand(j)
		i = i + 1
	
	return aabb

"TODO"#unit test and clean up
#assumes that the parts are already rectilinearly aligned
#this may become a shitshow when i add wedges
#the position of the aabb is relative to dragged part if dragged_parts transform is an identity
#perform the "normal vector bump" to make sure the parts dont phase through each other
func snap_position():
	"TODO"#just forget the aabb right now
	#what matters is figuring out the correct math here
	#var offset = (ray_result.position - dragged_part.global_position) * ray_result.normal
	
	
	var normal = ray_result.normal
	#first snap normal
	var hovered_scale = hovered_part.part_scale
	var hovered_transform = hovered_part.global_transform
	var dragged_scale = dragged_part.part_scale
	var dragged_transform = dragged_part.global_transform
		#first transform hovered part and dragged part by inverse transform of dragged part
		#that way the coords should be easy to work with
	hovered_transform = dragged_part.global_transform.inverse() * hovered_transform
	dragged_transform = Transform3D.IDENTITY
	
	
	
	#then transform the offset vector back after the operation and apply it
	
	
	
	
	#first find closest basis vectors to normal vector and use that to determine side lengths
	#var basis_vec_1 : Array[Vector3] = [hovered_part.basis.x, hovered_part.basis.y, hovered_part.basis.z]
	#basis_vec_1[0] = basis_vec_1[0] * hovered_part.part_scale.x
	#basis_vec_1[1] = basis_vec_1[1] * hovered_part.part_scale.y
	#basis_vec_1[2] = basis_vec_1[2] * hovered_part.part_scale.z
	
	var basis_vec_2 : Array[Vector3] = [dragged_part.basis.x, dragged_part.basis.y, dragged_part.basis.z]
	basis_vec_2[0] = basis_vec_2[0] * dragged_part.part_scale.x
	basis_vec_2[1] = basis_vec_2[1] * dragged_part.part_scale.y
	basis_vec_2[2] = basis_vec_2[2] * dragged_part.part_scale.z
	
	#var r_dict_1 = find_closest_vector_abs(basis_vec_1, normal)
	var r_dict_2 = find_closest_vector_abs(basis_vec_2, normal)
	
	
	
	
	#next, recalculate full position without using current position as start
	#not using the current position prevents a possible feedback loop
	
	#get halved combination of side lengths which are parallel to normal
	#var normal_term = (r_dict_1.vector.length() + r_dict_2.vector.length()) * 0.5
	var normal_term = r_dict_2.vector.length() * 0.5
	#subtract difference in positions
	normal_term = normal_term * normal - drag_offset
	print(normal_term)
	
	
	
	
	#in future: + planar_term and bool parameter to disable planar snap calculations if snap increment is set to 0
	var offset = normal_term
	#print(offset)
	dragged_part.global_position = ray_result.position + drag_offset + offset
	#below, offset gets applied to each selected part
	var i : int = 0
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
	var rotated_basis : Basis = snap_rotation(initial_rotation, ray_result)
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
	
	
	"TODO"
	#to get local coords, move parts to center, undo rotation, add offsets back
	#then do snap ops
	#then reverse that with the snapped positions
	#and then apply the new positions to the parts 

#returns index of closest pointing vector, ignoring if the vector is pointing the opposite way
func find_closest_vector_abs(search_array : Array[Vector3], target : Vector3):
	var highest_dot : float
	var closest_vec_index : int
	var closest_vec : Vector3
	var i : int = 0
	while i < search_array.size():
		var dot_product = search_array[i].dot(target)
		if abs(highest_dot) < abs(dot_product):
			highest_dot = dot_product
			closest_vec_index = i
			closest_vec = search_array[i]
		i = i + 1
	var return_dict = {
		index = closest_vec_index,
		dot = highest_dot,
		vector = closest_vec
	}
	return return_dict

func part_rectilinear_alignment_check(p1 : Part, p2 : Part):
	var i : int = 0
	var b_array_1 : Array[Vector3] = [p1.global_transform.basis.x,
	p1.global_transform.basis.y, p1.global_transform.basis.z]
	var b_array_2 : Array[Vector3] = [p2.global_transform.basis.x,
	p2.global_transform.basis.y]
	var is_aligned_1 : bool = false
	var is_aligned_2 : bool = false
	
	#at least one of 3 vectors should evaluate to (almost) 1
	while i < b_array_1.size():
		#this is as precise as 32bit floats can do
		if abs(b_array_1[i].dot(b_array_2[0])) > 0.999999:
			is_aligned_1 = true
			break
		i = i + 1
	
	i = 0
	while i < b_array_1.size():
		if abs(b_array_1[i].dot(b_array_2[1])) > 0.999999:
			is_aligned_2 = true
			break
		i = i + 1
	return is_aligned_1 and is_aligned_2

#p1: part to be affected, p2: part to align to
func part_exact_alignment(p1 : Basis, p2 : Basis):
	var i : int = 0
	var j : int = 0
	var b_array_1 : Array[Vector3] = [p1.x, p1.y, p1.z]
	var b_array_2 : Array[Vector3] = [p2.x, p2.y, p2.z]

	#at least one of 3 vectors should evaluate to 1
	while i < b_array_1.size():
		while j < b_array_2.size():
			var dot : float = b_array_1[i].dot(b_array_2[j])
			if abs(dot) > 0.95:
				b_array_1[i] = b_array_2[j] * sign(dot)
			j = j + 1
		j = 0
		i = i + 1

	#assign to p1
	p1.x = b_array_1[0]
	p1.y = b_array_1[1]
	p1.z = b_array_1[2]
	return p1

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
