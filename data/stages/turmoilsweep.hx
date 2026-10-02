

// === MM stage triggers (auto) ===
// 'Turmoil Attack' - ported from PlayState.hx (case 'Turmoil Attack').
// The 'warning' and 'buttonxml' sprites are part of this stage's XML
// (data/stages/turmoilsweep.xml). Dodge immunity/cooldown and the player-line
// CPU guard are shared through songs/MMcamera.hx's mmDodge API.
//
// This stage is also **Last Course's**, and only that song uses it, so the stage
// script carries that group's stage-level half as well:
//
//   3301       `noCount = true` - the engine's READY/SET/GO are dropped
//              (onCountdown cancelled below), and with them the countdown
//              branch of 7857-7862, which is reproduced in onSongStart(): the
//              black curtain eases out over 4s after a one-second delay and
//              `buttonxml` fades out over 2s after a three-second delay.
//   4673-4679  `blackBarThingie` for luigiout/realbg/turmoilsweep/secretbg: a
//              full-screen black on camEst created at alpha **1**, so this stage
//              opens on black. camEst sits between camGame and camHUD, so the
//              port's stand-in is a screen-space sprite in front of the draw
//              list (`scrollFactor(0, 0)`, see execlassic.hx) - it covers the
//              stage and the fighters, which is what the fade-out reveals.
//   10565-10609 'Triggers Last Course' is **camera only** - every write in it is
//              a BF_CAM_X / camFollowPos / camGame.zoom / FOLLOWCHARS /
//              ZOOMCHARS one, all of which songs/MMcamera.hx owns
//              (mmLastCourseTrigger). The chart sends the group as 'Triggers
//              Universal', which this script used to answer with mmTurmoilAttack
//              - a leftover from before the group existed, and wrong: 'Turmoil
//              Attack' is its own chart event (the last-course chart fires 13 of
//              them) and Last Course's 'Triggers Universal' carries 0-8. The
//              two are separated below.
//
// The button is pressed on a dodge (not on note hits), starts visible for the
// opening instructions, and fades out on the source's three-second delay.
//
// `fogblack` (3333-3338) is the stage's third create-block sprite: the
// 'modstuff/126' vignette at alpha 1, on camEst, screen-centred. The source
// builds it *after* `warning` and adds `buttonxml` after it, and that order is
// the draw order - reproduced in postCreate below. Nothing ever tweens it here
// (realbg's copy of the same asset is the one triggers fade).

var mmCurtain = null;
var mmEstCam = null;
var mmButtonWasDodging = false;

function mmDodgeApi() {
	return PlayState.instance.scripts.get("mmDodge");
}

function mmEst() {
	if (mmEstCam == null) {
		mmEstCam = new FlxCamera(0, 0, FlxG.width, FlxG.height);
		mmEstCam.bgColor = FlxColor.TRANSPARENT;
		FlxG.cameras.add(mmEstCam, false);
		var list = FlxG.cameras.list;
		list.remove(mmEstCam);
		var at = list.indexOf(camHUD);
		list.insert(at < 0 ? list.length : at, mmEstCam);
	}
	return mmEstCam;
}

function postUpdate(elapsed) {
	var api = mmDodgeApi();
	var dodging = api != null && api.active();
	if (dodging && !mmButtonWasDodging && buttonxml != null) buttonxml.animation.play("press");
	mmButtonWasDodging = dodging;
}

// PlayState.hx:8577-8580: every singing turmoil1 opponent note drains .015,
// including sustain pieces, but the drain stops below .4 health.
function onNoteHit(event) {
	if (event.noteType != "No Animation" && event.noteType != "Bullet Bill" && event.noteType != "Bullet2"
		&& event.character != null && !event.character.isPlayer
		&& event.character.curCharacter == "turmoil1" && health >= 0.4)
		health -= 0.015;
}

function destroy() {
	if (mmEstCam != null) {
		FlxG.cameras.remove(mmEstCam, true);
		mmEstCam = null;
	}
}

var mmFogBlack = null;

function mmGetFogBlack() {
	if (mmFogBlack == null) {
		mmFogBlack = new FlxSprite(0, 0);
		mmFogBlack.loadGraphic(Paths.image("modstuff/126"));
		mmFogBlack.antialiasing = true; // ClientPrefs.globalAntialiasing, taken as on
		mmFogBlack.cameras = [mmEst()];
		mmFogBlack.alpha = 1;
		mmFogBlack.screenCenter();
		add(mmFogBlack);
	}
	return mmFogBlack;
}

function mmGetCurtain() {
	if (mmCurtain == null) {
		mmCurtain = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		mmCurtain.scale.set(10, 10); // source's setGraphicSize(width * 10)
		mmCurtain.scrollFactor.set(0, 0);
		mmCurtain.alpha = 1;
		add(mmCurtain);
	}
	return mmCurtain;
}

function onCountdown(event) {
	// `noCount = true` (3301): the source never builds its 3-2-1-GO sprites.
	event.cancelled = true;
}

function onSongStart() {
	// 7857-7862: the stage's opening, one beat after the song starts.
	FlxTween.tween(mmGetCurtain(), {alpha: 0}, 4, {startDelay: 1, ease: FlxEase.quadInOut});
	if (buttonxml != null) FlxTween.tween(buttonxml, {alpha: 0}, 2, {startDelay: 3, ease: FlxEase.quadInOut});
}

function postCreate() {
	// initial state from the source stage creation
	mmGetCurtain();
	if (gf != null) gf.visible = false;
	if (camHUD != null) camHUD.alpha = 0;

	// 4378-4380: the create switch lists this stage out of its `add(dadGroup)`
	// line (shared with directstream/piracy) and the foreground switch adds dad
	// *after* `add(boyfriendGroup)` instead - in the source he draws over the
	// player for the whole song. The port's characters sit at their XML markers,
	// so dad is spliced out and put back directly after the boyfriend.
	if (dad != null && boyfriend != null) {
		remove(dad, true);
		var i:Int = members.indexOf(boyfriend);
		insert(i >= 0 ? i + 1 : members.length, dad);
	}
	warning.cameras = [mmEst()];
	warning.screenCenter();
	warning.scale.x = 1; warning.scale.y = 1;
	mmGetFogBlack(); // 3333-3338, between `warning` and `buttonxml`
	buttonxml.cameras = [mmEst()];
	buttonxml.alpha = 1;
	// 3348: the source `add()`s `buttonxml` *after* the vignette, so on its
	// camEst the button draws over the black frame; both are ordinary stage
	// sprites here and the XML's own order would leave the button under it (the
	// vignette is a full-screen plate at alpha 1 with a transparent middle, so
	// the difference shows wherever the two overlap). The source's `add()` is
	// the splice-to-the-end this port uses everywhere else.
	remove(buttonxml, true);
	insert(members.length, buttonxml);

	// Let the 'Char Attack' event reach this stage attack. The hook goes through
	// CnE's ScriptPack (`scripts.set` / `scripts.get`), the engine's own
	// cross-script channel - the previous `Reflect.setProperty(PlayState.instance,
	// "onTrigger", ...)` logged `Invalid field:onTrigger` and threw (Haxe's
	// Reflect only touches fields that already exist), so the hook was never
	// registered and the event did nothing.
	if (PlayState.instance != null && PlayState.instance.scripts != null)
		PlayState.instance.scripts.set("onTrigger",
			function(name:String, v1:String, v2:String) {
				if (name == "Turmoil Attack") mmTurmoilAttack();
			});
}

function onEvent(event) {
	// 'Triggers Last Course' (and the generic 'Triggers Universal' the chart
	// sends it as) is camera only - songs/MMcamera.hx's mmLastCourseTrigger does
	// all of it, so there is nothing to do here.
	if (event.event.name != "Turmoil Attack") return;
	mmTurmoilAttack();
}

function mmTurmoilAttack() {
	var beat:Float = 1 / (Conductor.bpm / 60);

	FlxG.sound.play(Paths.sound('warningT2'));
	warning.alpha = 1;
	var wary:Float = warning.y;
	warning.y = wary - 50;
	warning.scale.set(0.7, 0.7);
	FlxTween.tween(warning, {y: wary, alpha: 0.2}, 0.5 * beat, {ease: FlxEase.expoOut});
	FlxTween.tween(buttonxml, {alpha: 1}, 0.2, {ease: FlxEase.quadOut});

	new FlxTimer().start(beat, function(tmr:FlxTimer) {
		FlxG.sound.play(Paths.sound('warningT2'));
		warning.alpha = 1;
		FlxTween.tween(warning.scale, {y: 0.8, x: 0.8}, 0.5 * beat, {ease: FlxEase.elasticOut});
		FlxTween.tween(warning, {alpha: 0.2}, 0.5 * beat, {ease: FlxEase.quadOut});
	});

	new FlxTimer().start(2 * beat, function(tmr:FlxTimer) {
		FlxG.sound.play(Paths.sound('warningT2'));
		warning.alpha = 1;
		FlxTween.tween(warning.scale, {y: 1, x: 1}, 0.5 * beat, {ease: FlxEase.elasticOut});
		FlxTween.tween(warning, {alpha: 0}, 0.5 * beat, {ease: FlxEase.quadOut});
	});

	new FlxTimer().start(0.2083 - (3 * beat), function(tmr:FlxTimer) {
		if (dad != null) dad.playAnim('preattack', true);
	});

	new FlxTimer().start(3 * beat, function(tmr:FlxTimer) {
		if (dad != null) dad.playAnim('attack', true);
		FlxG.sound.play(Paths.sound('TURMOIL-LENGUETAZO'));
		if (camGame != null) camGame.shake(0.007, 0.15);
		if (camHUD != null) camHUD.shake(0.007, 0.15);

		new FlxTimer().start(0.0483, function(tmr2:FlxTimer) {
			var api = mmDodgeApi();
			if (api != null && api.bot()) {
				buttonxml.animation.play("press");
				api.auto();
			} else if (api == null || !api.active()) {
				if (boyfriend != null) boyfriend.playAnim('singRIGHTmiss', true);
				FlxTween.tween(PlayState.instance, {health: health - 1.2}, 0.2, {ease: FlxEase.quadOut});
			}
		});

		FlxTween.tween(buttonxml, {alpha: 0}, 0.5 * beat, {startDelay: 0.5, ease: FlxEase.quadOut});
	});
}
// === end MM stage triggers ===
