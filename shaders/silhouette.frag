// SilhouetteShader (Mario-Madness/source/SilhouetteShader.hx), ported to a
// Codename sprite shader - the mod's 'silhouette' CustomShader.
//
// The source is a Psych `FlxShader` set straight onto the characters
// (`boyfriend.shader` / `dad.shader`, PlayState.hx:4585-4589) and ramped by
// `transitionOGN()` (5949-5994). It is the 'Oh God No' look: the two fighters
// sink into a flat colour (BF into `col` = (255, 0, 59), dad into
// (20, 180, 0)) and climb back out again.
//
//   col    - the colour the sprite becomes (vec3, 0..1)
//   amount - how far along that is (0 = the sprite, 1 = flat `col`)
//
// Nothing of the GLSL changed. Sprite shaders sample with `flixel_texture2D`
// (the .colorTransform-aware sampler) rather than `texture2D` - see the
// engine's assets/shaders/engine/CompatabilityGuide.md. `amount` is driven from
// data/stages/hatebg.hx, which mirrors the source's own `update(amount1)`
// stepping.
#pragma header

uniform vec3 col;
uniform float amount;

void main() {
	vec4 orig = flixel_texture2D(bitmap, openfl_TextureCoordv);
	gl_FragColor = vec4(mix(orig.rgb, mix(vec3(0.0, 0.0, 0.0), col, orig.a), amount), orig.a);
}
