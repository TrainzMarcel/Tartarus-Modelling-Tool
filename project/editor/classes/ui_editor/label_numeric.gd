@tool
extends Label
class_name LabelNumeric

@export var digits : int = 1:
	set(value):
		digits = value
		custom_minimum_size.x = 18 * digits
		size.x = custom_minimum_size.x
		custom_minimum_size.y = 36
		number = 0

var number:
	set(value):
		number = value
		text = str(value).lpad(digits, "0")
