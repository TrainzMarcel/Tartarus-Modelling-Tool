extends RefCounted
class_name UndoManager

#limit of undodata objects in undo stack
static var undo_limit : int = 10#255
#how much to subtract from the array size if the limit is exceeded
static var limit_decrement : int = 2#16

static var undo_stack : Array = []
static var undo_index : int = -1

#object key, int item counting the number of refs in undo data stack
#gets incremented and decremented whenever undodata is added or removed
static var reference_counter : Dictionary = {}

#purely for user feedback
static var undo_counter : int = 1
static var redo_counter : int = 1

"TODO"#add history undo option


class UndoData:
	#parallel arrays of functions and corresponding arguments
	var undo_action : Array[Callable]
	var undo_args : Array[Array]
	
	var redo_action : Array[Callable]
	var redo_args : Array[Array]
	
	#simple storage of object references to track references to delete objects
	#this must be filled with any objects that can get deleted
	#such as parts but not materials
	var explicit_object_references : Array
	
	#actions are executed in the same order as they are added
	func append_undo_action_with_args(undo_action : Callable, undo_args : Array):
		self.undo_action.append(undo_action)
		self.undo_args.append(undo_args)
	
	func append_redo_action_with_args(redo_action : Callable, redo_args : Array):
		self.redo_action.append(redo_action)
		self.redo_args.append(redo_args)


#undodata structs can be registered
static func register_undo_data(undo_data : UndoData):
	#ref tracking
	var to_be_removed : Array = undo_stack.slice(undo_index + 1, undo_stack.size())
	print("---------------------------------------------------------------------------")
	print("---------------------------------------------------------------------------")
	print("removing the following parts from undo data:")
	print(to_be_removed)
	to_be_removed.map(func (input): update_dependencies(input, false))
	
	#if undo was pressed, any proceeding actions must be deleted first
	#so shorten array to current
	undo_index = undo_index + 1
	undo_stack.resize(undo_index)
	undo_stack.append(undo_data)
	update_dependencies(undo_data, true)
	
	if undo_stack.size() > undo_limit:
		#ref tracking
		to_be_removed = undo_stack.slice(0, limit_decrement)
		to_be_removed.map(func (input): update_dependencies(input, false))
		
		print("decrementing... from ", undo_stack.size(), " to ", undo_stack.size() - limit_decrement)
		#take away from the front of the stack
		undo_stack = undo_stack.slice(limit_decrement, undo_stack.size())
		undo_index = undo_index - limit_decrement
	
	debug_pretty_print()
	undo_counter = 1
	redo_counter = 1


#this function updates the dependency tracking 
static func update_dependencies(undo_data : UndoData, is_appending : bool):
	#increment counter/add to counter if object doesnt exist
	if is_appending:
		for i in undo_data.explicit_object_references:
			var has_reference = reference_counter.get(i) is int
			if has_reference:
				#increment
				reference_counter[i] = reference_counter[i] + 1
			else:
				#first counted reference
				reference_counter[i] = 1
	#decrement counter/remove from counter if object count reaches 0
	else:
		for i in undo_data.explicit_object_references:
			var has_reference = reference_counter.get(i) is int
			if has_reference:
				#decrement
				reference_counter[i] = reference_counter[i] - 1
				#if this was the last reference to this object
				if reference_counter[i] == 0:
					reference_counter.erase(i)
					#only delete fully from memory when this is an orphan node
					print("i.get_parent()")
					print(i.get_parent())
					if i.get_parent() == null:
						i.queue_free()
			else:
				push_error("tried to remove nonexistant reference")
	print(reference_counter.keys())
	print(reference_counter.values())


static func undo():
	if undo_index < 0:
		return
	
	if undo_index > undo_stack.size() - 1 or undo_index < -1:
		push_warning("undo_index out of range, is this on purpose?")
		undo_index = undo_stack.size() - 1
	
	var current = undo_stack[max(undo_index, 0)]
	#can be null
	if not is_instance_valid(current):
		return
	
	var i : int = 0
	while i < current.undo_action.size():
		current.undo_action[i].callv(current.undo_args[i])
		i = i + 1
	
	undo_index = max(undo_index - 1, -1)
	debug_pretty_print(32)
	
	#undo redo message count
	EditorUI.set_l_msg("Undo (x" + str(undo_counter) + ")")
	undo_counter = undo_counter + 1
	redo_counter = 1


static func redo():
	if undo_index + 1 == undo_stack.size():
		return
	
	undo_index = min(undo_index + 1, undo_stack.size() - 1 )
	
	var current = undo_stack[undo_index]
	#can be null
	if not is_instance_valid(current):
		return
	
	var i : int = 0
	while i < current.redo_action.size():
		current.redo_action[i].callv(current.redo_args[i])
		i = i + 1
	
	debug_pretty_print()
	#undo redo message count
	EditorUI.set_l_msg("Redo (x" + str(redo_counter) + ")")
	undo_counter = 1
	redo_counter = redo_counter + 1


#print out whats in the undo stack
static func debug_pretty_print(stack_print_limit : int = 10):
	#get the name of every first undo action in the undo stack (this should give an idea of which action is which) and strip first 10 chars: GDScript::
	var undo_function_names : Array = undo_stack.map(func(input): if input != null and input.undo_action.size() > 0: return str(input.undo_action[0]).right(-10) else: return "WARNING no function")
	#get the name of every first redo action in the undo stack
	var redo_function_names : Array = undo_stack.map(func(input): if input != null and input.redo_action.size() > 0: return str(input.redo_action[0]).right(-10) else: return "WARNING no function")
	
	#iterate through the previous two arrays to get the longest of each function name (if theyre not already the same length)
	#this provides the basis for correct spacing
	var function_name_lengths : Array[int]
	var i : int = 0
	while i < undo_function_names.size():
		function_name_lengths.append(max(undo_function_names[i].length(), redo_function_names[i].length()))
		i = i + 1
	
	
	var output_undo_index : String = "undo_index"
	if undo_index < 0:
		output_undo_index = output_undo_index + " (-1)"
	
	var output_v : String = "V"
	var output_index : String = ""
	var output_undo_func : String = ""
	var output_redo_func : String = ""
	i = 0
	while i < undo_stack.size() and i < stack_print_limit:
		if undo_index > i:
			#repeat spaces until function name length is reached + 1 for pipe separator
			output_undo_index = " ".repeat(function_name_lengths[i] + 1) + output_undo_index
			output_v = " ".repeat(function_name_lengths[i] + 1) + output_v
		
		output_index = output_index + str(i).rpad(function_name_lengths[i]) + "|"
		output_undo_func = output_undo_func + undo_function_names[i].rpad(function_name_lengths[i]) + "|"
		output_redo_func = output_redo_func + redo_function_names[i].rpad(function_name_lengths[i]) + "|"
		i = i + 1
	
	print()
	print(output_undo_index)
	print(output_v)
	print(output_index)
	print(output_undo_func)
	print(output_redo_func)
	print("stack size: ", undo_stack.size())
	print("print limit: ", stack_print_limit)
	print()
	
	print("current undo_args:")
	print(undo_stack[undo_index].undo_args)
	print("current redo_args:")
	print(undo_stack[undo_index].redo_args)
	print()
	
