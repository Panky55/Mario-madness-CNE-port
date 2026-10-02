// MosaicShader (Mario-Madness/source/openfl/MosaicShader.hx), the shader behind
// SMWPixelBlurShader - `effect` in PlayState.hx. It is Paranoia's CRT boot-up:
// the source arms it at 40 blocks and eases back to 1 over 0.7s as the intro
// stinger plays (PlayState.hx:6376).
//
// Same maths as the source (`openfl_TextureSize / uBlocksize` blocks per screen,
// so `uBlocksize` is the block's size in pixels and 1 is a no-op), with the
// camera-space uv handling Codename camera shaders use, and the centered
// quantisation the engine's own pixel shaders apply.
#pragma header

uniform vec2 uBlocksize;

void main() {
	vec2 uv = getCamPos(openfl_TextureCoordv);
	vec2 blocks = openfl_TextureSize / uBlocksize;

	uv -= vec2(0.5, 0.5);
	uv = floor(uv * blocks) / blocks;
	uv += vec2(0.5, 0.5);

	gl_FragColor = textureCam(bitmap, uv);
}
