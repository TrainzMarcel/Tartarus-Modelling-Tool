extends Control
class_name EditorUI

"TODO"#add create color button function, material button function, part button function

#ui naming convention: prefix the default node name with what kind of ui it corresponds too

#top left block
	#top menu bar
#static var mb_top_bar : MenuBar
static var pm_file : PopupMenu
static var pm_edit : PopupMenu
static var pm_assets : PopupMenu
static var pm_help : PopupMenu


	#tool bar
static var b_drag_tool : Button
static var b_move_tool : Button
static var b_rotate_tool : Button
static var b_scale_tool : Button
static var b_spawn_part : Button
#static var b_dropdown_part : Button
static var b_delete_tool : Button
static var b_paint_tool : Button
#static var b_dropdown_color : Button
static var b_material_tool : Button
#static var b_dropdown_material : Button
static var b_lock_tool : Button

	#selector panels (specifically the containers of the buttons)
static var gc_paint_panel : GridContainer
static var vbc_material_panel : VBoxContainer
static var gc_part_panel : GridContainer


#bottom left block
static var b_local_transform : Button
static var b_snapping_enabled : Button
static var hbc_snap_increments : HBoxContainer

	#units snapping options
static var le_unit_step : LineEdit
static var le_unit_step_increment_step : LineEdit
static var b_unit_increment : Button
static var b_unit_decrement : Button
static var b_unit_double : Button
static var b_unit_half : Button

	#rotation snapping options
static var le_rotation_step : LineEdit
static var le_rotation_step_increment_step : LineEdit
static var b_rotation_increment : Button
static var b_rotation_decrement : Button
static var b_rotation_double : Button
static var b_rotation_half : Button


#bottom bar
static var l_camera_speed : Label
static var l_message : Label

#array of control nodes which are iterated over to check if the mouse is over ui
static var no_drag_ui : Array[Control]

#array of numeric line edits
static var numeric_line_edit_array : Array[LineEdit]


func initialize(
	on_spawn_pressed : Callable,
	on_tool_selected : Callable,
	main_on_snap_button_pressed : Callable,
	main_on_snap_text_changed : Callable,
	on_local_transform_active_set : Callable,
	on_snapping_active_set : Callable,
	on_color_selected : Callable):
	
#assign all ui nodes
	#top left block
		#top menu bar
	#mb_top_bar = %TopBar
	pm_file = %File
	pm_edit = %Edit
	pm_assets = %Assets
	pm_help = %Help
	
		#tool bar
	b_drag_tool = %ButtonDragTool
	b_move_tool = %ButtonMoveTool
	b_rotate_tool = %ButtonRotateTool
	b_scale_tool = %ButtonScaleTool
	b_spawn_part = %ButtonSpawnPart
	b_delete_tool = %ButtonDeleteTool
	b_paint_tool = %ButtonPaintTool
	b_material_tool = %ButtonMaterialTool
	b_lock_tool = %ButtonLockTool
	
	
		#selector panels (specifically the containers of the buttons)
	gc_paint_panel = %GridContainerColorPanel
	vbc_material_panel = %VBoxContainerMaterialPanel
	gc_part_panel = %PartPanelGridContainer
	
		#bottom left block
	b_local_transform = %ButtonLocalTransform
	b_snapping_enabled = %ButtonSnapping
	
		#units snapping options
	le_unit_step = %LineEditUnitStep
	le_unit_step_increment_step = %LineEditUnitStepIncrementStep
	b_unit_increment = %ButtonUnitIncrement
	b_unit_decrement = %ButtonUnitDecrement
	b_unit_double = %ButtonUnitDouble
	b_unit_half = %ButtonUnitHalf
	
		#rotation snapping options
	le_rotation_step = %LineEditRotationStep
	le_rotation_step_increment_step = %LineEditRotationStepIncrementStep
	b_rotation_increment = %ButtonRotationIncrement
	b_rotation_decrement = %ButtonRotationDecrement
	b_rotation_double = %ButtonRotationDouble
	b_rotation_half = %ButtonRotationHalf
	
		#bottom bar
	l_camera_speed = %LabelCameraSpeed
	l_message = %LabelMessage
	
	
	no_drag_ui = [
		$PanelContainerTopLeftBlock,
		$PanelContainerBottomLeftBlock,
		$DocumentDisplayManual,
		$DocumentDisplayLicense,
		$PanelContainerBottomLeftBlock,
		$PanelContainerTopLeftBlock/MarginContainer/VBoxContainer/ToolBar/HBoxContainerPaintTool/DropDownButton/PanelContainerColor,
		$PanelContainerTopLeftBlock/MarginContainer/VBoxContainer/ToolBar/HBoxContainerMaterialTool/DropDownButton/PanelContainerMaterial,
		$PanelContainerTopLeftBlock/MarginContainer/VBoxContainer/ToolBar/HBoxContainerSpawnPart/DropDownButton/PanelContainerPartType
	]
	
#initialize picker/selector menus
	var r_dict : Dictionary = WorkspaceData.read_colors_and_create_colors(FileAccess.get_file_as_string("res://editor/data_editor/default_color_codes.txt"))
	
	var r_dict_2 : Dictionary = AutomatedColorPalette.full_color_sort(gc_paint_panel, r_dict.color_array, r_dict.color_name_array)
	
	var default_palette : WorkspaceData.ColorPalette = WorkspaceData.ColorPalette.new()
	default_palette.color_array = r_dict_2.color_array
	default_palette.color_name_array = r_dict_2.color_name_array
	WorkspaceData.available_color_palette_array.append(default_palette)
	WorkspaceData.selected_color_palette = default_palette
	
	EditorUI.create_color_buttons(gc_paint_panel, on_color_selected, r_dict_2.color_array, r_dict_2.color_name_array)
	#DataLoader.read_parts_and_create_parts()
	#UI.create_part_buttons(gc_part_panel, on_part_selected, r_dict_3.part_array)
	#DataLoader.read_materials_and_create_materials()
	#UI.create_material_buttons()
	
#connect signals
	b_snapping_enabled.toggled.connect(on_snapping_active_set)
	b_local_transform.toggled.connect(on_local_transform_active_set)
	
	le_rotation_step.text_changed.connect(main_on_snap_text_changed.bind(le_rotation_step))
	le_unit_step.text_changed.connect(main_on_snap_text_changed.bind(le_unit_step))
	
	b_rotation_increment.pressed.connect(main_on_snap_button_pressed.bind(b_rotation_increment))
	b_rotation_decrement.pressed.connect(main_on_snap_button_pressed.bind(b_rotation_decrement))
	b_rotation_double.pressed.connect(main_on_snap_button_pressed.bind(b_rotation_double))
	b_rotation_half.pressed.connect(main_on_snap_button_pressed.bind(b_rotation_half))
	b_unit_increment.pressed.connect(main_on_snap_button_pressed.bind(b_unit_increment))
	b_unit_decrement.pressed.connect(main_on_snap_button_pressed.bind(b_unit_decrement))
	b_unit_double.pressed.connect(main_on_snap_button_pressed.bind(b_unit_double))
	b_unit_half.pressed.connect(main_on_snap_button_pressed.bind(b_unit_half))
	
	
	
	b_drag_tool.pressed.connect(on_tool_selected.bind(b_drag_tool))
	b_move_tool.pressed.connect(on_tool_selected.bind(b_move_tool))
	b_rotate_tool.pressed.connect(on_tool_selected.bind(b_rotate_tool))
	b_scale_tool.pressed.connect(on_tool_selected.bind(b_scale_tool))
	b_paint_tool.pressed.connect(on_tool_selected.bind(b_paint_tool))
	b_material_tool.pressed.connect(on_tool_selected.bind(b_material_tool))
	b_lock_tool.pressed.connect(on_tool_selected.bind(b_lock_tool))
	b_spawn_part.pressed.connect(on_spawn_pressed.bind(b_spawn_part))
	
	



func _input(event):
	if event is InputEventKey:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			var focus_owner : Control = get_viewport().gui_get_focus_owner()
			if focus_owner is LineEdit:
				focus_owner.release_focus()

#helper functions
static func create_color_buttons(parent : Control, on_color_selected : Callable, color_array : Array[Color], color_name_array : Array[String]):
	
	#unload existing nodes (when for example, color palette changes
	var existing_nodes : Array[Node] = parent.get_children()
	var sample_button : Button = existing_nodes[0]
	
	#delete all but first button
	var i : int = 1
	while i < existing_nodes.size():
		existing_nodes[i].queue_free()
		i = i + 1
	
	i = 0
	while i < color_array.size():
		var new : Button = sample_button.duplicate()
		new.self_modulate = color_array[i]
		new.tooltip_text = color_name_array[i]
		new.set_script(preload("res://editor/classes/ui_editor/tooltip_assign.gd"))
		new.pressed.connect(on_color_selected.bind(new))
		parent.add_child(new)
		i = i + 1
	sample_button.queue_free()


#todo: regenerate color buttons based on data in WorkspaceData
static func update_color_panel():
	pass

static func update_material_panel():
	pass

static func update_part_type_panel():
	pass


#signals
static func select_tool(
	button : Button,
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
	"TODO"#if selected tool has selection drop down then tell the user what is selected with bottom bar text
	if button.button_pressed:
		match button:
			b_drag_tool:
				selected_tool = Main.SelectedToolEnum.t_drag
				has_associated_transform_handles = false
				is_drag_tool = true
			b_move_tool:
				selected_tool = Main.SelectedToolEnum.t_move
				has_associated_transform_handles = true
				is_drag_tool = true
			b_rotate_tool:
				selected_tool = Main.SelectedToolEnum.t_rotate
				has_associated_transform_handles = true
				is_drag_tool = true
			b_scale_tool:
				selected_tool = Main.SelectedToolEnum.t_scale
				has_associated_transform_handles = true
				is_drag_tool = true
			b_material_tool:
				selected_tool = Main.SelectedToolEnum.t_material
				has_associated_transform_handles = false
				is_drag_tool = false
			b_paint_tool:
				selected_tool = Main.SelectedToolEnum.t_color
				has_associated_transform_handles = false
				is_drag_tool = false
			b_lock_tool:
				selected_tool = Main.SelectedToolEnum.t_lock
				has_associated_transform_handles = false
				is_drag_tool = false
	else:
		selected_tool = Main.SelectedToolEnum.none
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


static func on_snap_text_changed(line_edit : LineEditNumeric):
	var r_dict : Dictionary = {}
	r_dict.rotational_snap_increment = le_rotation_step.true_value
	r_dict.positional_snap_increment = le_unit_step.true_value
	return r_dict


static func on_snap_button_pressed(button : Button, positional_snap_increment : float, rotational_snap_increment : float):
	match button:
		b_rotation_increment:
			rotational_snap_increment = rotational_snap_increment + le_rotation_step_increment_step.true_value
		b_rotation_decrement:
			rotational_snap_increment = rotational_snap_increment - le_rotation_step_increment_step.true_value
		b_rotation_double:
			rotational_snap_increment = rotational_snap_increment * 2
		b_rotation_half:
			rotational_snap_increment = rotational_snap_increment * 0.5
		b_unit_increment:
			positional_snap_increment = positional_snap_increment + le_unit_step_increment_step.true_value
		b_unit_decrement:
			positional_snap_increment = positional_snap_increment - le_unit_step_increment_step.true_value
		b_unit_double:
			positional_snap_increment = positional_snap_increment * 2
		b_unit_half:
			positional_snap_increment = positional_snap_increment * 0.5
	
	positional_snap_increment = max(positional_snap_increment, 0)
	rotational_snap_increment = max(rotational_snap_increment, 0)
	
	le_rotation_step.text = str(rotational_snap_increment)
	le_unit_step.text = str(positional_snap_increment)
	
	var r_dict : Dictionary = {}
	r_dict.rotational_snap_increment = rotational_snap_increment
	r_dict.positional_snap_increment = positional_snap_increment
	return r_dict


#tooltip styling
"TODO"#throw these filepaths into dataloader
static var tooltip_panel : StyleBox = preload("res://editor/data_ui/styles/panel_styles/tooltip_panel.tres")#DataLoader.ui_tooltip_panel
static var tooltip_font : Theme = preload("res://editor/data_ui/styles/font_styles/t_sci_fi_regular.tres")

static func custom_tooltip(for_text : String):
	var tooltip : Label = Label.new()
	for_text = for_text
	tooltip.text = for_text.replace("(", "[ ").replace(")", " ]").replace("\n", " ")
	tooltip.theme = EditorUI.tooltip_font
	tooltip.add_theme_stylebox_override("normal", tooltip_panel)
	tooltip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return tooltip
