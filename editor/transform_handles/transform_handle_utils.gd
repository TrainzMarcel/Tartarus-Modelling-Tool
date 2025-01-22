extends RefCounted
class_name TransformHandleUtils

"TODO"#add a max distance in case user drags too far
#make sure to test this with orthogonal camera in the future
static func transform(active_handle : TransformHandle, transform_handle_root : Node3D, drag_offset : Vector3, ray_result : Dictionary, event : InputEventMouseMotion, cam_normal_prev : Vector3, cam_normal : Vector3, cam : FreeLookCamera):
	var r_transform : Transform3D
	match active_handle.direction_type:
		TransformHandle.DirectionTypeEnum.axis_move:
			#first construct a plane along the axis the normal of which points to the camera
			#(but only rotating along the axis)
			var plane_axis : Plane = Plane(active_handle.direction_vector)
			#need a plane which acts like a sprite that rotates around the handles direction_vector
			var plane_cam : Plane = Plane(plane_axis.project(cam.global_position))
			var cam_normal_plane = plane_cam.intersects_ray(cam.global_position, cam_normal)
			var cam_normal_prev_plane = plane_cam.intersects_ray(cam.global_position, cam_normal_prev)
			
			#find vector between mouse projected onto plane_cam from
			if cam_normal_plane != null and cam_normal_prev_plane != null:
				var term_1 = cam_normal_plane - cam_normal_prev_plane
				var term_2 = active_handle.direction_vector * (active_handle.direction_vector.dot(term_1))
				r_transform.origin = term_2
			
			
			
			
		TransformHandle.DirectionTypeEnum.axis_rotate:
			print("GRAOW ROTATE")
		TransformHandle.DirectionTypeEnum.plane_move:
			print("GRAOW PLANE MOVE")
	
	
	#take ((plane normal times absolute distance to plane) DOT cam_normal) * cam_normal
	#do same operation with cam_normal_prev
	#then subtract them
	#finally, project result onto active_handle.normal
	
	
	
	
	
	return r_transform

