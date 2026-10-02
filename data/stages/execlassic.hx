

// === MM stage triggers (auto) ===
// 'Triggers Its a me' - ported from PlayState.hx:9498-9527, together with the
// stage half of `case 'execlassic'` (1063-1130, 4346-4350, 6419-6428).
//
// The stage is shared by 'Its a me' and 'Its a me Old', which is exactly what
// the source's create splits on (`if (PlayState.SONG.song != 'Its a me Old')`,
// 1068): the whole overlay stack - the two fire rings, the smoke plate and the
// permanent darkening - belongs to the *modern* song. This port's
// execlassic.xml is built from the modern branch, so the old song's own art
// (1131-1160, the five `mario/EXE1/old/*` plates) is rebuilt here and the modern
// layers are hidden for it; everything below is gated on the song the same way
// the stage behaves.
//
// The case itself (the chart sends it as 'Triggers Universal' 0-1):
//   0 (188.16s) - both fire rings fade in and rise 800px over 15s (linear)
//                 while the smoke plate fades in over the same 15s (quadInOut).
//   1 (209.50s) - the black curtain drops over 3s, camHUD fades out over 5s and
//                 the pixel blur (SMWPixelBlurShader =
//                 `shaders/mosaicShader.frag`) ramps its block size 1 -> 20 over
//                 3s. Its `camGame.zoom -> 1.3` (5s, sineIn) half is in
//                 songs/MMcamera.hx (`mmExeTrigger`), because the camera script
//                 owns every zoom write - a zoom tween here would be
//                 overwritten by mmApply every frame.
//
// camEst placement. The source's extra camera sits *between* camGame and camHUD
// (it is added right after camGame, 832-835), so its sprites draw above the
// world and the fighters but *below* the HUD. That matters here: fogblack is a
// 0.8-alpha full-screen darkening that is on for the whole song, and the health
// bar, the notes and the combo text have to stay readable through it. The port
// therefore does not build an overlay camera of its own (the shape
// allfinal.hx/wetworld.hx use when the source's camEst layer *is* the whole
// presentation, and which would sit above camHUD here and dim it); the three
// sprites are appended to the state's draw list - drawn on camGame, after the
// stage group and the characters, the slot exesequel.hx lifts platform2 into -
// and given scrollFactor(0, 0), which is screen-space, exactly like camEst's
// never-scrolled view. Their creation order (smoke, darkening, curtain) is the
// source's own, because that is what decides who draws over whom.

var mmFireOverlay = null;   // 'mario/EXE1/smoke' on camEst, 1280x720, alpha 0
var mmFog = null;           // 'mario/EXE1/dark' on camEst, alpha 0.8, screenCenter
var mmBlackBar = null;      // full-screen black on camEst, alpha 0
var mmIntro = null;         // the countdown's black, on camHUD
var mmMosaic = null;        // SMWPixelBlurShader, `effect` in the source
var mmMosaicVal = null;     // {v} holder the 1 -> 20 ramps in

// The stage's song (PlayState.SONG.meta.displayName is what a script can see).
// An exact match, not a prefix: 'Its A Me Old' starts with 'Its A Me'.
function mmSongIs(name:String):Bool {
	var meta = (PlayState.SONG != null) ? PlayState.SONG.meta : null;
	if (meta == null) return false;
	return StringTools.trim(Std.string(meta.displayName)) == name;
}

// A screen-space sprite, appended to the draw list (see the header).
function mmScreen(spr) {
	spr.scrollFactor.set(0, 0);
	add(spr);
	return spr;
}

// The source's `remove(x); add(x)` on one of its own state sprites means "move
// to the very front of the draw list". A stage sprite already lives in this
// state's draw list (`Stage.addSprite`), so it is that same remove + re-add -
// but neither call does what it says on its own: `FlxGroup.remove(basic,
// splice = false)` only nulls the slot (`members[index] = null`) and
// `FlxGroup.add` re-fills the *first* null slot (`getFirstNull()` =
// `members.indexOf(null)`), which is that very slot, so the pair is a no-op and
// the sprite never leaves the world layer. Splice it out and append it past the
// end of the list instead.
function mmToFront(obj) {
	remove(obj, true);
	insert(members.length, obj);
}

// ---------------------------------------------------------------------------
// 'Its a me Old' (1131-1160)
// ---------------------------------------------------------------------------
// The old song's own art: five plain `mario/EXE1/old/*` plates, all added in the
// create switch (so all below the characters), at the source's scales. The old
// song's camera row is (420,450,0.9) for dad and (720,450,0.9) for BF (1132-1139)
// - not the modern table's (songs/MMcamera.hx).
function mmWorldTop():Int {
	var st = PlayState.instance;
	if (st == null || stage == null) return -1;
	var poses = Reflect.field(stage, "characterPoses");
	var gfPos = (poses != null) ? poses.get("girlfriend") : null;
	if (gfPos == null) return -1;
	var i:Int = st.members.indexOf(gfPos);
	return (i >= 0) ? i - 1 : -1;
}

function mmCam(which:String, args:Array<Dynamic>):Dynamic {
	var ps = PlayState.instance;
	if (ps == null || ps.scripts == null) return null;
	var api:Dynamic = ps.scripts.get("mmCamera");
	if (api == null) return null;
	if (!Reflect.hasField(api, which)) return null;
	return Reflect.callMethod(api, Reflect.field(api, which), args);
}

var mmOldPlates = [];

function mmOldPlate(path:String, x:Float, y:Float, sx:Float, sy:Float, scale:Float) {
	var s = new FunkinSprite(x, y);
	s.loadGraphic(Paths.image(path));
	s.scrollFactor.set(sx, sy);
	s.scale.set(scale, scale);
	s.updateHitbox();
	s.antialiasing = true; // ClientPrefs.globalAntialiasing, taken as on
	return s;
}

function mmBuildOldStage() {
	if (mmOldPlates.length > 0) return;

	// The XML carries the modern branch's art.
	if (bg != null) bg.visible = false;
	if (castillo != null) castillo.visible = false;
	if (suelo != null) suelo.visible = false;
	if (bloques != null) bloques.visible = false;
	if (fireL != null) fireL.visible = false;
	if (fireR != null) fireR.visible = false;

	// 1141-1160, back-to-front so the source's order survives the insert loop.
	var a = mmOldPlate("mario/EXE1/old/Brick3", -100, -100, 0.45, 0.45, 1.3);
	var b = mmOldPlate("mario/EXE1/old/Brick4", -100, -100, 0.55, 0.55, 1.3);
	var c = mmOldPlate("mario/EXE1/old/BricksBG1", -300, -100, 1, 1, 1.4);
	var d = mmOldPlate("mario/EXE1/old/Brick5", -60, 190, 1, 1, 1.3);
	var e = mmOldPlate("mario/EXE1/old/BricksBG2", -100, -100, 0.95, 0.95, 1.3);
	mmOldPlates = [a, b, c, d, e];
	for (s in [e, d, c, b, a]) {
		var i = mmWorldTop();
		if (i >= 0) insert(i, s); else add(s);
	}

	// The row is re-sent once from update(): `mmCam` is a no-op until
	// MMcamera's own postCreate has published its api, nothing orders the two
	// scripts' postCreate calls, and if this one ran first the old song would keep
	// the shared `execlassic` row (400,350 / 1020,500 at 0.5) all song.
	mmCam("setCam", ["dad", 420, 450, 0.9]);
	mmCam("setCam", ["bf", 720, 450, 0.9]);
	mmOldCamPending = true;
}

var mmOldCamPending:Bool = false;

function mmOldCamApply() {
	var ps = PlayState.instance;
	if (ps == null || ps.scripts == null || ps.scripts.get("mmCamera") == null) return;
	mmCam("setCam", ["dad", 420, 450, 0.9]);
	mmCam("setCam", ["bf", 720, 450, 0.9]);
	mmOldCamPending = false;
}

// `if (!ClientPrefs.lowQuality)` (9519) is not script-reachable; the engine's own
// shader switch stands in for it, the same check hatebg.hx makes.
function mmShadersAllowed():Bool {
	if (Options == null) return true;
	if (!Reflect.hasField(Options, "gameplayShaders")) return true;
	return Options.gameplayShaders;
}

function mmGetFog() {
	if (mmFog == null) {
		mmFog = new FlxSprite(0, 0);
		mmFog.loadGraphic(Paths.image("mario/EXE1/dark")); // a plain image, no .xml
		mmFog.alpha = 0.8;
		mmFog.screenCenter();
		mmScreen(mmFog);
	}
	return mmFog;
}

function mmGetFireOverlay() {
	if (mmFireOverlay == null) {
		mmFireOverlay = new FlxSprite(0, 0);
		mmFireOverlay.loadGraphic(Paths.image("mario/EXE1/smoke")); // a plain image
		mmFireOverlay.alpha = 0;
		mmFireOverlay.screenCenter();
		mmScreen(mmFireOverlay);
	}
	return mmFireOverlay;
}

function mmGetBlackBar() {
	if (mmBlackBar == null) {
		mmBlackBar = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		mmBlackBar.scale.set(10, 10); // source's setGraphicSize(width * 10)
		mmBlackBar.alpha = 0;
		mmScreen(mmBlackBar);
	}
	return mmBlackBar;
}

// 9516-9526. The source arms the shader at strength 40 and then immediately
// tweens 1 -> 20 over 3s, so 40 never survives a frame; only the ramp is
// reproduced, driven from update() because a two-element uniform array cannot be
// written by a tween (the same split virtual.hx uses for the CRT boot-up).
function mmMosaicStart() {
	if (mmMosaic != null || mmMosaicVal != null) return;
	if (!mmShadersAllowed() || camGame == null) return;
	mmMosaic = new CustomShader("mosaicShader");
	mmMosaic.data.uBlocksize.value = [1, 1];
	camGame.addShader(mmMosaic);
	mmMosaicVal = {v: 1.0};
	FlxTween.tween(mmMosaicVal, {v: 20.0}, 3);
}

function update(elapsed:Float) {
	if (mmOldCamPending) mmOldCamApply();
	if (mmMosaic == null || mmMosaicVal == null) return;
	mmMosaic.data.uBlocksize.value = [mmMosaicVal.v, mmMosaicVal.v];
}

function postCreate() {
	if (mmSongIs("Its A Me")) {
		// 4346-4350: `bloques` (the brick layer) is added *after* the character
		// groups, i.e. in front of the fighters. Every sprite in a Codename stage
		// XML sits below them, so it is lifted out of the world layer to the front.
		if (bloques != null) mmToFront(bloques);
	} else {
		mmBuildOldStage();
	}

	// 6419-6428 (`else if (curStage == 'execlassic')` in startCountdown): the
	// countdown runs behind a full-screen black that fades off over one second.
	// Stage-level, so both songs get it (this stage keeps its READY/SET/GO - the
	// source never sets `noCount` here).
	mmIntro = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
	mmIntro.scale.set(10, 10);
	mmIntro.cameras = [camHUD];
	add(mmIntro);
	FlxTween.tween(mmIntro, {alpha: 0}, 1, {ease: FlxEase.quadInOut});

	if (!mmSongIs("Its A Me")) return; // 'Its a me Old': no overlay stack
	// The source's own creation order (1102 smoke, 1109 dark, 1114 curtain) is
	// the draw order here too: each `add()` appends above the last.
	mmGetFireOverlay();
	mmGetFog();       // 1109-1116, always on
	mmGetBlackBar();
}

// ---------------------------------------------------------------------------
// 'Triggers Its a me' 0-1
// ---------------------------------------------------------------------------
// Sent as 'Triggers Universal' by the chart (the source re-dispatches that to
// 'Triggers <song>' at runtime, 9489-9496), so both names are accepted - the
// same shape every other stage script here uses.
function onEvent(event) {
	if (event.event.name != "Triggers Its a me" && event.event.name != "Triggers Universal") return;
	if (!mmSongIs("Its A Me")) return; // the old song has its own art and no beats

	var trigger = Std.parseInt(event.event.params[0]);
	if (trigger == null || Math.isNaN(trigger)) trigger = 0;

	switch (trigger) {
		case 0:
			// 9504-9511: the two rings come up and drift 800px upwards; the
			// smoke fades in over the same 15s (quadInOut). The tweened `y` is
			// read at trigger time, like the source does.
			if (fireL != null) {
				fireL.alpha = 1;
				FlxTween.tween(fireL, {y: fireL.y - 800}, 15, {ease: FlxEase.linear});
			}
			if (fireR != null) {
				fireR.alpha = 1;
				FlxTween.tween(fireR, {y: fireR.y - 800}, 15, {ease: FlxEase.linear});
			}
			FlxTween.tween(mmGetFireOverlay(), {alpha: 1}, 15, {ease: FlxEase.quadInOut});

		case 1:
			// 9514-9526: the ending blackout. No ease on the curtain (3s), the
			// HUD fades over 5s, then the pixel blur comes up.
			FlxTween.tween(mmGetBlackBar(), {alpha: 1}, 3);
			if (camHUD != null) FlxTween.tween(camHUD, {alpha: 0}, 5);
			mmMosaicStart();
	}
}
// === end MM stage triggers ===
