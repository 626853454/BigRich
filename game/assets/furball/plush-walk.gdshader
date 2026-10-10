shader_type spatial;
render_mode cull_disabled;
uniform vec4 plush_color : source_color = vec4(1.0);
uniform float plush_roughness = 0.72;
uniform float plush_metallic = 0.0;
uniform float gait_phase = 0.0;
uniform float gait_weight = 0.0;
uniform float body_height = 0.0;
void vertex() {
    // Existing upright corgi paws sit below0.5m, either side of the midline.
    // Smooth masks keep the torso, scarf, face and accessories unchanged.
    float low = 1.0 - smoothstep(0.20, 0.52, VERTEX.y);
    float sides = smoothstep(0.08, 0.19, abs(VERTEX.x));
    float mask = low * sides;
    float step_phase = gait_phase + (VERTEX.x < 0.0 ? 3.14159265 : 0.0);
    float stride = sin(step_phase) * gait_weight;
    VERTEX.z += stride * 0.09 * mask;
    VERTEX.y += (max(0.0, stride) * 0.045 - body_height) * mask;
}
void fragment() {
    ALBEDO = plush_color.rgb;
    ROUGHNESS = plush_roughness;
    METALLIC = plush_metallic;
}
