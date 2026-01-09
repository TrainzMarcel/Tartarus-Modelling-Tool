extends RefCounted
class_name MainUIEvents

#this namespace serves as a central registry for ui events that
#interact with namespaces or classes other than their own


#set selected state and is_drag_tool
static func select_tool(button : Button):
	ToolManager.select_tool(button)


static func on_pivot_reset_pressed():
	if ToolManager.selected_tool != ToolManager.SelectedToolEnum.t_pivot:
		WorkspaceManager.pivot_mesh.visible = false
		WorkspaceManager.pivot_custom_mode_active = false
	SelectionManager.refresh_bounding_box()
	WorkspaceManager.pivot_local_transform = Transform3D.IDENTITY
	WorkspaceManager.pivot_transform = SelectionManager.selected_parts_abb.transform
	ToolManager.handle_set_root_position(
		Main.transform_handle_root,
		SelectionManager.selected_parts_abb,
		WorkspaceManager.pivot_transform,
		WorkspaceManager.pivot_custom_mode_active,
		Main.local_transform_active,
		ToolManager.selected_tool_handle_array
	)


static func on_group_selection_pressed():
	SelectionManager.selection_group()
	return


static func on_ungroup_selection_pressed():
	SelectionManager.selection_ungroup()
	return


static func on_spawn_pressed():
	WorkspaceManager.part_spawn(WorkspaceManager.selected_part_type)


static func on_color_selected(button : Button):
	WorkspaceManager.selected_color = button.self_modulate
	SelectionManager.hover_selection_box.material_regular_color(button.self_modulate)
	EditorUI.set_l_msg(button.tooltip_text + " selected")


static func on_part_type_selected(button : Button):
	WorkspaceManager.selected_part_type = WorkspaceManager.available_part_types[WorkspaceManager.button_part_type_mapping[button]]
	EditorUI.set_l_msg(button.text.capitalize() + " selected")
	WorkspaceManager.part_spawn(WorkspaceManager.selected_part_type)


static func on_material_selected(button : Button):
	WorkspaceManager.selected_material = WorkspaceManager.available_materials[WorkspaceManager.button_material_mapping[button]]
	EditorUI.set_l_msg(button.text + " selected")


static func on_snap_text_changed(new_text):
	Main.positional_snap_increment = float(EditorUI.le_unit_step.text)
	Main.rotational_snap_increment = float(EditorUI.le_rotation_step.text)


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
	ToolManager.handle_set_root_position(
		Main.transform_handle_root,
		SelectionManager.selected_parts_abb,
		WorkspaceManager.pivot_transform,
		WorkspaceManager.pivot_custom_mode_active,
		Main.local_transform_active,
		ToolManager.selected_tool_handle_array
	)


static func on_snapping_active_set(active):
	Main.snapping_active = active


static func on_file_manager_accept_pressed(filepath : String, name : String):
	WorkspaceManager.confirm_save_load(filepath, name)

#i already tried doing a dynamic dispatch with function arrays, it sucked
#if else is much more readable in this case
static func on_top_bar_id_pressed(id : int, pm : PopupMenu):
	#file dropdown----------------------
	if pm == EditorUI.pm_file:
		if id == 0:
			#save (model) as
			WorkspaceManager.request_save_as()
		elif id == 1:
			#save (model)
			WorkspaceManager.request_save()
		elif id == 2:
			#load model
			WorkspaceManager.request_load()
		elif id == 3:
			#import model (planned: .res/tres, .gltf, .obj)
			pass
		elif id == 4:
			#export model
			pass
			#var groups : Array[Array] = MeshUtils.group_parts_by_material_and_color(WorkspaceManager.workspace.get_children().filter(func(input): return input is Part))
			#var mesh = MeshUtils.create_mesh_from_part_groupings(groups)
			#MeshUtils.add_metadata_to_mesh(groups, mesh)
			#ResourceSaver.save(mesh, "/home/marci/Desktop/save testing/MAOW.res", ResourceSaver.FLAG_BUNDLE_RESOURCES)
		
	#edit dropdown----------------------
	elif pm == EditorUI.pm_edit:
		if id == 0:
			#undo
			WorkspaceManager.undo()
		elif id == 1:
			#redo
			WorkspaceManager.redo()
		elif id == 3:
			#select all
			SelectionManager.selection_set_to_workspace_undoable()
			SelectionManager.post_selection_update()
		elif id == 4:
			#ctrl c copy selection
			SelectionManager.selection_copy()
			EditorUI.set_l_msg("copied " + str(SelectionManager.parts_clipboard.size()) + " parts")
		elif id == 5:
			#ctrl v paste selection
			SelectionManager.selection_paste_undoable()
			SelectionManager.post_selection_update()
			EditorUI.set_l_msg("pasted " + str(SelectionManager.parts_clipboard.size()) + " parts")
		elif id == 6:
			#ctrl x cut selection
			SelectionManager.selection_copy()
			SelectionManager.selection_delete_undoable()
			SelectionManager.post_selection_update()
			EditorUI.set_l_msg("cut " + str(SelectionManager.parts_clipboard.size()) + " parts")
		elif id == 7:
			#ctrl d duplicate selection
			SelectionManager.selection_duplicate_undoable()
			SelectionManager.post_selection_update()
			EditorUI.set_l_msg("duplicated " + str(SelectionManager.selected_parts_array.size()) + " parts")
		elif id == 8:
			#delete clear selection
			EditorUI.set_l_msg("deleted " + str(SelectionManager.selected_parts_array.size()) + " parts")
			SelectionManager.selection_delete()
			SelectionManager.post_selection_update()
		elif id == 8:
			#settings window
			pass
		
		
		#asset manager stuff, not implemented yet, dropped for v0.1
	#asset dropdown---------------------
	elif pm == EditorUI.pm_assets:
		#theres only one button anyway
		OS.shell_show_in_file_manager(ProjectSettings.globalize_path(FilePathRegistry.data_folder_assets))
		
	#help dropdown----------------------
	elif pm == EditorUI.pm_help:
		if id == 0:
			EditorUI.dd_manual.popup()
		elif id == 1:
			EditorUI.dd_license.popup()
