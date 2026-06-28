@tool
extends MeshInstance3D
@export var print_surfaces : bool = false:
	set(value):
		MeshUtils.debug_print_mesh_surfaces(self.mesh)

@export var test_surfaces : bool = false:
	set(value):
		var test_material : StandardMaterial3D = StandardMaterial3D.new()
		var duration : int = 1
		var i : int = 0
		var surfaces = mesh.get_surface_count()
		test_material.albedo_color = Color.RED
		test_material.stencil_mode = BaseMaterial3D.STENCIL_MODE_XRAY
		test_material.stencil_color = Color.RED
		
		while i < surfaces:
			mesh.surface_set_material(i, test_material)
			await get_tree().create_timer(duration).timeout
			mesh.surface_set_material(i, null)
			print("surface ", i, "!")
			i = i + 1
		print("test over")
		
