extends RefCounted
class_name UndoManager

class ActionData:
	var transform : Transform3D
	var prev_transform : Transform3D
	var action : Callable
	var reverse_action : Callable

static var undo_stack : Array = []
static var redo_stack : Array = []
static var pointer : int = 0




static func undo():
	var current = undo_stack[undo_stack.size() - 1]
	current.reverse_action.call(current.prev_transform.origin)
	

static func redo():
	return






