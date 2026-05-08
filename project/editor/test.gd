@tool
extends MeshInstance3D
@export var print_surfaces : bool = false:
	set(value):
		MeshUtils.debug_print_mesh_surfaces(self.mesh)
