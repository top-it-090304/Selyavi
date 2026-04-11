shader_type canvas_item;

uniform vec2 hole_center; // В пикселях
uniform vec2 hole_size;   // В пикселях
uniform float hole_radius; // В пикселях
uniform float shape : hint_range(0.0, 1.0) = 0.0; // 0: круг, 1: квадрат
uniform float blur : hint_range(0.0, 1.0) = 0.2;
uniform float alpha_val : hint_range(0.0, 1.0) = 0.7;

void fragment() {
    // Получаем текущие координаты пикселя экрана
    vec2 current_pixel = SCREEN_UV / SCREEN_PIXEL_SIZE;
    float dist = 0.0;

    if (shape < 0.5) {
        // Идеальный круг в пикселях
        dist = distance(current_pixel, hole_center) - hole_radius;
    } else {
        // Идеальный прямоугольник в пикселях
        vec2 d = abs(current_pixel - hole_center) - (hole_size * 0.5);
        dist = length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
    }

    // Плавный переход
    float edge = 20.0 + (max(hole_radius, hole_size.x) * blur);
    float mask = smoothstep(0.0, edge, dist);

    COLOR = vec4(0.0, 0.0, 0.0, alpha_val * mask);
}
