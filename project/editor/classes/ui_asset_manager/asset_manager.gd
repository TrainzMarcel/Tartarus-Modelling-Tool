extends Control
class_name AssetManagerUI
"CUT CONTENT"#cut from at least v0.1
#ui
#top bar
var tab_button_array : Array[Button]
var b_close_page : Button

#left container, upper section
var le_palette_name : LineEdit
var te_palette_description : TextEdit

#left container, lower section
#color palette section
var cp_color_palette : ColorPicker
var b_sort_color : Button
var b_color_add : Button
var b_color_delete : Button
var gc_color_panel : GridContainer
var color_button : Button = load(FilePathRegistry.scene_color_button).instantiate()

#material palette section


#part type palette section


#panel container right
var l_equipped_palette : Label
var b_equipped_palette_entry : Button

#header 1
var b_palette_new : Button
var b_palette_delete : Button
var b_palette_equip : Button

#header 2
var b_palette_import_export : Button
var b_palette_save : Button
var b_palette_save_as : Button

#palette list ui node
var vbc_palette_entry : VBoxContainer

enum PaletteType {
	color_palette,
	material_palette,
	part_type_palette
}

var current_mode : PaletteType = PaletteType.color_palette

func _ready():
	b_close_page = %ButtonClosePage
	tab_button_array.append_array([%ButtonColorPalette, %ButtonMaterialPalette, %ButtonPartTypePalette])


func popup():
	visible = true

func close():
	visible = false

func on_palette_equip_pressed():
	#based on current toggled button in palette list
	#WorkspaceData.create_mapping()
	#use mapping to get palette
	#refresh editor ui of palette type
	#update equipped palette entry ui
	#set workspace data equipped palette
	
	pass

func on_palette_add_new_pressed():
	#based on current tab
	#instantiate a new empty palette object and update asset manager ui accordingly
	
	
	pass

func on_palette_delete_pressed():
	pass

func on_color_add_new_pressed():
	pass

func on_material_add_new_pressed():
	pass

func on_part_type_add_new_pressed():
	pass

func on_color_delete_pressed():
	pass

func on_material_delete_pressed():
	pass

func on_part_type_delete_pressed():
	pass

func on_palette_save_pressed():
	#based on current tab and current toggled button in palette list:
	
	#tell workspacedata to save that palette
	
	pass

func on_palette_save_as_pressed():
	#based on current tab and current toggled button in palette list:
	
	#tell workspacedata to save that palette with specific name
	
	pass

func on_text_field_entered():
	pass



