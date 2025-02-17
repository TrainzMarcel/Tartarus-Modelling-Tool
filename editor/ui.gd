extends Control
class_name UI

#top panel, left block
static var b_drag : Button
static var b_move : Button
static var b_rotate : Button
static var b_scale : Button
static var b_color : Button
static var b_material : Button
static var b_lock : Button
static var b_spawn : Button
static var b_spawn_type : OptionButton

#top panel, right block
static var b_local_transform_active : CheckBox
static var b_snapping_active : CheckBox
static var l_positional_snap_increment : LineEdit
static var l_rotational_snap_increment : LineEdit
static var b_position_snap_double : Button
static var b_position_snap_half : Button

#bottom panel
static var msg_label : Label
static var camera_speed_label : Label
static var camera_zoom_label : Label

#array of control nodes which are iterated over to check if the mouse is over ui
static var no_drag_ui : Array[Control]

func initialize(
	on_spawn_pressed : Callable,
	on_tool_selected : Callable,
	on_snap_increment_set : Callable,
	on_snap_increment_doubled_or_halved : Callable,
	on_local_transform_active_set : Callable,
	on_snapping_active_set : Callable
	):
	
	UI.b_drag = %Button
	UI.b_move = %Button2
	UI.b_rotate = %Button3
	UI.b_scale = %Button4
	UI.b_color = %Button5
	UI.b_material = %Button6
	UI.b_lock = %Button7
	UI.b_spawn = %Button8
	UI.b_spawn_type = %OptionButton
	UI.b_local_transform_active = %Button9
	UI.b_snapping_active = %Button10
	
	UI.l_positional_snap_increment = %LineEditPositionIncrement
	UI.b_position_snap_double = %ButtonSnapDouble
	UI.b_position_snap_half = %ButtonSnapHalf
	UI.l_rotational_snap_increment = %LineEditRotationIncrement
	
	UI.msg_label = %Label
	UI.camera_speed_label = %Label2
	UI.camera_zoom_label = %Label3
	
	#array of ui nodes to loop over to check for mouse hovering
	UI.no_drag_ui = [
		UI.b_drag,
		UI.b_move,
		UI.b_rotate,
		UI.b_scale,
		UI.b_color,
		UI.b_material,
		UI.b_lock,
		UI.b_spawn,
		UI.b_spawn_type,
		UI.b_position_snap_double,
		UI.b_position_snap_half,
		%VBoxContainer,
		%Panel
	]
	
	#connect all pressed signals to an event with a reference as their parameter
	UI.b_drag.pressed.connect(on_tool_selected.bind(UI.b_drag))
	UI.b_move.pressed.connect(on_tool_selected.bind(UI.b_move))
	UI.b_rotate.pressed.connect(on_tool_selected.bind(UI.b_rotate))
	UI.b_scale.pressed.connect(on_tool_selected.bind(UI.b_scale))
	UI.b_color.pressed.connect(on_tool_selected.bind(UI.b_color))
	UI.b_material.pressed.connect(on_tool_selected.bind(UI.b_material))
	UI.b_lock.pressed.connect(on_tool_selected.bind(UI.b_lock))
	UI.b_spawn.pressed.connect(on_spawn_pressed.bind(UI.b_spawn))
	
	#when mouse isnt hovering and clicks on something else, ui focus gets released
	UI.l_positional_snap_increment.text_submitted.connect(on_snap_increment_set.bind(UI.l_positional_snap_increment))
	UI.l_rotational_snap_increment.text_submitted.connect(on_snap_increment_set.bind(UI.l_rotational_snap_increment))
	
	UI.b_position_snap_double.pressed.connect(on_snap_increment_doubled_or_halved.bind(UI.b_position_snap_double))
	UI.b_position_snap_half.pressed.connect(on_snap_increment_doubled_or_halved.bind(UI.b_position_snap_half))
	
	UI.b_local_transform_active.toggled.connect(on_local_transform_active_set)
	UI.b_snapping_active.toggled.connect(on_snapping_active_set)

static func select_tool(
	button : Control,
	selected_tool_handle_array : Array[TransformHandle],
	selected_tool : Main.SelectedToolEnum,
	is_drag_tool : bool,
	transform_handle_root : TransformHandleRoot,
	selected_parts_abb : ABB,
	local_transform_active : bool,
	selected_parts_array : Array[Part],
	selection_box_array : Array[SelectionBox],
	offset_abb_to_selected_array : Array[Vector3]
	):
	
	if not selected_tool_handle_array.is_empty():
		TransformHandleUtils.set_tool_handle_array_active(selected_tool_handle_array, false)
	
	var has_associated_transform_handles : bool = false
	
	match button:
		b_drag:
			selected_tool = Main.SelectedToolEnum.t_drag
			has_associated_transform_handles = false
			is_drag_tool = true
		b_move:
			selected_tool = Main.SelectedToolEnum.t_move
			has_associated_transform_handles = true
			is_drag_tool = true
		b_rotate:
			selected_tool = Main.SelectedToolEnum.t_rotate
			has_associated_transform_handles = true
			is_drag_tool = true
		b_scale:
			selected_tool = Main.SelectedToolEnum.t_scale
			has_associated_transform_handles = true
			is_drag_tool = true
		b_material:
			selected_tool = Main.SelectedToolEnum.t_material
			has_associated_transform_handles = false
			is_drag_tool = false
		b_color:
			selected_tool = Main.SelectedToolEnum.t_color
			has_associated_transform_handles = false
			is_drag_tool = false
		b_lock:
			selected_tool = Main.SelectedToolEnum.t_lock
			has_associated_transform_handles = false
			is_drag_tool = false
	
	if has_associated_transform_handles:
		selected_tool_handle_array = transform_handle_root.tool_handle_array[selected_tool]
	else:
		selected_tool_handle_array = []
	
	if is_drag_tool:
		if has_associated_transform_handles:
			Main.set_transform_handle_root_position(transform_handle_root, selected_parts_abb.transform, local_transform_active, selected_tool_handle_array)
			if selected_parts_array.size() > 0:
				TransformHandleUtils.set_tool_handle_array_active(selected_tool_handle_array, true)
		
	else:
		selected_parts_array.clear()
		Main.clear_all_selection_boxes(selection_box_array)
		offset_abb_to_selected_array.clear()
	
	
	var r_dict : Dictionary = {}
	r_dict.selected_tool = selected_tool
	r_dict.selected_tool_handle_array = selected_tool_handle_array
	r_dict.is_drag_tool = is_drag_tool
	r_dict.selected_parts_array = selected_parts_array
	r_dict.offset_abb_to_selected_array = offset_abb_to_selected_array
	return r_dict
