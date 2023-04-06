out vec4 fragColor;

in vec2 UV;
in vec2 pos;

uniform sampler2D renderedTexture;
uniform sampler2D blurTexture;
uniform float time;

#define SCAN_AMOUNT 2000.0
#define SCAN_STRENGTH 0.2

#define OFFSET_AMOUNT 0.0008

//curve and vignet were from https://www.shadertoy.com/view/Ms23DR
vec2 curve(vec2 uv)
{
	uv = (uv - 0.5) * 2.0;
	uv *= 1.1;	
	uv.x *= 1.0 + pow((abs(uv.y) / 7.0), 2.0);
	uv.y *= 1.0 + pow((abs(uv.x) / 6.0), 2.0);
	uv  = (uv / 2.0) + 0.5;
	uv =  uv *0.92 + 0.04;
	return uv;
}

float scan_strength(vec2 uv)
{
   float value = sin(uv.y * SCAN_AMOUNT);
   value = (value + 1.0) / 2.0;
   return value * value;
}

void main()
{
		vec2 uv = UV;
    
    uv = curve(uv);

		if (uv.x > 1.0 || uv.x < 0.0) {
			fragColor = vec4(0.0, 0.0, 0.0, 1.0);
			return;
		}
		if (uv.y > 1.0 || uv.y < 0.0) {
			fragColor = vec4(0.0, 0.0, 0.0, 1.0);
			return;
		}

    
    float vig = (0.8 + 1.0*12.0*uv.x*uv.y*(1.0-uv.x)*(1.0-uv.y));
    
    vec3 color;
    color.r = texture(renderedTexture, uv + vec2(-OFFSET_AMOUNT, 0.0)).r;
    color.g = texture(renderedTexture, uv + vec2(0.0, 0.0)).g;
    color.b = texture(renderedTexture, uv + vec2(OFFSET_AMOUNT, 0.0)).b;

		vec3 blurColor = texture(blurTexture, uv).xyz;
    
    color *= vig;
    
    color -= vec3(scan_strength(uv) * SCAN_STRENGTH);

		color += blurColor * 1.2 - 0.2;

    // Output to screen
    fragColor = vec4(color,1.0);
}
