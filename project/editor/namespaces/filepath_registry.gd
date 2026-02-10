extends RefCounted
class_name FilePathRegistry


#set by WorkspaceManager.initialize()
static var data_folder_executable : String
#these paths get the executable folder path prepended at runtime in WorkspaceManager.initialize()
static var data_program : String = "program_data.json"
static var data_folder_assets : String = "assets/"
static var data_folder_autosaves : String = "autosaves/"

#save names
static var data_crash_save : String = "crash_save"
static var data_auto_save : String = "auto_save"

#used as fallbacks for null values
const data_fallback_material : String = "res://editor/data_editor/broken_checkers.tres"
const data_fallback_part : String = "res://editor/data_editor/error_mesh.tres"


#ui tooltip paths
const script_tooltip_assign : String = "res://editor/classes/ui_editor/tooltip_assign.gd"
const style_tooltip_panel : String = "res://editor/data_ui/styles/panel_styles/tooltip_panel.tres"
const style_font_tooltip : String = "res://editor/data_ui/styles/font_styles/t_sci_fi_regular.tres"

#ui scene paths
const scene_color_button : String = "res://editor/data_ui/component_scenes/button_color.tscn"
const scene_material_part_type_button : String = "res://editor/data_ui/component_scenes/button_material_and_part_type.tscn"
const scene_palette_button : String = "res://editor/data_ui/component_scenes/palette_button/button_palette_entry.tscn"
