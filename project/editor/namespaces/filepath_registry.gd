extends RefCounted
class_name FilePathRegistry

const scene_color_button : String = "res://editor/data_ui/component_scenes/button_color.tscn"
const scene_material_part_type_button : String = "res://editor/data_ui/component_scenes/button_material_and_part_type.tscn"
const scene_palette_button : String = "res://editor/data_ui/component_scenes/palette_button/button_palette_entry.tscn"

const data_folder_default_assets : String = "res://editor/data_editor/"
const data_folder_user_assets : String = "user://user/assets/"
const data_user_settings : String = "user://user/settings.json"

#experimental path replacement in tres files
const resource_path_original : String = "res://editor/data_editor/"
const resource_path_replacement : String = "user://assets/"

#used as fallbacks for null values
const data_default_material : String = "res://editor/data_editor/plastic_01.tres"
const data_default_part : String = "res://editor/data_editor/cuboid.tres"


const script_tooltip_assign : String = "res://editor/classes/ui_editor/tooltip_assign.gd"
const style_tooltip_panel : String = "res://editor/data_ui/styles/panel_styles/tooltip_panel.tres"
const style_font_tooltip : String = "res://editor/data_ui/styles/font_styles/t_sci_fi_regular.tres"
