extends RefCounted
class_name MainUIEvents

#this namespace serves as a central registry for ui events that
#interact with namespaces or classes other than their own

"TODO"#put all the things one has to edit to add a new tool to transformhandleroot into one file (if possible)
#set selected state and is_drag_tool
static func select_tool(button : Button):
	if not Main.selected_tool_handle_array.is_empty():
		TransformHandleUtils.set_tool_handle_array_active(Main.selected_tool_handle_array, false)
	
	var has_associated_transform_handles : bool = false
	if button.button_pressed:
		match button:
			EditorUI.b_drag_tool:
				Main.selected_tool = Main.SelectedToolEnum.t_drag
				has_associated_transform_handles = false
				Main.is_drag_tool = true
			EditorUI.b_move_tool:
				Main.selected_tool = Main.SelectedToolEnum.t_move
				has_associated_transform_handles = true
				Main.is_drag_tool = true
			EditorUI.b_rotate_tool:
				Main.selected_tool = Main.SelectedToolEnum.t_rotate
				has_associated_transform_handles = true
				Main.is_drag_tool = true
			EditorUI.b_scale_tool:
				Main.selected_tool = Main.SelectedToolEnum.t_scale
				has_associated_transform_handles = true
				Main.is_drag_tool = true
			EditorUI.b_material_tool:
				Main.selected_tool = Main.SelectedToolEnum.t_material
				has_associated_transform_handles = false
				Main.is_drag_tool = false
			EditorUI.b_paint_tool:
				Main.selected_tool = Main.SelectedToolEnum.t_color
				has_associated_transform_handles = false
				Main.is_drag_tool = false
			EditorUI.b_delete_tool:
				Main.selected_tool = Main.SelectedToolEnum.t_delete
				has_associated_transform_handles = false
				Main.is_drag_tool = false
			EditorUI.b_lock_tool:
				Main.selected_tool = Main.SelectedToolEnum.t_lock
				has_associated_transform_handles = false
				Main.is_drag_tool = false
	else:
		Main.selected_tool = Main.SelectedToolEnum.none
		has_associated_transform_handles = false
		Main.is_drag_tool = false
	
	if has_associated_transform_handles:
		Main.selected_tool_handle_array = Main.transform_handle_root.tool_handle_array[Main.selected_tool]
	else:
		Main.selected_tool_handle_array = []
	
	if Main.is_drag_tool:
		if has_associated_transform_handles:
			Main.set_transform_handle_root_position(Main.transform_handle_root, Main.selected_parts_abb.transform, Main.local_transform_active, Main.selected_tool_handle_array)
			if WorkspaceManager.selected_parts_array.size() > 0:
				TransformHandleUtils.set_tool_handle_array_active(Main.selected_tool_handle_array, true)
		
	else:
		WorkspaceManager.selection_clear()


static func on_spawn_pressed():
	WorkspaceManager.spawn_part(Main.raycast_length, Main.part_spawn_distance, Main.cam)


static func on_color_selected(button : Button):
	WorkspaceManager.selected_color = button.self_modulate
	EditorUI.l_message.text = button.tooltip_text + " selected"


static func on_part_type_selected(button : Button):
	WorkspaceManager.selected_part_type = WorkspaceManager.available_part_types[WorkspaceManager.button_part_type_mapping[button]]
	EditorUI.l_message.text = button.text.capitalize() + " selected"


static func on_material_selected(button : Button):
	WorkspaceManager.selected_material = WorkspaceManager.available_materials[WorkspaceManager.button_material_mapping[button]]
	EditorUI.l_message.text = button.text + " selected"


static func on_snap_text_changed(line_edit):
	var r_dict = EditorUI.main_on_snap_text_changed(line_edit, Main.positional_snap_increment, Main.rotational_snap_increment)
	Main.positional_snap_increment = r_dict.positional_snap_increment
	Main.rotational_snap_increment = r_dict.rotational_snap_increment


static func on_snap_button_pressed(button):
	var r_dict = EditorUI.on_snap_button_pressed(button, Main.positional_snap_increment, Main.rotational_snap_increment)
	Main.positional_snap_increment = r_dict.positional_snap_increment
	Main.rotational_snap_increment = r_dict.rotational_snap_increment


static func on_local_transform_active_set(active):
	Main.local_transform_active = active
	Main.set_transform_handle_root_position(Main.transform_handle_root, Main.selected_parts_abb.transform, Main.local_transform_active, Main.selected_tool_handle_array)

static func on_snapping_active_set(active):
	Main.snapping_active = active
