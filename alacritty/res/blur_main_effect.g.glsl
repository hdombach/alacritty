out vec4 fragColor;

in vec2 UV;
in vec2 pos;

uniform sampler2D renderedTexture;
uniform bool horizontal;
uniform float weight[5] = float[] (0.227027, 0.1945946, 0.1216216, 0.054054, 0.016216);

float to_grayscale(vec3 value) {
	return value.r * 0.3 + value.g * 0.53 + value.b * 0.11;
}

void main()
{            
		vec2 uv = UV;
    vec2 tex_offset = 1.0 / textureSize(renderedTexture, 0); // gets size of single texel
    vec3 result = texture(renderedTexture, uv).rgb * weight[0]; // current fragment's contribution
    if(horizontal)
    {
        for(int i = 1; i < 5; ++i)
        {
            result += texture(renderedTexture, uv + vec2(tex_offset.x * i, 0.0)).rgb * weight[i];
            result += texture(renderedTexture, uv - vec2(tex_offset.x * i, 0.0)).rgb * weight[i];
        }
    }
    else
    {
        for(int i = 1; i < 5; ++i)
        {
            result += texture(renderedTexture, uv + vec2(0.0, tex_offset.y * i)).rgb * weight[i];
            result += texture(renderedTexture, uv - vec2(0.0, tex_offset.y * i)).rgb * weight[i];
        }
    }
    fragColor = vec4(result, 1.0);
}
