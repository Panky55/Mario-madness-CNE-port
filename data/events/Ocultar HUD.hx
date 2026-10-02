// 'Ocultar HUD' - fades the HUD camera in/out. Ported from Mario's Madness
// (source/PlayState.hx: 0 = hide, 1 = instant show, 2 = fade in).
function onEvent(event) {
	if (event.event.name != "Ocultar HUD") return;
	var mode = Std.parseInt(event.event.params[0]);
	if (mode == null || Math.isNaN(mode)) mode = 0;
	switch (mode) {
		case 0:
			FlxTween.tween(camHUD, {alpha: 0}, 0.5, {ease: FlxEase.quadInOut});
		case 1:
			FlxTween.tween(camHUD, {alpha: 1}, 0.001, {ease: FlxEase.quadInOut});
		case 2:
			FlxTween.tween(camHUD, {alpha: 1}, 0.5, {ease: FlxEase.quadInOut});
	}
}
