// OldTVShader (Mario-Madness/source/OldTVShader.hx) as a Codename camera shader -
// the mod's 'oldTv' CustomShader. `oldFX` in PlayState.hx.
//
// The source's worn-tape layer: it is mounted on camGame/camEst/camHUD (5676-5678)
// only when a stage sets `oldTV` *as well as* `tvEffect` - promoshow sets both
// (1818-1819). Per frame it pulls the picture into vertical rolling bands and
// offsets those bands horizontally by a noise amount, adds the 16-direction blur
// that makes the tape look soft, punches the black dropouts on the left edge and
// through the frame, mixes in the per-pixel static, and finishes on the white
// sploches that ride the brighter parts of the picture.
//
// One deviation from the source's GLSL is unconditional, and one fallback only
// exists for compilers that cannot express the source's prng:
//
//   * sampling - Codename camera shaders use `getCamPos` / `textureCam` to map
//     camera coordinates to the backing texture; identity at all zooms/sizes has
//     not been established by the compatibility guide or mocked tests.
//
// The source's prng is kept. It hashes a `uvec3` with `>>`/`^` on unsigned ints,
// which needs GLSL 1.30+, so the shader asks the compiler which version it is
// running at (`__VERSION__`, a built-in macro) and uses the source function
// verbatim wherever the compiler can take it - CNE's OpenGL fork assembles
// desktop shaders at `330 core`, so that is the normal path here. Compilers
// below 130 (the same fork uses 120 on macOS and 100 on web) cannot parse
// `uvec3`/`uint` at all, so they get the usual sine-free float hash (Dave
// Hoskins) with the same contract: a vec3 in, three [0,1) values out, floored
// first to keep the source's integer-sized cells - same cells, different
// sequence. Which branch the running build took is visible in the shader's
// first lines at compile time: `#version 330 core` + the unsigned version, or
// `#version 120`/`100` + the float fallback.
//
// Uniforms, set from data/stages/promoshow.hx (the source's `update()` at 7246
// through `OldTVShader.update`):
//   iTime - seeded once with process time at mount, then accumulated elapsed
//           seconds, exactly like the source's `OldTVShader.new()`
//           (`iTime.value = [Timer.stamp()]`) plus `update(elapsed)`. The
//           rolling-band and static phases therefore match the fork's own
//           start-of-song phase instead of always starting at 0.
#pragma header

#define id vec2(0.,1.)
#define PI 3.141592653
#define TAU PI * 2.

uniform float iTime;

#if __VERSION__ >= 130

// The source's prng, verbatim: https://stackoverflow.com/a/52207531
#define k 1103515245U
vec3 hash(vec3 x) {
    // The source wrote `hash(uvec3(0., uv.y * uvyMul, ...))` at every call site,
    // i.e. the float->uint constructor truncated each component to a whole
    // number before hashing. Converting here keeps every call site the same.
    uvec3 u = uvec3(x);
    u = ((u>>8U)^u.yzx)*k;
    u = ((u>>8U)^u.yzx)*k;
    u = ((u>>8U)^u.yzx)*k;
    return vec3(u)*(1.0/float(0xffffffffU));
}

#else

//prng func, source: https://stackoverflow.com/a/52207531 (integer version)
//float version: https://www.shadertoy.com/view/4djSRW
float hash1(vec3 p3) {
    p3 = fract(p3 * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

vec3 hash(vec3 x) {
    // The source handed these to a `uvec3`, so every component was truncated to a
    // whole number before hashing. That quantisation is part of the look: the
    // white sploches land on a ~20-cell grid across x, the black dropouts on ~100
    // rows, and the rolling band's offset is constant along each 1/100th of the
    // height. Without it the noise is per-pixel and reads as far busier - the
    // static flickers harder and the sploches come much faster than the source's.
    x = floor(x);
    return vec3(
        hash1(x),
        hash1(x + vec3(19.19, 7.77, 3.33)),
        hash1(x + vec3(5.51, 13.13, 23.23)));
}

#endif

void main() {
    bool flag = false;
    bool flag2 = false;

    vec2 uv = getCamPos(openfl_TextureCoordv);

    //picture offset
    float time = 2.0;
    float timeMod = 2.5;
    float repeatTime = 1.25;
    float lineSize = 50.0;
    float offsetMul = 0.01;
    float updateRate2 = 50.0;
    float uvyMul = 100.0;

    float realSize = lineSize / openfl_TextureSize.y / 2.0;
    float position = mod(iTime, timeMod) / time;
    float position2 = 99.;
    if (iTime > repeatTime) {
        position2 = mod(iTime - repeatTime, timeMod) / time;
    }
    if (!(uv.y - position > realSize || uv.y - position < -realSize)) {
        uv.x -= hash(vec3(0., uv.y * uvyMul, iTime * updateRate2)).x * offsetMul;
        flag = true;
    } else if (position2 != 99.) {
        if (!(uv.y - position2 > realSize || uv.y - position2 < -realSize)) {
            uv.x -= hash(vec3(0., uv.y * uvyMul, iTime * updateRate2)).x * offsetMul;
            flag = true;
        }
    }

    vec4 col = textureCam(bitmap, uv);

    //blur, from https://www.shadertoy.com/view/Xltfzj
    float directions = 16.0;
    float quality = 3.0;
    float size = 4.0;

    vec2 radius = size / openfl_TextureSize;
    for(float d = 0.0; d < TAU; d += TAU / directions) {
        for(float i= 1.0 / quality; i <= 1.0; i += 1.0 / quality) {
            col += textureCam(bitmap, uv + vec2(cos(d), sin(d)) * radius * i);
        }
    }
    col /= quality * directions - 14.0;

    //for the black on the left
    if (uv.x < 0.) {
        col = id.xxxy;
        flag = false;
        flag2 = true;
    }

    //randomized black shit and sploches
    float updateRate4 = 100.0;
    float uvyMul3 = 100.0;
    float cutoff2 = 0.92;
    float valMul2 = 0.007;

    float val2 = hash(vec3(uv.y * uvyMul3, 0., iTime * updateRate4)).x;
    if (val2 > cutoff2) {
        float adjVal2 = (val2 - cutoff2) * valMul2 * (1. / (1. - cutoff2));
        if (uv.x < adjVal2) {
            col = id.xxxy;
            flag2 = true;
        } else {
            flag = true;
        }
    }

    //static
    if (!flag2) {
        float updateRate = 100.0;
        float mixPercent = 0.05;
        col = mix(col, vec4(hash(vec3(uv * openfl_TextureSize, iTime * updateRate)).rrr, 1.), mixPercent);
    }

    //white sploches
    float updateRate3 = 75.0;
    float uvyMul2 = 400.0;
    float uvxMul = 20.0;
    float cutoff = 0.95;
    float valMul = 0.7;
    float falloffMul = 0.7;

    if (flag) {
        float val = hash(vec3(uv.x * uvxMul, uv.y * uvyMul2, iTime * updateRate3)).x;
        if (val > cutoff) {
            float offset = hash(vec3(uv.y * uvyMul2, uv.x * uvxMul, iTime * updateRate3)).x;
            float adjVal = (val - cutoff) * valMul * (1. / (1. - cutoff));
            adjVal -= abs((uv.x * uvxMul - (floor(uv.x * uvxMul) + offset)) * falloffMul);
            adjVal = clamp(adjVal, 0., 1.);
            col = vec4(mix(col.rgb, id.yyy, adjVal), col.a);
        }
    }

    gl_FragColor = col;
}
