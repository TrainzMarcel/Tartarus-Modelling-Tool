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
	#with some function to make sure
	#child_entities of parent_group and vice reversa are always updated in sync
	var parent_group : Group 
	var child_entities : Array = []
	#group_abb orientation part / group
	var primary_entity
	var group_abb : ABB = ABB.new()
	
	
	func copy():
		var new : Group = Group.new()
		
		#base case: if no data is in the group, return an empty group
		#copy child groups
		var child_groups : Array = self.child_entities.filter(SelectionManager.is_group)
		var child_parts : Array = self.child_entities.filter(SelectionManager.is_part)
		if not child_groups.is_empty():
			for child_group in child_groups:
				SelectionManager.group_add_child_entities(new, [child_group.copy()])
		
		#copy child parts
		"TODO"#test
		if not child_parts.is_empty():
			for child_part in child_parts:
				var copy = child_part.copy()
				WorkspaceManager.workspace.add_child(copy)
				copy.initialize()
				SelectionManager.group_add_child_entities(new, [copy])
			 
		
		#copy primary_entity
		if not self.primary_entity == null:
			#if the parent group is the primary entity, copy it
			if self.parent_group == self.primary_entity:
				new.primary_entity = self.primary_entity.copy()
			#otherwise copy the child entity that is the primary entity
			else:
				var primary_entity_index : int = self.child_entities.find(self.primary_entity)
				new.primary_entity = new.child_entities[primary_entity_index]
			
			if new.primary_entity == null:
				push_error("primary entity is not within the group?")
			
		else:
			push_warning("copied group does not have a primary entity")
		
		#copy group_abb
		if not self.group_abb == null:
			new.group_abb = ABB.new()
			new.group_abb.extents = self.group_abb.extents
			new.group_abb.transform = self.group_abb.transform
		
		SelectionManager.entities_activate([new])
		return new
	
	func debug_print():
		print("group_debug---------------------------------------------------------------------")
		print("root_groups: ", SelectionManager.root_groups.size())
		print("selected abb: ", SelectionManager.selected_parts_abb.extents)
		print("group.group_abb: ", self.group_abb.extents)
		print("selected abb: ", SelectionManager.selected_parts_abb.transform.origin)
		print("group.group_abb: ", self.group_abb.transform.origin)
		print("selected_entities:          ", SelectionManager.selected_entities.filter(SelectionManager.is_part).size(), " parts, ", SelectionManager.selected_entities.filter(SelectionManager.is_group).size(), " groups")
		print("selected_entities_internal: ", SelectionManager.selected_entities_internal.filter(SelectionManager.is_part).size(), " parts, ", SelectionManager.selected_entities_internal.filter(SelectionManager.is_group).size(), " groups")
		print("selection_box_targets:      ", SelectionManager.selection_box_targets.size())
		print("selection_boxes:            ", SelectionManager.selection_boxes.size())
		print("group data")
		print("group child groups:  ", self.child_entities.filter(SelectionManager.is_group).size())
		print("group child parts:   ", self.child_entities.filter(SelectionManager.is_part).size())
		print("group primary entity:", self.primary_entity)

#0 counts as a level so 2 permits 3 levels
const group_depth_max : int = 2
const group_depth_colors : Array[Color] = [Color.BLACK, Color.DIM_GRAY, Color.WHITE]

#keep track of groups which have depth selectionboxes assigned to them
static var group_depth_assigned_groups : Array = []
static var is_depth_visualization_active : bool = false

#child part keys pointing at root groups (for quickly finding the top most group on hovering over any part)
static var root_group_child_parts_hashmap : Dictionary = {}
#child entity keys pointing at parent groups (for quickly removing references from their parent group on deletion)
static var parent_group_child_entity_hashmap : Dictionary = {}
static var root_groups : Array[Group] = []
static var existing_groups : Array[Group] = []

#selected groups/parts, parallel with selectionbox array
static var selected_entities : Array = []

#selected_entities_internal and offset_abb_to_internal_entities are parallel arrays!!
#flattened array of full hierarchy of selected_entities (all root and child parts and child groups) for transformations
static var selected_entities_internal : Array = []
#local offsets from the internal selected parts and groups positions to the abb position: recalculate_abb_offsets()
static var offset_abb_to_internal_entities : Array[Vector3] = []

#selection_boxes and selection_box_targets are parallel arrays
#simply copy transforms from targets to selectionboxes when necessary: update_selection_boxes()
static var selection_box_targets : Array = []
static var selection_boxes : Array[SelectionBox] = []

#set this on selection change, this tells the bounding box to recalculate itself
#between selection handling and selection transform operations
static var selection_changed : bool = false:
	set(value):
		#wait until end of process frame to call post_selection_update
		#if its state flips from false to true, await process frame to call post selection update
		#it has to be called at the end of the frame though and not at the start of the next frame
		if value and not selection_changed:
			post_selection_update.call_deferred()
		
		selection_changed = value


#call set_transform_handle_root at end of input frame
static var selection_moved : bool = false:
	set(value):
		if value and not selection_moved:
			post_movement_update.call_deferred()
		
		selection_moved = value


static var groups_changed : bool = false:
	set(value):
		if value and not selection_moved:
			post_group_update.call_deferred()
		
		groups_changed = value


#for copy pasting
static var entities_clipboard : Array = []


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
						SelectionManager.selection_remove_entities_undoable([hovered_entity])
			#hovered part is not in selection
				else:
				#shift is held
					if Input.is_key_pressed(KEY_SHIFT) and Main.safety_check(dragged_part):
						SelectionManager.selection_add_entities_undoable([hovered_entity])
					else:
						SelectionManager.selection_clear()
						SelectionManager.selection_add_entities_undoable([hovered_entity])
	#no parts hovered
			elif is_selecting_allowed:
				#shift is unheld
				if not Input.is_key_pressed(KEY_SHIFT):
					if not Main.safety_check(hovered_handle):
						SelectionManager.selection_clear_undoable()
			
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
				#immediately update hovered_part in case theres another part behind the deleted one(s)
				hovered_part = Main.part_hover_check()
				SelectionManager.selection_box_hover_on_target(hovered_entity, is_hovering_allowed)
		#deselect all
		elif event.keycode == KEY_A and event.ctrl_pressed and event.shift_pressed:
			if is_selecting_allowed:
				SelectionManager.selection_clear_undoable()
				EditorUI.set_l_msg("cleared selection")
		#select all
		elif event.keycode == KEY_A and event.ctrl_pressed:
			if is_selecting_allowed:
				SelectionManager.selection_set_to_workspace_undoable()
				EditorUI.set_l_msg("selected all parts")
		#cut
		elif event.keycode == KEY_X and event.ctrl_pressed:
			SelectionManager.selection_copy()
			SelectionManager.selection_delete_undoable()
			EditorUI.set_l_msg("cut " + str(SelectionManager.entities_clipboard.size()) + " entities")
		#copy
		elif event.keycode == KEY_C and event.ctrl_pressed:
			SelectionManager.selection_copy()
			EditorUI.set_l_msg("copied " + str(SelectionManager.entities_clipboard.size()) + " entities")
		#paste
		elif event.keycode == KEY_V and event.ctrl_pressed:
			SelectionManager.selection_paste_undoable()
			EditorUI.set_l_msg("pasted " + str(SelectionManager.entities_clipboard.size()) + " entities")
		#duplicate
		elif event.keycode == KEY_D and event.ctrl_pressed:
			SelectionManager.selection_duplicate_undoable()
			EditorUI.set_l_msg("duplicated " + str(SelectionManager.selected_entities.size()) + " entities")
		#ungroup
		elif event.keycode == KEY_G and event.ctrl_pressed and event.shift_pressed:
			SelectionManager.selection_ungroup_undoable()
		#group
		elif event.keycode == KEY_G and event.ctrl_pressed:
			SelectionManager.selection_group_undoable()


"TODO"#make guard clauses and use returns to flatten this mess
#static func handle_left_click(event : InputEvent, is_selecting_allowed : bool, hovered_part : Part, dragged_part, hovered_handle : TransformHandle, is_ui_hovered : bool):
#click selecting behavior
#if click on unselected part, set it as the selection (array with only that part, discard any prior selection)
#if click on unselected part while shift is held, append to selection
#if click on part in selection while shift is held, remove from selection
#if click on nothing, clear selection array
#if click on nothing while shift is held, do nothing
#function....


"TODO"#parameterize variables from main, it would help debugging immensely
#this function MUST be called whenever the number of selected parts changes
#it is separate because you may save performance by
#making multiple selection calls before calling this one
static func post_selection_update(is_manual_call : bool = false):
	if selected_entities.size() > 0 and (Main.is_selecting_allowed or ToolManager.selected_tool == ToolManager.SelectedToolEnum.t_pivot):
		#refresh bounding box on definitive selection change
		#automatically refreshes abb offset array
		_refresh_bounding_box()
		#TODO this only actually needs to be called when the selection changes from size 0 to size > 0
		ToolManager.handle_set_active(ToolManager.selected_tool_handle_array, true)
		#call this automatically because its cheap and the selection will have moved
		post_movement_update()
	
	elif selected_entities.size() == 0 and selection_changed and ToolManager.selected_tool != ToolManager.SelectedToolEnum.t_pivot:
		#TODO this only needs to be called when the selection changes from size > 0 to 0
		ToolManager.handle_set_active(ToolManager.selected_tool_handle_array, false)
	
	
	group_display()
	
	print("post selection update called, manual call: ", is_manual_call)
	if not is_manual_call:
		selection_changed = false


static func post_movement_update():
	if SelectionManager.selected_entities.size() > 0 and (Main.is_selecting_allowed or ToolManager.selected_tool == ToolManager.SelectedToolEnum.t_pivot):
		#if selection_changed or selection_moved:
			#recalculate local pivot transform on selection change
			if WorkspaceManager.pivot_custom_mode_active:
				WorkspaceManager.pivot_local_transform = SelectionManager.selected_parts_abb.transform.inverse() * WorkspaceManager.pivot_transform
			
			ToolManager.handle_set_root_position(
				Main.transform_handle_root,
				SelectionManager.selected_parts_abb,
				WorkspaceManager.pivot_transform,
				WorkspaceManager.pivot_custom_mode_active,
				Main.local_transform_active,
				ToolManager.selected_tool_handle_array
			)
	
	selection_box_update_transforms()
	
	selection_moved = false


#figure out exactly how to control and keep track of groups
#probably in a similar manner to selection_add_entity and selection_remove_entity
#and then based on these variables (or some other data?)
#static var root_group_child_parts_hashmap : Dictionary = {}
#static var root_groups : Array[Group] = []
#post group update would then update these variables and also call group_display
static func post_group_update():
	#update external state
	#process information for hovering over parts and determining if theyre in a group
	group_recalculate_hashmap_and_root()
	
	
	#with in-group part selecting implemented, group bounding boxes must be refreshed
	#whenever the user selects parts within groups and modifies them
	#var affected_groups : Array = group_get_root_groups_of_selected_entities()
	
	#for the time being, update all existing groups instead of guessing through what is selected
	#the delete tool doesnt select anything which causes this system to miss what groups are to be updated
	#in the future i will build a reusable batch-update and pooling system instead
	var i : int = 0
	while i < existing_groups.size():
		#for group in group_get_full_hierarchy(affected_groups[i]):
		for group in existing_groups:
			group_recalculate_bounding_box(group)
		i = i + 1
	
	#affected_groups.size()
	if existing_groups.size() > 0 and is_depth_visualization_active:
		selection_box_redraw_all()
	group_display()
	groups_changed = false


static func selection_rect_prepare(event : InputEvent, selection_rect : Panel):
	is_rect_selecting_active = true
	initial_selection_rect_event = event
	#duplicate to avoid mutation
	initial_selected_entities = selected_entities.duplicate()
	undo_data_selection_rect = UndoManager.UndoData.new()
	undo_data_selection_rect.append_undo_action_with_args(selection_clear, [])
	undo_data_selection_rect.append_undo_action_with_args(selection_add_entities, [initial_selected_entities])
	
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
		var a1 : Vector3 = cam.project_position(a, Main.raycast_length)
		var b1 : Vector3 = cam.project_position(b, Main.raycast_length)
		var c1 : Vector3 = cam.project_position(c, Main.raycast_length)
		var d1 : Vector3 = cam.project_position(d, Main.raycast_length)
		
		var e1 : Vector3 = cam.position
		
		var frustum_collider : ConvexPolygonShape3D = ConvexPolygonShape3D.new()
		frustum_collider.points = [a1, b1, c1, d1, e1]
		
		var params : PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
		params.shape = frustum_collider
		var result = physics.intersect_shape(params, 2048)
		
		var result_colliders = result.map(func(input): return input.collider)
		var result_entities : Array = []
		
		for i in result_colliders:
			if i is Part:
				var entity = SelectionManager.get_hovered_entity(i, Main.group_exclude_key)
				if not result_entities.has(entity):
					result_entities.append(entity)
		
		"TODO"#there has to be a better way to do this
		#guarantee the first selected part is always at the start of the array
		#so that the bounding box orientation doesnt change
		if result_entities.size() > 0 and first_entity_selection_rect == null:
			first_entity_selection_rect = last_element(result_entities)
			Main.initial_rotation = selection_target_get_transform(first_entity_selection_rect).basis
		
		if first_entity_selection_rect != null and result_entities.size() > 1:
			result_entities.erase(first_entity_selection_rect)
			result_entities.push_front(first_entity_selection_rect)
		
		#shift holding logic
		if result_entities.size() > 0:
			if first_entity_selection_rect != null:
				if Input.is_key_pressed(KEY_SHIFT):
					for entity in initial_selected_entities:
						#if shift is held, simply flip the state
						#so any selected entities get deselected
						if result_entities.has(entity):
							result_entities.erase(entity)
						else:
							result_entities.append(entity)
				
				selection_clear()
				selection_add_entities(result_entities)
		else:
			if Input.is_key_pressed(KEY_SHIFT) and initial_selected_entities.size() > 0:
				selection_clear()
				selection_add_entities(initial_selected_entities)
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
	undo_data_selection_rect.append_redo_action_with_args(selection_clear, [])
	undo_data_selection_rect.append_redo_action_with_args(selection_add_entities, [selection])
	undo_data_selection_rect.explicit_object_references.append_array(selection)
	UndoManager.register_undo_data(undo_data_selection_rect)
	undo_data_selection_rect = null


#selection functions------------------------------------------------------------
#returns a root group or a part depending on whether a part belongs to a group
static func get_hovered_entity(hovered_part : Part, exclude_group_key : Key):
	if Input.is_key_pressed(exclude_group_key):
		return hovered_part
	
	var group_of_part : Group = root_group_child_parts_hashmap.get(hovered_part)
	if Main.safety_check(group_of_part):
		return group_of_part
	return hovered_part


static func selection_add_entities(entities : Array):
	if entities.is_empty():
		return
	
	_internal_entities_add_entities(entities)
	print(selected_entities_internal)
	for entity in entities:
		#theoretically this should never be called on already selected entities
		if selected_entities.has(entity):
			push_error("entities that are already selected are unable to be added")
			continue
		selected_entities.append(entity)
		selection_box_instance_on_target(entity)
		print("added: ", entity)
	
	#currently the selected entities bounding box's transform
	#(position before recalculating bounds but especially the rotation)
	#is set as the last part
	selected_parts_abb.transform = selection_target_get_transform(last_element(selected_entities))
	#trigger post selection update at end of frame
	selection_changed = true
	#print("debug---------------------------------------------------------------------------")
	#print("selected_entities: ", selected_entities.filter(is_group).size(), " groups, ", selected_entities.filter(is_part).size(), " parts")
	#print("selected_entities_internal: ", selected_entities_internal.filter(is_group).size(), " groups, ", selected_entities_internal.filter(is_part).size(), " parts")


static func selection_add_entities_undoable(entities : Array):
	if selected_entities.has(entities):
		push_error("entities that are already selected are unable to be added")
		return
	
	var prev_selection : Array = entities.duplicate()
	selection_add_entities(entities)
	
	var undo : UndoManager.UndoData = UndoManager.UndoData.new()
	undo.append_undo_action_with_args(selection_remove_entities, [prev_selection])
	undo.explicit_object_references.append_array(prev_selection)
	undo.append_redo_action_with_args(selection_add_entities, [prev_selection])
	UndoManager.register_undo_data(undo)


static func selection_remove_entities(entities : Array):
	if entities.is_empty():
		return
	
	_internal_entities_remove_entities(entities)
	
	for entity in entities:
		if not selected_entities.has(entity):
			push_error("entities that are not selected are unable to be removed")
			continue
		
		selection_box_delete_on_part(entity)
		selected_entities.erase(entity)
	
	selection_changed = true


static func selection_remove_entities_undoable(entities : Array):
	for entity in entities:
		if not selected_entities.has(entity):
			push_error("entities that are not selected are unable to be removed")
			continue
	
	var prev_selection : Array = entities.duplicate()
	selection_remove_entities(entities)
	
	var undo : UndoManager.UndoData = UndoManager.UndoData.new()
	undo.append_undo_action_with_args(selection_add_entities, [prev_selection])
	undo.explicit_object_references.append_array(prev_selection)
	undo.append_redo_action_with_args(selection_remove_entities, [prev_selection])
	UndoManager.register_undo_data(undo)


static func selection_set_to_workspace_undoable():
	var selection_before : Array = selected_entities.duplicate()
	
	selection_clear()
	selection_add_entities(get_workspace_entities())
	
	var selection_after : Array = selected_entities.duplicate()
	var undo : UndoManager.UndoData = UndoManager.UndoData.new()
	undo.append_undo_action_with_args(selection_clear, [])
	undo.append_undo_action_with_args(selection_add_entities, [selection_before])
	undo.explicit_object_references.append_array(selection_before)
	undo.explicit_object_references.append_array(selection_after)
	undo.append_redo_action_with_args(selection_clear, [])
	undo.append_redo_action_with_args(selection_add_entities, [selection_after])
	UndoManager.register_undo_data(undo)


static func get_workspace_entities():
	var all_entities : Array = []
	var workspace_parts = WorkspaceManager.workspace.get_children().filter(func(part):
		return part is Part
		)
	
	var modifier_key : Key = KEY_NONE
	
	for i in workspace_parts:
		var entity = get_hovered_entity(i, modifier_key)
		
		#make sure not to return duplicates as many parts will belong to one group
		if not all_entities.has(entity):
			all_entities.append(entity)
	
	return all_entities


static func selection_clear():
	selection_box_clear_all(selected_entities)
	selected_entities.clear()
	selected_entities_internal.clear()
	offset_abb_to_internal_entities.clear()
	selection_changed = true
	#does not need to call selection_changed as the bounding box doesnt matter when nothing is selected


static func selection_clear_undoable():
	var selection : Array = selected_entities.duplicate()
	
	selection_clear()
	
	var undo : UndoManager.UndoData = UndoManager.UndoData.new()
	undo.append_undo_action_with_args(selection_clear, [])
	undo.append_undo_action_with_args(selection_add_entities, [selection])
	undo.explicit_object_references.append_array(selection)
	undo.append_redo_action_with_args(selection_clear, [])
	UndoManager.register_undo_data(undo)


#selected entities operations---------------------------------------------------
#for now, made delete key use this function instead of the undoable one
static func selection_delete():
	var selection : Array = selected_entities.duplicate()
	selection_clear()
	entities_delete(selection)


static func selection_delete_undoable():
	var undo : UndoManager.UndoData = UndoManager.UndoData.new()
	var selection : Array = selected_entities.duplicate()
	
	selection_clear()
	
	undo.append_redo_action_with_args(selection_clear, [])
	undo.append_undo_action_with_args(selection_clear, [])
	entities_delete_undoable(selection, undo)
	
	undo.append_undo_action_with_args(selection_add_entities, [selection])
	undo.explicit_object_references.append_array(selection)
	
	UndoManager.register_undo_data(undo)


static func selection_copy():
	entities_clipboard.clear()
	for i in selected_entities:
		entities_clipboard.append(i.copy())


static func selection_paste():
	if entities_clipboard.is_empty():
		return
	
	var duplicated_entities : Array = []
	
	selection_clear()
	for i in entities_clipboard:
		if i is Part:
			var copy : Part = i.copy()
			WorkspaceManager.workspace.add_child(copy)
			copy.initialize()
			duplicated_entities.append(copy)
		else:
			var copy : Group = i.copy()
			for part in group_get_all_child_parts(group_get_full_hierarchy(copy)):
				root_group_child_parts_hashmap[part] = copy
			duplicated_entities.append(copy)
			groups_changed = true
	
	selection_add_entities(duplicated_entities)


static func selection_paste_undoable():
	if entities_clipboard.is_empty():
		return
	
	var undo : UndoManager.UndoData = UndoManager.UndoData.new()
	var selection_before : Array = selected_entities.duplicate()
	selection_paste()
	var selection_after : Array = selected_entities.duplicate()
	
	undo.append_undo_action_with_args(selection_clear, [])
	undo.append_undo_action_with_args(selection_add_entities, [selection_before])
	undo.append_undo_action_with_args(entities_deactivate, [selection_after])
	undo.explicit_object_references.append_array(selection_before)
	undo.explicit_object_references.append_array(selection_after)
	undo.append_redo_action_with_args(entities_activate, [selection_after])
	undo.append_redo_action_with_args(selection_add_entities, [selection_after])
	undo.append_redo_action_with_args(selection_clear, [])
	UndoManager.register_undo_data(undo)


static func selection_duplicate():
	for i in selected_entities:
		if i is Part:
			var copy : Part = i.copy()
			WorkspaceManager.workspace.add_child(copy)
			copy.initialize()
		else:
			var copy : Group = i.copy()
			root_groups.append(copy)
			#recalculate hashmap
			group_append_to_hashmap([copy])


static func selection_duplicate_undoable():
	if selected_entities.is_empty():
		return
	
	var copied_entities : Array = []
	for i in selected_entities:
		if i is Part:
			var copy : Part = i.copy()
			"TODO"#this should be abstracted somehow
			WorkspaceManager.workspace.add_child(copy)
			copy.initialize()
			copied_entities.append(copy)
		else:
			var copy : Group = i.copy()
			groups_changed = true
			copied_entities.append(copy)
	
	
	var undo : UndoManager.UndoData = UndoManager.UndoData.new()
	undo.append_undo_action_with_args(entities_deactivate, [copied_entities])
	undo.explicit_object_references = copied_entities
	undo.append_redo_action_with_args(entities_activate, [copied_entities])
	assert(selected_entities_internal.size() == offset_abb_to_internal_entities.size())


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
	
	groups_changed = true
	
	#move transform handles with selection
	selection_moved = true


#rotation only
"TODO"#parameterize everything for clarity and to prevent bugs
"TODO"#check and ensure numerical stability
#pivot point is local to the selection bounding box (x 0.5 means 0.5 to the right of the abb)
static func selection_rotate(rotated_basis : Basis, local_pivot_point : Vector3 = Vector3.ZERO):
	var original_basis : Basis = Basis(selected_parts_abb.transform.basis)
	#calculate difference betwee5n original basis and new basis
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
	while i < selected_entities_internal.size():
		#rotate offset_dragged_to_selected_array vector by the difference basis
		offset_abb_to_internal_entities[i] = difference * offset_abb_to_internal_entities[i]
		#move part to ray_result.position for easier pivoting (drag-specific functionality)
		var new_transform : Transform3D
		if not Main.ray_result.is_empty():
			new_transform = selection_target_get_transform(selected_entities_internal[i])
			new_transform.origin = Main.ray_result.position
		else:
			new_transform = selection_target_get_transform(selected_entities_internal[i])
			new_transform.origin = selected_parts_abb.transform.origin
		
		
		#rotate this entity
		new_transform.basis = difference * new_transform.basis
		#move it back out along the newly rotated offset_dragged_to_selected_array vector
		new_transform.origin = selected_parts_abb.transform.origin + offset_abb_to_internal_entities[i]
		selection_target_set_transform(selected_entities_internal[i], new_transform)
		#copy transform
		#selection_box_update_transforms()
		i = i + 1
	
	#update group display
	groups_changed = true
	
	#move transform handles with selection
	selection_moved = true

#scale_absolute meaning it will set the scale of the selection bounding box to this value
#must call selection_move after this function due to the updated offset_abb_to_selected_array
"TODO"#OPTIMIZE OPTIMIZE OPTIMIZE
#https://www.reddit.com/r/godot/comments/187npcd/how_to_increase_performance/
#https://docs.godotengine.org/en/4.1/classes/class_renderingserver.html
"TODO"#this function is not very stable mathematically
"TODO"#add variables that remember the original scale and part positions from when the scaling handle drag started
static func selection_scale(scale_absolute : Vector3):
	
	#dont do anything if scale is the same
	if scale_absolute == selected_parts_abb.extents:
		return
	
	#scaling singular entities is easy
	if selected_entities_internal.size() == 1:
		selection_target_set_extents(selected_entities_internal[0], scale_absolute)
		selected_parts_abb.extents = scale_absolute
		selection_box_redraw_all()
		selection_moved = true
		return
	
	
	#!!scalable_parts and local_scales are parallel arrays!!
	var scalable_entities : Array
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
	scalable_entities = selected_entities_internal.filter(func(entity):
		return SnapUtils.part_rectilinear_alignment_check(selected_parts_abb.transform.basis, selection_target_get_transform(entity).basis)
	)
	
	
	#first get the local scale of each scalable part
	for i_a in scalable_entities:
		var abb_basis : Basis = selected_parts_abb.transform.basis
		var p : Basis = selection_target_get_transform(i_a).basis
		var s : Vector3 = selection_target_get_extents(i_a)
		
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
	for i_b in offset_abb_to_internal_entities:
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
		while j < scalable_entities.size():
			#get relative scale from 0 to 1 depending on how much space the part takes up in the bounding box
			var new_scale : float = local_scales[j][i] / ext[i]
			new_scale = lerp(0.0, scale_absolute[i], new_scale)
			local_scales[j][i] = new_scale
			j = j + 1
		
		
		
		j = 0
		#move all parts in relation to where they are in the bounding box
		while j < selected_entities_internal.size():
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
	while i_d < scalable_entities.size():
		var abb_basis = selected_parts_abb.transform.basis
		var p : Basis = selection_target_get_transform(scalable_entities[i_d]).basis
		var s : Vector3 = selection_target_get_extents(scalable_entities[i_d])
		
		#abb local to world
		var world_scale_again = abb_basis * local_scales[i_d]
		
		#world space to part space
		var diff_reverse = p.inverse()
		var local_scale = diff_reverse * world_scale_again
		
		local_scale.x = abs(local_scale.x)
		local_scale.y = abs(local_scale.y)
		local_scale.z = abs(local_scale.z)
		selection_target_set_extents(scalable_entities[i_d], local_scale)
		i_d = i_d + 1
	
	
	#reassign transformed local offsets to global offset array
	offset_abb_to_internal_entities.clear()
	for i_g in local_offsets:
		offset_abb_to_internal_entities.append(i_g * inverse)
	
	selection_box_redraw_all()
	#move transform handles with selection
	selection_moved = true


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
	selection_box_redraw_all()
	selection_moved = true


#new internal functions to help manage state without errors
static func _internal_entities_add_entities(entities : Array):
	for entity in entities:
		#check if the entity is in the internal array already and the entity isnt already in a selected group
		if selected_entities_internal.has(entity):
			if not selected_entities.has(root_group_child_parts_hashmap.get(entity)):
				push_warning("entities that are already selected are unable to be added")
			continue
		
	#add all child entities of a group to internal array
		if entity is Group:
			var child_entities : Array = group_get_all_child_entities(entity)
			
			assert(child_entities.size() >= 2, "a selected group should have at least 2 child entities")
			
			selected_entities_internal.append_array(child_entities)
			
			#TODO no longer necessary as post_selection_update refreshes abb offsets automatically
			#var calculate_offsets : Callable = func(input):
			#	return selection_target_get_transform(input).origin - selected_parts_abb.transform.origin
			#offset_abb_to_internal_entities.append_array(child_entities.map(calculate_offsets))
		else:
			selected_entities_internal.append(entity)
			#offset_abb_to_internal_entities.append(entity.transform.origin - selected_parts_abb.transform.origin)


static func _internal_entities_remove_entities(entities : Array):
	for entity in entities:
		if entity is Group:
			
			var total : Array = group_get_all_child_entities(entity)
			
			#remove all entities
			for child in total:
			#	offset_abb_to_internal_entities.remove_at(selected_entities_internal.find(child))
				selected_entities_internal.erase(child)
		else:
			#make sure the internal entity being removed is not contained in a selected group
			var group_containing_entity = root_group_child_parts_hashmap.get(entity)
			if group_containing_entity != null:
				if selected_entities.has(group_containing_entity) or selected_entities_internal.has(group_containing_entity):
					continue
			
			#erase the same index as hovered_part
			#offset_abb_to_internal_entities.remove_at(selected_entities_internal.find(entity))
			selected_entities_internal.erase(entity)


#partgroup related functions----------------------------------------------------
static var is_group : Callable = func(input_entity): return input_entity is Group
static var is_part : Callable = func(input_entity): return input_entity is Part


static func selection_group(undo_group_reference : Group = null):
	var selected_parts : Array = selected_entities.filter(is_part)
	var selected_groups : Array = selected_entities.filter(is_group)
	
	assert(not selected_groups.has(undo_group_reference))
	
#first, do a bunch of checks to avoid invalid groups
	var depth : int = 0
	#if depth limit is reached in any of these, cancel
	for group in selected_groups:
		depth = max(group_get_hierarchy_depth_from_root(group), depth)
	assert(depth <= group_depth_max)
	if depth == group_depth_max:
		EditorUI.set_l_msg("grouping failed: group depth limit (" + str(group_depth_max + 1) + ") reached.")
		return
	
	if selected_entities.size() < 2:
		EditorUI.set_l_msg("grouping failed: selection must contain at least 2 entities.")
		return
	
	for part in selected_parts:
		if root_group_child_parts_hashmap.has(part):
			EditorUI.set_l_msg("grouping failed: parts cant be in two groups at once.")
			return
	
#initialize the group
	var group : Group
	if Main.safety_check(undo_group_reference):
		group = undo_group_reference
	else:
		group = Group.new()
	
	
	entities_activate([group])
	group_add_child_entities(group, selected_entities)
	
	
	#this shouldnt be possible but i will keep it just in case of some catastrophic failure
	if not Main.safety_check(group.primary_entity):
		push_error("group was initialized without primary entity; this means the bounding box rotation cannot be set correctly")
	
	#call now to prevent bounding box from being 0,0w,0 when selectionbox is being assigned
	group_recalculate_bounding_box(group)
	
	#group.debug_print()
	selection_clear()
	selection_add_entities([group])
	
	#print("selected abb: ", selected_parts_abb.extents)
	#print("group.group_abb: ", group.group_abb.extents)
	#print("selected abb: ", selected_parts_abb.transform.origin)
	#print("group.group_abb: ", group.group_abb.transform.origin)
	#skippable in case 
	return group


static func selection_group_undoable():
#first, do a bunch of checks to avoid invalid groups
	var selected_parts : Array = selected_entities.filter(is_part)
	var selected_groups : Array = selected_entities.filter(is_group)
	
	var depth : int = 0
	#if depth limit is reached in any of these, cancel
	for group in selected_groups:
		depth = max(group_get_hierarchy_depth_from_root(group), depth)
	assert(depth <= group_depth_max)
	if depth == group_depth_max:
		EditorUI.set_l_msg("grouping failed: group depth limit (" + str(group_depth_max + 1) + ") reached.")
		return
	
	if selected_entities.size() < 2:
		EditorUI.set_l_msg("grouping failed: selection must contain at least 2 entities.")
		return
	
	for part in selected_parts:
		if root_group_child_parts_hashmap.has(part):
			EditorUI.set_l_msg("grouping failed: parts cant be in two groups at once.")
			return
	
	var selection : Array = selected_entities.duplicate()
	var undo_group : Group = selection_group()
	#print("undo_group: ", undo_group)
	#print("select: ", selection.size())
	var undo : UndoManager.UndoData = UndoManager.UndoData.new()
	undo.append_undo_action_with_args(selection_clear, [])
	undo.append_undo_action_with_args(selection_add_entities, [[undo_group]])
	undo.append_undo_action_with_args(selection_ungroup, [])
	undo.explicit_object_references.append_array(selection)
	undo.explicit_object_references.append(undo_group)
	undo.append_redo_action_with_args(selection_clear, [])
	undo.append_redo_action_with_args(selection_add_entities, [selection])
	undo.append_redo_action_with_args(selection_group, [undo_group])
	UndoManager.register_undo_data(undo)


static func selection_ungroup():
	print(selected_entities)
	var selected_groups : Array = selected_entities.filter(is_group)
	
	selection_clear()
	var to_remove : Array = []
	var to_add : Array = selected_entities.filter(is_part)
	
	if selected_groups.size() < 1:
		EditorUI.set_l_msg("ungrouping failed: at least one group must be selected.")
		return
	
	
	for group in selected_groups:
		for child_entity in group.child_entities:
			to_add.append(child_entity)
		
		group_clear_child_entities(group)
		#to_remove.append(group)
	
	#deactivate groups after clearing their children
	entities_deactivate(selected_groups)
	
	
	
	#TODO figure out whether its better ux wise to clear the selection and only add what was grouped before
	#or to leave all previously selected entities selected and add what was grouped before
	selection_add_entities(to_add)


static func selection_ungroup_undoable():
#preliminary checks
	var selection : Array = selected_entities.duplicate()
	var selected_groups : Array = selected_entities.filter(is_group)
	
	if selected_groups.size() < 1:
		EditorUI.set_l_msg("ungrouping failed: at least one group must be selected.")
		return
	
	
	var undo : UndoManager.UndoData = UndoManager.UndoData.new()
	undo.append_undo_action_with_args(selection_clear, [])
	undo.append_undo_action_with_args(selection_add_entities, [selection])
	for undo_group in selected_groups:
		undo.explicit_object_references.append(undo_group)
		undo.append_undo_action_with_args(selection_group, [undo_group])
	
	undo.append_undo_action_with_args(post_selection_update, [])
	
	selection_ungroup()
	var selection_after : Array = selected_entities.duplicate()
	
	undo.explicit_object_references.append_array(selection_after)
	undo.append_redo_action_with_args(selection_clear, [])
	undo.append_redo_action_with_args(selection_add_entities, [selection_after])
	undo.append_redo_action_with_args(selection_ungroup, [])


#handle "activating and deactivating" entities when needed for undoable deletion
#this will automatically handle all child entities of provided groups
#this activates parts and all of a groups children but does not dissolve invalid groups
#it does not change any group references it only activates and deactivates entities
#"TODO" this is a pretty bad abstraction i think because it forces the developer to think about the inner workings
static func entities_activate(entities : Array):
	var groups_to_activate : Array = []
	var parts_to_activate : Array = []
	
	#populate groups to activate
	#provided group + all of its children are added
	for entity in entities.filter(is_group):
		var all_child_groups : Array = group_get_full_hierarchy(entity)
		for child_group in all_child_groups:
			if not groups_to_activate.has(entity):
				groups_to_activate.append(entity)
	
	#populate parts to activate
	for entity in entities.filter(is_part):
		if not parts_to_activate.has(entity):
			parts_to_activate.append(entity)
	
	for group in groups_to_activate:
		for part in group.child_entities.filter(is_part):
			if not parts_to_activate.has(part):
				parts_to_activate.append(part)
	
	#activate entities
	existing_groups.append_array(groups_to_activate)
	groups_changed = not groups_to_activate.is_empty()
	
	for part in parts_to_activate:
		WorkspaceManager.workspace.add_child(part)


#this deactivates parts and all of a groups children but does not dissolve invalid groups or change group references
static func entities_deactivate(entities : Array):
	var groups_to_deactivate : Array = []
	var parts_to_deactivate : Array = []
	
	#populate groups to deactivate
	for entity in entities.filter(is_group):
		var all_child_groups : Array = group_get_full_hierarchy(entity)
		for child_group in all_child_groups:
			if not groups_to_deactivate.has(entity):
				groups_to_deactivate.append(entity)
	
	#populate parts to deactivate
	for entity in entities.filter(is_part):
		if not parts_to_deactivate.has(entity):
			parts_to_deactivate.append(entity)
	
	for group in groups_to_deactivate:
		for part in group.child_entities.filter(is_part):
			if not parts_to_deactivate.has(part):
				parts_to_deactivate.append(part)
	
	#deactivate entities
	for group in groups_to_deactivate:
		entities_deactivate_individual(group)
	
	groups_changed = not groups_to_deactivate.is_empty()
	
	for part in parts_to_deactivate:
		entities_deactivate_individual(part)

#bare minimum, no entity hierarchy tree traversal
static func entities_deactivate_individual(entity):
	if entity is Part:
		WorkspaceManager.workspace.remove_child(entity)
	else:
		existing_groups.erase(entity)
		groups_changed = true


"TODO"#somewhat outdated comment
#1. capture and deduplicate every affected hierarchy (even counting entities with no parent or children)
#2. convert them all into 2d array representations of their hierarchy structure
#3. let the deletion (deactivation) operation happen
#4. go through the same array that was created in step 1 and record their hierarchies in 2d arrays again
#5. when undo and redo are pressed, a special function toggles the entities which were deactivated and
#restructures the groups with the same objects as needed
static func entities_delete_undoable(entities : Array, undo_data : UndoManager.UndoData):
	#simple case: delete entity along with any children
	var entities_no_parent : Array = []
	#complex case: delete entity with children and dissolve the parent if it is invalid.
	#if the parent had one child left and it has a grandparent, reparent the child to its grandparent.
	var entities_with_parent : Array = []
	
	#undo data
	#combination of both above arrays with only the root entities deduplicated and stored
	var entities_all_root : Array = group_get_root_groups_of_entities(entities)
	#remember which entities to activate/deactivate
	var entities_affected : Array = []
	
	assert(entities_all_root.filter(is_group).all(func(input): return input.parent_group == null))
	assert(entities_all_root.filter(is_part).all(func(input): return root_group_child_parts_hashmap.get(input) == null))
	
#populate arrays
	for entity in entities:
		var parent = parent_group_child_entity_hashmap.get(entity)
		if parent != null:
			entities_with_parent.append(entity)
		else:
			entities_no_parent.append(entity)
	
	#i have not considered or thought through what will happen if non-root groups are selected
	assert(entities_with_parent.filter(is_group).size() == 0, "all provided groups must be root groups. it shouldnt be possible to select any other group within a group tree. undefined behavior.")
	
#setup is done, now comes the main part of this function
#1 record the state of all entities with their complete hierarchies before
	var affected_hierarchies_before : Array = []
	for root in entities_all_root:
		affected_hierarchies_before.append(group_convert_hierarchy_to_dictionary(root))
	
	
#2 delete every entity with no parent, along with any child entities
#all deactivated entities get added to entities_affected
	_entities_no_parent_deactivate(entities_no_parent, entities_affected)
	
	#make sure none of the entities were deleted by being within the deactivated entities array
	entities_with_parent = entities_with_parent.filter(func(input): 
		return not entities_affected.has(input)
	)
	
#3 mark remaining parts with parents and dereference them from their parents
#all deactivated entities get added to entities_affected
	_entities_with_parent_deactivate(entities_with_parent, entities_affected)
	
#4 record the state after
	var affected_hierarchies_after : Array = []
	for root in entities_all_root:
		affected_hierarchies_after.append(group_convert_hierarchy_to_dictionary(root))
#5 set undo
	
	for hierarchy in affected_hierarchies_before:
		undo_data.explicit_object_references.append_array(hierarchy.keys())
		var deduplicate : Array = []
		for parent in hierarchy.values():
			if not deduplicate.has(parent):
				deduplicate.append(parent)
		
		undo_data.explicit_object_references.append_array(deduplicate)
	
	
	for hierarchy in affected_hierarchies_after:
		undo_data.append_redo_action_with_args(group_convert_dictionary_to_hierarchy, [hierarchy])
	undo_data.append_redo_action_with_args(entities_deactivate, [entities_affected])
	
	for hierarchy in affected_hierarchies_before:
		undo_data.append_undo_action_with_args(group_convert_dictionary_to_hierarchy, [hierarchy])
	undo_data.append_undo_action_with_args(entities_activate, [entities_affected])
	
	
	return undo_data


static func _entities_no_parent_deactivate(entities_no_parent : Array, entities_affected : Array):
		entities_deactivate(entities_no_parent)
		
		for entity in entities_no_parent:
			if entity is Group:
				for group in group_get_full_hierarchy(entity):
					entities_affected.append(group)
					entities_affected.append_array(group.child_entities.filter(is_part))
			else:
				entities_affected.append(entity)


static func _entities_with_parent_deactivate(entities_with_parent : Array, entities_affected : Array):
	#this will invalidate any group entities that have too many of their child entities deleted
	var affected_parent_entities : Array = []
	var i : int = 0
	while i < entities_with_parent.size():
		if entities_with_parent[i] is Part:
			var parent = parent_group_child_entity_hashmap.get(entities_with_parent[i])
			group_remove_child_entities(parent, [entities_with_parent[i]])
			affected_parent_entities.append(parent)
			entities_affected.append(parent)
			entities_affected.append(entities_with_parent[i])
			entities_deactivate_individual(entities_with_parent[i])
		i = i + 1
	
#recursively dissolve groups and reparent their entities, from the bottom up
	for group in affected_parent_entities:
		entities_affected.append_array(_group_reparent_dissolve(group))


static func entities_delete(entities : Array):
	@warning_ignore("confusable_local_declaration")
	var _entities_no_parent_delete : Callable = func (entities_no_parent : Array):
		for entity in entities_no_parent:
			if entity is Group:
				var full_tree : Array = group_get_full_hierarchy(entity)
				for i in full_tree:
					#handle child parts
					for child_part in i.child_entities.filter(is_part):
						if Main.safety_check(child_part):
							child_part.queue_free()
					
					#clearing all references of the tree this way should suffice
					i.parent_group = null
					group_clear_child_entities(i)
					existing_groups.erase(i)
			else:
				if Main.safety_check(entity):
					entity.queue_free()
	
	
	@warning_ignore("confusable_local_declaration")
	var _entities_with_parent_delete : Callable = func (entities_with_parent : Array):
		#this will invalidate any group entities that have too many of their child entities deleted
		var affected_parent_entities : Array = []
		var i : int = 0
		while i < entities_with_parent.size():
			if entities_with_parent[i] is Part:
				var parent = parent_group_child_entity_hashmap.get(entities_with_parent[i])
				group_remove_child_entities(parent, [entities_with_parent[i]])
				affected_parent_entities.append(parent)
				entities_with_parent[i].queue_free()
			i = i + 1
	
	#recursively dissolve groups and reparent their entities, from the bottom up
		for group in affected_parent_entities:
			_group_reparent_dissolve(group)
	
	
	#simple case: delete entity along with any children
	var entities_no_parent : Array = []
	#complex case: delete entity with children and dissolve the parent if it is invalid.
	#if the parent had one child left and it has a grandparent, reparent the child to its grandparent.
	var entities_with_parent : Array = []
	#direct reference for easy access
	
	
#populate arrays
	for entity in entities:
		var parent = parent_group_child_entity_hashmap.get(entity)
		if parent != null:
			entities_with_parent.append(entity)
		else:
			entities_no_parent.append(entity)
	
	#i have not considered or thought through what will happen if non-root groups are selected
	assert(entities_with_parent.filter(is_group).size() == 0, "all provided groups must be root groups. it shouldnt be possible to select any other group within a group tree. undefined behavior.")
	
#1. delete every entity with no parent, along with any child entities
	_entities_no_parent_delete.call(entities_no_parent)
	
	#make sure none of the entities were deleted by being within a deleted root group
	entities_with_parent = entities_with_parent.filter(func(input): return Main.safety_check(input))
	
#2. mark remaining parts with parents and dereference them from their parents
	_entities_with_parent_delete.call(entities_with_parent)


#recursive, call on root
static func _group_reparent_dissolve(group : Group):
	var entities_affected : Array = []
	for child_group in group.child_entities.filter(is_group):
		entities_affected.append_array(_group_reparent_dissolve(child_group))
	
	if group == null:
		return
	
	var grandparent = group.parent_group
	
	if group.child_entities.size() == 1:
		entities_deactivate_individual(group)
		entities_affected.append(group)
		var child : Array = group.child_entities.duplicate()
		group_clear_child_entities(group)
		if grandparent != null:
			group_add_child_entities(grandparent, child)
			group_remove_child_entities(grandparent, [group])
		return entities_affected
	
	if group.child_entities.is_empty():
		entities_deactivate_individual(group)
		entities_affected.append(group)
		if grandparent != null:
			group_remove_child_entities(grandparent, [group])
		return entities_affected
	
	return entities_affected


static func group_add_child_entities(group : Group, entities : Array):
	group.child_entities.append_array(entities)
	for entity in entities:
		if entity is Group:
			entity.parent_group = group
	
	#set primary_entity which will determine the rotation of the group bounding box
	group.primary_entity = last_element(group.child_entities)
	SelectionManager.groups_changed = true


static func group_remove_child_entities(group : Group, entities : Array):
	var primary_entity_removed : bool = false
	for entity in entities:
		group.child_entities.erase(entity)
		if entity is Group:
			entity.parent_group = null
		
		if entity == group.primary_entity:
			primary_entity_removed = true
	
	#if primary entity was removed, attempt to set new primary entity
	if primary_entity_removed:
		group.primary_entity = SelectionManager.last_element(group.child_entities)
	
	SelectionManager.groups_changed = true


static func group_clear_child_entities(group : Group):
		for entity in group.child_entities:
			if entity is Group:
				entity.parent_group = null
		
		group.primary_entity = null
		group.child_entities.clear()
		SelectionManager.groups_changed = true


static func group_recalculate_bounding_box(group : Group):
	group.group_abb = SnapUtils.calculate_extents(group.group_abb, group.primary_entity, group.child_entities)


#recalculate hashmap for whenever root_groups changes
static func group_recalculate_hashmap_and_root():
	root_group_child_parts_hashmap.clear()
	root_groups.clear()
	parent_group_child_entity_hashmap.clear()
	
	for group in existing_groups:
		if group.parent_group == null:
			root_groups.append(group)
		
		for entity in group.child_entities:
			parent_group_child_entity_hashmap[entity] = group
	
	
	for r_group in root_groups:
		for part in group_get_all_child_parts(group_get_full_hierarchy(r_group)):
			root_group_child_parts_hashmap[part] = r_group


#same function but without affecting the existing references and only adding specific groups
static func group_append_to_hashmap(groups_to_append : Array):
	for group in groups_to_append:
		for part in group_get_all_child_parts(group_get_full_hierarchy(group)):
			root_group_child_parts_hashmap[part] = group


#recursive
static func group_get_full_hierarchy(group : Group):
	var child_groups : Array = group.child_entities.filter(is_group)
	if child_groups.is_empty():
		return [group]
	else:
		var child_groups_return : Array = []
		for child_group in child_groups:
			child_groups_return.append_array(group_get_full_hierarchy(child_group))
		child_groups_return.append(group)
		return child_groups_return


#feed result of function above as parameter
#this saves on a little bit of processing
"TODO"#DEPRECATED
static func group_get_all_child_parts(groups : Array):
	var child_parts : Array = []
	for child_group in groups:
		child_parts.append_array(child_group.child_entities.filter(is_part))
	return child_parts


#return flat array
"TODO"#DEPRECATED
static func group_get_all_child_entities(group : Group):
	var all_groups : Array = group_get_full_hierarchy(group)
	var entities : Array = group_get_all_child_parts(all_groups)
	entities.append_array(all_groups)
	return entities


#this one is specifically for getting the tree depth from a root group
static func group_get_hierarchy_depth_from_root(group : Group, depth : int = 0):
	var child_groups : Array = group.child_entities.filter(is_group)
	if child_groups.is_empty():
		return depth
	
	var depth_return : int = 0
	for child_group in child_groups: 
		depth_return = max(depth_return, group_get_hierarchy_depth_from_root(child_group, depth + 1))
	return depth_return


#this is for querying any group within a hierarchy
static func group_get_individual_depth(group : Group, depth : int = 0):
	if group.parent_group != null:
		return group_get_individual_depth(group.parent_group, depth + 1)
	else:
		return depth


#disused function
#returns a 2d array of group levels. index 0 will always contain root.
static func group_convert_hierarchy_to_array(group : Group):
	var hierarchy_levels : Array[Array] = []
	assert(group.parent_group == null, "group_organize_hierarchy_by_depth must be called on a root group (must not have a parent)")
	
	for child_group in group_get_full_hierarchy(group):
		var depth : int = group_get_individual_depth(child_group)
		
		#add more space if the array is too small
		while hierarchy_levels.size() < depth + 1:
			hierarchy_levels.append([])
		
		hierarchy_levels[depth].append(child_group)
	
	return hierarchy_levels


static func group_convert_hierarchy_to_dictionary(group : Group):
	var full_hierarchy : Array = group_get_full_hierarchy(group)
	var result : Dictionary = {}
	for child_group in full_hierarchy:
		#assign child entities as keys to their parent group
		for child_entity in child_group.child_entities:
			result[child_entity] = child_group
		
		#if the groups child entities are empty, assign empty value
		if child_group.child_entities.is_empty():
			result[null] = child_group
	
	return result


static func group_convert_dictionary_to_hierarchy(dictionary : Dictionary):
	#first clear remaining hierarchy
	var cleared_groups : Array = []
	for group in dictionary.values():
		if not cleared_groups.has(group):
			cleared_groups.append(group)
			group_clear_child_entities(group)
	
	#secondly assign every child entity key to the value parent
	for child_entity in dictionary.keys():
		if child_entity == null:
			continue
		
		var parent : Group = dictionary[child_entity]
		group_add_child_entities(parent, [child_entity])


#TODO probably outdated comment, need to refine the api anyway
#with in-group part selecting implemented, group bounding boxes must be refreshed
#if there are parts in selected_entities which are in a group
#it tells us the user used the in-group select because
#otherwise only root groups and ungrouped parts show up in selected_entities
static func group_get_root_groups_of_entities(entities : Array):
	var affected_groups : Array = []
	var i : int = 0
	#loop through all entities
	while i < entities.size():
		if entities[i] is Group:
			#climb to root
			var i_group : Group = entities[i]
			while i_group.parent_group != null:
				i_group = i_group.parent_group
			
			if not affected_groups.has(i_group):
				affected_groups.append(i_group)
		else:
			#attempt to get root group of entity
			var group_of_selected_part = root_group_child_parts_hashmap.get(entities[i])
			#only if its not null and the group hasnt been added yet, add it to the affected groups array
			if group_of_selected_part != null and not affected_groups.has(group_of_selected_part):
				affected_groups.append(group_of_selected_part)
		i = i + 1
	return affected_groups


"TODO"#this could be better
#i could assign selectionboxes *while* traversing the hierarchy instead of this
#i could even do the functional approach like Array.map() but rather like group_full_hierarchy_map(function(input_group))
#and i could add a selectionbox hierarchy system to automatically manage which system gets highest display priority
#(selecting priority 10, group display priority 5,...)
static func group_display():
	if is_depth_visualization_active:
		
		for group in group_depth_assigned_groups:
			selection_box_delete_on_part(group)
		group_depth_assigned_groups.clear()
		
		for group in root_groups:
			var child_groups : Array = group_get_full_hierarchy(group)
			for child_group in child_groups:
				#dont add selectionbox to root hierarchy group that already has one on it
				if selection_box_targets.has(child_group):
					continue
				var new : SelectionBox = selection_box_instance_on_target(child_group)
				var depth : int = group_get_individual_depth(child_group)
				new.material_regular_color(group_depth_colors[depth])
				new.box_thickness = 0.014 - depth * 0.001
				group_depth_assigned_groups.append(child_group)
	else:
		#clean up
		for group in group_depth_assigned_groups:
			selection_box_delete_on_part(group)
		group_depth_assigned_groups.clear()


#selection box functions--------------------------------------------------------
static func selection_box_update_transforms():
	var i : int = 0
	assert(selection_boxes.size() == selection_box_targets.size(), "selection_boxes: " + str(selection_boxes.size()) + " == selection_box_targets: " + str(selection_box_targets.size()))
	while i < selection_box_targets.size():
		selection_boxes[i].transform = selection_target_get_transform(selection_box_targets[i])
		i = i + 1


#instance and fit selection box to an entity and add it and the target to arrays
static func selection_box_instance_on_target(target):
	var new : SelectionBox = SelectionBox.new()
	selection_boxes.append(new)
	selection_box_targets.append(target)
	WorkspaceManager.workspace.add_child(new)
	new.box_scale = selection_target_get_extents(target)
	new.transform = selection_target_get_transform(target)
	new.material_regular()
	return new


#delete all selection boxes and clear all selection box targets
static func selection_box_clear_all(targets : Array):
	for i in targets:
		if not Main.safety_check(i):
			print("selection_box_clear_all(): invalid target")
			continue
		var index : int = selection_box_targets.find(i)
		if index == -1:
			print("selection_box_clear_all(): could not find target to delete")
			continue
		
		selection_boxes.pop_at(index).queue_free()
		selection_box_targets.remove_at(index)


#only used for scale tool
static func selection_box_redraw_all():
	assert(selection_box_targets.size() == selection_boxes.size())
	var i : int = 0
	while i < selection_box_targets.size():
		if Main.safety_check(selection_box_targets[i]):
			selection_boxes[i].box_scale = selection_target_get_extents(selection_box_targets[i])
			selection_boxes[i].transform = selection_target_get_transform(selection_box_targets[i])
		else:
			push_error("safety check failed: ", selection_box_targets[i])
		i = i + 1


#delete selection box whos index matches the selection box targets index
"TODO"#selectionbox pooling?
static func selection_box_delete_on_part(selection_box_target):
	assert(selection_box_targets.size() == selection_boxes.size(), "selection_boxes: " + str(selection_boxes.size()) + " == selection_box_targets: " + str(selection_box_targets.size()))
	if not Main.safety_check(selection_box_target):
		return
	
	var i : int = selection_box_targets.find(selection_box_target)
	#make sure its in the array
	#assert(i >= 0)
	if i == -1:
		print("selection_box_delete_on_part(): could not find target to delete")
		return
	selection_box_targets.remove_at(i)
	selection_boxes.pop_at(i).queue_free()


"TODO"#unit test somehow?
static func selection_box_hover_on_target(target, is_hovering_allowed : bool):
	if is_hovering_allowed and Main.safety_check(target) and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		hover_selection_box.visible = true
		hover_selection_box.global_transform = selection_target_get_transform(target)
		hover_selection_box.box_scale = selection_target_get_extents(target)
	else:
		hover_selection_box.visible = false


static func _refresh_bounding_box():
	#this function can take selected_entities because
	#it includes the root groups and non-parts from which the selection bounding box can be calculated quicker
	selected_parts_abb = SnapUtils.calculate_extents(selected_parts_abb, last_element(selected_entities), selected_entities)
	#debug
	var d_input = {}
	d_input.transform = selected_parts_abb.transform
	d_input.extents = selected_parts_abb.extents
	HyperDebug.actions.abb_visualize.do(d_input)
	
	#refresh offset abb to selected array
	#this array is used for transforming the whole selection with the position of the abb
	refresh_offset_abb_to_selected_array()


#utils--------------------------------------------------------------------------
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
		offset_abb_to_internal_entities.append(selection_target_get_transform(selected_entities_internal[i]).origin - selected_parts_abb.transform.origin)
		i = i + 1


static func last_element(input : Array):
	if input.size() == 0:
		return null
	else:
		return input.get(input.size() - 1)


#convenience methods for undoing and redoing deletion
#they take flat part arrays as parameter
static func add_child_parts(input : Array):
	for i in input:
		assert(i is Part)
		WorkspaceManager.workspace.add_child(i)


static func remove_child_parts(input : Array):
	for i in input:
		assert(i is Part)
		WorkspaceManager.workspace.remove_child(i)
