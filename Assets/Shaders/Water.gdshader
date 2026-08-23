shader_type spatial;
render_mode world_vertex_coords, cull_disabled, depth_draw_always;

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap, repeat_disable;

group_uniforms colours;
uniform vec3 absorptioncolour : source_color;
uniform float absorptionmultiplier = 1.0;

group_uniforms material;
uniform float AirIOR = 1.0;
uniform float IOR = 1.33;

group_uniforms textures;
uniform vec2 sampler1speed = vec2(0.02, 0.0);
uniform vec2 sampler2speed = vec2(0.0, 0.02);
uniform float samplermix : hint_range(0.0, 1.0, 0.1) = 0.5;
uniform vec2 samplerscale = vec2(0.1);
uniform sampler2D normal1tex : filter_linear_mipmap, hint_normal;
uniform sampler2D normal2tex : filter_linear_mipmap, hint_normal;
uniform float normalstrength : hint_range(0.0, 5.0, 0.01) = 1.0;
uniform sampler2D height1tex : filter_linear_mipmap;
uniform sampler2D height2tex : filter_linear_mipmap;
uniform float heightstrength : hint_range(0.0, 5.0, 0.01) = 0.12;
uniform sampler2D edge1tex : filter_linear_mipmap;
uniform sampler2D edge2tex : filter_linear_mipmap;

group_uniforms pixelation;
uniform float pixel_resolution : hint_range(8.0, 128.0, 1.0) = 48.0;

varying vec2 position;
varying vec3 wposition;

group_uniforms refraction;
uniform int refraction_type : hint_enum("None", "Simple") = 1;
uniform float simple_refraction_amount = 0.1;

group_uniforms edge;
uniform float edge_size : hint_range(0.01, 0.5, 0.01) = 0.1;
uniform bool foam_or_fade = false;

uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_linear_mipmap, repeat_disable;

group_uniforms screen_space_reflection;
uniform int ssr_type : hint_enum("None", "Simple") = 0;
uniform float ssr_screen_fade : hint_range(0.01, 0.5, 0.01) = 0.05;

float schlickfresnel(float ior1, float ior2, vec3 view, vec3 norm) {
	float incident = dot(view, norm);
	float reflectance = ((ior2 - ior1)/(ior2 + ior1)) * ((ior2 - ior1)/(ior2 + ior1));
	float fresnelincident = reflectance + (1.0 - reflectance) * pow(1.0 - cos(incident), 5.0);
	return clamp(fresnelincident / incident, 0.0, 1.0);
}

void vertex() {
	position = VERTEX.xz;
	UV = VERTEX.xz * samplerscale + (sampler1speed * TIME);
	UV2 = VERTEX.xz * samplerscale + (sampler2speed * TIME);
	float height = mix(texture(height1tex, UV), texture(height2tex, UV2), samplermix).x;
	VERTEX.y += (height - 0.5) * heightstrength;
	wposition = VERTEX;
}

float linear_depth(float nonlinear_depth, mat4 inv_projection_matrix) {
	#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
		nonlinear_depth = nonlinear_depth * 2.0 - 1.0;
	#endif
	return 1.0 / (nonlinear_depth * inv_projection_matrix[2].w + inv_projection_matrix[3].w);
}

vec2 view2uv(vec3 position_view_space, mat4 proj_m) {
	vec4 position_clip_space = proj_m * vec4(position_view_space.xyz, 1.0);
	vec2 position_ndc = position_clip_space.xy / position_clip_space.w;
	return position_ndc.xy * 0.5 + 0.5;
}

float edge_fade(vec2 uv, float size) {
	float x1 = clamp((uv.x - 0.0) / size, 0.0, 1.0);
	float x2 = clamp((uv.x - 1.0) / (-size), 0.0, 1.0);
	float y1 = clamp((uv.y - 0.0) / size, 0.0, 1.0);
	float y2 = clamp((uv.y - 1.0) / (-size), 0.0, 1.0);
	return x1 * x2 * y1 * y2;
}

void refraction(vec3 normal, vec3 vertex, vec2 normmap, bool reverse, mat4 projection_matrix, vec3 tangent, vec3 binormal, vec2 screen_uv, vec2 viewport_size, inout vec3 emission) {
	mat4 inv_proj_mat = inverse(projection_matrix);
	
	if (refraction_type == 1) {
		float lineardepth = linear_depth(texture(DEPTH_TEXTURE, screen_uv).r, inv_proj_mat);
		float selfdepth = -vertex.z;
		float depth_diff = lineardepth - selfdepth;
		float x_mult = viewport_size.y / viewport_size.x;
		vec3 tanx = binormal * (normmap.x - 0.5) * normalstrength * x_mult;
		vec3 tany = tangent * (normmap.y - 0.5) * normalstrength;
		vec2 refracted_uv = screen_uv + (tanx + tany).xy * simple_refraction_amount * depth_diff / lineardepth;
		float newdepth = linear_depth(texture(DEPTH_TEXTURE, refracted_uv).r, inv_proj_mat);
		if (newdepth >= selfdepth) {
			depth_diff = newdepth - selfdepth;
		}
		
		vec3 newvolcolour;
		if (reverse) {
			newvolcolour = vec3(1.0);
		} else {
			newvolcolour = pow(absorptioncolour, vec3(depth_diff * absorptionmultiplier));
		}
		emission = newvolcolour * texture(screen, refracted_uv).rgb;

		if (newdepth < selfdepth) {
			emission = newvolcolour * texture(screen, screen_uv).rgb;
		}
	} else {
		float lineardepth = linear_depth(texture(DEPTH_TEXTURE, screen_uv).r, inv_proj_mat);
		float selfdepth = -vertex.z;
		float depth_diff = lineardepth - selfdepth;
		vec3 newvolcolour;
		if (reverse) {
			newvolcolour = vec3(1.0);
		} else {
			newvolcolour = pow(absorptioncolour, vec3(depth_diff * absorptionmultiplier));
		}
		emission = newvolcolour * texture(screen, screen_uv).rgb;
	}
}

void reflection(vec3 normal, vec3 vertex, mat4 projection_matrix, inout vec3 emission, inout float specular) {
	vec3 view = normalize(-vertex);
	if (ssr_type == 1) {
		vec3 reflected = -reflect(view, normal);
		if (reflected.z < 0.0) {
			vec2 uv = view2uv(reflected, projection_matrix);
			float testdepth = texture(DEPTH_TEXTURE, uv).r;
			
			if (testdepth > 0.0) {
				specular *= 1.0 - edge_fade(uv, ssr_screen_fade);
				emission += texture(screen, uv).xyz * schlickfresnel(1.0, 1.33, view, normal) * edge_fade(uv, ssr_screen_fade);
			}
		}
	}
}

void fragment() {
	vec2 pixel_uv = floor(UV * pixel_resolution) / pixel_resolution;
	vec2 pixel_uv2 = floor(UV2 * pixel_resolution) / pixel_resolution;

	vec3 onorm = NORMAL;

	vec2 normmap = mix(texture(normal1tex, pixel_uv), texture(normal2tex, pixel_uv2), samplermix).xy;
	NORMAL += TANGENT * (normmap.x - 0.5) * normalstrength;
	NORMAL += BINORMAL * (normmap.y - 0.5) * normalstrength;

	ROUGHNESS = 0.05;
	METALLIC = 0.0;
	ALBEDO = vec3(0.0);
	
	if (FRONT_FACING) {
		float fres = clamp(schlickfresnel(AirIOR, IOR, VIEW, NORMAL), 0.0, 1.0);
		float lineardepth = linear_depth(texture(DEPTH_TEXTURE, SCREEN_UV).r, INV_PROJECTION_MATRIX);
		float selfdepth = -VERTEX.z;
		float depth_diff = lineardepth - selfdepth;
		
		refraction(NORMAL, VERTEX, normmap, false, PROJECTION_MATRIX, TANGENT, BINORMAL, SCREEN_UV, VIEWPORT_SIZE, EMISSION);
		EMISSION *= 1.0 - fres;
		reflection(NORMAL, VERTEX, PROJECTION_MATRIX, EMISSION, SPECULAR);

		float distfromedge = depth_diff * dot(normalize(NORMAL), normalize(-VERTEX)) / VIEW.z;
		if (distfromedge < edge_size) {
			distfromedge /= edge_size;
			if (foam_or_fade) {
				ALPHA = distfromedge;
			} else {
				float edgetex = mix(texture(edge1tex, pixel_uv).r, texture(edge2tex, pixel_uv2).r, samplermix);
				if (edgetex > distfromedge) {
					ALBEDO = vec3(1.0);
					ROUGHNESS = 1.0;
					METALLIC = 1.0;
					EMISSION = vec3(0.0);
					NORMAL = onorm;
				}
			}
		} else {
			ALPHA = 1.0;
		}
	} else {
		float window = dot(refract(VIEW, NORMAL, IOR / AirIOR), -NORMAL);

		if (window >= 1.00) {
			SPECULAR = 0.0;
			refraction(NORMAL, VERTEX, normmap, true, PROJECTION_MATRIX, TANGENT, BINORMAL, SCREEN_UV, VIEWPORT_SIZE, EMISSION);
		} else if (window <= 0.0) {
			reflection(NORMAL, VERTEX, PROJECTION_MATRIX, EMISSION, SPECULAR);
		} else {
			SPECULAR *= clamp(1.0 - window, 0.0, 1.0);
			refraction(NORMAL, VERTEX, normmap, true, PROJECTION_MATRIX, TANGENT, BINORMAL, SCREEN_UV, VIEWPORT_SIZE, EMISSION);
			EMISSION *= window;
			reflection(NORMAL, VERTEX, PROJECTION_MATRIX, EMISSION, SPECULAR);
		}
	}
	ALPHA = clamp(ALPHA, 0.0, 1.0);
}