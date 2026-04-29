extends LineEdit
class_name LineEditNumeric

var previous_text : String
var true_value : float
var regex_num_only : RegEx
var normal_style : StyleBoxFlat = preload("res://editor/data_ui/styles/panel_styles/number_display_panel.tres")
var invalid_style : StyleBoxFlat = preload("res://editor/data_ui/styles/panel_styles/number_display_panel_invalid.tres")


# Called when the node enters the scene tree for the first time.
func _ready():
	text_changed.connect(on_line_edit_numeric_text_changed)
	on_line_edit_numeric_text_changed(text)


func on_line_edit_numeric_text_changed(new_text : String):
	#check if the newly input text is a valid float or empty
	if (new_text.is_valid_float() and not new_text.contains("e")) or new_text.is_empty():
		previous_text = text
		if not new_text.is_empty():
			true_value = text.to_float()
		else:
			true_value = 0.0
		toggle_red_outline(false)
	else:
	#if invalid, mark the input field with a red border and do not let the invalid input get entered
		var prev_column : int = caret_column
		get_scroll_offset()
		text = previous_text
		caret_column = prev_column
		toggle_red_outline(true)


func toggle_red_outline(activate : bool):
	if activate:
		add_theme_stylebox_override("normal", invalid_style)
	else:
		add_theme_stylebox_override("normal", normal_style)
