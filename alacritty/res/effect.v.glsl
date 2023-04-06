layout (location = 0) in vec2 aPos;
layout (location = 1) in vec2 aUV;

out vec2 UV;
out vec2 pos;

void main() {
	UV = aUV;
	pos = aPos;
	gl_Position = vec4(aPos.x, aPos.y, 0.0, 1.0);
}
