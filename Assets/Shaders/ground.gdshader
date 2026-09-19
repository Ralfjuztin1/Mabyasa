shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Colors extracted from your Yugen terrain
uniform vec4 grass_color_1 : source_color = vec4(0.392, 0.471, 0.318, 1.0);
uniform vec4 grass_color_2 : source_color = vec4(0.322, 0.482, 0.384, 1.0);

// Controls the size of the grass patches
uniform float noise_scale = 0.15; 

varying vec3 world_pos;

// Procedural random generator
vec2 random(vec2 uv) {
    uv = vec2(dot(uv, vec2(127.1,311.7)), dot(uv, vec2(269.5,183.3)));
    return -1.0 + 2.0 * fract(sin(uv) * 43758.5453123);
}

// Procedural noise generator
float noise(vec2 uv) {
    vec2 i = floor(uv);
    vec2 f = fract(uv);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(dot(random(i + vec2(0.0,0.0)), f - vec2(0.0,0.0)),
                   dot(random(i + vec2(1.0,0.0)), f - vec2(1.0,0.0)), u.x),
               mix(dot(random(i + vec2(0.0,1.0)), f - vec2(0.0,1.0)),
                   dot(random(i + vec2(1.0,1.0)), f - vec2(1.0,1.0)), u.x), u.y);
}

void vertex() {
    // Track world position to seamlessly map noise across boundaries
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    // Base noise layer
    float n1 = noise(world_pos.xz * noise_scale);
    n1 = n1 * 0.5 + 0.5; 
    
    // Detail noise layer
    float n2 = noise(world_pos.xz * (noise_scale * 2.5));
    n2 = n2 * 0.5 + 0.5;
    
    float final_noise = (n1 * 0.7) + (n2 * 0.3);
    
    // Controls how sharp the transition between the two colors is
    float blend = smoothstep(0.35, 0.65, final_noise);
    
    ALBEDO = mix(grass_color_1.rgb, grass_color_2.rgb, blend);
    ROUGHNESS = 0.85;
}