// Ported from PlayState.hx beatHit() (case 'virtual').
// The player's glitched head drops in and fades out on a beat pattern that
// pauses during certain sections, the two Koopas' glitched idle is restarted
// every 2 beats, and the 'dupe' section steps its shader once every
// `mmDupeTimer` beats (the shader state itself lives in the trigger block
// below, from PlayState.hx's 'Triggers Universal' 7/8/9).
var cantfade:Bool = false;
var cantchange:Bool = false;
var cancelArray = [116, 124, 132, 140, 142, 148, 156, 164, 172, 468, 470];
var changeArray = [16, 336, 372];
var changeArray2 = [324, 340, 500];

function beatHit(curBeat:Int) {
	cantfade = (curBeat >= 177 && curBeat <= 258) || cancelArray.contains(curBeat) || curBeat >= 550;
	if (changeArray.contains(curBeat)) cantchange = true;
	if (changeArray2.contains(curBeat)) cantchange = false;

	// Source 16628-16631: the bar comes back one beat *before* 'Triggers
	// Universal' 2 (106.03s) raises it for the GF-was-taken cut, so the black is
	// already there when the cut lands.
	if (curBeat == 256) mmGetBlackBar().alpha = 1;

	var fadechange = cantchange ? 2 : 4;
	if (curBeat % fadechange == 0 && !cantfade) {
		yourhead.alpha = 0.8;
		yourhead.y = -200;
		FlxTween.tween(yourhead, {y: -122, alpha: 0.2}, 0.4, {ease: FlxEase.quadOut});
	}

	// The Koopas' idle is a non-looping anim (addByPrefix(..., false)), so the
	// source replays it every 2 beats or it freezes on its last frame. Only
	// while they are actually idling - 'Triggers Paranoia' 3's 'glitch' anim is
	// left to finish on its own.
	if (curBeat % 2 == 0) {
		var tanim = turtle.animation.curAnim;
		if (tanim != null && tanim.name == "idle") {
			turtle.playAnim("idle", true);
			turtle2.playAnim("idle", true);
		}
	}

	// The dupe section (source: the `if(dupeTimer != 0)` block of the virtual
	// case). Every mmDupeTimer beats the screen is tiled one step further
	// (multi + 1, no mirror) until the multiplier reaches mmDupeMax, then the
	// steps mirror the tiles and walk back down to 1, and each step spikes the
	// angel glitch along with it. 'Triggers Universal' 8 arms it and 9 sets the
	// max; 'Triggers Paranoia' 7 sets the multiplier directly. Both shaders are
	// only mounted while the section is armed, hence the null guards.
	if (mmDupeTimer != 0 && mmDupe != null) {
		if (curBeat % mmDupeTimer == 0) {
			var dmult = mmDupe.data.multi.value[0];
			if (mmDupeInc) {
				if (mmAngel != null) mmAngel.data.pixel.value = [2, 2];
				mmDupe.data.mirrorS.value = [0];
				dmult += 1;
				if (dmult == mmDupeMax) mmDupeInc = false;
			} else {
				if (mmAngel != null) mmAngel.data.pixel.value = [0.5, 0.5];
				mmDupe.data.mirrorS.value = [1];
				dmult -= 1;
				if (dmult == 1) mmDupeInc = true;
			}
			mmDupe.data.multi.value = [dmult, dmult];
			var spike = ((0.25 / 4)) * dmult;
			if (mmAngel != null) mmAngel.data.stronk.value = [spike, spike];
		}
	}
}

// === MM stage triggers (auto) ===
// 'Triggers Paranoia' - ported from PlayState.hx (case 'Triggers Paranoia').
// NOTE: the source's wallpaper swap, its "hide every other window" call and the
// Win32 layered window all come from the Windows-only `ndll-mario` shim (the
// `CppAPI.*` calls) and have no Codename/lime equivalent - see the window block
// below for what *is* ported. Its in-game half is: `virtuabg` is a `makeGraphic`
// colour fill, so it is rebuilt in this file (port_stages.py only lifts
// `new BGSprite` blocks into the XML), and `clashmario` is a group whose members
// the XML does carry - flat rather than grouped, so mmSetClashVisible() hides
// them together.
// The camera half of triggers 1, 4 and 6 is handled by MMcamera
// (mmParanoiaTrigger), which is the only writer of camFollow / camGame.zoom.
// Virtual stage creation (PlayState.hx:4545 `if (curStage == 'virtual') gf.visible
// = false`): the real GF is hidden for the whole song - she is the one who was
// taken, and the opponent becomes her stand-in (vDialog2 / vGF2 through the
// chart's 'Change Character' events). Nothing in Paranoia shows her again.
//
// The stage's three shaders (PlayState.hx:2391: `camGame.setFilters([effect,
// dupe, angel])` + `camHUD.setFilters([angel])`) are the mod's shaders/*.frag,
// mounted on the cameras here: 'mosaicShader' (= SMWPixelBlurShader, the CRT
// boot'up of the intro), 'camDupe' (= CamDupeShader, the tiled/mirrored screen)
// and 'angel' (= AngelShader, the RGB tear). See mmCreateShaders /
// mmPixelIntro / mmDupeArm and the beatHit() dupe block in this file.

// --- dupe / angel / CRT shader state --------------------------------------- //
var mmPixel = null;          // 'mosaicShader' instance (the intro's block-out)
var mmDupe = null;           // 'camDupe' instance
var mmAngel = null;          // 'angel' instance
var mmDupeOn:Bool = false;   // are mmDupe/mmAngel currently on the cameras?
var mmDupeTimer:Int = 0;     // beats between dupe steps; 0 = effect off
var mmDupeMax:Int = 4;       // multiplier the dupe steps back down from
var mmDupeInc:Bool = true;   // walking up (false: mirroring back down)
var mmPixelBoot = null;      // {v} holder the intro's mosaic tween drives

// --- the game-window half of the virtual stage ----------------------------- //
// Paranoia is meant to be a small game window on the desktop with the rest of
// the screen visible around it. PlayState.hx's creation block forces the window
// out of fullscreen and locks it (2373-2388), its stepHit() walks the window
// around the desktop and then throws it over the whole screen for the
// GF-was-taken section (15826-15936, applied by the `startwindow`/`startresize`
// branches of update(), 7622-7630) and 'Triggers Paranoia' 4 drops it back to
// the small box (13647-13684). destroy() hands the window back to the player
// (15782-15790). The box the reference port uses for all of that - a centred
// 2/3 of the monitor - is what this file shrinks to on load; the source
// snapshot's own numbers were the window's load-time geometry, so its version
// of trigger 4 is a no-op on an un-shrunk window. All of it is lime Window API,
// so it is ported; the rest of the source's window work - `CppAPI.setWallpaper`,
// `hideWindows`/`restoreWindows` and the layered-window transparency - is the
// Windows-only ndll shim, which has no Linux build, so it is not (see
// PORT_NOTES.md).
//
// The step numbers below are the source's own, and they line up with the chart
// because stepCrochet is 15000/bpm (103.45ms at 145bpm): step 320 is 33.10s,
// 935 - where the dance stops - is 96.72s, and 1008, where the window goes
// full-monitor, is 104.28s, the exact spot the reference port's own chart
// calls `preGfWindow` on.
var mmWinResize:Bool = false;                           // source's `startresize`
var mmWinStart:Bool = false;                            // source's `startwindow`
var mmWinDances = [];                                   // source's `windowTween`s
var mmWinBox = {x: 0.0, y: 0.0, w: 1280.0, h: 720.0};    // the live window box
var mmWinSmall = {x: 0.0, y: 0.0, w: 1280.0, h: 720.0};  // the 'Mr. Virtual' box
var mmWinFull = {x: 0.0, y: 0.0, w: 1920.0, h: 1080.0};  // the whole monitor
var mmWinOgX:Int = 0;                     // the geometry the song started with
var mmWinOgY:Int = 0;
var mmWinOgW:Int = 0;
var mmWinOgH:Int = 0;
var mmWinOk:Bool = false;                 // did the box resolve?
var mmWinTween = null;                    // running mmWinBox tween, if any

function postCreate() {
	if (gf != null) gf.visible = false;
	mmCreateShaders();
	mmWindowInit();
	// The source's bar starts at alpha 1, i.e. the stage is black until the
	// intro's stinger timer clears it (mmPixelIntro, below).
	mmGetBlackBar().alpha = 1;
}

// Does this engine build have the "Gameplay Shaders" option, and is it on?
// (With it off, every shader below stays null and its setters no-op.)
function mmShadersAllowed():Bool {
	if (Options == null) return true;
	if (!Reflect.hasField(Options, "gameplayShaders")) return true;
	return Options.gameplayShaders;
}

// The source's creation block: `effect = new SMWPixelBlurShader(); dupe = new
// CamDupeShader(); dupe.mult = 1; angel = new AngelShader();`. MosaicShader's
// constructor seeds uBlocksize with [1, 1] (SMWPixelBlurShader.DEFAULT_STRENGTH),
// so the effect is a no-op until the intro raises it - the hidden state it also
// starts in in the source. The dupe/angel shaders are *not* mounted here: the
// beat block below only ever runs while they are armed, and a 1x tiling with no
// mirror (dupe) plus a 0-strength angel are exact identity passes, so mounting
// them with the effect gives the same picture for less work than the source's
// always-on filter list.
//
// Idempotent on purpose: the intro arms the mosaic from onStartCountdown(),
// which the engine fires from createPost() *before* the scripts' postCreate
// hook (PlayState.hx:901-912), so it may have to build them itself.
var mmShadersDone:Bool = false;
function mmCreateShaders() {
	if (mmShadersDone) return;
	mmShadersDone = true;
	if (!mmShadersAllowed()) return;

	mmPixel = new CustomShader("mosaicShader");
	mmPixel.data.uBlocksize.value = [1, 1];
	if (camGame != null) camGame.addShader(mmPixel);

	mmDupe = new CustomShader("camDupe");
	mmDupe.data.multi.value = [1, 1];   // CamDupeShader.set_mult writes [v, v]
	mmDupe.data.mirrorS.value = [0];

	mmAngel = new CustomShader("angel");
	mmAngel.data.stronk.value = [0];
	mmAngel.data.pixel.value = [1, 1];
}

// The intro's CRT boot'up (PlayState.hx:6376-6380), the other half of the 1s
// timer in the source's startCountdown(): 1s into the hold the mosaic is armed
// at 40 blocks and eased to 1 (a pixel-perfect screen) over 0.7s - exactly when
// songs/MMcamera.hx plays the 'virtualintro' stinger on the same second. Past
// that it is a no-op pass, so it is dropped from the camera instead of being
// left mounted for the whole song.
var mmPixelBooted:Bool = false;
function mmPixelIntro() {
	mmCreateShaders();   // onStartCountdown can land before postCreate does
	if (mmPixelBooted || mmPixel == null || camGame == null) return;
	mmPixelBooted = true;
	// The same second the mosaic waits is when the source's timer clears
	// `blackBarThingie` (6372) - immediately before arming the effect - so the
	// black screen the stage loaded on goes away as the CRT boot'up begins.
	new FlxTimer().start(1, function(tmr) {
		mmGetBlackBar().alpha = 0;
	});
	mmPixelBoot = {v: 40.0};
	FlxTween.tween(mmPixelBoot, {v: 1.0}, 0.7, {
		startDelay: 1,
		onUpdate: function(twn) {
			mmPixel.data.uBlocksize.value = [mmPixelBoot.v, mmPixelBoot.v];
		},
		onComplete: function(twn) {
			camGame.removeShader(mmPixel);
		}
	});
}

// Fired by startCountdown() before it does anything; MMcamera cancels it for
// this stage and re-calls it a second later, which is what mirrors the source's
// "the countdown does not start until the intro has played" (PlayState.hx:6375,
// `startedCountdown = true` inside the timer) - so the 1s hold is running by the
// time this returns. Nothing to hold here: this stage's half of the intro is the
// shader boot'up, and its own 1s startDelay is what syncs it with the stinger.
function onStartCountdown(event) {
	mmPixelIntro();
}

// Mount/unmount the dupe section's two shaders. The angel one goes on both
// cameras the source filtered through it (camGame and camHUD); the dupe one
// only ever touched camGame.
function mmDupeArm(on:Bool) {
	if (on == mmDupeOn) return;
	mmDupeOn = on;

	if (mmDupe != null && camGame != null) {
		if (on) camGame.addShader(mmDupe);
		else camGame.removeShader(mmDupe);
	}
	if (mmAngel == null) return;
	if (camGame != null) {
		if (on) camGame.addShader(mmAngel);
		else camGame.removeShader(mmAngel);
	}
	if (camHUD != null) {
		if (on) camHUD.addShader(mmAngel);
		else camHUD.removeShader(mmAngel);
	}
}

// 'Triggers Universal' 8 - the source's `dupeTimer`: the number of beats
// between dupe steps, 0 to end the section (the chart sends 4, then 1, then 0).
function mmSetDupeTimer(v:Int) {
	if (v == null) return;
	mmDupeTimer = v;
	mmDupeArm(v != 0);
}

// 'Triggers Paranoia' 7 (source: `dupe.mult = Std.parseFloat(value2);
// dupe.mirror = false;`). `multi` + `mirrorS` are the camDupe uniforms; a NaN
// (the param left out) is ignored rather than poisoning the tiling.
function mmDupeSetMult(v:Float, mirror:Bool) {
	if (mmDupe == null || (v == null || Math.isNaN(v))) return;
	mmDupe.data.multi.value = [v, v];
	mmDupe.data.mirrorS.value = [mirror ? 1 : 0];
}

// The dupe section is the one effect of this stage that can fail *silently*: the
// tiling is camDupe's own work, so an angel that never reaches the GPU still
// multiplies the screen and "no RGB tear" reads as a missing effect rather than
// a broken one. That is why this script used to carry a `mmDebugProbe` switch (a
// per-dupe-step log of both shaders' null-ness, camera membership and uniforms,
// plus a 4s self-test that mounted the pair and spiked the angel to strength 1).
// Both are gone: the section is chart-driven, and the uniforms the trigger block
// sets below are the whole port of it.

// value2 (params[1]) of the trigger event the onEvent below is dispatching.
// The source reads it out of its own `value2` split; a short param list reads
// as "" so Std.parseInt gives null / Std.parseFloat gives NaN.
function mmTriggerValue2(event):String {
	var p = event.event.params;
	if (p == null || p.length < 2 || p[1] == null) return "";
	return Std.string(p[1]);
}

// Is `field` readable off `obj`? `Reflect.field` throws on cpp for a name that
// is not there (and this engine's scripts cannot try/catch), so every read of a
// property the script globals do not spell out goes through this first.
function mmReadable(obj:Dynamic, field:String):Bool {
	return obj != null && Reflect.hasField(obj, field) && Reflect.field(obj, field) != null;
}

// The screen the window sits on, in pixels. CnE's script globals expose `window`
// and `Application`, but neither `Capabilities` nor `Type` (so
// `openfl.system.Capabilities.screenResolution*` cannot be resolved by name) -
// lime's display is what is reachable. The source's own measurement was a
// fullscreen round-trip (`fullscreen = true; fsX = width; fsY = height;
// fullscreen = false`, PlayState.hx:2373-2376), but that size only settles once
// the compositor has answered the fullscreen request, so reading the display
// directly is both the same number and flash-free. `display.bounds` is the
// monitor rectangle; `display.currentMode` and the window's own `displayMode`
// are the same resolution from the other direction. Worst case neither answers
// and the window's current size is used, which still gives a smaller box.
function mmWindowScreen():Array<Float> {
	var w:Float = null;
	var h:Float = null;
	if (mmReadable(window, "display")) {
		var d = window.display;
		if (mmReadable(d, "bounds")) {
			w = d.bounds.width;
			h = d.bounds.height;
		}
		if ((w == null || w <= 0) && mmReadable(d, "currentMode")) {
			w = d.currentMode.width;
			h = d.currentMode.height;
		}
	}

	if ((w == null || w <= 0) && mmReadable(window, "displayMode")) {
		w = window.displayMode.width;
		h = window.displayMode.height;
	}

	if (w == null || h == null || w <= 0 || h <= 0) {
		w = window.width;
		h = window.height;
	}

	if (w == null || h == null || w <= 0 || h <= 0) return null;
	return [w, h];
}

// The stage's window setup, from the creation block of PlayState.hx (2373-2388)
// plus the reference port's virtual.hx file scope. Paranoia is meant to be a
// game running in a small window on the desktop, not a fullscreen game: the
// window is forced out of fullscreen, unlocked from maximize and made
// non-resizable, and shrunk to the 'Mr. Virtual' box - two thirds of the
// monitor centred on it, which is the reference port's file scope
// (`window.width = Capabilities.screenResolutionX / 1.5` and
// `window.x = display.bounds.width / 6`, that second one being centring when
// the monitor starts at 0,0). What the window had before is remembered for
// destroy().
//
// The source's fullscreen round-trip (`fullscreen = true; fsX = width; fsY =
// height; fullscreen = false`) is replaced by reading the monitor size
// directly: it is the same measurement without the flash, and `fsX/fsY` in the
// source are only ever consumed by the Alone/'betamansion' fullscreen trick.
function mmWindowInit() {
	mmWinOk = false;
	if (window == null) return;

	mmWinOgX = Std.int(window.x);
	mmWinOgY = Std.int(window.y);
	mmWinOgW = Std.int(window.width);
	mmWinOgH = Std.int(window.height);

	window.fullscreen = false;
	window.maximized = false;
	window.resizable = false;

	var screen = mmWindowScreen();
	if (screen == null) return;
	mmWinOk = true;

	mmWinFull.w = screen[0];
	mmWinFull.h = screen[1];
	mmWinFull.x = 0;
	mmWinFull.y = 0;

	mmWinSmall.w = Math.round(screen[0] / 1.5);
	mmWinSmall.h = Math.round(screen[1] / 1.5);
	mmWinSmall.x = Math.round((screen[0] - mmWinSmall.w) / 2);
	mmWinSmall.y = Math.round((screen[1] - mmWinSmall.h) / 2);

	mmWinBox.x = mmWinSmall.x;
	mmWinBox.y = mmWinSmall.y;
	mmWinBox.w = mmWinSmall.w;
	mmWinBox.h = mmWinSmall.h;
	mmWinApply();
}

// Pushes mmWinBox to the window. This is the source's `startresize` branch of
// update() (7626-7630), which is what makes the box tweens move the window.
function mmWinApply() {
	if (window == null || !mmWinOk) return;
	window.resize(Std.int(mmWinBox.w), Std.int(mmWinBox.h));
	window.move(Std.int(mmWinBox.x), Std.int(mmWinBox.y));
}

// The source's `startwindow` branch (7624): position only. The window keeps the
// same size for the whole desktop dance, so asking the window manager to resize
// it on every frame of a 60fps ping-pong would only make it stutter.
function mmWinPushMove() {
	if (window == null || !mmWinOk) return;
	window.move(Std.int(mmWinBox.x), Std.int(mmWinBox.y));
}

// Eases the box to a new one; the per-frame push in update() moves the window
// along with it, and the final frame of the tween settles it exactly.
function mmWinTweenTo(x:Float, y:Float, w:Float, h:Float, sec:Float, ease) {
	if (window == null || !mmWinOk) return;
	if (mmWinTween != null) mmWinTween.cancel();

	mmWinResize = true;
	mmWinTween = FlxTween.tween(mmWinBox, {x: x, y: y, w: w, h: h}, sec, {ease: ease, onComplete: function(twn) {
		mmWinResize = false;
		mmWinTween = null;
		mmWinApply();
	}});
}

// Tracks one of the dance's tweens. Its ping-pongs never complete on their own,
// so they have to be kept to be cancelled at step 935 the way the source cancels
// its `windowTween` list.
function mmWinDance(twn) {
	if (twn == null) return;
	mmWinDances.push(twn);
}

function mmWinCancelDances() {
	for (twn in mmWinDances) twn.cancel();
	mmWinDances = [];
}

// Step 1008 (15890-15936): the source's `startresize = true` block, and the
// same 1.6s expoIn grow the reference port's chart calls `preGfWindow` on - the
// 'GF was taken' section takes the whole screen. Its onComplete drops the
// `startresize` flag and settles the window on the monitor box exactly.
function mmWindowGrow() {
	mmWinTweenTo(mmWinFull.x, mmWinFull.y, mmWinFull.w, mmWinFull.h, 1.6, FlxEase.expoIn);
}

// The reference port's `noMoreFullscreen()`, i.e. 'Triggers Paranoia' 4
// (PlayState.hx:13647): drop the borderless flag and ease the window back to
// the small box over 1s expoOut - the song is a little window on the desktop
// again until it ends. (The source snapshot tweens to its `ogwin*` reading
// instead, which was taken a few lines after `winx/winy` inside the same
// create() call - i.e. to the size the window happened to have at load, which
// is what an un-shrunk port did; the reference port's small box is what the
// stage is meant to look like.)
function mmWindowShrink() {
	if (window != null) window.borderless = false;
	mmWinStart = false;
	mmWinCancelDances();
	mmWinTweenTo(mmWinSmall.x, mmWinSmall.y, mmWinSmall.w, mmWinSmall.h, 1, FlxEase.expoOut);
}

// PlayState.hx's stepHit() window choreography for this stage (15826-15936,
// inside `curStage == 'virtual' && ClientPrefs.noVirtual`). Everything there is
// measured from `changex/changey`/`ogwin*`, and those are all the same reading -
// `winx = window.x; ... changex = winx;` at create(), `ogwinX = window.x` a few
// lines later - i.e. wherever the window sits for the song, which in this port
// is the small box. So homeX/homeY is the small box's own corner.
//
// 320 kicks the window around the desktop and starts the per-frame moves, 336
// slides it to a quarter of its home position, 384-576 ping-pong it around
// there, 935 cancels every running tween, pulls it home and stops the moves,
// and 1008 grows it over the whole monitor (mmWindowGrow, above).
function stepHit(curStep:Int) {
	if (window == null || !mmWinOk) return;

	var homeX:Float = mmWinSmall.x;
	var homeY:Float = mmWinSmall.y;

	switch (curStep) {
		case 320:
			mmWinStart = true;
			mmWinBox.x = homeX - 20;
			mmWinBox.y = homeY + 50;
		case 324:
			mmWinBox.x = homeX + 20;
			mmWinBox.y = homeY - 50;
		case 328:
			mmWinBox.x = homeX + 100;
			mmWinBox.y = homeY + 100;
		case 332:
			mmWinBox.x = homeX + 100;
			mmWinBox.y = homeY - 100;
		case 336:
			mmWinDance(FlxTween.tween(mmWinBox, {x: homeX / 4, y: Std.int(homeY / 4)}, 0.2, {startDelay: 0.2, ease: FlxEase.backIn}));
		case 384:
			mmWinBox.x = homeX / 4;
			mmWinBox.y = homeY / 4;
		case 392:
			mmWinDance(FlxTween.tween(mmWinBox, {y: Std.int(homeY + (homeX / 4))}, 3, {ease: FlxEase.quadInOut, type: FlxTween.PINGPONG}));
		case 400:
			mmWinDance(FlxTween.tween(mmWinBox, {x: Std.int(homeX + (homeX / 2))}, 5, {ease: FlxEase.quadInOut, type: FlxTween.PINGPONG}));
		case 448:
			mmWinDance(FlxTween.tween(mmWinBox, {y: homeY}, 0.5, {ease: FlxEase.expoOut}));
			mmWinDance(FlxTween.tween(mmWinBox, {x: homeX}, 0.5, {ease: FlxEase.expoOut}));
			mmWinDance(FlxTween.tween(mmWinBox, {y: homeY + 50}, 5, {startDelay: 0.5, ease: FlxEase.cubeInOut, type: FlxTween.PINGPONG}));
		case 576:
			mmWinDance(FlxTween.tween(mmWinBox, {x: homeX + 50}, 3, {ease: FlxEase.cubeInOut, type: FlxTween.PINGPONG}));
		case 935:
			mmWinCancelDances();
			mmWinDance(FlxTween.tween(mmWinBox, {x: homeX}, 0.5, {ease: FlxEase.cubeInOut}));
			mmWinDance(FlxTween.tween(mmWinBox, {y: homeY}, 0.5, {ease: FlxEase.cubeInOut}));
			new FlxTimer().start(0.5, function(tmr) {
				mmWinStart = false;
				mmWinApply();
			});
		case 1008:
			// The source also un-hides timeBarBG/timeBar/timeTxt/scoreTxt here
			// (`if (!ClientPrefs.hideTime)` / `if (!ClientPrefs.hideHud)`); in this port
			// the chart's 'Ocultar HUD' fades the whole camHUD instead, so there is
			// nothing to restore - same as 'Triggers Paranoia' 4.
			mmWinStart = false;
			mmWinCancelDances();
			mmWindowGrow();
	}
}

// PlayState.hx destroy() for the virtual stage (15782-15790): give the window
// back - resizable and borderless-free, at the size and position it had when
// the stage loaded. (The `CppAPI.restoreWindows()`/`setWallpaper('old')` next
// to it are the ndll calls that are not ported, and the source's
// PauseSubState.rest* restore is the pause menu's job.)
function destroy() {
	if (window == null) return;
	mmWinResize = false;
	mmWinStart = false;
	mmWinCancelDances();
	if (mmWinTween != null) {
		mmWinTween.cancel();
		mmWinTween = null;
	}
	window.resizable = true;
	window.maximized = false;
	window.borderless = false;
	window.resize(mmWinOgW, mmWinOgH);
	window.move(mmWinOgX, mmWinOgY);
}

// PlayState.hx's per-frame angel decay: the shader's spikes are one-shot, the
// strength always eases back to 0 and pixelSize back to 1. Rate 8 for the
// strength is the source's `else` branch - its `curStage != 'virtual'` test is
// false here - and 4 for pixelSize. iTime feeds the shader's noise.
function update(elapsed:Float) {
	// Source update() lines 7622-7630: while `startwindow` is set the window is
	// moved to the box every frame, and while `startresize` is set it is also
	// resized - that per-frame push is what animates the desktop dance and the
	// grow/shrink tweens.
	if (mmWinResize) mmWinApply();
	else if (mmWinStart) mmWinPushMove();

	if (mmAngel == null) return;

	var s = FlxMath.lerp(mmAngel.data.stronk.value[0], 0, FlxMath.bound(elapsed * 8, 0, 1));
	mmAngel.data.stronk.value = [s, s];   // AngelShader.set_strength writes [v, v]

	var p = FlxMath.lerp(mmAngel.data.pixel.value[0], 1, FlxMath.bound(elapsed * 4, 0, 1));
	mmAngel.data.pixel.value = [p, p];

	mmAngel.data.iTime.value = [Conductor.songPosition / 1000];
}

// Psych's `camOther`, which is where the source puts `blackBarThingie` (2422) so
// the cut covers the characters *and* the HUD and the notes. Codename's topmost
// camera is camHUD, and camHUD.alpha is spoken for (the intro holds it at 0 for
// the whole countdown), so the bar gets a camera of its own above it - added the
// same way allfinal.hx adds its mmEst, with `defaultDraw = false` so nothing
// starts drawing to it.
var mmBarCam:FlxCamera = null;
function mmGetBarCam():FlxCamera {
	if (mmBarCam == null) {
		mmBarCam = new FlxCamera(0, 0, FlxG.width, FlxG.height);
		mmBarCam.bgColor = FlxColor.TRANSPARENT;
		mmBarCam.zoom = 1;
		FlxG.cameras.add(mmBarCam, false);   // defaultDraw=false -> world not redrawn
	}
	return mmBarCam;
}

// The source's `blackBarThingie` (2419-2424): a full-screen black sprite that is
// its own hard cut. It is created with alpha 1 - the `alpha = 0` line right after
// `setGraphicSize` is commented out - so the stage loads on a black screen, the
// intro's timer clears it (6372), 'Triggers Universal' 2 raises it again (13619)
// and 'Triggers Paranoia' 1 (13591) and 4 (13680/13686) clear it.
var mmBlackBar:FlxSprite;
function mmGetBlackBar():FlxSprite {
	if (mmBlackBar == null) {
		mmBlackBar = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		mmBlackBar.scrollFactor.set();
		mmBlackBar.alpha = 0;
		mmBlackBar.cameras = [mmGetBarCam()];
		add(mmBlackBar);
	}
	return mmBlackBar;
}

// The source's `virtuabg` (PlayState.hx:2412): a plain colour fill, 0xFF571900 -
// the dark red-brown the 'Mr. Virtual' half of the song happens in - that
// 'Triggers Universal' 2 fades in (13618) and 'Triggers Paranoia' 4 fades out
// again (13679/13685). It is a `makeGraphic` fill rather than a BGSprite, which
// is why port_stages.py could not lift it into the stage XML, so it is built
// here at the same depth instead: the source adds it right after `yourhead` and
// before the level geometry, so only the geometry drawn over it (and vwall,
// which has already faded out by then) shows through.
// NOTE: a stage script's parent is the *PlayState*, not the Stage (ScriptPack.add
// -> __configureNewScript sets the pack's parent on every script, and
// Stage.loadXml only injects the stage's sprites as variables), so a bare
// `add()`/`insert()`/`members` here is the state's draw list. The stage's own
// sprites already live in that list (`Stage.addSprite`), so `yourhead` can be
// found there directly - unlike `stage.members`, which does not exist and threw
// Null Function Pointer.
//
// Index of the first character (the top of the world layer); the girlfriend node
// is the first character node in this stage's XML and her marker sits one slot
// past her character, so `indexOf(marker) - 1` is the band start.
function mmWorldTop():Int {
	var st = PlayState.instance;
	if (st == null || stage == null) return -1;
	var poses = Reflect.field(stage, "characterPoses");
	var gfPos = (poses != null) ? poses.get("girlfriend") : null;
	if (gfPos == null) return -1;
	var i:Int = st.members.indexOf(gfPos);
	return (i >= 0) ? i - 1 : -1;
}

function mmWorldAdd(spr) {
	var w:Int = mmWorldTop();
	if (w >= 0) insert(w, spr); else add(spr);
}

var mmVirtuaBg:FlxSprite;
function mmGetVirtuaBg():FlxSprite {
	if (mmVirtuaBg == null) {
		mmVirtuaBg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xFF571900);
		mmVirtuaBg.setGraphicSize(Std.int(mmVirtuaBg.width * 10));
		mmVirtuaBg.scrollFactor.set(0, 0);
		mmVirtuaBg.alpha = 0;

		var i:Int = members.indexOf(yourhead);
		if (i == -1) mmWorldAdd(mmVirtuaBg);
		else insert(i + 1, mmVirtuaBg);
	}
	return mmVirtuaBg;
}

// The source's `clashmario` group (2428-2477): both platforms, the four pipe
// layers and the two Koopas. 'Triggers Universal' 2 hides the whole group -
// both of its branches do it (13621 and 13628) - because the second half of the
// song happens on `crazyFloor` alone, over the `virtuabg` fill above. Nothing
// ever turns it back on, which is why the source has no platforms after that
// point either; the two Koopas are in the group as well, but they are already
// gone by then ('Triggers Paranoia' 6).
function mmSetClashVisible(on:Bool) {
	for (s in [backPipes, backFloor, frontPipes, frontFloor, cornerPipes, cornerPipes_2, turtle, turtle2]) {
		if (s != null) s.visible = on;
	}
}

// The chart replaces dad with vDialog2/vGF2/mrv2. The stage's globals still
// name its load-time cast, so reveals and icon reads must resolve the live line.
function mmMem(i:Int) {
	var ps = PlayState.instance;
	if (ps == null || ps.strumLines == null || ps.strumLines.members.length <= i) return null;
	var line = ps.strumLines.members[i];
	return (line != null && line.characters.length > 0) ? line.characters[0] : null;
}

function onEvent(event) {
	if (event.event.name != "Triggers Paranoia" && event.event.name != "Triggers Universal") return;
	var trigger = Std.parseInt(event.event.params[0]);
	if (trigger == null || Math.isNaN(trigger)) trigger = 0;

	switch (trigger) {
		case 1:
			var b1 = mmMem(1);
			var d1 = mmMem(0);
			if (b1 != null) b1.alpha = 1;
			if (d1 != null) d1.alpha = 1;
			if (mmBlackBar != null) mmBlackBar.alpha = 0;
			gfwasTaken.visible = false;
			// FOLLOWCHARS/ZOOMCHARS = true plus the (520, -1000) fly-around live in
			// MMcamera (data/songs/MMcamera.hx, mmParanoiaTrigger case 1). Anything
			// written to camFollow / camGame.zoom from here is rewritten by
			// MMcamera's mmApply on the same frame, so the tweens used to be lost.
		case 2:
			mmGetBlackBar().alpha = 1;
			yourhead.visible = true;
			crazyFloor.visible = true;   // the source's `noVirtual` branch (13620)
			mmGetVirtuaBg().alpha = 1;   // the brown the second half happens in (13618)
			mmSetClashVisible(false);    // platforms/pipes off (13621/13628)
			// The source swaps the icon here as well (`iconP1.changeIcon(
			// boyfriend.healthIcon)`), which is the icon of whatever character BF is at
			// that point ('bfsad' here). This engine has no `changeIcon` on HealthIcon -
			// it has `setIcon`, taking the name `Character.getIcon()` - so the old
			// Reflect.hasField("changeIcon") guard was silently dead and the icon never
			// moved.
			var b2 = mmMem(1);
			if (b2 != null && iconP1 != null && Reflect.hasField(iconP1, "setIcon") && Reflect.hasField(b2, "getIcon"))
				iconP1.setIcon(b2.getIcon());
			// The source spends this trigger on the ndll calls that are not ported
			// (it hides every other window and swaps the desktop wallpaper to
			// `toolate.bmp`). The window takes the whole screen 0.7 steps later,
			// from stepHit()'s case 1008 - which is where the source does it too.
			// (It used to grow here, which is 1.75s late.)
		case 3:
			turtle.offset.x = 130;
			turtle2.offset.x = 40;
			turtle.visible = true;
			turtle2.visible = true;
			turtle.playAnim("glitch");
			turtle2.playAnim("glitch");
			new FlxTimer().start(0.8, function(tmr) {
				turtle.playAnim("idle");
				turtle2.playAnim("idle");
				turtle.offset.x = 0;
				turtle2.offset.x = 0;
			});
		case 4:
			mmGetBlackBar().alpha = 0;
			crazyFloor.visible = false;
			mmGetVirtuaBg().alpha = 0;   // 13679/13685, in both of the source's branches
			// The source also un-hides timeBarBG/timeBar/timeTxt/scoreTxt here
			// (`if (!ClientPrefs.hideTime)` / `if (!ClientPrefs.hideHud)`). Nothing
			// in this port hides them individually - the chart's 'Ocultar HUD' fades
			// the whole camHUD instead - so there is nothing to restore.
			mmWindowShrink();
		case 6:
			turtle.playAnim("glitch", true);
			turtle2.playAnim("glitch", true);
			new FlxTimer().start(0.41, function(tmr) {
				turtle.visible = false;
				turtle2.visible = false;
			});
			FlxTween.tween(vwall, {alpha: 0}, 0.5, {startDelay: 0.2, ease: FlxEase.sineIn});
			// FOLLOWCHARS = ZOOMCHARS = false, camFollow -> (1200, 60) over 0.7s
			// quadOut and the 4s quadIn push of camGame.zoom/defaultCamZoom to 1.4
			// are MMcamera's (mmParanoiaTrigger case 6) - it writes those two
			// properties every frame, so the tweens here never showed.
			new FlxTimer().start(1, function(tmr) {
				gfwasTaken.visible = true;
				gfwasTaken.playAnim("dies");
			});
		// --- the dupe section: 'Triggers Universal' 7/8/9 ------------------ //
		// The source keeps these in the same trigger switch. 8 arms the
		// effect and sets how often it steps, 9 sets the multiplier it steps
		// back down from, 7 sets the multiplier directly and un-mirrors the
		// tiles. The per-beat stepping itself is in beatHit() (this file).
		case 7:
			mmDupeSetMult(Std.parseFloat(mmTriggerValue2(event)), false);
		case 8:
			mmSetDupeTimer(Std.parseInt(mmTriggerValue2(event)));
		case 9:
			var wantMax = Std.parseInt(mmTriggerValue2(event));
			if (wantMax != null) mmDupeMax = wantMax;
	}
}
// === end MM stage triggers ===
