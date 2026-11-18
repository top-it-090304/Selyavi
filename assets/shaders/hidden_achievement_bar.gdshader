shader_type canvas_item;

uniform vec2 bar_size = vec2(100.0, 16.0);

void fragment() {
	vec2 half_size = bar_size * 0.5;
	float radius = min(6.0, half_size.y);
	vec2 position = UV * bar_size;
	vec2 corner = abs(position - half_size) - half_size + vec2(radius);
	float edge = length(max(corner, vec2(0.0))) + min(max(corner.x, corner.y), 0.0) - radius;
	float mask = 1.0 - smoothstep(-0.5, 0.5, edge);
	float stripe = 1.0 - step(7.0, mod(position.x + position.y, 22.0));
	vec3 grey = mix(vec3(0.22, 0.24, 0.23), vec3(0.40, 0.42, 0.40), stripe);
	float inside = 1.0 - smoothstep(-1.5, -0.5, edge);
	COLOR = vec4(mix(vec3(0.12, 0.13, 0.12), grey, inside), mask);
}
