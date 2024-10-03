extends Node3D
class_name Main

@export var cam : FreeLookCamera

@export var raycast_length : float = 128
#for hovering
@export var selection_box_hover : SelectionBox
@export var no_drag_ui : Array[Control]
#for selected
var hovered_part : Part
var mouse_button_held : bool = false
var selected_parts : Array[Part] = []
var selection_box_array : Array[SelectionBox]
var drag_offset : Array[Vector3] = []

enum SelectedTool {
	drag,
	drag_move,
	drag_rotate,
	drag_scale,
	material,
	color
}

var tool_state : SelectedTool = SelectedTool.drag


# Called when the node enters the scene tree for the first time.
func _ready():
	
	OS.low_processor_usage_mode = true


# Called every input event.
func _input(event):
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
#lmb down
			if event.pressed:
				mouse_button_held = true
				var result : Dictionary = raycast_mouse_pos()
				
				if result and result.collider is Part:
					drag_offset.append(result.collider.global_position - result.position)
					var clicked_part : Part = result.collider
					var is_part_selected : bool = false
					
					if selected_parts.has(clicked_part):
						is_part_selected = true
					
					if is_part_selected:
						if Input.is_key_pressed(KEY_SHIFT):
							selected_parts.erase(clicked_part)
					else:
						if Input.is_key_pressed(KEY_SHIFT):
							selected_parts.append(clicked_part)
						else:
							selected_parts = [clicked_part]
				else:
					selected_parts.clear()
				
				print(hovered_part, " hovered part")
				if hovered_part and Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
					selected_parts.append(hovered_part)
					print(selected_parts[0])
#lmb up
			else:
				mouse_button_held = false
	
	if selected_parts.size() == 1:
		if selected_parts[0]:
			var result = raycast_mouse_pos([selected_parts[0].get_rid()])
			
			if result:
				#selection_box_1.box_scale = selected_parts[0].part_scale
				#selection_box_1.box_update()
				#selection_box_1.visible = true
				selected_parts[0].global_position = result.position + drag_offset
				#selection_box_1.global_transform = selected_parts[0].global_transform
	
	
	if event is InputEventMouseMotion:
		var drag_tool_selected = tool_state == SelectedTool.drag
		drag_tool_selected = drag_tool_selected or tool_state == SelectedTool.drag_move
		drag_tool_selected = drag_tool_selected or tool_state == SelectedTool.drag_rotate
		drag_tool_selected = drag_tool_selected or tool_state == SelectedTool.drag_scale
		
		
		
		#selection behavior:
		#if click on unselected part, set it as the selection (array with only that part, discard any prior selection)
		#if click on unselected part while shift is held, append to selection
		#if click on part in selection while shift is held, remove from selection
		#if click on nothing, clear selection array
		#if drag on part, figure this next part about dragging out
		
		#selection box behavior:
		#if hover over part, put s_box1 over it, hide when unhovered
		
		#if hover over selected part(s), hide s_box2 and replace with s_box1
		
		

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

func ui_hover_check(ui_list : Array[Control]):
	for i in ui_list:
		if i.get_rect().has_point(get_viewport().get_mouse_position()):
			return true
	return false
