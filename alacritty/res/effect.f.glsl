
out vec4 FragColor;

in vec2 UV;
in vec2 pos;

uniform sampler2D renderedTexture;

void main() {
	vec3 color = texture( renderedTexture, UV).xyz;
	color.xy += pos;
	FragColor = vec4(color, 1.0);
}
