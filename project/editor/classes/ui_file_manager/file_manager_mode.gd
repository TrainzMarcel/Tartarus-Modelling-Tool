extends Control
class_name FileManagerOperationData

#way to differentiate between operations
#if there are multiple entries, they can each be used to open this operation
@export var operation_name : Array[StringName]

#what text to set in the title bar
#if there are multiple entries, the one with the closest index to
#the operation_name will be used. if the op_name index exceeds the amount
#of entries, it will just use the last entry in here
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
	fm_file_manager.ob_filters.select(filter_index)
	fm_file_manager.on_ob_filters_item_selected(filter_index)
