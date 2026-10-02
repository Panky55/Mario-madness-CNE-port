// VCRMario85 (Mario-Madness/source/VCRMario85.hx) as a Codename camera shader -
// the mod's 'vcr85' CustomShader. `vcr` in PlayState.hx.
//
// The source is a Psych `FlxShader` applied to camGame/camEst/camHUD through
// `setFilters` whenever `tvEffect` is set (5647-5661); here it is added with
// each camera's own `addShader()`. Nothing of the GLSL changed except the
// sampling: Codename camera shaders use `getCamPos` / `textureCam` to map
// between camera and backing-texture coordinates. That mapping is not proven
// identity at every zoom/texture size; textureCam also applies Flixel's color
// transform where the source uses raw `texture`. Formula parity therefore does
// not establish identical pixels, especially on transparent camEst overlays.
//
// Uniforms, set from data/stages/promoshow.hx (the source's `update()` at 7241
// does the same through `VCRMario85.update`):
//   time - seconds since the effect was mounted, which is all the wobble, the
//          RGB split and the scanline need.
//
// The tape wobble is a per-scanline horizontal offset (fuzz + large fuzz), the
// split is the fixed +/-0.003 per-channel shift on top of it, and the scanline
// is the 800-cycle sine in the vertical uv.
#pragma header

uniform float time;

// Noise generation functions borrowed from:
// https://github.com/ashima/webgl-noise/blob/master/src/noise2D.glsl
// (mostly stolen from https://www.shadertoy.com/view/ldXGW4)

vec3 mod289(vec3 x) {
    return x - floor(x * (1.0 / 289.0)) * 289.0;
}

vec2 mod289(vec2 x) {
    return x - floor(x * (1.0 / 289.0)) * 289.0;
}

vec3 permute(vec3 x) {
    return mod289(((x*34.0)+1.0)*x);
}

float snoise(vec2 v)
{
    const vec4 C = vec4(0.211324865405187,  // (3.0-sqrt(3.0))/6.0
                        0.366025403784439,  // 0.5*(sqrt(3.0)-1.0)
                        -0.577350269189626,  // -1.0 + 2.0 * C.x
                        0.024390243902439); // 1.0 / 41.0
    // First corner
    vec2 i  = floor(v + dot(v, C.yy) );
    vec2 x0 = v -   i + dot(i, C.xx);

    // Other corners
    vec2 i1;
    //i1.x = step( x0.y, x0.x ); // x0.x > x0.y ? 1.0 : 0.0
    //i1.y = 1.0 - i1.x;
    i1 = (x0.x > x0.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
    // x0 = x0 - 0.0 + 0.0 * C.xx ;
    // x1 = x0 - i1 + 1.0 * C.xx ;
    // x2 = x0 - 1.0 + 2.0 * C.xx ;
    vec4 x12 = x0.xyxy + C.xxzz;
    x12.xy -= i1;

    // Permutations
    i = mod289(i); // Avoid truncation effects in permutation
    vec3 p = permute( permute( i.y + vec3(0.0, i1.y, 1.0 ))
            + i.x + vec3(0.0, i1.x, 1.0 ));

    vec3 m = max(0.5 - vec3(dot(x0,x0), dot(x12.xy,x12.xy), dot(x12.zw,x12.zw)), 0.0);
    m = m*m ;
    m = m*m ;

    // Gradients: 41 points uniformly over a line, mapped onto a diamond.
    // The ring size 17*17 = 289 is close to a multiple of 41 (41*7 = 287)

    vec3 x = 2.0 * fract(p * C.www) - 1.0;
    vec3 h = abs(x) - 0.5;
    vec3 ox = floor(x + 0.5);
    vec3 a0 = x - ox;

    // Normalise gradients implicitly by scaling m
    // Approximation of: m *= inversesqrt( a0*a0 + h*h );
    m *= 1.79284291400159 - 0.85373472095314 * ( a0*a0 + h*h );

    // Compute final noise value at P
    vec3 g;
    g.x  = a0.x  * x0.x  + h.x  * x0.y;
    g.yz = a0.yz * x12.xz + h.yz * x12.yw;
    return 130.0 * dot(m, g);
}

void main() {
    vec2 base = getCamPos(openfl_TextureCoordv);

    float fuzzOffset = snoise(vec2(time*15.0, base.y*80.0))*0.0005;
    float largeFuzzOffset = snoise(vec2(time*1.0, base.y*25.0))*0.001;
    float xOffset = (fuzzOffset + largeFuzzOffset);

    float red =   textureCam(bitmap, vec2(base.x + xOffset - 0.003, base.y)).r;
    float green = textureCam(bitmap, vec2(base.x + xOffset, base.y)).g;
    float blue =  textureCam(bitmap, vec2(base.x + xOffset + 0.003, base.y)).b;
    float alpha = textureCam(bitmap, vec2(base.x + xOffset, base.y)).a;

    vec3 color = vec3(red, green, blue);
    float scanline = sin(base.y*800.0)*0.04;
    color -= scanline;
    gl_FragColor = vec4(color, alpha);
}
