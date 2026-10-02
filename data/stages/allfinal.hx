// Ported from PlayState.hx beatHit() (case 'allfinal').
// The pupils sway is driven by "whoever is singing", which the source reads
// from the section's mustHitSection. Codename's chart has no such field, so
// mmPupilRight() (in the appended trigger block) uses the chart's
// 'Camera Movement' event - which the conversion emits straight from
// mustHitSection - and falls back to the camera target MMcamera publishes when
// that event has not reached this script.
function beatHit(curBeat:Int) {
	mmLastBeat = curBeat;

	// Source re-triggers BF's dance on these beats
	// (`var fuckyoupysch:Array<Int> = [57, 79, 97, 113, 185, 217, 241]`), because
	// he stands still through act 1's long instrumentals otherwise.
	var danceBeats:Array<Int> = [57, 79, 97, 113, 185, 217, 241];
	for (b in danceBeats) {
		if (curBeat == b) {
			var bfDance = mmBf();
			if (bfDance != null) bfDance.dance();
		}
	}

	// Yoshi restarts his idle every other beat, but only while idling.
	if (curBeat % 2 == 0) {
		var anim = funnylayer0.animation.curAnim;
		if (anim != null && anim.name == 'idle') {
			funnylayer0.playAnim('idle');
			funnylayer0.offset.x = 0;
			funnylayer0.offset.y = 0;
		}
	}

	// Ultra Mario's head bob + body pose change every 4 beats, and the pupils
	// slide toward the current singer. The pupil step is only *queued* here: the
	// beat is dispatched from Conductor.update, which is a FlxG.signals.preUpdate
	// hook (Conductor.hx:353) and so runs *before* PlayState.update executes the
	// chart's event loop. Sampling the singer at this point therefore reads the
	// previous section's 'Camera Movement' event, which made the eyes swap a whole
	// section (4 beats) late. The source is immune because it reads
	// SONG.notes[floor(curStep / 16)].mustHitSection straight out of the chart,
	// and Codename charts carry no such field. postUpdate runs after the event
	// loop (PlayState.hx:1446), so mmApplyPupils() in the trigger block does the
	// slide there - same beat, same 1.5s quadInOut tween as the source.
	if (curBeat % 4 == 0) {
		mmPupilBeat = curBeat;
		mmHeadBob(act3UltraHead1, -210);
		mmHeadBob(act3UltraHead2, -300);
		mmHeadBob(act3UltraPupils, 105);
		if (act3UltraBody != null) {
			if (curBeat <= 810) {
				if (curBeat != 808) act3UltraBody.animation.play('idle', true);
			} else {
				// Source: from the first %4 beat after 810 (i.e. 812, just after 3/4's
				// 'change' pose) the torso holds the 'idle-alt' design, and up to beat
				// 872 every 4th beat creeps the zoom up 0.005
				// (`triggerEventNote('Set Cam Zoom', camGame.zoom + 0.005, '')`). The
				// creep was missing, so act 3's second half sat at a fixed zoom instead
				// of slowly pushing in.
				if (mmTorsoDesign != 'idle-alt') {
					mmTorsoDesign = 'idle-alt';
					mmLog('act3: torso design -> idle-alt @ beat ' + curBeat + ' (' + Conductor.songPosition + ' ms)');
				}
				if (curBeat <= 872 && camGame != null) mmZoomCreep(camGame.zoom + 0.005);
				act3UltraBody.animation.play('idle-alt', true);
			}
		}
	}
}

function mmHeadBob(spr, base:Float) {
	if (spr == null) return;
	FlxTween.tween(spr, {y: base + 30}, 0.1, {ease: FlxEase.quadOut, onComplete: function(twn) {
		FlxTween.tween(spr, {y: base}, 0.4, {ease: FlxEase.quadInOut});
	}});
}

// === MM stage triggers (auto) ===
// 'Triggers All-Stars' (allfinal) - ported from PlayState.hx (case 'Triggers
// All-Stars').  This is the four-act finale: every act swaps characters,
// reveals a new backdrop and is stitched together with full-screen fades.
//
// Codename differences handled here:
//   * the source drives several full-screen overlays on its own `camOther` /
//     `camEst` cameras; Codename only has camGame/camHUD, so a dedicated,
//     non-scrolling `mmEst` camera is created for them (added with
//     defaultDraw=false, so the world is not duplicated on it).
//   * `dadGroup`/`gfGroup`/`boyfriendGroup` and `camFollowPos` do not exist in
//     Codename; characters are moved individually and the camera is owned by
//     songs/MMcamera.hx, which reads the same 'Triggers Universal' event.
//   * `customHB` and `resyncVocals()` are not exposed, so their fades are
//     applied to the health bar/icons instead and the vocal resync is guarded.
//
// The source's `titleText`/`autorText` act swaps (9831-9832, 9979-9980,
// 10083-10084) are not here but in `data/events/Show Song.hx`, which owns the
// card, keeps its two texts in step with the same 'Triggers Universal' values
// this script handles, and re-lays it out on every show - the chart re-shows
// the card once per act. The old comment here claimed the card 'is already
// hidden by then, so it never shows', which was wrong twice over: the card had
// no act text and was never re-laid out, so acts 2-4 re-showed 'Act 1' 30px
// lower each time.
//
// Not reproduced: `reloadHealthBarColors` (healthBar.createFilledBar is not
// script-reachable). The act 4 game-over character switch is reproduced, just
// not the way the source does it: the fork writes the global
// `GameOverSubstate.characterName`, this port carries the value on the dying
// character (see mmGameOverChar). The source's per-act `remove()`/`insert()`
// reshuffles of
// `dadGroup`/`gfGroup`/`act3BGGroup`/`act4BGGroup` ARE reproduced below (the
// stage XML keeps the characters after every stage sprite, which already
// matches the source's initial add order).

// --------------------------------------------------------------------------
// Overlays on the dedicated static camera
// --------------------------------------------------------------------------
function mmLog(msg:String) trace("[MM allfinal] " + msg);

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
// would put this layer *above* camHUD - over the notes and the HUD - so it is
// slid back into camHUD's own index here (the fleet-wide convention: piracy,
// forest, nesbeat, meatworld, exeport all place their camEst the same way).
function mmEstBelowHud() {
	if (mmEst == null || mmEstPlaced) return;
	var list = mmCamList();
	if (list == null) {
		if (!mmEstWarned) {
			mmEstWarned = true;
			mmLog("camEst: no FlxG.cameras.list - the overlays stay above camHUD");
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
}

// Screen-locked overlay drawn over the world.
function mmOverlay(spr) {
	spr.scrollFactor.set(0, 0);
	spr.cameras = [mmGetEst()];
	add(spr);
	return spr;
}

// Full-screen static image (single PNG, no atlas).
function mmFullImage(path:String, alpha:Float) {
	var s = new FunkinSprite(0, 0);
	s.loadGraphic(Paths.image(path));
	s.setGraphicSize(FlxG.width, FlxG.height);
	s.updateHitbox();
	s.screenCenter();
	s.alpha = alpha;
	return mmOverlay(s);
}

// Animated overlay at its natural size (atlas PNG + XML).
function mmAnimSprite(path:String, entries, alpha:Float) {
	var s = new FunkinSprite(0, 0);
	s.frames = Paths.getSparrowAtlas(path);
	for (e in entries) s.animation.addByPrefix(e[0], e[1], e[2], e[3]);
	s.alpha = alpha;
	return mmOverlay(s);
}

var mmBlack:FunkinSprite = null;
function mmGetBlack():FunkinSprite {
	if (mmBlack == null) {
		mmBlack = new FunkinSprite(0, 0);
		mmBlack.makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		mmBlack.scale.set(10, 10); // source's setGraphicSize(width * 10)
		mmOverlay(mmBlack);
	}
	return mmBlack;
}

var mmFog1:FunkinSprite = null;
var mmFog2:FunkinSprite = null;
var mmFog3:FunkinSprite = null;
var mmWhiteFlash:FunkinSprite = null;
var mmIntro1:FunkinSprite = null; // act 1 intro logo
var mmIntro2:FunkinSprite = null; // act 2 GF intro
var mmEyes:FunkinSprite = null;   // act 2 eyes
var mmIntro4:FunkinSprite = null; // act 4 voiceline
var mmGameOver:FunkinSprite = null;

// --------------------------------------------------------------------------
// World extras
// --------------------------------------------------------------------------
var mmSky:FunkinSprite = null; // act2 scrolling backdrop (source's FlxBackdrop)
// The source moves act2Sky with a tweened `velocity` (FlxBackdrop integrates it
// itself). A bare Float cannot be tweened, so the speed lives in a holder and
// `update()` integrates it - which is exactly what the FlxBackdrop did.
var mmSkyVelObj = {v: 100.0};
var mmSkyTween = null;
var mmFloaters = [];
// The source hides the whole act4Floaters group at 4/7, so objects spawned
// after that (the timer keeps running) come up invisible too.
var mmFloatersHidden:Bool = false;
var mmSpawnNum:Int = 1;
var mmFloaterTimer = null;

var mmIconLG = null;
var mmIconW4 = null;
var mmIconY0 = null;
var mmIconA4 = null;
var mmIconA42 = null;

// Chart 'Camera Movement' target (0 = opponent, 1 = player). Stands in for the
// source's per-section mustHitSection, which Codename charts do not carry.
var mmTarget:Int = 0;

// The last beatHit's beat (written by the generated beatHit head above).
var mmLastBeat:Int = -1;

// Last torso animation the beatHit asked Ultra M's body to play ('idle' /
// 'idle-alt'), so the design switch is logged once instead of every 4 beats.
var mmTorsoDesign:String = "";

// NOTE: this used to fall back to a value MMcamera published onto PlayState
// ("mmCamTarget") before the first 'Camera Movement' event arrived. That read
// threw "Invalid field:mmCamTarget" - Haxe's `Reflect.field` on cpp throws for a
// field that does not exist, it does not return null - and the events always do
// arrive, so the fallback only caused log spam. The chart events are the source
// of truth below.

// Beat whose pupil step is waiting for postUpdate (see beatHit / mmApplyPupils).
var mmPupilBeat:Int = -1;

// Source beatHit (case 'allfinal'): the pupils slide toward whoever is singing -
// `mustHitSection ? x = -175 : x = -220`.
function mmPupilRight():Bool {
	// mmTarget is fed by the chart's own 'Camera Movement' events (see onEvent),
	// which the conversion emits once per section - the same thing the source
	// reads as `mustHitSection`.
	return mmTarget == 1;
}

// Applies the pupil slide for `beat`, queued by beatHit. This has to run from
// postUpdate, not from beatHit: Conductor dispatches beatHit from
// FlxG.signals.preUpdate (Conductor.hx:353), while the chart's 'Camera Movement'
// event for that same beat is only executed later in the frame, in
// PlayState.update's event loop (script `update` is called at the top of
// PlayState.update, `postUpdate` at the bottom, line 1446). Sampling the singer
// in beatHit read the *previous* section's target, so the eyes switched a whole
// section - 4 beats, ~1.5s at 155bpm - late.
function mmApplyPupils(beat:Int) {
	if (act3UltraPupils == null) return;
	var px:Float = mmPupilRight() ? -175 : -220;
	FlxTween.tween(act3UltraPupils, {x: px}, 1.5, {ease: FlxEase.quadInOut});
}

function postUpdate(elapsed:Float) {
	if (mmPupilBeat < 0) return;
	var b:Int = mmPupilBeat;
	mmPupilBeat = -1;
	mmApplyPupils(b);
}

// Source beatHit (case 'allfinal'): while act 3's second half runs (curBeat
// 812..872) it creeps the zoom up 0.005 every 4 beats with
// `triggerEventNote('Set Cam Zoom', camGame.zoom + 0.005, '')`. 'Set Cam Zoom'
// writes defaultCamZoom, and the engine lerps camGame.zoom towards it, so this
// mirrors both instead of snapping an absolute value.
function mmZoomCreep(z:Float) {
	if (camGame != null) camGame.zoom = z;
	var st = PlayState.instance;
	if (st == null) return;
	// defaultCamZoom is a PlayState field, not one of this script's own vars.
	Reflect.setField(st, "defaultCamZoom", z);
}

// --------------------------------------------------------------------------
// Build everything the source builds in its stage-creation block
// --------------------------------------------------------------------------
function mmBuildAllStars() {
	mmGetBlack();
	mmFog1 = mmFullImage("mario/allfinal/act1/act1", 1);
	mmFog2 = mmFullImage("mario/allfinal/act2/act2", 1);
	mmFog3 = mmFullImage("mario/allfinal/act3/act3", 0.7);
	mmIntro1 = mmAnimSprite("mario/allfinal/act1/All_Stars_Intro",
		[["idle", "intro anim", 24, false]], 0);
	mmIntro1.screenCenter(FlxAxes.X);
	mmIntro2 = mmAnimSprite("mario/allfinal/act1/Act_2_Intro",
		[["idle", "Anim1", 24, true]], 0);
	mmIntro2.y = 330;
	mmIntro2.scale.set(2, 2);
	mmIntro2.screenCenter(FlxAxes.X);
	mmIntro2.x -= 40;
	mmIntro2.angle = -10;
	mmEyes = mmAnimSprite("mario/allfinal/act1/Act_2_Intro",
		[["idle", "EyesBG", 24, false]], 1);
	mmEyes.y = 320;
	mmEyes.scale.set(0.8, 0.8);
	mmEyes.screenCenter(FlxAxes.X);
	mmEyes.x -= 270;
	mmEyes.origin.set(mmEyes.width / 2, mmEyes.height / 2);
	mmIntro4 = mmAnimSprite("mario/allfinal/act4/Act_4_Voiceline",
		[["anim", "thingy", 24, false]], 0.00001);
	mmIntro4.scale.set(0.01, 0.01);
	// The source's act4GameOver is a plain sprite at (0,0) on camEst with no
	// setGraphicSize, and the art is only 351x55 - so do not stretch it. It IS
	// screenCentered though (PlayState.hx:3940 `act4GameOver.screenCenter()`),
	// and screenCenter() is what puts the 351x55 art in the middle of the
	// screen: without it the sprite sits at its (0,0) top-left corner, which is
	// where the game-over text used to show up.
	mmGameOver = new FunkinSprite(0, 0);
	mmGameOver.loadGraphic(Paths.image("mario/allfinal/act4/Act_4_FINALE_Gameover"));
	mmGameOver.screenCenter();
	mmGameOver.alpha = 0;
	mmOverlay(mmGameOver);
	// The source's act2WhiteFlash is a *stage* sprite, not a HUD/overlay one:
	// it does `add(act2Stat); add(act2WhiteFlash);`, so it lives in the world
	// layer and a huge size (`setGraphicSize(act2Stat.width * 10)`). Keeping that
	// matters - on the overlay camera it drew over the HUD, and in act 4 it also
	// covered the death sprite and the game-over art, which the source draws on
	// top of it.
	mmWhiteFlash = new FunkinSprite(0, 0);
	mmWhiteFlash.makeGraphic(FlxG.width, FlxG.height, FlxColor.WHITE);
	var flashScale:Float = 56;
	if (act2Stat != null && act2Stat.width > 0) flashScale = (act2Stat.width * 10) / FlxG.width;
	mmWhiteFlash.scale.set(flashScale, flashScale);
	mmWhiteFlash.alpha = 0;
	mmWhiteFlash.scrollFactor.set(1, 1);
	// Source: add(act2Stat); add(act2WhiteFlash) -> the flash is part of the world
	// layer, right after the static.
	mmInsertInWorld(act2Stat, mmWhiteFlash, 1);

	// NOTE: the character-atlas preload does NOT happen here. One atlas is
	// roughly a second of decode, so a timer firing during the song - even 1.6s
	// apart - makes the first ~18 seconds of the intro stutter, which is exactly
	// what the previous version of this code did. It now runs once, at script
	// load, i.e. inside the song's loading phase - see mmPreloadAll() below.

	mmSky = new FunkinSprite(-500, -300);
	mmSky.loadGraphic(Paths.image("mario/allfinal/act2/act2_scroll1"));
	mmSky.scrollFactor.set(0.3, 0.3);
	add(mmSky);

	mmBuildIcons();
}

function mmIcon(sheet:String, isAtlas:Bool) {
	var s = new FunkinSprite();
	if (isAtlas) {
		s.frames = Paths.getSparrowAtlas(sheet);
	} else {
		s.loadGraphic(Paths.image(sheet));
		var fw = Math.floor(s.width / 2);
		var fh = Math.floor(s.height);
		s.loadGraphic(Paths.image(sheet), true, fw, fh);
		s.animation.add("win", [0], 10, true);
		s.animation.add("lose", [1], 10, true);
	}
	s.cameras = [camHUD];
	add(s);
	return s;
}

function mmBuildIcons() {
	mmIconLG = mmIcon("icons/icon-LG", false);
	mmIconW4 = mmIcon("icons/icon-W4R", false);
	mmIconY0 = mmIcon("icons/icon-Y0SH", false);
	mmIconLG.visible = false;
	mmIconW4.visible = false;
	mmIconY0.visible = false;

	mmIconA4 = mmIcon("mario/allfinal/act4/iconAct4", true);
	var names = ["beta2", "costume", "devil", "gb", "hally", "luigiH2", "mrl",
		"2MX", "omega", "cdpeach", "peachex", "secret", "stanley", "sys",
		"turmoil", "v", "wario", "wdwluigi", "BEEGY0SH"];
	for (n in names) mmIconA4.animation.addByPrefix(n, n, 1, false);
	mmIconA4.visible = false;

	mmIconA42 = mmIcon("mario/allfinal/act4/iconAct4", true);
	mmIconA42.animation.addByPrefix("yoshiex", "yoshiex", 1, false);
	mmIconA42.visible = false;
}

// --------------------------------------------------------------------------
// Act sprite sets (the XML has no groups, so keep lists)
// --------------------------------------------------------------------------
var mmAct1 = null;
var mmAct2 = null;
var mmAct3 = null;
var mmAct4 = null;
// The source reshuffles whole FlxSpriteGroups; the XML is flat, so the same
// sets are kept as lists.
var mmAct3BG = null;  // act3BGGroup (the eight world sprites - act3Spotlight is
					  // not in it, and act3Fog is the camOther overlay mmFog3)
var mmAct4BG = null;  // act4BGGroup
var mmAct4BG2 = null; // act4BG2Group

// The source branches on ClientPrefs.downscroll when the extra HUD icons slide
// in; PlayState.downscroll is a get/set property, so read it defensively.
var mmDownscroll:Bool = false;
function mmDownScroll():Bool { return mmDownscroll; }

function mmVis(list, on:Bool) {
	if (list == null) return;
	for (o in list) if (o != null) o.visible = on;
}

// FlxSprite draws at `x - offset`, and Character.playAnim sets
//     offset.x = globalOffset.x * (isPlayer != playerOffsets ? 1 : -1)
//     offset.y = -globalOffset.y
// so a character *renders* at
//     rendered.x = x - k * globalOffset.x      k = (isPlayer != playerOffsets) ? 1 : -1
//     rendered.y = y + globalOffset.y
// The source only ever speaks of one position: `group + position`, where
// `position` is exactly what Codename keeps in globalOffset. Anything that has
// to place a character where the source puts it must invert the above: to render
// at world w, store `w + k * globalOffset.x` and `w.y - globalOffset.y` (which is
// what mmChangeChar does). Without that, any character whose position[0] is not 0
// lands 2 * position[0] away from the source, because the player side flips the
// sign while the opponent side happens to already agree.
function mmSideK(c):Float {
	if (c == null) return 1;
	return (c.isPlayer != c.playerOffsets) ? 1 : -1;
}

// Place `c` so that the engine renders it at the given world position, i.e. the
// inverse of the render offset documented above. Use this for the source writes
// that target the *sprite* (`dad.x = 320` in act 2, `dad.x = -370` in act 2,
// `dad.x = -1400` in act 3) - those are absolute world positions. The writes that
// target the *group* go through mmPlaceGroup instead.
function mmPlaceWorld(c, worldX:Float, worldY:Float) {
	if (c == null) return;
	c.x = worldX + mmSideK(c) * c.globalOffset.x;
	c.y = worldY - c.globalOffset.y;
}

// Place `c` as if the source had written its GROUP position (`gfGroup.x = 200`,
// `dadGroup.x = 100`, `boyfriendGroup.x = 810`).
//
// The source renders a character at `group + position[0]`, while we render at
// `x - k * globalOffset.x` (Character.hx:282, `offset.x = globalOffset.x *
// (isPlayer != playerOffsets ? 1 : -1)`), so writing the group x straight into
// `c.x` is only right when k is -1 - which is the dad and gf strumlines. The
// player's character (k = +1) lands `2 * position[0]` short, and worse,
// mmChangeChar reads that value back to recover the group position for the next
// swap, so every later swap in the act inherits the error. boyfriend is the one
// that bites: bf_ultrafinale has position.x = 90, so act 4's `boyfriendGroup.x =
// 810` put him 180px left of where he belongs and act 4/2's swap then landed him
// 180px further left again. Going through here keeps the stored value canonical
// for every side, so the recovery stays exact.
function mmPlaceGroup(c, groupX:Float, groupY:Float) {
	if (c == null) return;
	mmPlaceWorld(c, groupX + c.globalOffset.x, groupY + c.globalOffset.y);
}

// --------------------------------------------------------------------------
// Character resolution
// --------------------------------------------------------------------------
// The source's own 'Change Character' REASSIGNS the PlayState fields a script
// reads as `dad` / `boyfriend` / `gf` - PlayState.hx:9348 `dad =
// dadMap.get(value2)`, 9391 `gf = gfMap.get(value2)`. Our mmChangeChar (and
// data/events/Change Character.hx) replace the *strumline's* character instead,
// which is what actually renders - so the strumline is unambiguously the
// character the source means, and that is what every read below resolves.
//
// `dad` / `boyfriend` / `gf` are getters that read `strumLines.members[i]
// .characters[0]` (PlayState.hx:2259-2293), so they are a live view of the
// strumline and cannot go stale across a swap. Resolving the strumline is what
// the port's other scripts do anyway, and every step below is null-guarded, so a
// resolution failure can never kill a whole act.
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

// Generated charts put the opponent first, the player second, the girlfriend
// third - the same order data/events/Change Character.hx uses.
function mmDad() return mmMem(0);
function mmBf() return mmMem(1);
function mmGf() return mmMem(2);

// --------------------------------------------------------------------------
// Helpers
// --------------------------------------------------------------------------
// resyncVocals() is *private* in this engine build, so it can only be reached
// through reflection. The old version checked `Reflect.hasField` and then called
// `Reflect.callMethod(..., Reflect.field(...), [])` - if the interpreter reports
// the field but hands back null (which is what happens for non-public methods on
// some targets), callMethod throws and the whole act handler it was called from
// dies with it. That is why it is never called "for real" unless the resolved
// value is verifiably a function, and why every act now calls it LAST.
function mmResync() {
	var st = PlayState.instance;
	if (st == null) { mmLog("resync: no PlayState, skipped"); return; }
	var fn = Reflect.field(st, "resyncVocals");
	if (fn == null || !Reflect.isFunction(fn)) { mmLog("resync: resyncVocals not script-reachable, skipped"); return; }
	Reflect.callMethod(st, fn, []);
	mmLog("resync: ok");
}

function mmFlash(color:Int, dur:Float) {
	FlxG.camera.flash(color, dur);
}

// --------------------------------------------------------------------------
// Act 4 BF solo: hide the opponent's strums, centre BF's
// --------------------------------------------------------------------------
// Historical solo offsets, now owned by the modern song's modchart
// (source/modchart/Modcharts.hx,
// `case 'all-stars'`):
//
//     queueSet(4544, "transformX", -320, 0);   // player strums (BF)
//     queueSet(4544, "transformX", 1500, 1);   // opponent strums
//     queueSet(4800, "transformX", 0, 0);
//     queueSet(4800, "transformX", 0, 1);
//
// step -> ms at 150bpm is 100ms, so step 4544 is exactly the 4/2 trigger (the
// sad perspective, i.e. BF's solo) and step 4800 the 4/6 one (the finale): the
// shift lasts exactly the solo.
//
// Both source modchart and PlayState getPos use 0 = BF, 1 = opponent,
// so -320 lands on BF and +1500 on the opponent. Checked against both engines' strum X:
//     source getBaseX : bf 734,846,958,1070 -> -320 = 414..750 (middle)
//                       opp 102..438        -> +1500 = 1602..1938 (off screen)
//     CnE strum X     : bf 736,848,960,1072 -> -320 = 416..752 (middle)
//                       opp 96..432         -> +1500 = 1596..1932 (off screen)
// so the same two offsets do the same thing here: BF's strumline lands centred
// on 640 and the opponent's whole strumline (notes included) leaves the screen,
// which is how the opponent's notes "disappear" during the solo.
//
// MMmodfields applies these offsets to receptors and their relative notes.
// Do not apply a second stage-level delta here.
function mmSetSolo(on:Bool) {
	// songs/all-stars/scripts/modchart.hx owns the source's step 4544/4800
	// offsets. A stage-level copy applied them twice and also affected Old,
	// whose display name matches no Modcharts.hx timeline. Nothing to do here.
}

// --------------------------------------------------------------------------
// Act 4 finale lightning
// --------------------------------------------------------------------------
// The source only does `add(act4Lightning); act4Lightning.visible = true;` at
// 4/6, relying on the stage-creation block having started 'idle' at load. The
// XML does start it (`anim="idle" type="loop"`), so the fallback below is a
// no-op for a healthy sprite - but this is the one sprite whose entire reason to
// exist is that diagonal line, so the animation is asserted anyway (rebuilt from
// the atlas if the XML's addByPrefix never landed), then visibility/alpha, then
// the sprite goes to the front.
function mmLightningOn() {
	var s = act4Lightning;
	if (s == null) {
		mmLog("act4/6: lightning is NULL - the stage XML never handed act4Lightning to this script");
		return;
	}
	// Source: add(act4Lightning) + `visible = true` - it goes in front of
	// everything that was already there. These are the lines that matter, so
	// they run before anything that could throw below.
	mmMoveToFront(s);
	s.scrollFactor.set(1, 1);
	s.alpha = 1;
	s.visible = true;
	// `idle` is the XML's own animation (`anim="idle" type="loop"`), so it is
	// normally already registered and looping. Last, so a throw here cannot undo
	// the visible state set above.
	if (!s.animation.exists("idle")) {
		s.frames = Paths.getFrames("mario/allfinal/act4/Act_4_FINALE_Lightingmcqueen");
		s.animation.addByPrefix("idle", "line", 24, true);
	}
	s.animation.play("idle", true);
}

// Source: tween(act2Sky.velocity, {x: target}, dur, {ease: ...}) - the two act 2
// speed changes (10 over 0.8s quadInOut at 2/1, -700 over 1.6s cubeOut at 2/3).
function mmSkyTo(target:Float, dur:Float, ease) {
	if (mmSkyTween != null) {
		mmSkyTween.cancel();
		mmSkyTween = null;
	}
	mmSkyTween = FlxTween.tween(mmSkyVelObj, {v: target}, dur, {ease: ease, onComplete: function(twn) {
		mmSkyTween = null;
	}});
}

function mmSingName(dir:Int):String {
	switch (dir) {
		case 0: return "singLEFT";
		case 1: return "singDOWN";
		case 2: return "singUP";
		default: return "singRIGHT";
	}
}

// Same character swap as data/events/Change Character.hx, called directly so
// the acts can swap characters without dispatching a chart event.
// NOTE: every bail-out below logs *why* it bailed out. This function used to
// return silently on a missing strumline / empty strumline character, and a
// silent return here looks exactly like "the act transition did nothing".
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

// --------------------------------------------------------------------------
// Unloading a swapped-out character
// --------------------------------------------------------------------------
// Every act swap is forward-only - the opponent goes omega -> w4r -> gx ->
// mario_ultra2 -> mario_ultra3, the player bf_behind -> bfASsad ->
// bf_ultrafinale -> 2 -> 3, the girlfriend gf -> lg2 - so the character a swap
// replaces is never asked for again, yet nothing freed it: all of them stayed in
// memory with their decoded atlases until the end of the finale.
//
// `destroy()` is the whole unload. It drops the sprite's own frames/animation,
// and `FlxSprite.destroy()` nulls `graphic`, which *decrements the atlas' use
// count*; flixel's `FlxGraphic.checkUseCount()` then disposes that graphic (its
// BitmapData included, removed from `FlxG.bitmap` as well) as soon as the count
// reaches zero. That is what makes this safe without any bookkeeping here: a
// sheet another live character still holds keeps its count above zero and
// survives - only the sheets nobody uses any more are freed.
//
// The caller must have already taken `c` out of its strumline and out of the
// draw list, and read everything it needs off it (game over character,
// placement); this is the last thing an act swap does. The stale frames entry is
// dropped too: `Paths.getFrames()` would notice the disposed parent and
// re-decode by itself, this just does not keep the dead reference around.
function mmUnloadChar(c) {
	if (c == null) return;
	var img:String = null;
	if (c.frames != null && c.frames.parent != null) img = c.frames.parent.key;
	c.destroy();
	if (img != null && Paths.tempFramesCache.exists(img)) Paths.tempFramesCache.remove(img);
}

function mmChangeChar(index:Int, name:String) {
	if (name == null || name == "" || name == "null") { mmLog("CC: bad name, skipped"); return; }
	var xmlPath = Paths.xml("characters/" + name);
	if (!Assets.exists(xmlPath)) { mmLog("CC: no xml at " + xmlPath + ", skipped"); return; }
	if (strumLines == null) { mmLog("CC: strumLines unavailable, skipped"); return; }
	var member = null;
	switch (index) {
		case 0: member = (strumLines.members.length > 1) ? strumLines.members[1] : null;
		case 2: member = (strumLines.members.length > 2) ? strumLines.members[2] : null;
		default: member = strumLines.members[0];
	}
	if (member == null) { mmLog("CC: no strumline for index " + index + ", skipped"); return; }
	if (member.characters.length < 1) { mmLog("CC: strumline has no character, skipped"); return; }
	var old = member.characters[0];
	if (old.curCharacter == name) return;
	var isPlayer = old.isPlayer;
	var oldIndex:Int = members.indexOf(old);
	// Build the replacement *before* touching the old character: if the engine
	// cannot create it (missing atlas, bad xml), the old one is still in the game
	// and the rest of the act can run, instead of leaving the strumline empty.
	var fresh = new Character(0, 0, name, isPlayer);
	// Character.globalOffset comes from the character XML and is what the source
	// calls `position`; read it before applyCharStuff touches the sprite.
	var goX:Float = fresh.globalOffset.x;
	var goY:Float = fresh.globalOffset.y;
	if (stage != null) stage.applyCharStuff(fresh, member.data.position, 0);
	// applyCharStuff parked the swap-in at the stage node's x/y, which is the
	// source's `dadGroup`/`boyfriendGroup`/`gfGroup` x/y. This fork's
	// 'Change Character' does NOT reposition the swap-in at all: it picks a
	// pre-created character out of dadMap/boyfriendGroup/gfMap, and each of those
	// was built as `new Character(0, 0, name)` + `startCharacterPos()` while
	// already inside the group - so the swap-in sits at `group + its own
	// position`. Reproduce that instead of leaving it at the bare stage node.
	// The group's current position, recovered from the character being replaced.
	// The source never repositions a swap-in: it drops it into the SAME
	// FlxSpriteGroup - whose x/y earlier triggers may already have moved (act 4
	// does `dadGroup.x = 100`, `boyfriendGroup.x += 270`, ...) - and
	// startCharacterPos() adds the new character's own position on top. So the
	// stage node is only correct while the group still sits at its default, which
	// stops being true in act 4. Since rendered.x is `x + k * offset.x` while the
	// source's world x is `groupX + offset.x`, the stored x must be
	// `groupX + (k + 1) * offset.x`. y is `groupY` either way.
	var oldK:Float = mmSideK(old);
	var groupX:Float = old.x - (oldK + 1) * old.globalOffset.x;
	var groupY:Float = old.y;
	mmPlaceWorld(fresh, groupX + goX, groupY + goY);
	remove(old);
	member.characters.remove(old);
	// Keep the swap-in at the old character's draw index so the source's per-act
	// draw-order reshuffles survive later 'Change Character' swaps (the source
	// re-adds into the same persistent group, so the group keeps its z-position).
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
	// The swap is complete and everything the old character had to give (its
	// placement above, its game over character two lines up) has been read, so
	// this is the point where it can be handed back to the engine - see
	// mmUnloadChar for why that also frees its atlas.
	mmUnloadChar(old);
}

// --------------------------------------------------------------------------
// Draw-order helpers. `members` in a stage script *is* the state's draw list:
// Stage.loadXml puts every stage sprite into it (`addSprite` -> `state.add`) and
// inserts each character at its marker (`applyCharStuff`), so the world layer is
// the run of sprites below the character band and `members.indexOf(<stage
// sprite>)` finds it directly. (The old `stage.members` did not exist - calling
// through it resolved to null and threw Null Function Pointer, aborting the rest
// of the handler.) These helpers retarget the source's
// `insert(members.indexOf(<world sprite>), x)` calls by what is inserted.
// --------------------------------------------------------------------------

// Index in the state's draw list of the first character - the top of the world
// layer. The girlfriend node is the first character node in every ported stage
// XML, and its invisible marker is inserted one slot *past* its character, so
// `indexOf(marker) - 1` is the girlfriend (and the band start).
function mmWorldTop():Int {
	var st = PlayState.instance;
	if (st == null || stage == null) return -1;
	var poses = Reflect.field(stage, "characterPoses");
	var gfPos = (poses != null) ? poses.get("girlfriend") : null;
	if (gfPos == null) return -1;
	var i:Int = st.members.indexOf(gfPos);
	return (i >= 0) ? i - 1 : -1;
}

// Put a *world* sprite into the world layer at the anchor's slot (offset 0 =
// just behind the anchor, 1 = just in front of it). Falls back to the end of the
// world layer - directly below the characters - when the anchor is not there.
function mmInsertInWorld(anchor:Dynamic, obj:Dynamic, offset:Int):Void {
	var i:Int = (anchor != null) ? members.indexOf(anchor) : -1;
	if (i >= 0) { insert(i + offset, obj); return; }
	var w:Int = mmWorldTop();
	if (w >= 0) insert(w, obj); else add(obj);
}

// A *character* can never be interleaved with the world layer: the state draws
// the whole stage group first and the characters after it. So the closest the
// port can get to the source's "put this character right in front of / behind
// that world sprite" is the back of the character band, i.e. immediately above
// the world layer.
function mmInsertBehindCharacters(obj:Dynamic):Void {
	var w:Int = mmWorldTop();
	if (w >= 0) insert(w, obj); else add(obj);
}

// Take a stage sprite out of the world layer (a plain state remove - the
// stage's sprites already live in the state's draw list).
function mmLeaveWorld(obj:Dynamic):Void {
	remove(obj);
}

// The source's `remove(x); add(x)` on one of its own state sprites means "move
// to the very front of the draw list". It cannot be a bare remove + re-add:
// `FlxGroup.remove(basic, splice = false)` only nulls the slot
// (`members[index] = null`, `length` untouched) and `FlxGroup.add` re-fills the
// *first* null slot (`getFirstNull()` is `members.indexOf(null)`) - which is
// that same slot, so the sprite stays put; with a hole left anywhere earlier in
// the list (this stage swaps characters all the time) it would even travel
// backwards. Splice it out and append it past the end of the list instead.
function mmMoveToFront(obj:Dynamic):Void {
	remove(obj, true);
	insert(members.length, obj);
}

// One floating object for the act 4 finale (source's act4Floaters spawner).
function mmSpawnFloater() {
	var objsize:Float = FlxG.random.int(60, 115) / 100;
	var o = new FunkinSprite(2200, 200 + FlxG.random.int(-250, 250));
	// getFrames, not getSparrowAtlas: this is the exact call mmPreloadAll() already
	// cached, so the first floater of the finale no longer decodes the sheet.
	o.frames = Paths.getFrames("mario/allfinal/act4/floating objects");
	o.animation.addByIndices("1", "floating objects", [0], "", 24, true);
	o.animation.addByIndices("2", "floating objects", [1], "", 24, true);
	o.animation.addByIndices("3", "floating objects", [2], "", 24, true);
	o.animation.addByIndices("4", "floating objects", [3], "", 24, true);
	o.animation.addByIndices("5", "floating objects", [4], "", 24, true);
	o.animation.addByIndices("6", "floating objects", [5], "", 24, true);
	o.animation.addByIndices("7", "floating objects", [6], "", 24, true);
	o.animation.addByIndices("8", "floating objects", [7], "", 24, true);
	o.animation.addByIndices("9", "floating objects", [8], "", 24, true);
	o.animation.addByIndices("10", "floating objects", [9], "", 24, true);
	o.animation.play(FlxG.random.int(1, 10) + "", true);
	o.angle = FlxG.random.int(0, 360);
	o.scrollFactor.set(0.65 + (objsize / 5), 0.65 + (objsize / 5));
	o.scale.set(objsize, objsize);
	if (mmFloatersHidden) o.visible = false;
	var bfNow = mmBf();
	if (bfNow != null && bfNow.curCharacter == "bf_ultrafinale2") o.color = 0xff4e4e4e;
	// The source inserts into its own act4Floaters group, which sits right after
	// act4BGGroup (= act4Stat + act4Ripple), so a floater only has to land in that
	// band: just in front of the ripple, which is still behind the finale pipes
	// and behind the characters. (The old `+ Math.floor(6 + objsize * 100)` index
	// always overflowed the member list and put the floaters in front of the
	// characters instead.)
	mmInsertInWorld(act4Ripple, o, 1);
	mmFloaters.push(o);

	var speed:Float = FlxG.random.int(95, 220) / (7 + (mmSpawnNum * 3));
	if (FlxG.random.bool(50))
		FlxTween.tween(o, {angle: o.angle + FlxG.random.int(90, 360)}, speed);
	else
		FlxTween.tween(o, {angle: o.angle - FlxG.random.int(90, 360)}, speed);
	FlxTween.tween(o, {x: -450}, speed, {onComplete: function(twn) { o.destroy(); mmFloaters.remove(o); }});
}

function mmStartFloaters() {
	if (mmFloaterTimer != null) return;
	mmFloaterTimer = new FlxTimer().start(1 / mmSpawnNum, function(tmr) {
		for (i in 0...mmSpawnNum) mmSpawnFloater();
	}, 0); // 0 loops = repeat forever (the source never resets the interval)
}

// --------------------------------------------------------------------------
// Start-of-song state
// --------------------------------------------------------------------------
function mmAllStarsInit() {
	mmAct1 = [act1Stat, act1Sky, act1Skyline, act1Buildings, act1Floor, act1FG, act1Gradient];
	mmAct2 = [act2Stat, act2PipesFar, act2Gradient, act2PipesMiddle, act2PipesClose,
		act2LPipe, act2WPipe, act2YPipe, act2BFPipe];
	mmAct3 = [act3Stat, act3Hills, act3UltraArm, act3UltraBody, act3UltraHead1,
		act3UltraHead2, act3UltraPupils, act3BFPipe, act3Spotlight];
	mmAct4 = [act4Stat, act4Ripple, act4Pipe1, act4Pipe2, act4Memory1, act4Memory2,
		act4Lightning, act4DeadBF, act4Spotlight];
	mmAct3BG = [act3Stat, act3Hills, act3UltraArm, act3UltraBody, act3UltraHead1,
		act3UltraHead2, act3UltraPupils, act3BFPipe];
	mmAct4BG = [act4Stat, act4Ripple];
	mmAct4BG2 = [act4Pipe2, act4Memory1, act4Memory2];

	// The source sets this pivot in its stage-creation block; the XML has no
	// origin attribute, so it has to be set here.
	if (act3UltraArm != null) act3UltraArm.origin.set(880, 1540);

	// The source adds these three *after* the character groups (PlayState.hx
	// 4579), so they are foreground layers: act1FG and act1Gradient sit over the
	// act 1 city, act3Spotlight washes the act 3 stage. The XML puts every stage
	// sprite before the characters, so move them to the front here - as a splice
	// plus an append, the way mmMoveToFront does it and for the same reason.
	for (s in [act1FG, act1Gradient, act3Spotlight]) {
		if (s != null) {
			remove(s, true);
			insert(members.length, s);
		}
	}

	mmDownscroll = false;
	if (PlayState.instance != null && Reflect.hasField(PlayState.instance, "downscroll"))
		mmDownscroll = Reflect.field(PlayState.instance, "downscroll") == true;

	mmFog1.visible = false;
	mmFog2.visible = false;
	mmFog3.visible = false;
	mmVis(mmAct2, false);
	mmVis(mmAct3, false);
	mmVis(mmAct4, false);
	mmSky.visible = false;
	funnylayer0.visible = false;
	if (act3UltraHead2 != null) act3UltraHead2.alpha = 0.00001;
	act4DeadBF.alpha = 0.00001;
	mmBlack.alpha = 1;
	mmIntro1.alpha = 0;
	mmIntro2.visible = false;
	mmEyes.visible = false;
	mmIntro4.alpha = 0.00001;
	mmGameOver.alpha = 0;
	mmGameOver.visible = false;
	if (camHUD != null) camHUD.visible = false; // 4019 (not `noHUD`: the act fades bring it back)
}

// `noCount = true` (3683): the fork never builds its 3-2-1-GO sprites (Psych
// gates the whole countdown block on `!noCount`), so the song starts on the
// chart's own first beat with no READY/SET/GO over it. Codename builds those in
// the cancellable `onCountdown` event, one call per tick, so cancelling it drops
// them exactly the way the fork's flag does - the same thing hatebg.hx,
// wetworld.hx, endstage.hx, piracy.hx, realbg.hx, secretbg.hx, castlestar.hx,
// turmoilsweep.hx, demiseport.hx, directstream.hx, exeport.hx and
// songs/MMcamera.hx (for Paranoia) do. The countdown *timing* is untouched:
// the engine still advances `Conductor.songPosition` through the lead-in, so the
// song starts where it did before, just silently.
function onCountdown(event) {
	event.cancelled = true;
}

// NOTE: never use `try { } catch (e) { }` anywhere in a CnE script - the script
// parser used by the engine rejects that form outright and the whole file then
// fails to load, which silently disables every trigger in it. Every risky step
// below is null-guarded instead.
var mmBuilt:Bool = false;
function mmEnsureBuilt() {
	if (mmBuilt) return;
	mmBuilt = true; // set first so a partial failure cannot loop forever
	mmBuildAllStars();
	mmAllStarsInit();
}

function postCreate() {
	mmEnsureBuilt();
	if (iconP2 != null) iconP2.alpha = 1;
}

// --------------------------------------------------------------------------
// The trigger itself
// --------------------------------------------------------------------------
function onEvent(event) {
	if (event.event.name == "Camera Movement") {
		var t:Int = Std.parseInt(Std.string(event.event.params[0]));
		if (t != null) mmTarget = t;
		return;
	}
	if (event.event.name != "Triggers Universal") return;
	var group:Int = Std.parseInt(Std.string(event.event.params[0]));
	if (group == null) group = 0;
	var raw:String = (event.event.params.length > 1) ? Std.string(event.event.params[1]) : "";
	var val:Int = Std.parseInt(raw);
	if (val == null) val = 0;
	// Recover if the stage script's postCreate never got to run (the overlays
	// and the per-act sprite lists have to exist before any act handler runs).
	mmEnsureBuilt();

	// WARNING: the act handlers are named mmActNTrig, NOT mmActN. mmAct1..mmAct4
	// are the *sprite lists* (assigned in mmBuildAllStars). HScript keeps
	// functions and variables in one namespace, so calling these mmAct2/3/4
	// meant the list assignment silently overwrote the handler and every
	// act 2/3/4 trigger became a no-op ("Cannot call [object]").
	switch (group) {
		case 0: mmAct2Intro(val);
		case 1: mmAct1Intro(val);
		case 2: mmAct2Trig(val);
		case 3: mmAct3Trig(val);
		case 4: mmAct4Trig(val);
		case 5: mmSwitchIcon(raw);
		case 6: mmGameOverChar(val);
		default: mmLog("trigger: unhandled group " + group + " (value " + val + ")");
	}
}

// --------------------------------------------------------------------------
// Character-atlas preload
// --------------------------------------------------------------------------
// The mod's characters each live in their own sparrow atlas; the first use of
// one decodes the PNG + parses the XML in a single frame. Doing that inside an
// act transition is what made the transition, and each character appearing,
// stutter. `FunkinSprite.loadSprite` resolves its frames through
// `Paths.getFrames(path)`, which caches by path in `Paths.tempFramesCache` - so
// loading an atlas once up front makes the later `new Character()` cheap: the
// swap reuses the cached frames instead of decoding anything.
//
// It has to happen during the song's own loading phase, not during play. One
// atlas is around a second of decode, and the earlier timer-driven version (11
// loads spread across the first ~18 seconds of the song) was just as audible as
// the mid-transition stalls it was meant to remove. So mmPreloadAll() runs at
// SCRIPT LOAD - inside PlayState creation, before the countdown.
//
// DO NOT time anything in here with `Date`. `Date` is NOT a variable in a stage
// script: the engine logs `Unknown variable: Date`, the call aborts, and because
// the timing was the FIRST line of mmPreloadAll the entire preload silently
// became a no-op - which is why every swap logged `CC: atlas cached=false` and
// the transitions kept stalling. The per-atlas `preload:` lines plus the
// `CC: atlas cached=` line at each swap are the acceptance test instead.
var mmPreloadChars:Array<String> = ["omega", "bf_behind", "lg2", "w4r", "bfASsad", "gx",
	"bf_ultrafinale", "bf_ultrafinale2", "bf_ultrafinale3", "mario_ultra2", "mario_ultra3"];

// The image a character's XML points at (`sprite="..."`). This is the same
// value the preload caches under and the one `FunkinSprite.loadSprite` later
// asks `Paths.getFrames` for, which is what makes the cache hit work.
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
	// Exactly the call Character's own loader makes, so the cache key matches.
	Paths.getFrames(img, true);
}

// Same, for an atlas that is created lazily mid-song: the act 4 floaters decode
// their sheet on the first spawn, i.e. during the finale. Called without the
// optional second argument so it mirrors mmSpawnFloater's own call verbatim.
function mmPreloadAtlas(key:String) {
	if (!Paths.framesExists(key)) { mmLog("preload: no atlas at " + key); return; }
	Paths.getFrames(key);
}

function mmPreloadAll() {
	for (name in mmPreloadChars) mmPreloadChar(name);
	mmPreloadAtlas("mario/allfinal/act4/floating objects");
}

function mmAct1Intro(v:Int) {
	if (v == 1) {
		if (camHUD != null) camHUD.visible = false;
		mmBlack.alpha = 1;
		mmIntro1.alpha = 1;
		mmIntro1.animation.play("idle");
	} else if (v == 2) {
		mmFlash(FlxColor.RED, 0.8);
		mmFog1.visible = true;
		if (camHUD != null) camHUD.visible = true;
		mmBlack.alpha = 0;
		mmIntro1.alpha = 0;
		mmResync();
	}
}

function mmAct2Intro(v:Int) {
	if (v == 0) {
		mmIntro2.animation.play("idle");
		mmIntro2.visible = true;
		mmIntro2.alpha = 0;
		FlxTween.tween(mmIntro2, {alpha: 1}, 0.1);
		FlxTween.tween(mmIntro2.scale, {x: 0.01}, 3, {ease: FlxEase.expoOut});
		FlxTween.tween(mmIntro2.scale, {y: 0.01}, 3, {ease: FlxEase.expoOut});
		FlxTween.tween(mmIntro2, {y: mmIntro2.y - 400}, 3, {ease: FlxEase.circOut});
		FlxTween.tween(mmIntro2, {angle: 5}, 3, {ease: FlxEase.expoOut});
	} else if (v == 1) {
		FlxTween.tween(mmIntro2, {alpha: 0}, 0.6);
	} else if (v == 2) {
		mmEyes.visible = true;
		mmEyes.alpha = 1;
		mmEyes.animation.play("idle");
		FlxTween.tween(mmEyes.scale, {x: 1.8}, 0.8, {ease: FlxEase.expoIn});
		FlxTween.tween(mmEyes.scale, {y: 1.8}, 0.8, {ease: FlxEase.expoIn});
		FlxTween.tween(mmEyes, {x: mmEyes.x - 185}, 0.8, {ease: FlxEase.expoIn});
		FlxTween.tween(mmEyes, {y: 120}, 0.8, {ease: FlxEase.circOut});
	} else if (v == 3) {
		FlxTween.tween(mmBlack, {alpha: 0}, 0.7, {ease: FlxEase.expoOut});
		FlxTween.tween(mmEyes, {alpha: 0}, 0.2, {ease: FlxEase.expoOut});
		FlxTween.tween(mmFog2, {alpha: 0.7}, 0.7, {ease: FlxEase.expoOut});
		mmEyes.visible = false;
		mmIntro2.visible = false;
		if (camHUD != null) camHUD.visible = true;
	}
}

function mmAct2Trig(v:Int) {
	switch (v) {
		case 0:
			// Everything in this case happens inside a single frame, so the order
			// below is only about surviving a failure: reveal the act 2 stage first,
			// then swap the characters, then run the (engine-internal, reflection
			// based) vocal resync LAST. The source calls resyncVocals() first, and when
			// that call failed the whole transition used to vanish along with it.
			mmVis(mmAct1, false);
			mmFog1.visible = false;
			if (camHUD != null) camHUD.alpha = 0;
			mmBlack.alpha = 1;
			act2BFPipe.visible = true; // the pipe GF comes out of: show it with the stage
			mmVis(mmAct2, true);
			mmSky.visible = true;
			mmFog2.visible = true;
			mmFog2.alpha = 0;
			// Source's draw-order reshuffle (PlayState case 2/0, 9848-9849):
			// insert(indexOf(act2Sky) + 1, dadGroup) and insert(indexOf(act2BGGroup)
			// + 1, gfGroup) - the sky and the opponent sit *behind* the act 2 pipe
			// stack, GF just in front of it but behind the yoshi / BF-pipe layer.
			// mmSky is a world sprite, so it can go behind the pipe inside the world
			// layer; dad and GF are characters and the state draws every world sprite
			// before every character, so for them the back of the character band is
			// the closest reachable slot (dad first, so GF stays in front of him).
			if (mmSky != null) {
				remove(mmSky);
				mmInsertInWorld(act2PipesFar, mmSky, 0);
			}
			var d20 = mmDad();
			var g20 = mmGf();
			if (d20 != null) { remove(d20); mmInsertBehindCharacters(d20); }
			if (g20 != null) { remove(g20); mmInsertBehindCharacters(g20); }
			mmChangeChar(1, "omega");
			mmChangeChar(0, "bf_behind");
			// Source writes the *sprite* here (`dad.x = 320`), which is a world position.
			// Resolved again after the swap: omega is not the object the `dad` global
			// still names, so the old `dad.x = 320` write went nowhere.
			var nd20 = mmDad();
			if (nd20 != null) { mmPlaceWorld(nd20, 320, -130); nd20.scrollFactor.set(0.5, 0.5); }
			var ng20 = mmGf();
			if (ng20 != null) ng20.visible = false;
			mmResync();
		case 1:
			// Source 2/1 'luigi': the girlfriend slot becomes lg2 (Luigi rides up in
			// her place), she is shown at (200, 670) and rises 800px over 2s
			// circOut, together with the background pipe (act2LPipe, the same tween).
			mmChangeChar(2, "lg2");
			// The 800px rise has to be applied to the character mmChangeChar just put in
			// the girlfriend strumline. Aiming it at the `gf` global moved the object it
			// had already removed, so lg2 stayed put while the pipe rose - which is
			// exactly the "girlfriend is not dragged out of the pipe" that this beat is
			// supposed to sell.
			var g21 = mmGf();
			if (g21 != null) {
				g21.visible = true;
				// Source: gfGroup.x = 200; gfGroup.y = 670 (a group write).
				mmPlaceGroup(g21, 200, 670);
				g21.scrollFactor.set(0.9, 0.9);
				FlxTween.tween(g21, {y: g21.y - 800}, 2, {ease: FlxEase.circOut});
			}
			if (mmIconLG != null) {
				// Source (case 2/1) parks the extra icons around the opponent's icon
				// and slides them in over the next two triggers.
				var ipy:Float = (iconP2 != null) ? iconP2.y : 0;
				var off:Float = mmDownScroll() ? -250 : 250;
				mmIconLG.y = ipy;
				mmIconW4.y = ipy + 75 + off;
				mmIconY0.y = ipy - 75 + off;
				mmIconLG.visible = true;
			}
			if (iconP2 != null) iconP2.visible = false;
			FlxTween.tween(act2LPipe, {y: act2LPipe.y - 800}, 2, {ease: FlxEase.circOut});
			// Source: tween(act2Sky.velocity, {x: 10}, 0.8, quadInOut).
			mmSkyTo(10, 0.8, FlxEase.quadInOut);
		case 2:
			mmChangeChar(1, "w4r");
			// Source (case 2/2): remove(dadGroup); insert(indexOf(gfGroup)+1, dadGroup)
			// -> the opponent moves in front of GF but stays behind the yoshi and
			// the BF pipe.
			var d22 = mmDad();
			var g22 = mmGf();
			if (d22 != null && g22 != null) {
				remove(d22);
				insert(members.indexOf(g22) + 1, d22);
			}
			if (d22 != null) {
				mmPlaceWorld(d22, -370, 910); // source writes the sprite (world space)
				d22.visible = true;
				d22.scrollFactor.set(0.95, 0.95);
				FlxTween.tween(d22, {y: d22.y - 800}, 2, {ease: FlxEase.circOut});
			}
			if (mmIconW4 != null) {
				mmIconW4.visible = true;
				FlxTween.tween(mmIconW4, {y: mmIconW4.y + (mmDownScroll() ? 230 : -280)}, 2, {ease: FlxEase.circOut});
			}
			FlxTween.tween(act2WPipe, {y: act2WPipe.y - 800}, 2, {ease: FlxEase.circOut});
		case 3:
			funnylayer0.visible = true;
			funnylayer0.x = 850; funnylayer0.y = 1000;
			if (mmIconY0 != null) {
				mmIconY0.visible = true;
				FlxTween.tween(mmIconY0, {y: mmIconY0.y + (mmDownScroll() ? 280 : -230)}, 2, {ease: FlxEase.circOut});
			}
			// Source: tween(act2Sky.velocity, {x: -700}, 1.6, cubeOut).
			mmSkyTo(-700, 1.6, FlxEase.cubeOut);
			FlxTween.tween(funnylayer0, {y: funnylayer0.y - 800}, 2, {ease: FlxEase.circOut});
			FlxTween.tween(act2YPipe, {y: act2YPipe.y - 800}, 2, {ease: FlxEase.circOut});
		case 4:
			FlxTween.tween(mmBlack, {alpha: 1}, 0.8, {ease: FlxEase.quadInOut});
			FlxTween.tween(mmFog2, {alpha: 0}, 0.8, {ease: FlxEase.quadInOut});
			if (camHUD != null) {
				FlxTween.tween(camHUD, {alpha: 0}, 3.6, {ease: FlxEase.quadInOut});
				FlxTween.tween(camHUD, {angle: 15}, 3.6, {ease: FlxEase.quadIn});
				FlxTween.tween(camHUD, {y: 500}, 3.6, {ease: FlxEase.quadIn});
			}
		case 5:
			// omega scream: the source plays dad's 'scream', stops following the
			// characters for 1.1s, shakes the screen 0.2s later and pushes the camera
			// down. The camera half lives in MMcamera.
			var d25 = mmDad();
			if (d25 != null) d25.playAnim("scream", true);
			// Source: extraTimer(0.2) -> triggerEventNote('Screen Shake', '0.8, 0.01', '').
			// This fork's handler calls `camGame.shake(intensity, duration)` with the
			// two values in that order - i.e. shake(0.01, 0.8), not the usual
			// Flixel (duration, intensity) - so reproduce the literal call. It also
			// shakes camHUD/camEst, but the chart passes an empty second value, whose
			// parse yields 0 and is skipped there.
			new FlxTimer().start(0.2, function(tmr) { FlxG.camera.shake(0.01, 0.8); });
		case 6:
			// camera pan for the bow - handled by MMcamera
		case 7:
			var d27 = mmDad();
			if (d27 != null) d27.visible = false;
		case 8:
			FlxTween.tween(mmSky, {x: mmSky.x - 75}, 0.35, {ease: FlxEase.quadOut});
			mmWhiteFlash.color = FlxColor.WHITE;
			mmWhiteFlash.visible = true;
			mmWhiteFlash.alpha = 1;
			FlxTween.tween(mmWhiteFlash, {alpha: 0}, 0.35, {ease: FlxEase.quadInOut});
	}
}

function mmAct3Trig(v:Int) {
	switch (v) {
		case 0:
			mmChangeChar(0, "bfASsad");
			mmChangeChar(1, "gx");
			if (mmIconLG != null) {
				mmIconLG.visible = false;
				mmIconW4.visible = false;
				mmIconY0.visible = false;
			}
			// Source (10005-10006): remove(act3BGGroup); insert(indexOf(dadGroup) - 1,
			// act3BGGroup) -> the whole act 3 back layer moves in front of every other
			// back layer and directly behind the characters. act3BFPipe and act3Fog are
			// members of that group in the source too (3869/3878), so the pipe travels
			// with the backdrop rather than being covered by it, and act3Spotlight is
			// not in the group at all - the source adds it to the foreground switch
			// (4581), and postCreate already parks it in the fg band above the
			// characters, so this insert lands *below* it, as the source does.
			// The sprites are world sprites here, so each has to leave the world layer
			// when it moves in: a sprite left in both groups is drawn and *updated*
			// twice (act3Stat's static and act3UltraPupils' idle would run at double
			// speed) and the copy left behind would sit under every other stage sprite,
			// which is the very pile the source's reshuffle is undoing.
			var d30 = mmDad();
			if (d30 != null) {
				for (s in mmAct3BG) { mmLeaveWorld(s); remove(s); }
				for (s in mmAct3BG) insert(members.indexOf(d30), s);
			}
			mmVis(mmAct3, true);
			act3Spotlight.visible = true;
			act3Spotlight.alpha = 0.7;
			act3UltraHead2.alpha = 0.00001;
			mmFog3.visible = true;
			mmFog3.alpha = 0;
			FlxTween.tween(mmFog3, {alpha: 0.7}, 1, {ease: FlxEase.quadIn});
			FlxTween.tween(mmBlack, {alpha: 0}, 1, {ease: FlxEase.quadOut});
			mmVis(mmAct2, false);
			mmSky.visible = false;
			funnylayer0.visible = false;
			var g30 = mmGf();
			if (g30 != null) g30.visible = false;
			// Source writes the *sprite* here (`dad.x = -1400`), which is a world position.
			// d30 is gx, the character mmChangeChar swapped in at the top of this case.
			if (d30 != null) { mmPlaceWorld(d30, -1400, -1310); d30.scrollFactor.set(1, 1); }
			var b30 = mmBf();
			if (b30 != null) b30.playAnim("cut", true);
			mmResync();
		case 1:
			var d31 = mmDad();
			if (d31 != null) FlxTween.tween(d31, {y: d31.y + 900}, 1.6, {ease: FlxEase.quadInOut});
			FlxTween.tween(act3Spotlight, {alpha: 0}, 3.2, {ease: FlxEase.quadInOut});
		case 2:
			// camera reset - handled by MMcamera
		case 3:
			act3UltraHead1.visible = true;
			act3UltraHead1.animation.play("sing");
		case 4:
			// The head design switch. Source (case 3/4) does exactly this and nothing
			// earlier; the beatHit is what then leaves the 'change' pose alone at beat
			// 808 and moves the torso to 'idle-alt' at beat 812.
			act3UltraHead1.visible = false;
			act3UltraHead2.alpha = 1;
			act3UltraHead2.animation.play("sing");
			act3UltraBody.animation.play("change", true);
		case 5:
			if (camHUD != null) {
				camHUD.angle = 0;
				camHUD.y = 0;
				FlxTween.tween(camHUD, {alpha: 1}, 2.4, {ease: FlxEase.quadInOut});
			}
			if (iconP2 != null) iconP2.visible = true;
		case 6:
			act3UltraPupils.visible = false;
		case 7:
			act3UltraHead2.animation.play("laugh", true);
			if (camHUD != null) FlxTween.tween(camHUD, {alpha: 0}, 1, {ease: FlxEase.quadInOut});
			FlxTween.tween(camGame, {zoom: 0.6}, 1.2, {ease: FlxEase.quadInOut, onComplete: function(twn) {
				FlxTween.tween(mmFog3, {alpha: 0}, 0.35, {ease: FlxEase.quadInOut});
				FlxTween.tween(camGame, {zoom: 8}, 0.35, {ease: FlxEase.expoIn, onComplete: function(twn2) {
					mmBlack.alpha = 1;
				}});
			}});
	}
}

function mmAct4Trig(v:Int) {
	switch (v) {
		case 0:
			mmVis(mmAct3, false);
			mmFog3.visible = true;
			// Source (case 4/0) only reveals the act 4 back group and the first
			// pipe; the memories, lightning and spotlight all arrive later.
			mmVis(mmAct4, false);
			mmVis(mmAct4BG, true);
			if (act4Pipe1 != null) act4Pipe1.visible = true;
			// Same order as the source: change characters, then move the groups
			// (mmChangeChar keeps the existing placement across the swap).
			mmChangeChar(0, "bf_ultrafinale");
			mmChangeChar(1, "mario_ultra2");
			var d40 = mmDad();
			if (d40 != null) {
				d40.visible = true;
				// Source: dadGroup.x = 100; dadGroup.y = 100 (a group write).
				mmPlaceGroup(d40, 100, 100);
				// Source (10164): remove(dadGroup); insert(indexOf(act4Floaters)+1,
				// dadGroup) -> the opponent stands in front of the act 4 back layer and of
				// the floating objects, but behind the finale pipes. act4Pipe1 is a stage
				// sprite in the port, so he goes to the back of the character band: above
				// the whole world layer, which is as far in as a character can get.
				remove(d40);
				mmInsertBehindCharacters(d40);
			}
			var b40 = mmBf();
			// Source: boyfriendGroup.x = 810; boyfriendGroup.y = -75 (a group write).
			// This is the one that has to be canonical, or the 4/2 and 4/6 swaps land
			// on the wrong side of the pipe (see mmPlaceGroup).
			if (b40 != null) mmPlaceGroup(b40, 810, -75);
			// Source parks the act 4 icons where the act 2/3 ones ended up and puts
			// them in the HUD list just before the opponent's icon.
			var i4y:Float = (mmIconY0 != null) ? mmIconY0.y : 0;
			if (mmDownScroll() && mmIconW4 != null) i4y = mmIconW4.y;
			if (mmIconA4 != null) {
				mmIconA4.y = i4y;
				mmIconA4.visible = false;
				if (iconP2 != null && members.indexOf(iconP2) >= 0) {
					remove(mmIconA4);
					insert(members.indexOf(iconP2), mmIconA4);
				}
			}
			if (mmIconA42 != null) {
				if (mmIconA4 != null) {
					mmIconA42.y = mmIconA4.y + (mmDownScroll() ? -90 : 70);
					remove(mmIconA42);
					insert(members.indexOf(mmIconA4), mmIconA42);
				}
				mmIconA42.visible = false;
			}
			mmStartFloaters();
			mmResync();
		case 1:
			FlxTween.tween(iconP1, {alpha: 0}, 1.6, {ease: FlxEase.quadInOut});
			FlxTween.tween(iconP2, {alpha: 0}, 1.6, {ease: FlxEase.quadInOut});
			FlxTween.tween(healthBar, {alpha: 0}, 1.6, {ease: FlxEase.quadInOut});
			FlxTween.tween(healthBarBG, {alpha: 0}, 1.6, {ease: FlxEase.quadInOut});
			FlxTween.tween(mmBlack, {alpha: 1}, 1.6, {ease: FlxEase.quadInOut});
			FlxTween.tween(camGame, {zoom: 1.5}, 1.6, {ease: FlxEase.quadInOut});
		case 2:
			if (mmIconA4 != null) mmIconA4.visible = false;
			// Source: act4BGGroup.visible = false; act4Pipe1.visible = false;
			// act4BG2Group.visible = true; dad.visible = false;
			mmVis(mmAct4BG, false);
			if (act4Pipe1 != null) act4Pipe1.visible = false;
			mmVis(mmAct4BG2, true);
			var d42 = mmDad();
			if (d42 != null) d42.visible = false;
			mmSpawnNum = 1;
			if (act4Pipe2 != null) act4Pipe2.visible = true;
			if (act4Spotlight != null) {
				act4Spotlight.visible = true;
				// Source (10200): insert(members.indexOf(boyfriendGroup)+1, act4Spotlight)
				// - the source never added the spotlight before this point, so the insert
				// is its first membership and it ends up just in front of BF. It is a
				// stage sprite here, so leave the world layer as well, or it is drawn and
				// updated twice and the leftover copy stays behind the characters.
				var b42 = mmBf();
				if (b42 != null) {
					mmLeaveWorld(act4Spotlight);
					remove(act4Spotlight);
					insert(members.indexOf(b42) + 1, act4Spotlight);
				}
			}
			for (o in mmFloaters) o.color = 0xff4e4e4e;
			mmChangeChar(0, "bf_ultrafinale2");
			FlxTween.tween(mmBlack, {alpha: 0}, 0.8, {ease: FlxEase.quadInOut});
			// The modchart's 4/2 transformX: BF's strums to the middle and the
			// opponent's off screen for the whole solo (see mmSetSolo).
			mmSetSolo(true);
		case 3:
			FlxTween.tween(act4Spotlight, {alpha: 1}, 20, {ease: FlxEase.linear});
			// Source (case 4/3) uses two *separate* tweens: the drift lasts 9s linear
			// while the fade-in reaches 0.4 in 4.5s quadIn and only then fades out over
			// 4.5s quadOut. Merging alpha into the 9s drift made the memory stay
			// barely visible for the whole of it.
			FlxTween.tween(act4Memory1, {y: act4Memory1.y - 300}, 9, {ease: FlxEase.linear});
			FlxTween.tween(act4Memory1, {alpha: 0.4}, 4.5, {ease: FlxEase.quadIn, onComplete: function(twn) {
				FlxTween.tween(act4Memory1, {alpha: 0}, 4.5, {ease: FlxEase.quadOut});
			}});
		case 4:
			FlxTween.tween(act4Memory2, {y: act4Memory2.y + 300}, 9, {ease: FlxEase.linear});
			FlxTween.tween(act4Memory2, {alpha: 0.4}, 4.5, {ease: FlxEase.quadIn, onComplete: function(twn) {
				FlxTween.tween(act4Memory2, {alpha: 0}, 4.5, {ease: FlxEase.quadOut});
			}});
		case 5:
			FlxTween.tween(camGame, {zoom: 0.5}, 0.8, {ease: FlxEase.quadInOut, onComplete: function(twn) {
				mmSpawnNum = 4;
				FlxTween.tween(camGame, {zoom: 1.2}, 0.8, {ease: FlxEase.cubeIn});
			}});
		case 6:
			// The modchart's 4/6 reset (and the lightning) go first: the strums
			// snap back to their real X and the diagonal line comes up even if
			// anything later in this case fails.
			mmSetSolo(false);
			mmLightningOn();
			for (o in mmFloaters) o.color = FlxColor.WHITE;
			mmFlash(FlxColor.WHITE, 0.8);
			mmChangeChar(0, "bf_ultrafinale3");
			mmChangeChar(1, "mario_ultra3");
			var b46 = mmBf();
			if (b46 != null) { b46.x += 270; b46.y += 225; }
			var d46 = mmDad();
			if (d46 != null) d46.x += 250;
			// Source: act4BG2Group.visible = false; act4Spotlight.visible = false;
			// add(act4Lightning) (the lightning goes to the very front);
			// act4BGGroup.visible = true.
			mmVis(mmAct4BG2, false);
			if (act4Pipe2 != null) act4Pipe2.visible = false;
			if (act4Spotlight != null) act4Spotlight.visible = false;
			mmVis(mmAct4BG, true);
			var d46b = mmDad();
			if (d46b != null) d46b.visible = true;
			if (iconP1 != null) iconP1.alpha = 1;
			if (iconP2 != null) iconP2.alpha = 1;
			if (healthBar != null) healthBar.alpha = 1;
			if (healthBarBG != null) healthBarBG.alpha = 1;
			act4Ripple.x += 300; act4Ripple.y += 75;
			act4Stat.x += 150; act4Stat.y += 75;
		case 7:
			mmFlash(FlxColor.RED, 1);
			mmWhiteFlash.color = FlxColor.RED;
			mmWhiteFlash.visible = true;
			mmWhiteFlash.alpha = 1;
			if (camHUD != null) camHUD.visible = false;
			var d47 = mmDad();
			if (d47 != null) d47.visible = false;
			var b47 = mmBf();
			if (b47 != null) b47.visible = false;
			mmFog3.visible = false;
			// Source hides act4BGGroup, the floaters and the lightning, but keeps
			// the death sprite, which it re-adds to the very front.
			mmVis(mmAct4BG, false);
			mmVis(mmAct4BG2, false);
			// Source (case 4/7): act4Floaters.visible = false. The spawner keeps
			// running through the death scene, so the flag has to hide the objects it
			// keeps making as well - otherwise the finale debris drifts across the
			// red death screen and gets chopped off at the screen edge.
			mmFloatersHidden = true;
			for (o in mmFloaters) o.visible = false;
			if (act4Lightning != null) act4Lightning.visible = false;
			if (act4Spotlight != null) act4Spotlight.visible = false;
			if (act4DeadBF != null) {
				act4DeadBF.visible = true;
				act4DeadBF.animation.play("die");
				act4DeadBF.alpha = 1;
				// Source (10282-10283): remove(act4DeadBF); add(act4DeadBF) -> the death
				// sprite moves to the very front, over the game-over art.
				mmMoveToFront(act4DeadBF);
			}
			mmGameOver.alpha = 0;
			mmGameOver.visible = true;
		case 8:
			FlxTween.tween(camGame, {zoom: 0.1}, 7.2, {ease: FlxEase.quadIn});
			FlxTween.tween(act4DeadBF, {alpha: 0}, 4.8, {ease: FlxEase.quadIn});
		case 9:
			FlxTween.tween(mmGameOver, {alpha: 1}, 4.8, {ease: FlxEase.quadInOut});
		case 10:
			FlxTween.tween(mmBlack, {alpha: 1}, 4.8, {ease: FlxEase.quadInOut});
		case 11:
			mmSpawnNum = 3;
		case 12:
			mmSpawnNum = 2;
		case 13:
			FlxTween.tween(camGame, {zoom: 0.7 + 0.4}, 0.8, {ease: FlxEase.cubeIn});
		case 14:
			mmIntro4.scale.set(0.01, 0.01);
			mmIntro4.animation.play("anim", true);
			mmIntro4.visible = true;
			FlxTween.tween(mmIntro4, {alpha: 1}, 0.5, {ease: FlxEase.sineOut});
			FlxTween.tween(mmIntro4.scale, {x: 1, y: 1}, 0.8, {ease: FlxEase.sineOut, onComplete: function(twn) {
				FlxTween.tween(mmIntro4.scale, {x: 1.2, y: 1.2}, 10, {ease: FlxEase.quadInOut});
			}});
		case 15:
			FlxTween.tween(mmBlack, {alpha: 0}, 0.7, {ease: FlxEase.quadOut});
			FlxTween.tween(mmFog3, {alpha: 0.7}, 0.7, {ease: FlxEase.quadOut});
			FlxTween.tween(mmIntro4, {alpha: 0}, 0.7, {ease: FlxEase.quadOut});
			if (camHUD != null) camHUD.alpha = 1;
	}
}

function mmSwitchIcon(name:String) {
	if (mmIconA4 == null) return;
	mmIconA4.visible = true;
	mmIconA4.animation.play(name, true);
	mmIconA4.angle = 0;
	if (mmIconA42 != null) mmIconA42.angle = 0;
	FlxTween.tween(mmIconA4, {angle: mmIconA4.angle + 360}, 0.25, {ease: FlxEase.backOut});
	if (mmIconA42 != null) FlxTween.tween(mmIconA42, {angle: mmIconA42.angle + 360}, 0.25, {ease: FlxEase.backOut});
	if (mmIconA42 != null) mmIconA42.visible = (name == "peachex");
}

function mmGameOverChar(v:Int) {
	// 10351-10353: the per-act game-over character. The fork writes Psych's
	// global `GameOverSubstate.characterName`; Codename asks the dying character
	// for its own `gameOverCharacter` (`PlayState.gameOver()`:
	// `deathCharID.getDefault(charToUse.gameOverCharacter)`), so BF carries it -
	// the same hook meatworld.hx's mmGameOver and luigiout.hx's case 9 use. The
	// act's default (`bfASdeath`, the source's create() line 3680) comes from
	// songs/MMcamera.hx's game-over table; this is the group-6 switch above it.
	if (boyfriend == null) return;
	boyfriend.gameOverCharacter = (v == 0) ? "bfASdeath" : "gfASdeath";
}

// --------------------------------------------------------------------------
// Per-frame: scrolling backdrop, icons
// --------------------------------------------------------------------------
function update(elapsed:Float) {
	if (mmSky != null) {
		if (mmSky.visible) {
			mmSky.x += mmSkyVelObj.v * elapsed;
			if (mmSky.x > 0) mmSky.x -= mmSky.width;
			if (mmSky.x < -mmSky.width * 2) mmSky.x += mmSky.width;
		}
	}

	// iconLG/iconW4/iconY0 hug the opponent icon (source update()).
	if (iconP2 != null && mmIconLG != null && mmIconLG.visible) {
		var hp = (PlayState.instance != null) ? Reflect.getProperty(PlayState.instance, "health") : null;
		if (hp == null) hp = 1;
		mmIconLG.x = iconP2.x;
		mmIconW4.x = iconP2.x - 75;
		mmIconY0.x = iconP2.x - 75;
		mmIconLG.scale.set(iconP2.scale.x, iconP2.scale.y);
		mmIconW4.scale.set(iconP2.scale.x, iconP2.scale.y);
		mmIconY0.scale.set(iconP2.scale.x, iconP2.scale.y);
		var a = hp < 1.6 ? "win" : "lose";
		mmIconLG.animation.play(a);
		mmIconW4.animation.play(a);
		mmIconY0.animation.play(a);
	}

	if (iconP2 != null && mmIconA4 != null && mmIconA4.visible) {
		mmIconA42.x = iconP2.x - 50;
		mmIconA4.x = iconP2.x - 50;
		mmIconA4.scale.set(iconP2.scale.x - 0.2, iconP2.scale.y - 0.2);
		mmIconA42.scale.set(iconP2.scale.x - 0.2, iconP2.scale.y - 0.2);
		if (mmIconA4.alpha > 0.1) {
			mmIconA4.alpha -= elapsed;
			mmIconA42.alpha = mmIconA4.alpha;
		}
	}
}

// --------------------------------------------------------------------------
// Notes: Yoshi Note / AS Bud Note drive the stage Yoshi
// --------------------------------------------------------------------------
// Source keeps the "go back to idle" timers in an array
// (`funnyTimers`) and cancels the pending ones before scheduling a new one
// (PlayState.hx:8489 and 8550), but only while a sing animation is actually up.
// Without that, an earlier note's 0.5s timer fires in the middle of a later
// phrase and snaps yoshi back to idle - which is what made his singing look
// broken during the yoshi-only section.
var mmFunnyTimers:Array<FlxTimer> = [];

function onNoteHit(event) {
	// Source beat-zoom guard: on allfinal the engine's every-4-beats camera zoom
	// bump is skipped once the act 4 death flash has turned red
	// (`if (act2WhiteFlash.color != FlxColor.RED)` around `FlxG.camera.zoom +=
	// 0.015`). `preventCamZooming` is the engine's own switch for that bump.
	if (mmWhiteFlash != null && mmWhiteFlash.visible && mmWhiteFlash.color == FlxColor.RED) {
		event.preventCamZooming();
	}
	if (event.noteType != "Yoshi Note" && event.noteType != "AS Bud Note") return;
	if (funnylayer0 == null) return;
	funnylayer0.animation.play(mmSingName(event.direction), true);
	switch (event.direction) {
		case 0: funnylayer0.offset.x = 59; funnylayer0.offset.y = -5;
		case 1: funnylayer0.offset.x = 33; funnylayer0.offset.y = -88;
		case 2: funnylayer0.offset.x = -22; funnylayer0.offset.y = 74;
		case 3: funnylayer0.offset.x = -120; funnylayer0.offset.y = 39;
	}
	var ca = funnylayer0.animation.curAnim;
	if (ca != null && ca.name != "idle") {
		for (t in mmFunnyTimers) if (t != null) t.cancel();
		mmFunnyTimers = [];
	}
	mmFunnyTimers.push(new FlxTimer().start(0.5, function(tmr) {
		funnylayer0.animation.play("idle");
		funnylayer0.offset.x = 0;
		funnylayer0.offset.y = 0;
	}));
}

// --------------------------------------------------------------------------
// Runs at SCRIPT LOAD (see the preload section above). Keep this at the very
// end of the file: HScript executes top-level statements in order, so it must
// come after the declarations and functions it uses.
// --------------------------------------------------------------------------
mmPreloadAll();
// === end MM stage triggers ===
