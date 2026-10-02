// Camera zoom, ported from Mario's Madness
// assets/preload/data/songData/i-hate-you/script.lua.
function beatHit(curBeat) {
	if (curBeat >= 48 && curBeat <= 96) { camGame.zoom += 0.008; camHUD.zoom += 0.03; }
	if (curBeat >= 100 && curBeat <= 226) { camGame.zoom += 0.008; camHUD.zoom += 0.03; }
	if (curBeat >= 228 && curBeat <= 356) { camGame.zoom += 0.008; camHUD.zoom += 0.03; }
}
