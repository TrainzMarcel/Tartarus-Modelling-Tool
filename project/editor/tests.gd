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
	


#write unit test
#1. spawn 2 parts
#2. select them individually
#3. move them to the right a bit
#4. deselect one
#5. move it left
#6. then move the other back to the left
"""
func test_undo_with_changing_selection():
	#clear possible state
	UndoManager.undo_stack.clear()
	UndoManager.undo_index = -1
	SelectionManager.selected_parts_internal.clear()
	
	#create mock parts
	var part_a : Part = Part.new()
	var part_b : Part = Part.new()
	part_a.initialize()
	part_b.initialize()
	part_a.position = Vector3(0.2,0,0)
	part_b.position = Vector3(0.5,0,0)
	
	var step_1_a : Vector3 = part_a.position
	var step_1_b : Vector3 = part_b.position
	
	# 2. Simulate: Select both parts
	SelectionManager.selection_add_part_undoable(part_a, part_a) # Use internal method, or a test helper
	SelectionManager.selection_add_part_undoable(part_b, part_a)
	SelectionManager.post_selection_update()
	
	# 3. Simulate: Move selection right (this would call WorkspaceManager.selection_move)
	# We need to capture the undo data registration that *should* happen here.
	# Let's assume moving calls: UndoManager.register_undo_data(some_data)
	# We'll simulate the core of that by creating the UndoData ourselves.
	SelectionManager.selection_move()
	var transformation : Vector3 = Vector3(0.5, 0, 0)
	#var undo_data_step1 = UndoManager.UndoData.new()
	# Save OLD state: positions at Vector3.ZERO
	#undo_data_step1.append_undo_action_with_args(mock_set_position, [part_a, Vector3.ZERO])
	#undo_data_step1.append_undo_action_with_args(mock_set_position, [part_b, Vector3.ZERO])
	# Save NEW state: positions at Vector3.RIGHT
	#undo_data_step1.append_redo_action_with_args(mock_set_position, [part_a, Vector3.RIGHT])
	#undo_data_step1.append_redo_action_with_args(mock_set_position, [part_b, Vector3.RIGHT])
	#UndoManager.register_undo_data(undo_data_step1)
	# APPLY the move
	part_a.position = Vector3(0.7, 0, 0)
	part_b.position = Vector3(1, 0, 0)
	
	# 4. Simulate: Deselect part_b
	SelectionManager.selection_remove_part_undoable(part_b)
	
	# 5. Simulate: Move only part_a left
	var undo_data_step2 = UndoManager.UndoData.new()
	undo_data_step2.append_undo_action_with_args(mock_set_position, [part_a, Vector3.RIGHT]) # OLD state
	undo_data_step2.append_redo_action_with_args(mock_set_position, [part_a, Vector3.LEFT])  # NEW state
	UndoManager.register_undo_data(undo_data_step2)
	part_a.position = Vector3.LEFT
	
	# 6. Simulate: Reselect part_b? Or is it still selected? Your bug says "move the other back to the left"
	# Let's assume part_b is still selected. Move part_b left (to ZERO).
	var undo_data_step3 = UndoManager.UndoData.new()
	undo_data_step3.append_undo_action_with_args(mock_set_position, [part_b, Vector3.RIGHT])
	undo_data_step3.append_redo_action_with_args(mock_set_position, [part_b, Vector3.ZERO])
	UndoManager.register_undo_data(undo_data_step3)
	part_b.position = Vector3.ZERO
	
	# 7. THE MOMENT OF TRUTH: UNDO SEQUENCE
	UndoManager.undo() # Should undo step 3: move part_b from ZERO back to RIGHT
	assert(part_b.position.is_equal_approx(Vector3.RIGHT), "First undo should move part_b back to RIGHT")
	
	UndoManager.undo() # Should undo step 2: move part_a from LEFT back to RIGHT
	assert(part_a.position.is_equal_approx(Vector3.RIGHT), "Second undo should move part_a back to RIGHT")
	
	UndoManager.undo() # Should undo step 1: move BOTH parts from RIGHT back to ZERO
	assert(part_a.position.is_equal_approx(Vector3.ZERO), "Third undo should move part_a to ZERO")
	assert(part_b.position.is_equal_approx(Vector3.ZERO), "Third undo should move part_b to ZERO")
	
	#clean up
	UndoManager.undo_stack.clear()
	UndoManager.undo_index = -1
	SelectionManager.selected_parts_internal.clear()
	
	print("TEST PASSED: Complex selection-change undo sequence works.")
"""
