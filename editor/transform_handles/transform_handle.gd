@tool
extends StaticBody3D
class_name TransformHandle

"TODO"#i would like to have transform handles occupy about
#1/4th of the screenspace at all distances from the handles
#maybe one day i will reprogram these to work using a subviewport
enum DirectionTypeEnum
{
	axis_move,
	plane_move,
	axis_rotate,#rotate around center of selection TODO later add tool to move rotational pivot
	
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
@export var handle_follow_abb_surface : bool = false

#material to be used
@export var material : Material
@export var color_default : Color
#brighter color
@export var color_drag : Color

#all meshes that are part of this handle
@export var mesh_array : Array[MeshInstance3D]
#all colliders that are part of this handle
@export var collider_array : Array[CollisionShape3D]


func _ready():
	for i in mesh_array:
		i.material_override = material
		i.set_instance_shader_parameter("color", color_default)

func automated_setup():
		#rotation MUST be untouched for this to work properly, only rotate and move child nodes into place
		quaternion = Quaternion()
		
		#layer and mask MUST be set to 2
		collision_mask = SnapUtils.calculate_collision_layer([2])
		collision_layer = SnapUtils.calculate_collision_layer([2])
		
		var child_nodes = get_children()
		collider_array.clear()
		for i in child_nodes:
			if i is CollisionShape3D:
				collider_array.append(i)
				i.disabled = true
		mesh_array.clear()
		for j in child_nodes:
			if j is MeshInstance3D:
				mesh_array.append(j)
		
		if name.to_lower().contains("x"):
			direction_vector = Vector3.RIGHT
			color_default = Color(0.58, 0, 0)
			color_drag = Color(1, 0, 0)
		elif name.to_lower().contains("y"):
			direction_vector = Vector3.UP
			color_default = Color(0, 0.58, 0)
			color_drag = Color(0, 1, 0)
		elif name.to_lower().contains("z"):
			direction_vector = Vector3.BACK
			color_default = Color(0, 0, 0.58)
			color_drag = Color(0, 0, 1)
		if name.contains("2"):
			direction_vector = -direction_vector
		
		if self.material == null:
			material = ShaderMaterial.new()
			"TODO"#not sure if this works, will test tomorrow
			material.shader = preload("res://editor/transform_handles/render_over.gdshader")
