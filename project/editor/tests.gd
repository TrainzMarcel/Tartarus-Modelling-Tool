@tool
extends Node
class_name AutomatedTesting

@export_tool_button("run all tests") var run_all_action : Callable = run_all
var tests : Array[Callable] = [
	#self.test_undo_with_changing_selection
]


func run_all():
	for test in tests:
		test.call()


func test_undo_():
	#setup some hypothetical undo stuff
	#var new_parts : Array[Part] = [Part.new(), Part.new(), Part.new()]
	
	#call the public api
	return
	#assert expected changes
	#assert()
	
	#clean up
	


