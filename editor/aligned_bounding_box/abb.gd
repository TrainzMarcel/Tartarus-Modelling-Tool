extends RefCounted
class_name ABB

"DEBUG"
var debug_mesh : MeshInstance3D
var extents : Vector3 = Vector3.ZERO:
	set(value):
		extents = value
		debug_mesh.mesh.size = value

var transform : Transform3D:
	set(value):
		transform = value
		debug_mesh.transform = value


#expand bounding box to point in global space
func expand(point : Vector3):
	var dir : Array[Vector3]
	dir = [transform.basis.x, transform.basis.y, transform.basis.z]
	
	#vector pointing from center of bounding box to given point
	#point in local space now
	var to_point : Vector3 = transform.inverse() * point
	var i : int = 0
	while i < 3:
		#get distance to point in axis
		var projected : float = to_point[i]
		#get distance from center of bounding box to the surface of the bounding box
		var distance_center_to_face : float = (extents[i] * 0.5)
		
		#check if the projected scalar is longer than the distance to the face
		if abs(projected) > distance_center_to_face:
			#save current side length of the bounding box
			var difference = extents[i]
			
			#set new length:
			#projected length (center of box -> point) + half of original side length
			extents[i] = abs(projected) + extents[i] * 0.5
			
			#get the difference between the new and old side length
			difference = extents[i] - difference
			
			#set position of bounding box to encompass given point
			#while preserving the original position of the opposite side
			transform.origin = transform.origin + (difference * transform.basis[i] * 0.5) * sign(projected)
		
		i = i + 1

func has_point(point : Vector3):
	var dir : Array[Vector3]
	dir = [transform.basis.x, transform.basis.y, transform.basis.z]
	
	#vector pointing from center of bounding box to given point
	#point in local space now
	var to_point : Vector3 = transform.inverse() * point
	var i : int = 0
	while i < 3:
		#check if to_point scalar is longer than the distance from the center to the face
		if abs(to_point[i]) > extents[i] * 0.5:
			return false
		
		i = i + 1
	
	return true

