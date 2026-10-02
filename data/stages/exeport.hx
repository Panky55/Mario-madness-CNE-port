

// === MM stage triggers (auto) ===
// 'Triggers Powerdown' (exeport) - the whole song's staging, ported from
// PlayState.hx:
//
//   1385-1514   the stage's own create branch (both songs)
//   4431-4444   the exeport foreground: lightmx / killMX / gfFall / gfwasTaken
//   4684-4790   the camEst layer: blackBarThingie, screencolor, turnevil,
//               mxLaughNEW, mxLaugh, liveScreen, estatica (both songs)
//   6281-6296   the mid-song opening in startCountdown(): the static loop, the
//               two-second hold and the 3s static/TV/HUD cross-over
//   7770-7794   update(): the GF-death cinematic, driven off killMX's frames
//   10907-11005 'MX salto' (the jumpscare, shared with data/events/Char Attack)
//   11016-11161 'Triggers Powerdown' itself
//   16244-16257 beatHit(): turnevil's three beats and the creepy idles
//   16460-16485 beatHit(): the beat-496 killMX reset
//
// ---------------------------------------------------------------------------
// Two songs, one stage
// ---------------------------------------------------------------------------
// `powerdown` and `powerdown-old` both run on `exeport`, and their trigger
// numbers do not mean the same thing: the modern chart sends 3 / 4 (x4) / 5 / 6
// at 44.1-193.8s and 0 / 1 / 2 / 7 through 'Triggers Universal' at 164.9-170.3s,
// while `powerdown-old` sends only 0 (118.61s) / 1 (122.08s) / 2 (124.08s).
// That is the source's own split - cases 0/1/2 branch on
// `PlayState.SONG.song == 'Powerdown Old'` and everything else is shared - so
// mmIsPowerdownOld() (the song's display name) is the test, and the earlier
// version of this script had the two branches crossed over: it ran the Old
// song's black-bar-and-flash on every modern case 1/2 and never built the
// modern song's own `mxLaughNEW` beat at all.
//
// ---------------------------------------------------------------------------
// Where the camEst layer goes
// ---------------------------------------------------------------------------
// Psych's extra camera sits *between* camGame and camHUD (826-836: it is added
// right after camGame), so this whole stack draws above the world and the
// fighters but *below* the HUD - which is the point of the powerdown moment:
// at case 3 (44.14s) the screen goes black, the health bar and both icons fade
// out, and the notes keep coming down over the black (the chart has notes at
// 44.14s and 45.17-45.52s, exactly under it). Codename only has camGame/camHUD,
// so the port rebuilds the layer out of two pieces that both end up under
// camHUD:
//
//   * the two full-screen *fills* (blackBarThingie, screencolor) go on the
//     state's draw list with scrollFactor(0, 0) - appended after the characters
//     and therefore under camHUD, the slot execlassic.hx uses for its camEst
//     darkening - so the notes stay visible through the blackout, as they are
//     in the source. A scrollFactor-0 sprite is still *scaled* by its camera's
//     zoom, though (about the screen centre), and this song's chart drives
//     camGame hard: 'Set Cam Zoom 0.25 dad' at 45.53s and, right at the
//     transformation, `Camera Zoom Chain ['0.04, 0.05, 0.005, 0.002', '16, 2']`
//     at 46.88s - a 25x zoom-*out*. A fixed graphic cannot survive that: the
//     first version of this shipped built 8x the screen, which at 0.04 renders
//     at a third of the screen, i.e. the blackout shows up as a small black box.
//     So the graphic is exactly screen-sized at 0,0 (origin = frame centre, so
//     its centre *is* the window centre at any zoom) and mmFitFills() re-scales
//     it by 1 / camGame.zoom every frame - a screen-space fill, which is what
//     camEst gives the source for free. The three camera flashes (`FlxG.camera`
//     .flash, whose own sprite is sized to the *unzoomed* rect) are drawn as a
//     write + fade on those same fills for the same reason - see mmFlash().
//
//   * the five *art* sprites (turnevil, mxLaughNEW, mxLaugh, liveScreen,
//     estatica) and both MX faces go on a camera of this script's own (mmEst())
//     that is a *twin of camHUD*: a plain FlxCamera at camHUD's own size, zoom
//     1, never scrolled, added with defaultDraw=false and then slid into
//     camHUD's slot in `FlxG.cameras.list` - after camGame, before camHUD,
//     which is where Psych's camEst sits. As screen-space sprites on camGame
//     they would be shrunk to a quarter by that same chart zoom; on camHUD
//     itself they would be invisible for the whole intro (the port holds camHUD
//     at alpha 0 until the 3s cross-over) and y-flipped on downscroll (CNE's
//     HudCamera flips positions, not sprites). Slid in underneath instead, the
//     notes and the HUD keep drawing over them - the thing the source gets for
//     free from camEst, and the thing the earlier version of this script got
//     wrong by appending its camera last.
//
// The relative order of everything is the source's own creation order:
// blackBarThingie -> screencolor -> turnevil -> mxLaughNEW -> mxLaugh ->
// liveScreen -> estatica (4684-4790), and the MX faces are on the same camera
// as the art sprites, created by mmMxSalto before it needs them.
//
// ---------------------------------------------------------------------------
// Deviations
// ---------------------------------------------------------------------------
//   * `boyfriendGroup.color.saturation = 0` (4574, the greyscale BF) is not
//     reproduced: a colour transform's saturation is not script-reachable here
//     (only FlxTween.color is, and that is an RGB tween).
//   * the source's `FlxG.sound.music.volume -> 0` at the 3s mark would fade the
//     *song's* instrumental to silence here - Codename plays the inst as
//     FlxG.sound.music - so the port leaves it alone and stops its own static
//     loop instead, one second into the song (the same moment, and the source's
//     only audible effect once startSong() has replaced the static with the
//     inst at the two-second mark).
//   * case 7's mid-song video (`midsongVid` + `videos/Powerdownscene.mp4`) is
//     driven through hxvlc's FlxVideoSprite, which the engine bundles (its
//     `load`/`play`/`stop` and `onEndReached`/`finishCallback` all appear in the
//     binary and libvlc is linked). No script in this mod or in the engine has
//     ever driven one, so every call is made through Reflect and wrapped in
//     try/catch - see the video section below. The source's pause/resume of the
//     bitmap (7124/7583) is not reproduced: a paused game does not tick the
//     video either way.
//   * `PauseSubState.muymalo = 2` (case 5) and `FlxG.game.blendMode =
//     BlendMode.OVERLAY` (the static flash inside 'MX salto') are not
//     script-reachable; the alpha half of that flash is kept. The same goes for
//     the `gf.specialAnim = true` / `boyfriend.specialAnim = true` flags the
//     salto sets next to its 'hurt' animations - `playAnim(name, true)` already
//     forces the animation here.
//   * `ClientPrefs.filtro85` gates the creation of `estatica` and its fade at
//     case 6, and `ClientPrefs.flashing` gates the red flashes - neither is
//     script-reachable, so both are taken as on (the choice every other stage
//     script in this port makes).
//   * the create branch's `tvEffect = true` (1391) is ported: this stage sets it
//     without `oldTV`, so it mounts VCRMario85 + VCRBorder on camGame, camHUD and
//     the camEst layer (see "The TV filter stack" below) - and the same is true
//     of demiseport.hx now. The branch's `GameOverSubstate.characterName` /
//     `loopSoundName` / `endSoundName` ride `songs/MMcamera.hx`'s game-over
//     table (this stage's row is `bf_PDdeath`) and its `addCharacterToList`
//     preloads run from `mmPreloadAll()` at script load, the way
//     allfinal.hx/promoshow.hx do (see the preload section below).
//     The branch's second, unused VideoSprite (`vid`, 1515-1524: created
//     hidden, never shown) is dead in the source and is not built at all.
//   * `estatica`'s atlas is the one the source builds in its `else` (the
//     `ClientPrefs.lowQuality` branch uses 'modstuff/static' at 10x, which is
//     not reachable either).
//   * the dodge is the player's own - SPACE, `bfJump()`'s `funnylayer0` jump on
//     the modern song and BF's 'dodge' animation on 'Powerdown Old' (see the
//     dodge section below). The bot half is in as well: `mmPlayerBot()` reads
//     the player strumline's `cpu` flag (CNE's `cpuControlled`) and fires the
//     source's auto-jump at the apex (10976) / Old's auto-dodge on the landing
//     (11007), and the same flag gates the landing damage.
//   * 'Powerdown Old' plays the modern extract's art (the same pre-existing gap
//     execlassic.hx documents): the source's Old branch builds its own backdrop
//     ('mario/MX/old/*') that the extractor never lifted, and its
//     `epicbgthings.visible = true` (case 5) never runs on that chart, so the
//     port reveals the extracted backdrop at load for the old song and leaves
//     the modern reveal to case 5.

// Logs the failures this script can actually hit - a camera list it cannot
// reach, an atlas the preload cannot find - and nothing else. The probe
// scaffolding it carried while the staging was debugged (a per-frame/per-beat
// heartbeat, per-event dumps, the hit/miss counters) is gone.
function mmLog(msg:String) trace("[MM exeport] " + msg);

// ---------------------------------------------------------------------------
// The overlay camera
// ---------------------------------------------------------------------------
var mmEstCam:FlxCamera = null;
var mmEstPlaced:Bool = false;
var mmEstWarned:Bool = false;

// `Reflect.field` rather than `FlxG.cameras.list` directly: the array is a real
// field of the engine's camera front end, but a lookup that comes back empty
// must leave the camera where it is, not take the script down with it. (Reflect
// is already used this way in turmoilsweep.hx.)
function mmCamList() {
	return Reflect.field(FlxG.cameras, "list");
}

function mmHudIndex():Int {
	var list = mmCamList();
	if (list == null || camHUD == null) return -1;
	return list.indexOf(camHUD);
}

function mmEst():FlxCamera {
	if (mmEstCam == null) {
		mmEstCam = new FlxCamera(0, 0, mmCamW(), mmCamH());
		mmEstCam.bgColor = FlxColor.TRANSPARENT;
		mmEstCam.zoom = 1;
		FlxG.cameras.add(mmEstCam, false); // defaultDraw=false -> world not redrawn
		mmEstBelowHud();
	}
	return mmEstCam;
}

// Psych's camEst is a bare `new FlxCamera()` (827) added right after camGame and
// therefore *before* camHUD (833-836): the same view rectangle as the HUD, with
// its own canvas composited under the HUD's. Codename has only camGame and
// camHUD (PlayState.create: `camHUD = new HudCamera()`, added with
// defaultDraw=false), and in flixel a camera's canvas is composited in
// `FlxG.cameras.list` order - so the port adds its camera the normal way and
// then slides it in at camHUD's own index: after camGame, before camHUD, i.e.
// camEst's slot. Everything on it is then under the notes and the HUD.
function mmEstBelowHud() {
	if (mmEstCam == null || mmEstPlaced) return;
	var list = mmCamList();
	if (list == null) {
		if (!mmEstWarned) {
			mmEstWarned = true;
			mmLog("camEst: no FlxG.cameras.list - the layer stays above camHUD");
		}
		return;
	}
	list.remove(mmEstCam); // no-op when it is not in the list yet
	var at:Int = mmHudIndex(); // camHUD's index *after* the removal
	if (at < 0) {
		list.push(mmEstCam); // no camHUD yet: stay on top and try again next frame
		return;
	}
	list.insert(at, mmEstCam);
	mmEstPlaced = true;
}

// camEst and camHUD are the same rectangle in Psych (both are bare FlxCameras
// there), so the layer is pinned to camHUD's size rather than assumed to be
// FlxG's: if the engine ever resizes the HUD camera the art follows it, and a
// stale rectangle cannot crop a full-screen plate down to a corner of the
// screen. Two compares unless something actually changed.
function mmEstSize() {
	if (mmEstCam == null) return;
	var w = mmCamW();
	var h = mmCamH();
	if (mmEstCam.width != w) mmEstCam.width = w;
	if (mmEstCam.height != h) mmEstCam.height = h;
}

function mmCamW() {
	return (camHUD != null) ? camHUD.width : FlxG.width;
}

function mmCamH() {
	return (camHUD != null) ? camHUD.height : FlxG.height;
}

// The source's camEst puts a sprite in screen coordinates (the camera is never
// scrolled and never zoomed); a sprite on mmEst with default scrollFactor is
// the same thing.
function mmEstAdd(spr) {
	spr.cameras = [mmEst()];
	add(spr);
	return spr;
}

// ---------------------------------------------------------------------------
// The TV filter stack (1391 + 5647-5663)
// ---------------------------------------------------------------------------
// `case 'exeport'` sets `tvEffect` (1391) without `oldTV`, so the source mounts
// exactly two filters, `[VCRMario85, VCRBorder]`, on camGame, camEst and camHUD
// (5651-5663) while `ClientPrefs.filtro85` is on - which this port takes as on,
// like every other stage script. The camEst layer here is mmEst(); the pair
// lives in shaders/vcr85.frag and shaders/vcrBorder.frag, mounted from
// postCreate and driven from postUpdate with `vcr.update(elapsed)`'s own
// accumulation of the time uniform (7241). The border has no uniform of its own.
var mmVcr = null;            // VCRMario85 -> shaders/vcr85.frag
var mmVcrBorder = null;      // VCRBorder -> shaders/vcrBorder.frag
var mmTvOn:Bool = false;
var mmTvTime:Float = 0;

// Same read virtual.hx/promoshow.hx make: with the engine's "Gameplay Shaders"
// option off, `new CustomShader(...)` stays null and its setters no-op.
function mmShadersAllowed():Bool {
	if (Options == null) return true;
	if (!Reflect.hasField(Options, "gameplayShaders")) return true;
	return Options.gameplayShaders;
}

function mmTvMountAll(s) {
	if (s == null) return;
	if (camGame != null) camGame.addShader(s);
	if (camHUD != null) camHUD.addShader(s);
	var est = mmEst();
	if (est != null) est.addShader(s);
}

// `addShader` appends, so mounting vcr before border on each camera reproduces
// the source's `[vcr, border]` filter order. Each is mounted as soon as it is
// built, so a shader that fails to compile cannot cost the other its mount (see
// the oldTv.frag header for the one that did).
function mmTvStack() {
	if (mmTvOn || !mmShadersAllowed()) return;
	mmTvOn = true;
	mmVcr = new CustomShader("vcr85");
	mmTvMountAll(mmVcr);
	mmVcrBorder = new CustomShader("vcrBorder");
	mmTvMountAll(mmVcrBorder);
}

// `vcr.update(elapsed)` (7241) only accumulates the shader's own time uniform.
function mmTvTick(elapsed:Float) {
	if (mmVcr == null) return;
	mmTvTime += elapsed;
	mmVcr.data.time.value = [mmTvTime];
}

// A plain-image layer, `new FlxSprite(0, 0); loadGraphic(...)` in the source.
function mmEstImage(path:String, scale:Float, alpha:Float) {
	var s = new FlxSprite(0, 0);
	s.loadGraphic(Paths.image(path));
	s.antialiasing = false;
	if (scale != 1) s.setGraphicSize(Std.int(s.width * scale));
	s.alpha = alpha;
	s.updateHitbox();
	s.screenCenter();
	mmEstAdd(s);
	return s;
}

// A sparrow-atlas layer: `new BGSprite(asset, ...)` + animation.addByPrefix.
// The source's animation names and frame prefixes differ
// (`addByPrefix('laugh', "MX Transformation", 24, false)`), so both are taken.
//
// `autoPlay` mirrors the source's own create block (4684-4790): only the two
// *looping* idle layers are played there - `mxLaugh.animation.play('idle')` and
// `estatica.animation.play('idle')` - while `turnevil` and `mxLaughNEW` are left
// on frame 0 (`curAnim` null) and played by whichever trigger uses them.
// Playing a one-shot at creation consumes it: it finishes during the intro, and
// Flixel's `play(name)` without a force flag does not restart the animation that
// is already current - so the 45.5s transformation and the 164.9s laugh were
// both frozen on their first frame here.
function mmEstAnim(path:String, anim:String, prefix:String, fps:Int, loop:Bool, alpha:Float, autoPlay:Bool) {
	var s = new FlxSprite(0, 0);
	s.frames = Paths.getSparrowAtlas(path);
	s.animation.addByPrefix(anim, prefix, fps, loop);
	if (autoPlay) s.animation.play(anim);
	s.alpha = alpha;
	mmEstAdd(s);
	return s;
}

// ---------------------------------------------------------------------------
// The camEst layer itself (4684-4790)
// ---------------------------------------------------------------------------
// (The builders below are functions of the same name, so the cached sprites
// carry a suffix - HScript holds both in one namespace.)
var mmBlackBar = null;        // blackBarThingie, screen-sized, alpha 0
var mmScreenColorSpr = null;  // screencolor, red, alpha 0  (both below camHUD)
var mmTurnevilSpr = null;     // MX_Transformation_Assets, 'laugh'
var mmMxLaughNewSpr = null;   // MX_Dialogue_Asseta, 'freddyfazbear'
var mmMxLaughSpr = null;      // modstuff/MX_Assets_Laugh_v1, 'idle' (Old)
var mmLiveScreenSpr = null;   // modstuff/mxscreen, 3x - the opening's TV frame
var mmEstaticaSpr = null;     // modstuff/Mario_static, 'idle', alpha 0.05

// A full-screen fill for the state's draw list (see the header): exactly the
// screen's size at 0,0, with the origin on its centre, and re-scaled against
// camGame's zoom every frame by mmFitFills().
function mmFill(colour:Int) {
	var s = new FlxSprite(0, 0);
	s.makeGraphic(FlxG.width, FlxG.height, colour);
	s.scrollFactor.set(0, 0);
	s.updateHitbox();
	s.alpha = 0;
	add(s);
	return s;
}

// `1 / zoom` puts the fill back to window size (and the 5% margin absorbs the
// rounding on a fractional zoom). Called every frame from postUpdate, for both
// songs - only while the fill is actually visible, so an idle fill costs
// nothing.
function mmFitFills() {
	if (camGame == null) return;
	var z:Float = camGame.zoom;
	if (z <= 0.0001) z = 1;
	var k:Float = 1.05 / z;
	if (mmBlackBar != null && mmBlackBar.alpha > 0.001) mmBlackBar.scale.set(k, k);
	if (mmScreenColorSpr != null && mmScreenColorSpr.alpha > 0.001) mmScreenColorSpr.scale.set(k, k);
}

function mmBar() {
	if (mmBlackBar == null) mmBlackBar = mmFill(FlxColor.BLACK);
	return mmBlackBar;
}

function mmScreenColor() {
	if (mmScreenColorSpr == null) mmScreenColorSpr = mmFill(FlxColor.RED);
	return mmScreenColorSpr;
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

// `FlxG.camera.flash(colour, sec)` in the source (blackBarThingie.alpha = 0 plus
// a camera flash, and the two red ones of cases 1/2). The engine's own flash
// sprite is sized to the camera's *unzoomed* rect, so on a chart that drives
// camGame down to 0.25-0.6 it comes out as a small box in the middle of the
// screen instead of a wash - which is what the 46.90s reveal's black flash (and
// the red ones) looked like. The port's fills are screen-space (mmFitFills), so
// the flash is a write + fade on those instead: same colour, same duration, same
// slot (the source flashes FlxG.camera, i.e. camGame - below camHUD, so the notes
// stay on top of it), but always the size of the window.
function mmFlash(colour:Int, dur:Float) {
	var f = (colour == FlxColor.RED) ? mmScreenColor() : mmBar();
	f.alpha = 1;
	FlxTween.tween(f, {alpha: 0}, dur);
}

// ---------------------------------------------------------------------------
// Case 7's mid-song video (see the header)
// ---------------------------------------------------------------------------
// Psych's `VideoSprite` is hxcodec; Codename links hxvlc, whose sprite is
// `hxvlc.flixel.FlxVideoSprite` (FlxSprite subclass, `load(path)` -> Bool then
// `play()`). It is fetched with Type.resolveClass rather than constructed
// directly because HScript's global scope does not import hxvlc - the class is
// reachable only because it is compiled into the engine.
//
// Everything here is best-effort and silent on failure: if the class is not
// resolvable, if libvlc is missing, or if this hxvlc revision names things
// differently, the trigger logs one line and the song plays on without the
// video (which is exactly what the port did before this was attempted).
//
// The clip is 1.5s long, and the source's `finishCallback` hides the sprite and
// red-flashes the screen at the end. Both known end signals (`onEndReached` and
// `finishCallback`) are set, and a fallback timer one second past the clip's
// length guarantees the overlay never outlives it even if neither fires.
var mmVid = null;
var mmVidTried:Bool = false;
var mmVidFinished:Bool = false;

function mmCall(obj, name:String, args:Array<Dynamic>):Bool {
	if (obj == null) return false;
	var fn = Reflect.field(obj, name);
	if (fn == null) return false;
	Reflect.callMethod(obj, fn, args);
	return true;
}

// The source's `finishCallback`: hide the sprite, then `FlxG.camera.flash(RED, 1)`
// (through the port's own fill-based flash, like every other flash on this
// chart's 0.25-0.6 zooms). Idempotent - the callback and the fallback timer both
// call it.
function mmVidDone() {
	if (mmVidFinished) return;
	mmVidFinished = true;
	if (mmVid != null) mmVid.visible = false;
	mmFlash(FlxColor.RED, 1);
}

function mmMidsongVideo() {
	if (mmVidTried) return mmVid;
	mmVidTried = true;
	try {
		var cls = Type.resolveClass("hxvlc.flixel.FlxVideoSprite");
		if (cls == null) {
			trace("[MM exeport] case 7: hxvlc.flixel.FlxVideoSprite is not script-reachable - the mid-song video is skipped");
			return null;
		}
		mmVid = Type.createInstance(cls, []);
		if (mmVid == null) return null;
		mmVid.scrollFactor.set(0, 0);
		mmVid.cameras = [camHUD];
		mmVid.visible = false;
		add(mmVid);
		// Both spellings of the end callback, each guarded: `Reflect.setField` on a
		// field the class does not have throws on cpp, and that would land in the
		// catch below and throw away a perfectly good sprite.
		if (Reflect.hasField(mmVid, "onEndReached"))
			Reflect.setField(mmVid, "onEndReached", function() { mmVidDone(); });
		if (Reflect.hasField(mmVid, "finishCallback"))
			Reflect.setField(mmVid, "finishCallback", function() { mmVidDone(); });
	} catch (e:Dynamic) {
		trace("[MM exeport] case 7: the video sprite could not be built - " + Std.string(e));
		mmVid = null;
	}
	return mmVid;
}

function mmPlayMidsongVideo() {
	var vid = mmMidsongVideo();
	if (vid == null) return;
	if (!Reflect.hasField(vid, "load")) {
		trace("[MM exeport] case 7: the video sprite has no load() - the mid-song video is skipped");
		mmVidDone();
		return;
	}
	var loaded:Bool = false;
	try {
		// The source asks for `Paths.video('powerdownscene')` while the file is
		// videos/Powerdownscene.mp4 - a Windows-only case bug (audit_port.py's
		// check 2 reports it too). The port asks for the name that exists.
		loaded = Reflect.callMethod(vid, Reflect.field(vid, "load"), [Paths.video("Powerdownscene")]) == true;
	} catch (e:Dynamic) {
		loaded = false;
	}
	if (!loaded) {
		trace("[MM exeport] case 7: the mid-song video did not load ('Powerdownscene.mp4')");
		vid.visible = false;
		mmVidDone();
		return;
	}
	mmVidFinished = false;
	vid.visible = true;
	mmCall(vid, "play", []);
	try {
		new FlxTimer().start(2.5, function(tmr) { mmVidDone(); });
	} catch (e2:Dynamic) {}
}

function mmTurnevil() {
	if (mmTurnevilSpr == null) {
		// 4698-4704: -500/-1000, graphicSize * 0.5, alpha 0.00001, 'laugh'. Like
		// the source it is created *visible* and only the 136 beat hides it (its
		// alpha is what keeps it out of the way until case 4 and beat 132).
		mmTurnevilSpr = new FlxSprite(-500, -1000);
		mmTurnevilSpr.frames = Paths.getSparrowAtlas("mario/MX/MX_Transformation_Assets");
		mmTurnevilSpr.animation.addByPrefix("laugh", "MX Transformation", 24, false);
		mmTurnevilSpr.setGraphicSize(Std.int(mmTurnevilSpr.width * 0.5));
		mmTurnevilSpr.alpha = 0.00001;
		mmEstAdd(mmTurnevilSpr);
		// Deliberately NOT played: the source only `addByPrefix`es this one and
		// leaves it at frame 0, and the beat-132 branch of beatHit replays it.
	}
	return mmTurnevilSpr;
}

function mmMxLaughNew() {
	if (mmMxLaughNewSpr == null) {
		// 4706-4713: -1150/200, then updateHitbox + screenCenter; 'freddyfazbear'
		// is the "Innocence" frames at 32fps, alpha 0.000001.
		mmMxLaughNewSpr = mmEstAnim("mario/MX/MX_Dialogue_Asseta", "freddyfazbear", "Innocence", 32, false, 0.000001, false);
		mmMxLaughNewSpr.setPosition(-1150, 200);
		mmMxLaughNewSpr.updateHitbox();
		mmMxLaughNewSpr.screenCenter();
	}
	return mmMxLaughNewSpr;
}

function mmMxLaugh() {
	if (mmMxLaughSpr == null) {
		// 4715-4724: -15/716, screenCenter; 'idle' is the "MXLaugh" frames at
		// 18fps, alpha 0 (the legacy song's laugh).
		mmMxLaughSpr = mmEstAnim("modstuff/MX_Assets_Laugh_v1", "idle", "MXLaugh", 18, true, 0, true);
		mmMxLaughSpr.updateHitbox();
		mmMxLaughSpr.screenCenter();
	}
	return mmMxLaughSpr;
}

function mmLiveScreen() {
	// 4765-4771: created visible at alpha 1; the opening fades it out.
	if (mmLiveScreenSpr == null) mmLiveScreenSpr = mmEstImage("modstuff/mxscreen", 3, 1);
	return mmLiveScreenSpr;
}

function mmEstatica() {
	if (mmEstaticaSpr == null) {
		// 4775-4787: 'idle' is the "static play" frames at 15fps, alpha 0.05.
		mmEstaticaSpr = mmEstAnim("modstuff/Mario_static", "idle", "static play", 15, true, 0.05, true);
		mmEstaticaSpr.updateHitbox();
		mmEstaticaSpr.screenCenter();
	}
	return mmEstaticaSpr;
}

// Every builder above is idempotent, so this can run from postCreate and again
// from anything that needs a layer before postCreate has (the countdown hold).
function mmBuildOverlays() {
	mmBar();
	mmScreenColor();
	mmTurnevil();
	mmMxLaughNew();
	mmMxLaugh();
	// The two MX faces sit between mxLaugh and liveScreen in the source's own
	// create order (4754-4790), and they are built there too - not lazily from
	// 'MX salto' like the event file this used to live in, which made the first
	// jumpscare (73.8s) decode two big PNGs in one frame.
	mmGetMxFaces();
	mmLiveScreen();
	mmEstatica();
}

// ---------------------------------------------------------------------------
// epicbgthings (1446-1461, shown at case 5)
// ---------------------------------------------------------------------------
// The source collects seven of the stage's own sprites into an FlxTypedGroup
// and creates it `visible = false`, so the first 46.9s of the modern song play
// on `bg` + `lightmx` + `shadowbg` alone and the whole backdrop arrives with the
// character swap. In the port the seven are stage XML sprites, so the group is
// this list (the same set, in the source's own order).
function mmEpicList():Array<Dynamic> {
	return [fullbg, creppyleaf, creepyCloud, bgfloor, luigiempa, luigibody, dedtoad];
}

function mmSetEpic(visible:Bool) {
	for (s in mmEpicList()) {
		if (s != null) s.visible = visible;
	}
}

// ---------------------------------------------------------------------------
// 'MX salto' (10907-11005)
// ---------------------------------------------------------------------------
// Two screen-filling MX faces on the overlay camera: 'modstuff/cuidao0' (white)
// and 'modstuff/cuidao' (coloured). Creation (4727-4764):
//   loadGraphic; setGraphicSize(width * 8); antialiasing = false;
//   cameras = [camEst]; visible = false; updateHitbox();
//   screenCenter(Y); screenCenter(X)   // the middleScroll branch puts it at x=200
// This used to live in data/events/MX salto.hx, which read PlayState fields
// nothing ever created - the sprites belong to this stage, so they live here.
var mmImgWar = null;  // coloured face
var mmImgWarB = null; // white face

function mmMxFace(path:String) {
	var s = new FlxSprite();
	s.loadGraphic(Paths.image(path));
	s.setGraphicSize(Std.int(s.width * 8));
	s.antialiasing = false;
	s.cameras = [mmEst()];
	s.visible = false;
	s.updateHitbox();
	s.screenCenter(FlxAxes.Y);
	s.screenCenter(FlxAxes.X);
	add(s);
	return s;
}

function mmGetMxFaces() {
	if (mmImgWar != null) return;
	mmImgWarB = mmMxFace("modstuff/cuidao0");
	mmImgWar = mmMxFace("modstuff/cuidao");
}

// True for the legacy 'Powerdown Old' (both the .hx song folder and the chart
// meta carry the display name).
function mmIsPowerdownOld():Bool {
	if (PlayState.SONG == null) return false;
	var meta = PlayState.SONG.meta;
	if (meta == null) return false;
	return Std.string(meta.displayName) == "Powerdown Old";
}

// FlxFlicker.flicker(spr, duration, interval, false): blink for `duration` every
// `interval` and end hidden. FlxFlicker itself is not script-reachable, so this
// toggles visibility on a timer with the same timing.
function mmFlicker(spr, duration:Float, interval:Float) {
	if (spr == null) return;
	var n:Int = Std.int(duration / interval);
	if (n < 1) n = 1;
	spr.visible = true;
	spr.alpha = 1;
	var i:Int = 0;
	new FlxTimer().start(interval, function(tmr) {
		i += 1;
		spr.visible = (i < n);
	}, n);
}

// ---------------------------------------------------------------------------
// The dodge (8155-8199) and `bfJump()` (6001-6042)
// ---------------------------------------------------------------------------
// The source's `controls.DODGE` is bound to SPACE (Controls.hx 668/714). CNE has
// no DODGE action of its own, so the raw key is what this reads - and that is
// also why the source's `!inCutscene && !endingSong && !startingSong` guards are
// read off the state through Reflect: a field CNE does not have simply reads
// false, which is the same as "not in one of those states".
var mmIsDodging:Bool = false;
var mmCanDodge:Bool = false;

function mmStateFlag(name:String):Bool {
	var st = PlayState.instance;
	if (st == null) return false;
	return Reflect.hasField(st, name) && Reflect.field(st, name) == true;
}

function mmDodgeBlocked():Bool {
	return mmIsDodging || mmCanDodge || mmStateFlag("inCutscene")
		|| mmStateFlag("endingSong") || mmStateFlag("startingSong");
}

// 8155-8199: the modern song jumps BF out of the way, unless he is already in
// his 'bfsad' form (case 2's WAHOO swaps him there); 'Powerdown Old' plays his
// 'dodge' animation for 0.4s of immunity instead. `isDodging` is what skips
// 'MX salto''s damage branch - the warning faces are the tell, and a dodge that
// covers the 0.48s between the jump and the landing is what saves the 1.2.
function mmPlayerBot() {
	return strumLines.members.length > 1 && strumLines.members[1].cpu;
}

function onPlayerHit(event) {
	if (mmIsDodging) event.preventAnim();
}

function mmDodgePoll() {
	if (mmDodgeBlocked() || mmPlayerBot()) return;
	if (!FlxG.keys.justPressed.SPACE) return;
	if (mmIsPowerdownOld()) mmDodgeAnim();
	else {
		// The 'bfsad' guard has to read the live character: the chart swaps BF
		// to `bfsad` at 169.66s, after which the source's dodge is dead. A stale
		// global still says `bf`, so the jump kept coming out.
		var bLive = mmBfChar();
		if (bLive != null && bLive.curCharacter != "bfsad") mmBfJump();
	}
}

function mmDodgeAnim() {
	var bDodge = mmBfChar();
	if (bDodge != null) bDodge.playAnim("dodge", true);
	mmIsDodging = true;
	mmCanDodge = true;
	new FlxTimer().start(0.4, function(tmr) { mmIsDodging = false; });
	new FlxTimer().start(1, function(tmr) { mmCanDodge = false; });
}

// 6001-6042, verbatim in structure: BF goes invisible and the stage's own
// `funnylayer0` (declared hidden at 1120,185 in the XML) takes his place -
// 'jump' up 250px, back down 420px, land on 'jumpend' - and the writes close the
// loop exactly (+100/-270 on y, +10/-10 on x), so the plate is back at its own
// corner for the next salto. The 0.83s timer is BF's return and the 1.23s one
// re-arms the dodge.
function mmBfJump() {
	// Never happens (the plate is in the XML) - without it there is nothing to
	// jump with, so BF's own 'dodge' keeps the mechanic alive.
	if (funnylayer0 == null) { mmDodgeAnim(); return; }

	var bJump = mmBfChar();
	if (bJump != null) bJump.visible = false;
	funnylayer0.visible = true;
	funnylayer0.animation.play("jump");
	FlxG.sound.play(Paths.sound("bfjump"));

	mmIsDodging = true;
	mmCanDodge = true;

	new FlxTimer().start(0.1, function(tmr) {
		FlxTween.tween(funnylayer0, {y: funnylayer0.y - 250}, 0.3, {ease: FlxEase.expoOut, onComplete: function(twn) {
			FlxTween.tween(funnylayer0, {y: funnylayer0.y + 420}, 0.3, {ease: FlxEase.expoIn, onComplete: function(twn2) {
				funnylayer0.x += 10;
				funnylayer0.y += 100;
				mmIsDodging = false;
				funnylayer0.animation.play("jumpend");
			}});
		}});
	});
	new FlxTimer().start(0.83, function(tmr) {
		var bBack = mmBfChar();
		if (bBack != null) bBack.visible = true;
		funnylayer0.visible = false;
		funnylayer0.y -= 270;
		funnylayer0.x -= 10;
	});
	new FlxTimer().start(1.23, function(tmr) { mmCanDodge = false; });
}

// The dad's resting y, which the salto measures its jump from (`enemyY`: set at
// the countdown, 6284, and again by case 5, 11147).
var mmEnemyY:Float = 0;

function mmMxSalto() {
	mmGetMxFaces();
	if (mmImgWar == null || mmImgWarB == null) return;

	var beat:Float = 1 / (Conductor.bpm / 60);
	var old:Bool = mmIsPowerdownOld();

	// `ClientPrefs.flashing` is not script-reachable: the flashing branch always
	// runs (the same choice the other stage scripts make).
	if (old) {
		// The legacy song blinks both faces instead of dropping them in.
		mmFlicker(mmImgWarB, 0.24, 0.12);
		new FlxTimer().start(0.24, function(tmr) { mmFlicker(mmImgWar, 0.24, 0.12); });
	} else {
		mmImgWarB.visible = true;
		mmImgWarB.scale.set(10, 10);
		mmImgWarB.y += 50;
		FlxTween.tween(mmImgWarB, {y: (FlxG.height - mmImgWarB.height) / 2}, beat, {ease: FlxEase.expoOut});
		FlxTween.tween(mmImgWarB.scale, {x: 8, y: 8}, beat, {ease: FlxEase.elasticOut});
		FlxTween.angle(mmImgWarB, 35, 0, beat, {ease: FlxEase.elasticOut});

		new FlxTimer().start(beat, function(tmr) {
			mmImgWar.visible = true;
			mmImgWarB.visible = false;
			mmImgWar.scale.set(9, 9);
			mmImgWar.color = 0xFFFFFFFF;
			mmImgWar.alpha = 1;
			FlxTween.tween(mmImgWar.scale, {x: 8, y: 8}, beat, {ease: FlxEase.elasticOut});
			FlxTween.angle(mmImgWar, -20, 0, beat, {ease: FlxEase.elasticOut});
		});

		new FlxTimer().start(beat * 2, function(tmr) {
			FlxTween.tween(mmImgWar.scale, {x: 7, y: 7}, 0.5 * beat, {ease: FlxEase.bounceOut});
			FlxTween.color(mmImgWar, beat, FlxColor.WHITE, 0xFF737373, {ease: FlxEase.circOut});
		});

		new FlxTimer().start(beat * 3, function(tmr) {
			FlxTween.tween(mmImgWar, {alpha: 0}, beat);
		});
	}

	// 10960-11005: the jump. The faces are the warning; the damage lands when the
	// dad comes back down, 0.48s later.
	FlxG.sound.play(Paths.sound("warningmx"));
	var numberjump:Float = old ? 400 : 800;
	// The live pair: case 5 swaps dad at 46.90s and the chart swaps GF at
	// 46.89s, both before every 'MX salto' event (73.79s on), so the globals
	// would tween the removed dad and flinch the removed GF.
	var dJump = mmDadChar();
	if (dJump == null) return;
	FlxTween.tween(dJump, {y: mmEnemyY - numberjump}, 0.24, {startDelay: 0.24, ease: FlxEase.quadOut, onComplete: function(twn) {
		if (!old && mmPlayerBot()) mmBfJump(); // source 10976, at the jump apex
		FlxTween.tween(dJump, {y: mmEnemyY}, 0.24, {ease: FlxEase.quadIn, onComplete: function(twn2) {
			camGame.shake(0.03, 0.2);
			if (!old) {
				var gHurt = mmGfChar();
				if (gHurt != null) gHurt.playAnim("hurt", true);
			}
			// Source 10990 is outside the !old GF-hurt branch: both songs take
			// landing damage unless dodging. The previous nesting made Old harmless.
			if (!mmIsDodging && !mmPlayerBot()) {
				var bHurt = mmBfChar();
				if (bHurt != null) bHurt.playAnim("hurt", true);
				FlxTween.tween(PlayState.instance, {health: health - 1.2}, 0.2, {ease: FlxEase.quadOut});
				var st = mmEstatica();
				st.alpha = 0.5;
				FlxTween.tween(st, {alpha: 0.05}, 0.5, {ease: FlxEase.quadOut});
			}
			if (old && mmPlayerBot()) mmDodgeAnim();
		}});
	}});
}

// ---------------------------------------------------------------------------
// The source's group coordinates
// ---------------------------------------------------------------------------
// PlayState.gf/boyfriend/dad are properties over
// strumLines.members[2|1|0].characters[0], so every read goes through the
// strumline to be sure it sees a swap-in (the same reasoning as exesequel.hx).
function mmMem(i:Int) {
	var st = PlayState.instance;
	if (st == null) return null;
	var sl = Reflect.field(st, "strumLines");
	if (sl == null) return null;
	var mem = Reflect.field(sl, "members");
	if (mem == null || mem.length <= i) return null;
	var m = mem[i];
	if (m == null) return null;
	var chars = Reflect.field(m, "characters");
	if (chars == null || chars.length < 1) return null;
	return chars[0];
}

function mmDadChar() { return mmMem(0); }
function mmBfChar() { return mmMem(1); }
function mmGfChar() { return mmMem(2); }

// The source writes `gfGroup.visible` and `dadGroup.x -= 475` /
// `gfGroup.y -= 170`; a ported character has no group, so the group position has
// to be recovered from (and written back to) the character. FlxSprite draws at
// `x - offset` and Character.playAnim sets
//     offset.x = globalOffset.x * (isPlayer != playerOffsets ? 1 : -1)
//     offset.y = -globalOffset.y
// so a character *renders* at `stored.x + k * globalOffset.x` with
// k = (isPlayer != playerOffsets) ? 1 : -1, while the source renders it at
// `group + position`. y is the simple half (stored.y == groupY). (Same
// derivation as exesequel.hx's helpers and allfinal.hx's mmSideK/mmPlaceGroup.)
function mmSideK(c):Float {
	if (c == null) return 1;
	return (c.isPlayer != c.playerOffsets) ? 1 : -1;
}

function mmGroupX(c):Float {
	if (c == null) return 0;
	return c.x - (mmSideK(c) + 1) * c.globalOffset.x;
}

function mmGroupY(c):Float {
	return (c == null) ? 0 : c.y;
}

function mmGroupXTo(c, gx:Float):Float {
	if (c == null) return gx;
	return gx + (mmSideK(c) + 1) * c.globalOffset.x;
}

function mmPlaceGroup(c, gx:Float, gy:Float) {
	if (c == null) return;
	c.x = mmGroupXTo(c, gx);
	c.y = gy;
}

// Same swap as data/events/Change Character.hx, called directly because the
// source's case 5 fires 'Change Character' itself (1 -> mxV2 for the dad,
// 2 -> gfnew for the girlfriend). Unlike the event file this keeps the group
// position: the source drops the swap-in into the same group and it sits at
// `group + its own position`.
// The source moves the health icon with the character: `case 0` of its
// 'Change Character' ends with `iconP1.changeIcon(boyfriend.healthIcon)` (9331)
// and `case 1` with `iconP2.changeIcon(dad.healthIcon)` (9376); `case 2` (gf)
// touches no icon. This engine build has no `changeIcon` on HealthIcon, it has
// `setIcon`, and the name it wants is `Character.getIcon()` - the XML's `icon`
// attribute, falling back to the character's own name, which is what PlayState
// seeds `new HealthIcon(boyfriend.getIcon(), ...)` with. Both lookups are
// Reflect-guarded: an engine without them leaves the icon alone instead of
// dropping the swap.
function mmSwapIcon(index:Int, c) {
	var ic = (index == 0) ? iconP1 : ((index == 1) ? iconP2 : null);
	if (ic == null || c == null) return;
	if (!Reflect.hasField(ic, "setIcon") || !Reflect.hasField(c, "getIcon")) return;
	var n = c.getIcon();
	if (n != null && n != "") ic.setIcon(n);
}

function mmChangeChar(index:Int, name:String) {
	if (name == null || name == "" || name == "null") return;
	if (!Assets.exists(Paths.xml("characters/" + name))) return;
	var member = null;
	switch (index) {
		case 0: member = (strumLines.members.length > 1) ? strumLines.members[1] : null;
		case 2: member = (strumLines.members.length > 2) ? strumLines.members[2] : null;
		default: member = strumLines.members[0];
	}
	if (member == null || member.characters.length < 1) return;
	var old = member.characters[0];
	if (old.curCharacter == name) return;

	var isPlayer = old.isPlayer;
	var gx:Float = mmGroupX(old);
	var gy:Float = mmGroupY(old);
	var oldIndex:Int = members.indexOf(old);

	remove(old);
	member.characters.remove(old);

	var fresh = new Character(0, 0, name, isPlayer);
	if (stage != null) stage.applyCharStuff(fresh, member.data.position, 0);
	mmPlaceGroup(fresh, gx, gy);
	if (oldIndex >= 0) {
		remove(fresh);
		insert(oldIndex, fresh);
	}
	// The source's death character is a global (GameOverSubstate.characterName) and
	// survives a swap; this port keeps it on the character (see songs/MMcamera.hx's
	// game-over table), so the current one has to ride across.
	fresh.gameOverCharacter = old.gameOverCharacter;
	member.characters.insert(0, fresh);
	mmSwapIcon(index, fresh);
}

// ---------------------------------------------------------------------------
// Firing an event from a script
// ---------------------------------------------------------------------------
// Case 5's `triggerEventNote('Show Song', '0', '')` shows the song's title card
// (the card itself lives in data/events/Show Song.hx, and the chart hides it
// again at 49.66s). A stage script cannot queue chart events, but the source's
// own dispatcher is public: PlayState.executeEvent(event). It is called through
// Reflect - the same guarded-call idiom data/events/Char Attack.hx uses to reach
// PlayState.onTrigger - so that a build without it degrades to a logged no-op
// instead of taking the song down mid-run.
function mmFireEvent(name:String, params:Array<Dynamic>) {
	if (PlayState.instance == null) return;
	if (!Reflect.hasField(PlayState.instance, "executeEvent")) {
		trace("[MM exeport] no PlayState.executeEvent - dropped event '" + name + "'");
		return;
	}
	Reflect.callMethod(PlayState.instance, Reflect.field(PlayState.instance, "executeEvent"), [{name: name, time: 0, params: params}]);
}

// ---------------------------------------------------------------------------
// 'Triggers Powerdown' (11016-11161)
// ---------------------------------------------------------------------------
function onEvent(event) {
	if (event.event.name == "MX salto") {
		mmMxSalto();
		return;
	}
	if (event.event.name != "Triggers Powerdown" && event.event.name != "Triggers Universal") return;

	var trigger = Std.parseInt(event.event.params[0]);
	if (trigger == null || Math.isNaN(trigger)) trigger = 0;
	var value2:String = (event.event.params.length > 1) ? Std.string(event.event.params[1]) : "";
	var old:Bool = mmIsPowerdownOld();
	var beat:Float = 1 / (Conductor.bpm / 60);

	switch (trigger) {
		case 0:
			// 164.90s (modern) / 118.61s (old). The black curtain goes up, then
			// the laughing MX arrives on it: the new sprite for the modern song,
			// the old plate for the legacy one.
			if (old) {
				FlxTween.tween(mmBar(), {alpha: 1}, 0.5, {ease: FlxEase.quadInOut, onComplete: function(twn) {
					FlxTween.tween(mmMxLaugh(), {alpha: 1}, 1, {startDelay: 1, ease: FlxEase.quadInOut});
				}});
			} else {
				FlxTween.tween(mmBar(), {alpha: 1}, 1, {onComplete: function(twn) {
					var l = mmMxLaughNew();
					l.y = 200;
					l.scale.set(0.8, 0.8);
					FlxTween.tween(l.scale, {x: 1, y: 1}, 1.3, {startDelay: 1, ease: FlxEase.cubeOut});
					FlxTween.tween(l, {y: 80}, 1.3, {startDelay: 1, ease: FlxEase.cubeOut});
					FlxTween.tween(l, {alpha: 1}, 0.3, {startDelay: 1, ease: FlxEase.quadInOut});
					new FlxTimer().start(0.375, function(tmr) {
						l.animation.play("freddyfazbear");
					});
				}});
			}

		case 1:
			// 169.05s (modern) / 122.08s (old): the laugh fades; the legacy song
			// then drops the curtain and flashes.
			if (old) {
				FlxTween.tween(mmMxLaugh(), {alpha: 0}, 1, {ease: FlxEase.quadInOut});
				new FlxTimer().start(2, function(tmr) {
					mmBar().alpha = 0;
					mmFlash(FlxColor.RED, 0.5);
				});
			} else {
				FlxTween.tween(mmMxLaughNew(), {alpha: 0}, 0.5, {startDelay: 0.2, ease: FlxEase.quadInOut});
			}

		case 2:
			// 170.34s (modern) / 124.08s (old): the WAHOO. Both songs run the same
			// four tweens; only the modern one has the character to kill. On the
			// modern song those tweens are inert - `wahooText` is created at alpha 0
			// and only the *old* branch raises it - because there the WAHOO is the
			// chart's own `Add Subtitle ['WAHOOOO!!', 'Red']` at 170.35s.
			var w = wahooText;
			if (old) {
				w.alpha = 1;
			} else {
				mmBar().alpha = 0;
				mmFlash(FlxColor.RED, 0.5);
			}
			FlxTween.angle(w, 0, 40, 2, {ease: FlxEase.quadInOut});
			FlxTween.tween(w.scale, {x: 2, y: 2}, 2, {ease: FlxEase.quadInOut});
			FlxTween.tween(w, {alpha: 0}, 2, {ease: FlxEase.quadInOut});
			FlxTween.tween(w, {x: 600}, 0.5, {ease: FlxEase.quadInOut, onComplete: function(twn) {
				FlxTween.tween(w, {x: 700}, 1.5, {ease: FlxEase.quadInOut});
			}});
			if (!old) {
				// Dad is `mxV2` here - case 5 replaced the global's object.
				var dKill = mmDadChar();
				if (dKill != null) dKill.visible = false;
				var gfc = mmGfChar();
				if (gfc != null) gfc.visible = false; // gfGroup.visible = false
				var k = killMX;
				if (k != null) {
					k.alpha = 1;
					k.animation.play("yupi");
				}
			}

		case 3:
			// 44.14s: the screen goes black and the HUD clears - the notes keep
			// coming down over the fill (see the header). `customHB` is not
			// script-reachable, so the health bar stands in for it.
			FlxTween.tween(mmBar(), {alpha: 1}, 0.5, {ease: FlxEase.quadInOut});
			FlxTween.tween(healthBar, {alpha: 0}, 0.5, {ease: FlxEase.quadInOut});
			FlxTween.tween(healthBarBG, {alpha: 0}, 0.5, {ease: FlxEase.quadInOut});
			FlxTween.tween(iconP1, {alpha: 0}, 0.5, {ease: FlxEase.quadInOut});
			FlxTween.tween(iconP2, {alpha: 0}, 0.5, {ease: FlxEase.quadInOut});

		case 4:
			// 45.52/45.86/46.21/46.55s: one beat of red wash, and - unless the
			// chart's value2 is set (the first of the four carries '1') - the
			// transformation's one-beat flash. The turnevil beats themselves are
			// the stage's own beatHit (132/134/136), not this case.
			var sc = mmScreenColor();
			sc.alpha = 0.1;
			FlxTween.tween(sc, {alpha: 0}, 0.5 * beat, {ease: FlxEase.quadOut});
			if (value2 == "") {
				var te = mmTurnevil();
				te.alpha = 0.9;
				FlxTween.tween(te, {alpha: 0.3}, 0.5 * beat, {ease: FlxEase.quadOut});
			}

		case 5:
			// 46.90s: the reveal. The HUD comes back, the world is rebuilt
			// (epicbgthings + lightmx) and the fighters swap.
			FlxTween.tween(healthBar, {alpha: 1}, 0.5, {ease: FlxEase.quadInOut});
			FlxTween.tween(healthBarBG, {alpha: 1}, 0.5, {ease: FlxEase.quadInOut});
			FlxTween.tween(iconP1, {alpha: 1}, 0.5, {ease: FlxEase.quadInOut});
			FlxTween.tween(iconP2, {alpha: 1}, 0.5, {ease: FlxEase.quadInOut});
			mmBar().alpha = 0;
			mmScreenColor().alpha = 0;
			mmFlash(FlxColor.BLACK, 0.5);
			mmSetEpic(true);
			mmFireEvent("Show Song", ["0", ""]);
			mmChangeChar(1, "mxV2");
			mmChangeChar(2, "gfnew");
			mmDadGroupShift(-475, 0); // dadGroup.x -= 475
			var gfc5 = mmGfChar();
			mmPlaceGroup(gfc5, mmGroupX(gfc5), mmGroupY(gfc5) - 170); // gfGroup.y -= 170
			var dSwap = mmDadChar();
			mmEnemyY = (dSwap != null) ? dSwap.y : mmEnemyY;
			if (lightmx != null) lightmx.visible = false;

		case 6:
			// 193.79s: the static plate fades the whole way in (the source gates
			// it on ClientPrefs.filtro85).
			FlxTween.tween(mmEstatica(), {alpha: 1}, 2.5);

		case 7:
			// 169.65s: the mid-song video (`midsongVid` + 'Powerdownscene.mp4' on
			// camHUD, hidden again with a one-second red flash when it ends).
			mmPlayMidsongVideo();
	}
}

// `dadGroup.x -= 475` (case 5): a *relative* group write, i.e. the same delta on
// the character's own stored coordinates.
function mmDadGroupShift(dx:Float, dy:Float) {
	var d = mmDadChar();
	if (d == null) return;
	mmPlaceGroup(d, mmGroupX(d) + dx, mmGroupY(d) + dy);
}

// ---------------------------------------------------------------------------
// The opening (6281-6296)
// ---------------------------------------------------------------------------
// The stage runs with `noCount` + `noHUD` (1389-1391): no READY/SET/GO, no HUD,
// and a static screen with a looping hiss for the first seconds. The source
// plays `staticloop` as the *music* track and holds `startedCountdown` behind a
// two-second timer; here the countdown is cancelled on its first ask and
// re-issued two seconds later, which is the same shape hatebg.hx gives its
// cutscene (Codename only broadcasts onStartCountdown on the first call, so the
// re-issue runs the real countdown).
var mmStatic:FlxSound = null;
var mmIntroHeld:Bool = false;

function onCountdown(event) {
	event.cancelled = true;
}

function onStartCountdown(event) {
	if (mmIntroHeld) return;
	mmIntroHeld = true;
	event.cancelled = true;

	mmBuildOverlays();
	// Not `FlxG.sound.playMusic` like the source: the song's inst is the engine's
	// music track here and must not be replaced (see the header).
	var staticPath:String = Paths.music("staticloop");
	mmStatic = FlxG.sound.play(staticPath, 0.5, true);

	new FlxTimer().start(2, function(tmr) {
		if (PlayState.instance != null) PlayState.instance.startCountdown();
	});

	// 6287-6293: the branch's *second* timer, the 3s mark - both are timed from
	// the static start, i.e. from here. The countdown re-issued above is five
	// beats long (1.72s at 174bpm), so the chart's first beat lands at 3.72s and
	// the cross-over (0.5s) ends at 3.5s: 0.22s *before* the song, exactly as in
	// the source. Timing it from the song's own start (which is what an earlier
	// version did, one second into the chart, so 4.7s) left the hiss and the TV
	// frame on screen for the whole first second, with the notes already falling.
	new FlxTimer().start(3, function(tmr) { mmIntroCrossOver(); });
}

// 6289-6292: the hiss fades out over half a second while the TV frame and the
// HUD cross over. The source tweens `FlxG.sound.music`, which *is* the static
// there; in this port the hiss is a sound of its own (the song's inst owns the
// music slot - see the header), so the volume tween is on mmStatic instead.
function mmIntroCrossOver() {
	var snd = mmStatic;
	if (snd != null) {
		mmStatic = null;
		FlxTween.tween(snd, {volume: 0}, 0.5, {onComplete: function(twn) { snd.stop(); }});
	}
	var live = mmLiveScreen();
	if (live != null) FlxTween.tween(live, {alpha: 0}, 0.5, {ease: FlxEase.quadInOut});
	if (camHUD != null) FlxTween.tween(camHUD, {alpha: 1}, 0.5, {ease: FlxEase.quadInOut});
}

// ---------------------------------------------------------------------------
// beatHit (16244-16257, 16460-16485)
// ---------------------------------------------------------------------------
function beatHit() {
	// The stage's own beat branch is modern-only (`SONG.song != 'Powerdown Old'`).
	if (mmIsPowerdownOld()) return;
	var b:Int = curBeat;

	// 132 (45.52s) / 134 (46.21s) / 136 (46.90s), the same beats the chart's four
	// case-4 events land on.
	if (b == 132) {
		var te = mmTurnevil();
		te.alpha = 1;
		FlxTween.tween(te, {alpha: 0.3}, 0.5 * (1 / (Conductor.bpm / 60)), {ease: FlxEase.quadOut});
		te.animation.play("laugh");
	}
	if (b == 134) {
		var te2 = mmTurnevil();
		FlxTween.tween(te2, {x: -700, y: -700}, 2, {ease: FlxEase.expoOut});
		FlxTween.tween(te2.scale, {x: 0.25, y: 0.25}, 2, {ease: FlxEase.expoOut});
	}
	if (b == 136) {
		mmTurnevil().visible = false;
	}
	// 496 (170.69s): the WAHOO's aftermath - the killer leaves and the dad is back.
	if (b == 496) {
		if (killMX != null) killMX.visible = false;
		var dBack = mmDadChar();
		if (dBack != null) dBack.visible = true;
	}

	// 16244-16257: the cloud's idle is replayed every beat (it does not loop) and
	// the bush blinks on a 1-in-35 roll, holding the pose for 0.75s. The source
	// also cancels its whole `extraTimers` list here; the anim guard makes that
	// unnecessary (only one blink can be in flight).
	if (creepyCloud != null) creepyCloud.animation.play("idle", true);
	if (creppyleaf != null && FlxG.random.int(1, 35) == 1) {
		var ca = creppyleaf.animation.curAnim;
		if (ca == null || ca.name != "blink") {
			creppyleaf.animation.play("blink", true);
			new FlxTimer().start(0.75, function(tmr) {
				creppyleaf.animation.play("idle", true);
			});
		}
	}
}

// ---------------------------------------------------------------------------
// postUpdate (7770-7794): the GF-death cinematic
// ---------------------------------------------------------------------------
// Nothing schedules this - it is driven off killMX's own frames: the killer's
// 'yupi' animation hits frame 16, GF falls (gfFall), and when that fall ends the
// still 'gfwasTaken' takes its place. The source leaves the last pose paused on
// screen for the rest of the song.
function postUpdate(elapsed:Float) {
	// Both songs: keep the camEst layer in camEst's slot (once) and at camHUD's
	// size (a no-op unless the engine resized the HUD camera).
	mmEstBelowHud();
	mmEstSize();
	// Both songs: the VCR/border stack's time uniform (`vcr.update(elapsed)`).
	mmTvTick(elapsed);
	// Both songs: the curtain and the red wash follow the world's zoom.
	mmFitFills();
	// Both songs, and before the modern-only cinematic below: the dodge is read
	// here, one frame of input lag, the same slot the source's own check sits in.
	mmDodgePoll();
	if (mmIsPowerdownOld()) return;

	if (killMX != null && gfFall != null) {
		var ka = killMX.animation.curAnim;
		if (ka != null && ka.name == "yupi" && ka.curFrame == 16) {
			gfFall.alpha = 1;
			gfFall.animation.play("fallgirls");
		}
	}
	if (gfFall != null && gfwasTaken != null) {
		var fa = gfFall.animation.curAnim;
		if (fa != null && fa.name == "fallgirls" && fa.finished) {
			gfFall.alpha = 0;
			gfFall.animation.play("fallgirls");
			// Replaying it and pausing is the source's own way of arming the
			// branch exactly once (`finished` cannot come back).
			gfFall.animation.curAnim.paused = true;
			gfwasTaken.alpha = 1;
			gfwasTaken.animation.play("fallgu");
		}
	}
}

// ---------------------------------------------------------------------------
// Character-atlas preload (the create branch's addCharacterToList, 1388-1435)
// ---------------------------------------------------------------------------
// The create branch preloads exactly four characters, during the loading screen:
//     addCharacterToList('bf_PDdeath', 0);  addCharacterToList('mxV2', 1);
//     addCharacterToList('bfsad', 0);       addCharacterToList('gfnew', 2);
// so that case 5's swap (46.9s) does not decode an atlas mid-song - one atlas is
// around a second of decode, which is a visible stall right when MX transforms.
// allfinal.hx fixes the same stall the same way (see its mmPreloadAll comment):
// `FunkinSprite.loadSprite` resolves frames through `Paths.getFrames(path)`, which
// caches by path in `Paths.tempFramesCache`, so decoding each atlas once here
// makes the later `new Character()` reuse it. Like allfinal's, this runs at
// SCRIPT LOAD - inside PlayState creation, before the countdown.
var mmPreloadChars:Array<String> = ["mxV2", "gfnew", "bfsad", "bf_PDdeath"];

// The image a character's XML points at (`sprite="..."`) - the same value the
// preload caches under and the one `FunkinSprite.loadSprite` later asks for.
function mmCharImage(name:String) {
	var xmlPath:String = Paths.xml("characters/" + name);
	if (!Assets.exists(xmlPath)) return null;
	var txt:String = Assets.getText(xmlPath);
	var i:Int = txt.indexOf('sprite="');
	if (i < 0) return null;
	var j:Int = txt.indexOf('"', i + 8);
	if (j < 0) return null;
	return Paths.image("characters/" + txt.substring(i + 8, j));
}

function mmPreloadChar(name:String) {
	var img:String = mmCharImage(name);
	if (img == null) { mmLog("preload: no sprite attribute for " + name); return; }
	if (!Assets.exists(img)) { mmLog("preload: no image at " + img); return; }
	Paths.getFrames(img, true); // exactly Character's own loader call
}

function mmPreloadAll() {
	for (name in mmPreloadChars) mmPreloadChar(name);
}

// ---------------------------------------------------------------------------
// postCreate
// ---------------------------------------------------------------------------
function postCreate() {
	// `noHUD = true` (1390): the HUD starts hidden and the opening's 3s mark
	// brings it back (the countdown hold's cross-over above).
	if (camHUD != null) camHUD.alpha = 0;

	mmBuildOverlays();

	// `enemyY = dad.y` (6284) - what 'MX salto' measures its 800px jump from.
	mmEnemyY = (dad != null) ? dad.y : 0;

	// epicbgthings is created `visible = false` and only case 5 reveals it (the
	// group is six backgrounds deep, so it has to be the whole set); the old song
	// never sends case 5, so it gets the extracted backdrop at load instead and
	// loses the two modern-only layers (see the header). postCreate runs from
	// inside create(), before the first draw, so nothing of the group is ever
	// rendered for the modern song.
	if (mmIsPowerdownOld()) {
		mmSetEpic(true);
		if (lightmx != null) lightmx.visible = false;
		if (shadowbg != null) shadowbg.visible = false;
	} else {
		mmSetEpic(false);
		// 1434-1437 (`case 'exeport'`, modern branch, `SONG.song != 'Powerdown Old'`):
		// the create path itself parks GF at x = 650, over the stage XML's own
		// position. The Old branch never runs this, so it keeps the XML position.
		mmPlaceGroup(gf, 650, mmGroupY(gf));
	}

	// 4431-4444: the foreground switch's own adds. None of the five is added in
	// the create branch (they are created there and only `add()`ed here), so in
	// the source every one of them draws after the character groups - in front
	// of the fighters - in exactly this order, with `shadowbg` last, over the
	// rest. The stage XML carries them as ordinary children, so each is lifted
	// to the end of the state's draw list here. (The old version of this block
	// moved only `lightmx`, to just under `killMX`, which left all five below
	// the fighters.)
	if (mmIsPowerdownOld()) {
		mmToFront(wahooText);
	} else {
		mmToFront(lightmx);
		mmToFront(killMX);
		mmToFront(gfFall);
		mmToFront(gfwasTaken);
		mmToFront(shadowbg);
	}

	// 5647-5663: the filters are mounted at create, before the countdown runs.
	mmTvStack();
}

// Runs at SCRIPT LOAD, i.e. inside PlayState creation - the same slot the
// source's addCharacterToList calls sit in.
mmPreloadAll();
// === end MM stage triggers ===
