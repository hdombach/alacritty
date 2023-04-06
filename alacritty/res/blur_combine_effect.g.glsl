out vec4 fragColor;

in vec2 UV;
in vec2 pos;

uniform sampler2D renderTexture;
uniform sampler2D blurTexture;

float to_grayscale(vec3 value) {
	return value.r * 0.3 + value.g * 0.53 + value.b * 0.11;
}

vec3 mix(vec3 color1, vec3 color2, float factor) {
	factor = clamp(factor, 0.0, 1.0);
	return color1 * factor + color2 * (1.0 - factor);
}

void main()
{
	vec2 uv = UV;

	vec4 color = texture(renderTexture, uv);
	vec4 blur = texture(blurTexture, uv);


	vec4 blur_color = clamp(blur - color, 0.0, 1.0);

	float strength = to_grayscale(blur_color.xyz);

	blur_color = (blur_color + (1.0 - strength)) / 2.0 - 0.5;
	blur_color = color + blur_color * 6.0 - strength * 0.5;

	fragColor = blur_color;

	fragColor.a = 1.0;

	//fragColor = blur;
}
