// TVStatic (Mario-Madness/source/TitleScreenShaders.hx, class TVStatic) as a
// Codename camera shader - the mod's 'tvStatic' CustomShader. It is `staticShader`
// in PlayState.hx.
//
// Golden Land's create branch mounts it on camGame together with VCRBorder
// (1312-1316): `setFilters([new ShaderFilter(staticShader), new ShaderFilter(border)])`
// and sets `strengthMulti = 0.5`, `imtoolazytonamethis = 0.3`. The source's
// per-frame `staticShader.update(elapsed)` (7289-7290) only accumulates `iTime`.
//
// Nothing of the GLSL changed except the sampling: this port uses Codename's
// camera-space helpers (`getCamPos` in, `textureCam` back). Source-parity tests
// verify the noise math with that adaptation allowed; they do not prove that
// its UV mapping/GPU output is identical to Psych's full-camera ShaderFilter.
// Do not mistake a passing mocked test for a rendered visual comparison.
//
// Uniforms, set from data/stages/landstage.hx:
//   iTime                - seconds since the effect was mounted.
//   strengthMulti        - the source's 0.5.
//   imtoolazytonamethis  - the source's 0.3; it raises the static's floor.
#pragma header

uniform float iTime;
uniform float strengthMulti;
uniform float imtoolazytonamethis;

const float maxStrength = 0.8;
const float minStrength = 0.3;

const float speed = 20.0;

float random(vec2 noise) {
    return fract(sin(dot(noise.xy, vec2(10.998, 98.233))) * 12433.14159265359);
}

void main() {
    vec2 uv = getCamPos(openfl_TextureCoordv);
    vec2 uv2 = fract(uv * fract(sin(iTime * speed)));

    float _maxStrength = clamp(sin(iTime / 2.0), minStrength + imtoolazytonamethis, maxStrength) * strengthMulti;

    vec3 colour = vec3(random(uv2.xy) - 0.1) * _maxStrength;
    vec3 background = vec3(textureCam(bitmap, uv));

    gl_FragColor = vec4(background - colour, 1.0);
}
