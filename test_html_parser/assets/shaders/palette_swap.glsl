// Palette swap shader for LÖVE2D
extern vec3 source_colors[4];
extern vec3 target_colors[4];
extern float tolerance;

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
{
    vec4 pixel = Texel(texture, texture_coords);
    
    // If pixel is transparent, return as-is
    if (pixel.a < 0.1) {
        return pixel;
    }
    
    // Check each source color for a match
    for (int i = 0; i < 4; i++) {
        vec3 diff = abs(pixel.rgb - source_colors[i]);
        float distance = diff.r + diff.g + diff.b;
        
        if (distance < tolerance) {
            // Replace with target color, preserve alpha
            return vec4(target_colors[i], pixel.a) * color;
        }
    }
    
    // No match, return original pixel
    return pixel * color;
}