// Camera zoom + shakes, ported from Mario's Madness
// assets/preload/data/songData/no-hope/script.lua (`onBeatHit`).
//
// The source's 'Add Camera Zoom' value1 is the *game* camera's bump and value2
// the HUD camera's (the same split as data/events/Add Camera Zoom), and its
// 'Screen Shake' value1/value2 are "duration, intensity" for camGame/camHUD -
// so the shake arguments are (intensity, duration), which is the order
// data/events/Screen Shake.hx uses.
function beatHit(curBeat) {
	if (curBeat % 2 == 0) {
		// 128-208: a bump every other beat...
		if (curBeat >= 128 && curBeat <= 208) { camGame.zoom += 0.02; camHUD.zoom += 0.03; }
		// ...and from 144 on, a shake with it.
		if (curBeat >= 144 && curBeat <= 208) {
			camGame.zoom += 0.02; camHUD.zoom += 0.03;
			camGame.shake(0.003, 0.27);
			camHUD.shake(0.0015, 0.27);
		}
		if (curBeat >= 400 && curBeat <= 455) { camGame.zoom += 0.02; camHUD.zoom += 0.03; }
	}

	// Every fourth beat the bump is bigger and hits both cameras.
	if (curBeat % 4 == 0) {
		if (curBeat >= 216 && curBeat <= 276) { camGame.zoom += 0.04; camHUD.zoom += 0.01; }
		if (curBeat >= 456 && curBeat <= 552) { camGame.zoom += 0.04; camHUD.zoom += 0.01; }
	}

	// 280-344: every beat, a bump and a harder shake than the 144-208 one.
	if (curBeat >= 280 && curBeat <= 344) {
		camGame.zoom += 0.02; camHUD.zoom += 0.03;
		camGame.shake(0.004, 0.27);
		camHUD.shake(0.002, 0.27);
	}
}
