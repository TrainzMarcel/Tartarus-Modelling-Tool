extends RefCounted
class_name SnapUtils
"TODO"#review all functions and maximize their numerical stability


#take input from transform handle and return a global-space vector3 to apply
static func transform_handle_snap_position(input : float, handle_unit_vector_global : Vector3, initial_position : Vector3, positional_snap_increment : float, snapping_active : bool):
	if snapping_active:
		return (snappedf(input, positional_snap_increment) * handle_unit_vector_global) + initial_position
	else:
		return (input * handle_unit_vector_global) + initial_position


#take input from transform handle and return a global-space basis to apply
static func transform_handle_snap_rotation(input_angle : float, input_basis : Basis, handle_unit_vector_global : Vector3, rotational_snap_increment : float, snapping_active : bool):
	if snapping_active:
		return input_basis.rotated(handle_unit_vector_global, snappedf(input_angle, rotational_snap_increment))
	else:
		return input_basis.rotated(handle_unit_vector_global, input_angle)


#dont move when minimum distance is reached
static func scaling_clamp(input : float, handle_unit_vector_local : Vector3, initial_extents : Vector3, positional_snap_increment : float, snapping_active : bool):
	#scaling vector index
	var index : int = max_axis_index_abs(handle_unit_vector_local)
	var handle_sign : int = sign(handle_unit_vector_local[index])
	var side_length : float = initial_extents[index] + input# * handle_sign
	
	
	if side_length < positional_snap_increment:
		input = -initial_extents[index] + positional_snap_increment
	
	return input


#take input from transform handle and return a local-space scale vector3 to apply
static func transform_handle_snap_scale(input : float,
	handle_unit_vector_local : Vector3,
	initial_extents : Vector3,
	positional_snap_increment : float,
	snapping_active : bool,
	is_ctrl_pressed : bool,
	is_shift_pressed : bool
	):
	
	#scaling vector index
	var index : int = max_axis_index_abs(handle_unit_vector_local)
	var handle_sign : int = sign(handle_unit_vector_local[index])
	
	
	#snap
	if snapping_active:
		input = snappedf(input, positional_snap_increment)
	
	
	#ctrl: scale both sides with no movement
	if is_ctrl_pressed:
		input = input * 2
	
	var result : Vector3 = initial_extents + input * handle_sign * handle_unit_vector_local
	
	if is_shift_pressed:
		var percentage = (initial_extents[index] + input) / initial_extents[index]
		result = initial_extents * percentage
	
	if is_ctrl_pressed and not is_shift_pressed:
		result[index] = initial_extents[index] + input# * handle_sign
	
	
	#clamp minimum size
	if snapping_active:
		result[index] = max(result[index], positional_snap_increment)
	else:
		#clamp to 0 if snapping is off
		result[index] = max(result[index], 0)
	
	return result


#input is meant to be the part-to-be-rotated's basis
"TODO"#unit test and make above comment better
static func drag_snap_rotation_to_hovered(input : Basis, ray_result : Dictionary):
	var hovered_part : Part = ray_result.collider
	var input_2 : Basis = hovered_part.basis
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
	#print(rad_to_deg(angle))
	
	var cross_product : Vector3 = (closest_vector_1 * sign(dot_1)).cross(closest_vector_2)
	var rotated_basis : Basis = input
	
	#if cross product returns empty vector, dont modify basis
	if cross_product.length() != 0:
		rotated_basis = rotated_basis.rotated(cross_product.normalized(), angle).orthonormalized()
	
	
	
#find basis vector on canvas part which is not equal to closest_vector_2 or inverted closest_vector_2
#use x vector, else use y vector
	var vec_1 : Vector3
		#remember, 1 = parallel vectors, 0 = perpendicular, -1 = opposing vectors
		#the closer to 0 the better in this case
	if abs(hovered_part.basis.x.dot(closest_vector_2)) < abs(hovered_part.basis.y.dot(closest_vector_2)):
		#canvas.basis.x is closer to 0
		vec_1 = hovered_part.basis.x
	else:
		#canvas.basis.y is closer to 0
		vec_1 = hovered_part.basis.y
	
	
#iterate over all 3 vectors and again find closest absolute dot product
#find signed angle between that and the closest vector and rotate accordingly
	var r_dict_2 = find_closest_vector_abs(rotated_basis, vec_1, true)
	angle = (r_dict_2.vector * sign(r_dict_2.dot)).angle_to(vec_1)
	cross_product = (r_dict_2.vector * sign(r_dict_2.dot)).cross(vec_1)
	
	if cross_product.length() == 0:
		return input
	
	#the part should now hopefully be aligned and ready for linear snapping
	var final : Basis = rotated_basis.rotated(cross_product.normalized(), angle).orthonormalized()
	return final


#planar positional snap, returns global vector3 position of dragged part
static func drag_snap_position_to_hovered(
	ray_result : Dictionary,
	dragged_part : Part,
	selected_parts_abb : ABB,
	drag_offset : Vector3,
	positional_snap_increment : float,
	snapping_active : bool
	):
	
	
	var hovered_part : Part = ray_result.collider
	var normal : Vector3 = ray_result.normal
	
	#first find closest basis vectors to normal vector and use that to determine which side length of the abb to use
	var r_dict_1 : Dictionary = SnapUtils.find_closest_vector_abs(selected_parts_abb.transform.basis, normal, true)
	#abb_normal_length is used to move the selection up until the bottom surface meets with the "canvas" surface that is being dragged onto
	var abb_normal_length : float = selected_parts_abb.extents[r_dict_1.index]
	
	#inverse for transforming everything to local space of the hovered part
	var inverse : Transform3D = hovered_part.global_transform.inverse()
	
	#transformed local variables
	var ray_result_local_position : Vector3 = inverse * ray_result.position
	var normal_local : Vector3 = inverse.basis * normal
	var drag_offset_local : Vector3 = inverse.basis * drag_offset
	var dragged_part_local : Basis = inverse.basis * dragged_part.basis
	var dragged_part_scale_local : Vector3 = SnapUtils.get_scale_local(dragged_part.part_scale, dragged_part_local)
	
	
	#normal "bump" (to prevent dragged part from intersecting hovered part when dragging)
	"TODO"#make this into a function (like get_surface_height_by_unit_vector())
	"TODO"#make normal_local * (side_length * 0.5) into a function (like get_surface_height_by_unit_vector())
	var drag_offset_local_normal = normal_local * (abb_normal_length * 0.5)
	var drag_offset_local_planar = drag_offset_local - (drag_offset_local.dot(normal_local) * normal_local)
	
	
	#reassign this value with the new normal height (again to prevent intersecting)
	drag_offset_local = drag_offset_local_normal + drag_offset_local_planar
	
	#local coordinate of dragged part
	var result_local : Vector3 = ray_result_local_position + drag_offset_local
	
	
	#make selection snap by the closest corner of dragged part to ray_result.position
	var result_local_snap : Vector3 = result_local
	if snapping_active:
		
		var i : int = 0
		while i < 3:
			#dont snap normal direction, only planar directions
			if abs(normal_local.dot(Basis.IDENTITY[i])) > 0.9:
				i = i + 1
				continue
			
			#1. get closest corner of hovered part to ray_result_local_position
			#or more specifically if its on the positive or negative side of the current vector
			var hovered_corner_sign : float = -signf(ray_result_local_position[i])
			var hovered_corner : float = hovered_corner_sign * hovered_part.part_scale[i] * 0.5
			
			#2. get vector of dragged corner for dragged part
			var dragged_corner_sign : float = signf(drag_offset_local[i])
			var dragged_corner : float = dragged_corner_sign * dragged_part_scale_local[i] * 0.5
			var dragged_corner_position : float = dragged_corner + result_local[i]
			
			#3. new var snap(dragged part corner - canvas part corner)
			result_local_snap[i] = (result_local_snap[i] + hovered_corner) - dragged_corner
			result_local_snap[i] = snapped(result_local_snap[i], positional_snap_increment)
			result_local_snap[i] = (result_local_snap[i] - hovered_corner) + dragged_corner
			
			
			
			#if i == 2:
			#	print("Z ---------------------------------------------------------------------------")
			#	print("dragged scale            ", dragged_part_scale_local)
			#	print("hovered scale            ", hovered_part.part_scale)
			#	print("dragged_corner           ", dragged_corner)
			#	print("hovered_corner           ", hovered_corner)
			#	print("result local snap        ", result_local_snap)
			#	print("result local             ", result_local)
			#4. return this value
			i = i + 1
	
	
	#transform to global space and apply this to dragged_part
	var result : Vector3 = hovered_part.global_transform * result_local_snap
	print("---------------------------------_")
	print("dragged_part pos  ", dragged_part.position)
	print("result            ", result)
	print("result_local_snap ", result_local_snap)
	print("result_local      ", result_local)
	print("drag_offset_local ", drag_offset_local)
	print("bounding box size ", selected_parts_abb.extents)
	return result


static func max_axis_index_abs(vector : Vector3):
	#scaling vector index
	var index : int = 0
	if abs(vector.x) > 0:
		return 0
	elif abs(vector.y) > 0:
		return 1
	elif abs(vector.z) > 0:
		return 2

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


#automatically flips vector if its opposing target
static func find_closest_vector(search_array, target : Vector3, is_search_array_basis : bool):
	var return_dict = find_closest_vector_abs(search_array, target, is_search_array_basis)
	if return_dict.vector.dot(target) < 0:
		return_dict.vector = -return_dict.vector
	
	return return_dict


static func part_rectilinear_alignment_check(p1 : Basis, p2 : Basis):
	var i : int = 0
	var is_aligned_1 : bool = false
	var is_aligned_2 : bool = false
	
	#at least one of 3 vectors should evaluate to (almost) 1
	while i < 3:
		#this is as precise as 32bit floats can do
		if abs(p1[i].dot(p2[0])) > 0.999999:
			is_aligned_1 = true
			break
		i = i + 1
	
	i = 0
	while i < 3:
		if abs(p1[i].dot(p2[1])) > 0.999999:
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


static func part_average_position(input : Array[Part]):
	var sum : Vector3 = Vector3.ZERO
	for i in input:
		sum = sum + i.global_position
	return sum / input.size()


#return whether a number contains an odd or even amount of snap increments
static func is_odd_with_snap_size(input : float, snap_increment : float):
	var term_1 : float = input / snap_increment
	var term_2 : int = int(roundf(term_1))
	return term_2 % 2 != 0


#assuming part rotation is rectilinear
static func get_scale_local(part_scale : Vector3, part_rotation : Basis):
	return abs(part_rotation * part_scale)


"TODO"#clean up (maybe)
static func calculate_extents(abb : ABB, rotation_origin_part : Part, parts : Array[Part]):
	abb.transform = rotation_origin_part.transform
	abb.extents = Vector3.ZERO
	
	var i : int = 0
	while i < parts.size():
		var corners : Array[Vector3] = []
		for x in [-0.5, 0.5]:
			for y in [-0.5, 0.5]:
				for z in [-0.5, 0.5]:
					var corner = parts[i].transform.origin
					corner = corner + parts[i].transform.basis.x * (x * parts[i].part_scale.x)
					corner = corner + parts[i].transform.basis.y * (y * parts[i].part_scale.y)
					corner = corner + parts[i].transform.basis.z * (z * parts[i].part_scale.z)
					corners.append(corner)
		
		for j in corners:
			abb.expand(j)
		i = i + 1
	
	return abb


#if anybody is confused about this calculation
#https://docs.godotengine.org/en/4.1/tutorials/physics/physics_introduction.html#code-example
static func calculate_collision_layer(input_layers_to_enable : Array[int]):
	if not input_layers_to_enable.is_empty():
		var sum : int = 0
		for i in input_layers_to_enable:
			sum = int(sum + pow(2, i - 1))
		
		return sum
