shader_type canvas_item;

uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float tint_amount : hint_range(0.0, 1.0) = 0.5;
uniform float brightness : hint_range(0.0, 2.0) = 1.0;

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    vec3 tinted = mix(tex.rgb, tint_color.rgb, tint_amount);
    COLOR = vec4(tinted * brightness, tex.a);
}
