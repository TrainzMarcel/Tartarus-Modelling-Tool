extends RefCounted
class_name TransformHandleUtils


"TODO"#add a max distance in case user drags too far
#make sure to test this with orthogonal camera in the future
"TODO"#this math doesnt always work properly (something to do with camera angle and being too close to a handle)
static func transform(active_handle : TransformHandle, transform_handle_root : Node3D, drag_offset : Vector3, ray_result : Dictionary, event : InputEventMouseMotion, cam_normal_prev : Vector3, cam_normal : Vector3, cam : FreeLookCamera):
	var r_transform : Transform3D = Transform3D()
	var local_vector : Vector3 = transform_handle_root.transform.basis * active_handle.direction_vector
	match active_handle.direction_type:
		TransformHandle.DirectionTypeEnum.axis_move:
			#first construct a plane along the axis the normal of which points to the camera
			#(but only rotating along the axis)
			var plane_axis : Plane = Plane(local_vector)
			#need a plane which acts like a sprite that rotates around the handles direction_vector
			var plane_cam : Plane = Plane(plane_axis.project(cam.global_position))
			var cam_normal_plane = plane_cam.intersects_ray(cam.global_position, cam_normal)
			var cam_normal_prev_plane = plane_cam.intersects_ray(cam.global_position, cam_normal_prev)
			
			#find vector between mouse projected onto plane_cam from
			if cam_normal_plane != null and cam_normal_prev_plane != null:
				var term_1 = cam_normal_plane - cam_normal_prev_plane
				var term_2 = local_vector * (local_vector.dot(term_1))
				r_transform.origin = term_2
			
			
			
			
		TransformHandle.DirectionTypeEnum.axis_rotate:
			print("ROTATE")
		TransformHandle.DirectionTypeEnum.plane_move:
			print("PLANE MOVE")
	
	
	#take ((plane normal times absolute distance to plane) DOT cam_normal) * cam_normal
	#do same operation with cam_normal_prev
	#then subtract them
	#finally, project result onto active_handle.normal
	
	
	
	
	"TODO"#last time i focused on modularizing main and improving the data structure of transformhandle root AND i have to make tool switching work with collision and visibility.
	#next would be to implement rotating tool, scaling tool, spawning of parts, color and material tool, material shader, then saving and loading, then wedges, better snapping, pivot point and export import pipeline as final boss
	return r_transform


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


static func initialize_transform_handle_root(input : TransformHandleRoot):
	var child_nodes : Array[Node] = input.get_children()
	var transform_handle_array : Array[TransformHandle] = []
	
	for i in child_nodes:
		transform_handle_array.append(i)
	
	input.tool_handle_array.move = transform_handle_array

