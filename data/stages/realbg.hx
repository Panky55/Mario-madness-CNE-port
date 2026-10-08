

// === MM stage triggers (auto) ===
// 'Triggers Thalassophobia' - ported from PlayState.hx (case 'Triggers
// Thalassophobia', 13886-13947) plus everything else the stage carries:
//
//   3197-3199   `noCount`/`noHUD`/`specialGameOver` - the engine's READY/SET/GO
//               are dropped (`onCountdown` cancelled) and camHUD starts at alpha
//               0 (the chart's own 'Ocultar HUD' 2 brings it back at 9.42s).
//               `specialGameOver` has no Codename equivalent (a script cannot
//               swap the game-over substate); noted on the stage, not ported.
//   3231-3236   `fogblack` ('modstuff/126', a vignette) on camEst, alpha 1.
//   3238-3253   `lifemetter` - the nine-frame Luigi life meter on camHUD,
//               alpha 0, 2.2x, screen-centred.
//   4675-4681   `blackBarThingie` - a 10x-scaled black plate created at
//               **alpha 1**: the song opens on a black screen and trigger 3
//               (5.33s) is what fades it off. The source puts it on camEst; see
//               the Layers note for why this port puts it on camGame.
//   5836-5842   dad tinted 0xFF608B60, both icons hidden, enemyY = dad.y.
//   7511-7516   the per-frame drive: the meter's `life<luigilife>` animation
//               and the 1.7 health cap.
//   13905-13944 the trigger cases.
//   15641-15653 a hit 'Coin Note' adds a life (capped at 8) and bumps dad up;
//               the 'refill' sound is data/notes/Coin Note.hx's.
//   16746-16760 the beat drain: with `candrain` on (it starts on) and from beat
//               160, every 8th beat costs a life and drops dad by 50px, and
//               hitting 0 kills the player.
//
// Layers: Psych's camEst sits *between* camGame and camHUD (below the notes and
// the HUD), and the fog goes on a camera of this script's own slid in under
// camHUD. That camera now also re-asserts the order through
// `FlxG.cameras.setOrder` (mmSyncCameraOrder, see the note below it): a
// camera's flashSprite is a second half of its place that editing
// `FlxG.cameras.list` by hand never moved, so the layer drew over camHUD - and
// with it the falling notes - whatever the list said. The black plate itself
// stays on camGame: the chart blacks out at 96s and 170.67s with notes already
// falling, camGame is composited first under every mechanism there is, and the
// only thing that reaches over the plate is this stage's own black vignette -
// a black wash over black, so nothing is lost.
//
// Camera: data/songs/MMcamera.hx owns camFollow/defaultCamZoom for this stage
// (isCameraOnForcedPos is never read in the fork, and camFollow is rewritten by
// the section block every frame), so the cases that move the camera go through
// the api it publishes through the engine's ScriptPack instead of writing those
// fields.
// MMcamera's MM_START_CAM row carries this stage's `snapCamFollowToPos(1020,
// 650)`.
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

function mmDownscroll():Bool {
	// `PlayState.downscroll` is a get/set property over `camHUD.downscroll`; on
	// cpp `Reflect.field` returns null for get/set properties (only
	// `Reflect.getProperty`, which is what a script's field access compiles to,
	// runs the getter), so read the property itself rather than through Reflect.
	var d = (camHUD != null) ? camHUD.downscroll : null;
	if (d != null) return d == true;
	if (PlayState.instance != null && PlayState.instance.downscroll != null)
		return PlayState.instance.downscroll == true;
	return false;
}

// Psych's HUD rows are already screen-space. CNE's HudCamera applies
// height - y - sprite.height, so invert that once to keep the source's rows
// without mirroring twice; sprite.height is the scaled hitbox, not frameHeight.
function mmHudY(s, up:Float, down:Float):Float {
	if (!mmDownscroll()) return up;
	var h:Float = (camHUD != null) ? camHUD.height : FlxG.height;
	return h - down - s.height;
}

// CNE exposes downscroll directly, but has no matching middleScroll field in
// this build. Keep the optional state lookup; a missing field reads false.
function mmMiddleScroll():Bool {
	var ps = PlayState.instance;
	if (ps != null && Reflect.field(ps, "middleScroll") != null)
		return Reflect.field(ps, "middleScroll") == true;
	return false;
}

// ---------------------------------------------------------------------------
// The camEst layer (see the header)
// ---------------------------------------------------------------------------
var mmEstCam:FlxCamera = null;
function mmEst():FlxCamera {
	if (mmEstCam == null) {
		mmEstCam = new FlxCamera(0, 0, FlxG.width, FlxG.height);
		mmEstCam.bgColor = FlxColor.TRANSPARENT;
		mmEstCam.zoom = 1;
		FlxG.cameras.add(mmEstCam, false); // defaultDraw=false -> world not redrawn
		mmEstBelowHud();
	}
	return mmEstCam;
}

// Psych adds camEst right after camGame and therefore *before* camHUD (833-836),
// so its sprites draw above the fighters but below the notes and the HUD.
// Codename only has camGame and camHUD, so the port's camera is slid in at
// camHUD's own index.
function mmEstBelowHud() {
	if (mmEstCam == null) return;
	var list = (FlxG.cameras != null) ? FlxG.cameras.list : null;
	if (list == null) return;
	list.remove(mmEstCam); // no-op when it is not in the list yet
	var at:Int = -1;
	var i:Int = 0;
	while (i < list.length) {
		if (list[i] == camHUD) { at = i; break; }
		i += 1;
	}
	if (at < 0) { list.push(mmEstCam); return; }
	list.insert(at, mmEstCam);
	mmSyncCameraOrder(list);
}

// A camera's place is two things, and only one of them is `FlxG.cameras.list`:
// its own flashSprite is its render surface, and it is that sprite, in the
// display list, that decides what composites over what. Psych never has to
// think about it - it adds camEst (826-836) *before* camHUD, so both halves land
// right from the start - but this layer is built later, while the song loads,
// and `FlxG.cameras.add` drops a fresh camera's flashSprite on top of everything
// already mounted. Editing the list by hand - which the engine's own docs call
// out as unsupported ("Do not edit directly, use `add` and `remove`") - moves
// the list half only, so a layer that reads as "under camHUD" still drew over
// camHUD: So Cool's chat block over the score/misses, Thalassophobia's blackout
// over the falling notes. So re-assert the order through the engine's own
// `setOrder`, from the list this helper just built.
function mmSyncCameraOrder(list) {
	if (list == null || list.length == 0) return;
	var order:Array<FlxCamera> = [];
	for (c in list) order.push(c);
	// Two arguments only: flixel 5's own `Destroy` defaults to false, and the
	// two-parameter form is what every version of this method has taken.
	FlxG.cameras.setOrder(order, null);
}

// ---------------------------------------------------------------------------
// Early hook: the source's `noCount` (3198)
// ---------------------------------------------------------------------------
function onCountdown(event) {
	event.cancelled = true;
}

// ---------------------------------------------------------------------------
// Create-time state (see the header)
// ---------------------------------------------------------------------------
var mmBlackBar:FlxSprite = null;
function mmGetBlackBar():FlxSprite {
	if (mmBlackBar == null) {
		// 4675-4681: 10x-scaled (the source's setGraphicSize(width * 10)) so it
		// still covers the screen at the 0.45-0.7 zooms the chart uses.
		mmBlackBar = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		mmBlackBar.scale.set(10, 10);
		mmBlackBar.scrollFactor.set(0, 0);
		// The source puts it on camEst, which is above the world and the
		// fighters but *below* camHUD - and camHUD is where the notes live
		// (StrumLine carries its own notes into camHUD), so in the source the
		// notes stay visible right through every blackout (the chart blacks out
		// at 96s/170.67s while notes are falling). Pin it to camGame rather than
		// this script's camEst layer: camGame is composited first under every
		// mechanism, so the notes can never be covered whatever the camera list
		// does. What draws over it is this stage's own black vignette - a black
		// wash over black, so nothing is lost. 10x still covers the window at
		// this chart's zooms.
		mmBlackBar.cameras = [camGame];
		mmBlackBar.alpha = 1;
		add(mmBlackBar);
	}
	return mmBlackBar;
}

var mmFog:FlxSprite = null;
function mmGetFog():FlxSprite {
	if (mmFog == null) {
		// 3231-3236: a vignette plate, alpha 1 for the whole song.
		mmFog = new FlxSprite().loadGraphic(Paths.image("modstuff/126"));
		mmFog.antialiasing = true; // source ClientPrefs.globalAntialiasing
		mmFog.scrollFactor.set(0, 0);
		mmFog.cameras = [mmEst()];
		mmFog.alpha = 1;
		mmFog.screenCenter();
		add(mmFog);
	}
	return mmFog;
}

var mmLifeMeter = null;
var mmDadTween = null;
var mmEnemyY:Float = 0;
var mmLuigiLife:Int = 8;
var mmCanDrain:Bool = true;

function mmLifePlay() {
	if (mmLifeMeter != null) mmLifeMeter.animation.play("life" + mmLuigiLife, true);
}

// 15648-15653 / 16756-16760: dad drops 50px per life - `(enemyY + 250) -
// (luigilife * 50)` - over half a second quadOut, cancelling the previous hop.
function mmDadDrop() {
	if (dad == null) return;
	if (mmDadTween != null) mmDadTween.cancel();
	mmDadTween = FlxTween.tween(dad, {y: (mmEnemyY + 250) - (mmLuigiLife * 50)}, 0.5, {ease: FlxEase.quadOut});
}

function mmGetLifeMeter() {
	if (mmLifeMeter != null) return mmLifeMeter;
	var img:String = Paths.image("mario/lisfalse/health");
	if (!Assets.exists(img)) return null;

	// 3238-3253.
	var s = new FunkinSprite(25, 40);
	s.frames = Paths.getSparrowAtlas("mario/lisfalse/health");
	var i:Int = 0;
	while (i < 9) {
		s.animation.addByPrefix("life" + i, "health " + i, 24, true);
		i += 1;
	}
	// Play a full-size frame before the sprite is measured below. The atlas'
	// `health 80000/70000/60000` entries are marked frameWidth 67 / frameHeight
	// 68 over 268x272 art, and `updateHitbox` compensates the trim from that
	// figure - measured on one of those the hitbox comes out a quarter of the
	// art, which drags the drawn sprite up by ~220px (the source measures
	// `lifemetter.width` only because flixel hands it a full-size frame, so its
	// meter sits on its y). `life0` is `health 00000`: 268x272, no trim.
	s.animation.play("life0", true);
	s.cameras = [camHUD];
	s.antialiasing = true; // BGSprite inherits the source's global preference
	s.alpha = 0;
	s.setGraphicSize(Std.int(s.width * 2.2));
	s.updateHitbox();
	s.y = mmHudY(s, 40, 40);
	s.x = (FlxG.width - s.width) / 2;
	add(s);
	mmLifeMeter = s;
	mmLifePlay();
	return mmLifeMeter;
}

// The fork's `remove(x); add(x)` idiom, done the way this engine needs it: a
// bare `remove` only nulls the slot and `add` re-fills that same slot, so the
// splice is what actually moves the sprite.
function mmToFront(obj) {
	if (obj == null) return obj;
	remove(obj, true);
	insert(members.length, obj);
	return obj;
}

function postCreate() {
	// `noHUD = true` (3199) - the chart's 'Ocultar HUD' 2 restores it at 9.42s.
	if (camHUD != null) camHUD.alpha = 0;

	// 4427-4430: the foreground switch adds both of the stage's foreground
	// plates after the character groups, so in the source they draw over the
	// fighters. The stage XML carries them as ordinary children (`foreground2`
	// first, `foreground1` over it - the source's own order). The two camEst
	// plates (`mmGetBlackBar` / `mmGetFog`) are on a camera of their own and stay
	// above this layer.
	mmToFront(foreground2);
	mmToFront(foreground1);

	// The fork adds the vignette first (3237), then its curtain (4680).
	mmGetFog();
	mmGetBlackBar();
	mmGetLifeMeter();

	// 5837-5841.
	if (dad != null) {
		mmEnemyY = dad.y;
		dad.color = 0xFF608B60;
	}
	// The source also takes `customHB` (the 'healthBarNEW' frame over the health
	// bar) to alpha 0 here and back to 1 in case 5. Codename draws its own health
	// bar and has no such frame, so only the two icons carry that beat.
	if (iconP1 != null) iconP1.alpha = 0;
	if (iconP2 != null) iconP2.alpha = 0;
}

// 7511-7516: the meter follows `luigilife` and health is capped at 1.7 for the
// whole song.
function postUpdate(elapsed) {
	if (health > 1.7) health = 1.7;
	mmLifePlay();
}

// 16746-16760: every 8th beat from beat 160, one life drains (and dad drops);
// at 0 lives the player dies. The source's !cpuControlled guard maps to the
// player strumline's cpu flag (not the always-CPU opponent strumline).
function beatHit() {
	if (!mmCanDrain) return;
	if (strumLines.members.length > 1 && strumLines.members[1].cpu) return;
	if (curBeat < 160 || curBeat % 8 != 0) return;
	mmLuigiLife -= 1;
	if (mmLuigiLife <= 0) {
		mmLuigiLife = 0;
		health = 0;
	}
	mmDadDrop();
}

// 15641-15653: a hit 'Coin Note' is one life back, capped at 8.
function onNoteHit(event) {
	if (event.noteType != "Coin Note") return;
	if (!event.player) return;
	if (mmLuigiLife >= 8) mmLuigiLife = 8; else mmLuigiLife += 1;
	mmDadDrop();
}

// ---------------------------------------------------------------------------
// 'Triggers Thalassophobia' 0-8
// ---------------------------------------------------------------------------
function onEvent(event) {
	if (event.event.name != "Triggers Thalassophobia" && event.event.name != "Triggers Universal") return;
	var trigger = Std.parseInt(event.event.params[0]);
	if (trigger == null || Math.isNaN(trigger)) trigger = 0;

	switch (trigger) {
		case 0:
			mmGetBlackBar().alpha = 0;
			// 13893-13903: `if (ClientPrefs.flashing) FlxG.camera.flash(WHITE, 1)`
			// (the source's else branch never flashes: it just set alpha to 0).
			// The port takes flashing as on, like
			// every other stage script here. The engine's own camera flash is
			// sized to the camera's *unzoomed* rect and then scaled by the zoom,
			// so at this chart's 0.5-0.7 zooms it reads as a white box in the
			// middle of the screen; a screen-space plate is used instead.
			mmFlash(FlxColor.WHITE, 1);
		case 1:
			mmGetBlackBar().alpha = 1;
		case 2:
			// 13905: the drain toggle (it starts on).
			mmCanDrain = !mmCanDrain;
		case 3:
			// 13914-13920: FOLLOWCHARS = false, then a *delayed* pan of camFollowPos
			// to (1020, 750) over 11 beats (1 beat of startDelay) plus the matching
			// camGame zoom to 0.7. Both are staged in MMcamera now: the pan is a
			// lockDelay, the zoom a drive, and FOLLOWCHARS=false is what makes the
			// pan visible at all (with it on, the source's own per-frame lerp keeps
			// pulling camFollowPos back to the section).
			FlxTween.tween(mmGetBlackBar(), {alpha: 0}, 3);
			mmCam("follow", [false]);
			mmCam("lockDelay", [1020, 750, (11 / (Conductor.bpm / 60)), (1 / (Conductor.bpm / 60)), FlxEase.quadInOut]);
			mmCam("zoom", [0.7, (11 / (Conductor.bpm / 60)), (1 / (Conductor.bpm / 60)), FlxEase.quadInOut]);
		case 4:
			// 13922-13924: FOLLOWCHARS = true and both the camera and its target
			// zoom back to 0.8 over 1s quadOut.
			mmCam("follow", [true]);
			mmCam("zoom", [0.8, 1, 0, FlxEase.quadOut]);
		case 5:
			// 13926-13929: the icons and `customHB` fade back in (see postCreate).
			FlxTween.tween(iconP1, {alpha: 1}, 0.5, {ease: FlxEase.quadInOut});
			FlxTween.tween(iconP2, {alpha: 1}, 0.5, {ease: FlxEase.quadInOut});
		case 6:
			// 13930-13933: the meter moves 0 -> 50 (up) / 600 -> 550 (down)
			// and fades in over 2s expoOut, in the source's physical HUD rows.
			var meter = mmGetLifeMeter();
			if (meter != null) {
				meter.y = mmHudY(meter, 0, 600);
				if (mmMiddleScroll()) meter.x = 1000;
				FlxTween.tween(meter, {y: mmHudY(meter, 50, 550), alpha: 1}, 2, {ease: FlxEase.expoOut});
			}
		case 7:
			// 13935-13936: a full refill.
			mmLuigiLife = 8;
		case 8:
			FlxTween.tween(eel, {x: 2000}, 10);
	}
}

// `FlxG.camera.flash` (see case 0). A 10x-scaled screen-space plate in the
// state's draw list: same layer as the camera's own flash, but it covers the
// window at any zoom.
function mmFlash(color:Int, dur:Float) {
	var spr = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, color);
	spr.scale.set(10, 10);
	spr.scrollFactor.set(0, 0);
	// The source's camera flash is `FlxG.camera.flash`, i.e. camGame's own
	// flash - it washes the world and the fighters and leaves the notes and the
	// HUD readable on top of it, so the plate goes on camGame too.
	spr.cameras = [camGame];
	add(spr);
	FlxTween.tween(spr, {alpha: 0}, dur, {onComplete: function(twn) { spr.destroy(); }});
}
// === end MM stage triggers ===
