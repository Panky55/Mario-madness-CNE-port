

// === MM stage triggers (auto) ===
// 'Triggers No Party' - ported from PlayState.hx:10498-10564.
//
// The group is the No Party "DS" cutscene: the spotlight above the DJ booth
// fades up (case 0), the screen blacks out and flashes white (1/2), the drawn
// spotlight drops in with the 'lightOn' stinger (3), slides back out (4), the
// `Finish` board slams in with the 'finish' sound (5) and finally the DS message
// blinks between its normal and its 'criminal' colouring (6).
//
// Stage-level behaviour that comes with the case (PlayState.hx 4155-4310):
//   4157       `noCount = true` - the READY/SET/GO are dropped (onCountdown
//              cancelled below), like every other MM stage that does this.
//   4162-4170  `gfGroup.visible = false` (she is not in this chart) and
//              `boyfriendGroup.scrollFactor.set(0.1, 0.1)` - BF parallaxes
//              slowly over the booth instead of moving with the camera.
//   884-910    the DS console *window*: the OS window is re-centred and resized
//              to a 512x768 portrait, the root surface is scaled 2.665x, and
//              camGame/camHUD/camEst/camOther are all parked at (0, -600) - the
//              upscroll block below is the last word on camHUD, at -480 instead
//              of -600. `destroy()` hands the window and the scale back, the way
//              the source's own destroy does (15758-15798); somari.hx's port of
//              the same kind of window work is the precedent.
//   4166-4190  the "DS console" layout. The stage is written for downscroll
//              (`//hasDownScroll = true;` is commented out at 4156) and for
//              upscroll it drops the whole HUD 480px (`camHUD.y = -480`) and
//              the two fighters (boyfriendGroup.y = 280, dadGroup.y = 470),
//              with the Hally stack shifted down by `scrollcoords = 362`. The
//              fork draws its notes and strums on camHUD (5615-5617) and so
//              does this engine (`strLine.cameras = [camHUD]`), so the same
//              write puts the receptors mid-screen here: the port reproduces
//              the whole block. The only pieces left out are the unreachable
//              ones - the score text's BIOS font (5515, and the text rides the
//              moved camHUD, i.e. off screen) and `lifebar` (4214-4220, a
//              'mario/piracy/bar' BGSprite created `visible = false` that only
//              ever feeds the source's own HUD FlxBar its x/y/width, 5214-5216;
//              Codename mirrors its HUD itself, so nothing reads it here).
//   4181-4210  `bgH1` and `bgbottom`, the two `FlxBackdrop`s the extractor
//              cannot lift, are rebuilt as tiled copies (`mmStrip`, the same
//              stand-in demiseport.hx uses) with the source's scale, position
//              and velocity. The source adds the three Hally overlays *after*
//              `dadGroup` (4170-4201) - the DJ booth covers his lower body - so
//              postCreate puts them back above him; the port's XML had them all
//              below the cast.
//   4267-4268  `FlxG.mouse.load(TitleState.mouse.pixels, 0.8);
//              FlxG.mouse.visible = true;` - the stage shows the real cursor
//              while the DS message is on screen. Only the visibility half is
//              kept: `TitleState.mouse` is a fork static this port has no
//              equivalent for, and the cursor image is the system one anyway.
//   4295-4297  `djStart`/`djDone` are created with `y = hasDownScroll ? 150 :
//              510`. The extractor folded that conditional to y = 0, so both are
//              put back on their real row here.
//
// NOT ported: `Main.fpsVar.visible = false` (the engine's FPS text is not
// script-reachable here), the `pixelPerfect` flag of line 975, and the DS
// write-screen sprites themselves (`backing`/`thetext`/`thetextC`/`canvas`/
// `writeText`, 4222-4255, drawn on the source's camEst) - data/events/Write DS.hx
// renders that message as HUD text instead, see its own header.

// ----------------------------------------------------------------------------
// Helpers
// ----------------------------------------------------------------------------
// A screen-locked sprite on an overlay camera of its own: the source's camOther
// (drawspot) sits *above* camHUD, which is what a camera added last gives.
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

function mmScreen(spr, cam) {
	spr.scrollFactor.set(0, 0);
	spr.cameras = [cam];
	add(spr);
	return spr;
}

// Codename's `Stage` is not a group (`class Stage extends FlxBasic`), so
// `stage.add`/`stage.members` do not exist and HScript resolves them to null -
// calling them throws Null Function Pointer and aborts the rest of the handler.
// `Stage.addSprite` instead puts every stage sprite straight into the *state's*
// draw list and `Stage.applyCharStuff` inserts each character at its marker, so
// a bare `members`/`add`/`insert` here is the state's list and the world layer is
// the run of sprites below the character band.
//
// Index of the first character (the top of the world layer). The girlfriend node
// is the first character node in every ported stage XML and her marker sits one
// slot past her character, so `indexOf(marker) - 1` is the band start.
function mmWorldTop():Int {
	var st = PlayState.instance;
	if (st == null || stage == null) return -1;
	var poses = Reflect.field(stage, "characterPoses");
	var gfPos = (poses != null) ? poses.get("girlfriend") : null;
	if (gfPos == null) return -1;
	var i:Int = st.members.indexOf(gfPos);
	return (i >= 0) ? i - 1 : -1;
}

// A create-switch world sprite: the source `add()`s it before
// `add(boyfriendGroup)`, so it belongs at the top of the world layer, directly
// below the characters.
function mmWorldAdd(spr) {
	var w:Int = mmWorldTop();
	if (w >= 0) insert(w, spr); else add(spr);
}

// ----------------------------------------------------------------------------
// camEst (4211-4255)
// ----------------------------------------------------------------------------
// The source's camEst layer sits *between* the world and camHUD; a camera added
// with `FlxG.cameras.add(cam, false)` draws only what is assigned to it, and
// sliding it into camHUD's slot in `FlxG.cameras.list` is what puts it there.
// Only `bgbottom` uses it in this port (the DS write-screen the source draws on
// it is data/events/Write DS.hx's, see the header).
var mmEstCam:FlxCamera = null;
var mmEstPlaced:Bool = false;
var mmEstWarned:Bool = false;

function mmCamList() {
	return Reflect.field(FlxG.cameras, "list");
}

function mmEst():FlxCamera {
	if (mmEstCam == null) {
		var w = (camHUD != null) ? camHUD.width : FlxG.width;
		var h = (camHUD != null) ? camHUD.height : FlxG.height;
		mmEstCam = new FlxCamera(0, 0, w, h);
		mmEstCam.bgColor = FlxColor.TRANSPARENT;
		mmEstCam.zoom = 1;
		FlxG.cameras.add(mmEstCam, false); // defaultDraw=false -> world not redrawn
		mmEstBelowHud();
	}
	return mmEstCam;
}

function mmEstBelowHud() {
	if (mmEstCam == null || mmEstPlaced) return;
	var list = mmCamList();
	if (list == null) {
		if (!mmEstWarned) {
			mmEstWarned = true;
			trace("[MM piracy] camEst: no FlxG.cameras.list - the DS layer stays above camHUD");
		}
		return;
	}
	list.remove(mmEstCam); // no-op when it is not in the list yet
	var at:Int = (camHUD != null) ? list.indexOf(camHUD) : -1;
	if (at < 0) {
		list.push(mmEstCam); // no camHUD yet: stay on top
		return;
	}
	list.insert(at, mmEstCam);
	mmEstPlaced = true;
}

// ----------------------------------------------------------------------------
// FlxBackdrop stand-ins (4181-4210)
// ----------------------------------------------------------------------------
// `FlxBackdrop` is not safe to instantiate from HScript (its constructor takes a
// `FlxAxes` enum, and passing enums through a script call is what breaks - see
// demiseport.hx), so each one becomes the handful of copies the class would
// draw: identical sprites at `i * tile`, travelling in the velocity's own
// direction and wrapped every `tile` px. Two details matter and are easy to get
// wrong: the copies have to be spaced at the *scaled* size (Flixel's tile step
// is `(frame + spacing) * scale` - flixel-addons `FlxBackdrop.drawComplex`), and
// `velocity` there is plain FlxObject velocity, so the sprite's own x/y is what
// moves and the tiling, which is derived from it, travels *with* it - a positive
// velocity.x slides the pattern right, not left.
var mmStrips = [];
var mmBgH1 = null;

function mmStrip(img:String, x:Float, y:Float, scl:Float, axis:String, speed:Float, tile:Float, cam) {
	var path = Paths.image(img);
	if (path == null || !Assets.exists(path)) {
		trace("[piracy] backdrop missing -> " + path);
		return null;
	}
	if (tile <= 0) tile = 256;
	var span:Float = (axis == "y") ? FlxG.height : FlxG.width;
	var n:Int = Std.int(Math.ceil(span / tile)) + 2;
	if (n < 2) n = 2;
	var sprs = [];
	for (i in 0...n) {
		var s = new FunkinSprite(axis == "y" ? x : x + i * tile, axis == "y" ? y + i * tile : y);
		s.loadGraphic(path);
		if (scl != 0 && scl != 1) s.scale.set(scl, scl);
		s.updateHitbox();
		s.scrollFactor.set(0, 0);
		s.antialiasing = false; // source sets it false on both backdrops
		if (cam != null) s.cameras = [cam];
		add(s);
		sprs.push(s);
	}
	var g = {sprs: sprs, tile: tile, v: speed, t: 0.0, axis: axis, base: (axis == "y") ? y : x};
	mmStrips.push(g);
	return g;
}

function update(elapsed:Float) {
	for (g in mmStrips) {
		if (g.v == 0) continue;
		// The phase is kept in (-tile, 0] and travels with the velocity (see
		// mmStrip): positive slides right/down, negative left/up, and the wrap at
		// either end lands every copy on an identical one's old spot.
		g.t += g.v * elapsed;
		while (g.t <= -g.tile) g.t += g.tile;
		while (g.t > 0) g.t -= g.tile;
		var i:Int = 0;
		for (s in g.sprs) {
			if (g.axis == "y") s.y = g.base + i * g.tile + g.t;
			else s.x = g.base + i * g.tile + g.t;
			i += 1;
		}
	}
}

// 4170-4201: the source `add()`s bgH1/bgH3/bgH4 *after* `add(dadGroup)`, so the
// booth layers draw over him. Picking a sprite out of the world layer and
// putting it back directly above the dad character reproduces that (the bare
// remove + insert pair catches the slot `remove` leaves behind - see mmLift).
function mmAboveDad(spr) {
	if (spr == null) return spr;
	remove(spr, true);
	var i:Int = (dad != null) ? members.indexOf(dad) : -1;
	if (i < 0) add(spr); else insert(i + 1, spr);
	return spr;
}

// `PlayState.downscroll` is a get/set property, so read it defensively (the
// same helper exesequel.hx/allfinal.hx carry).
function mmDownscroll():Bool {
	if (PlayState.instance != null && Reflect.field(PlayState.instance, "downscroll") != null)
		return Reflect.field(PlayState.instance, "downscroll") == true;
	return false;
}

// The two shake tweens the source keeps in `extraTween` and case 4/5 cancel.
var mmExtra = [];

function mmCancelExtra() {
	for (t in mmExtra) t.cancel();
	mmExtra = [];
}

// ----------------------------------------------------------------------------
// The sprites the group owns
// ----------------------------------------------------------------------------
// 4388-4398: `blackBarThingie` is created in the *foreground* switch, i.e.
// right after `add(boyfriendGroup)`, with `bfspot` an instant before it - a
// plain `add()` at the end of the state's draw list, over the cast. It used to
// go to the top of the world layer here, which left the two fighters and bfspot
// drawn over the blackout it is supposed to be.
var mmBlackBar = null;

function mmGetBlackBar() {
	if (mmBlackBar == null) {
		mmBlackBar = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		mmBlackBar.scale.set(10, 10); // source's setGraphicSize(width * 10)
		mmBlackBar.scrollFactor.set(0, 0);
		mmBlackBar.alpha = 0;
		add(mmBlackBar);
	}
	return mmBlackBar;
}

// 4272-4277: the drawn spotlight. Created in create(), added right away with
// alpha 0 (so it is in the draw list the whole time, like the source's) and put
// on camOther - the camera above the HUD.
var mmDrawSpot = null;

function mmGetDrawSpot() {
	if (mmDrawSpot == null) {
		mmDrawSpot = new FunkinSprite(-83, -100);
		mmDrawSpot.loadGraphic(Paths.image("mario/piracy/spotlight"));
		mmDrawSpot.alpha = 0;
		mmScreen(mmDrawSpot, mmGetOther());
	}
	return mmDrawSpot;
}

// 4295-4297: the two DJ boards are created above the fighters' row, upscroll,
// but never `add()`ed until 'Show Song' 0 (`djStart`) / case 5 (`djDone`).
// Lifting one out of the world layer to the front of the draw list is what the
// source's `add()` there does - and, like every other lift in this port, it has
// to be written as a splice plus an append: a bare `remove(x); add(x)` is a
// no-op in Flixel, because `remove` only nulls the slot and `add` re-fills the
// first null slot in the list, which is that same one.
function mmLift(obj) {
	remove(obj, true);
	insert(members.length, obj);
	return obj;
}

// ----------------------------------------------------------------------------
// The DS console window (884-910)
// ----------------------------------------------------------------------------
// The source wears the whole game as a DS: the OS window is re-centred and
// resized to a 512x768 portrait (exactly the two DS screens at 2x), the root
// surface is scaled 2.665x, and every camera - camGame included, through
// `FlxG.camera` - is parked at x 0 / y -600, which is what lands the world and
// the HUD on the console's screens. The upscroll block in postCreate then lifts
// camHUD another 120px to -480, exactly as the source's stage block (4157-4190)
// does *after* this one runs. somari.hx does the same kind of window work for
// its 800x600 NES screen, so the mechanism (and its guarded reads) is proven
// here; `destroy()` hands everything back, the way the source's own destroy
// does at 15758-15798.
var mmScreenOn:Bool = false;
var mmWinOgX:Int = 0;
var mmWinOgY:Int = 0;

function mmPiracyScreen() {
	if (mmScreenOn) return;
	mmScreenOn = true;

	// 885-896: centre and resize the window to the DS's 2:3 portrait.
	if (window != null) {
		mmWinOgX = Std.int(window.x);
		mmWinOgY = Std.int(window.y);
		window.resizable = false;
		window.move(mmWinOgX + Std.int((window.width - 512) / 2), mmWinOgY + Std.int((window.height - 768) / 2));
		window.resize(512, 768);
	}

	// 897-898: the 2.665x root scale.
	if (Lib != null && Lib.current != null) {
		Lib.current.x = 0;
		Lib.current.y = 0;
		Lib.current.scaleX = 2.665;
		Lib.current.scaleY = 2.665;
	}

	// 900-910: camHUD, camEst and camOther up to the same row, plus camGame
	// itself (`mmEst()`/`mmGetOther()` are this port's camEst and camOther).
	for (cam in [camGame, camHUD, mmEst(), mmGetOther()]) {
		if (cam == null) continue;
		cam.x = 0;
		cam.y = -600;
	}
}

function destroy() {
	if (mmEstCam != null && FlxG.cameras != null && FlxG.cameras.list != null)
		FlxG.cameras.list.remove(mmEstCam);
	if (mmOther != null && FlxG.cameras != null && FlxG.cameras.list != null)
		FlxG.cameras.list.remove(mmOther);
	if (!mmScreenOn) return;
	mmScreenOn = false;

	if (window != null) {
		window.resize(1280, 720);
		window.move(mmWinOgX, mmWinOgY);
		window.resizable = true;
	}
	if (Lib != null && Lib.current != null) {
		Lib.current.scaleX = 1;
		Lib.current.scaleY = 1;
	}
}

// ----------------------------------------------------------------------------
// Load
// ----------------------------------------------------------------------------
function onCountdown(event) {
	// `noCount = true` (4157): the source never builds its 3-2-1-GO sprites.
	event.cancelled = true;
}

function postCreate() {
	// 884-910 runs before the stage block in the source, and the upscroll part
	// of that block (camHUD.y = -480) overrides this camera's -600.
	mmPiracyScreen();

	// 4391-4392: `add(bfspot)` in the foreground switch, right before the
	// black-out plate - the spotlight draws over the fighters and the plate over
	// the spotlight (`mmGetBlackBar` appends it right after this lift).
	if (bfspot != null) mmLift(bfspot);

	mmGetBlackBar();
	mmGetDrawSpot();

	// 4162-4170: GF is not in this chart, and BF parallaxes.
	if (gf != null) gf.visible = false;
	if (boyfriend != null) boyfriend.scrollFactor.set(0.1, 0.1);

	// 4166-4190: the DS-console layout - upscroll only (the stage is built for
	// downscroll, which skips the whole block).
	var scrollcoords:Float = 0;
	if (!mmDownscroll()) {
		scrollcoords = 362;
		if (camHUD != null) camHUD.y = -480;
		if (boyfriend != null) boyfriend.y = 280;
		if (dad != null) dad.y = 470;
	}

	// The four sprites whose y carried `-2.5 + scrollcoords` in the source, which
	// the extractor folded to 0 - bfspot and the three Hally plates it sits in.
	var bgY:Float = -2.5 + scrollcoords;
	if (bgH0 != null) bgH0.y = bgY;
	if (bgH3 != null) bgH3.y = bgY;
	if (bgH4 != null) bgH4.y = bgY;
	if (bfspot != null) bfspot.y = bgY;

	// 4181-4190: HallyBG4 tiled vertically at x 240, 1.3x, screen-locked, its
	// pattern drifting down at 40 px/s (tile = 296 * 1.3 - see mmStrip).
	mmBgH1 = mmStrip("mario/piracy/HallyBG4", 240, 0, 1.3, "y", 40, 384.8, null);

	// 4203-4210: `bgbottom`, 2.5x, on the camEst layer, drifting right at 40.
	mmStrip("mario/piracy/bgbottom", 600, mmDownscroll() ? 360 : -120, 2.5, "x", 40, 640, mmEst());

	// 4170-4201: the three booth overlays sit above dad, in this order - so they
	// go back in reverse (each lands directly above him).
	mmAboveDad(bgH4);
	mmAboveDad(bgH3);
	if (mmBgH1 != null) {
		for (s in mmBgH1.sprs) mmAboveDad(s);
	}

	// 4295-4297: the extractor folded `hasDownScroll ? 150 : 510` to 0.
	var djY:Float = mmDownscroll() ? 150 : 510;
	if (djStart != null) djStart.y = djY;
	if (djDone != null) djDone.y = djY;

	// 4267-4268: the DS message is drawn with the real cursor on screen.
	if (FlxG.mouse != null) FlxG.mouse.visible = true;
}

// ----------------------------------------------------------------------------
// 'Show Song' 0 on piracy (14222-14238)
// ----------------------------------------------------------------------------
// The source's title card is per-stage and piracy's is `djStart`: it slides in
// from the left, waits a second and slides back out - no title/author text.
// Show Song.hx stands down on this stage and this is the replacement (the same
// split endstage uses for its `linefount` card).
var mmDjStartAdded:Bool = false;

function mmShowDjStart() {
	if (djStart == null) return;
	// `add(djStart)` only once - a second Show Song 0 would otherwise add the
	// same sprite twice (drawn and updated twice).
	if (!mmDjStartAdded) {
		mmDjStartAdded = true;
		mmLift(djStart);
	}
	FlxTween.tween(djStart, {x: 110}, 1, {ease: FlxEase.backOut, onComplete: function(twn) {
		FlxTween.tween(djStart, {x: -300}, 1, {startDelay: 1, ease: FlxEase.backIn});
	}});
}

// ----------------------------------------------------------------------------
// 'Triggers No Party' 0-6
// ----------------------------------------------------------------------------
// Sent as 'Triggers Universal' by the chart (the source re-dispatches that to
// 'Triggers <song>' at runtime, 9489-9496), so both names are accepted. The
// camera half (case 0's BF_ZOOM 1 -> 1.2 over 6s and case 2's `BF_ZOOM = 1`)
// lives in songs/MMcamera.hx (mmPiracyTrigger).
function onEvent(event) {
	if (event.event.name == "Show Song") {
		if (event.event.params.length < 1) return;
		var s = Std.parseInt(event.event.params[0]);
		if (s == null || s == 0) mmShowDjStart();
		return;
	}

	if (event.event.name != "Triggers No Party" && event.event.name != "Triggers Universal") return;
	var trigger = Std.parseInt(event.event.params[0]);
	if (trigger == null || Math.isNaN(trigger)) trigger = 0;

	switch (trigger) {
		case 0:
			// 92.16s: the spotlight fades up over 6s (linear).
			if (bfspot != null) FlxTween.tween(bfspot, {alpha: 1}, 6);
		case 1:
			// 107.52s: the world blacks out over 1.5s.
			FlxTween.tween(mmGetBlackBar(), {alpha: 1}, 1.5);
		case 2:
			// 109.44s: white flash, and both the spotlight and the black are cut.
			FlxG.camera.flash(FlxColor.WHITE, 0.5);
			if (bfspot != null) bfspot.alpha = 0;
			mmGetBlackBar().alpha = 0;
		case 3:
			// 117.12s: the drawn spotlight drops in with the 'lightOn' sound.
			FlxG.sound.play(Paths.sound('lightOn'));
			var d = mmGetDrawSpot();
			d.flipY = !mmDownscroll();
			d.alpha = 1;
			d.scale.set(1.3, 1.3);
			d.y = mmDownscroll() ? -100 : -20;
			d.angle = 2;

			var coords:Float = mmDownscroll() ? -20 : -100;
			FlxTween.tween(d.scale, {x: 1, y: 1}, 1, {ease: FlxEase.expoOut});
			FlxTween.tween(d, {y: coords}, 2, {ease: FlxEase.expoOut});
			mmExtra.push(FlxTween.tween(d, {angle: -2}, 2,
				{ease: FlxEase.quadInOut, type: FlxTween.PINGPONG}));
		case 4:
			// 132.0s: the sway is cancelled and the spotlight leaves again.
			mmCancelExtra();
			var d4 = mmGetDrawSpot();
			// 10538-10542: `coords = -100; if(!hasDownScroll) coords = -20;` - the
			// mirror of case 3 above, so the spotlight leaves through the side it
			// came in from.
			var back:Float = mmDownscroll() ? -100 : -20;
			FlxTween.tween(d4, {angle: 0}, 1, {ease: FlxEase.quadInOut});
			FlxTween.tween(d4, {alpha: 0}, 1.5, {startDelay: 0.5});
			FlxTween.tween(d4, {y: back}, 2, {ease: FlxEase.backIn});
		case 5:
			// 149.76s: the `Finish` board slams in.
			if (djDone == null) return;
			var fin:FlxSprite = mmLift(djDone);
			fin.scale.set(20, 20);
			FlxG.sound.play(Paths.sound('finish'));
			mmExtra.push(FlxTween.tween(fin, {x: fin.x + 3}, 0.04, {type: FlxTween.PINGPONG}));
			mmExtra.push(FlxTween.tween(fin, {y: fin.y + 3}, 0.02, {type: FlxTween.PINGPONG}));
			FlxTween.tween(fin.scale, {x: 2, y: 2}, 0.7, {ease: FlxEase.cubeInOut, onComplete: function(twn) {
				mmCancelExtra();
			}});
			FlxTween.tween(fin, {y: fin.y - 200}, 0.8, {startDelay: 1.5, ease: FlxEase.backIn});
		case 6:
			// The DS message's normal <-> 'criminal' blink. The text sprites belong
			// to 'Write DS' (data/events/Write DS.hx), which owns the same toggle -
			// nothing to do here.
	}
}
// === end MM stage triggers ===
