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
	on_snapping_active_set : Callable,
	on_color_selected : Callable
	):
	
	UI.b_drag = %Button
	UI.b_move = %Button2
	UI.b_rotate = %Button3
	UI.b_scale = %Button4
	UI.b_color = %Button5
	UI.b_material = %Button6
	UI.b_lock = %Button7
	UI.b_spawn = %Button8
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
		#UI.b_spawn_type,
		UI.b_position_snap_double,
		UI.b_position_snap_half,
		%VBoxContainer,
		%Panel,
		%ColorPanel
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
	
	
	
	#set up color picker
	var sample_button : Button = %ColorPanel/MarginContainer/GridContainer/Button
	
	
	var r_dict : Dictionary = AutomatedColorPalette.read_colors_and_create_colors(FileAccess.get_file_as_string("res://editor/data/default_color_codes.txt"))
	await sample_button.tree_exited
	var grid_container : GridContainer = %ColorPanel/MarginContainer/GridContainer
	r_dict = AutomatedColorPalette.full_color_sort(grid_container, r_dict.color_array, r_dict.color_name_array)
	var color_buttons : Array[Button] = AutomatedColorPalette.create_buttons_from_colors(sample_button, r_dict.color_array, r_dict.color_name_array)
	sample_button.queue_free()
	
	#add buttons to grid container and connect signals
	var i : int = 0
	while i < color_buttons.size():
		grid_container.add_child(color_buttons[i])
		color_buttons[i].pressed.connect(on_color_selected.bind(color_buttons[i]))
		i = i + 1
	
	
	
	#when mouse isnt hovering and clicks on something else, ui focus gets released
	UI.l_positional_snap_increment.text_submitted.connect(on_snap_increment_set.bind(UI.l_positional_snap_increment))
	UI.l_rotational_snap_increment.text_submitted.connect(on_snap_increment_set.bind(UI.l_rotational_snap_increment))
	
	UI.b_position_snap_double.pressed.connect(on_snap_increment_doubled_or_halved.bind(UI.b_position_snap_double))
	UI.b_position_snap_half.pressed.connect(on_snap_increment_doubled_or_halved.bind(UI.b_position_snap_half))
	
	UI.b_local_transform_active.toggled.connect(on_local_transform_active_set)
	UI.b_snapping_active.toggled.connect(on_snapping_active_set)


#tooltip styling
static var tooltip_panel : StyleBox = preload("res://editor/data_ui/styles/panel_styles/tooltip_panel.tres")
static var tooltip_font : Theme = preload("res://editor/data_ui/styles/font_styles/t_sci_fi_regular.tres")

static func custom_tooltip(for_text : String):
	var tooltip : Label = Label.new()
	for_text = for_text
	tooltip.text = for_text.replace("(", "[ ").replace(")", " ]").replace("\n", " ")
	tooltip.theme = UI.tooltip_font
	tooltip.add_theme_stylebox_override("normal", tooltip_panel)
	tooltip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return tooltip


