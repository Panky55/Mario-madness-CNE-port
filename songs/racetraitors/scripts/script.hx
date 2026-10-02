// Camera follow + zoom, ported from Mario's Madness
// assets/preload/data/songData/racetraitors/script.lua.
//
// The lua is the stock "camera follows whoever is singing" loop: dad at
// (420, 450) and BF at (720, 450), each nudged 30px towards the direction of
// the sing, with dad's 'Hey' pose pulling up to y 350. `ofs2`/`del`/`del2` are
// declared in the source and never used (`ofs2` is even 120 while every branch
// uses `ofs`), and its `else triggerEvent('Camera Follow Pos','','')` is dead -
// nothing ever sets `followchars` false - so neither is reproduced here.
//
// Same shape as songs/nourishing-blood/scripts/script.hx: read the current
// camera target's character through `curCameraTarget` (1 = BF, the source's
// `mustHitSection`) and drive `camFollow` directly.
var xx = 420;  var yy = 450;  var yyh = 350;
var xx2 = 720; var yy2 = 450;
var ofs = 30;

function update(elapsed:Float) {
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
		// Dad's 'Hey' is the one pose that changes the row: (xx - ofs, yyh).
		case "Hey":
			dx = -ofs;
			dy = yyh - yy;
	}
	camFollow.x = bx + dx;
	camFollow.y = by + dy;
}

// 196-260: a 0.01 game-camera bump every beat.
function beatHit(curBeat) {
	if (curBeat >= 196 && curBeat <= 260) { camGame.zoom += 0.01; camHUD.zoom += 0.03; }
}
