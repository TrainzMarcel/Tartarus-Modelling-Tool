extends RefCounted
class_name AutomatedColorPalette


#read colors from file
"TODO"#make a centralized class for reading config data and asset (color, material, primitives) data



"TODO"#handle in ui
#simply add the buttons to the tree afterward
static func create_buttons_from_colors(sample_button : Button, color_array : Array[Color], color_name_array : Array[String]):
	var i : int = 0
	var button_array : Array[Button] = []
	while i < color_array.size():
		var button : Button = sample_button.duplicate()
		"TODO"#find best property to change on button for displaying color
		button.tooltip_text = color_name_array[i]
		button_array.append(button)
		i = i + 1
	
	return button_array


static func sort_by_saturation(a : Button, b : Button):
	var saturation_a : float = AutomatedColorPalette.get_saturation(a.modulate)
	var saturation_b : float = AutomatedColorPalette.get_saturation(b.modulate)
	if saturation_a > saturation_b:
		return true
	return false


static func get_grayscale(color : Color, epsilon : int):
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

static func full_color_sort(grid_container : GridContainer, color_array : Array[Color], color_name_array : Array[String] = []):
	
	#set up required variables
	var w : int = grid_container.columns
	var i : int = 0
	var j : int = 0
	var no_more_swaps : bool = false
	var using_color_name_array : bool = not color_name_array.is_empty()
	
	
	var grayscale_color_array : Array[Color] = []
	var grayscale_color_name_array : Array[String] = []
	
	var grayscale_epsilon : int = 30
	
	#sort color buttons by value
	while not no_more_swaps:
		no_more_swaps = true
		while i < color_array.size() - 1:
			var index_1 : int = i
			var index_2 : int = i + 1
			var color_1 : Color = color_array[index_1]
			var color_2 : Color = color_array[index_2]
			#swap if hue of current color is bigger than the one of next color
			if AutomatedColorPalette.get_saturation(color_1) > AutomatedColorPalette.get_saturation(color_2): 
				var temp = color_array[index_1]
				color_array[index_1] = color_array[index_2]
				color_array[index_2] = temp
				
				if using_color_name_array:
					temp = color_name_array[index_1]
					color_name_array[index_1] = color_name_array[index_2]
					color_name_array[index_2] = temp
				
				no_more_swaps = false
			i = i + 1
		i = 0
	
	i = 0
	no_more_swaps = false
	#sort color buttons by hue
	while not no_more_swaps:
		no_more_swaps = true
		while i < color_array.size() - 1:
			var index_1 : int = i
			var index_2 : int = i + 1
			var color_1 : Color = color_array[index_1]
			var color_2 : Color = color_array[index_2]
			#swap if hue of current color is bigger than the one of next color
			if AutomatedColorPalette.get_hue(color_1) > AutomatedColorPalette.get_hue(color_2):
				var temp = color_array[index_1]
				color_array[index_1] = color_array[index_2]
				color_array[index_2] = temp
				
				if using_color_name_array:
					temp = color_name_array[index_1]
					color_name_array[index_1] = color_name_array[index_2]
					color_name_array[index_2] = temp
				
				no_more_swaps = false
			i = i + 1
		i = 0
	
	
	
	#lastly place grayscale colors at the end
	i = 0
	while i < color_array.size():
		#take out, append to end
		if AutomatedColorPalette.get_grayscale(color_array[i], grayscale_epsilon):
			grayscale_color_array.append(color_array.pop_at(i))
			if using_color_name_array:
				grayscale_color_name_array.append(color_name_array.pop_at(i))
			i = i - 1
		i = i + 1
	
	#sort color buttons in each row by value
	i = 0
	while i < color_array.size():
		no_more_swaps = false
		while not no_more_swaps:
			no_more_swaps = true
			j = 0
			
			if i + w > color_array.size():
				w = color_array.size() - i
			
			while j < w - 1:
				var index_1 : int = i + j
				var index_2 : int = i + j + 1
				var color_1 : Color = color_array[index_1]
				var color_2 : Color = color_array[index_2]
				#swap if hue of current color is bigger than the one of next color
#				if AutomatedColorPalette.get_saturation(button_1.modulate) < AutomatedColorPalette.get_saturation(button_2.modulate): 
				if color_1.v < color_2.v: 
					var temp = color_array[index_1]
					color_array[index_1] = color_array[index_2]
					color_array[index_2] = temp
					
					if using_color_name_array:
						temp = color_name_array[index_1]
						color_name_array[index_1] = color_name_array[index_2]
						color_name_array[index_2] = temp
					
					no_more_swaps = false
				j = j + 1
		i = i + w
	
	
	i = 0
	no_more_swaps = false
	while not no_more_swaps:
		no_more_swaps = true
		while i < grayscale_color_array.size() - 1:
			var index_1 : int = i
			var index_2 : int = i + 1
			var color_1 : Color = grayscale_color_array[index_1]
			var color_2 : Color = grayscale_color_array[index_2]
			#swap if hue of current color is bigger than the one of next color
			if color_1.v < color_2.v:
				var temp = grayscale_color_array[index_1]
				grayscale_color_array[index_1] = grayscale_color_array[index_2]
				grayscale_color_array[index_2] = temp
				
				if using_color_name_array:
					temp = grayscale_color_name_array[index_1]
					grayscale_color_name_array[index_1] = grayscale_color_name_array[index_2]
					grayscale_color_name_array[index_2] = temp
				
				no_more_swaps = false
			i = i + 1
		i = 0
	
	color_array.append_array(grayscale_color_array)
	if using_color_name_array:
		color_name_array.append_array(grayscale_color_name_array)
	
	var r_dict : Dictionary = {}
	
	r_dict.color_array = color_array
	r_dict.color_name_array = color_name_array
	return r_dict
#	"DEBUG"
#	i = 0
#	var print_array : Array = []
#	while i < color_buttons.size():
#		#print_array.append(str(round(AutomatedColorPalette.get_hue(color_buttons[i].modulate)*100)*0.01))
#		print_array.append(str(round(color_buttons[i].modulate.v*100)*0.01))
#		#print_array.append(str(AutomatedColorPalette.get_grayscale(color_buttons[i].modulate)))
#		if print_array.size() > w - 1:
#			print(print_array)
#			print_array.clear()
#		i = i + 1


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


static func coordinate_to_index(x : int, y : int, grid_width : int):
	#array index output
	return x + y * grid_width
