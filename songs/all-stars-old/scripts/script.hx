// Camera follow / zoom, ported from Mario's Madness
// assets/preload/data/songData/all-stars-old/script.lua (the "act" system).
var act = 1;
var xx = 220;   var yy = 450;
var xx2 = -420; var yy2 = 150;
var ofs = 30;   var ofs2 = 60;
var zoom1 = 0.6; var zoom2 = 0.35;
var followchars = true;
var zoomchars = true;

function mmOldCam(which, args) {
	var api = PlayState.instance.scripts.get("mmCamera");
	if (api == null || !Reflect.hasField(api, which)) return;
	Reflect.callMethod(api, Reflect.field(api, which), args);
}

function update(elapsed:Float) {
	if (!followchars) return;

	var c = null; var bx = 0; var by = 0; var o = 0;
	if (curCameraTarget == 1) {
		c = boyfriend; bx = xx; by = yy; o = ofs;
		if (zoomchars) defaultCamZoom = zoom1;
	} else {
		c = dad; bx = xx2; by = yy2; o = ofs2;
		if (zoomchars) defaultCamZoom = zoom2;
	}
	if (c == null) return;

	var anim = c.getAnimName();
	if (anim == null) return;

	var dx = 0; var dy = 0;
	switch (anim) {
		case "singLEFT" | "singLEFT-alt": dx = -o;
		case "singRIGHT" | "singRIGHT-alt": dx = o;
		case "singUP" | "singUP-alt": dy = -o;
		case "singDOWN" | "singDOWN-alt": dy = o;
	}
	camFollow.x = bx + dx;
	camFollow.y = by + dy;
}

function beatHit(curBeat) {
	if (curBeat == 264) { zoom2 = 2; xx2 = 480; yy2 = -180; }
	if (curBeat == 268) act = 2;
	if (curBeat == 396) act = 2.5;
	if (curBeat == 328) {
		followchars = false; zoomchars = false;
		FlxTween.tween(camHUD, {alpha: 0.7}, 0.5, {ease: FlxEase.quadInOut});
		mmOldCam("lock", [xx2, yy2 - 300, 1.6, FlxEase.quadIn]);
	}
	if (curBeat == 332) {
		followchars = true; zoomchars = true;
		mmOldCam("release", []);
		FlxTween.tween(camHUD, {alpha: 1}, 0.5, {ease: FlxEase.quadOut});
	}
	if (curBeat == 580) { act = 3; xx2 = -800; yy2 = 300; zoom2 = 0.7; ofs2 = 20; ofs = 20; }
	if (curBeat == 586) {
		followchars = false; zoomchars = false;
		mmOldCam("lock", [xx2, yy2, 5, FlxEase.quadInOut]);
		mmOldCam("zoom", [zoom2, 5, 0, FlxEase.quadInOut]);
	}
	if (curBeat == 604) {
		followchars = true; zoomchars = true;
		xx2 = -400; yy2 = 300; zoom2 = 0.6;
		mmOldCam("release", []);
	}
	if (curBeat == 668) { ofs2 = 80; ofs = 60; }
	if (curBeat == 844) { act = 3.5; zoomchars = false; }

	// Beat-synced camera zoom chains from the source script.
	if (curBeat >= 300 && curBeat <= 331) { camGame.zoom += 0.015; camHUD.zoom += 0.03; }
	if (curBeat >= 364 && curBeat <= 395) { camGame.zoom += 0.016; camHUD.zoom += 0.03; }
	if (curBeat >= 426 && curBeat <= 472) { camGame.zoom += 0.016; camHUD.zoom += 0.03; }
	if (curBeat >= 476 && curBeat <= 491) { camGame.zoom += 0.016; camHUD.zoom += 0.03; }
	if (curBeat >= 508 && curBeat <= 523) { camGame.zoom += 0.016; camHUD.zoom += 0.03; }
	if (curBeat >= 540 && curBeat <= 556) { camGame.zoom += 0.016; camHUD.zoom += 0.03; }

	if (curBeat % 4 == 0) {
		if (curBeat >= 396 && curBeat <= 424) { camGame.zoom += 0.032; camHUD.zoom += 0.03; }
		if (curBeat >= 460 && curBeat <= 472) { camGame.zoom += 0.032; camHUD.zoom += 0.03; }
		if (curBeat >= 492 && curBeat <= 507) { camGame.zoom += 0.032; camHUD.zoom += 0.03; }
		if (curBeat >= 524 && curBeat <= 539) { camGame.zoom += 0.052; camHUD.zoom += 0.06; }
	}
	if (curBeat % 2 == 0 && curBeat >= 268 && curBeat <= 299) { camGame.zoom += 0.024; camHUD.zoom += 0.03; }
}
