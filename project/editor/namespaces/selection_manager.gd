extends RefCounted
class_name SelectionManager


#handles all logic related to selected objects and selecting objects 
"TODO"#refactor messy, overly coupled selected_parts_abb orientation setting logic!!
"TODO"#add selectionbox pooling

#dependencies
static var hover_selection_box : SelectionBox

#bounding box of selected parts for snapping purposes
static var selected_parts_abb : ABB = ABB.new()

#grouping
class Group:
	extends RefCounted
	
	var parent_group : Group
	var child_groups : Array = []
	var child_parts : Array = []
	#group_abb orientation part
	var primary_part : Part
	var group_abb : ABB = ABB.new()

const group_depth_max : int = 3
const group_depth_colors : Array[Color] = [Color.WHITE, Color.DARK_GRAY, Color.DIM_GRAY]

static var root_group_child_parts_hashmap : Dictionary = {}
static var root_groups : Array[Group] = []


#selected groups/parts, parallel with selectionbox array
static var selected_entities : Array = []

#selected_entities_internal and offset_abb_to_internal_entities are parallel arrays!!
#flattened array of full hierarchy of selected_entities (all root and child parts and groups) for transformations
static var selected_entities_internal : Array = []
#local offsets from the internal selected parts and groups positions to the abb position: recalculate_abb_offsets()
static var offset_abb_to_internal_entities : Array[Vector3] = []

#selection_boxes and selection_box_targets are parallel arrays
#simply copy transforms from targets to selectionboxes when necessary: update_selection_boxes()
static var selection_box_targets : Array = []
static var selection_boxes : Array[SelectionBox] = []

#set this on selection change, this tells the bounding box to recalculate itself
#between selection handling and selection transform operations
static var selection_changed : bool = false

#call set_transform_handle_root at end of input frame
static var selection_moved : bool = false

#for copy pasting
static var parts_clipboard : Array[Part] = []


#initial selection rect event where the user starts dragging while not hovered over anything draggable
static var initial_selection_rect_event : InputEvent
#keep track of first selected part to guarantee bounding box orientation
static var first_entity_selection_rect
#for shift-selecting, i need to keep track of the initial selection
static var initial_selected_entities : Array
#i also need a place for the undo data from start to end of a marquee selection
static var undo_data_selection_rect : UndoManager.UndoData
"TODO"#rename this better
static var is_rect_selecting_active : bool = false



static func initialize(hover_selection_box : SelectionBox):
	SelectionManager.hover_selection_box = hover_selection_box


#input handling functions-------------------------------------------------------
static func handle_input(
	event : InputEvent,
	is_ui_hovered : bool,
	is_selecting_allowed : bool,
	is_hovering_allowed : bool,
	hovered_entity,
	hovered_part,
	dragged_part,
	hovered_handle : TransformHandle,
	ray_result : Dictionary,
	positional_snap_increment : float,
	snapping_active : bool,
	cam : FreeLookCamera
	):

#click selecting behavior
#if click on unselected part, set it as the selection (array with only that part, discard any prior selection)
#if click on unselected part while shift is held, append to selection
#if click on part in selection while shift is held, remove from selection
#if click on nothing, clear selection array
#if click on nothing while shift is held, do nothing
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
#lmb down
		#handle_left_click()
		if event.pressed:
			var is_part_hovered : bool = Main.safety_check(Main.hovered_part)
	#if part is hovered
			if is_part_hovered and is_selecting_allowed:
			#hovered part is in selection
				if SelectionManager.selected_entities.has(hovered_entity):
				#shift is held
					if Input.is_key_pressed(KEY_SHIFT):
						#patch to stop dragging when holding shift and
						#dragging on an already selected part
						if SelectionManager.selected_entities.has(hovered_entity) and hovered_part == dragged_part:
							dragged_part = null
						SelectionManager.selection_remove_part_undoable(hovered_entity)
						SelectionManager.post_selection_update()
			#hovered part is not in selection
				else:
				#shift is held
					if Input.is_key_pressed(KEY_SHIFT) and Main.safety_check(dragged_part):
						SelectionManager.selection_add_part_undoable(hovered_entity, dragged_part)
						SelectionManager.post_selection_update()
					else:
						SelectionManager.selection_set_to_part_undoable(hovered_entity, dragged_part)
						SelectionManager.post_selection_update()
	#no parts hovered
			elif is_selecting_allowed:
				#shift is unheld
				if not Input.is_key_pressed(KEY_SHIFT):
					if not Main.safety_check(hovered_handle):
						SelectionManager.selection_clear_undoable()
						SelectionManager.post_selection_update()
			
			#if no parts, handles or ui detected, start selection rect
			if not Main.safety_check(hovered_part) and not Main.safety_check(hovered_handle) and not is_ui_hovered:
				selection_rect_prepare(event, Main.panel_selection_rect)
	#lmb up
		else:
			if is_rect_selecting_active:
				selection_rect_terminate(Main.panel_selection_rect)
	
	#selection rect/marquee select handling
	if event is InputEventMouseMotion:
		selection_rect_handle(event, Main.panel_selection_rect, Main.cam)
		SelectionManager.post_selection_update()
	
#keyboard input-----------------------------------------------------------------
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		#change initial_transform on r or t press
	#rotate clockwise around normal vector
		if event.keycode == KEY_R:
			if Main.safety_check(hovered_part) and Main.safety_check(dragged_part) and is_selecting_allowed and not ray_result.is_empty():
				Main.initial_rotation = Main.initial_rotation.rotated(ray_result.normal, PI * 0.5)
				#use initial_rotation so that dragged_part doesnt continually rotate further 
				#from its initial rotation after being dragged over multiple off-grid parts
				SelectionManager.selection_rotate(SnapUtils.drag_snap_rotation_to_hovered(Main.initial_rotation, ray_result))
				SelectionManager.selection_move(SnapUtils.drag_snap_position_to_hovered(
					ray_result,
					dragged_part,
					SelectionManager.selected_parts_abb,
					WorkspaceManager.drag_offset,
					positional_snap_increment,
					snapping_active
				))
	#rotate around part vector which is closest to cam.basis.x
		elif event.keycode == KEY_T:
			if Main.safety_check(hovered_part) and Main.safety_check(dragged_part) and is_selecting_allowed and not ray_result.is_empty():
				var r_dict = SnapUtils.find_closest_vector(Main.initial_rotation, cam.basis.x, true)
				
				Main.initial_rotation = Main.initial_rotation.rotated(r_dict.vector.normalized(), PI * 0.5)
				#use initial_rotation so that dragged_part doesnt continually rotate further 
				#from its initial rotation after being dragged over multiple off-grid parts
				
				SelectionManager.selection_rotate(SnapUtils.drag_snap_rotation_to_hovered(Main.initial_rotation, ray_result))
				SelectionManager.selection_move(SnapUtils.drag_snap_position_to_hovered(
					ray_result,
					dragged_part,
					SelectionManager.selected_parts_abb,
					WorkspaceManager.drag_offset,
					positional_snap_increment,
					snapping_active
				))
		elif event.keycode == KEY_DELETE:
			if is_selecting_allowed:
				EditorUI.set_l_msg("deleted " + str(SelectionManager.selected_entities.filter(is_part).size()) + " parts")
				SelectionManager.selection_delete_undoable()
				SelectionManager.post_selection_update()
				#immediately update hovered_part in case theres another part behind the deleted one(s)
				hovered_part = Main.part_hover_check()
				SelectionManager.selection_box_hover_on_target(hovered_entity, is_hovering_allowed)
		#deselect all
		elif event.keycode == KEY_A and event.ctrl_pressed and event.shift_pressed:
			if is_selecting_allowed:
				SelectionManager.selection_clear_undoable()
				SelectionManager.post_selection_update()
				EditorUI.set_l_msg("cleared selection")
		#select all
		elif event.keycode == KEY_A and event.ctrl_pressed:
			if is_selecting_allowed:
				SelectionManager.selection_set_to_workspace_undoable()
				SelectionManager.post_selection_update()
				EditorUI.set_l_msg("selected all parts")
		#cut
		elif event.keycode == KEY_X and event.ctrl_pressed:
			SelectionManager.selection_copy()
			SelectionManager.selection_delete_undoable()
			SelectionManager.post_selection_update()
			EditorUI.set_l_msg("cut " + str(SelectionManager.parts_clipboard.size()) + " parts")
		#copy
		elif event.keycode == KEY_C and event.ctrl_pressed:
			SelectionManager.selection_copy()
			SelectionManager.post_selection_update()
			EditorUI.set_l_msg("copied " + str(SelectionManager.parts_clipboard.size()) + " parts")
		#paste
		elif event.keycode == KEY_V and event.ctrl_pressed:
			SelectionManager.selection_paste_undoable()
			SelectionManager.post_selection_update()
			EditorUI.set_l_msg("pasted " + str(SelectionManager.parts_clipboard.size()) + " parts")
		#duplicate
		elif event.keycode == KEY_D and event.ctrl_pressed:
			SelectionManager.selection_duplicate_undoable()
			SelectionManager.post_selection_update()
			EditorUI.set_l_msg("duplicated " + str(SelectionManager.selected_entities.filter(is_part).size()) + " parts")
		#group
		elif event.keycode == KEY_G and event.ctrl_pressed:
			SelectionManager.selection_group()
		elif event.keycode == KEY_G and event.ctrl_pressed and event.shift_pressed:
			SelectionManager.selection_ungroup()
		#ungroup


"TODO"#make guard clauses and use returns to flatten this mess
#static func handle_left_click(event : InputEvent, is_selecting_allowed : bool, hovered_part : Part, dragged_part, hovered_handle : TransformHandle, is_ui_hovered : bool):
#click selecting behavior
#if click on unselected part, set it as the selection (array with only that part, discard any prior selection)
#if click on unselected part while shift is held, append to selection
#if click on part in selection while shift is held, remove from selection
#if click on nothing, clear selection array
#if click on nothing while shift is held, do nothing
	#function....




"TODO"#parameterize variables from main
#this function MUST be called whenever the number of selected parts changes
#it is separate because you may save performance by
#making multiple selection calls before calling this one
static func post_selection_update():
	if SelectionManager.selected_entities.size() > 0 and (Main.is_selecting_allowed or ToolManager.selected_tool == ToolManager.SelectedToolEnum.t_pivot):
		#refresh bounding box on definitive selection change
		#automatically refreshes abb offset array
		SelectionManager.refresh_bounding_box()
		#TODO this only actually needs to be called when the selection changes from size 0 to size > 0
		ToolManager.handle_set_active(ToolManager.selected_tool_handle_array, true)
	
	elif SelectionManager.selected_entities.size() == 0 and SelectionManager.selection_changed and ToolManager.selected_tool != ToolManager.SelectedToolEnum.t_pivot:
		#TODO this only needs to be called when the selection changes from size > 0 to 0
		ToolManager.handle_set_active(ToolManager.selected_tool_handle_array, false)


static func selection_rect_prepare(event : InputEvent, selection_rect : Panel):
	is_rect_selecting_active = true
	initial_selection_rect_event = event
	#duplicate to avoid mutation
	initial_selected_entities = selected_entities
	undo_data_selection_rect = UndoManager.UndoData.new()
	undo_data_selection_rect.append_undo_action_with_args(selection_set_to_part_array, [initial_selected_entities, last_element(initial_selected_entities)])
	
	selection_rect.position = initial_selection_rect_event.position
	selection_rect.size = Vector2.ZERO
	selection_rect.visible = true


#this function has not yet been tested for orthographic view
static func selection_rect_handle(event : InputEvent, selection_rect : Panel, cam : Camera3D):
	if Main.is_mouse_button_held and Main.is_selecting_allowed and initial_selection_rect_event != null and event is InputEventMouse:
		var physics : PhysicsDirectSpaceState3D = cam.get_world_3d().direct_space_state
		
		
		#render the selection rect
		var scaling : Vector2 = event.position - initial_selection_rect_event.position
		selection_rect.size = scaling.abs()
		if scaling.x < 0:
			selection_rect.position.x = initial_selection_rect_event.position.x + scaling.x
		
		if scaling.y < 0:
			selection_rect.position.y = initial_selection_rect_event.position.y + scaling.y
		
		
		var rect : Rect2 = selection_rect.get_rect()
		var a : Vector2 = rect.position
		var b : Vector2 = Vector2(rect.position.x + rect.size.x, rect.position.y)
		var c : Vector2 = rect.position + rect.size
		var d : Vector2 = Vector2(rect.position.x, rect.position.y + rect.size.y)
		var rect_points : PackedVector2Array = [a,b,c,d]
		
		#collision checks
		var collider_points : PackedVector3Array = []
		var a1 = cam.project_position(a, Main.raycast_length)
		var b1 = cam.project_position(b, Main.raycast_length)
		var c1 = cam.project_position(c, Main.raycast_length)
		var d1 = cam.project_position(d, Main.raycast_length)
		
		var e1 = cam.position
		
		var frustum_collider : ConvexPolygonShape3D = ConvexPolygonShape3D.new()
		frustum_collider.points = [a1, b1, c1, d1, e1]
		
		var params : PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
		params.shape = frustum_collider
		var result = physics.intersect_shape(params, 2048)
		
		var result_colliders = result.map(func(input): return input.collider)
		var result_parts : Array[Part] = []
		
		for i in result_colliders:
			if i is Part:
				result_parts.append(i)
		
		"TODO"#there has to be a better way to do this
		#guarantee the first selected part is always at the start of the array
		#so that the bounding box orientation doesnt change
		if result_parts.size() > 0 and first_entity_selection_rect == null:
			first_entity_selection_rect = result_parts[-1]
			Main.initial_rotation = result_parts[-1].basis
		
		if first_entity_selection_rect != null and result_parts.size() > 1:
			result_parts.erase(first_entity_selection_rect)
			result_parts.push_front(first_entity_selection_rect)
		
		
		if result_parts.size() > 0:
			if first_entity_selection_rect != null:
				if Input.is_key_pressed(KEY_SHIFT):
					for part in initial_selected_entities:
						if result_parts.has(part):
							result_parts.erase(part)
						else:
							result_parts.append(part)
				
				selection_set_to_part_array(result_parts, first_entity_selection_rect)
		else:
			if Input.is_key_pressed(KEY_SHIFT) and initial_selected_entities.size() > 0:
				selection_set_to_part_array(initial_selected_entities, initial_selected_entities[0])
			else:
				selection_clear()
			first_entity_selection_rect = null


static func selection_rect_terminate(selection_rect : Panel):
	is_rect_selecting_active = false
	selection_rect.visible = false
	initial_selection_rect_event = null
	first_entity_selection_rect = null
	initial_selected_entities = []
	selection_changed = true
	var selection = selected_entities.duplicate()
	undo_data_selection_rect.append_redo_action_with_args(selection_set_to_part_array, [selection, last_element(selection)])
	undo_data_selection_rect.explicit_object_references.append_array(selection)
	UndoManager.register_undo_data(undo_data_selection_rect)
	undo_data_selection_rect = null


#selection functions------------------------------------------------------------
#returns a root group or a part depending on whether a part belongs to a group
static func get_hovered_entity(hovered_part : Part):
	var group_of_part : Group = root_group_child_parts_hashmap.get(hovered_part)
	if Main.safety_check(group_of_part):
		return group_of_part
	return hovered_part


#
static func selection_add_part(hovered_entity, abb_orientation : Part):
	selected_entities.append(hovered_entity)
	
	if hovered_entity is Group:
		var child_groups_flat : Array = group_get_full_hierarchy(hovered_entity)
		var child_parts_flat : Array = group_get_all_child_parts(child_groups_flat)
		var total : Array = []
		total.append_array(child_parts_flat)
		total.append_array(child_groups_flat)
		
		selected_entities_internal.append_array(total)
		var calculate_offsets : Callable = func(input):
			return selection_target_get_transform(input) - abb_orientation.transform.origin
		offset_abb_to_internal_entities.append_array(total.map(calculate_offsets))
	else:
		selected_entities_internal.append(hovered_entity)
		offset_abb_to_internal_entities.append(hovered_entity.transform.origin - abb_orientation.transform.origin)
	
	selection_box_instance_on_target(hovered_entity)
	selection_changed = true


static func selection_add_part_undoable(hovered_entity, abb_orientation : Part):
	selection_add_part(hovered_entity, abb_orientation)
	
	var undo : UndoManager.UndoData = UndoManager.UndoData.new()
	undo.append_undo_action_with_args(selection_remove_part, [hovered_entity])
	undo.append_undo_action_with_args(post_selection_update, [])
	undo.explicit_object_references.append(hovered_entity)
	undo.append_redo_action_with_args(selection_add_part, [hovered_entity, abb_orientation])
	undo.append_redo_action_with_args(post_selection_update, [])
	UndoManager.register_undo_data(undo)


static func selection_remove_part(hovered_entity):
	selection_box_delete_on_part(hovered_entity)
	selected_entities.erase(hovered_entity)
	
	if hovered_entity is Group:
		var child_groups_flat : Array = group_get_full_hierarchy(hovered_entity)
		var child_parts_flat : Array = group_get_all_child_parts(child_groups_flat)
		var total : Array = []
		total.append_array(child_parts_flat)
		total.append_array(child_groups_flat)
		
		#remove all entities
		for entity in total:
			offset_abb_to_internal_entities.remove_at(selected_entities_internal.find(entity))
			selected_entities_internal.erase(entity)
	else:
		#erase the same index as hovered_part
		offset_abb_to_internal_entities.remove_at(selected_entities_internal.find(hovered_entity))
		selected_entities_internal.erase(hovered_entity)
	
	selection_changed = true


static func selection_remove_part_undoable(hovered_entity):
	selection_remove_part(hovered_entity)
	
	var undo : UndoManager.UndoData = UndoManager.UndoData.new()
	"TODO"#bounding box orientation setting should be SEPARATE from selecting functions!!
	#this causes the bounding box to be a different orientation after the undo!!
	#bad ux!
	undo.append_undo_action_with_args(selection_add_part, [hovered_entity, hovered_entity])
	undo.append_undo_action_with_args(post_selection_update, [])
	undo.explicit_object_references.append(hovered_entity)
	undo.append_redo_action_with_args(selection_remove_part, [hovered_entity])
	undo.append_redo_action_with_args(post_selection_update, [])
	UndoManager.register_undo_data(undo)


static func selection_set_to_workspace():
	selection_clear()
	"TODO"#get all parts function in workspacemanager
	var workspace_parts = WorkspaceManager.workspace.get_children().filter(func(part):
		return part is Part
		)
	
	for i in workspace_parts:
		selection_add_part(i, workspace_parts[0])
	selection_changed = true


static func selection_set_to_workspace_undoable():
	var selection_before : Array = selected_entities.duplicate()
	
	selection_set_to_workspace()
	post_selection_update()
	
	var selection_after : Array = selected_entities.duplicate()
	var undo : UndoManager.UndoData = UndoManager.UndoData.new()
	undo.append_undo_action_with_args(selection_set_to_part_array, [selection_before, last_element(selection_before)])
	undo.append_undo_action_with_args(post_selection_update, [])
	undo.explicit_object_references.append_array(selection_before)
	undo.explicit_object_references.append_array(selection_after)
	undo.append_redo_action_with_args(selection_set_to_part_array, [selection_after, last_element(selection_after)])
	undo.append_redo_action_with_args(post_selection_update, [])
	UndoManager.register_undo_data(undo)


static func selection_set_to_part(hovered_entity, abb_orientation : Part):
	selection_clear()
	if hovered_entity is Group:
		selection_add_part(hovered_entity, abb_orientation)
	else:
		selection_add_part(hovered_entity, abb_orientation)
	
	selection_changed = true


static func selection_set_to_part_undoable(hovered_entity, abb_orientation : Part):
	var selection : Array = selected_entities.duplicate()
	
	selection_set_to_part(hovered_entity, abb_orientation)
	
	var undo : UndoManager.UndoData = UndoManager.UndoData.new()
	"TODO"#do something about get function pushing an error if 0 is out of bounds
	undo.append_undo_action_with_args(selection_set_to_part_array, [selection, last_element(selection)])
	undo.append_undo_action_with_args(post_selection_update, [])
	undo.explicit_object_references.append_array(selection)
	undo.explicit_object_references.append(hovered_entity)
	undo.append_redo_action_with_args(selection_set_to_part, [hovered_entity, abb_orientation])
	undo.append_redo_action_with_args(post_selection_update, [])
	UndoManager.register_undo_data(undo)


#for undo operations
static func selection_set_to_part_array(input : Array, abb_orientation : Part):
	selection_clear()
	
	for entity in input:
		if not selected_entities.has(entity):
			selection_add_part(entity, abb_orientation)
	selection_changed = true


static func selection_set_to_part_array_undoable(input : Array, abb_orientation : Part):
	var selection : Array = selected_entities.duplicate()
	
	selection_set_to_part_array(input, abb_orientation)
	
	var undo : UndoManager.UndoData = UndoManager.UndoData.new()
	"TODO"#do something about get function pushing an error if 0 is out of bounds
	undo.append_undo_action_with_args(selection_set_to_part_array, [selection, last_element(selection)])
	undo.append_undo_action_with_args(post_selection_update, [])
	undo.explicit_object_references.append_array(selection)
	undo.explicit_object_references.append_array(input)
	undo.append_redo_action_with_args(selection_set_to_part_array, [input, abb_orientation])
	undo.append_redo_action_with_args(post_selection_update, [])
	UndoManager.register_undo_data(undo)


static func selection_clear():
	selected_entities.clear()
	selected_entities_internal.clear()
	selection_box_clear_all()
	offset_abb_to_internal_entities.clear()
	selection_changed = true
	#does not need to call selection_changed as the bounding box doesnt matter when nothing is selected


static func selection_clear_undoable():
	var selection : Array = selected_entities.duplicate()
	
	selection_clear()
	
	var undo : UndoManager.UndoData = UndoManager.UndoData.new()
	undo.append_undo_action_with_args(selection_set_to_part_array, [selection, last_element(selection)])
	undo.append_undo_action_with_args(post_selection_update, [])
	undo.explicit_object_references.append_array(selection)
	undo.append_redo_action_with_args(selection_clear, [])
	undo.append_redo_action_with_args(post_selection_update, [])
	UndoManager.register_undo_data(undo)


static func selection_delete():
	for i in selected_entities:
		if i is Group:
			group_get_all_child_parts(i).map(func(input): i.queue_free())
		
		i.queue_free()
	
	selection_clear()


static func selection_delete_undoable():
	var undo : UndoManager.UndoData = UndoManager.UndoData.new()
	var selection : Array = selected_entities.duplicate()
	undo.append_undo_action_with_args(add_children, [WorkspaceManager.workspace, selection])
	undo.append_undo_action_with_args(selection_set_to_part_array, [selection, last_element(selection)])
	undo.append_undo_action_with_args(post_selection_update, [])
	undo.explicit_object_references = selection
	undo.append_redo_action_with_args(remove_children, [WorkspaceManager.workspace, selection])
	undo.append_redo_action_with_args(selection_clear, [])
	undo.append_redo_action_with_args(post_selection_update, [])
	UndoManager.register_undo_data(undo)
	
	remove_children(WorkspaceManager.workspace, selection) 
	selection_clear()


static func selection_copy():
	parts_clipboard.clear()
	for i in selected_entities:
		parts_clipboard.append(i.copy())


static func selection_paste():
	if parts_clipboard.is_empty():
		return
	
	selection_clear()
	for i in parts_clipboard:
		var copy : Part = i.copy()
		WorkspaceManager.workspace.add_child(copy)
		copy.initialize()
		selection_add_part(copy, copy)
	refresh_bounding_box()
	selection_moved = true


static func selection_paste_undoable():
	if parts_clipboard.is_empty():
		return
	
	var undo : UndoManager.UndoData = UndoManager.UndoData.new()
	var selection_before : Array = selected_entities.duplicate()
	selection_paste()
	var selection_after : Array = selected_entities.duplicate()
	
	undo.append_undo_action_with_args(selection_set_to_part_array, [selection_before])
	undo.append_undo_action_with_args(post_selection_update, [])
	undo.append_undo_action_with_args(remove_children, [WorkspaceManager.workspace, selection_after])
	undo.explicit_object_references.append_array(selection_before)
	undo.explicit_object_references.append_array(selection_after)
	undo.append_redo_action_with_args(add_children, [WorkspaceManager.workspace, selection_after])
	undo.append_redo_action_with_args(selection_set_to_part_array, [selection_after, last_element(selection_after)])
	undo.append_redo_action_with_args(post_selection_update, [])
	UndoManager.register_undo_data(undo)


static func selection_duplicate():
	for i in selected_entities:
		var copy : Part = i.copy()
		WorkspaceManager.workspace.add_child(copy)
		copy.initialize()


static func selection_duplicate_undoable():
	if selected_entities.is_empty():
		return
	
	var copied_parts : Array = []
	for i in selected_entities:
		var copy : Part = i.copy()
		copied_parts.append(copy)
		WorkspaceManager.workspace.add_child(copy)
		copy.initialize()
	
	var undo : UndoManager.UndoData = UndoManager.UndoData.new()
	undo.append_undo_action_with_args(remove_children, [WorkspaceManager.workspace, copied_parts])
	undo.explicit_object_references = copied_parts
	undo.append_redo_action_with_args(add_children, [WorkspaceManager.workspace, copied_parts])


#position only
"TODO"#check and ensure numerical stability
static func selection_move(input_absolute : Vector3):
	assert(selected_entities_internal.size() == offset_abb_to_internal_entities.size())
	#recalculate pivot offset on selection move
	if WorkspaceManager.pivot_custom_mode_active:
		WorkspaceManager.pivot_transform.origin = WorkspaceManager.pivot_transform.origin + input_absolute - selected_parts_abb.transform.origin
	selected_parts_abb.transform.origin = input_absolute
	
	var i : int = 0
	while i < selected_entities_internal.size():
		var transform_new : Transform3D = selection_target_get_transform(selected_entities_internal[i])
		transform_new.origin = selected_parts_abb.transform.origin + offset_abb_to_internal_entities[i]
		selection_target_set_transform(selected_entities_internal[i], transform_new)
		i = i + 1
	
	selection_box_update_transforms()
	
	#move transform handles with selection
	selection_moved = true


#rotation only
"TODO"#parameterize everything for clarity and to prevent bugs
"TODO"#check and ensure numerical stability
#pivot point is local to the selection bounding box (x 0.5 means 0.5 to the right of the abb)
static func selection_rotate(rotated_basis : Basis, local_pivot_point : Vector3 = Vector3.ZERO):
	pass
	"""
	var original_basis : Basis = Basis(selected_parts_abb.transform.basis)
	#calculate difference between original basis and new basis
	var difference : Basis = rotated_basis * original_basis.inverse()
	var global_pivot_point = selected_parts_abb.transform.basis * local_pivot_point
	#rotate pivot vector
	var global_pivot_point_rotated = difference * global_pivot_point 
	WorkspaceManager.drag_offset = difference * WorkspaceManager.drag_offset
	
	#rotate abb
	if WorkspaceManager.pivot_custom_mode_active:
		selected_parts_abb.transform.origin = selected_parts_abb.transform.origin + global_pivot_point
		selected_parts_abb.transform.basis = difference * selected_parts_abb.transform.basis
		selected_parts_abb.transform.origin = selected_parts_abb.transform.origin - global_pivot_point_rotated
		#recalculate local pivot transform
		WorkspaceManager.pivot_transform = selected_parts_abb.transform * WorkspaceManager.pivot_local_transform
	else:
		selected_parts_abb.transform.basis = difference * selected_parts_abb.transform.basis
	
	#rotate the offset_abb_to_selected_array vector by the difference between the
	#original basis and rotated basis
	var i : int = 0
	while i < selected_parts_internal.size():
		#rotate offset_dragged_to_selected_array vector by the difference basis
		offset_abb_to_selected_parts[i] = difference * offset_abb_to_selected_parts[i]
		#move part to ray_result.position for easier pivoting (drag-specific functionality)
		if not Main.ray_result.is_empty():
			selected_parts_internal[i].global_position = Main.ray_result.position
		else:
			selected_parts_internal[i].global_position = selected_parts_abb.transform.origin
		
		
		#rotate this part
		selected_parts_internal[i].basis = difference * selected_parts_internal[i].basis
		
		#move it back out along the newly rotated offset_dragged_to_selected_array vector
		selected_parts_internal[i].global_position = selected_parts_abb.transform.origin + offset_abb_to_selected_parts[i]
		#copy transform
		selection_boxes[i].global_transform = selected_parts_internal[i].global_transform
		i = i + 1
	
	#move transform handles with selection
	selection_moved = true
"""

#scale_absolute meaning it will set the scale of the selection bounding box to this value
#must call selection_move after this function due to the updated offset_abb_to_selected_array
"TODO"#OPTIMIZE OPTIMIZE OPTIMIZE
#https://www.reddit.com/r/godot/comments/187npcd/how_to_increase_performance/
#https://docs.godotengine.org/en/4.1/classes/class_renderingserver.html
"TODO"#this function is not very stable mathematically
"TODO"#add variables that remember the original scale and part positions from when the scaling handle drag started
static func selection_scale(scale_absolute : Vector3):
	pass
	"""
	#dont do anything if scale is the same
	if scale_absolute == selected_parts_abb.extents:
		return
	
	#scaling singular parts is easy
	if selected_parts_internal.size() == 1:
		selected_parts_internal[0].part_scale = scale_absolute
		selected_parts_abb.extents = scale_absolute
		selection_box_redraw_all()
		selection_moved = true
		return
	
	
	#!!scalable_parts and local_scales are parallel arrays!!
	var scalable_parts : Array[Part]
	var local_scales : PackedVector3Array = []
	#!!selected_parts_internal, offset_abb_to_selected_array and local_offsets are parallel arrays!!
	#offset_abb_to_selected_array is in global space
	var local_offsets : PackedVector3Array = []
	var inverse : Basis = selected_parts_abb.transform.basis.inverse()
	#shorthand
	var ext : Vector3 = selected_parts_abb.extents
	#loop
	var i : int = 0
	var j : int = 0
	
	
	
	#parts can only be scaled along their basis vectors
	#so only work on parts that are rectilinearly aligned with the bounding box
	scalable_parts = selected_parts_internal.filter(func(part):
		return SnapUtils.part_rectilinear_alignment_check(selected_parts_abb.transform.basis, part.basis)
	)
	
	
	#first get the local scale of each scalable part
	for i_a in scalable_parts:
		var abb_basis = selected_parts_abb.transform.basis
		var p = i_a.basis
		var s = i_a.part_scale
		
		#world space scale vector
		var world_scale = p * s
		
		#bounding box local vector
		var diff_forward = abb_basis.inverse()
		var local_scale_abb = diff_forward * world_scale
		
		#set any negative components to not be negative
		local_scale_abb.x = abs(local_scale_abb.x)
		local_scale_abb.y = abs(local_scale_abb.y)
		local_scale_abb.z = abs(local_scale_abb.z)
		local_scales.append(local_scale_abb)
		i = i + 1
	
	#then get the local offsets to the bounding box of each selected part
	for i_b in offset_abb_to_selected_parts:
		var new : Vector3 = i_b * selected_parts_abb.transform.basis
		local_offsets.append(new)
	
	
	#work on each dimension individually
	i = 0
	while i < 3:
		#if this dimension is already scaled correctly, go to next iteration
		if scale_absolute[i] == ext[i]:
			i = i + 1
			continue
		
		#only scale scalable parts
		#scale each scalable part in relation to bounding box
		j = 0
		while j < scalable_parts.size():
			#get relative scale from 0 to 1 depending on how much space the part takes up in the bounding box
			var new_scale : float = local_scales[j][i] / ext[i]
			new_scale = lerp(0.0, scale_absolute[i], new_scale)
			local_scales[j][i] = new_scale
			j = j + 1
		
		
		
		j = 0
		#move all parts in relation to where they are in the bounding box
		while j < selected_parts_internal.size():
			#get relative position from -1 to 1 depending on how close to the edge of the bounding box a part is
			var pos : float = local_offsets[j][i] / ext[i]
			pos = lerp(0.0, scale_absolute[i], pos)
			local_offsets[j][i] = pos
			j = j + 1
		
		selected_parts_abb.extents[i] = scale_absolute[i]
		i = i + 1
	
	
	#im sad to admit i needed chatgpt to figure this one out
	#reassign transformed local scales to part-space scales
	var i_d : int = 0
	while i_d < scalable_parts.size():
		var abb_basis = selected_parts_abb.transform.basis
		var p = scalable_parts[i_d].basis
		var s = scalable_parts[i_d].part_scale
		
		#abb local to world
		var world_scale_again = abb_basis * local_scales[i_d]
		
		#world space to part space
		var diff_reverse = p.inverse()
		var local_scale = diff_reverse * world_scale_again
		
		local_scale.x = abs(local_scale.x)
		local_scale.y = abs(local_scale.y)
		local_scale.z = abs(local_scale.z)
		scalable_parts[i_d].part_scale = local_scale
		i_d = i_d + 1
	
	
	#reassign transformed local offsets to global offset array
	offset_abb_to_selected_parts.clear()
	for i_g in local_offsets:
		offset_abb_to_selected_parts.append(i_g * inverse)
	
	selection_box_redraw_all()
	#move transform handles with selection
	selection_moved = true
"""


"TODO"#SELECT
#this is for precisely reversing scale operations with undo
static func selection_set_exact_transforms(transform_array : Array, scale_array : Array, scale_absolute : Vector3):
	assert(selected_entities_internal.size() == transform_array.size())
	var i : int = 0
	
	while i < selected_entities_internal.size():
		selection_target_set_extents(selected_entities_internal[i], scale_array[i])
		selection_target_set_transform(selected_entities_internal[i], transform_array[i])
		i = i + 1
	
	
	selected_parts_abb.extents = scale_absolute
	refresh_offset_abb_to_selected_array()
	selection_box_update_transforms()
	selection_box_redraw_all()
	selection_moved = true


#partgroup related functions----------------------------------------------------
static var is_group : Callable = func(input_entity): return input_entity is Group
static var is_part : Callable = func(input_entity): return input_entity is Part

	#var depth : int = 0
	#for group in selected_groups_internal:
	#	depth = max(group_get_hierarchy_depth(group), depth)
	#assert(depth <= group_depth_max)
	#if depth == group_depth_max:
	#	EditorUI.set_l_msg("grouping failed: group depth limit (" + str(group_depth_max) + ") reached.")
	#	return

static func selection_group():
	var non_grouped_parts : Array = selected_entities.filter(is_part)
	if non_grouped_parts.is_empty():
		EditorUI.set_l_msg("grouping failed: all selected parts already grouped.")
		return
	
	var group : Group = Group.new()
	group.child_groups = selected_entities_internal.filter(is_group)
	group.child_parts = non_grouped_parts
	group.primary_part = last_element(group.child_parts)
	group.group_abb = SnapUtils.calculate_extents(group.group_abb, group.primary_part, group.child_parts)
	
	root_groups.append(group)
	#filter out groups from root_groups which are now able to be found under group.child_groups
	var grouped_groups : Callable = func(input): return not group.child_groups.has(input)
	root_groups = root_groups.filter(grouped_groups)
	
	#recalculate hashmap
	root_group_child_parts_hashmap.clear()
	for r_group in root_groups:
		for part in r_group.child_parts:
			root_group_child_parts_hashmap[part] = r_group
	
	selected_entities.clear()
	offset_abb_to_internal_entities.clear()
	selected_entities_internal.clear()
	selection_box_clear_all()
	selection_add_part(group, group.primary_part)


static func selection_ungroup():
	
	
	
	
	
	
	
	return


#recursive
static func group_get_full_hierarchy(group : Group):
	if group.child_groups.is_empty():
		return [group]
	else:
		var child_groups_return : Array = []
		for child_group in group.child_groups:
			child_groups_return.append_array(group_get_full_hierarchy(child_group))
		return child_groups_return


static func group_get_hierarchy_depth(group : Group):
	
	
	return


#feed result of function above as parameter
#this saves on a little bit of processing
static func group_get_all_child_parts(groups : Array):
	var child_parts : Array = []
	for child_group in groups:
		child_parts.append_array(child_group.child_parts)
	return child_parts


#selection box functions--------------------------------------------------------
static func selection_box_update_transforms():
	var i : int = 0
	assert(selection_boxes.size() == selection_box_targets.size())
	while i < selection_box_targets.size():
		selection_boxes[i].transform = selection_target_get_transform(selection_box_targets[i])
		i = i + 1


#instance and fit selection box to a part as child of workspace node and add it to the array
"TODO"#assigned_node property needs to be removed and checking which part is assigned
#can just be done by matching indices on the parallel arrays
static func selection_box_instance_on_target(target):
	selection_box_targets.append(target)
	var new : SelectionBox = SelectionBox.new()
	selection_boxes.append(new)
	WorkspaceManager.workspace.add_child(new)
	new.box_scale = selection_target_get_extents(target)
	new.transform = selection_target_get_transform(target)
	"TODO"#probably add this to filepathregistry
	var mat : StandardMaterial3D = preload("res://editor/classes/selection_box/selection_box_mat.res")
	new.material_override = mat


#delete all selection boxes and clear 
static func selection_box_clear_all():
	for i in selection_boxes:
		if Main.safety_check(i):
			i.queue_free()
	selection_boxes.clear()


#only used for scale tool
static func selection_box_redraw_all():
	assert(selected_entities.size() == selection_boxes.size())
	var i : int = 0
	while i < selected_entities.size():
		if Main.safety_check(selected_entities[i]):
			selection_boxes[i].box_scale = selection_target_get_extents(selected_entities[i])
			selection_boxes[i].transform = selection_target_get_transform(selected_entities[i])
		else:
			push_error("safety check failed: ", selected_entities[i])
		i = i + 1


#delete selection box whos index matches the selection box targets index
"TODO"#selectionbox pooling?
static func selection_box_delete_on_part(selection_box_target):
	assert(selected_entities.size() == selection_boxes.size())
	if not Main.safety_check(selection_box_target):
		return
	
	var i : int = selected_entities.find(selection_box_target)
	#make sure its in the array
	assert(i >= 0)
	selection_boxes.pop_at(i).queue_free()


"TODO"#unit test somehow?
static func selection_box_hover_on_target(target, is_hovering_allowed : bool):
	if is_hovering_allowed and Main.safety_check(target):
		hover_selection_box.visible = true
		hover_selection_box.global_transform = selection_target_get_transform(target)
		hover_selection_box.box_scale = selection_target_get_extents(target)
	else:
		hover_selection_box.visible = false


static func refresh_bounding_box():
	selected_parts_abb = SnapUtils.calculate_extents(selected_parts_abb, last_element(selected_entities_internal), selected_entities_internal)
	#debug
	var d_input = {}
	d_input.transform = selected_parts_abb.transform
	d_input.extents = selected_parts_abb.extents
	HyperDebug.actions.abb_visualize.do(d_input)
	
	#refresh offset abb to selected array
	#this array is used for transforming the whole selection with the position of the abb
	refresh_offset_abb_to_selected_array()


#utils
static func selection_target_get_extents(target):
	if target is Part:
		return target.part_scale
	elif target is Group:
		return target.group_abb.extents
	else:
		push_error("invalid_type: ", target)


static func selection_target_set_extents(target, input : Vector3):
	if target is Part:
		target.part_scale = input
	elif target is Group:
		target.group_abb.extents = input
	else:
		push_error("invalid_type: ", target)


static func selection_target_get_transform(target):
	if target is Part:
		return target.transform
	elif target is Group:
		return target.group_abb.transform
	else:
		push_error("invalid_type: ", target)


static func selection_target_set_transform(target, input : Transform3D):
	if target is Part:
		target.transform = input
	elif target is Group:
		target.group_abb.transform = input
	else:
		push_error("invalid_type: ", target)


#this function is only used in refresh_bounding_box() and selection_set_exact_transforms()
static func refresh_offset_abb_to_selected_array():
	var i : int = 0
	offset_abb_to_internal_entities.clear()
	while i < selected_entities_internal.size():
		offset_abb_to_internal_entities.append(selected_entities_internal[i].transform.origin - selected_parts_abb.transform.origin)
		i = i + 1


static func last_element(input : Array):
	if input.size() == 0:
		return null
	else:
		return input.get(input.size() - 1)


#convenience methods for undoing and redoing deletion
static func add_children(on_node : Node, input : Array):
	for i in input:
		on_node.add_child(i)


static func remove_children(from_node : Node, input : Array):
	for i in input:
		from_node.remove_child(i)
