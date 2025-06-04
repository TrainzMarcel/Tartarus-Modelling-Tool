extends Control
class_name FileManager

var file_mode : FileMode = FileMode.open_file
enum FileMode {
	open_file,
	save_file
}



#filters like *.jpg
@export var file_icon : Texture2D
@export var folder_icon : Texture2D
@export var file_list_max_entries : int = 10

@export var filters : Array[String] = ["*"]
@export var dir_start : String = "/"
var selected_filter : String = filters[0]
var dir_current : String = "/"
var dir_current_globalized : String = ""
var dir_access : DirAccess
@export var dir_history : Array[String]
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
var b_close_page : Button

#second row
var le_filepath : LineEdit
var ob_drives : OptionButton

#file display
var t_main_file_display : Tree
var hbc_list_file_display : HBoxContainer
var t_list_file_display : Array[Tree]
var t_list_file_display_extra : Array[Tree]

#bottom controls
var l_file_count : LabelNumeric
var l_subfolder_count : LabelNumeric
var b_accept : Button
var le_file_name : LineEdit
var ob_filters : OptionButton

signal accepted_file(path : String, filename : String)

var i : int = 0
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
	b_close_page = %ButtonClosePage
	le_filepath = %LineEditFilepath
	ob_drives = %OptionButtonDrives
	l_title = %LabelTitle
	
#file displays
	t_main_file_display = %TreeMainFileDisplay
	hbc_list_file_display = %HBoxContainerListFileDisplay
	
	#root of tree
	t_main_file_display.create_item()
	
	
#bottom controls
	l_file_count = %LabelFileCount
	l_subfolder_count = %LabelSubfolderCount
	b_accept = %ButtonAccept
	le_file_name = %LineEditFileName
	ob_filters = %OptionButtonFilters
	
#initialize control variables
	dir_history.append(dir_start)
	dir_access = DirAccess.open(dir_start)
	
	for drive in DirAccess.get_drive_count():
		var drive_name : String = DirAccess.get_drive_name(drive)
		ob_drives.add_item(drive_name)
	
	for filter in filters:
		ob_filters.add_item(filter)
	ob_filters.selected = 0
	selected_filter = filters[0]
	
	update_file_display(dir_start)
	
	
	#signals
	b_close_page.pressed.connect(on_b_close_page_pressed)
	
	t_main_file_display.item_activated.connect(on_t_file_display_item_activated.bind(t_main_file_display))
	
	
	b_parent_folder.pressed.connect(on_b_parent_folder_pressed)
	b_next_folder.pressed.connect(on_b_next_folder_pressed)
	b_previous_folder.pressed.connect(on_b_previous_folder_pressed)
	b_root_folder.pressed.connect(on_b_root_folder_pressed)
	b_list_folder.pressed.connect(on_b_list_folder_pressed)
	b_refresh.pressed.connect(on_b_refresh_pressed)
	le_filepath.text_submitted.connect(on_le_filepath_text_submitted)
	ob_drives.item_selected.connect(on_ob_drives_item_selected)
	ob_filters.item_selected.connect(on_ob_filters_item_selected)


#helper functions
func popup():
	#i dont actually think users want to re-navigate back each time this opens
	#change_dir(dir_start, true)
	
	if file_mode == FileMode.save_file:
		l_title.text = "Save a file"
	else:
		l_title.text = "Load a file"
	
	
	visible = true


func close():
	visible = false


func change_dir(input : String, record : bool):
	var previous_dir : String = dir_access.get_current_dir()
	dir_access.change_dir(input)
	var current_dir : String = dir_access.get_current_dir()
	
	#record means add to visited filepath history
	if record:
		#if index is not at the end
		if dir_history_index != dir_history.size() - 1:
			#pop everything past the index off
			var i : int = 0
			var index_to_end : int = (dir_history.size() - 1) - dir_history_index
			while i < index_to_end:
				dir_history.pop_back()
				i = i + 1
			
		dir_history.append(dir_access.get_current_dir())
		dir_history_index = dir_history.size() - 1
	
	print("-----------------------------------------------------------------")
	if current_dir == "/":
		subfolder_count = 0
	elif current_dir != previous_dir:
		subfolder_count = current_dir.split("/").size() - 1
	
	
	update_file_display(current_dir)


func update_file_display(current_dir : String):
	var folders : PackedStringArray = dir_access.get_directories()
	var files : PackedStringArray = dir_access.get_files()
	var total : int = folders.size() + files.size()
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
			var i : int = existing_trees.size()
			while i < required_trees:
				var new : Tree = Tree.new()
				new.item_activated.connect(on_t_file_display_item_activated.bind(new))
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
				
				i = i + 1
		
		elif required_trees <= existing_trees.size():
			#unhide needed tree nodes
			var i : int = 0
			while i < required_trees:
				existing_trees[i].visible = true
				i = i + 1
			
			#hide unneeded tree nodes
			i = required_trees
			while i < existing_trees.size():
				existing_trees[i].visible = false
				i = i + 1
		
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
		if selected_filter != "*":
			if not file.ends_with(selected_filter.lstrip("*")):
				new.set_selectable(0, false)
				new.set_custom_color(0, Color(0.3,0.3,0.3))


#signals
func on_b_close_page_pressed():
	close()


#folder buttons
func on_b_previous_folder_pressed():
	#do not exceed 0
	dir_history_index = max(dir_history_index - 1, 0)
	change_dir(dir_history[dir_history_index], false)


func on_b_next_folder_pressed():
	#do not exceed array size
	dir_history_index = min(dir_history_index + 1, dir_history.size() - 1)
	change_dir(dir_history[dir_history_index], false)


func on_b_parent_folder_pressed():
	change_dir("..", true)


func on_b_root_folder_pressed():
	change_dir("/", true)


func on_b_refresh_pressed():
	update_file_display(dir_access.get_current_dir())


func on_b_list_folder_pressed():
	update_file_display(dir_access.get_current_dir())


func on_le_filepath_text_submitted(new : String):
	if dir_access.dir_exists(new):
		change_dir(new, true)


func on_ob_drives_item_selected(index : int):
	var drive : String = ob_drives.get_item_text(index)
	change_dir(ProjectSettings.localize_path(drive), true)
	le_filepath.text = drive


func on_ob_filters_item_selected(index : int):
	selected_filter = ob_filters.get_item_text(index)
	update_file_display(dir_access.get_current_dir())


func on_b_accept_pressed():
	if not le_file_name.text.is_valid_filename():
		return
	accepted_file.emit(dir_access.get_current_dir(), le_file_name.text + selected_filter.lstrip("*"))
	update_file_display(dir_access.get_current_dir())


#tree signals
func on_t_file_display_item_activated(tree : Tree):
	var selected : TreeItem = tree.get_selected()
	if selected == null:
		return
	var selected_text : String = selected.get_text(0)
	
	print(dir_access.get_current_dir() + "/" + selected_text)
	if dir_access.dir_exists(dir_access.get_current_dir() + "/" + selected_text):
		change_dir(selected_text, true)
	elif dir_access.file_exists(dir_access.get_current_dir() + "/" + selected_text):
		le_file_name.text = selected_text.rsplit(".", true, 1)[0]

