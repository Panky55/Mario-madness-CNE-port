// Camera zoom / shake, ported from Mario's Madness
// assets/preload/data/songData/paranoia/script.lua.
function beatHit(curBeat) {
	if (curBeat >= 48 && curBeat <= 112) { camGame.zoom += 0.005; camHUD.zoom += 0.03; }

	if (curBeat >= 112 && curBeat <= 141 && curBeat % 2 == 0) { camGame.zoom += 0.015; camHUD.zoom += 0.03; }
	if (curBeat == 142) defaultCamZoom = 0.9;
	if (curBeat >= 144 && curBeat <= 176 && curBeat % 2 == 0) { camGame.zoom += 0.015; camHUD.zoom += 0.03; }

	if (curBeat >= 112 && curBeat <= 175 && curBeat % 8 == 0) {
		camGame.shake(0.002, 0.35);
		camHUD.shake(0.002, 0.35);
	}

	if (curBeat == 245) {
		defaultCamZoom = 0.6;
		camFollow.x = 1470;
		camFollow.y = 60;
	}

	if (curBeat >= 258 && curBeat <= 324) { camGame.zoom += 0.00625; camHUD.zoom += 0.03; }
	if (curBeat >= 372 && curBeat <= 434) { camGame.zoom += 0.005; camHUD.zoom += 0.03; }
	if (curBeat >= 436 && curBeat <= 500) { camGame.zoom += 0.005; camHUD.zoom += 0.03; }
}
