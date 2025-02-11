extends RefCounted
class_name SnapUtils


static func average_position_part(input : Array[Part]):
	var sum : Vector3 = Vector3.ZERO
	for i in input:
		sum = sum + i.global_position
	return sum / input.size()


#if anybody is confused about this calculation
#https://docs.godotengine.org/en/4.1/tutorials/physics/physics_introduction.html#code-example
static func calculate_collision_layer(input_layers_to_enable : Array[int]):
	if not input_layers_to_enable.is_empty():
		var sum : int = 0
		for i in input_layers_to_enable:
			sum = int(sum + pow(2, i - 1))
		
		return sum


#input is meant to be the part-to-be-rotated's basis
"TODO"#unit test and make above comment better
#res://editor/debug_and_unit_tests/unit_test.gd
static func snap_rotation(input : Basis, ray_result : Dictionary):
	var input_2 : Basis = ray_result.collider.basis
	var i : int = 0
	var closest_vector_1 : Vector3
	var closest_vector_2 : Vector3
	var highest_dot : float = 0
	
#find closest matching basis vector of dragged_part to normal vector using absolute dot product
#(the dot product farthest from 0)
	while i < 3:
		var j : int = 0
		while j < 3:
			#remember, 1 = parallel vectors, 0 = perpendicular, -1 = opposing vectors
			if abs(input[i].dot(input_2[j])) > abs(highest_dot):
				highest_dot = input[i].dot(input_2[j])
				closest_vector_1 = input[i]
				closest_vector_2 = input_2[j]
			j = j + 1
		i = i + 1
	
	if is_equal_approx(highest_dot, 0.0):
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
	var r_dict_2 = find_closest_vector_abs(rotated_basis, vec_1, true)
	angle = (r_dict_2.vector * sign(r_dict_2.dot)).angle_to(vec_1)
	cross_product = (r_dict_2.vector * sign(r_dict_2.dot)).cross(vec_1)
	
	if cross_product.length() == 0:
		return input
	
	#the part should now hopefully be aligned and ready for linear snapping
	return rotated_basis.rotated(cross_product.normalized(), angle).orthonormalized()


#planar positional snap, returns global vector3 position of dragged part
static func snap_position(ray_result : Dictionary,
dragged_part : Part,
hovered_part : Part,
selected_parts_abb : ABB,
drag_offset : Vector3,
positional_snap_increment : float,
snapping_active : bool):
	
	var normal = ray_result.normal
	
	#first find closest basis vectors to normal vector and use that to determine which side length of the abb to use
	var r_dict_1 = SnapUtils.find_closest_vector_abs(dragged_part.basis, normal, true)
	var side_length = selected_parts_abb.extents[r_dict_1.index]
	
	#inverse for transforming everything to local space of the hovered part
	var inverse = hovered_part.global_transform.inverse()
	#transformed local variables
	var ray_result_local_position : Vector3 = inverse * ray_result.position
	var normal_local : Vector3 = inverse.basis * normal
	var drag_offset_local : Vector3 = inverse.basis * drag_offset
	
	#normal "bump"
	drag_offset_local = normal_local * (side_length * 0.5) + (drag_offset_local - drag_offset_local.dot(normal_local) * normal_local)
	var result_local = ray_result_local_position + drag_offset_local
	var r_dict_2 = SnapUtils.find_closest_vector_abs(Basis.IDENTITY, normal_local, true)
	
	
	#if one parts side length is even and one is odd
	#add half of a snap increment to offset it away
	var dragged_part_local : Basis = inverse.basis * dragged_part.basis
	var dragged_part_side_lengths_local : Vector3 = SnapUtils.get_side_lengths_local(dragged_part.part_scale, dragged_part_local)
	#print(dragged_part_side_lengths_local)
	var i : int = 0
	
	if snapping_active:
		while i < 3:
			#dont snap normal direction, only planar directions
			if abs(normal_local.dot(Basis.IDENTITY[i])) > 0.9:
				i = i + 1
				continue
			
			result_local[i] = snapped(result_local[i], positional_snap_increment)
			var side_1_odd : bool = SnapUtils.is_odd_with_snap_size(hovered_part.part_scale[i], positional_snap_increment)
			var side_2_odd : bool = SnapUtils.is_odd_with_snap_size(dragged_part_side_lengths_local[i], positional_snap_increment)
			if side_1_odd != side_2_odd:
				result_local[i] = result_local[i] + positional_snap_increment * 0.5
			i = i + 1
	
	#apply this to dragged_part, 
	"TODO"#make this return a transform which can be applied to everything
	"TODO"#delete all relative returns in this program
	"TODO"#make selection snap by the closest corner of ray_result.position
	var relative : Vector3 = (hovered_part.global_transform * result_local) - dragged_part.position
	return {absolute = hovered_part.global_transform * result_local,
	relative = relative}
	
	#i = 0
	#while i < selected_parts.size():
	#	selected_parts[i].global_position = dragged_part.global_position + main_offset[i]
	#	selection_box_array[i].global_transform = selected_parts[i].global_transform


#returns index of most parallel vector to target vector, no matter if its pointing the opposite way or not
#update; removed type of search_array to allow basis as parameter
static func find_closest_vector_abs(search_array, target : Vector3, is_search_array_basis : bool):
	var highest_dot : float
	var closest_vec_index : int
	var closest_vec : Vector3
	
	var i : int = 0
	var j : int = 0
	if is_search_array_basis:
		j = 3
	else:
		j = search_array.size()
	
	while i < j:
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
	var p1_basis : Basis = p1.global_transform.basis
	var p2_basis : Basis = p2.global_transform.basis
	var is_aligned_1 : bool = false
	var is_aligned_2 : bool = false
	
	#at least one of 3 vectors should evaluate to (almost) 1
	while i < 3:
		#this is as precise as 32bit floats can do
		if abs(p1_basis[i].dot(p2_basis[0])) > 0.999999:
			is_aligned_1 = true
			break
		i = i + 1
	
	i = 0
	while i < 3:
		if abs(p1_basis[i].dot(p2_basis[1])) > 0.999999:
			is_aligned_2 = true
			break
		i = i + 1
	return is_aligned_1 and is_aligned_2

#p1: part to be affected, p2: part to align to
static func part_exact_alignment(p1 : Basis, p2 : Basis):
	var i : int = 0
	var j : int = 0
	var p1_mutated : Basis = Basis(p1)
	
	#at least one of 3 vectors should evaluate to 1
	while i < 3:
		while j < 3:
			var dot : float = p1[i].dot(p2[j])
			if abs(dot) > 0.95:
				p1_mutated[i] = p2[j] * sign(dot)
			j = j + 1
		j = 0
		i = i + 1
	
	return p1_mutated


#return whether a number contains an odd or even amount of snap increments
static func is_odd_with_snap_size(input : float, snap_increment : float):
	var term_1 : float = input / snap_increment
	var term_2 : int = int(roundf(term_1))
	return term_2 % 2 != 0


#assuming part rotation is rectilinear
static func get_side_lengths_local(part_scale : Vector3, part_rotation : Basis):
	return abs(part_rotation * part_scale)


"TODO"#clean up (maybe)
static func calculate_extents(abb : ABB, rotation_origin_part : Part, parts : Array[Part]):
	abb.transform = rotation_origin_part.global_transform
	abb.extents = Vector3.ZERO
	
	var i : int = 0
	while i < parts.size():
		var corners : Array[Vector3] = []
		for x in [-0.5, 0.5]:
			for y in [-0.5, 0.5]:
				for z in [-0.5, 0.5]:
					var corner = parts[i].global_transform.origin
					corner = corner + parts[i].global_transform.basis.x * (x * parts[i].part_scale.x)
					corner = corner + parts[i].global_transform.basis.y * (y * parts[i].part_scale.y)
					corner = corner + parts[i].global_transform.basis.z * (z * parts[i].part_scale.z)
					corners.append(corner)
		
		for j in corners:
			abb.expand(j)
		i = i + 1
	
	return abb
