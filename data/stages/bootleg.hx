// Ported from PlayState.hx beatHit() (case 'bootleg').
// The gang idles every beat and the START sign blinks on/off each beat.
function beatHit(curBeat:Int) {
	startbutton.visible = !startbutton.visible;
	thegang.playAnim('idle', true);
}

// === MM stage triggers (auto) ===
// 'Triggers Nourishing Blood' (and 'Triggers Grand Dad') - ported from
// PlayState.hx's two copies of this group: the live 'Triggers Nourishing Blood'
// block (10380-10650) and `case 'Triggers Grand Dad' | 'Triggers Nourishing
// Blood'` (12161+). Haxe takes the first matching case, so the Nourishing Blood
// name always runs the 10380 copy and only 'Triggers Grand Dad' reaches 12161;
// the two differ in case 0 alone, which is why the handler branches on the name.
// The cave/normal character swaps are performed here because they are fired
// by the source handler, not chart Change Character events. gdRunners remains
// an open gap (the source's custom GrandDadRunners group).
//
// Camera: the source's create block leaves FOLLOWCHARS = false (2241) with a
// snapCamFollowToPos(850, -930) (5851), so the stage opens on a frozen camera -
// MMcamera's mmInit reproduces both. The trigger cases below then move the
// camera *targets* (DAD_CAM_X/Y, BF_CAM_X/Y) and toggle FOLLOWCHARS back on
// (case 4), which is the one path that makes those targets visible, so they go
// through the same api (data/songs/MMcamera.hx).
//
// The fork's beat pulse while `blockzoom` is set (16151-16154) is
// `songs/MMcamera.hx`'s `beatHit`: it owns camGame/camHUD's zoom here, and the
// gate this stage sets through mmCamera.blockZoom is what arms it.
//
// The stage's opening blackout is in *The opening* below (the source builds it
// inside the countdown branch, 6297-6312, which this stage's `noCount`
// replacement otherwise skips).
var mmHudTween = null;
var mmNBChars = [[], [], []];

// Keep previously used characters, as the fork's boyfriendMap/dadMap/gfMap do.
function mmNBSwap(index, name, x, y) {
	var line = strumLines.members[index];
	if (line == null || line.characters.length == 0) return;
	var old = line.characters[0];
	if (old.curCharacter == name) {
		old.x = x;
		old.y = y;
		return;
	}
	if (mmNBChars[index].indexOf(old) < 0) mmNBChars[index].push(old);
	var fresh = null;
	for (c in mmNBChars[index]) if (c.curCharacter == name) fresh = c;
	if (fresh == null) {
		fresh = new Character(0, 0, name, old.isPlayer);
		stage.applyCharStuff(fresh, line.data.position, 0);
		mmNBChars[index].push(fresh);
	} else {
		insert(members.indexOf(stage.characterPoses.get(line.data.position)), fresh);
	}
	remove(old, true);
	line.characters[0] = fresh;
	fresh.gameOverCharacter = old.gameOverCharacter;
	fresh.x = x;
	fresh.y = y;
	var icon = index == 0 ? iconP2 : (index == 1 ? iconP1 : null);
	if (icon != null) icon.setIcon(fresh.getIcon());
}

function onCountdown(event) {
	// PlayState.hx:2240, noCount.
	event.cancelled = true;
}

// ---------------------------------------------------------------------------
// The opening (6297-6312)
// ---------------------------------------------------------------------------
// `noCount` (2240) means the source's countdown branch never shows READY/SET/GO
// - it shows this instead: a black plate on **camOther** (above camHUD, so it
// covers the HUD too), faded out over half a second starting 1.4s in, while the
// camera pulls back to 0.6 over two beats from 1.8s, with the 'gdstart' cue at
// full volume. Codename has no camOther, so the port adds a camera of its own
// last in `FlxG.cameras.list` - the same shape piracy.hx's `drawspot` layer
// uses - which composites above camHUD. The zoom goes through `songs/MMcamera`'s
// api (`mmCam("zoom", ...)`), not a raw camGame tween: the source's tween lands
// because its own camZooming bounce is still off at song start (`camZooming`
// only turns on after an opponent note, 8378-8382), while this engine eases
// camGame.zoom towards defaultCamZoom every frame, so a raw write here is
// overwritten before it is ever seen. The api drives both fields, which is the
// closest spelling of the fork's own resting state.
var mmOther:FlxCamera = null;

function mmGetOther():FlxCamera {
	if (mmOther == null) {
		mmOther = new FlxCamera(0, 0, FlxG.width, FlxG.height);
		mmOther.bgColor = FlxColor.TRANSPARENT;
		mmOther.zoom = 1;
		FlxG.cameras.add(mmOther, false); // defaultDraw=false -> world not redrawn
	}
	return mmOther;
}

var mmOpenBlack = null;
var mmOpenDone:Bool = false;

function mmBootlegOpening() {
	if (mmOpenDone) return;
	mmOpenDone = true;

	mmOpenBlack = new FlxSprite(0, 0);
	mmOpenBlack.makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
	mmOpenBlack.scale.set(10, 10);
	mmOpenBlack.scrollFactor.set(0, 0);
	mmOpenBlack.alpha = 1;
	mmOpenBlack.cameras = [mmGetOther()];
	add(mmOpenBlack);

	FlxTween.tween(mmOpenBlack, {alpha: 0}, 0.5, {startDelay: 1.4, ease: FlxEase.quadInOut});
	mmCam("zoom", [0.6, 2 * (1 / (Conductor.bpm / 60)), 1.8, FlxEase.expoOut]);
	FlxG.sound.play(Paths.sound('gdstart'), 0.6);
}

function onSongStart() {
	mmBootlegOpening();
}

function postCreate() {
	// 2241/noHUD: the chart brings the HUD back at its first notes.
	camHUD.alpha = 0;
	// 2245-2248: blue makeGraphic backdrop, before every stage sprite.
	var blue = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xFF155FD9);
	blue.scale.x = 10;
	blue.scale.y = 10;
	blue.scrollFactor.x = 0;
	blue.scrollFactor.y = 0;
	insert(members.indexOf(startbutton), blue);
}

function mmCam(which:String, args:Array<Dynamic>):Dynamic {
	// songs/MMcamera.hx publishes its api through CnE's ScriptPack
	// (`PlayState.instance.scripts.set/get`), the engine's own cross-script
	// channel. It cannot be a `Reflect.setProperty(PlayState.instance, ...)`
	// field: Haxe's Reflect on cpp only touches fields that already exist and
	// throws `Invalid field:<name>` otherwise (see the note in MMcamera.hx).
	var ps = PlayState.instance;
	if (ps == null || ps.scripts == null) return null;
	var api:Dynamic = ps.scripts.get("mmCamera");
	if (api == null) return null;
	if (!Reflect.hasField(api, which)) return null;
	return Reflect.callMethod(api, Reflect.field(api, which), args);
}

function onEvent(event) {
	if (event.event.name != "Triggers Nourishing Blood" && event.event.name != "Triggers Grand Dad" && event.event.name != "Triggers Universal") return;
	var trigger = Std.parseInt(event.event.params[0]);
	if (trigger == null || Math.isNaN(trigger)) trigger = 0;

	switch (trigger) {
		case 0:
			FlxG.camera.flash(FlxColor.WHITE, 0.5);
			flintbg.visible = true;
			flintwater.visible = true;
			thegang.visible = false;
			// Only case 0 differs between the group's two source copies (see the
			// header): 10380 has BF (1258, 480), GF (593, 393) and dad (-1, 556),
			// 12161 has BF (1263, 509.5), GF (597, 421) and dad (0, 560).
			var nb:Bool = (event.event.name != "Triggers Grand Dad");
			mmNBSwap(1, "bfcave", nb ? 1258 : 1263, nb ? 480 : 509.5);
			mmNBSwap(2, "gfcave", nb ? 593 : 597, nb ? 393 : 421);
			mmNBSwap(0, "grandcave", nb ? -1 : 0, nb ? 556 : 560);
			// 10400-10403 / 12186-12189: the camera targets move with the
			// characters (both source copies carry the same pair).
			mmCam("setCam", ["dad", 460, 750, null]);
			mmCam("setCam", ["bf", 810, 750, null]);
		case 1:
			mmNBSwap(1, "bfGD", 1270, 310);
			mmNBSwap(2, "gfGD", 500, 250);
			mmNBSwap(0, "grand", -200, 330);
			flintbg.visible = false;
			flintwater.visible = false;
			thegang.visible = true;
			// 10420-10423 / 12206-12209 - the preload's own bootleg row.
			mmCam("setCam", ["dad", 120, 650, null]);
			mmCam("setCam", ["bf", 1120, 750, null]);
		case 2:
			thegang.visible = true;
			thegang.scale.x = 0.1;
			thegang.scale.y = 0.5;
			FlxTween.tween(camGame, {zoom: 0.7}, 0.25, {ease: FlxEase.backOut});
			FlxTween.tween(thegang.scale, {x: 1, y: 1}, 0.25, {ease: FlxEase.backOut});
		case 3:
			FlxTween.tween(hamster, {y: -1700}, 0.15, {ease: FlxEase.sineOut});
			FlxTween.tween(hamster, {y: -330}, 0.25, {startDelay: 0.15, ease: FlxEase.sineIn});
			FlxTween.tween(hamster, {x: -400}, 0.33, {onComplete: function(twn) { hamster.visible = false; }});
		case 4:
			// 10440 / 12221 - a toggle, not a pair of cases: the camera alternates
			// between the scripted position and the section cameras every time the
			// chart sends it.
			mmCam("toggleFollow", []);
		case 5:
			// 10442-10452: the HUD pulse that goes with the camera zoom, and the
			// `blockzoom` gate the fork puts on its zoom lerp (7962).
			mmCam("blockZoom", [true]);
			var beatTime:Float = 1 * (1 / (Conductor.bpm / 60));
			FlxTween.tween(camHUD, {zoom: 1}, beatTime, {ease: FlxEase.elasticOut});
			if (mmHudTween != null) mmHudTween.cancel();
			mmHudTween = FlxTween.tween(camHUD, {angle: 0}, 2 * beatTime, {ease: FlxEase.quadOut});
		case 6:
			// 10455 (the source's `blockzoom = false`).
			mmCam("blockZoom", [false]);
		case 7:
			// 10460-10461: both the camera and its zoom target go to 0.8 on the
			// same expoIn curve over 1.9 beats, which is exactly what a drive does.
			mmCam("zoom", [0.8, 1.9 * (1 / (Conductor.bpm / 60)), 0, FlxEase.expoIn]);
	}
}
// === end MM stage triggers ===
