shader_type spatial;

uniform vec3 color_1 : source_color = vec3(0.0, 0.6, 1.0);
uniform vec3 color_2 : source_color = vec3(0.39, 0.76, 1.0);
uniform float speed = 5.0;


void fragment() {
	ALBEDO = mix(color_1, color_2, (sin(TIME * speed)/speed) * 0.5);
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.5;
	EMISSION = ALBEDO;
}