extends RefCounted
class_name AutomatedColorPalette


#read colors from file
#simply add the buttons to the tree afterward
static func read_colors_and_create_buttons(file_as_string : String, sample_button : Button):
	var lines : PackedStringArray = file_as_string.split("\n")
	var button_array : Array[Button] = []
	var i : int = 0
	
	#iterate through each line
	while i < lines.size():
		#get data in each line
		var data : PackedStringArray = lines[i].split(",")
		
		"DEBUG"
		if data[0] == "#":
			break
		
		
		#strip spaces that come after commas
		for j in data:
			j.lstrip(" ")
		
		#configure buttons
		if data.size() == 4:
			var new : Button = sample_button.duplicate()
			new.tooltip_text = data[0]
			new.modulate = Color8(int(data[1]), int(data[2]), int(data[3]))
			button_array.append(new)
		i = i + 1
	
	return button_array


static func sort_by_saturation(a : Button, b : Button):
	var saturation_a : float = AutomatedColorPalette.get_saturation(a.modulate)
	var saturation_b : float = AutomatedColorPalette.get_saturation(b.modulate)
	if saturation_a > saturation_b:
		return true
	return false


static func get_grayscale(color : Color, epsilon : int, name : String):
	@warning_ignore("narrowing_conversion")
	var r : int = color.r * 255
	@warning_ignore("narrowing_conversion")
	var b : int = color.b * 255
	@warning_ignore("narrowing_conversion")
	var g : int = color.g * 255
	var max_c : float = max(r, b, g)
	var min_c : float = min(r, b, g)
	var delta : float = max_c - min_c
	
	#grayscale if within epsilon value
	#if delta == 0:
	
	if abs(delta) < epsilon:
		return true
	return false


static func sort_by_hue(a : Button, b : Button):
	var hue_a : float = AutomatedColorPalette.get_hue(a.modulate)
	var hue_b : float = AutomatedColorPalette.get_hue(b.modulate)
	if hue_a > hue_b:
		return true
	return false


static func sort_by_value(a : Button, b : Button):
	if a.modulate.get_luminance() > b.modulate.get_luminance():
		return true
	return false


static func get_saturation(color : Color):
	var r : float = color.r
	var b : float = color.b
	var g : float = color.g
	var max_c : float = max(r, b, g)
	var min_c : float = min(r, b, g)
	var l = (max_c + min_c) / 2
	var d = max_c - min_c
	return d / ( 1 - abs(2 * l - 1))


static func get_hue(color : Color):
	var hue : float = 0
	
	var r : float = color.r
	var g : float = color.g
	var b : float = color.b
	var max_c : float = max(r, g, b)
	var min_c : float = min(r, g, b)
	var delta : float = max_c - min_c
	
	#grayscale
	if delta == 0:
		return 0
	
	#if red is biggest
	if max_c == r:
		hue = (g - b) / (max_c - min_c)
	#if green is biggest
	elif max_c == g:
		hue = 2 + (b - r) / (max_c - min_c)
	#if blue is biggest
	elif  max_c == b:
		hue = 4 + (r - g) / (max_c - min_c)
	
	#normalize
	#hue = hue / 6
	#if hue < 0:
	#	hue = hue + 1
	
	return hue

#16 wide grid
static func coordinate_to_index(x : int, y : int, grid_width : int):
	#array index output
	return x + y * grid_width
