// AngelShader (Mario-Madness/source/AngelShader.hx), ported to a Codename
// Engine camera shader - the mod's 'angel' CustomShader.
//
// The source is a Psych `FlxShader` applied to camGame and camHUD through
// `setFilters`; here it is added with `camGame.addShader()` / `camHUD.addShader()`.
// Nothing of the GLSL changed except the uv handling: Codename camera shaders
// sample in camera space (`getCamPos` in, `textureCam` back), which is the
// identity mapping when the camera renders to its own texture (see
// assets/shaders/engine/CompatabilityGuide.md).
//
// Uniforms, set from data/stages/virtual.hx:
//   stronk - glitch strength, `AngelShader.strength` (0 = a no-op pass)
//   pixel  - the mosaic size, `AngelShader.pixelSize` (1 = pixel-perfect)
//   iTime  - seconds, `angel.data.iTime.value = [Conductor.songPosition / 1000]`
#pragma header

uniform float stronk;
uniform float iTime;
uniform vec2 pixel;

const bool allowWiggle = true;

vec2 uvp(vec2 uv) {
	return clamp(uv, 0.0, 1.0);
}

float rand(vec2 co) {
	return fract(sin(dot(co.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

void main() {
	vec2 base = getCamPos(openfl_TextureCoordv);
	vec3 col;
	float amp = stronk;

	// Three passes, one per channel: pass i only keeps its own channel, which is
	// what tears the picture into a red / green / blue ghost.
	for (int i = 0; i < 3; i++) {
		vec2 size = openfl_TextureSize.xy / pixel;
		vec2 uv = floor(base.xy * size) / size;

		if (allowWiggle)
			uv += vec2(sin(float(i) * amp), cos(float(i) * amp)) * amp * 0.05;

		vec3 texOrig = textureCam(bitmap, uvp(uv)).rgb;

		// The offset grows with the channel's own brightness, so dark pixels
		// stay put and the bright ones smear sideways.
		uv.x += (rand(vec2(uv.y + float(i), iTime)) * 2.0 - 1.0) * amp * 0.8 * (texOrig[i] + 0.2);
		uv.y += (rand(vec2(uv.x, iTime + float(i))) * 2.0 - 1.0) * amp * 0.1 * (texOrig[i] + 0.2);

		vec3 tex = textureCam(bitmap, uvp(uv)).rgb;

		tex += abs(tex[i] - texOrig[i]);
		tex *= rand(uv) * amp + 1.0;

		col[i] = tex[i];
	}

	gl_FragColor = vec4(col, textureCam(bitmap, base).a);
}
