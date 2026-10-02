// VCRBorder (Mario-Madness/source/VCRBorder.hx) as a Codename camera shader -
// the mod's 'vcrBorder' CustomShader. `border` in PlayState.hx.
//
// It is the last filter the source stacks on every camera (5661/5678/5682): the
// barrel curve that bows the picture inward and the cosine vignette that darkens
// the corners, which is what reads as a curved CRT tube. No uniforms - the
// `update()` it has nothing to feed - so it is mounted once and left alone.
//
// Same uv handling as the source; only the sampling moved to Codename's camera
// space (`getCamPos` in, `textureCam` back). The out-of-range branch is the
// source's own: the curve pushes the corners past the texture, and those samples
// are painted black rather than being clamped into a smear.
#pragma header

vec2 curve(vec2 uv) {
    uv = (uv - 0.5) * 2.0;
    uv *= 1.1;
    uv.x *= 1.0 + pow((abs(uv.y) / 5.0), 2.0);
    uv.y *= 1.0 + pow((abs(uv.x) / 4.0), 2.0);
    uv  = (uv / 2.0) + 0.5;
    uv =  uv *0.92 + 0.04;
    return uv;
}

float vignette(vec2 uv) {
    uv = (uv - 0.5) * 0.98;
    return clamp(pow(cos(uv.x * 3.1415), 2.5) * pow(cos(uv.y * 3.1415), 2.5) * 100.0, 0.0, 1.0);
}

void main() {
    vec2 uv = getCamPos(openfl_TextureCoordv);
    uv = curve(uv);
    vec3 color = textureCam(bitmap, uv).rgb;
    float alpha = textureCam(bitmap, uv).a;
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
        color = vec3(0.0, 0.0, 0.0);
    }
    gl_FragColor = vec4(color * vignette(uv), alpha);
}
