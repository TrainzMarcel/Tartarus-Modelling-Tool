extends RefCounted
class_name DataLoader






#read colors from file
static func read_colors_and_create_colors(file_as_string : String):
	var lines : PackedStringArray = file_as_string.split("\n")
	var color_array : Array[Color] = []
	var color_name_array : Array[String] = []
	var i : int = 0
	
	#read data
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
		
		
		#configure arrays
		if data.size() == 4:
			color_name_array.append(data[0])
			color_array.append(Color8(int(data[1]), int(data[2]), int(data[3])))
		i = i + 1
	
	var r_dict : Dictionary = {}
	r_dict.color_array = color_array
	r_dict.color_name_array = color_name_array
	return r_dict

"TODO"#add config read function, add material read function, add part model read function
"TODO"#also add all the filepaths in here
