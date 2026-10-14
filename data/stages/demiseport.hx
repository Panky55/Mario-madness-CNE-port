

// === MM stage triggers (auto) ===
// 'Triggers Demise' - ported from PlayState.hx (case 'Triggers Demise',
// 11162-11295). Both `demise` and `demise-old` run on this stage, but only the
// regular chart sends these beats (demise-old sends none), and it sends them as
// 'Triggers Universal' - so both event names are accepted.
//
// The camera half (cases 3, 5, 7, 9, 10) is in songs/MMcamera.hx
// (`mmDemiseTrigger`): camGame.zoom at case 3 and 5, camFollowPos at case 5, the
// camHUD fade at case 5/7 and the FOLLOWCHARS/ZOOMCHARS toggles at 9/10.
//
// This stage's backdrop is entirely `FlxBackdrop` in the source (3040-3196: the
// sky, the level and the ground of both the surface and the underground world
// are backdrops, which is why the extractor - which only lifts BGSprite art -
// left the stage with a floor and two foreground layers and nothing else). They
// are rebuilt in postCreate as small tiled groups with the source's own y,
// scroll factors, velocities and spacings (see mmBackdrop).
//
// Stage-level behaviour that comes with the case:
//   3041-3046  `noCount = true` (the READY/SET/GO are dropped), the HUD icons
//              flip (`flipchar` + the demiseport override at 5642-5646:
//              iconP1/iconP2 flipX on, both health bars off) and health starts
//              at 2.
//   4445-4452  `demoFore1..4` and `underdemFore1/2` are added in the *foreground*
//              switch, i.e. after the character groups - the XML puts every
//              sprite below them, so postCreate lifts them to the front.
//   16489      beatHit()'s demFlash pulse (case 11 toggles `demFlash`).
//
// Game-over configuration/preloads live in MMcamera; the default field swap
// is in MMmodfields. `tvEffect` (3043) is ported: this stage sets it without
// `oldTV`, so camGame, camHUD and the camEst layer get VCRMario85 + VCRBorder
// (5647-5663) - see "The TV filter stack" below. Still open: `demColor`'s
// visible effect - it is a makeGraphic curtain added *behind* every backdrop, so
// the beat pulse below is faithful but invisible, as it is in the source.

// ---------------------------------------------------------------------------
// camEst (the transition wipe, 3196-3199)
// ---------------------------------------------------------------------------
var mmEst:FlxCamera = null;
var mmEstPlaced:Bool = false;
var mmEstWarned:Bool = false;

function mmCamList() {
	return Reflect.field(FlxG.cameras, "list");
}

function mmGetEst():FlxCamera {
	if (mmEst == null) {
		mmEst = new FlxCamera(0, 0, FlxG.width, FlxG.height);
		mmEst.bgColor = FlxColor.TRANSPARENT;
		mmEst.zoom = 1;
		FlxG.cameras.add(mmEst, false); // defaultDraw=false -> world not redrawn
		mmEstBelowHud();
	}
	return mmEst;
}

// Psych builds camEst right after camGame (FlxCamera 826-828), so it composites
// between the world's canvas and camHUD's. `FlxG.cameras.add` appends, which
// would put this layer *above* camHUD - over the notes and the HUD, and over the
// wipe's own 3:1 plate - so it is slid back into camHUD's own index here (the
// fleet-wide convention: piracy, forest, nesbeat, meatworld, exeport all place
// their camEst the same way).
// (The list is only half of a camera's place: its own flashSprite in the
// display list is the surface that composites, and `add` leaves a fresh one on
// top of camHUD - which is what `mmSyncCameraOrder` below re-asserts.)
function mmEstBelowHud() {
	if (mmEst == null || mmEstPlaced) return;
	var list = mmCamList();
	if (list == null) {
		if (!mmEstWarned) {
			mmEstWarned = true;
			trace("[MM demiseport] camEst: no FlxG.cameras.list - the wipe stays above camHUD");
		}
		return;
	}
	list.remove(mmEst); // no-op when it is not in the list yet
	var at:Int = (camHUD != null) ? list.indexOf(camHUD) : -1;
	if (at < 0) {
		list.push(mmEst); // no camHUD yet: stay on top
		return;
	}
	list.insert(at, mmEst);
	mmEstPlaced = true;
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

function mmOverlay(spr) {
	spr.scrollFactor.set(0, 0);
	spr.cameras = [mmGetEst()];
	add(spr);
	return spr;
}

// ---------------------------------------------------------------------------
// The TV filter stack (3043 + 5647-5663)
// ---------------------------------------------------------------------------
// `case 'demiseport'` sets `tvEffect` (3043) without `oldTV`, so the source
// mounts exactly two filters, `[VCRMario85, VCRBorder]`, on camGame, camEst and
// camHUD (5651-5663) while `ClientPrefs.filtro85` is on - which this port takes
// as on, like every other stage script. The camEst layer here is mmGetEst(); the
// pair lives in shaders/vcr85.frag and shaders/vcrBorder.frag, mounted from
// postCreate and driven from postUpdate with `vcr.update(elapsed)`'s own
// accumulation of the time uniform (7241). The border carries no uniform.
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
	var est = mmGetEst();
	if (est != null) est.addShader(s);
}

// `addShader` appends, so mounting vcr before border on each camera reproduces
// the source's `[vcr, border]` filter order.
function mmTvStack() {
	if (mmTvOn || !mmShadersAllowed()) return;
	mmTvOn = true;
	mmVcr = new CustomShader("vcr85");
	mmTvMountAll(mmVcr);
	mmVcrBorder = new CustomShader("vcrBorder");
	mmTvMountAll(mmVcrBorder);
}

// `vcr.update(elapsed)` (7241) only accumulates the shader's own time uniform.
function mmTvTick(elapsed) {
	if (mmVcr == null) return;
	mmTvTime += elapsed;
	mmVcr.data.time.value = [mmTvTime];
}

// Codename's `Stage` is not a group (`class Stage extends FlxBasic`), so
// `stage.add`/`stage.remove`/`stage.insert`/`stage.members` do not exist and
// HScript resolves them to null - calling them throws Null Function Pointer and
// aborts the rest of the handler. `Stage.addSprite` instead puts every stage
// sprite straight into the *state's* draw list and `Stage.applyCharStuff` inserts
// each character at its marker, so a bare `members`/`add`/`insert`/`remove` here
// is the state's list and the world layer is the run of sprites below the
// character band.
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

// ---------------------------------------------------------------------------
// Character resolution (see exesequel.hx for the longer note)
// ---------------------------------------------------------------------------
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

// Same swap as data/events/Change Character.hx, for the four pairs the case
// fires itself (mx_demiseUG/bf_demiseUG underground, mx_demise/bf_demise back).
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
	remove(old);
	member.characters.remove(old);
	var fresh = new Character(0, 0, name, isPlayer);
	if (stage != null) stage.applyCharStuff(fresh, member.data.position, 0);
	// The source's death character is a global (GameOverSubstate.characterName) and
	// survives a swap; this port keeps it on the character (see songs/MMcamera.hx's
	// game-over table), so the current one has to ride across.
	fresh.gameOverCharacter = old.gameOverCharacter;
	member.characters.insert(0, fresh);
	var icon = index == 0 ? iconP1 : (index == 1 ? iconP2 : null);
	if (icon != null) icon.setIcon(fresh.getIcon());
}

// ---------------------------------------------------------------------------
// FlxBackdrop stand-ins
// ---------------------------------------------------------------------------
// The source uses `new FlxBackdrop(Paths.image(img), X)` with an optional
// spacing (defaults to the graphic's width) and a `velocity`; the class itself is
// not safe to instantiate from HScript, so each backdrop becomes a handful of
// copies at `i * spacing`, travelling at the source's velocity and wrapped every
// `spacing` px. That is what FlxBackdrop draws (the same graphic tiled at
// `spacing`, offset by the accumulated velocity) - but only ever in the window
// the camera can see: it lays its tiles out *against the view* every draw
// (`drawComplex`: `left = modMin(bounds.right, tile, viewMargins.left) -
// bounds.width`, `tilesX = round((right - left) / tileSize.x)`), so it covers the
// screen wherever the camera sits. The copies below do the same, on the view
// rather than on a fixed window from world x 0 - see update().
//
// The direction is Flixel's, not an assumption: `FlxBackdrop.velocity` is plain
// `FlxObject.velocity`, so the sprite's own x/y is what moves, and the tiling is
// derived from it - a positive velocity.x slides the pattern **right**, and the
// negative-y ones slide it up. This was inverted when the backdrops were first
// rebuilt (the copies travelled against the velocity), which no static check can
// see; the source's velocities here are all positive, so all seven were drifting
// the wrong way.
// `tile` is the repeat pitch - the wrap distance *and* how far apart the copies
// sit; the art's width only sets the pitch, it never places anything.
var mmBackdrops = [];

// The last sprite of a group, or `fallback` when the group never got built - so
// the insert chain below still has an anchor after a missing image.
function mmLastSpr(g, fallback) {
	if (g == null || g.sprs.length < 1) return fallback;
	return g.sprs[g.sprs.length - 1];
}

// `after` is the world sprite this backdrop must be drawn on top of (the copies
// go in one after the other, so the group stays contiguous).
function mmBackdrop(img:String, y:Float, sfX:Float, sfY:Float, speed:Float, tile:Float, visible:Bool, after) {
	var path = Paths.image(img);
	if (path == null || !Assets.exists(path)) {
		trace("[demiseport] backdrop missing -> " + path);
		return null;
	}
	// `FlxBackdrop`'s third argument is the *gap* between tiles, and the pitch it
	// draws at is the graphic's own width plus that gap (`tileSize =
	// frame.frame.width; tileSize.add(spacing)` - flixel-addons 2.12.1, 3.0.0,
	// 3.3.2, 4.0.0 and 4.0.1 all read it that way, and they are the whole range
	// of versions whose `FlxBackdrop(graphic, axes, spacing)` signature matches
	// the source's calls). A spacing of 0 therefore means "tile at the graphic's
	// own width". The 2600px placeholder this stand-in used was wrong for every
	// layer - it overlapped the 2893/4642/5128/4304-wide art and wrapped it
	// hundreds of pixels early - and the three explicit spacings (800, 6000,
	// 4000) are gaps to add to those widths, not pitches to draw at.
	var sprs = [];
	var first = new FunkinSprite(0, y);
	first.loadGraphic(path);
	var pitch:Float = first.width + ((tile > 0) ? tile : 0);
	if (pitch <= 0) pitch = 1;
	// How many copies: the row is re-anchored on the camera's view every frame
	// (see update()), so it has to be at least as long as the widest view the song
	// reaches - `FlxG.width / zoom` - plus the slack the class keeps for itself
	// (one tile at each end, the `- bounds.width` / `+ origTileSizeX` above). This
	// stage's own zoom-out is 0.4 (MMcamera's case 3/5 and the chart's own 'Set
	// Cam Zoom'); the floor is taken at 0.25 so a lower one still lands inside the
	// row rather than past its end.
	var n:Int = Std.int(Math.ceil((FlxG.width / 0.25) / pitch)) + 3;
	if (n < 3) n = 3;
	var anchor = after;
	for (i in 0...n) {
		var s = (i == 0) ? first : new FunkinSprite(i * pitch, y);
		if (i > 0) s.loadGraphic(path);
		s.scrollFactor.set(sfX, sfY);
		s.updateHitbox();
		s.visible = visible;
		var idx:Int = (anchor != null) ? members.indexOf(anchor) : -1;
		if (idx < 0) mmWorldAdd(s); else insert(idx + 1, s);
		sprs.push(s);
		anchor = s;
	}
	var g = {sprs: sprs, tile: pitch, v: speed, t: 0.0, sf: sfX};
	mmBackdrops.push(g);
	return g;
}

function mmBackdropVisible(g, on:Bool) {
	if (g == null) return;
	for (s in g.sprs) s.visible = on;
}

function mmBackdropFade(g, a:Float, t:Float, ease) {
	if (g == null) return;
	for (s in g.sprs) {
		if (ease == null) FlxTween.tween(s, {alpha: a}, t);
		else FlxTween.tween(s, {alpha: a}, t, {ease: ease});
	}
}

// The world x the middle of the screen sits at *for this row*.
//
// The conversion is the one meatworld.hx's `mmHallViewCentre` documents, and it
// is Flixel's own: `FlxPointer.getScreenPosition` turns a screen pixel back into
// the world with `screen / camera.zoom + camera.scroll.x`, so a sprite with
// scroll factor `sf` draws at `(x - camera.scroll.x * sf) * camera.zoom`. The
// world x at the screen's left edge is therefore `camera.scroll.x * sf`, and the
// screen's middle is half a view - `camera.width / 2 / camera.zoom` - past it.
//
// A camera whose `scroll` cannot be read (or whose zoom is missing, 0 or NaN)
// returns null, and the row keeps the old fixed window rather than being parked
// at a non-finite x.
function mmBackdropViewCentre(g):Dynamic {
	if (g == null || g.sprs.length < 1) return null;
	if (camGame == null) return null;
	var z:Float = camGame.zoom;
	if (!(z > 0)) z = 1; // missing, 0 or NaN all mean "no zoom"
	var scrub = Reflect.field(camGame, "scroll");
	var sx = (scrub != null) ? Reflect.field(scrub, "x") : null;
	if (sx == null) return null;
	var vc:Float = sx * g.sf + camGame.width * 0.5 / z;
	if (vc != vc) return null; // NaN: leave the row on the fixed window
	return vc;
}

function update(elapsed:Float) {
	for (b in mmBackdrops) {
		if (b.v == 0) continue;
		// The phase is kept in (-tile, 0] and travels with the velocity (see
		// above): positive slides the pattern right, negative left, and the wrap
		// at either end lands every copy on an identical one's old spot.
		b.t += b.v * elapsed;
		while (b.t <= -b.tile) b.t += b.tile;
		while (b.t > 0) b.t -= b.tile;
		// Re-anchor the row on what the camera can see, which is what the source's
		// FlxBackdrop does by construction (it draws the tiles the view needs - see
		// the note at the top of this block). A row fixed from world x 0 rightwards
		// is *not* where this stage's camera is: the fight sits at x 0 (BF) and 1900
		// (dad) - the two XML nodes - while the rows carry 0.3/0.5/0.9 scroll
		// factors, so a row's own view starts at `camGame.scroll.x * sf`, left of
		// x 0 for most of the song: at the chart's own wide shot (a 380 follow row
		// at the 0.4 zoom - `380 - 640 / 0.4` = -1220) that is 366px on the two 0.3
		// rows and about 1098px on the 0.9 ones, i.e. a bare strip down the left of
		// the screen. The row's own drift then walked that strip across the screen
		// and snapped it back a whole tile on every wrap - 29s apart on `dembg`
		// (2893/100) and 51s on the 5128px mountains - which is what reads as the
		// art "spawning in". Moving a row by whole tiles is invisible (the art
		// repeats with `tile`), so the phase `t`, and with it the slide, is
		// preserved exactly; the row is centred on the view rather than
		// left-anchored so a frame's own transparent lead-in cannot bare an edge
		// either.
		var vc = mmBackdropViewCentre(b);
		var i:Int = 0;
		if (vc == null) {
			for (s in b.sprs) { s.x = i * b.tile + b.t; i += 1; }
		} else {
			var rowLen:Float = b.sprs.length * b.tile;
			var start:Float = b.t + Math.floor((vc - rowLen * 0.5 - b.t) / b.tile) * b.tile;
			for (s in b.sprs) { s.x = start + i * b.tile; i += 1; }
		}
	}
}

// ---------------------------------------------------------------------------
// The surface / underground backdrops (3044-3110)
// ---------------------------------------------------------------------------
var mmDemColor = null;
var mmDemBg = null;
var mmDemLevel = null;
var mmDemGround = null;
var mmUnderBg = null;
var mmUnderLevel = null;
var mmUnderGround1 = null;
var mmUnderGround2 = null;
var mmWhenYoureRed = null;
var mmDemiseTran = null;

function mmInsertAfter(anchor, obj) {
	if (obj == null) return;
	var i:Int = (anchor != null) ? members.indexOf(anchor) : -1;
	if (i < 0) { mmWorldAdd(obj); return; }
	insert(i + 1, obj);
}

// 3050-3053: a full-screen white graphic whose `color` is BLACK - a curtain at
// the very back of the draw list.
function mmGetDemColor() {
	if (mmDemColor == null) {
		mmDemColor = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		mmDemColor.scale.set(10, 10); // source's setGraphicSize(width * 10)
		mmDemColor.scrollFactor.set(0, 0);
		insert(0, mmDemColor);
	}
	return mmDemColor;
}

// 3115-3120: the red wash under the cutscene, after the underground roof.
function mmGetWhenYoureRed() {
	if (mmWhenYoureRed == null) {
		mmWhenYoureRed = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xFFD10000);
		mmWhenYoureRed.scale.set(10, 10);
		mmWhenYoureRed.alpha = 0;
		mmInsertAfter(underroofdemise, mmWhenYoureRed);
	}
	return mmWhenYoureRed;
}

// 3196-3200: the wipe, on camEst, three times as wide as it is tall.
function mmGetDemiseTran() {
	if (mmDemiseTran == null) {
		mmDemiseTran = new FunkinSprite(-1600, 0);
		mmDemiseTran.loadGraphic(Paths.image("mario/MX/demise/1/transition"));
		mmDemiseTran.scale.set(3, 1);
		mmOverlay(mmDemiseTran);
	}
	return mmDemiseTran;
}

// ---------------------------------------------------------------------------
// The opening cutscene video (5805-5808)
// ---------------------------------------------------------------------------
// `startVideo('demise_cutscene')` runs before the countdown on the warp
// version, once per session (`seenCutscene` - the engine's own static, shared
// here so a cutscene seen anywhere counts), and Demise is the one song ENTER
// cannot skip (7595), so there is no skip path. Only the modern song: the
// fork's switch matches `demise`, not `demise-old` - the same displayName gate
// the other old-song stages use.
//
// It is an *overlay on a running song*, not a pre-roll. `startVideo` schedules
// `startCountdown()` 0.32s into the clip (6193-6196), and this stage's own
// branch of that countdown runs with `noCount` (3041) and
// `Conductor.songPosition = 0` (6432-6435 - the one song that skips the
// `-= crochet * 5` under it), so the inst starts *under* the clip - the port
// starts it on the postCreate frame, the fork one crochet later thanks to that
// 0.32s timer - and the end callback has nothing left to do but take the clip
// down:
// `remove(cutVid)` plus a red `camHUD.flash` (6188-6192). Holding the engine's
// start flow instead (`inCutscene` until the clip ended - v1.0.1's update
// returns at PlayState.hx:1353 while it is set, freezing `Conductor.songPosition`
// so `startSong` waits) started the song from zero the moment the clip
// finished, instead of continuing the song under it. The chart's own first
// notes are at 15.16s (dad's, behind the clip) and the first player note at
// 20.21s - four seconds after the clip's last frame.
//
// The file is `videos/demise_cutscene.mp4` (16.04s, 1280x720) - **video only**,
// which is the name `startVideo('demise_cutscene')` resolves to. The
// `demise_cutscene_SOUND.mp4` variant carries its own aac track and does *not*
// belong here: the fork lists it only in `StoryMenuState.cutscenes`
// (StoryMenuState.hx:62), the warp **menu** previews, where no song is playing
// and the clip has to bring its own audio. In song the audio is the song's own -
// `noCount` + `songPosition = 0` starts the inst and the vocals on the clip's
// first frame - so playing the SOUND variant here doubled the intro (one
// version off the clip, one off the inst), which is the reported "two
// versionings playing together". The player is hxvlc's FlxVideoSprite (the
// engine bundles it; the same class the mid-song videos in
// exeport.hx/wetworld.hx use, both of which load the source's own name -
// exeport's `Powerdownscene.mp4` is video-only for the same reason).
var mmIntroVid = null;
var mmIntroDone:Bool = false;

// camOther's slot: a camera of this script's own, appended after camHUD (the
// wetworld shape) - the clip has to cover the HUD, not slide under it like camEst.
var mmOtherCam:FlxCamera = null;
function mmGetOther():FlxCamera {
	if (mmOtherCam == null) {
		mmOtherCam = new FlxCamera(0, 0, FlxG.width, FlxG.height);
		mmOtherCam.bgColor = FlxColor.TRANSPARENT;
		mmOtherCam.zoom = 1;
		FlxG.cameras.add(mmOtherCam, false); // appended after camHUD = Psych's camOther
	}
	return mmOtherCam;
}

// A stage script has no `meta` global - the song's is `PlayState.SONG.meta`, the
// same read exeport.hx/hatebg.hx/meatworld.hx make. (Reading a bare `meta`
// threw "Unknown variable: meta" on cpp and aborted the rest of
// mmPlayIntroVideo, which is why the video never started.)
function mmSongName():String {
	if (PlayState.SONG == null || PlayState.SONG.meta == null) return "";
	var n = PlayState.SONG.meta.displayName;
	return (n == null) ? "" : StringTools.trim(Std.string(n));
}

function mmPlayIntroVideo() {
	// The fork's zero lead-in (6432-6435) in Codename's terms: `startCountdown`
	// arms `introLength` crochets of it (v1.0.1 PlayState.hx:984-990), and the
	// script-reachable way to make that zero is to write the field and call
	// `startCountdown()` again - the second call skips its own cancellable
	// `onStartCountdown` (`_startCountdownCalled`, 973-979) and re-arms
	// `Conductor.songPosition` from the field, which is the same re-issue
	// hatebg.hx and exeport.hx use to move a song start. The `startingSong`
	// guard matters: once `startSong()` has run, re-issuing would rewind
	// `Conductor.songPosition` to the lead-in again. Demise Old keeps the
	// engine's lead-in, exactly as the fork's `!= 'demise'` does.
	if (mmSongName() != "Demise Old" && PlayState.instance != null && PlayState.instance.startingSong) {
		PlayState.instance.introLength = 0;
		PlayState.instance.startCountdown();
	}
	if (mmSongName() == "Demise Old") return;
	if (PlayState.seenCutscene) return;
	// Getting at hxvlc's class takes an `import`. hscript's `new` only accepts a
	// name that is already in the script's own scope: `Interp.cnew` looks the
	// name up *there* first and throws "Unknown variable" before it ever asks
	// Type.resolveClass, so a dotted `new hxvlc.flixel.FlxVideoSprite()` cannot
	// work (that is the error this port first hit). `import` is what puts the
	// class in scope - it resolves the path itself and binds the class under its
	// short name - and the engine's own scripts reach their classes the same way
	// (a script's scope has no `Type` to resolve one by hand: v1.0.1's defaults
	// are Std/Math/Reflect/StringTools/Json plus the engine's own list). Both
	// statements are inside the try so a build without hxvlc skips just the clip
	// instead of failing the whole stage script.
	var vid = null;
	var loaded:Bool = false;
	try {
		import hxvlc.flixel.FlxVideoSprite;
		vid = new FlxVideoSprite();
		if (vid != null) {
			vid.scrollFactor.set(0, 0);
			vid.cameras = [mmGetOther()];
			vid.visible = false;
			mmVideoHooks(vid, function() { mmIntroOver(); });
			add(vid);
			loaded = vid.load(Paths.video("demise_cutscene")) == true;
		}
	} catch (e:Dynamic) {
		trace("[MM demiseport] opening video: the video could not be prepared - " + Std.string(e));
		loaded = false;
	}
	if (!loaded) {
		trace("[MM demiseport] opening video did not load ('demise_cutscene.mp4')");
		return;
	}
	// Only a playable clip consumes the session's once: a failed load retries
	// on the next attempt, like the source's startCountdown fallback.
	PlayState.seenCutscene = true;
	mmIntroVid = vid;
	mmIntroDone = false;
	vid.visible = true;
	try {
		vid.play();
	} catch (e:Dynamic) {
		trace("[MM demiseport] opening video could not play - " + Std.string(e));
		mmIntroOver();
		return;
	}
	// Fallback: the clip is 16.04s; if the end signal never fires, the overlay
	// still comes down instead of sitting on the song.
	try {
		new FlxTimer().start(17, function(tmr) { mmIntroOver(); });
	} catch (e2:Dynamic) {}
}

// hxvlc's callbacks are signals on the sprite's own `bitmap`
// (`video.bitmap.onEndReached.add(fn)`, `...onFormatSetup.add(fn)`) - the exact
// two lines the engine's own VideoCutscene wires. Psych's `finishCallback` is
// not on this class at all, which is why the old guarded `Reflect.setField`
// pair silently did nothing and the clip only ever ended on a timer. They are
// written as plain member accesses, not `Reflect.field` lookups: hscript's
// `get` goes through Reflect.getProperty, which reaches the sprite's properties
// and the signal's `add` method, while a hand-rolled `Reflect.field` on a class
// *method* answers null on cpp and skipped the wiring (and then the load/play
// calls below) entirely.
// The format hook is also where the sprite takes the video's size: it is built
// 1x1 (`makeGraphic(1, 1)`) and only learns the frame size when the decoder
// reports it, so the fit-to-window has to happen there for the clip to cover
// the screen.
function mmVideoHooks(vid, onEnd) {
	vid.bitmap.onEndReached.add(onEnd);
	vid.bitmap.onFormatSetup.add(function() {
		if (vid.bitmap == null || vid.bitmap.bitmapData == null) return;
		var w = vid.bitmap.bitmapData.width;
		var h = vid.bitmap.bitmapData.height;
		var sc:Float = Math.max(FlxG.width / w, FlxG.height / h);
		vid.setGraphicSize(w * sc, h * sc);
		vid.updateHitbox();
		vid.screenCenter();
	});
}

// The source's own end of the clip (6188-6192): drop the video, then
// `camHUD.flash(FlxColor.RED, 2)`. Nothing here touches the song - the clip
// runs over a song that is already playing, which is the whole point of the
// start above.
function mmIntroOver() {
	if (mmIntroDone) return;
	mmIntroDone = true;
	if (mmIntroVid != null) mmIntroVid.visible = false;
	if (camHUD != null) camHUD.flash(FlxColor.RED, 2);
}

// The backdrops go in one by one, each on top of the previous one, so the world
// layer ends up in the source's order: demColor, dembg, demLevel, floordemise
// (XML), demGround, underdembg, underdemLevel, underdemGround1, underdemGround2,
// underfloordemise (XML), underroofdemise (XML), whenyourered, then the four
// cutscene bodies and gordobondiola (XML).
function mmBuildBackdrops() {
	mmGetDemColor();
	mmDemBg = mmBackdrop("mario/MX/demise/1/Demise_BG_BG2", -500, 0.3, 0.3, 100, 0, true, mmDemColor);
	mmDemLevel = mmBackdrop("mario/MX/demise/1/Demise_BG_BGCaca", -300, 0.5, 0.5, 250, 0, true, mmLastSpr(mmDemBg, mmDemColor));
	mmDemGround = mmBackdrop("mario/MX/demise/1/Demise_BG_BG1", -70, 0.9, 0.9, 3200, 800, true, floordemise);
	mmUnderBg = mmBackdrop("mario/MX/demise/2/Demise_BG2_Mountains.png", -500, 0.3, 0.3, 100, 0, false, mmLastSpr(mmDemGround, floordemise));
	mmUnderLevel = mmBackdrop("mario/MX/demise/2/Demise_BG2_BGLower.png", -1400, 0.5, 0.5, 250, 0, false, mmLastSpr(mmUnderBg, floordemise));
	mmUnderGround1 = mmBackdrop("mario/MX/demise/2/Demise_BG2_BG1", -800, 0.9, 0.9, 3200, 6000, false, mmLastSpr(mmUnderLevel, floordemise));
	mmUnderGround2 = mmBackdrop("mario/MX/demise/2/Demise_BG2_BG2", -800, 0.9, 0.9, 3200, 4000, false, mmLastSpr(mmUnderGround1, floordemise));
	mmGetWhenYoureRed();
	mmGetDemiseTran();
}

// ---------------------------------------------------------------------------
// The foreground cars (16819-16871)
// ---------------------------------------------------------------------------
// The source picks a random 1..4 (1..2 underground), slides that sprite across,
// and half a second later picks again - `Reflect.getProperty(this, under +
// 'demFore' + coso)`, which here is an index into the two lists.
var mmFore = [];
var mmUnderFore = [];

function mmStartFore(lastSprite:Int) {
	var coso:Int = FlxG.random.int(1, 4);
	var under:Bool = false;
	if (underfloordemise != null && underfloordemise.visible) {
		coso = FlxG.random.int(1, 2);
		under = true;
	}
	if (coso == lastSprite) {
		mmStartFore(coso);
		return;
	}
	var list = under ? mmUnderFore : mmFore;
	var s = (coso - 1 < list.length) ? list[coso - 1] : null;
	if (s == null) return;

	if (FlxG.random.bool(50)) {
		if (!under && coso == 3) {
			s.x = -1800;
			FlxTween.tween(s, {x: 6800}, 1.3);
		} else {
			s.x = -3800;
			FlxTween.tween(s, {x: 3800}, 1.3);
			if (under)
				new FlxTimer().start(1, function(tmr) { mmStartFore(coso); });
		}
		if (!under)
			new FlxTimer().start(0.5, function(tmr) { mmStartFore(coso); });
	} else {
		new FlxTimer().start(0.5, function(tmr) { mmStartFore(lastSprite); });
	}
}

// ---------------------------------------------------------------------------
// The underground swap (case 1 and case 2)
// ---------------------------------------------------------------------------
function mmDemWorld(under:Bool) {
	if (under) {
		mmChangeChar(1, "mx_demiseUG");
		mmChangeChar(0, "bf_demiseUG");
	} else {
		mmChangeChar(1, "mx_demise");
		mmChangeChar(0, "bf_demise");
	}
	mmBackdropVisible(mmUnderBg, under);
	mmBackdropVisible(mmUnderLevel, under);
	mmBackdropVisible(mmUnderGround1, under);
	mmBackdropVisible(mmUnderGround2, under);
	if (underfloordemise != null) underfloordemise.visible = under;
	if (underroofdemise != null) underroofdemise.visible = under;
	mmBackdropVisible(mmDemBg, !under);
	mmBackdropVisible(mmDemLevel, !under);
	if (floordemise != null) floordemise.visible = !under;
	mmBackdropVisible(mmDemGround, !under);
	for (s in mmFore) if (s != null) s.visible = !under;
}

// ---------------------------------------------------------------------------
// Load
// ---------------------------------------------------------------------------
function onCountdown(event) {
	// `noCount = true` (3041).
	event.cancelled = true;
}

// PlayState.hx:6631-6639, in startSong(): the cutscene bodies start the song
// hidden at full alpha - case 5 below only flips `visible`, so without this the
// reveal would show the XML's alpha-0.000001 nothings.
function onSongStart() {
	for (s in [demcut1, demcut2, demcut3, demcut4]) {
		if (s == null) continue;
		s.visible = false;
		s.alpha = 1;
	}
}

function postCreate() {
	// PlayState.hx:3044-3046: hidden GF and a full opening health bar.
	if (gf != null) gf.visible = false;
	health = 2;
	// 5642-5646: `flipchar` plus the demiseport override - both icons mirrored,
	// both health bars back to normal.
	if (iconP1 != null) iconP1.flipX = true;
	if (iconP2 != null) iconP2.flipX = true;
	if (healthBar != null) healthBar.flipX = false;
	if (healthBarBG != null) healthBarBG.flipX = false;

	// 4445-4452: the foreground switch adds these after the character groups, so
	// they belong in front of the fighters. The lift is a splice plus an append,
	// not a bare remove + re-add: `remove(x)` only nulls the slot and `add(x)`
	// re-fills the first null slot of the list, which is that same one.
	for (s in [demFore1, demFore2, demFore3, demFore4, underdemFore1, underdemFore2]) {
		if (s == null) continue;
		remove(s, true);
		insert(members.length, s);
	}
	mmFore = [demFore1, demFore2, demFore3, demFore4];
	mmUnderFore = [underdemFore1, underdemFore2];

	mmBuildBackdrops();

	// The source's cutscene sprites 2..4 are placed relative to demcut1
	// (`demcut1.x + 650` and friends), which the extractor could not fold - the
	// XML has them all at (0, 0). Put them where the source puts them.
	if (demcut2 != null) { demcut2.x = -450; demcut2.y = -250; }
	if (demcut3 != null) { demcut3.x = 0; demcut3.y = 120; }
	if (demcut4 != null) { demcut4.x = -830; demcut4.y = -220; }

	mmStartFore(1);

	// 5647-5663: the filters are mounted at create, before the countdown runs.
	mmTvStack();

	// 5805-5808: the warp version's opening video, before the countdown.
	mmPlayIntroVideo();
}

// PlayState.hx:7705-7707, the Demise-specific flipchar icon layout.
function postUpdate(elapsed) {
	// The VCR/border stack's time uniform (`vcr.update(elapsed)`), before the
	// HUD early-return below - the filters (and the cutscene below) do not
	// depend on the icons.
	mmTvTick(elapsed);
	mmDemCutscene();
	if (healthBar == null || iconP1 == null || iconP2 == null) return;
	iconP2.x = healthBar.x + healthBar.width - 40;
	iconP1.x = healthBar.x + healthBar.width * (1 - health / 2) - 35;
}

// PlayState.hx:7791-7816, the cutscene's per-frame half: bodies 2..4 ride on
// body 1 every frame, body 1's Bodies animation carries GF and MX's fall, and
// its own frame 17 starts body 1's drift up off the stage into its hover.
function mmDemCutscene() {
	if (demcut1 == null) return;
	if (demcut2 != null) { demcut2.x = demcut1.x + 650; demcut2.y = demcut1.y; }
	if (demcut3 != null) { demcut3.x = demcut1.x + 1100; demcut3.y = demcut1.y + 370; }
	if (demcut4 != null) { demcut4.x = demcut1.x + 270; demcut4.y = demcut1.y + 30; }
	var fi:Dynamic = (demcut1.animation != null) ? demcut1.animation.frameIndex : null;
	if (fi == null) return;
	// 7800-7806: frame 17, body 1 (GF and MX with it) lifts off.
	if (fi == 17 && demcut1.alpha == 1 && demcut1.visible) {
		FlxTween.tween(demcut1, {y: -600, x: -200}, 5, {ease: FlxEase.quadInOut, onComplete: function(twn) {
			FlxTween.tween(demcut1, {x: -300}, 2.5, {ease: FlxEase.quadInOut, type: FlxTween.PINGPONG});
			FlxTween.tween(demcut1, {y: -500}, 4, {ease: FlxEase.quadInOut, type: FlxTween.PINGPONG});
		}});
	}
	// 7808-7816: the last frame - bodies and MX out, fighters back. Without
	// this BF kept case 5's alpha 0 for the rest of the song.
	if (fi == 232 && demcut1.alpha == 1 && demcut1.visible) {
		for (s in [demcut1, demcut2, demcut3, demcut4]) if (s != null) s.visible = false;
		if (gordobondiola != null) gordobondiola.visible = false;
		var b = mmBfChar();
		if (b != null) b.alpha = 1;
		var d = mmDadChar();
		if (d != null) d.alpha = 1;
	}
}

// 16489-16493: the flash pulse, one crochet long, on every beat while case 11
// has `demFlash` on.
var mmDemFlash:Bool = false;

function beatHit(curBeat:Int) {
	if (!mmDemFlash) return;
	var c = mmGetDemColor();
	FlxTween.color(c, 1 / (Conductor.bpm / 60), 0xFF4D0000, FlxColor.BLACK);
}

// ---------------------------------------------------------------------------
// 'Triggers Demise' 0-11
// ---------------------------------------------------------------------------
function onEvent(event) {
	if (event.event.name != "Triggers Demise" && event.event.name != "Triggers Universal") return;
	var trigger:Float = Std.parseFloat(Std.string(event.event.params[0]));
	if (trigger == null || Math.isNaN(trigger)) trigger = 0;

	switch (trigger) {
		case 0:
			// 11167: the 'HA!' that flies off to the left.
			var hatext = new FlxText(900, -270, 600, "HA!", 120);
			hatext.setFormat(Paths.font("mariones.ttf"), 120, FlxColor.WHITE, "left");
			add(hatext);
			hatext.angle = FlxG.random.float(-20, 20);
			FlxTween.tween(hatext, {x: 500, y: (hatext.angle * 20) - 270, alpha: 0}, 1, {ease: FlxEase.expoOut, onComplete: function(twn) {
				remove(hatext);
			}});

		case 1:
			// 11177: wipe to the underground, and two crochets later the swap.
			var tr1 = mmGetDemiseTran();
			tr1.x = -1600;
			FlxTween.tween(tr1, {x: 2600}, 1.4);
			new FlxTimer().start(2 * (1 / (Conductor.bpm / 60)), function(tmr) { mmDemWorld(true); });

		case 2:
			// 11204: the same wipe, back to the surface.
			var tr2 = mmGetDemiseTran();
			tr2.x = -1600;
			FlxTween.tween(tr2, {x: 2600}, 1.4);
			new FlxTimer().start(2 * (1 / (Conductor.bpm / 60)), function(tmr) { mmDemWorld(false); });

		case 3:
			// 11232: everything goes dark red and the fighters turn to
			// silhouettes; the 20.21s zoom to 0.4 is MMcamera's.
			FlxTween.tween(mmGetWhenYoureRed(), {alpha: 1}, 1, {ease: FlxEase.quadOut});
			if (underdemFore1 != null) FlxTween.tween(underdemFore1, {alpha: 0}, 1, {ease: FlxEase.quadOut});
			if (underdemFore2 != null) FlxTween.tween(underdemFore2, {alpha: 0}, 1, {ease: FlxEase.quadOut});
			var b3 = mmBfChar();
			if (b3 != null) FlxTween.color(b3, 1, FlxColor.WHITE, FlxColor.BLACK, {ease: FlxEase.quadOut});
			var d3 = mmDadChar();
			if (d3 != null) FlxTween.color(d3, 1, FlxColor.WHITE, FlxColor.BLACK, {ease: FlxEase.quadOut});

		case 4:
			// 11244: and back.
			FlxTween.tween(mmGetWhenYoureRed(), {alpha: 0}, 2, {ease: FlxEase.quadInOut});
			if (underdemFore1 != null) FlxTween.tween(underdemFore1, {alpha: 1}, 2, {ease: FlxEase.quadOut});
			if (underdemFore2 != null) FlxTween.tween(underdemFore2, {alpha: 1}, 2, {ease: FlxEase.quadOut});
			var b4 = mmBfChar();
			if (b4 != null) FlxTween.color(b4, 2, FlxColor.BLACK, FlxColor.WHITE, {ease: FlxEase.quadInOut});
			var d4 = mmDadChar();
			if (d4 != null) FlxTween.color(d4, 2, FlxColor.BLACK, FlxColor.WHITE, {ease: FlxEase.quadInOut});

		case 5:
			// 11254: the cutscene. The fighters go, the four cutscene bodies
			// appear, the floor/ground fade out and the camera lunges in
			// (MMcamera owns the zoom and the camFollowPos tweens).
			var b5 = mmBfChar();
			if (b5 != null) b5.alpha = 0;
			var d5 = mmDadChar();
			if (d5 != null) d5.alpha = 0;			for (s in [demcut1, demcut2, demcut3, demcut4]) {
			if (s == null) continue;
			s.visible = true;
			s.alpha = 1; // onSongStart already did this; belt and braces for the XML's 0.000001
			if (s.animation != null) s.animation.play("idle", true);
		}
			if (floordemise != null) FlxTween.tween(floordemise, {alpha: 0}, 0.5);
			mmBackdropFade(mmDemGround, 0, 0.5, null);
			FlxTween.tween(camHUD, {alpha: 0.1}, 0.5);

		case 6:
			if (floordemise != null) FlxTween.tween(floordemise, {alpha: 1}, 1);
			mmBackdropFade(mmDemGround, 1, 1, null);

		case 7:
			// 11284: MX drops in and the cutscene bodies go grey.
			if (gordobondiola != null) FlxTween.tween(gordobondiola, {x: 1000, y: -900}, 1.85, {ease: FlxEase.expoIn});
			for (s in [demcut1, demcut2, demcut3, demcut4])
				if (s != null) FlxTween.color(s, 0.4, FlxColor.WHITE, 0xFF5E5E5E);
			FlxTween.tween(camHUD, {alpha: 1}, 0.5);

		case 8:
			for (s in [demcut1, demcut2, demcut3, demcut4])
				if (s != null) FlxTween.color(s, 0.4, 0xFF5E5E5E, FlxColor.WHITE);

		case 9:
			// FOLLOWCHARS = !FOLLOWCHARS - the camera side.
			break;

		case 10:
			// ZOOMCHARS = !ZOOMCHARS - the camera side.
			break;

		case 11:
			mmDemFlash = !mmDemFlash;
	}
}
// === end MM stage triggers ===
