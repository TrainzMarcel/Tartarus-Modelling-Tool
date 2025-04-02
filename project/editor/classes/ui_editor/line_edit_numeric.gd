extends LineEdit
class_name LineEditNumeric

var previous_text : String
var true_value : float
var regex_num_only : RegEx


# Called when the node enters the scene tree for the first time.
func _ready():
	regex_num_only = RegEx.new()
	regex_num_only.compile("^[a-zA-Z0-9,]*\\.?[a-zA-Z0-9,]*$") 
	text_changed.connect(on_line_edit_numeric_text_changed)
	on_line_edit_numeric_text_changed(text)
# Called every frame. 'delta' is the elapsed time since the previous frame.


func on_line_edit_numeric_text_changed(new_text):
	
	if regex_num_only.search(new_text) == null:
		text = previous_text
	else:
		previous_text = text
		true_value = text.to_float()
