// Camera, ported from Mario's Madness
// assets/preload/data/songData/dark-forest/script.lua.
// NOTE: the "Triggers Dark Forest" values (4/6/7) drive stage effects that are
// hardcoded in the source PlayState.hx; they still need the forest stage script.
function stepHit(curStep) {
	if (curStep == 1052) {
		FlxTween.tween(camGame, {zoom: 1}, 0.5, {ease: FlxEase.cubeOut});
		FlxTween.tween(camHUD, {alpha: 0.5}, 0.10);
	}
	if (curStep == 1056) FlxTween.tween(camHUD, {alpha: 1}, 0.10);
	if (curStep == 1068) {
		FlxTween.tween(camGame, {zoom: 1}, 0.4, {ease: FlxEase.cubeOut});
		FlxTween.tween(camHUD, {alpha: 0}, 0.10);
	}
	if (curStep == 1072) FlxTween.tween(camHUD, {alpha: 1}, 0.10);
}
