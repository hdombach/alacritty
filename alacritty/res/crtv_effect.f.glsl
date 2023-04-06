// CRT emulation

out vec4 FragColor;

in vec2 UV;
in vec2 pos;

uniform sampler2D renderedTexture;
uniform float time;

// Shader Options
#define ENABLE_CURVE            1
#define ENABLE_BLOOM            1
#define ENABLE_BLUR             1
#define ENABLE_GRAYSCALE        0
#define ENABLE_BLACKLEVEL       1
#define ENABLE_REFRESHLINE      1
#define ENABLE_SCANLINES        1
#define ENABLE_TINT             1
#define ENABLE_GRAIN            1

// Settings - Overscan
#define OVERSCAN_PERCENTAGE     0.1

// Settings - Bloom
#define BLOOM_OFFSET            0.0015
#define BLOOM_STRENGTH          0.8

// Settings - Blur
#define BLUR_MULTIPLIER         1.05
#define BLUR_STRENGTH           0.4
#define BLUR_OFFSET             0.003

// Settings - Grayscale
#define GRAYSCALE_INTENSITY     0
#define GRAYSCALE_GLEAM         0
#define GRAYSCALE_LUMINANCE     1
#define GRAYSCALE_LUMA          0

// Settings - Blacklevel
#define BLACKLEVEL_FLOOR        TINT_COLOR / 40

// Settings - Tint
// Colors variations from https://superuser.com/a/1206781
#define TINT_COLOR              TINT_CUSTOM 

#define TINT_CUSTOM             vec3(1.0, 0.9, 0.7)
#define TINT_AMBER              vec3(1.0, 0.7, 0.0) // P3 phosphor
#define TINT_LIGHT_AMBER        vec3(1.0, 0.8, 0.0)
#define TINT_GREEN_1            vec3(0.2, 1.0, 0.0)
#define TINT_APPLE_II           vec3(0.2, 1.0, 0.2) // P1 phosphor
#define TINT_GREEN_2            vec3(0.0, 1.0, 0.2)
#define TINT_APPLE_IIc          vec3(0.4, 1.0, 0.4) // P24 phpsphor
#define TINT_GREEN_3            vec3(0.0, 1.0, 0.4)
#define TINT_WARM               vec3(1.0, 0.9, 0.8)
#define TINT_COOL               vec3(0.8, 0.9, 1.0)

// Settings - Gain
#define GRAIN_INTENSITY         0.02

// If you have Bloom enabled, it doesn't play well
// with the way Gleam and Luma calculate grayscale
// so fall back to Luminance
#if ENABLE_BLOOM && (GRAYSCALE_GLEAM || GRAYSCALE_LUMA)
#undef GRAYSCALE_INTENSITY
#undef GRAYSCALE_GLEAM
#undef GRAYSCALE_LUMINANCE
#undef GRAYSCALE_LUMA
#define GRAYSCALE_LUMINANCE 1
#endif

// Provide a reasonable Blacklevel even if Tint isn't enabled
#if ENABLE_BLACKLEVEL && !ENABLE_TINT
#undef BLACKLEVEL_FLOOR
#define BLACKLEVEL_FLOOR vec3(0.05, 0.05, 0.05)
#endif

// All the DEBUG settings are optional
// At a minimum, #define DEBUG 1 will pass debug visualizations
// through, but that can be refined with the additional settings
// #define SHOW_UV and SHOW_POS can be useful for seeing the
// coordinates but this is more valuable when trying to see these
// coordinates when applied to the Windows Terminal, a capability
// disabled by default. SHOW_UV and SHOW_POS are independant of
// DEBUG and effectively replace the shader code being written. This
// can be useful to temporarily disable the shader code with a
// minumum output which renders during development.

// Settings - Debug
#define DEBUG                   1
//#define DEBUG_ROTATION          0.25
//#define DEBUG_SEGMENTS          1
//#define DEBUG_OFFSET            0.425
//#define DEBUG_WIDTH             0.15
#define SHOW_UV                 0
#define SHOW_POS                0
#define CURVE_AMOUNT 1.0
#define INSET 4.0

#if ENABLE_CURVE
vec2 transformCurve(vec2 uv) {
  // TODO: add control variable for transform intensity
  uv -= 0.5;				// offcenter screen
  float r = uv.x * uv.x + uv.y * uv.y; 	// get ratio
  uv *= INSET + r * CURVE_AMOUNT;				// apply ratio
  uv *= 0.25;				// zoom
  uv += 0.5;				// move back to center
  return uv;
}
#endif

vec3 saturate(vec3 color) {
	//TODO
	return color;
}

vec3 pow(vec3 value, float power) {
	return vec3(pow(value.x, power), pow(value.y, power), pow(value.z, power));
}

#if ENABLE_BLOOM
vec3 bloom(vec3 color, vec2 uv)
{
  vec3 bloom = color - texture(renderedTexture, uv + vec2(-BLOOM_OFFSET, 0) * 0.3).rgb;
  vec3 bloom_mask = bloom * BLOOM_STRENGTH;
  //return bloom_mask;
  return saturate(color + bloom_mask);
}
#endif

#if ENABLE_BLUR
const float blurWeights[9]= float[9](0.0, 0.092, 0.081, 0.071, 0.061, 0.051, 0.041, 0.031, 0.021);

vec3 blurH(vec3 c, vec2 uv)
{
  vec3 screen =
    texture(renderedTexture, uv).rgb * 0.102;
  for (int i = 1; i < 9; i++) screen +=
    texture(renderedTexture, uv + vec2( i * BLUR_OFFSET, 0)).rgb * blurWeights[i];
  for (int i = 1; i < 9; i++) screen +=
    texture(renderedTexture, uv + vec2(-i * BLUR_OFFSET, 0)).rgb * blurWeights[i];
  return screen * BLUR_MULTIPLIER;
}

vec3 blurV(vec3 c, vec2 uv)
{
  vec3 screen =
    texture(renderedTexture, uv).rgb * 0.102;
  for (int i = 1; i < 9; i++) screen +=
    texture(renderedTexture, uv + vec2(0,  i * BLUR_OFFSET)).rgb * blurWeights[i];
  for (int i = 1; i < 9; i++) screen +=
    texture(renderedTexture, uv + vec2(0, -i * BLUR_OFFSET)).rgb * blurWeights[i];
  return screen * BLUR_MULTIPLIER;
}

vec3 blur(vec3 color, vec2 uv)
{
  vec3 blur = (blurH(color, uv) + blurV(color, uv)) / 2 - color;
  vec3 blur_mask = blur * BLUR_STRENGTH;
  //return blur_mask;
  return saturate(color + blur_mask);
}
#endif

#if ENABLE_GRAYSCALE
// https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0029740
vec3 rgb2intensity(vec3 c)
{
  return vec3((c.r + c.g + c.b) / 3.0);
}

#define GAMMA 2.2
vec3 gamma(vec3 c)
{
  return pow(c, GAMMA);
}

vec3 invGamma(vec3 c)
{
  return pow(c, 1.0 / GAMMA);
}

vec3 rgb2gleam(vec3 c)
{
  c = invGamma(c);
  c= rgb2intensity(c);
  return gamma(c);
}

vec3 rgb2luminance(vec3 c)
{
	//changed greatly
  return vec3(0.2989 * c.r + 0.5866 * c.g + 0.1145 * c.b);
}

vec3 rgb2luma(vec3 c)
{
	c = invGamma(c);
	c = vec3(0.2126 * c.r, 0.7152 * c.g, 0.0722 * c.b);
	return gamma(c);
}

vec3 grayscale(vec3 color)
{
  #if GRAYSCALE_INTENSITY
  color.rgb = saturate(rgb2intensity(color.rgb));
  #elif GRAYSCALE_GLEAM
  color.rgb = saturate(rgb2gleam(color.rgb));
  #elif GRAYSCALE_LUMINANCE
  color.rgb = saturate(rgb2luminance(color.rgb));
  #elif GRAYSCALE_LUMA
  color.rgb = saturate(rgb2luma(color.rgb));
  #else // Error, strategy not defined
  color.rgb = vec3(1.0, 0.0, 1.0) - color.rgb;
  #endif

  return color;
}
#endif

#if ENABLE_BLACKLEVEL
vec3 blacklevel(vec3 color)
{
	color.rgb -= BLACKLEVEL_FLOOR;
	color.rgb = saturate(color.rgb);
	color.rgb += BLACKLEVEL_FLOOR;
	return saturate(color);
}
#endif

#if ENABLE_REFRESHLINE
vec3 refreshLines(vec3 color, vec2 uv)
{
  float timeOver = mod(time / 5.0f, 1.5f) - 0.5f;
  float refreshLineColorTint = timeOver - uv.y;
  if(uv.y > timeOver && uv.y - 0.03 < timeOver ) color.rgb += (refreshLineColorTint * 2.0);
  return saturate(color);
}
#endif

#if ENABLE_SCANLINES
// retro.hlsl
#define SCANLINE_FACTOR 0.3
#define SCALED_SCANLINE_PERIOD 10.0

float squareWave(float y)
{
  return 1 - floor(mod(y / SCALED_SCANLINE_PERIOD, 2.0)) * SCANLINE_FACTOR;
}

vec3 scanlines(vec3 color, vec2 pos)
{
  float wave = squareWave(pos.y);

  // TODO:GH#3929 make this configurable.
  // Remove the && false to draw scanlines everywhere.
  if (length(color.rgb) < 0.2 && false)
  {
    return saturate(color + wave * 0.1);
  }
  else
  {
    return saturate(color * wave);
  }
}
// end - retro.hlsl
#endif

#if ENABLE_TINT
vec3 tint(vec3 color)
{
	color.rgb *= TINT_COLOR;
	return saturate(color);
}
#endif

#if ENABLE_GRAIN
// Grain Lookup Table
#define a0  0.151015505647689
#define a1 -0.5303572634357367
#define a2  1.365020122861334
#define b0  0.132089632343748
#define b1 -0.7607324991323768

float permute(float x)
{
  x *= (34 * x + 1);
  return 289 * mod(x * 1 / 289.0, 1.0);
}

float rand(inout float state)
{
  state = permute(state);
  return mod(state / 41.0, 1.0);
}

vec3 grain(vec3 color, vec2 uv)
{
  vec3 m = vec3(uv, time) + 1.0;
  float state = permute(permute(m.x) + m.y) + m.z;
  
  float p = 0.95 * rand(state) + 0.025;
  float q = p - 0.5;
  float r2 = q * q;
  
  float grain = q * (a2 + (a1 * r2 + a0) / (r2 * r2 + b1 * r2 + b0));
  color.rgb += GRAIN_INTENSITY * grain;

  return saturate(color);
}
#endif

void main() {
  // Use pos and uv in the shader the same as we might use
  // time, Scale, Resolution, and Background. Unlike those,
  // they are local variables in this implementation and should
  // be passed to any functions using them.
  
	vec2 uv = UV;

//-- Shader goes here --//
  #if ENABLE_CURVE
  uv = transformCurve(uv);

  // TODO: add monitor visuals and make colors static consts
  // Outer Box
  if(uv.x <  -0.025 || uv.y <  -0.025) {
		FragColor = vec4(0.0, 0.0, 0.0, 1.0);
		return;
	} 
  if(uv.x >   1.025 || uv.y >   1.025) {
		FragColor = vec4(0.0, 0.0, 0.0, 1.0);
		return;
	}
  // Bezel
  if(uv.x <  -0.015 || uv.y <  -0.015) {
		FragColor = vec4(0.03, 0.03, 0.03, 1.0);
		return;
	}
  if(uv.x >   1.015 || uv.y >   1.015) {
		FragColor = vec4(0.03, 0.03, 0.03, 1.0);
		return;
	}
  // Screen Border
  if(uv.x <  -0.001 || uv.y <  -0.001) {
		FragColor = vec4(0.0, 0.0, 0.0, 1.0);
		return;
	}
  if(uv.x >   1.001 || uv.y >   1.001) {
		FragColor = vec4(0.0, 0.0, 0.0, 1.0);
		return;
	}
  #endif
  
  // Temporary color to be substituted
  vec4 color = vec4(1,0,1,-1);

  // We need to track two different uv's. The screen uv is effectively
  // the CRT glass. We also want to track uv for when we sample from the
  // texture.
  vec2 screenuv = uv;

  // If no options are selected, this will just display as normal.
  // This must come after we've adjusted the uv for OVERSCAN.
  if (color.a < 0) {
		color = texture(renderedTexture, uv);
  }
   
  #if ENABLE_BLOOM
  color.rgb = bloom(color.rgb, uv);
  #endif
  
  #if ENABLE_BLUR
  color.rgb = blur(color.rgb, uv);
  #endif
  
  #if ENABLE_GRAYSCALE
  color.rgb = grayscale(color.rgb);
  #endif
  
  #if ENABLE_BLACKLEVEL
  color.rgb = blacklevel(color.rgb);
  #endif
  
  #if ENABLE_REFRESHLINE
  color.rgb = refreshLines(color.rgb, screenuv);
  #endif
  
  #if ENABLE_SCANLINES
  color.rgb = scanlines(color.rgb, pos);
  #endif
  
  #if ENABLE_TINT
  color.rgb = tint(color.rgb);
  #endif
  
  #if ENABLE_GRAIN
  color.rgb = grain(color.rgb, screenuv);
  #endif
  
	FragColor = color;
//-- Shader goes here --//
}
