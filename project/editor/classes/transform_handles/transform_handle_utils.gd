extends RefCounted
class_name TransformHandleUtils

"TODO"#comment better
"TODO"#add a max distance in case user drags too far
#make sure to test this with orthogonal camera in the future


#return delta of how far to move depending on if ctrl is held
static func input_scale_linear_move(
		cam : Camera3D,
		active_handle : TransformHandle,
		global_vector : Vector3,
		cam_normal : Vector3,
		cam_normal_initial : Vector3,
		is_ctrl_pressed : bool,
	):
	
	#ctrl: scale both sides, no movement
	if is_ctrl_pressed:
		return 0.0
	return input_linear_move(cam, active_handle, global_vector, cam_normal, cam_normal_initial)


#process input for transform handles that rotate
static func input_rotation(
		cam : Camera3D,
		active_handle : TransformHandle,
		global_vector : Vector3,
		cam_normal : Vector3,
		cam_normal_initial : Vector3
	):
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
	#figure out direction of angle and return
	return angle * sign(term_1.cross(term_2).dot(global_vector))


#process input for transform handles that move linearly
#that includes scaling handles
static func input_linear_move(
		cam : Camera3D,
		active_handle : TransformHandle,
		global_vector : Vector3,
		cam_normal : Vector3,
		cam_normal_initial : Vector3
	):
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


"TODO"
static func input_planar_move():
	
	
	
	pass


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
