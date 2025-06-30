shader_type spatial;

uniform vec3 color : source_color;
uniform float mixed_color_ratio : hint_range(0.0, 1.0, 0.01);
uniform float contrast : hint_range(0.0, 1.0, 0.01);
//uniform float tint_strength: hint_range(0.0f, 10.0f) = 1.0f;

render_mode blend_mix,depth_draw_opaque,cull_back,diffuse_burley,specular_schlick_ggx;
uniform sampler2D texture_albedo : source_color,filter_linear_mipmap,repeat_enable;
uniform float roughness : hint_range(0,1);
uniform sampler2D texture_metallic : hint_default_white,filter_linear_mipmap,repeat_enable;
uniform vec4 metallic_texture_channel;
uniform sampler2D texture_roughness : hint_roughness_r,filter_linear_mipmap,repeat_enable;
uniform float specular;
uniform float metallic;
uniform sampler2D texture_normal : hint_roughness_normal,filter_linear_mipmap,repeat_enable;
uniform float normal_scale : hint_range(-16,16);
varying vec3 uv1_triplanar_pos;
varying vec3 uv1_power_normal;
//uniform vec3 uv1_scale = vec3(1.0);
//uniform vec3 uv1_offset;
varying vec3 basis_scale;
varying mat3 basis;

void vertex() {
	TANGENT = vec3(0.0,0.0,-1.0) * abs(NORMAL.x);
	TANGENT+= vec3(1.0,0.0,0.0) * abs(NORMAL.y);
	TANGENT+= vec3(1.0,0.0,0.0) * abs(NORMAL.z);
	TANGENT = normalize(TANGENT);
	BINORMAL = vec3(0.0,1.0,0.0) * abs(NORMAL.x);
	BINORMAL+= vec3(0.0,0.0,-1.0) * abs(NORMAL.y);
	BINORMAL+= vec3(0.0,1.0,0.0) * abs(NORMAL.z);
	BINORMAL = normalize(BINORMAL);
	//1.0 used to be triplanar blend sharpness parameter
	uv1_power_normal=pow(abs(NORMAL),vec3(1.0));
	//made shader work with mesh size but not mesh position or rotation(good)
	basis = mat3(MODEL_MATRIX);
	basis_scale = vec3(length(basis[0]), length(basis[1]), length(basis[2]));
	uv1_triplanar_pos = (basis_scale * vec3(VERTEX)).xyz;
	//uv1_triplanar_pos = VERTEX;// * uv1_scale + uv1_offset
	uv1_power_normal/=dot(uv1_power_normal,vec3(1.0));
	uv1_triplanar_pos *= vec3(1.0,-1.0, 1.0);
}



//void vertex() {
	//uv1_power_normal=pow(abs(mat3(MODEL_MATRIX) * NORMAL),vec3(uv1_blend_sharpness));
	//uv1_triplanar_pos = (mat3(MODEL_MATRIX) * vec3(VERTEX)).xyz;
	//uv1_power_normal/=dot(uv1_power_normal,vec3(1.0));
	//uv1_triplanar_pos *= vec3(1.0,-1.0, 1.0);
//}



vec4 triplanar_texture(sampler2D p_sampler,vec3 p_weights,vec3 p_triplanar_pos) {
	vec4 samp=vec4(0.0);
	samp+= texture(p_sampler,p_triplanar_pos.xy) * p_weights.z;
	samp+= texture(p_sampler,p_triplanar_pos.xz) * p_weights.y;
	samp+= texture(p_sampler,p_triplanar_pos.zy * vec2(-1.0,1.0)) * p_weights.x;
	return samp;
}


void fragment() {
	vec4 albedo_tex = triplanar_texture(texture_albedo,uv1_power_normal,uv1_triplanar_pos);
	//ALBEDO = color.rgb * albedo_tex.rgb;
	ALBEDO = color + contrast * (mixed_color_ratio - albedo_tex.rgb);
	float metallic_tex = dot(triplanar_texture(texture_metallic,uv1_power_normal,uv1_triplanar_pos),metallic_texture_channel);
	METALLIC = metallic_tex * metallic;
	vec4 roughness_texture_channel = vec4(1.0,0.0,0.0,0.0);
	float roughness_tex = dot(triplanar_texture(texture_roughness,uv1_power_normal,uv1_triplanar_pos),roughness_texture_channel);
	ROUGHNESS = roughness_tex * roughness;
	SPECULAR = specular;
	NORMAL_MAP = triplanar_texture(texture_normal,uv1_power_normal,uv1_triplanar_pos).rgb;
	NORMAL_MAP_DEPTH = normal_scale;
}