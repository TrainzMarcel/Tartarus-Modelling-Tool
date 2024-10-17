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
var selection_box_array : Array[SelectionBox]

#for selected
var hovered_part : Part
var dragged_part : Part
var mouse_button_held : bool = false
var selected_parts : Array[Part] = []
var drag_offset : Array[Vector3] = []

enum SelectedTool {
	drag,
	drag_move,
	drag_rotate,
	drag_scale,
	material,
	color,
	lock
}

enum DragState {
	unselected_part_clicked_shift_unheld,
	selected_part_clicked_shift_unheld,
	unselected_part_clicked_shift_held,
	selected_part_clicked_shift_held,
	nothing_clicked_shift_unheld
}

var selected_state : SelectedTool = SelectedTool.drag
var drag_state : DragState = DragState.nothing_clicked_shift_unheld
#gets set in on_tool_selected
var is_drag_tool : bool = true
var is_cursor_not_captured : bool = true


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
	is_cursor_not_captured = Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED
	#check validity of selecting
	#there will probably be more conditions here in the future
	var is_selecting_allowed : bool = is_drag_tool
	#is_drag_tool is set by on_tool_selected
	is_selecting_allowed = is_selecting_allowed and not ui_hover_check(no_drag_ui)
	is_selecting_allowed = is_selecting_allowed and is_cursor_not_captured
	
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
#lmb down
			if event.pressed:
				mouse_button_held = true
				var result : Dictionary
				
				result = raycast_mouse_pos()
				
	#if part is hovered
				if not result.is_empty() and result.collider is Part and is_selecting_allowed:
					drag_offset.append(result.collider.global_position - result.position)
					print(hovered_part)
					hovered_part = result.collider
					print(result.collider)
					print(hovered_part)
					print("result is not empty")
		#hovered part is in selection
					if selected_parts.has(hovered_part):
				#shift is held
						if Input.is_key_pressed(KEY_SHIFT):
							drag_state = DragState.selected_part_clicked_shift_held
							delete_selection_box(hovered_part)
							selected_parts.erase(hovered_part)
				#shift is unheld
						else:
							drag_state = DragState.selected_part_clicked_shift_unheld
		#hovered part is not in selection
					else:
				#shift is held
						if Input.is_key_pressed(KEY_SHIFT):
							drag_state = DragState.unselected_part_clicked_shift_held
							selected_parts.append(hovered_part)
							part_instance_selection_box(hovered_part)
							
				#shift is unheld
						else:
							drag_state = DragState.unselected_part_clicked_shift_unheld
							selected_parts = [hovered_part]
							clear_all_selection_boxes()
							part_instance_selection_box(hovered_part)
		#no parts hovered
				else:
					hovered_part = null
				#shift is unheld
					if not Input.is_key_pressed(KEY_SHIFT):
						drag_state = DragState.nothing_clicked_shift_unheld
						selected_parts.clear()
						clear_all_selection_boxes()
#lmb up
			else:
				mouse_button_held = false
	
	#is this actually a good idea? it becomes very hard to follow when a bug happens
	"""if is_selecting_allowed and is_instance_valid(hovered_part):
		if drag_state == DragState.unselected_part_clicked_shift_held:
			selected_parts.append(hovered_part)
			part_instance_selection_box(hovered_part)
		elif drag_state == DragState.unselected_part_clicked_shift_unheld:
			selected_parts = [hovered_part]
			clear_all_selection_boxes()
			part_instance_selection_box(hovered_part)
		
		elif drag_state == DragState.selected_part_clicked_shift_held:
			delete_selection_box(hovered_part)
			selected_parts.erase(hovered_part)
		
		elif drag_state == DragState.selected_part_clicked_shift_unheld:
			pass
		
		#no state for nothing clicked shift held, as the user likely does not
		#want their multi selection cleared if they misclick
		elif drag_state == DragState.nothing_clicked_shift_unheld:
			selected_parts.clear()
			clear_all_selection_boxes()"""
		
		
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
	if event is InputEventMouseMotion:
		if is_selecting_allowed:
			
			var result = raycast_mouse_pos()
			if not result.is_empty():
				if result.collider is Part:
					hover_selection_box.visible = true
					hovered_part = result.collider
					hover_selection_box.global_transform = hovered_part.transform
					hover_selection_box.box_scale = hovered_part.part_scale
					for i in selection_box_array:
						if is_instance_valid(i):
							if not i.is_queued_for_deletion():
								if i.assigned_node == hovered_part:
									i.visible = false
									break
			else:
				for i in selection_box_array:
					if is_instance_valid(i):
						if not i.is_queued_for_deletion():
							if i.assigned_node == hovered_part:
								i.visible = true
								break
				hovered_part = null
				hover_selection_box.visible = false
		

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
func ui_hover_check(ui_list : Array[Control]):
	for i in ui_list:
		if i.get_rect().has_point(get_viewport().get_mouse_position()) and i.visible:
			return true
	return false

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
		if is_instance_valid(i):
			if not i.is_queued_for_deletion():
				i.queue_free()

#delete selection box whos assigned_node matches assigned_part
func delete_selection_box(assigned_part : Node3D):
	for i in selection_box_array:
		if is_instance_valid(i):
			if i.assigned_node == assigned_part:
				if not i.is_queued_for_deletion():
					i.queue_free()
					return
