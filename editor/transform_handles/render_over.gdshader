// A Godot 4 shader to make things appear on top of other things within a range.
// Initially, this was made so my characters' facial features would be rendered on top of their hair.

shader_type spatial;
render_mode unshaded;


uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;

// Maximum depth we can overdraw relative to the object original depth, in ENGINE UNITS.
// For example, if overdraw_depth_limit = 0.2 and the original depth of the object is 1,
// the object will be drawn on top of everything that as a depth between 1.0 and 1.2
uniform float overdraw_depth_limit : hint_range(0.0, 100.0) = 99;
instance uniform vec3 color : source_color;


// Function taken from stackoverflow : https://stackoverflow.com/a/51137756
float linearize(float depth, float z_near, float z_far) {
	return z_near * z_far / (z_far + depth * (z_near - z_far));
}

//TODO possibly remove all these calculations and just set DEPTH = screen_depth - 0.01
void fragment() {
	// Calculate z_near and z_far (required for the linearize function)
	float z_near = abs(PROJECTION_MATRIX[3][2] / PROJECTION_MATRIX[2][2]);
	float z_far = abs((PROJECTION_MATRIX[3][2] * z_near) / (PROJECTION_MATRIX[3][2] + z_near));

	// Get the depth difference between the object we want to overdraw and the other objects
	float screen_depth = textureLod(depth_texture, SCREEN_UV, 0.0).r;
	float fragment_depth = FRAGCOORD.z;
	float depth_delta = fragment_depth - screen_depth;

	float l_screen_depth = linearize(screen_depth, z_near, z_far);
	float l_fragment_depth = linearize(fragment_depth, z_near, z_far);
	float l_depth_delta = l_fragment_depth - l_screen_depth;

	DEPTH = fragment_depth; // Set DEPTH default value

	if (abs(l_depth_delta) < overdraw_depth_limit) { // Fragment is behind geometry, but in the overdraw zone
		DEPTH = screen_depth - 0.01; // Skip the inverse linearize operation and reuse the screen depth directly
	}
  
 	// Change the rest to suit your needs
	ALBEDO = color;
}