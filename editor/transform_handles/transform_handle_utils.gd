extends RefCounted
class_name TransformHandleUtils

"TODO"#when adding scaling tool, return a .size attribute for scaled parts
"TODO"#rename variables better
"TODO"#comment better
"TODO"#add a max distance in case user drags too far
"TODO"#add snapping increment
#make sure to test this with orthogonal camera in the future
"TODO"#this math doesnt always work properly (something to do with camera angle and being too close to a handle)

static func transform(active_handle : TransformHandle, transform_handle_root : Node3D, drag_offset : Vector3, handle_initial_transform : Transform3D, cam_normal_initial : Vector3, event : InputEventMouseMotion, cam : FreeLookCamera, debug_mesh : Array, p_snap_increment : float, r_snap_increment : float, snapping_active : bool):
	#return transform
	var r_dict : Dictionary = {
		absolute = Transform3D(),
		relative = Transform3D(),
		modify_position = false,
		modify_rotation = false,
		modify_scale = false
	}
	
	#direction_vector of active_handle transformed from local to global space (local to active_handle)
	var global_vector : Vector3 = (transform_handle_root.transform.basis * active_handle.direction_vector).normalized()
	
	match active_handle.direction_type:
		TransformHandle.DirectionTypeEnum.axis_move:
			#need a plane which acts like a sprite that rotates around the handles direction_vector
			
			#vector pointing from handle to camera.global_position
			var vec : Vector3 = cam.global_position - active_handle.global_position
			#project this vector onto the transform_handles direction vector
			#to only get the part of the vector that is pointing along that direction vector
			var vec_2 : Vector3 = vec.dot(global_vector.normalized()) * global_vector.normalized()
			#flatten vector along transform handle
			#imagine a disc around the transform handles vector and flattening the vector onto the disc
			#like now taking away the component that vec_2 had
			vec = (vec - vec_2).normalized()
			
			#get length (and with the dot product also whether the camera is facing away or not, to flip plane_cam_d)
			var plane_cam_d = active_handle.global_position.dot(vec)
			
			#create plane which cursor would land on if it was put in 3d space
			var plane_cam : Plane = Plane(vec, plane_cam_d)
			
			"DEBUG"#--------------------------------------------------------------------------------
			#print(plane_cam.normal)
			debug_mesh[0].input_vector = plane_cam.normal
			debug_mesh[0].origin_position = Vector3.ZERO
			debug_mesh[0].origin_position = debug_mesh[0].origin_position + plane_cam.d * plane_cam.normal
			"DEBUG"#--------------------------------------------------------------------------------
			
			var cam_normal_initial_plane = plane_cam.intersects_ray(cam.global_position, cam_normal_initial)
			
			#fallback value if intersects_ray fails
			var term_1 = Vector3.ZERO
			if cam_normal_initial_plane != null:
				term_1 = (cam_normal_initial_plane.dot(global_vector)) * global_vector
			#print("global_vector", global_vector)
			#print("cam normal initial ", cam_normal_initial_plane)
			#print("term 1 ", term_1)
			
			var projected_offset : Vector3 = drag_offset.dot(global_vector) * global_vector
			
			var term_snapped : Vector3 = term_1 + projected_offset
			var projected_initial : Vector3 = handle_initial_transform.origin.dot(global_vector) * global_vector
			if snapping_active:
				term_snapped = term_snapped - projected_initial
				term_snapped = term_snapped * handle_initial_transform.basis
				var j : int = 0
				while j < 3:
					term_snapped[j] = snapped(term_snapped[j], p_snap_increment)
					j = j + 1
				
				term_snapped = handle_initial_transform.basis * term_snapped
				term_snapped = term_snapped + projected_initial
			
			#absolute defined as the original position plus the amount the user dragged
			#r_dict.absolute.origin = term_snapped + handle_initial_transform.origin + projected_offset
			
			#print(debug_mesh[1].input_vector)
			r_dict.absolute.origin = term_snapped + (handle_initial_transform.origin - handle_initial_transform.origin.dot(global_vector) * global_vector)
			r_dict.absolute.basis = handle_initial_transform.basis
			#relative defined as only the amount the user dragged
			r_dict.relative.origin = term_snapped
			r_dict.relative.basis = handle_initial_transform.basis
			r_dict.modify_position = true
			
		TransformHandle.DirectionTypeEnum.axis_rotate:
			print("ROTATE")
		TransformHandle.DirectionTypeEnum.plane_move:
			print("PLANE MOVE")
	
	
	#next would be to implement rotating tool, scaling tool, spawning of parts, color and material tool, material shader, then saving and loading, then wedges, better snapping, pivot point and export import pipeline
	return r_dict


static func set_tool_handle_array_active(bundle : Array, input : bool):
	for i in bundle:
		i.visible = input
		for j in i.collider_array:
			j.disabled = not input


static func set_transform_handle_highlight(handle : TransformHandle, input : bool):
	if input:
		for i in handle.mesh_array:
			i.set_instance_shader_parameter("color", handle.color_drag)
	else:
		for i in handle.mesh_array:
			i.set_instance_shader_parameter("color", handle.color_default)


"TODO"#put everything needed to add a new tool into this file (or another)
#this system is very bad with the identifiers and all
static func initialize_transform_handle_root(input : TransformHandleRoot):
	var child_nodes : Array[Node] = input.get_children()
	var transform_handle_array : Array[TransformHandle] = []
	var identifiers : Array[String] = ["move", "rotate"]
	
	#loop through identifiers
	for j in identifiers:
		#for each identifier, loop over all child nodes
		for i in child_nodes:
			#if child nodes identifier matches the current one
			if i.identifier == j:
				#add it to the array
				transform_handle_array.append(i)
		
		
		#after the loop, assign duplicate (just to be safe) of typed array to the correct dict key
		match j:
			"move":
				input.tool_handle_array.move = transform_handle_array.duplicate()
			"rotate":
				input.tool_handle_array.rotate = transform_handle_array.duplicate()
		
		#clear before getting the next tool handles to assign
		transform_handle_array.clear()
