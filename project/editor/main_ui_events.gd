extends RefCounted
class_name MainUIEvents

#this namespace serves as a central registry for ui events that
#interact with namespaces or classes other than their own


#set selected state and is_drag_tool
static func select_tool(button : Button):
	if not Main.selected_tool_handle_array.is_empty():
		TransformHandleUtils.set_tool_handle_array_active(Main.selected_tool_handle_array, false)
	"TODO"#use dynamic dispatch here with a dict mapping instead of this ugly match thing
	var has_associated_transform_handles : bool = false
	if button.button_pressed:
		#all tools require hovering over parts and detecting them
		Main.is_hover_tool = true
		WorkspaceManager.hover_selection_box.material_highlighter()
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
				WorkspaceManager.hover_selection_box.material_regular_color(Color.ORANGE)
			EditorUI.b_paint_tool:
				Main.selected_tool = Main.SelectedToolEnum.t_color
				has_associated_transform_handles = false
				Main.is_drag_tool = false
				WorkspaceManager.hover_selection_box.material_regular_color(WorkspaceManager.selected_color)
			EditorUI.b_delete_tool:
				Main.selected_tool = Main.SelectedToolEnum.t_delete
				has_associated_transform_handles = false
				Main.is_drag_tool = false
				WorkspaceManager.hover_selection_box.material_regular_color(Color.RED)
			EditorUI.b_lock_tool:
				Main.selected_tool = Main.SelectedToolEnum.t_lock
				has_associated_transform_handles = false
				Main.is_drag_tool = false
	else:
		Main.selected_tool = Main.SelectedToolEnum.none
		has_associated_transform_handles = false
		Main.is_drag_tool = false
		Main.is_hover_tool = false
	
	if has_associated_transform_handles:
		Main.selected_tool_handle_array = Main.transform_handle_root.tool_handle_array[Main.selected_tool]
	else:
		Main.selected_tool_handle_array = []
	
	if Main.is_drag_tool:
		if has_associated_transform_handles:
			Main.set_transform_handle_root_position(Main.transform_handle_root, WorkspaceManager.selected_parts_abb.transform, Main.local_transform_active, Main.selected_tool_handle_array)
			if WorkspaceManager.selected_parts_array.size() > 0:
				TransformHandleUtils.set_tool_handle_array_active(Main.selected_tool_handle_array, true)


static func on_spawn_pressed():
	WorkspaceManager.part_spawn(WorkspaceManager.selected_part_type)


static func on_color_selected(button : Button):
	WorkspaceManager.selected_color = button.self_modulate
	WorkspaceManager.hover_selection_box.material_regular_color(button.self_modulate)
	EditorUI.l_message.text = button.tooltip_text + " selected"


static func on_part_type_selected(button : Button):
	WorkspaceManager.selected_part_type = WorkspaceManager.available_part_types[WorkspaceManager.button_part_type_mapping[button]]
	EditorUI.l_message.text = button.text.capitalize() + " selected"


static func on_material_selected(button : Button):
	WorkspaceManager.selected_material = WorkspaceManager.available_materials[WorkspaceManager.button_material_mapping[button]]
	EditorUI.l_message.text = button.text + " selected"


static func on_snap_text_changed(new_text):
	Main.positional_snap_increment = float(EditorUI.le_rotation_step.text)
	Main.rotational_snap_increment = float(EditorUI.le_unit_step.text)


static func on_snap_button_pressed(button):
	match button:
		EditorUI.b_rotation_increment:
			Main.rotational_snap_increment = Main.rotational_snap_increment + EditorUI.le_rotation_step_increment_step.true_value
		EditorUI.b_rotation_decrement:
			Main.rotational_snap_increment = Main.rotational_snap_increment - EditorUI.le_rotation_step_increment_step.true_value
		EditorUI.b_rotation_double:
			Main.rotational_snap_increment = Main.rotational_snap_increment * 2
		EditorUI.b_rotation_half:
			Main.rotational_snap_increment = Main.rotational_snap_increment * 0.5
		EditorUI.b_unit_increment:
			Main.positional_snap_increment = Main.positional_snap_increment + EditorUI.le_unit_step_increment_step.true_value
		EditorUI.b_unit_decrement:
			Main.positional_snap_increment = Main.positional_snap_increment - EditorUI.le_unit_step_increment_step.true_value
		EditorUI.b_unit_double:
			Main.positional_snap_increment = Main.positional_snap_increment * 2
		EditorUI.b_unit_half:
			Main.positional_snap_increment = Main.positional_snap_increment * 0.5
	
	Main.positional_snap_increment = max(Main.positional_snap_increment, 0)
	Main.rotational_snap_increment = max(Main.rotational_snap_increment, 0)
	
	EditorUI.le_unit_step.text = str(Main.positional_snap_increment)
	EditorUI.le_rotation_step.text = str(Main.rotational_snap_increment)
	


static func on_local_transform_active_set(active):
	Main.local_transform_active = active
	Main.set_transform_handle_root_position(Main.transform_handle_root, WorkspaceManager.selected_parts_abb.transform, Main.local_transform_active, Main.selected_tool_handle_array)

static func on_snapping_active_set(active):
	Main.snapping_active = active

#i already tried doing a dynamic dispatch with function arrays, it sucked
#if else is much more readable in this case
static func on_top_bar_id_pressed(id : int, pm : PopupMenu):
	#file dropdown----------------------
	if pm == EditorUI.pm_file:
		if id == 0:
			#save (model) as
			pass
		elif id == 1:
			#save (model)
			
			WorkspaceManager.save_model()
		elif id == 2:
			#load model
			WorkspaceManager.load_model()
		elif id == 3:
			#import model (planned: .gltf, .obj)
			pass
		elif id == 4:
			#export model
			pass
		
	#edit dropdown----------------------
	elif pm == EditorUI.pm_edit:
		if id == 0:
			#undo
			WorkspaceManager.undo()
		elif id == 1:
			#redo
			WorkspaceManager.redo()
		elif id == 3:
			WorkspaceManager.selection_set_to_workspace()
		elif id == 4:
			#ctrl c copy selection
			WorkspaceManager.selection_copy()
		elif id == 5:
			#ctrl v paste selection
			WorkspaceManager.selection_paste()
		elif id == 6:
			#ctrl x cut selection
			WorkspaceManager.selection_copy()
			WorkspaceManager.selection_delete()
		elif id == 7:
			#ctrl d duplicate selection
			WorkspaceManager.selection_duplicate()
		elif id == 8:
			#delete clear selection
			WorkspaceManager.selection_delete()
		elif id == 8:
			#settings window
			pass
		
		
		#asset manager stuff, not implemented yet, dropped for v0.1
	#asset dropdown---------------------
	elif pm == EditorUI.pm_assets:
		pass
		
		
	#help dropdown----------------------
	elif pm == EditorUI.pm_help:
		if id == 0:
			EditorUI.dd_manual.popup()
		elif id == 1:
			EditorUI.dd_license.popup()
