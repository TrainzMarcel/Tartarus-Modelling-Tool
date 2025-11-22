extends RefCounted
class_name UndoManager

#limit of undodata objects in undo stack
static var undo_limit : int = 8#255
#how much to subtract from the array size if the limit is exceeded
static var limit_decrement : int = 2#16

class UndoData:
	#parallel arrays of functions and corresponding arguments
	var undo_action : Array[Callable]
	var undo_args : Array[Array]
	
	var redo_action : Array[Callable]
	var redo_args : Array[Array]
	
	#actions are executed in the same order as they are added
	func append_undo_action_with_args(undo_action : Callable, undo_args : Array):
		self.undo_action.append(undo_action)
		self.undo_args.append(undo_args)
	
	func append_redo_action_with_args(redo_action : Callable, redo_args : Array):
		self.redo_action.append(redo_action)
		self.redo_args.append(redo_args)


static var undo_stack : Array = []
static var undo_index : int = -1

#undodata structs can be registered
static func register_undo_data(undo_data : UndoData):
	#if undo was pressed, any proceeding actions must be deleted first
	#so shorten array to current
	
	undo_index = undo_index + 1
	undo_stack.resize(undo_index)
	undo_stack.append(undo_data)
	
	#increment index to take us to the element we just appended
	
	if undo_stack.size() > undo_limit:
		print("decrementing... from ", undo_stack.size(), " to ", undo_stack.size() - limit_decrement)
		#take away from the front of the stack
		undo_stack = undo_stack.slice(limit_decrement, undo_stack.size())
		undo_index = undo_index - limit_decrement
	debug_pretty_print()



static func undo():
	if undo_index < 0:
		return
	
	if undo_index > undo_stack.size() - 1:
		push_warning("undo_index out of range, is this on purpose?")
		undo_index = undo_stack.size() - 1
	
	var current = undo_stack[undo_index]
	#can be null
	if not is_instance_valid(current):
		return
	
	var i : int = 0
	while i < current.undo_action.size():
		current.undo_action[i].callv(current.undo_args[i])
		i = i + 1
	undo_index = max(undo_index - 1, 0)
	debug_pretty_print()

static func redo():
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
	print()
	
	#print("undo_action:   ", undo_stack[i].undo_action)
	#print("undo_args:     ", undo_stack[i].undo_args)
	#print("redo_action:   ", undo_stack[i].redo_action)
	#print("redo_args:     ", undo_stack[i].redo_args)
