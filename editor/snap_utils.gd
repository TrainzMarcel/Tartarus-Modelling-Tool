extends RefCounted
class_name SnapUtils


#input is meant to be the part-to-be-rotated's basis
"TODO"#unit test and make above comment better
#res://editor/debug_and_unit_tests/unit_test.gd
static func snap_rotation(input : Basis, ray_result : Dictionary):
	var b_array : Array[Vector3] = [input.x, input.y, input.z]
	var b_array_2 : Array[Vector3] = [ray_result.collider.basis.x, ray_result.collider.basis.y, ray_result.collider.basis.z]
	var i : int = 0
	var closest_vector_1 : Vector3
	var closest_vector_2 : Vector3
	var highest_dot : float = 0
	
#find closest matching basis vector of dragged_part to normal vector using absolute dot product
#(the dot product farthest from 0)
	while i < b_array.size():
		var j : int = 0
		while j < b_array_2.size():
			#remember, 1 = parallel vectors, 0 = perpendicular, -1 = opposing vectors
			if abs(b_array[i].dot(b_array_2[j])) > abs(highest_dot):
				highest_dot = b_array[i].dot(b_array_2[j])
				closest_vector_1 = b_array[i]
				closest_vector_2 = b_array_2[j]
			j = j + 1
		i = i + 1
	
	if highest_dot == 0:
		return input
	
	
#use angle_to between these two vectors as amount to rotate
#cross product as axis to rotate around
	var dot_1 = closest_vector_1.dot(closest_vector_2)
	#if vectors are opposed, flip closest_vector_1
	var angle = (closest_vector_1 * sign(dot_1)).angle_to(closest_vector_2)
	var cross_product : Vector3 = (closest_vector_1 * sign(dot_1)).cross(closest_vector_2)
	
	#if cross product returns empty vector, return unmodified basis
	if cross_product.length() == 0:
		return input
	
	var rotated_basis : Basis = input.rotated(cross_product.normalized(), angle).orthonormalized()
	
	
#find basis vector on canvas part which is not equal to closest_vector_2 or inverted closest_vector_2
#use x vector, else use y vector
	var vec_1 : Vector3
		#remember, 1 = parallel vectors, 0 = perpendicular, -1 = opposing vectors
		#the closer to 0 the better in this case
	if abs(ray_result.collider.basis.x.dot(closest_vector_2)) < abs(ray_result.collider.basis.y.dot(closest_vector_2)):
		#canvas.basis.x is closer to 0
		vec_1 = ray_result.collider.basis.x
	else:
		#canvas.basis.y is closer to 0
		vec_1 = ray_result.collider.basis.y
	
	
#iterate over all 3 vectors and again find closest absolute dot product
#find signed angle between that and the closest vector and rotate accordingly
	b_array = [rotated_basis.x, rotated_basis.y, rotated_basis.z]
	var r_dict_2 = find_closest_vector_abs(b_array, vec_1)
	angle = (r_dict_2.vector * sign(r_dict_2.dot)).angle_to(vec_1)
	cross_product = (r_dict_2.vector * sign(r_dict_2.dot)).cross(vec_1)
	
	if cross_product.length() == 0:
		return input
	
	#the part should now hopefully be aligned and ready for linear snapping
	return rotated_basis.rotated(cross_product.normalized(), angle).orthonormalized()


#returns index of closest pointing vector, ignoring if the vector is pointing the opposite way
static func find_closest_vector_abs(search_array : Array[Vector3], target : Vector3):
	var highest_dot : float
	var closest_vec_index : int
	var closest_vec : Vector3
	var i : int = 0
	while i < search_array.size():
		var dot_product = search_array[i].dot(target)
		if abs(highest_dot) < abs(dot_product):
			highest_dot = dot_product
			closest_vec_index = i
			closest_vec = search_array[i]
		i = i + 1
	var return_dict = {
		index = closest_vec_index,
		dot = highest_dot,
		vector = closest_vec
	}
	return return_dict


static func part_rectilinear_alignment_check(p1 : Part, p2 : Part):
	var i : int = 0
	var b_array_1 : Array[Vector3] = [p1.global_transform.basis.x,
	p1.global_transform.basis.y, p1.global_transform.basis.z]
	var b_array_2 : Array[Vector3] = [p2.global_transform.basis.x,
	p2.global_transform.basis.y]
	var is_aligned_1 : bool = false
	var is_aligned_2 : bool = false
	
	#at least one of 3 vectors should evaluate to (almost) 1
	while i < b_array_1.size():
		#this is as precise as 32bit floats can do
		if abs(b_array_1[i].dot(b_array_2[0])) > 0.999999:
			is_aligned_1 = true
			break
		i = i + 1
	
	i = 0
	while i < b_array_1.size():
		if abs(b_array_1[i].dot(b_array_2[1])) > 0.999999:
			is_aligned_2 = true
			break
		i = i + 1
	return is_aligned_1 and is_aligned_2

#p1: part to be affected, p2: part to align to
static func part_exact_alignment(p1 : Basis, p2 : Basis):
	var i : int = 0
	var j : int = 0
	var b_array_1 : Array[Vector3] = [p1.x, p1.y, p1.z]
	var b_array_2 : Array[Vector3] = [p2.x, p2.y, p2.z]

	#at least one of 3 vectors should evaluate to 1
	while i < b_array_1.size():
		while j < b_array_2.size():
			var dot : float = b_array_1[i].dot(b_array_2[j])
			if abs(dot) > 0.95:
				b_array_1[i] = b_array_2[j] * sign(dot)
			j = j + 1
		j = 0
		i = i + 1

	#assign to p1
	p1.x = b_array_1[0]
	p1.y = b_array_1[1]
	p1.z = b_array_1[2]
	return p1


#return whether a number contains an odd or even amount of snap increments
static func is_odd_with_snap_size(input : float, snap_increment : float):
	var term_1 : float = input/snap_increment
	var term_2 : int = roundf(term_1)
	
	return term_2 % 2 != 0
	
	


#assuming part rotation is rectalinear
static func get_side_lengths_local(part_scale : Vector3, part_rotation : Basis):
	return abs(part_rotation * part_scale)
