extends RefCounted
class_name OBJExporter

#static var tree_access : Node

#static func initialize(tree : Node):
#	tree_access = tree

#signal export_started
#signal export_progress_updated(surf_idx, progress_value)
#signal export_completed(object_file, material_file)

# Dump given mesh to obj file
static func save_mesh_to_files(mesh: ArrayMesh, file_path: String, object_name: String):
	# Based on:
	# https://github.com/fractilegames/godot-obj-export/blob/main/objexport.gd
	# https://github.com/mohammedzero43/CSGExport-Godot/blob/master/addons/CSGExport/csgexport.gd
	# Blank material, used when no material is assigned to mesh
	#obj file content
	var output : String = "mtllib " + object_name + ".mtl\no " + object_name + "\n"
	const stream_length : int = 4096
	#mtl file content
	var mat_output : String = ""
	
	if not file_path.ends_with("/"):
		file_path += "/"
	
	
	var file_obj : FileAccess = FileAccess.open(file_path + object_name + ".obj", FileAccess.WRITE)
	var file_mtl : FileAccess = FileAccess.open(file_path + object_name + ".mtl", FileAccess.WRITE)
	var stream_data : Callable = func(output : String):
		if output.length() > stream_length:
			print("writing " + str(output.length()) + " characters")
			var error : bool = file_obj.store_string(output)
			assert(error)
			file_obj.flush()
			return ""
		return output
	
	#emit_signal("export_started")
	
	# Write all surfaces in mesh (obj file indices start from 1)
	var index_base = 1
	for s in range(mesh.get_surface_count()):
		var mat_check = mesh.surface_get_material(s)
		var mat : StandardMaterial3D = mesh.surface_get_material(s)
		var has_uv = false
		var has_n = false
		var surface = mesh.surface_get_arrays(s)
		
		#protect against issues
		if mat_check != null and mat_check is StandardMaterial3D:
			mat = mat_check
		else:
			var blank_material = StandardMaterial3D.new()
			blank_material.resource_name = "BlankMaterial"
			mat = blank_material
		
		
		if surface[ArrayMesh.ARRAY_INDEX] == null:
			push_error("Saving only supports indexed meshes for now, skipping non-indexed surface " + str(s))
			continue
		
		
		output += "g surface" + str(s) + "\n"
		
		for v in surface[ArrayMesh.ARRAY_VERTEX]:
			output += " ".join(["v", str(v.x), str(v.y), str(v.z) + "\n"])
			output = stream_data.call(output)
		
		if surface[ArrayMesh.ARRAY_TEX_UV] != null:
			has_uv = true
			for uv in surface[ArrayMesh.ARRAY_TEX_UV]:
				output += " ".join(["vt", str(uv.x), str(uv.y) + "\n"])
				output = stream_data.call(output)
		
		if surface[ArrayMesh.ARRAY_NORMAL] != null:
			for n in surface[ArrayMesh.ARRAY_NORMAL]:
				output += " ".join(["vn", str(n.x), str(n.y), str(n.z) + "\n"])
				output = stream_data.call(output)
			has_n = true
		
		
		output = output + "usemtl "+ mesh.surface_get_name(s) +"\n"
		
		#optimized for max speed, precomputed as much as possible
		var format_face_line : Callable = func(indices : Array, i : int):
			var result : String = ""
			var tokens : PackedStringArray = []
			var ii : int = i + 1
			var iii : int = i + 2
			
			#index_base means one added to the value in indices, for 1-starting obj indices
			var index_token_i : String = str(index_base + indices[i])
			#obj face winding is different than godot, so i + 2 comes first
			var index_token_iii : String = str(index_base + indices[iii])
			var index_token_ii : String = str(index_base + indices[ii])
			
			
			if not has_uv and not has_n:
				return "f " + index_token_i + " " + index_token_iii + " " + index_token_ii + "\n"
			elif has_uv and not has_n:
				tokens = [
					"f " + index_token_i,
					index_token_i + " " + index_token_iii,
					index_token_iii + " " + index_token_ii,
					index_token_ii + "\n"
					]
			elif has_n and not has_uv:
				#two slashes //
				tokens = [
					"f " + index_token_i,
					"",
					index_token_i + " " + index_token_iii,
					"",
					index_token_iii + " " + index_token_ii,
					"",
					index_token_ii + "\n"
				]
			#elif has_n and has_uv
			else:
				tokens = [
					"f " + index_token_i,
					index_token_i,
					index_token_i + " " + index_token_iii,
					index_token_iii,
					index_token_iii + " " + index_token_ii,
					index_token_ii,
					index_token_ii + "\n"
				]
			
			
			return "/".join(tokens)
		
		# Write triangle faces
		# Note: Godot's front face winding order is different from obj file format
		var i : int = 0
		var indices : Array = surface[ArrayMesh.ARRAY_INDEX]
		var indices_count : int = indices.size()
		while i < indices_count:
			
			output = output + format_face_line.call(indices, i)
			output = stream_data.call(output)
			#if (i % 60) == 0: # Modulo must be multiple of 3 as it's the step
				#emit_signal("export_progress_updated", s, i / float(indices_count))
				#await tree_access.get_tree().process_frame
			i = i + 3
		
		#emit_signal("export_progress_updated", s, 1.0)
		
		index_base += surface[ArrayMesh.ARRAY_VERTEX].size()
		
		# Create Materials for current surface
		mat_output += str("newmtl "+ mesh.surface_get_name(s))+'\n'
		mat_output += str("Kd ",mat.albedo_color.r," ",mat.albedo_color.g," ",mat.albedo_color.b)+'\n'
		mat_output += str("Ke ",mat.emission.r," ",mat.emission.g," ",mat.emission.b)+'\n'
		mat_output += str("d ",mat.albedo_color.a)+"\n"
	
	file_obj.store_string(output)
	file_mtl.store_string(mat_output)
	file_obj.close()
	file_mtl.close()
	
	#emit_signal("export_completed", obj_file, mat_file)


static func load_mesh_from_file(filename: String, material_filename: String = "") -> Mesh:
	# Transparent call to Ezcha's gd-obj
	return OBJParser.load_obj(filename, material_filename)
