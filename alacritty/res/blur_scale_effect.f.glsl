out vec4 fragColor;

in vec2 UV;
in vec2 pos;

uniform sampler2D renderedTexture;
uniform float blur_scale;

void main()
{
	vec2 uv = UV;
	vec2 tex_offset = 1.0 / textureSize(renderedTexture, 0);

	float h_blur_scale = blur_scale / 2.0;

	vec4 color = vec4(0.0);

	for (float x = -h_blur_scale; x < h_blur_scale; x++) {
		for (float y = -h_blur_scale; y < h_blur_scale; y++) {
			color += texture(renderedTexture, uv * blur_scale + vec2(x * tex_offset.x, y * tex_offset.y));
		}
	}
	color /= blur_scale * blur_scale;
	fragColor = color;
}
