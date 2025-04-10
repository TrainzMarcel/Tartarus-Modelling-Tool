extends RefCounted
class_name HyperDebug

#all registered debug actions---------------------------------------------------
static var actions : Dictionary
static var debug_active : bool

class Action:
	var f : Callable
	var active : bool
	var debug_object : Object = null
	
	func do(input):
		if debug_object != null:
			input.debug_object = debug_object
			f.call(input)
		else:
			f.call(input)


#empty function to bind when not debugging--------------------------------------
static func empty_f(empty):
	pass


#actual debug functions---------------------------------------------------------
static func print_wrapper(to_print : String):
	print(to_print)


static func assert_wrapper(to_assert : bool):
	assert(to_assert)


static func vector_visualize(input : Dictionary):
	var d_vector : DebugVector3D = input.debug_object
	d_vector.origin_position = input.origin_position
	d_vector.input_vector = input.input_vector


static func box_visualize(input : Dictionary):
	var box : MeshInstance3D = input.debug_object
	box.transform = input.transform
	box.mesh.size = input.extents


static func initialize(debug_active : bool, tree_access : Node):
	HyperDebug.debug_active = debug_active
	HyperDebug.config(tree_access)
	
	for i in HyperDebug.actions.keys():
		if not debug_active or not HyperDebug.actions[i].active:
			HyperDebug.actions[i].f = HyperDebug.empty_f


#configure everything in here
static func config(tree_access : Node):
	HyperDebug.actions.basis_print = Action.new()
	HyperDebug.actions.transform_handle_rotation_visualize = Action.new()
	HyperDebug.actions.abb_visualize = Action.new()
	HyperDebug.actions.transform_handle_linear_visualize = Action.new()
	HyperDebug.actions.document_viewer_asserts = Action.new()
	
	
	HyperDebug.actions.basis_print.active = false
	HyperDebug.actions.transform_handle_rotation_visualize.active = false
	HyperDebug.actions.abb_visualize.active = false
	HyperDebug.actions.transform_handle_linear_visualize.active = false
	HyperDebug.actions.document_viewer_asserts.active = false
	
	
	#set all actions false if debug_active is false
	HyperDebug.master_set()
	
	HyperDebug.actions.basis_print.f = HyperDebug.print_wrapper
	
	HyperDebug.actions.transform_handle_rotation_visualize.f = HyperDebug.vector_visualize
	HyperDebug.actions.transform_handle_rotation_visualize.debug_object = create_debug_vector(tree_access, HyperDebug.actions.transform_handle_rotation_visualize, Color(1.0, 1.0, 0.0, 0.4), true)
	
	HyperDebug.actions.abb_visualize.f = HyperDebug.box_visualize
	HyperDebug.actions.abb_visualize.debug_object = create_debug_box(tree_access, HyperDebug.actions.abb_visualize, Color(0.0, 1.0, 1.0, 0.3))
	
	HyperDebug.actions.transform_handle_linear_visualize.f = HyperDebug.vector_visualize
	HyperDebug.actions.transform_handle_linear_visualize.debug_object = HyperDebug.create_debug_vector(tree_access, HyperDebug.actions.transform_handle_linear_visualize, Color(1.0, 1.0, 0.0, 0.4), true)
	
	HyperDebug.actions.document_viewer_asserts.f = HyperDebug.assert_wrapper


static func create_debug_vector(tree_access : Node, action : Action, color : Color, add_plane : bool):
	if not action.active:
		return null
	
	var new : DebugVector3D = DebugVector3D.new()
	tree_access.add_child(new)
	new.color = color
	if add_plane:
		var plane_node : MeshInstance3D = MeshInstance3D.new()
		var plane : BoxMesh = BoxMesh.new()
		plane.size = Vector3(10, 0.01, 10)
		plane.material = new.mesh.material.duplicate()
		plane.material.uv1_triplanar = true
		plane.material.albedo_texture = preload("res://editor/icon.svg")
		plane_node.mesh = plane
		new.add_child(plane_node)
		plane_node.position = Vector3(0, -0.5, 0)
	return new


static func create_debug_box(tree_access : Node, action : Action, color : Color):
	if not action.active:
		return null
	
	var new : MeshInstance3D = MeshInstance3D.new()
	var box : BoxMesh = BoxMesh.new()
	box.material = StandardMaterial3D.new()
	box.material.albedo_color = color
	box.material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	new.mesh = box
	tree_access.add_child(new)
	return new

static func master_set():
	for i in HyperDebug.actions.values():
		i.active = i.active and HyperDebug.debug_active
