extends Control
class_name FileManager

"TODO ERROR"#add error handling whenever fileaccess and diraccess are used
#this filemanager can only select single files currently which is fine for my purposes

@export var file_icon : Texture2D
@export var folder_icon : Texture2D
@export var file_list_max_entries : int = 10

@export var dir_start_linux : String = "/"
@export var dir_start_windows : String = "C:"
var dir_start : String
var selected_filters : Array
var dir_access : DirAccess

#for moving to trash and renaming
var selected_file_or_folder : String

var dir_history : Array[String]
var dir_history_index : int = 0
var subfolder_count : int = 0

#ui
var l_title : Label
#top controls
var b_previous_folder : Button
var b_next_folder : Button
var b_parent_folder : Button
var b_refresh : Button
var b_list_folder : Button
var b_root_folder : Button
var b_new_folder : Button
var b_rename : Button
var b_trash : Button
var b_close_page : Button

#second row
var le_filepath : LineEdit
var ob_drives : OptionButton

#file display
var t_main_file_display : Tree
var hbc_list_file_display : HBoxContainer
var t_list_file_display : Array[Tree]
var t_list_file_display_extra : Array[Tree]
var pc_mode_data_holder : PanelContainer
var mode_name_to_data_map : Dictionary
var current_mode : StringName


#bottom controls
var l_file_count : LabelNumeric
var l_subfolder_count : LabelNumeric
var b_accept : Button
var le_file_name : LineEdit
var ob_filters : OptionButton

signal accept_button_pressed(path : String, filename : String)

#var i : int = 0
#enum Icon
# Called when the node enters the scene tree for the first time.
func _ready():
#initialize ui variables
	b_previous_folder = %ButtonPreviousFolder
	b_next_folder = %ButtonNextFolder
	b_parent_folder = %ButtonParentFolder
	b_refresh = %ButtonRefresh
	b_list_folder = %ButtonList
	b_root_folder = %ButtonRoot
	b_new_folder = %ButtonNewFolder
	b_rename = %ButtonRename
	b_trash = %ButtonTrash
	
	b_close_page = %ButtonClosePage
	le_filepath = %LineEditFilepath
	ob_drives = %OptionButtonDrives
	l_title = %LabelTitle
	
#file displays
	t_main_file_display = %TreeMainFileDisplay
	hbc_list_file_display = %HBoxContainerListFileDisplay
	#root of tree
	t_main_file_display.create_item()
	
#options/mode data container
	pc_mode_data_holder = %PanelContainerModeData
	
	
#bottom controls
	l_file_count = %LabelFileCount
	l_subfolder_count = %LabelSubfolderCount
	b_accept = %ButtonAccept
	le_file_name = %LineEditFileName
	ob_filters = %OptionButtonFilters
	
#initialize control variables
	if OS.has_feature("windows"):
		dir_start = dir_start_windows
	elif OS.has_feature("linuxbsd"):
		dir_start = dir_start_linux
	
	dir_history.append(dir_start)
	dir_access = DirAccess.open(dir_start)
	
	for drive in DirAccess.get_drive_count():
		var drive_name : String = DirAccess.get_drive_name(drive)
		ob_drives.add_item(drive_name)
	
#get configs from pc_configuration_data
	for mode_data in pc_mode_data_holder.get_children():
		mode_data = mode_data as FileManagerModeData
		mode_name_to_data_map[mode_data.mode_name] = mode_data
		
		#create 2d array
		for filter in mode_data.filters:
			filter = filter as String
			mode_data.filters_internal.append(filter.split(","))
	
	pc_mode_data_holder.visible = false
	update_file_display(dir_start)
	
	
	#signals
	b_close_page.pressed.connect(on_b_close_page_pressed)
	
	t_main_file_display.item_activated.connect(on_t_file_display_item_activated.bind(t_main_file_display))
	t_main_file_display.item_selected.connect(on_t_file_display_item_selected.bind(t_main_file_display))
	
	b_next_folder.pressed.connect(on_b_next_folder_pressed)
	b_previous_folder.pressed.connect(on_b_previous_folder_pressed)
	b_parent_folder.pressed.connect(on_b_parent_folder_pressed)
	b_refresh.pressed.connect(on_b_refresh_pressed)
	b_list_folder.pressed.connect(on_b_list_folder_pressed)
	b_root_folder.pressed.connect(on_b_root_folder_pressed)
	b_new_folder.pressed.connect(on_b_new_folder_pressed)
	b_rename.pressed.connect(on_b_rename_pressed)
	b_trash.pressed.connect(on_b_trash_pressed)
	
	
	le_filepath.text_submitted.connect(on_le_filepath_text_submitted)
	ob_drives.item_selected.connect(on_ob_drives_item_selected)
	ob_filters.item_selected.connect(on_ob_filters_item_selected)
	b_accept.pressed.connect(on_b_accept_pressed)


#helper functions
func popup(mode_name : StringName):
	#i dont actually think users want to re-navigate back each time this opens
	#change_dir(dir_start, true)
	var mode_data : FileManagerModeData = mode_name_to_data_map.get(mode_name)
	if mode_data == null:
		push_error("file manager mode not found: ", mode_name)
		return
	
	#keep track of current mode
	current_mode = mode_name
	
	#set filemanager title
	l_title.text = mode_data.mode_title
	
	#if there is no settings ui, hide that panel
	if mode_data.settings_ui_array.is_empty():
		pc_mode_data_holder.visible = false
	#else, hide all except the current modes options
	else:
		pc_mode_data_holder.visible = true
		for settings in pc_mode_data_holder.get_children():
			settings.visible = false
		mode_data.visible = true
	
	#initialize filters ui
	ob_filters.clear()
	if not mode_data.filters.is_empty():
		for filters in mode_data.filters:
			ob_filters.add_item(filters)
			selected_filters = mode_data.filters_internal[0]
	else:
		ob_filters.add_item("*")
		selected_filters = ["*"]
	
	ob_filters.selected = 0
	visible = true


func close():
	visible = false


#for easily reading ui state from outside
func get_options_ui(mode_name : StringName):
	var mode_data = mode_name_to_data_map.get(mode_name)
	if mode_data == null:
		push_error("file manager mode data not found: ", mode_name)
	return mode_data


#for easily refreshing from outside after a file operation
func refresh_file_manager():
	update_file_display(dir_access.get_current_dir())


func change_dir(input : String):
	dir_access.change_dir(input)
	var current_dir : String = dir_access.get_current_dir()
	
	update_file_display(current_dir)


func change_dir_undoable(input : String):
	if dir_history_index != dir_history.size() - 1:
		#pop everything past the index off
		var i : int = 0
		var index_to_end : int = (dir_history.size() - 1) - dir_history_index
		while i < index_to_end:
			dir_history.pop_back()
			i = i + 1
	
	dir_history.append(dir_access.get_current_dir())
	dir_history_index = dir_history.size() - 1
	
	change_dir(input)


func update_file_display(current_dir : String):
	var folders : PackedStringArray = dir_access.get_directories()
	var files : PackedStringArray = dir_access.get_files()
	var total : int = folders.size() + files.size()
	
	subfolder_count = current_dir.split("/").size() - 1
	
	le_filepath.text = ProjectSettings.globalize_path(current_dir)
	l_file_count.number = total
	l_subfolder_count.number = subfolder_count
	
	#use t_list_file_display
	if b_list_folder.button_pressed:
		%ScrollContainerListFileDisplay.visible = true
		t_main_file_display.visible = false
		#cast to float to get rid of int division warning
		#always show at least 4 tree displays
		var required_trees : int = max(ceil(float(total) / file_list_max_entries), 4)
		var existing_trees : Array[Node] = hbc_list_file_display.get_children()
		if required_trees > existing_trees.size():
			var k : int = existing_trees.size()
			while k < required_trees:
				var new : Tree = Tree.new()
				new.item_activated.connect(on_t_file_display_item_activated.bind(new))
				new.item_selected.connect(on_t_file_display_item_selected.bind(new))
				new.hide_folding = true
				new.hide_root = true
				new.custom_minimum_size = Vector2i(248, 301)
				new.add_theme_constant_override("v_separation", 3)
				var empty : StyleBoxEmpty = StyleBoxEmpty.new()
				new.add_theme_stylebox_override("focus", empty)
				#create root
				new.create_item()
				hbc_list_file_display.add_child(new)
				new.set_column_clip_content(0, true)
				#BROKEN
				new.scroll_horizontal_enabled = false
				new.scroll_vertical_enabled = false
				
				k = k + 1
		
		elif required_trees <= existing_trees.size():
			#unhide needed tree nodes
			var j : int = 0
			while j < required_trees:
				existing_trees[j].visible = true
				j = j + 1
			
			#hide unneeded tree nodes
			j = required_trees
			while j < existing_trees.size():
				existing_trees[j].visible = false
				j = j + 1
		
		#refresh after possible changes
		#only get tree nodes that are set visible
		existing_trees = hbc_list_file_display.get_children().filter(func(input):
			return input.visible
			)
		
		#only populate trees with up to 10 items each
		var i : int = 0
		var paging : int = 0
		var start_files : int = folders.size()
		var end_files : int = start_files + files.size()
		while i < existing_trees.size():
			var given_folders = []
			var given_files = []
			var j : int = 0
			while j < file_list_max_entries:
				if paging < start_files:
					given_folders.append(folders[paging])
				elif paging < end_files:
					given_files.append(files[paging - start_files])
				j = j + 1
				paging = paging + 1
			
			regen_tree_ui(existing_trees[i], given_folders, given_files)
			existing_trees[i].size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			existing_trees[i].size = existing_trees[i].custom_minimum_size
			i = i + 1
		
		
		
	#use t_main_file_display
	else:
		%ScrollContainerListFileDisplay.visible = false
		t_main_file_display.visible = true
		regen_tree_ui(t_main_file_display, folders, files)


func regen_tree_ui(tree : Tree, folders : PackedStringArray, files : PackedStringArray):
	var root : TreeItem = tree.get_root()
	#clear existing tree items
	for i in root.get_children():
		i.free()
	
	for folder in folders:
		var new : TreeItem = root.create_child()
		new.set_text(0, folder)
		new.set_icon(0, folder_icon)
		new.set_tooltip_text(0, " ")
		new.set_text_overrun_behavior(0, TextServer.OVERRUN_TRIM_CHAR)
	
	for file in files:
		var new : TreeItem = root.create_child()
		new.set_text(0, file)
		new.set_icon(0, file_icon)
		new.set_tooltip_text(0, " ")
		new.set_text_overrun_behavior(0, TextServer.OVERRUN_TRIM_CHAR)
		if selected_filters != ["*"]:
			var is_file_matching : bool = false
			for filter in selected_filters:
				is_file_matching = is_file_matching or file.match(filter)
			
			if not is_file_matching:
				new.set_selectable(0, false)
				new.set_custom_color(0, Color(0.3,0.3,0.3))


#signals
func on_b_close_page_pressed():
	close()


#folder buttons
func on_b_previous_folder_pressed():
	#do not exceed 0
	dir_history_index = max(dir_history_index - 1, 0)
	change_dir(dir_history[dir_history_index])


func on_b_next_folder_pressed():
	#do not exceed array size
	dir_history_index = min(dir_history_index + 1, dir_history.size() - 1)
	change_dir(dir_history[dir_history_index])


func on_b_parent_folder_pressed():
	change_dir_undoable("..")


func on_b_root_folder_pressed():
	change_dir_undoable(dir_start)


func on_b_new_folder_pressed():
	if le_file_name.text.is_valid_filename():
		DirAccess.make_dir_absolute(dir_access.get_current_dir().path_join(le_file_name.text))
	refresh_file_manager()


func on_b_rename_pressed():
	if le_file_name.text.is_valid_filename():
		dir_access.rename(selected_file_or_folder, le_file_name.text)
	refresh_file_manager()


func on_b_trash_pressed():
	OS.move_to_trash(ProjectSettings.globalize_path(dir_access.get_current_dir().path_join(selected_file_or_folder)))
	refresh_file_manager()


func on_b_refresh_pressed():
	refresh_file_manager()


func on_b_list_folder_pressed():
	update_file_display(dir_access.get_current_dir())


func on_le_filepath_text_submitted(new : String):
	if dir_access.dir_exists(new):
		change_dir_undoable(new)


func on_ob_drives_item_selected(index : int):
	var drive : String = ob_drives.get_item_text(index)
	change_dir_undoable(ProjectSettings.localize_path(drive))
	le_filepath.text = drive


func on_ob_filters_item_selected(index : int):
	selected_filters = mode_name_to_data_map.get(current_mode).filters_internal[index]
	update_file_display(dir_access.get_current_dir())


#important
func on_b_accept_pressed():
	if not le_file_name.text.is_valid_filename():
		return
	accept_button_pressed.emit(dir_access.get_current_dir(), le_file_name.text)
	update_file_display(dir_access.get_current_dir())


#tree signals
func on_t_file_display_item_activated(tree : Tree):
	var selected : TreeItem = tree.get_selected()
	if selected == null:
		return
	var selected_text : String = selected.get_text(0)
	
	if dir_access.dir_exists(dir_access.get_current_dir() + "/" + selected_text):
		change_dir_undoable(selected_text)
	elif dir_access.file_exists(dir_access.get_current_dir() + "/" + selected_text):
		le_file_name.text = selected_text.rsplit(".", true, 1)[0]

#for deleting (moving to trash) and renaming
func on_t_file_display_item_selected(tree : Tree):
	var selected : TreeItem = tree.get_selected()
	if selected == null:
		return
	selected_file_or_folder = selected.get_text(0)
