extends Control
class_name FileManagerOperationData

#way to differentiate between operations
@export var operation_name : Array[StringName]
#what text to set in the title bar
@export var operation_title : Array[String]

#available file ending filters to apply for this mode
#each entry must be formatted like the default
#multiple filters at once supported
@export var filters : Array[String] = ["*.jpg,*.png", ".obj", "*"]
#2d array of filters
var filters_internal : Array


#on press, automatically set a filter
@export var buttons_set_filter_index : Dictionary[Control, int]


func button_set_filter_on_button_pressed(fm_file_manager : FileManager, filter_index : int):
	fm_file_manager.on_ob_filters_item_selected(filter_index)
