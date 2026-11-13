shader_type canvas_item;
uniform vec4 trunks_color : source_color = vec4(1.0,0.60,0.42,1.0);
void fragment(){
    vec4 source = texture(TEXTURE, UV);
    if(source.r > 0.30 && source.r > source.g * 1.7 && source.g < 0.40 && source.b > source.g * 0.70 && source.b < source.r * 0.75){
        source.rgb = trunks_color.rgb * clamp(source.r * 1.15, 0.30, 1.0);
    }
    COLOR = source;
}
