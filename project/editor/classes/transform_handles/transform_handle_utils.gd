extends RefCounted
class_name TransformHandleUtils

"TODO"#rename variables better
"TODO"#comment better
"TODO"#add a max distance in case user drags too far
#make sure to test this with orthogonal camera in the future
static func transform(
		active_handle : TransformHandle,
		transform_handle_root : Node3D,
		abb_initial_extents : Vector3,
		handle_initial_transform : Transform3D,
		initial_event : InputEventMouse,
		event : InputEventMouseMotion,
		cam : Camera3D,
		p_snap_increment : float,
		r_snap_increment : float,
		snapping_active : bool,
		is_ctrl_pressed : bool,
		is_shift_pressed : bool
	):
	
	#return transform
	var r_dict : Dictionary = {
		transform = Transform3D(),
		basis_relative = 0.0,
		part_scale = Vector3(),
		modify_position = false,
		modify_rotation = false,
		modify_scale = false
	}
	
	#direction_vector of active_handle transformed from local to global space (local to active_handle)
	var global_vector : Vector3 = (transform_handle_root.transform.basis * active_handle.direction_vector).normalized()
	#for rotation purposes (prevents weird wobbles from happening)
	var global_vector_initial : Vector3 = (handle_initial_transform.basis * active_handle.direction_vector).normalized()
	var cam_normal : Vector3 = cam.project_ray_normal(event.position)
	var cam_normal_initial : Vector3 = cam.project_ray_normal(initial_event.position)
	
	#future note: make it possible to scale selections or groupings if all parts are rectilinearly aligned
	match active_handle.direction_type:
		TransformHandle.DirectionTypeEnum.axis_move:
			
			var term_1 : float = linear_move(cam, active_handle, global_vector, cam_normal, cam_normal_initial)
			
			if snapping_active:
				term_1 = snapped(term_1, p_snap_increment)
			
			#absolute defined as the original position plus the amount the user dragged
			#add the snapped term and take away the original position along the vector axis
			r_dict.transform.origin = (term_1 * global_vector) + handle_initial_transform.origin
			r_dict.transform.basis = handle_initial_transform.basis
			r_dict.scalar = term_1
			r_dict.modify_position = true
		TransformHandle.DirectionTypeEnum.axis_rotate:
			#need a plane which is placed right on the ring
			#get distance from origin point (and with the dot product whether the plane is in
			#negative space or not, to flip plane_cam_d)
			var plane_cam_d = active_handle.global_position.dot(global_vector)
			
			#create plane which cursor would land on if it was put in 3d space
			var plane_ring : Plane = Plane(global_vector, plane_cam_d)
			var cam_normal_initial_plane = plane_ring.intersects_ray(cam.global_position, cam_normal_initial)
			var cam_normal_plane = plane_ring.intersects_ray(cam.global_position, cam_normal)
			
			HyperDebug.actions.transform_handle_rotation_visualize.do({
				origin_position = plane_ring.d * plane_ring.normal,
				input_vector = plane_ring.normal
				})
			
			#fallback value if intersects_ray fails
			var term_1 = Vector3.ZERO
			var term_2 = Vector3.ZERO
			if cam_normal_initial_plane != null and cam_normal_plane != null:
				term_1 = cam_normal_initial_plane - active_handle.global_position
				term_2 = cam_normal_plane - active_handle.global_position
			
			var angle = term_1.angle_to(term_2)
			angle = angle * sign(term_1.cross(term_2).dot(global_vector))
			
			var angle_snapped = angle
			if snapping_active:
				angle_snapped = deg_to_rad(snapped(rad_to_deg(angle_snapped), r_snap_increment))
			
			#absolute defined as the original position plus the amount the user dragged
			r_dict.transform.basis = handle_initial_transform.basis.rotated(global_vector_initial, angle_snapped).orthonormalized()
			r_dict.angle_relative = angle_snapped
			r_dict.transform.origin = handle_initial_transform.origin
			r_dict.modify_rotation = true
		TransformHandle.DirectionTypeEnum.plane_move:
			print("PLANE MOVE")#coming probably in v0.2
		TransformHandle.DirectionTypeEnum.axis_scale:
			
			var term_1 : float = linear_move(cam, active_handle, global_vector, cam_normal, cam_normal_initial)
			
			if snapping_active:
				term_1 = snapped(term_1, p_snap_increment)
			
			#control: makes part not move and scale toward both directions
			#shift: makes part scale toward all directions proportionally
			#shift + control: makes part not move and scale toward all directions proportionally
			
			#set this with ctrl and shift
			var multiplier = 0.5
			if Input.is_key_pressed(KEY_CTRL):
				multiplier = 0
				term_1 = term_1 * 2
			
			
			var local : Vector3 = active_handle.direction_vector
			
			#if local x y or z are negative, set scalar to be negative
			var i = 0
			while i < 3:
				if local[i] < 0 and not Input.is_key_pressed(KEY_SHIFT):
					term_1 = -term_1
				i = i + 1
			
			
			var scale_min : Vector3 = abb_initial_extents + term_1 * local
			var scale_diff : Vector3 = term_1 * local
			
			
			if Input.is_key_pressed(KEY_SHIFT):
				var percentage = (abb_initial_extents.dot(local) + term_1) / abb_initial_extents.dot(local)
				scale_min = abb_initial_extents + abb_initial_extents * percentage
				scale_diff = abb_initial_extents * percentage
			
			
			
			"TODO"#this loop sucks because it affects all dimensions and not just the one which is being scaled
			i = 0
			while i < 3:
				
				scale_min[i] = max(scale_min[i], p_snap_increment)
				i = i + 1
			
			r_dict.part_scale = scale_min
			
			
			r_dict.transform.origin = handle_initial_transform.origin + handle_initial_transform.basis * (scale_diff * local * multiplier)
	
			
			
			
			
			#absolute defined as the original position plus the amount the user dragged
			#add the snapped term and take away the original position along the vector axis
			#r_dict.transform.origin = (term_1 * global_vector) + handle_initial_transform.origin
			r_dict.transform.basis = handle_initial_transform.basis
			#r_dict.part_scale = (term_1 * active_handle.direction_vector)
			#r_dict.scalar = term_1
			r_dict.modify_position = true
			r_dict.modify_scale = true
	
	#next would be to implement scaling tool, spawning of parts, color and material tool, material shader, then saving and loading, then wedges, better snapping, pivot point and export import pipeline
	return r_dict


static func linear_move(cam : Camera3D, active_handle : TransformHandle, global_vector : Vector3, cam_normal : Vector3, cam_normal_initial : Vector3):
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
	
	
	
	
	
	#vector pointing to mouse position projected onto the plane
	var cam_normal_plane = plane_cam.intersects_ray(cam.global_position, cam_normal)
	var cam_normal_plane_initial = plane_cam.intersects_ray(cam.global_position, cam_normal_initial)
	
	HyperDebug.actions.transform_handle_linear_visualize.do({
		input_vector = plane_cam.normal,
		origin_position = plane_cam.d * plane_cam.normal
		})
	
	
	#fallback value if intersects_ray fails
	var term_1 : float = 0
	if cam_normal_plane != null:
		#get the difference between (current projected mouse position) and (initial projected mouse position)
		term_1 = cam_normal_plane.dot(global_vector) - cam_normal_plane_initial.dot(global_vector)
	return term_1


static func set_tool_handle_array_active(bundle : Array, input : bool):
	for i in bundle:
		i.visible = input
		for j in i.collider_array:
			j.disabled = not input


"TODO"#cleaner parameters, like an enum or set color
static func set_transform_handle_highlight(handle : TransformHandle, drag : bool, hover : bool):
	if drag:
		for i in handle.mesh_array:
			i.material_override.albedo_color = handle.color_drag
	elif hover:
		for i in handle.mesh_array:
			i.material_override.albedo_color = handle.color_hover
	else:
		for i in handle.mesh_array:
			i.material_override.albedo_color = handle.color_default


"TODO"#put everything needed to add a new tool into this file (or another)
static func initialize_transform_handle_root(input : TransformHandleRoot):
	var child_nodes : Array[Node] = input.get_children()
	var transform_handle_array : Array[TransformHandle] = []
	
	#loop through identifiers
	for j in Main.SelectedToolEnum.values():
		#for each identifier, loop over all child nodes
		for i in child_nodes:
			#if child nodes identifier matches the current one
			if i.tool_type == j:
				#add it to the array
				transform_handle_array.append(i)
		
		
		#after the loop, assign duplicate (just to be safe) of typed array to the correct dict key
		input.tool_handle_array[j] = transform_handle_array.duplicate()
		
		#clear before getting the next tool handles to assign
		transform_handle_array.clear()
