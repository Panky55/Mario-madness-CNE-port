// YCBUEndingShader (Mario-Madness/source/YCBUEndingShader.hx) as a Codename
// camera shader - the mod's 'ycbuEnding' CustomShader. `beatend` in PlayState.hx.
//
// The source is a Psych `FlxShader` that only `case 'nesbeat'` creates (5664):
// it splits the picture's channels and slides them sideways in bands, so the
// frame tears into red / green / blue (the "You Cannot Beat Us" ending). It is
// mounted on camGame (5666); its own `update(amount, elapsed)` ramps the
// `intensity` uniform and advances `seed`, and PlayState only calls that while
// `endingnes` is set (7282-7286).
//
// Two adaptations from the source's GLSL, both forced by Codename compiling at
// `#version 120` (the same reason shaders/oldTv.frag rewrites its prng):
//
//   * the prng - the source hashes a `uvec3` with `>>` and `^` on unsigned ints
//     (`const uint k = 1103515245U`), which needs GLSL 130 / GL_EXT_gpu_shader4.
//     It is replaced by the float hash oldTv.frag uses, with the same contract -
//     a vec3 in, three [0,1) values out - and the input floored first, because
//     the source's `uvec3(...)` conversion truncated its components to whole
//     numbers.
//   * `round()` is GLSL 130; `floor(x + 0.5)` is the same for the non-negative
//     glitch values used here.
//
// Sampling is Codename's camera space (`getCamPos` in, `textureCam` back), the
// same move the other camera shaders here make.
//
// Uniforms, set from data/stages/nesbeat.hx:
//   seed      - starts at a random value and only advances while `endingnes`
//   intensity - 0 = the frozen channel split, ramping to 1 for the full static
#pragma header

#define LINES1 16.0
#define LINES2 32.0
#define LINES3 6.0
#define MAX_LINES 20.0

uniform float seed;
uniform float intensity;

//float version of the source's integer hash (see the header)
float hash1(vec3 p3) {
    p3 = fract(p3 * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

vec3 hash(vec3 x) {
    x = floor(x);
    return vec3(
        hash1(x),
        hash1(x + vec3(19.19, 7.77, 3.33)),
        hash1(x + vec3(5.51, 13.13, 23.23)));
}

float offset(vec2 co) {
    if (intensity < 0.6) return 0.0;
    return sin(co.y * (intensity - 0.6) * (intensity - 0.6));
}

float random(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

float glitch(vec2 uv, float lines, float r) {
    float y = floor(uv.y * lines) / lines;
    return random(vec2(r, y)) * (0.5 + (intensity * MAX_LINES) * 0.01);
}

void main() {
    vec2 uv = getCamPos(openfl_TextureCoordv);
    vec2 fragCoord = openfl_TextureSize * uv;
    uv = vec2(uv.x + offset(vec2(fragCoord.x, sin(mod(fragCoord.y, 200.0) / 15.84))), uv.y);
    float gl1 = glitch(uv, LINES1, floor(seed * 2.0));
    float gl2 = glitch(uv, LINES2, floor(seed * 5.0));
    float gl3 = glitch(uv, LINES3, floor(seed));
    float d1 = floor(gl1 + 0.5) * gl1;
    float d2 = floor(gl2 + 0.5) * gl2;
    float d3 = floor(gl3 + 0.5) * (0.75 - gl3);

    uv.x += d1;
    uv.x -= d2;
    uv.x += d3;

    float r = textureCam(bitmap, uv + (d1 - d2 + d3) / 6.0).r;
    float g = textureCam(bitmap, uv).g;
    float b = textureCam(bitmap, uv - (d1 - d2 + d3) / 6.0).b;
    gl_FragColor = vec4(r, g, b, 1);
    if (intensity > 0.5) {
        gl_FragColor = mix(gl_FragColor, vec4(hash(vec3(fragCoord.xy, seed * 100.0)), 1), (intensity - 0.5) / 0.5);
        float finalCol = gl_FragColor.r * 0.59 + gl_FragColor.g * 0.3 + gl_FragColor.b * 0.11;
        gl_FragColor = mix(gl_FragColor, vec4(finalCol, finalCol, finalCol, 1), (intensity - 0.5) / 0.5);
    }
}
