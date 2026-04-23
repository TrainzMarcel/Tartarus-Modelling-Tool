extends Control
class_name FileManagerOperationData

#way to differentiate between operations
@export var operation_name : Array[StringName]
#what text to set in the title bar
@export var operation_title : Array[String]

#available file ending filters to apply for this mode
#each entry must be formatted like the default
@export var filters : Array[String] = ["*.jpg,*.png"]
#2d array of filters
var filters_internal : Array
