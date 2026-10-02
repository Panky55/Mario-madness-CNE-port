// Camera follow, ported from Mario's Madness
// assets/preload/data/songData/i-hate-you-old/script.lua.
var followchars = true;
var xx = 220;  var yy = 450;  var yyh = 350;
var xx2 = 920; var yy2 = 550;
var ofs = 30;

function update(elapsed:Float) {
	if (!followchars) return;

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
