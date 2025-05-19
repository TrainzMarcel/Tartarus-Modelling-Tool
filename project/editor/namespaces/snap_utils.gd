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
	var final : Basis = rotated_basis.rotated(cross_product.normalized(), angle).orthonormalized()
	return final


#planar positional snap, returns global vector3 position of dragged part
static func snap_position(
	ray_result : Dictionary,
	dragged_part : Part,
	hovered_part : Part,
	selected_parts_abb : ABB,
	positional_snap_increment : float,
	snapping_active : bool
	):
	
	
	var normal : Vector3 = ray_result.normal
	
	#first find closest basis vectors to normal vector and use that to determine which side length of the abb to use
	var r_dict_1 : Dictionary = SnapUtils.find_closest_vector_abs(selected_parts_abb.transform.basis, normal, true)
	var side_length : float = selected_parts_abb.extents[r_dict_1.index]
	
	#inverse for transforming everything to local space of the hovered part
	var inverse : Transform3D = hovered_part.global_transform.inverse()
	
	#transformed local variables
	var ray_result_local_position : Vector3 = inverse * ray_result.position
	var normal_local : Vector3 = inverse.basis * normal
	"TODO"#this is terrible
	#drag_offset needs to be abstracted much better
	#utility functions should always get everything passed in by parameters
	var drag_offset_local : Vector3 = inverse.basis * WorkspaceManager.drag_offset
	
	#normal "bump" (to prevent dragged part from intersecting hovered part when dragging)
	"TODO"#make this into a function (like get_surface_height_by_unit_vector())
	var drag_offset_local_planar = drag_offset_local - (drag_offset_local.dot(normal_local) * normal_local)
	var drag_offset_local_normal = normal_local * (side_length * 0.5)
	
	"TODO"#make normal_local * (side_length * 0.5) into a function (like get_surface_height_by_unit_vector())
	#reassign this value with the new normal height (again to prevent intersecting)
	drag_offset_local = drag_offset_local_normal + drag_offset_local_planar
	
	#local coordinate of dragged part
	var result_local : Vector3 = ray_result_local_position + drag_offset_local
	
	#if one parts side length is even and one is odd
	#add half of a snap increment to offset it away
	var dragged_part_local : Basis = inverse.basis * dragged_part.basis
	var dragged_part_scale_local : Vector3 = SnapUtils.get_scale_local(dragged_part.part_scale, dragged_part_local)
	
	
	"TODO"#make selection snap by the closest corner of ray_result.position
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
			
			#3. new var snap(d. part corner - canvas part corner)
			result_local_snap[i] = (result_local_snap[i] + hovered_corner) - dragged_corner
			result_local_snap[i] = snapped(result_local_snap[i], positional_snap_increment)
			result_local_snap[i] = (result_local_snap[i] - hovered_corner) + dragged_corner
			
			if i == 2:
				print("Z ---------------------------------------------------------------------------")
				print("dragged scale            ", dragged_part_scale_local)
				print("hovered scale            ", hovered_part.part_scale)
				print("dragged_corner           ", dragged_corner)
				print("hovered_corner           ", hovered_corner)
				print("result local snap        ", result_local_snap[i])
			#4. return this value
			
			#result_local_snap[i] = snapped(result_local_snap[i], positional_snap_increment)
			
			i = i + 1
	
	#transform to global space and apply this to dragged_part
	var result : Vector3 = hovered_part.global_transform * result_local_snap
	return result


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
"TODO"#rename this to s
static func get_scale_local(part_scale : Vector3, part_rotation : Basis):
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
