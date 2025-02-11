@tool
extends StaticBody3D
class_name TransformHandle


enum DirectionTypeEnum
{
	axis_move,
	plane_move,
	axis_rotate,#rotate around center of selection TODO later add tool to move rotational pivot
	axis_scale
}


@export var set_up : bool = false:
	set(value):
		automated_setup()

@export var identifier : String = ""
@export var direction_vector : Vector3
@export var direction_type : DirectionTypeEnum = DirectionTypeEnum.axis_move

#this setting makes it so that the transform handle gets moved out to the face it represents
#note that im not implementing this for local transform mode where the handles may not align with any face
#this is needed for the scaling tool im making
@export var handle_force_follow_abb_surface : bool = false

#material to be used
@export var material : Material
@export var color_default : Color
#brighter color
@export var color_drag : Color
#brightest color
@export var color_hover : Color

#all meshes that are part of this handle
@export var mesh_array : Array[MeshInstance3D]
#all colliders that are part of this handle
@export var collider_array : Array[CollisionShape3D]


func automated_setup():
		#rotation MUST be untouched for this to work properly, only rotate and move child nodes into place
		quaternion = Quaternion()
		material = preload("res://editor/transform_handles/transform_handle_material.tres").duplicate()
		
		var child_nodes = get_children()
		collider_array.clear()
		for i in child_nodes:
			if i is CollisionShape3D:
				collider_array.append(i)
				i.disabled = true
		mesh_array.clear()
		var intensity_default : float = 0.8
		var intensity_drag : float = 0.58
		var intensity_hover : float = 1
		
		if name.to_lower().contains("x"):
			direction_vector = Vector3.RIGHT
			color_default = Color(intensity_default, 0, 0)
			color_drag = Color(intensity_drag, 0, 0)
			color_hover = Color(intensity_hover, 0, 0)
		elif name.to_lower().contains("y"):
			direction_vector = Vector3.UP
			color_default = Color(0, intensity_default, 0)
			color_drag = Color(0, intensity_drag, 0)
			color_hover = Color(0, intensity_hover, 0)
		elif name.to_lower().contains("z"):
			direction_vector = Vector3.BACK
			color_default = Color(0, 0, intensity_default)
			color_drag = Color(0, 0, intensity_drag)
			color_hover = Color(0, 0, intensity_hover)
		if name.contains("2"):
			direction_vector = -direction_vector
		
		for j in child_nodes:
			if j is MeshInstance3D:
				mesh_array.append(j)
				j.material_override = material
				j.material_override.albedo_color = color_default
