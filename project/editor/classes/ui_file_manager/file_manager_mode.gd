extends Control
class_name FileManagerModeData

@export var mode_name : StringName
#what text to set in the title nar
@export var mode_title : String

#available file ending filters to apply for this mode
#each entry must be formatted like the default
@export var filters : Array[String] = ["*.jpg,*.png"]
#2d array of filters
var filters_internal : Array
#if no controls are assigned, PanelContainerModeData will be hidden
#PanelContainerModeData is both for holding mode data and
#for holding extra options ui for a mode if needed.
@export var settings_ui_array : Array[Control]
