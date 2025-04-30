extends Control
class_name DocumentDisplay

@export_multiline var contents : Array[String]
@export var marker_1_brighter : String = "[bgcolor=#f0ff007b]"
@export var marker_1 : String = "[bgcolor=#00ff337b]"
@export var marker_2 : String = "[/bgcolor]"

"TODO"#re-architect this codebase to be less chaotic and messy
#although this isnt that urgent since this is self contained

"TODO"#double check which bbcode tags contents have to be stripped
	#list of tags whos content has to be stripped too (for example, if the content is a filepath)
var tags_strip_content : Array[String] = ["[img]", "[font]", "[hint]", "[opentype_features]"]#, "[table]"]
var current_page : int
var current_search_result : int
var current_search_result_page : int
var total_results : int
#cache search results and bbcode free contents as well as map
#to highlight page on page change
var search_results : Array[Array]
var contents_stripped : Array[String]
var contents_stripped_map : Array[Array]

#ui
#top bar
var b_close_page : Button
#search controls
var le_search_bar : LineEdit
var b_cancel_search : Button
var b_first_result : Button
var b_previous_result : Button
var l_current_result : Label
var l_sum_result : Label
var b_next_result : Button
var b_last_result : Button

#content
var rtl_page : RichTextLabel
var vsb_page : VScrollBar

#page controls
var hb_page_controls : HBoxContainer
var b_first_page : Button
var b_previous_page : Button
var l_current_page : Label
var l_sum_page : Label
var b_next_page : Button
var b_last_page : Button

# Called when the node enters the scene tree for the first time.
func _ready():
	#initialize
	#top bar
	b_close_page = %ClosePageButton
	#search controls
	le_search_bar = %SearchLineEdit
	b_cancel_search = %CancelSearchButton
	
	
	#content
	rtl_page = %PageRichTextLabel
	vsb_page = rtl_page.get_v_scroll_bar()
	
	#page controls
	hb_page_controls = %PageControlsHBoxContainer
	b_first_page = %FirstPage
	b_previous_page = %PreviousPage
	l_current_page = %CurrentPageDisplay
	l_sum_page = %SumPageDisplay
	b_next_page = %NextPage
	b_last_page = %LastPage
	
	
	b_first_result = %FirstResult
	b_previous_result = %PreviousResult
	l_current_result = %CurrentResultDisplay
	l_sum_result = %SumResultDisplay
	b_next_result = %NextResult
	b_last_result = %LastResult
	
	#signals
	b_first_page.pressed.connect(on_page_control_pressed.bind(b_first_page))
	b_next_page.pressed.connect(on_page_control_pressed.bind(b_next_page))
	b_previous_page.pressed.connect(on_page_control_pressed.bind(b_previous_page))
	b_last_page.pressed.connect(on_page_control_pressed.bind(b_last_page))
	
	b_first_result.pressed.connect(on_search_control_pressed.bind(b_first_result))
	b_next_result.pressed.connect(on_search_control_pressed.bind(b_next_result))
	b_previous_result.pressed.connect(on_search_control_pressed.bind(b_previous_result))
	b_last_result.pressed.connect(on_search_control_pressed.bind(b_last_result))
	
	b_close_page.button_up.connect(on_close_button_up)
	
	b_cancel_search.button_up.connect(on_cancel_search_button_up)
	le_search_bar.text_changed.connect(on_search_bar_text_changed)
	
	
	
	if contents.size() > 0:
		rtl_page.text = contents[0]
	
	if contents.size() < 2:
		hb_page_controls.visible = false
	
	l_current_page.text = "01"
	l_sum_page.text = str(contents.size()).lpad(2, "0")
	
	l_current_result.text = "000"
	l_sum_result.text = "000"


#helper functions
func popup():
	visible = true


func close():
	visible = false

"TODO"#add more asserts
#returns a dict with a map from the stripped content to the original content
#and the stripped content
func remove_bbcode(input : String, tags_strip_content : Array[String]):
	var output : String = input
	#array which will map the output to the input
	#eg: if a tag is removed in the output, the same character index in the output will point to 
	var map_array : Array[int] = []
	var i : int = 0
	
	#for each removed character, increment by 1
	var total_offset : int = 0
	#detect tags, check their length and insert this to the map
	while i < output.length():
		
		#if tag detected
		if output[i] == "[":
			#get the length of the substring that needs to be removed
			var length : int = get_tag_length(output, i, is_tag_content_immutable(output, i, tags_strip_content))
			
			#erase just that part
			output = output.erase(i, length)
			#sum up length of that part for total offset
			total_offset = total_offset + length
		
		#count along output chars + total offset
		#EDGE CASE: dont append last index if output ends with a tag
		if not i + total_offset >= input.length():
			map_array.append(i + total_offset)
		else:
			break
		
		i = i + 1
	
	#return dict
	var r_dict : Dictionary = {}
	r_dict.text = output
	r_dict.map_array = map_array
	return r_dict


#check if a tag at "from" has content which should not be changed (e.g. img tags with filepath in between)
func is_tag_content_immutable(input : String, from : int, tags_strip_content : Array[String]):
	#HyperDebug.actions.document_viewer_asserts.do(input[from] == "[")
	for tag in tags_strip_content:
		if input.substr(from, tag.length()) == tag:
			return true
		return false


#get tag length
#assuming this starts on the "[" character
func get_tag_length(input : String, from : int, include_next_tag : bool):
	#HyperDebug.actions.document_viewer_asserts.do(input[from] == "[")
	#number of closing brackets counted
	var closing_brackets : int = 0
	#length counter
	var i : int = 0
	while i + from < input.length() - 1:
		
		#QUICKFIX: if theres another tag right after this one, keep counting it as one tag
		if input[i + from] == "]" and input[i + from + 1] != "[":
			closing_brackets = closing_brackets + 1
		
		i = i + 1
		
		#if end of second tag has been reached
		if include_next_tag and closing_brackets == 2:
			break
		
		#if end of second tag has been reached
		if not include_next_tag and closing_brackets == 1:
			break
	
	return i


#take all these arguments to add bbcode bgcolor tags into some text and return it
#in theory this could use any tags
#indices should be from text with no tags
func highlight_search_results(
	text_unstripped : String,
	map_stripped_to_unstripped : Array[int],
	search_indices_stripped : Array[int],
	selected_search_result_index : int,
	tag_1_brighter : String,
	tag_1 : String,
	tag_2 : String,
	search_word_length : int):
	
	var output : String = text_unstripped
	var total_offset : int = 0
	var selected_tag : String
	
	
	var iteration : int = 0
	#for each search index:
	for i in search_indices_stripped:
		#if its the selected search result, mark it in a different color
		if iteration == selected_search_result_index:
			selected_tag = tag_1_brighter
		else:
			selected_tag = tag_1
		
		
		#insert tag at the search index
		#and add its length to the total_offset variable
		output = output.insert(map_stripped_to_unstripped[i] + total_offset, selected_tag)
		total_offset = total_offset + selected_tag.length()
		
		#iterate through map by search word length
		var j : int = 0
		while j < search_word_length - 1:
			#if a "gap" has been detected in the map during search word
			var index_along_word : int = i + j
			if map_stripped_to_unstripped[index_along_word] != map_stripped_to_unstripped[index_along_word + 1] - 1:
				#insert an ending tag at gap and at the next character, not at the character where the gap starts
				#(otherwise there would be a gap left in the highlighting, right before the detected tag)
				output = output.insert(map_stripped_to_unstripped[index_along_word] + 1 + total_offset, tag_2)
				total_offset = total_offset + tag_2.length()
				# and a starting tag at the next position
				output = output.insert(map_stripped_to_unstripped[index_along_word + 1] + total_offset, selected_tag)
				total_offset = total_offset + selected_tag.length()
			j = j + 1
		
		#at the end of the loop, insert tag 2 and add len to total_offset
		#EDGE CASE: if this is at the end of the string, it wont work.
		if i + search_word_length - 1 >= map_stripped_to_unstripped.size():
			output = output + tag_2
		else:
			output = output.insert(map_stripped_to_unstripped[i + search_word_length - 1] + total_offset + 1, tag_2)
		
		total_offset = total_offset + tag_2.length()
		i = i + 1
		iteration = iteration + 1
		#continue to next search index and repeat
	
	return output


#change page wrapper
func clean_up_markers(current_page : int):
	change_page(current_page)


#return first non-empty index in an array
func get_first_non_empty_index(array : Array):
	var i : int = 0
	while i < array.size():
		if not array[i].is_empty():
			return i
		i = i + 1


#find all occurences of the search string and return their indices
func findn_all_instances(content : String, search : String):
	#content = strip_bbcode(content)
	var indices : Array[int] = []
	var i : int = 0
	#loop through until i becomes -1 
	while i != -1:
		i = content.findn(search, i)
		#only append and increment if i isnt set to -1
		if i != -1:
			#skip past by search length to avoid overlapping results
			indices.append(i)
			i = i + search.length()
	
	return indices


#find all occurences of the search string in multiple pages and return
#a 2d array containing the indices of each page
#note that this will have an empty item if that items page returned no results
func findn_all_instances_array(content_array : Array[String], search : String):
	var indices : Array[Array] = []
	var i : int = 0
	while i < content_array.size():
		indices.append(findn_all_instances(content_array[i], search))
		i = i + 1
	
	return indices


#only use this to change page
func change_page(array_index : int, selected_search_index_on_page : int = -1):
	l_current_page.text = str(array_index + 1).lpad(2, "0")
	current_page = array_index
	
	if le_search_bar.text == "":
		rtl_page.text = contents[array_index]
	else:
		"TODO"#if current search result is not on the page, use -1
		
		
		
		rtl_page.text = highlight_search_results(contents[array_index], contents_stripped_map[array_index], search_results[array_index], selected_search_index_on_page, marker_1_brighter, marker_1, marker_2, le_search_bar.text.length())


#jump to search result with character index local to the current page
func jump_to_search_result(search_result_index : int):
	"TODO"#sometimes it wont scroll to a really low search result
	rtl_page.scroll_to_line(rtl_page.get_character_line(search_result_index))
	"TODO"#set the search displays
	#and button events


#set ui number displays
func update_search_display(results_sum : int, current_result : int):
	if results_sum == 0:
		l_sum_result.text = "000"
		l_current_result.text = "000"
	else:
		l_sum_result.text = str(results_sum).lpad(3, "0").right(3)
		l_current_result.text = str(current_result + 1).lpad(3, "0").right(3)


#signals
#search bar
func on_search_bar_text_changed(text):
	if text == "":
		total_results = 0
		update_search_display(0, 0)
		clean_up_markers(current_page)
		return
	
	current_search_result = 0
	
	var page : int = 0
	while page < contents.size():
		if contents_stripped.size() != contents.size():
			var r_dict : Dictionary = remove_bbcode(contents[page], tags_strip_content)
			contents_stripped.append(r_dict.text)
			contents_stripped_map.append(r_dict.map_array)
		
		search_results = findn_all_instances_array(contents_stripped, text)
		page = page + 1
	
	var i : int = 0
	total_results = 0
	while i < search_results.size():
		total_results = total_results + search_results[i].size()
		i = i + 1
	
	update_search_display(total_results, current_search_result)
	
	
	var page_first_result = get_first_non_empty_index(search_results)
	
	#if there is a result and if the first result is not on the current page
	if page_first_result != null:
		#automatically highlights page
		change_page(page_first_result, 0)
		#HyperDebug.actions.document_viewer_asserts.do(contents_stripped_map[page_first_result].size() == contents[page_first_result].length())
		jump_to_search_result(search_results[page_first_result][0])
		
	else:
		clean_up_markers(current_page)


#bottom pagination signal
func on_page_control_pressed(button : Button):
	var new_page_number : int
	match button:
		b_first_page:
			new_page_number = 0
		b_next_page:
			new_page_number = min(current_page + 1, contents.size() - 1)
		b_previous_page:
			new_page_number = max(current_page - 1, 0)
		b_last_page:
			new_page_number = contents.size() - 1
	
	#turn current_search_result (1d index) into
	#2d indices new_search_result_page_number and new_search_result_index_on_page
	
	#iterate through search result pages
	var new_search_result_page_number : int = 0
	var new_search_result_index_on_page : int = 0
	var sum : int = 0
	
	while new_search_result_page_number < search_results.size():
		if current_search_result < sum + search_results[new_search_result_page_number].size():
			new_search_result_index_on_page = current_search_result - sum
			break
		
		new_search_result_page_number = new_search_result_page_number + 1
	
	if new_search_result_page_number != new_page_number:
		change_page(new_page_number)
	else:
		change_page(new_page_number, new_search_result_index_on_page)


#search result pagination signal
func on_search_control_pressed(button : Button):
	if search_results.is_empty():
		return
	
	var new_search_result_index : int = 0
	
	var i : int = 0
	total_results = 0
	while i < search_results.size():
		total_results = total_results + search_results[i].size()
		i = i + 1
	
	match button:
		b_first_result:
			i = 0
			var page : int = get_first_non_empty_index(search_results)
			while i < page:
				new_search_result_index = new_search_result_index + search_results[i].size()
				i = i + 1
			
		b_next_result:
			new_search_result_index = min(current_search_result + 1, total_results - 1)
		b_previous_result:
			new_search_result_index = max(current_search_result - 1, 0)
		b_last_result:
			new_search_result_index = total_results - 1
	
	#turn current_search_result (1d index) into
	#2d indices new_search_result_page_number and new_search_result_index_on_page
	
	#iterate through search result pages
	
	var sum : int = 0
	var new_search_result_page_number : int
	var new_search_result_index_on_page : int = 0 #equivalent to x
	#i used i to make the iterator more obvious
	i = 0 #equivalent to y
	while i < search_results.size():
		
		if new_search_result_index <= sum + search_results[i].size() - 1 and not search_results[i].is_empty():
			new_search_result_index_on_page = new_search_result_index - sum
			break
		sum = sum + search_results[i].size()
		i = i + 1
	new_search_result_page_number = i #equivalent to y
	
	
	
	
	#set search display with new selected search result and possibly new page
	current_search_result = new_search_result_index
	current_search_result_page = new_search_result_page_number
	update_search_display(total_results, current_search_result)
	change_page(new_search_result_page_number, new_search_result_index_on_page)
	jump_to_search_result(search_results[new_search_result_page_number][new_search_result_index_on_page])


#top right close button signal
func on_close_button_up():
	close()


#x button next to search bar signal
func on_cancel_search_button_up():
	current_search_result = 0
	total_results = 0
	update_search_display(total_results, current_search_result)
	le_search_bar.text = ""
	clean_up_markers(current_page)
