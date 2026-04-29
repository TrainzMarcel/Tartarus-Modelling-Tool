@tool
extends MeshInstance3D
@export var print_surfaces : bool = false:
	set(value):
		var surfaces : int = mesh.get_surface_count()
		var sum : int = 0
		for surface in surfaces:
			var count = mesh.surface_get_arrays(surface)[0].size()
			print("surface " + str(surface) + " vert count: ", count, "   mats: ", mesh.get_meta("material_names")[surface], " color: ", mesh.get_meta("colors")[surface])
			sum = sum + count
		
		print("total: ", str(sum))
"TODO"#move this to mesh utils
