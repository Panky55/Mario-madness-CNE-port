// CamDupeShader (Mario-Madness/source/CamDupeShader.hx), ported to a Codename
// Engine camera shader - the mod's 'camDupe' CustomShader.
//
// The source is a Psych `FlxShader` in camGame's filter list; here it is added
// with `camGame.addShader()`. The tiling maths is the source's, unchanged:
//
//   multi   - how many times the screen is tiled (1 = untouched)
//   mirrorS - flip every other tile horizontally on the way back down
//
// Only difference: `mirrorS` is a float instead of the source's `bool`
// (`if (mirrorS)`), so it is set as [0.0] / [1.0] from data/stages/virtual.hx -
// Codename's shader backend takes float uniforms on every platform, while a
// bool uniform's value packing is renderer dependent.
//
// Note the source's first line is a no-op - `openfl_TextureCoordv *
// openfl_TextureSize / openfl_TextureSize.xy` is just `openfl_TextureCoordv` -
// so the tiling has always been anchored to the top-left of the screen.
#pragma header

uniform float multi;
uniform float mirrorS;

void main() {
	vec2 uv = getCamPos(openfl_TextureCoordv);
	uv *= multi;
	uv = fract(uv);
	if (mirrorS > 0.5)
		uv.x = (0.0 - uv.x) + 1.0;

	vec3 duplicate = vec3(mod(floor(uv.x) + floor(uv.y), 1.0));
	vec3 color = vec3(textureCam(bitmap, uv)) * (1.0 - duplicate);

	gl_FragColor = vec4(color, textureCam(bitmap, uv).a);
}
