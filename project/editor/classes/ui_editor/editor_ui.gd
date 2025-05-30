extends Control
class_name EditorUI

"TODO"#add create color button function, material button function, part button function

#ui naming convention: prefix the default node name with what kind of ui it corresponds too

#top left block
	#top menu bar
static var pm_file : PopupMenu
static var pm_edit : PopupMenu
static var pm_assets : PopupMenu
static var pm_help : PopupMenu

	#mapping from pm to array index
static var pm_top_mapping : Dictionary


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
static var ui_no_drag : Array[Control]

#array of control nodes which are iterated over to check if any menus are open
#and blocking the editor view
#had to remove the type because filedialog is of type window
static var ui_menu : Array#[Control]

#document displays
static var dd_manual : DocumentDisplay
static var dd_license : DocumentDisplay

#file manager
static var fd_file : FileDialog


func initialize(
	on_spawn_pressed : Callable,
	select_tool : Callable,
	main_on_snap_button_pressed : Callable,
	main_on_snap_text_changed : Callable,
	on_local_transform_active_set : Callable,
	on_snapping_active_set : Callable,
	on_color_selected : Callable,
	on_material_selected : Callable,
	on_part_type_selected : Callable,
	on_top_bar_id_pressed : Callable
	):
	
#assign all ui nodes
	#top left block
		#top menu bar
	#mb_top_bar = %MenuBarTop
	pm_file = %File
	pm_edit = %Edit
	pm_assets = %Assets
	pm_help = %Help
	#dict key to array index
	pm_top_mapping = WorkspaceManager.create_mapping(%MenuBarTop.get_children())
	
	
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
	
	#document displays
	dd_manual = %DocumentDisplayManual
	dd_license = %DocumentDisplayLicense
	
	#file dialog
	fd_file = %FileDialog
	
	ui_menu = [
		%DocumentDisplayManual,
		%DocumentDisplayLicense,
		$AssetManager,
		fd_file
	]
	
	ui_no_drag = [
		$PanelContainerTopLeftBlock,
		$PanelContainerBottomLeftBlock,
		$BottomPanel,
		%DocumentDisplayManual,
		%DocumentDisplayLicense,
		$PanelContainerTopLeftBlock/MarginContainer/VBoxContainer/ToolBar/HBoxContainerPaintTool/DropDownButton/PanelContainerColor,
		$PanelContainerTopLeftBlock/MarginContainer/VBoxContainer/ToolBar/HBoxContainerMaterialTool/DropDownButton/PanelContainerMaterial,
		$PanelContainerTopLeftBlock/MarginContainer/VBoxContainer/ToolBar/HBoxContainerSpawnPart/DropDownButton/PanelContainerPartType
	]
	
#initialize picker/selector menus
	#future
	#var default_palette : WorkspaceManager.ColorPalette = WorkspaceManager.ColorPalette.new()
	#default_palette.color_array = r_dict_2.color_array
	#default_palette.color_name_array = r_dict_2.color_name_array
	#WorkspaceManager.available_color_palette_array.append(default_palette)
	#WorkspaceManager.equipped_color_palette = default_palette
	
	
	var r_dict : Dictionary = WorkspaceManager.read_colors_and_create_colors(FileAccess.get_file_as_string(FilePathRegistry.data_file_color))
	var r_dict_2 : Dictionary = AutomatedColorPalette.full_color_sort(gc_paint_panel, r_dict.color_array, r_dict.color_name_array)
	EditorUI.create_color_buttons(gc_paint_panel, on_color_selected, r_dict_2.color_array, r_dict_2.color_name_array)
	EditorUI.create_material_buttons(on_material_selected)
	EditorUI.create_part_type_buttons(on_part_type_selected)
	
	
	#set tooltip script in filedialog
	EditorUI.customize_file_dialog(fd_file)
	
	#DataLoader.read_parts_and_create_parts()
	#UI.create_part_buttons(gc_part_panel, on_part_selected, r_dict_3.part_array)
	#DataLoader.read_materials_and_create_materials()
	#UI.create_material_buttons()
	
#connect signals
	b_snapping_enabled.toggled.connect(on_snapping_active_set)
	b_local_transform.toggled.connect(on_local_transform_active_set)
	
	le_rotation_step.text_changed.connect(main_on_snap_text_changed)
	le_unit_step.text_changed.connect(main_on_snap_text_changed)
	
	b_rotation_increment.pressed.connect(main_on_snap_button_pressed.bind(b_rotation_increment))
	b_rotation_decrement.pressed.connect(main_on_snap_button_pressed.bind(b_rotation_decrement))
	b_rotation_double.pressed.connect(main_on_snap_button_pressed.bind(b_rotation_double))
	b_rotation_half.pressed.connect(main_on_snap_button_pressed.bind(b_rotation_half))
	b_unit_increment.pressed.connect(main_on_snap_button_pressed.bind(b_unit_increment))
	b_unit_decrement.pressed.connect(main_on_snap_button_pressed.bind(b_unit_decrement))
	b_unit_double.pressed.connect(main_on_snap_button_pressed.bind(b_unit_double))
	b_unit_half.pressed.connect(main_on_snap_button_pressed.bind(b_unit_half))
	
	
	
	b_drag_tool.pressed.connect(select_tool.bind(b_drag_tool))
	b_move_tool.pressed.connect(select_tool.bind(b_move_tool))
	b_rotate_tool.pressed.connect(select_tool.bind(b_rotate_tool))
	b_scale_tool.pressed.connect(select_tool.bind(b_scale_tool))
	b_delete_tool.pressed.connect(select_tool.bind(b_delete_tool))
	b_paint_tool.pressed.connect(select_tool.bind(b_paint_tool))
	b_material_tool.pressed.connect(select_tool.bind(b_material_tool))
	b_lock_tool.pressed.connect(select_tool.bind(b_lock_tool))
	b_spawn_part.pressed.connect(on_spawn_pressed)
	
	pm_file.id_pressed.connect(on_top_bar_id_pressed.bind(pm_file))
	pm_edit.id_pressed.connect(on_top_bar_id_pressed.bind(pm_edit))
	pm_assets.id_pressed.connect(on_top_bar_id_pressed.bind(pm_assets))
	pm_help.id_pressed.connect(on_top_bar_id_pressed.bind(pm_help))


#theoretically should work for all ui in the program
#releases focus if user presses enter while focused into line or text edit
func _input(event):
	if event is InputEventKey:
		if (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER) and not event.shift_pressed:
			var focus_owner : Control = get_viewport().gui_get_focus_owner()
			if focus_owner is LineEdit or focus_owner is TextEdit:
				focus_owner.release_focus()


#helper functions
"TODO"#replace this with generic function
static func create_color_buttons(parent : Control, on_color_selected : Callable, color_array : Array[Color], color_name_array : Array[String]):
	
	#unload existing nodes (when for example, color palette changes
	var existing_nodes : Array[Node] = parent.get_children()
	
	var sample_button : Button = load(FilePathRegistry.scene_color_button).instantiate()
	
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
		new.pressed.connect(on_color_selected.bind(new))
		parent.add_child(new)
		i = i + 1
	sample_button.queue_free()


static func create_part_type_buttons(on_part_type_selected : Callable):
	var file_list = DirAccess.get_files_at(FilePathRegistry.data_folder_part)
	
	var new_buttons : Array = UIUtils.update_list_ui(
	EditorUI.gc_part_panel,
	func(data_item, button):
		#strip .tres
		button.text = data_item.left(-5)
		button.pressed.connect(on_part_type_selected.bind(button))
		return button,
	preload(FilePathRegistry.scene_material_part_type_button).instantiate(),
	file_list
	)
	
	
	WorkspaceManager.button_part_type_mapping = WorkspaceManager.create_mapping(new_buttons)



static func create_material_buttons(on_material_selected):
	var file_list = DirAccess.get_files_at(FilePathRegistry.data_folder_material)
	
	var new_buttons : Array = UIUtils.update_list_ui(
	EditorUI.vbc_material_panel,
	func(data_item, button):
		#strip .tres
		button.text = data_item.left(-5).capitalize()
		button.pressed.connect(on_material_selected.bind(button))
		return button,
	preload(FilePathRegistry.scene_material_part_type_button).instantiate(),
	file_list
	)
	
	
	WorkspaceManager.button_material_mapping = WorkspaceManager.create_mapping(new_buttons)


#style file dialog like the editor
#todo clean up but not very important
static func customize_file_dialog(fd : FileDialog):
	fd_file.get_vbox().get_child(2).get_child(0).set_script(load(FilePathRegistry.script_tooltip_assign))
	var hbox = fd_file.get_vbox().get_child(0)
	var new_2 = Panel.new()
	new_2.size_flags_horizontal = SIZE_EXPAND_FILL
	new_2.custom_minimum_size = Vector2i(0, 2)
	new_2.add_theme_stylebox_override("panel", preload("res://editor/data_ui/styles/panel_styles/gradient_panel.tres"))
	var new_3 = new_2.duplicate()
	fd_file.get_vbox().add_child(new_2)
	fd_file.get_vbox().move_child(new_2, 1)
	fd_file.get_vbox().add_child(new_3)
	fd_file.get_vbox().move_child(new_3, 4)
	
	#duplicate buttons because styling and theming did not work for some damn reason
	for button in hbox.get_children():
		if not button is Button:
			continue
		
		var n = button.name
		var pos = button.get_index()
		var signals = button.get_signal_list()
		var new : Button = Button.new()
		
		new.set_script(load(FilePathRegistry.script_tooltip_assign))
		new.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
		new.custom_minimum_size = Vector2i(20, 20)
		new.toggle_mode = button.toggle_mode
		new.icon = button.icon
		new.text = button.text
		new.tooltip_text = button.tooltip_text.rstrip(".")
		
		new.add_theme_stylebox_override("normal", preload("res://editor/data_ui/styles/button_and_line_edit_styles/file_dialog/hover_normal.tres"))
		new.add_theme_stylebox_override("pressed", preload("res://editor/data_ui/styles/button_and_line_edit_styles/file_dialog/pressed.tres"))
		new.add_theme_stylebox_override("hover", preload("res://editor/data_ui/styles/button_and_line_edit_styles/file_dialog/hover_normal.tres"))
		new.add_theme_stylebox_override("disabled", preload("res://editor/data_ui/styles/button_and_line_edit_styles/file_dialog/hover_normal.tres"))
		var x = 1
		#brighten back and forth buttons
		#because theyre dark
		if pos == 0 or pos == 1 or pos == 2:
			x = 10
		new.add_theme_color_override("icon_normal_color", Color(x, x, x))
		new.add_theme_color_override("icon_focus_color", Color(x, x, x))
		new.add_theme_color_override("icon_hover_color", Color(x, x, x))
		new.add_theme_color_override("icon_pressed_color", Color(x, x, x))
		new.add_theme_color_override("icon_hover_pressed_color", Color(x, x, x))
		new.add_theme_stylebox_override("focus", preload("res://editor/data_ui/styles/button_and_line_edit_styles/focus_invisible.tres"))
		hbox.add_child(new)
		hbox.move_child(new, pos)
		
		for s in signals:
			var signals_c = button.get_signal_connection_list(s.name)
			for c in signals_c:
				if button.is_connected(s.name, c.callable) and not new.is_connected(s.name, c.callable):
					new.connect(s.name, c.callable)
		
		
		button.free()
		new.name = n
		


#tooltip styling
static var tooltip_panel : StyleBox = preload(FilePathRegistry.style_tooltip_panel)
static var tooltip_font : Theme = preload(FilePathRegistry.style_font_tooltip)

static func custom_tooltip(for_text : String):
	var tooltip : Label = Label.new()
	for_text = for_text
	tooltip.text = for_text.replace("(", "[ ").replace(")", " ]").replace("\n", " ")
	tooltip.theme = EditorUI.tooltip_font
	tooltip.add_theme_stylebox_override("normal", tooltip_panel)
	tooltip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return tooltip
