@tool
extends MeshInstance3D
class_name SelectionBox


#debug
@export var debug_update : bool = false:
	set(val):
		debug_update = false
		box_update()


@export var box_scale : Vector3 = Vector3(0.4, 0.2, 0.8):
	set(val):
		box_scale = val
		box_update()


@export var box_thickness : float = 0.015:
	set(val):
		box_thickness = val
		box_update()


func material_highlighter():
	material_override = preload("res://editor/classes/selection_box/highlight_mat.res")


func material_regular():
	material_override = preload("res://editor/classes/selection_box/selection_box_mat.res")


func material_regular_color(color : Color):
	#i have no idea what subresources this material could have but without them, the color appears very pale
	material_override = preload("res://editor/classes/selection_box/selection_box_mat.res").duplicate(true)
	material_override.albedo_color = color
	material_override.emission = color

#"TODO"#pre-generate the mesh then edit with meshdatatool
#func _ready()



func draw_quad(i_mesh : ImmediateMesh, vec_a : Vector3, vec_b : Vector3, vec_c : Vector3, vec_d : Vector3, normal : Vector3):
	i_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	i_mesh.surface_set_normal(normal)
	i_mesh.surface_add_vertex(vec_a)
	i_mesh.surface_set_normal(normal)
	i_mesh.surface_add_vertex(vec_b)
	i_mesh.surface_set_normal(normal)
	i_mesh.surface_add_vertex(vec_c)
	i_mesh.surface_end()
	i_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	i_mesh.surface_set_normal(normal)
	i_mesh.surface_add_vertex(vec_c)
	i_mesh.surface_set_normal(normal)
	i_mesh.surface_add_vertex(vec_b)
	i_mesh.surface_set_normal(normal)
	i_mesh.surface_add_vertex(vec_d)
	i_mesh.surface_end()


func draw_frame(i_mesh : ImmediateMesh, box_scale : Vector3, direction : Basis, box_thickness : float, mode = 0):
	#direction = Basis(Vector3.RIGHT, Vector3.UP, Vector3.FORWARD)
	#box scale corresponds directly to direction
	var half_box_thickness = box_thickness * 0.5
	var outer : Array[Vector3] = []
	var inner : Array[Vector3] = []
	var recessed : Array[Vector3] = []
	var original_vec : Vector3
	var vec : Vector3
	
	match mode:
		#generate z surfaces
		0:
			original_vec = direction.x * box_scale.x * 0.5
			original_vec = original_vec + direction.y * box_scale.y * 0.5
			original_vec = original_vec + direction.z * box_scale.z * 0.5
		#generate x surfaces
		1:
			original_vec = direction.x * box_scale.z * 0.5
			original_vec = original_vec + direction.y * box_scale.y * 0.5
			original_vec = original_vec + direction.z * box_scale.x * 0.5
		#generate y surfaces
		2:
			original_vec = direction.x * box_scale.x * 0.5
			original_vec = original_vec + direction.y * box_scale.z * 0.5
			original_vec = original_vec + direction.z * box_scale.y * 0.5
	
	
	vec = original_vec + (direction.x * half_box_thickness) + (direction.y * half_box_thickness)
	vec = vec + direction.z * half_box_thickness
	outer.append(vec)
	vec.x = -vec.x
	outer.append(vec)
	vec.y = -vec.y
	outer.append(vec)
	vec.x = -vec.x
	outer.append(vec)
	
	
	vec = original_vec + (-direction.x * half_box_thickness) + (-direction.y * half_box_thickness)
	vec = vec + direction.z * half_box_thickness
	inner.append(vec)
	vec.x = -vec.x
	inner.append(vec)
	vec.y = -vec.y
	inner.append(vec)
	vec.x = -vec.x
	inner.append(vec)
	
	vec = original_vec + (-direction.x * half_box_thickness) + (-direction.y * half_box_thickness)
	vec = vec + -direction.z * half_box_thickness
	recessed.append(vec)
	vec.x = -vec.x
	recessed.append(vec)
	vec.y = -vec.y
	recessed.append(vec)
	vec.x = -vec.x
	recessed.append(vec)
	
	#rotate position vectors to make y and x sides
	if mode == 1:
		var i = 0
		while i != inner.size():
			inner[i] = inner[i].rotated(Vector3.UP, PI * 0.5)
			outer[i] = outer[i].rotated(Vector3.UP, PI * 0.5)
			recessed[i] = recessed[i].rotated(Vector3.UP, PI * 0.5)
			i = i + 1
		direction = direction.rotated(Vector3.UP, PI * 0.5)
	elif mode == 2:
		var i = 0
		while i != inner.size():
			inner[i] = inner[i].rotated(Vector3.RIGHT, PI * 0.5)
			outer[i] = outer[i].rotated(Vector3.RIGHT, PI * 0.5)
			recessed[i] = recessed[i].rotated(Vector3.RIGHT, PI * 0.5)
			i = i + 1
		direction = direction.rotated(Vector3.RIGHT, PI * 0.5)
	
	
	#draw flat part of frame
	draw_quad(i_mesh, outer[0], outer[1], inner[0], inner[1], direction.z)
	draw_quad(i_mesh, outer[1], outer[2], inner[1], inner[2], direction.z)
	draw_quad(i_mesh, outer[2], outer[3], inner[2], inner[3], direction.z)
	draw_quad(i_mesh, outer[3], outer[0], inner[3], inner[0], direction.z)
	
	#draw inner part of frame
	draw_quad(i_mesh, inner[0], inner[1], recessed[0], recessed[1], -direction.y)
	draw_quad(i_mesh, inner[1], inner[2], recessed[1], recessed[2], direction.x)
	draw_quad(i_mesh, inner[2], inner[3], recessed[2], recessed[3], direction.y)
	draw_quad(i_mesh, inner[3], inner[0], recessed[3], recessed[0], -direction.x)


#most important function
func box_update():
	var i_mesh : ImmediateMesh
	if self.mesh != ImmediateMesh:
		i_mesh = ImmediateMesh.new()
		self.mesh = i_mesh
	else:
		i_mesh = self.mesh
	
	
	var box_half_thickness = box_thickness * 0.5
	
	var i : int = 0
	i_mesh.clear_surfaces()
	while i != 3:
		draw_frame(i_mesh, box_scale, Basis(-Vector3.RIGHT, Vector3.UP, -Vector3.FORWARD), box_thickness, i)
		draw_frame(i_mesh, box_scale, Basis(Vector3.RIGHT, Vector3.UP, Vector3.FORWARD), box_thickness, i)
		i = i + 1
