extends Control
class_name UIV2

"TODO"#add create color button function, material button function, part button function

static var signals : Array[Callable]

#top menu bar
static var mb_top_bar : MenuBar
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
static var b_dropdown_part : Button
static var b_delete_tool : Button
static var b_paint_tool : Button
static var b_dropdown_color : Button
static var b_material_tool : Button
static var b_dropdown_material : Button
static var b_lock_tool : Button


#array of control nodes which are iterated over to check if the mouse is over ui
static var no_drag_ui : Array[Control]




static func initialize(tree_access : Node):
	
	pass

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
