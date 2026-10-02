// Camera follow + zoom, ported from Mario's Madness
// assets/preload/data/songData/nourishing-blood/script.lua.
var followchars = true;
var xx = 120;   var yy = 650;  var yyh = 350;
var xx2 = 1120; var yy2 = 750;
var ofs = 30;

function update(elapsed:Float) {
	if (!followchars) {
		camFollow.x = 800;
		camFollow.y = -1000;
		return;
	}

	var c = null; var bx = 0; var by = 0;
	switch (curCameraTarget) {
		case 1: c = boyfriend; bx = xx2; by = yy2;
		default: c = dad; bx = xx; by = yy;
	}
	if (c == null) return;

	var anim = c.getAnimName();
	if (anim == null) return;

	var dx = 0; var dy = 0;
	switch (anim) {
		case "singLEFT" | "singLEFT-alt": dx = -ofs;
		case "singRIGHT" | "singRIGHT-alt": dx = ofs;
		case "singUP" | "singUP-alt": dy = -ofs;
		case "singDOWN" | "singDOWN-alt": dy = ofs;
		case "Hey": dx = -ofs; by = yyh;
	}
	camFollow.x = bx + dx;
	camFollow.y = by + dy;
}

function beatHit(curBeat) {
	if (curBeat >= 4 && curBeat <= 228) { camGame.zoom += 0.01; camHUD.zoom += 0.03; }
	if (curBeat >= 244 && curBeat <= 359) { camGame.zoom += 0.01; camHUD.zoom += 0.03; }
	if (curBeat >= 392 && curBeat <= 404) { camGame.zoom += 0.01; camHUD.zoom += 0.03; }
}
