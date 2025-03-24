extends Control

@export var contents : Array[String]
@export var marker_1 : String = "[bgcolor=#00ff337b]"
@export var marker_2 : String = "[/bgcolor]"

var current_page : int
"TODO"#21.3. added search result markers and jumping between search results with buttons
var search_results : Array[Array]

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
	
	#signals
	b_first_page.pressed.connect(on_page_control_pressed.bind(b_first_page))
	b_next_page.pressed.connect(on_page_control_pressed.bind(b_next_page))
	b_previous_page.pressed.connect(on_page_control_pressed.bind(b_previous_page))
	b_last_page.pressed.connect(on_page_control_pressed.bind(b_last_page))
	
	b_close_page.button_up.connect(on_close_button_up)
	
	b_cancel_search.button_up.connect(on_cancel_search_button_up)
	le_search_bar.text_changed.connect(on_search_bar_text_changed)
	
	if contents.size() > 0:
		rtl_page.text = contents[0]
	
	if contents.size() < 2:
		hb_page_controls.visible = false
	
	l_current_page.text = "01"
	l_sum_page.text = str(contents.size()).lpad(2, "0")


#helper functions
func popup():
	visible = true

func close():
	visible = false

#only use this to change page
func change_page(array_index : int):
	rtl_page.text = contents[array_index]
	l_current_page.text = str(array_index + 1).lpad(2, "0")
	current_page = array_index


func jump_to_search_result(search_result_index : int):
	"TODO"#sometimes it wont scroll to a really low search result
	rtl_page.scroll_to_line(rtl_page.get_character_line(search_result_index))
	print("--------------------------")
	print(rtl_page.get_character_line(search_result_index))
	print(search_result_index)
	"TODO"#set the search displays
	#and button events


#this will work even with tags in between
#indices should be from text with no tags
func create_markers(search_indices : Array[int], clean_text_indices_map : Array[int], tag_1 : String, tag_2 : String, search_word_length : int):
	
	pass

func create_markers_old(indices : Array[int], tag_1 : String, tag_2 : String, spacing : int):
	#sum of added tags which gets added to result_index
	var sum : int = 0
	
	for result_index in indices:
		print(tag_1)
		print(tag_2)
		rtl_page.text = rtl_page.text.insert(result_index + sum, tag_1)
		sum = sum + tag_1.length()
		
		#count to end of current pos + spacing
		var search_string_char_count : int = 0
		while search_string_char_count < spacing:
			print(search_string_char_count," < ",spacing)
			#if we encounter a tag, count how far the tag goes
			var true_index : int = sum + search_string_char_count + result_index
			print(true_index," = ", sum ," + ", search_string_char_count ," + ", result_index )
			if rtl_page.text.substr(true_index + 1, 1) == "[":
				
				rtl_page.text = rtl_page.text.insert(true_index, tag_2)
				sum = sum + tag_2.length()
				true_index = sum + search_string_char_count + result_index
				
				#count how far the tag goes and make sure we dont run into another one
				#second condition needs to be ahead because one character cant be the same
				while not rtl_page.text.substr(true_index, 1) == "]" and not rtl_page.text.substr(true_index, 2) == "][":
					search_string_char_count = search_string_char_count + 1
					true_index = sum + search_string_char_count + result_index
					
				#add the count back to j to continue
				#add the new tags to the sum
				rtl_page.text = rtl_page.text.insert(true_index, tag_1)
				sum = sum + tag_1.length()
				
				
			search_string_char_count = search_string_char_count + 1
			
		
		rtl_page.text = rtl_page.text.insert(result_index + sum + search_string_char_count, tag_2)
		sum = sum + tag_2.length()


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
			
			#check if this is inside a tag before appending
			var j : int = i
			var in_tag_1 = true
			var in_tag_2 = true
			
			#loop backward
			while j >= 0:
				if content.substr(j, 1) == "]":
					in_tag_1 = false
				elif content.substr(j, 1) == "[":
					break
				else:
					in_tag_1 = false
				j = j - 1
			
			j = i
			#loop forward
			while j < content.length():
				if content.substr(j, 1) == "[":
					in_tag_2 = false
				elif content.substr(j, 1) == "]":
					break
				else:
					in_tag_2 = false
				j = j + 1
			
			if not in_tag_1 or not in_tag_2:
				print(in_tag_1, in_tag_2)
				indices.append(i)
			i = i + 1
	
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


#signals
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
	
	change_page(new_page_number)
	if le_search_bar.text != "":
		create_markers(search_results[new_page_number], marker_1, marker_2, le_search_bar.text.length())


func on_close_button_up():
	close()


func on_cancel_search_button_up():
	le_search_bar.text = ""
	clean_up_markers(current_page)


func on_search_bar_text_changed(text):
	if text == "":
		clean_up_markers(current_page)
		return
	
	#dont let user search for tags
	var inner_bracket : bool = false
	var outer_bracket : bool = false
	for i in text.length():
		inner_bracket = text.chr(i) == "["
		outer_bracket = text.chr(i) == "]"
	
	if outer_bracket and inner_bracket:
		return
	
	
	
	#array containing the returned search indices of each page
	search_results = findn_all_instances_array(contents, text)
	
	var total_results : int = 0
	for page in search_results:
		total_results = total_results + page.size()
	
	
	if total_results > 0:
		var page_first_result = get_first_non_empty_index(search_results)
		#if there is a result and if the first result is not on the current page
		if page_first_result != null and page_first_result != current_page:
			change_page(page_first_result)
			create_markers(search_results[page_first_result], marker_1, marker_2, text.length())
		elif page_first_result != null and page_first_result == current_page:
			#only needs to be called for when the same pages results change
			#otherwise change_page() will replace the page with an unchanged version anyway
			#and actually this is just a wrapper for change page 
			clean_up_markers(current_page)
			create_markers(search_results[page_first_result], marker_1, marker_2, text.length())
		
		if page_first_result != null:
			jump_to_search_result(search_results[page_first_result][0])
		
	else:
		clean_up_markers(current_page)

func strip_bbcode(source : String):
	
	
	
	
	
