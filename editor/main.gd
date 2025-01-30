extends Node3D
class_name Main

#DEBUG
@export var d_vector : Array[DebugVector3D]

#ui
#top panel, left block
@export var b_drag : Button
@export var b_move : Button
@export var b_rotate : Button
@export var b_scale : Button
@export var b_color : Button
@export var b_material : Button
@export var b_lock : Button
@export var b_spawn : Button
@export var b_spawn_type : OptionButton

#top panel, right block
@export var b_local_transform_active : CheckBox
@export var l_positional_snap_increment : LineEdit
@export var l_rotational_snap_increment : LineEdit

#bottom panel
@export var msg_label : Label
@export var camera_speed_label : Label
@export var camera_zoom_label : Label

#dependencies
@export var cam : FreeLookCamera
@export var raycast_length : float = 128
@export var positional_snap_increment : float = 0.2
@export var rotational_snap_increment : float = 15
@export var workspace : Node

#transform handles
@export var transform_handle_root : TransformHandleRoot
var local_transform_active : bool = false

#for hovering
@export var no_drag_ui : Array[Control]
@export var hover_selection_box : SelectionBox

#dragging data------------------------------------------------------------------
#raw ray result
var ray_result : Dictionary
var dragged_part : Part
var hovered_part : Part
#store handle which is being dragged, in case mouse moves off handle while dragging
var dragged_handle : TransformHandle
var hovered_handle : TransformHandle
#purely rotational basis set from start of drag as a reference for snapping
var initial_rotation : Basis
#bounding box of selected parts for positional snapping
var selected_parts_abb : ABB = ABB.new()
#!!!selected_parts_array, offset_dragged_to_selected_array and selection_box_array are parallel arrays!!!
var selected_parts_array : Array[Part] = []
var offset_dragged_to_selected_array : Array[Vector3] = []
#offset from the dragged parts position to the raycast hit position
var selection_box_array : Array[SelectionBox] = []
#vector pointing from ray_result.position to dragged_part 
var drag_offset : Vector3

#conditionals-------------------------------------------------------------------
var mouse_button_held : bool = false
#gets set in on_tool_selected
#contains the transformhandles of any currently selected tool
var selected_tool_handle_array : Array[TransformHandle]
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
	
	"TODO"#add a mechanism to remove focus when there is a left click off the ui
	l_positional_snap_increment.text_submitted.connect(on_snap_increment_set.bind(l_positional_snap_increment))
	l_rotational_snap_increment.text_submitted.connect(on_snap_increment_set.bind(l_rotational_snap_increment))
	
	b_local_transform_active.toggled.connect(on_local_transform_set)
	
	TransformHandleUtils.initialize_transform_handle_root(transform_handle_root)
	selected_parts_abb.debug_mesh = $MeshInstance3D


"TODO"#from last time
				#PRIMARY
					#clean up this code, comment, make the arrows functional (add functions to make handles work on click and drag)
					#make it a REFINED SIMPLE and WELL ARCHITECTED system
					#also update doc_planning with the things i did today
				
				#SECONDARY
					#add and configure rest of transform tools
					#use abb to position position and scale handles
					#use distance from camera for scale (this was what needed to be in _process(delta))


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
	
	
	#for transform handle root to be set to global rotation or local part rotation
	
	
#do raycasting, set hovered_handle
#if handle wasnt found, raycast and set hovered_part, render selectionbox around hovered_part
#transform handles take priority over parts
	if event is InputEventMouseMotion:
		if is_hovering_allowed:
			hovered_handle = handle_hover_check()
			#handle wasnt detected
			if not safety_check(hovered_handle) and not safety_check(dragged_handle):
				hovered_part = part_hover_check()
				part_hover_selection_box(hovered_part)
			#handle was detected
			else:
				#set hovered_part to null as mouse is no longer hovering over a part
				hovered_part = null
	
	
#set dragged_part, recalculate all offset_dragged_to_selected_array vectors and bounding box on new click
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				mouse_button_held = true
				
				if safety_check(hovered_part):
					initial_rotation = hovered_part.basis
					dragged_part = hovered_part
					drag_offset = dragged_part.global_position - ray_result.position
					selected_parts_abb = SnapUtils.calculate_extents(selected_parts_abb, dragged_part, selected_parts_array)
					"TEST"
					set_transform_handle_root_position(transform_handle_root, selected_parts_abb.transform, local_transform_active)
					#transform_handle_root.global_transform = selected_parts_abb.transform
					var i : int = 0
					offset_dragged_to_selected_array.clear()
					while i < selected_parts_array.size():
						offset_dragged_to_selected_array.append(selected_parts_array[i].global_position - dragged_part.global_position)
						i = i + 1
				
				#if handle is detected, try setting dragged_handle
				if safety_check(hovered_handle):
					#ONLY set dragged_handle if its null
					#if not safety_check(dragged_handle):
						dragged_handle = hovered_handle
						TransformHandleUtils.set_transform_handle_highlight(dragged_handle, true)
						#hide hover selection_box because it does not move with transforms
						hover_selection_box.visible = false
				
			else:
				dragged_part = null
				if safety_check(dragged_handle):
					TransformHandleUtils.set_transform_handle_highlight(dragged_handle, false)
				dragged_handle = null
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
					if selected_parts_array.has(hovered_part):
					#shift is held
						if Input.is_key_pressed(KEY_SHIFT):
							#patch to stop dragging when holding shift and
							#dragging on an already selected part
							if selected_parts_array[selected_parts_array.find(hovered_part)] == dragged_part:
								dragged_part = null
							delete_selection_box(hovered_part)
							#erase the same index as hovered_part
							offset_dragged_to_selected_array.remove_at(selected_parts_array.find(hovered_part))
							selected_parts_array.erase(hovered_part)
				#hovered part is not in selection
					else:
					#shift is held
						if Input.is_key_pressed(KEY_SHIFT):
							selected_parts_array.append(hovered_part)
							part_instance_selection_box(hovered_part)
							offset_dragged_to_selected_array.append(hovered_part.global_position - dragged_part.global_position)
					#shift is unheld
						else:
							selected_parts_array = [hovered_part]
							offset_dragged_to_selected_array = [hovered_part.global_position - dragged_part.global_position]
							clear_all_selection_boxes()
							part_instance_selection_box(hovered_part)
		#no parts hovered
				elif is_selecting_allowed:
					#shift is unheld
					if not Input.is_key_pressed(KEY_SHIFT):
						if not safety_check(hovered_handle):
							selected_parts_array.clear()
							clear_all_selection_boxes()
							offset_dragged_to_selected_array.clear()
					
					
	#lmb up
			else:
				pass
			
	#post click checks
			if selected_parts_array.size() > 0:
				selected_parts_abb = SnapUtils.calculate_extents(selected_parts_abb, selected_parts_array[0], selected_parts_array)
				TransformHandleUtils.set_tool_handle_array_active(selected_tool_handle_array, true)
			
			if selected_parts_array.size() == 0:
				TransformHandleUtils.set_tool_handle_array_active(selected_tool_handle_array, false)
	
	
#change initial_transform on r or t press
	if Input.is_key_pressed(KEY_R) or Input.is_key_pressed(KEY_T):
		if event.is_pressed() and not event.is_echo() and not ray_result.is_empty():
			if safety_check(hovered_part) and safety_check(dragged_part) and is_selecting_allowed:
				#rotate clockwise around normal vector
				if Input.is_key_pressed(KEY_R):
					initial_rotation = initial_rotation.rotated(ray_result.normal, PI * 0.5)
					apply_snap_rotation()
					var result = SnapUtils.snap_position(ray_result, dragged_part, hovered_part, selected_parts_abb, drag_offset, positional_snap_increment)
					apply_snap_position(result.absolute, result.relative)
					
				#rotate around part vector which is closest to cam.basis.x
				if Input.is_key_pressed(KEY_T):
					var r_dict = SnapUtils.find_closest_vector_abs(initial_rotation, cam.basis.x, true)
					if r_dict.vector.dot(cam.basis.x) < 0:
						r_dict.vector = -r_dict.vector
					initial_rotation = initial_rotation.rotated(r_dict.vector.normalized(), PI * 0.5)
					apply_snap_rotation()
					var result = SnapUtils.snap_position(ray_result, dragged_part, hovered_part, selected_parts_abb, drag_offset, positional_snap_increment)
					apply_snap_position(result.absolute, result.relative)
	
	
	
#dragging (parts AND transform handles) happens here
	if event is InputEventMouseMotion:
		#parts dragging under this if
		if mouse_button_held and not ray_result.is_empty() and is_selecting_allowed:
			if safety_check(dragged_part):
				if safety_check(hovered_part):
					if not SnapUtils.part_rectilinear_alignment_check(dragged_part, hovered_part):
						apply_snap_rotation()
					
					#set positions according to offset_dragged_to_selected_array and where the selection is being dragged (ray_result.position)
					var result = SnapUtils.snap_position(ray_result, dragged_part, hovered_part, selected_parts_abb, drag_offset, positional_snap_increment)
					apply_snap_position(result.absolute, result.relative)
		
		#transform handle dragging under this if
		#handles do not need a "canvas" collider to be dragged over
		#so theres no check of hovered_part or hovered_handle
		if mouse_button_held and is_selecting_allowed:
			if safety_check(dragged_handle):
				#add function to move handles here
				"TODO"#comment better
				var first = cam.project_ray_normal(event.position - event.relative)
				var second = cam.project_ray_normal(event.position)
				var new_transform = TransformHandleUtils.transform(dragged_handle, transform_handle_root, drag_offset, ray_result, event, first, second, cam, [$DebugVector3D3, $DebugVector3D4], positional_snap_increment)
				"TEST"
				#transform_handle_root.global_transform = new_transform * transform_handle_root.global_transform
				set_transform_handle_root_position(transform_handle_root, new_transform * transform_handle_root.global_transform, local_transform_active)
				
				
				var i : int = 0
				while i < selected_parts_array.size():
					var part = selected_parts_array[i]
					var box = selection_box_array[i]
					part.global_transform = new_transform * part.global_transform
					box.global_transform = part.global_transform
					i = i + 1
				
				selected_parts_abb.transform = new_transform * selected_parts_abb.transform
				

#set selected state and is_drag_tool
"TODO"#put all the things one has to edit to add a new tool, into one file (maybe)
func on_tool_selected(button):
	match button:
		b_drag:
			if selected_parts_array.size() > 0:
				TransformHandleUtils.set_tool_handle_array_active(selected_tool_handle_array, false)
			selected_tool_handle_array = []
			is_drag_tool = true
		b_move:
			selected_tool_handle_array = transform_handle_root.tool_handle_array.move
			is_drag_tool = true
			transform_handle_root.transform = selected_parts_abb.transform
			if selected_parts_array.size() > 0:
				TransformHandleUtils.set_tool_handle_array_active(selected_tool_handle_array, true)
		b_rotate:
			#selected_tool_handle_array = transform_handle_root.tool_handle_array.rotate
			is_drag_tool = true
		b_scale:
			#selected_tool_handle_array = transform_handle_root.tool_handle_array.scale
			is_drag_tool = true
		b_material:
			#selected_tool_handle_array = []
			is_drag_tool = false
			selected_parts_array.clear()
			clear_all_selection_boxes()
			offset_dragged_to_selected_array.clear()
		b_color:
			#selected_tool_handle_array = []
			is_drag_tool = false
			selected_parts_array.clear()
			clear_all_selection_boxes()
			offset_dragged_to_selected_array.clear()
		b_lock:
			#selected_tool_handle_array = []
			is_drag_tool = false
			selected_parts_array.clear()
			clear_all_selection_boxes()
			offset_dragged_to_selected_array.clear()


func on_snap_increment_set(new, line_edit):
	if line_edit == l_positional_snap_increment:
		positional_snap_increment = float(line_edit.text)
	elif line_edit == l_rotational_snap_increment:
		rotational_snap_increment = float(line_edit.text)
	line_edit.release_focus()


func on_local_transform_set(active):
	local_transform_active = active
	set_transform_handle_root_position(transform_handle_root, selected_parts_abb.transform, local_transform_active)

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
func raycast_mouse_pos(exclude : Array[RID] = [], collision_mask : Array[int] = []):
	#project ray origin simply returns the camera position, EXCEPT,
	#when camera is set to orthogonal
	return raycast(
		cam.project_ray_origin(get_viewport().get_mouse_position()),
		cam.project_ray_origin(get_viewport().get_mouse_position()) + 
		cam.project_ray_normal(get_viewport().get_mouse_position()) * raycast_length,
		exclude, collision_mask
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
	#make sure were not dragging a part before detecting a handle
	if not ray_result.is_empty() and not safety_check(dragged_part):
		if safety_check(ray_result.collider):
			return ray_result.collider
	return null


#returns null or any hovered part
func part_hover_check():
	if mouse_button_held and safety_check(dragged_part):
		#while dragging, exclude selection
		#exclude selection
		var rids : Array[RID] = []
		for i in selected_parts_array:
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


#position only
func apply_snap_position(absolute : Vector3, relative : Vector3):
	dragged_part.position = absolute
	selected_parts_abb.transform.origin = selected_parts_abb.transform.origin + relative
	transform_handle_root.transform.origin = selected_parts_abb.transform.origin
	
	
	var i : int = 0
	while i < selected_parts_array.size():
		selected_parts_array[i].global_position = dragged_part.global_position + offset_dragged_to_selected_array[i]
		selection_box_array[i].global_transform = selected_parts_array[i].global_transform
		i = i + 1


#rotation only
func apply_snap_rotation():
	#use initial_rotation so that dragged_part doesnt continually rotate further 
	#from its initial rotation after being dragged over multiple off-grid parts
	var rotated_basis : Basis = SnapUtils.snap_rotation(initial_rotation, ray_result)
	#calculate difference between original basis and new basis
	var difference : Basis = rotated_basis * dragged_part.basis.inverse()
	
	drag_offset = difference * drag_offset
	
	#vector pointing from dragged part to abb
	var offset_abb_dragged_part : Vector3 = selected_parts_abb.transform.origin - dragged_part.position
	
	#rotate the offset_dragged_to_selected_array vector by the difference between the
	#original matrix and rotated matrix
	var i : int = 0
	while i < selected_parts_array.size():
		#rotate offset_dragged_to_selected_array vector by the difference basis
		offset_dragged_to_selected_array[i] = difference * offset_dragged_to_selected_array[i]
		#move part to ray_result.position for easier pivoting
		selected_parts_array[i].global_position = ray_result.position
		
		#rotate this part
		selected_parts_array[i].basis = difference * selected_parts_array[i].basis
		
		#move it back out along the newly rotated offset_dragged_to_selected_array vector
		#dragged_part is always first entry in the selected_parts_array
		if i == 0:
			selected_parts_array[i].global_position = dragged_part.global_position + offset_dragged_to_selected_array[i]
		else:
			dragged_part.global_position = ray_result.position + drag_offset
		
		selection_box_array[i].global_transform = selected_parts_array[i].global_transform
		i = i + 1
	
	
	"TODO"#this is rushed code
	#the below section takes care of the abb which needs to move with the selection
	#rotate vector by difference
	offset_abb_dragged_part = difference * offset_abb_dragged_part
	#rotate abb
	selected_parts_abb.transform.basis = difference * selected_parts_abb.transform.basis
	#move abb to vector
	selected_parts_abb.transform.origin = offset_abb_dragged_part + dragged_part.position


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


func set_transform_handle_root_position(root : TransformHandleRoot, new_transform : Transform3D, local_transform_active : bool):
	if local_transform_active:
		root.transform = new_transform
	else:
		root.transform.origin = new_transform.origin
		root.transform.basis = Basis.IDENTITY
