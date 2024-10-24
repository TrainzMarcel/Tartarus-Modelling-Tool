extends Node3D
class_name Main

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
@export var workspace : Node

#for hovering
@export var no_drag_ui : Array[Control]
@export var hover_selection_box : SelectionBox
#if hovering over some block, hide regular selection box and store ref to it here
var hidden_selection_box : SelectionBox
var selection_box_array : Array[SelectionBox]

enum SelectedTool {
	drag,
	drag_move,
	drag_rotate,
	drag_scale,
	material,
	color,
	lock
}

#will probably remove this
enum DragState {
	unselected_part_clicked_shift_unheld,
	selected_part_clicked_shift_unheld,
	unselected_part_clicked_shift_held,
	selected_part_clicked_shift_held,
	nothing_clicked_shift_unheld
}

#for selected
var hovered_part : Part
#raw ray result
var ray_result : Dictionary

var dragged_part : Part
var initial_rotation : Transform3D

var mouse_button_held : bool = false
var selected_parts : Array[Part] = []
var drag_offset : Array[Vector3] = []

var selected_state : SelectedTool = SelectedTool.drag
var drag_state : DragState = DragState.nothing_clicked_shift_unheld
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
	
	
#set dragged_part, recalculate all drag_offset vectors on new click
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if safety_check(hovered_part):
					dragged_part = hovered_part
					var initial_rotation = hovered_part.transform
					var i : int = 0
					drag_offset.clear()
					while i < selected_parts.size():
						drag_offset.append(selected_parts[i].global_position - ray_result.position)
						i = i + 1
					
				mouse_button_held = true
			else:
				dragged_part = null
				mouse_button_held = false
		
#selection logic (to be put in another function? maybe? probably)
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
							drag_offset.remove_at(selected_parts.find(hovered_part))
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
							drag_offset.append(hovered_part.global_position - ray_result.position)
				#shift is unheld
						else:
							selected_parts = [hovered_part]
							drag_offset = [hovered_part.global_position - ray_result.position]
							clear_all_selection_boxes()
							part_instance_selection_box(hovered_part)
#-------------------------------------------------------------------------------
		#no parts hovered
				else:
				#shift is unheld
					if not Input.is_key_pressed(KEY_SHIFT):
						selected_parts.clear()
						clear_all_selection_boxes()
						drag_offset.clear()
	#lmb up
			else:
				pass
	
	
		#selection behavior:
		#if click on unselected part, set it as the selection (array with only that part, discard any prior selection)
		#if click on unselected part while shift is held, append to selection
		#if click on part in selection while shift is held, remove from selection
		#if click on nothing, clear selection array
		#if drag on part, figure this next part about dragging out
		#selection box behavior:
		#if hover over part, put s_box1 over it, hide when unhovered
		#if hover over selected part(s), hide s_box2 and replace with s_box1
	
	
	
	"TODO"#implement dragging here once selecting works properly
	"TODO"#maybe clean this up
	#dragging happens here
	if event is InputEventMouseMotion:
		if mouse_button_held and safety_check(dragged_part) and not ray_result.is_empty():
			var i : int = 0
			while i < selected_parts.size():
				selected_parts[i].global_position = ray_result.position + drag_offset[i]
				selection_box_array[i].global_transform = selected_parts[i].global_transform
				
				i = i + 1
			
			#dragged_part.rotation = snap_rotation() * dragged_part.rotation
			if safety_check(hovered_part):
				if not part_rectilinear_alignment_check(dragged_part, hovered_part):
					print("parts are NOT ALIGNED")
					dragged_part.global_transform.basis = snap_rotation(dragged_part, ray_result)
				else:
					"DEBUG"
					print("parts are ALIGNED")


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
"TODO"#unit test
func safety_check(instance):
	if is_instance_valid(instance):
		if not instance.is_queued_for_deletion():
			return true
		return false
	return false

#returns null or any hovered part
"TODO"#unit test
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

#d_part stands for dragged_part
func snap_rotation(d_part : Part, ray_result : Dictionary):
	
#find closest matching basis vector of dragged_part to normal vector using absolute dot product
#(the result farthest from 0)
	var b_array : Array[Vector3] = [d_part.global_transform.basis.x,
		d_part.global_transform.basis.y, d_part.global_transform.basis.z]
	var i : int = 0
	var closest_vector : Vector3
	var highest_dot : float = 0
	while i < b_array.size():
		#remember, 1 = parallel vectors, 0 = perpendicular, -1 = opposing vectors
		if abs(b_array[i].dot(ray_result.normal)) > highest_dot:
			highest_dot = b_array[i].dot(ray_result.normal)
			closest_vector = b_array[i]
		i = i + 1
	
	if highest_dot == 0:
		return d_part.global_transform.basis
	
#use angle_to between these two vectors as amount to rotate
#cross product as axis to rotate around
	
	var rotated_basis : Basis = d_part.basis
	var dot_1 = closest_vector.dot(ray_result.normal)
	
	#if vectors are opposed, flip closest_vector
	var angle = (closest_vector * sign(dot_1)).angle_to(ray_result.normal)
	var cr_p : Vector3 = (closest_vector * sign(dot_1)).cross(ray_result.normal)
	
	#if cross product returns empty vector, return unmodified basis
	if cr_p.length() == 0:
		return d_part.basis
	
	rotated_basis = d_part.basis.rotated(cr_p.normalized(), angle).orthonormalized()
	
	
#find basis vector on canvas part which is not equal to normal or inverted normal
#use x vector, else use y vector
	var vec_1 : Vector3
		#remember, 1 = parallel vectors, 0 = perpendicular, -1 = opposing vectors
		#the closer to 0 the better in this case
	if abs(ray_result.collider.basis.x.dot(ray_result.normal)) < abs(ray_result.collider.basis.y.dot(ray_result.normal)):
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
		return d_part.basis
	
	rotated_basis = rotated_basis.rotated(cr_p.normalized(), angle).orthonormalized()
	
	#the part should now hopefully be aligned and ready for linearly translating
	#attempt exact alignment (assigning basis vectors of collider to d_part)
	#and return
	#return part_exact_alignment(rotated_basis, ray_result.collider.basis)
	return rotated_basis

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
