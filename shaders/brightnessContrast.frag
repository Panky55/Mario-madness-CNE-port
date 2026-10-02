// BrightnessContrastShader (Mario-Madness/source/BrightnessContrastShader.hx) as
// a Codename camera shader - the mod's 'brightnessContrast' CustomShader.
// `contrastFX` in PlayState.hx.
//
// The source is a Psych `FlxShader` created for every `tvEffect` + `oldTV` stage
// (5680) and prepended to camGame's filters (5682). On its own it is an identity
// pass - its defaults are `brightness = contrast = 1.0` - which is why the
// promotion and endstage ports leave it out. Wetworld's own 'Triggers Abandoned'
// 5/6 *do* write it (13200-13201 and 13218-13219: brightness 0.3 with contrast
// 2.0 as the TV intro ends, then back to 0.8/1.0 when the intro fades), so it is
// ported for that stage and fed from data/stages/wetworld.hx.
//
// Sampling is Codename's camera space (`getCamPos` in, `textureCam` back), the
// same move the other camera shaders here make; the arithmetic is the source's
// verbatim.
#pragma header

uniform float brightness;
uniform float contrast;

void main() {
    vec2 uv = getCamPos(openfl_TextureCoordv);
    gl_FragColor = textureCam(bitmap, uv);
    gl_FragColor.rgb = ((gl_FragColor.rgb - 0.5) * max(contrast, 0.)) + 0.5;
    gl_FragColor.rgb *= max(brightness, 0.);
}
