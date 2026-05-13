shader_type canvas_item;

// 在右侧检查器中调整贴图的缩放比例
uniform float scale = 1.0; 

// 【新增】基础颜色变量，默认是纯白色。加了 source_color 后，编辑器会显示一个取色器
uniform vec4 base_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// 用于在顶点和像素处理之间传递世界坐标
varying vec2 world_pos; 

void vertex() {
    // 获取当前顶点的绝对世界坐标
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
    // 将世界坐标缩小一定比例后作为 UV 使用
    vec2 world_uv = world_pos / 100.0 * scale; 
    
    // 采样贴图本身的颜色
    vec4 tex_color = texture(TEXTURE, world_uv);
    
    // 【修改】将贴图颜色与你自定义的基础颜色相乘，得出最终输出颜色
    COLOR = tex_color * base_color;
}