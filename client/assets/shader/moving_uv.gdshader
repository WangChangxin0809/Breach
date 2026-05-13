shader_type canvas_item;
void fragment() {
    vec2 moving_uv = UV;
    moving_uv.x -= TIME * 0.5; // 控制纹理沿触手滚动的速度
    COLOR = texture(TEXTURE, moving_uv);
}