

// === MM stage triggers (auto) ===
import flixel.text.FlxText;

// 'Triggers MARIO SING AND GAME RYTHM 9' - ported from PlayState.hx (case
// 'Triggers MARIO SING AND GAME RYTHM 9', 10468-10496).
//
// Only mario-sing-and-game-rythm-9 runs on this stage, and its chart sends these
// beats as 'Triggers Universal 1' with the spotlight animation's name in value2
// ('full' / 'none' / 'left' / 'double' / 'right'), so both event names are
// accepted. The case has no camera writes - the camera half of this song's
// chart is the ordinary per-section camera.
//
// postCreate also picks up the stage's load-time pieces the XML could not
// express:
//   - `pixelLights` is `add()`ed in the source's *foreground* switch (4459), i.e.
//     after the character groups - it is what lights the fighters up, so the XML
//     (which puts every sprite below them) has to lift it out of the world layer,
//     the same move exesequel.hx makes for its SS_foreground platform.
//   - `bgstars` scrolls at creation (`eventTweens.push(FlxTween.tween(bgstars,
//     {x: bgstars.x - 1388}, 30, {type: LOOPING}))`, 2076).
//   - `titleNES` (2098-2111) is this stage's own song-title card: a 4-frame NES
//     strip on camHUD, built invisible and driven by 'Show Song' (see onEvent).
//
// The stage's whole presentation is the somari "handheld screen": the source
// resizes the game window to 800x600, scales the entire root 1.8x and shifts
// every camera up-left (911-955), then draws the ring counter and the score on
// camHUD (2113-2131, 4929-4937), the per-frame ring/score text (7434-7441), the
// ring loss/hit rules (15210-15235, 15391-15410, 15654-15659) and the two
// `blackHUD` bars that frame the small screen on camEst (5706-5722).
//
// The window/scale/camera half is reproduced here in postCreate(); the bars sit
// on a camera of this port's own, placed in camEst's slot (between camGame and
// camHUD - see mmEst). The ring *system* (the health drain, the 'ringloss' and
// 'ringhit' sounds, BF's 'hit' animation) lives here because a Ring Note is the
// only way to gain rings, but the note script (data/notes/Ring Note.hx) is what
// plays 'ringhit' on the hit, so the stage script only counts.
//
// Not ported: `Main.fpsVar.visible = false`, `specialGameOver = true` (the
// special game-over cinematic is stage-independent engine state), `stream = 1`
// and case 0's `if (!paused)` guard - a Codename script has no pause flag. Case
// 0 is ported for completeness even though the chart never sends it (the chart
// uses 1 only).
//
// The stage's HUD is reduced to its own two texts: 5488-5494 sets `timeTxt`,
// `timeBarBG`, `timeBar`, `iconP2`, `iconP1`, `customHB` and `healthBar`
// invisible on somari (see postCreate). Of those, `timeTxt`/`timeBarBG`/
// `timeBar`/`customHB` do not exist in Codename, so only the icons and the two
// bars are switched off - `healthBarBG` too, which the source happens never to
// show on *any* stage (it is created `visible = false` at 5208 and only its
// tracker, `healthBar`, is the visible bar) while Codename's is visible by
// default. data/stages/endstage.hx hides the same set for the same reason.
//
// Also not ported, because the source never uses them: `mario/Somari/gbalay`
// (760x428, a purple Game Boy Advance shell with a transparent 456x305 screen
// window) and `mario/Somari/starlight` (257x169). Both ship in the mod's images
// but no PlayState block, stage preload or chart mentions either name - the
// create switch above loads only somari_stag1, buildings_papu, bgstars,
// platform, image and spot (plus pixelUI/title). They are unused art, so they
// stay unused here rather than being given a position the source never had.

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
// Codename's `Stage` is not a group (`class Stage extends FlxBasic`), so
// `stage.add`/`stage.remove`/`stage.insert`/`stage.members` do not exist and
// HScript resolves them to null - calling them throws Null Function Pointer and
// aborts the rest of the handler (this postCreate used to die on the first
// `stage.remove`). `Stage.addSprite` instead puts every stage sprite straight
// into the *state's* draw list and `Stage.applyCharStuff` inserts each character
// at its marker, so a bare `members`/`add`/`insert`/`remove` here is the state's
// list and the world layer is the run of sprites below the character band.
//
// Index of the first character (the top of the world layer). The girlfriend node
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

// Move a world sprite to the top of the world layer, directly below the
// characters (the slot the source's create-switch `add()` gives it).
function mmWorldAdd(spr) {
	var w:Int = mmWorldTop();
	if (w >= 0) insert(w, spr); else add(spr);
}

// The source's bgstars reorder is a plain draw-list move (`remove(bgstars);
// insert(...)`, 10483/10490/10494) and every sprite already lives in the state's
// draw list here, so the same move happens there:
//   'none'  -> just behind `building`, its load-time slot (`insert(indexOf(
//              building) - 1, bgstars)`)
//   'full'  -> the very front of the world layer, i.e. directly under the
//              characters, which is where `insert(indexOf(pixelLights) + 1, ...)`
//              lands once pixelLights has been lifted to the state's front
//   'other' -> `insert(indexOf(building) - 2, bgstars)`; in this three-sprite band
//              that is the back of the world layer, so the stars sit behind `bg`
//              as well
function mmMoveBgStars(mode:String) {
	if (bgstars == null) return;
	remove(bgstars);
	if (mode == "full") { mmWorldAdd(bgstars); return; }
	var b:Int = (building != null) ? members.indexOf(building) : -1;
	if (b < 0) { mmWorldAdd(bgstars); return; }
	if (mode == "none") insert(b, bgstars);
	else insert(0, bgstars);
}

// `PlayState.downscroll` is a get/set property, so read it defensively (the
// same helper piracy.hx/exesequel.hx carry).
function mmDownscroll():Bool {
	if (PlayState.instance != null && Reflect.hasField(PlayState.instance, "downscroll"))
		return Reflect.field(PlayState.instance, "downscroll") == true;
	return false;
}

// Source FlxFlicker.flicker(boyfriendGroup, 3, 0.2, true): alternate visibility
// during the invulnerability window, then restore it (never leave BF hidden).
function mmFlicker(spr, duration:Float, interval:Float) {
	if (spr == null) return;
	var n:Int = Std.int(duration / interval);
	if (n < 1) n = 1;
	spr.visible = true;
	spr.alpha = 1;
	var i:Int = 0;
	new FlxTimer().start(interval, function(tmr) {
		i += 1;
		spr.visible = (i >= n) ? true : !spr.visible;
	}, n);
}

// `formatMario(num, size)` (17151): zero-pad `Math.round(num)` to `size` digits.
function mmFormatMario(num:Float, size:Int):String {
	var finalVal:String = "";
	var stringNum:String = Std.string(Math.round(num));
	var i:Int = 0;
	while (i < size - stringNum.length) {
		finalVal += "0";
		i += 1;
	}
	return finalVal + stringNum;
}

// ---------------------------------------------------------------------------
// The somari screen (PlayState.hx 911-955)
// ---------------------------------------------------------------------------
// The source turns the game into a small handheld: the window is resized to
// 800x600 with the OS window handles locked, the whole root is scaled 1.8x and
// every camera (camGame, camHUD, camEst, camOther) is moved to (-300,-210) -
// (-260 under downscroll). Everything below (the bars' own coordinates, the
// ring/score HUD's row) is authored in that shifted/scaled frame, so it has to
// be reproduced for those numbers to land where the source puts them. `Lib` and
// `window` are both guarded because neither is guaranteed to be reachable from
// a stage script.
var mmWinOgX:Int = 0;
var mmWinOgY:Int = 0;
var mmWinOgW:Int = 0;
var mmWinOgH:Int = 0;
var mmScreenOn:Bool = false;
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

// Psych's camEst is a bare `new FlxCamera()` (826) added right after camGame and
// therefore *before* camHUD (833-836), so its sprites draw above the world and
// fighters but below the notes and the HUD. Codename only has camGame and
// camHUD; its list is [camGame, camHUD], so the port's camera is slid in at
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
}

function mmSomariScreen() {
	if (mmScreenOn) return;
	mmScreenOn = true;

	// 911-931: the 800x600 window. `winx`/`winy` in the source are the window's
	// position when the state was created; a script reads them straight off the
	// window here.
	if (window != null) {
		mmWinOgX = Std.int(window.x);
		mmWinOgY = Std.int(window.y);
		mmWinOgW = Std.int(window.width);
		mmWinOgH = Std.int(window.height);
		window.fullscreen = false;
		window.maximized = false;
		window.resizable = false;
		if (mmWinOgW == 1280 && mmWinOgH == 720) window.move(mmWinOgX + 240, mmWinOgY + 60);
		else window.move(560, 240);
		window.resize(800, 600);
	}

	// 936-939: the 1.8x root scale.
	if (Lib != null && Lib.current != null) {
		Lib.current.x = 0;
		Lib.current.y = 0;
		Lib.current.scaleX = 1.8;
		Lib.current.scaleY = 1.8;
	}

	// 942-955: every camera up-left.
	var camY:Float = mmDownscroll() ? -260 : -210;
	for (cam in [camGame, camHUD, mmEst()]) {
		if (cam == null) continue;
		cam.x = -300;
		cam.y = camY;
	}
}

// ---------------------------------------------------------------------------
// The ring HUD (2113-2131, 4929-4937) and the black bars (5706-5722)
// ---------------------------------------------------------------------------
var mmRing:Int = 0;
var mmRingText = null;   // `ringcount`, camHUD
var mmRingIcon = null;   // 'mario/Somari/image' x8, camHUD
var mmScoreTxt = null;   // the somari score text (the source replaces scoreTxt)
var mmTitleNES = null;   // 'pixelUI/title' x2, camHUD (the 'Show Song' card)
var mmNoDamage:Bool = false;

// makeGraphic + `setGraphicSize(width * 10)`, on a camera: what both blackHUD
// bars are. The x position is left at 0 in the source (the bars are 4000px wide
// and cover the whole row).
function mmBlackHud(w:Int, h:Int, y:Float, cam) {
	var s = new FlxSprite().makeGraphic(w, h, FlxColor.BLACK);
	s.setGraphicSize(Std.int(s.width * 10));
	s.cameras = [cam];
	s.y = y;
	add(s);
	return s;
}

// 2098-2111: the stage's song-title card, a 4-frame NES strip (1752x46, so 438x46
// per frame). The source loads it once whole and again split, because the per-
// frame width is only known after the first load - `titleNES.width = titleNES.
// width / 4` then `loadGraphic(..., true, that, height)`. Kept exactly that way
// rather than hard-coding 438, so the two loads stay the source's. It is
// screen-centred with the source's own +25 nudge and starts invisible; 'show'
// runs 3->2->1->0 (ending on the drawn frame) and 'hide' runs 0->1->2->3 (ending
// on the blank one), which is why case 1 has to play *both* in order and never
// needs to set `visible` back to false.
function mmGetTitleNES() {
	if (mmTitleNES == null) {
		mmTitleNES = new FlxSprite();
		mmTitleNES.loadGraphic(Paths.image("pixelUI/title"));
		mmTitleNES.width = mmTitleNES.width / 4;
		mmTitleNES.loadGraphic(Paths.image("pixelUI/title"), true, Std.int(Math.floor(mmTitleNES.width)), Std.int(Math.floor(mmTitleNES.height)));
		mmTitleNES.scale.set(2, 2);
		mmTitleNES.antialiasing = false;
		mmTitleNES.visible = false;
		mmTitleNES.cameras = [camHUD];
		mmTitleNES.updateHitbox();
		mmTitleNES.screenCenter();
		mmTitleNES.x += 25;
		mmTitleNES.animation.add("show", [3, 2, 1, 0], 12, false);
		mmTitleNES.animation.add("hide", [0, 1, 2, 3], 12, false);
		add(mmTitleNES);
	}
	return mmTitleNES;
}

function onCountdown(event) {
	// `noCount = true` (2061): the source never builds its 3-2-1-GO sprites.
	event.cancelled = true;
}

function postCreate() {
	mmSomariScreen();

	// 5488-5494: this stage fights with no health bar and no icons - the only
	// things it draws on camHUD are its own mariones score and the ring counter.
	// The source's list is `timeTxt`, `timeBarBG`, `timeBar`, `iconP2`, `iconP1`,
	// `customHB` and `healthBar`; the four that Codename does not have are simply
	// absent, and `healthBarBG` is added because the fork never shows it on any
	// stage (created `visible = false` at 5208, with `healthBar` - an
	// AttachedSprite's tracker - the bar that actually shows) whereas Codename's
	// health bar background is on by default. `missesTxt`/`accuracyTxt` are
	// Codename's own additions to that row and go too: the source has neither, and
	// they sit at `healthBarBG.y + 30`, right on this stage's score row.
	if (healthBar != null) healthBar.visible = false;
	if (healthBarBG != null) healthBarBG.visible = false;
	if (iconP1 != null) iconP1.visible = false;
	if (iconP2 != null) iconP2.visible = false;
	if (missesTxt != null) missesTxt.visible = false;
	if (accuracyTxt != null) accuracyTxt.visible = false;

	// 2098-2111: the card is created at load, before the ring HUD (2098 vs 2113),
	// so it sits under it in the state's draw list.
	mmGetTitleNES();

	// 2113-2131: `ringcount` is a right-aligned mariones 40 text 115px off the
	// left edge on the score's own row, `ringicon` the 6x6 ring image scaled 8x
	// at x 1020.
	mmRingText = new FlxText(-115, 670, FlxG.width, "00", 24);
	mmRingText.setFormat(Paths.font("mariones.ttf"), 40, FlxColor.WHITE, "right");
	mmRingText.antialiasing = false;
	mmRingText.cameras = [camHUD];
	add(mmRingText);
	if (mmDownscroll()) mmRingText.y = -20;

	mmRingIcon = new FlxSprite(1020, mmRingText.y);
	mmRingIcon.loadGraphic(Paths.image("mario/Somari/image"));
	mmRingIcon.scale.set(8, 8);
	mmRingIcon.updateHitbox();
	mmRingIcon.antialiasing = false;
	mmRingIcon.cameras = [camHUD];
	add(mmRingIcon);

	if (mmDownscroll()) {
		mmRingText.y = -20;
		mmRingIcon.y = -20;
	}

	// 4929-4937: the somari score text replaces the engine's own (`scoreTxt = new
	// FlxText(...)`), so the engine text is hidden and a mariones copy drawn on
	// its row (152, 670), left-aligned and screen-locked.
	if (scoreTxt != null) scoreTxt.visible = false;
	mmScoreTxt = new FlxText(152, 670, FlxG.width, "", 60);
	mmScoreTxt.setFormat(Paths.font("mariones.ttf"), 40, FlxColor.WHITE, "left");
	mmScoreTxt.scrollFactor.set(0, 0);
	mmScoreTxt.antialiasing = false;
	mmScoreTxt.cameras = [camHUD];
	if (mmDownscroll()) mmScoreTxt.y = -20;
	add(mmScoreTxt);

	// 5706-5722: the two black bars. `blackHUD1` is the top one, `blackHUD2` the
	// bottom one; both carry the source's own y (and `blackHUD2` is created at
	// 7197 for either scroll direction).
	var cam = mmEst();
	mmBlackHud(400, 200, mmDownscroll() ? -969 : -879, cam);
	mmBlackHud(400, 1473, 7197, cam);

	// The stage's own load-time pieces. `pixelLights` is `add()`ed after the
	// character groups in the source (4428-4432), so it is lifted in front of
	// them - with a splice plus an append, because a bare `remove(x); add(x)` is
	// a no-op (see the header's draw-order note).
	if (pixelLights != null) {
		remove(pixelLights, true);
		insert(members.length, pixelLights);
	}
	if (bgstars != null) FlxTween.tween(bgstars, {x: bgstars.x - 1388}, 30, {type: FlxTween.LOOPING});
}

// 7434-7441: the score is the zero-padded `songScore`, the counter is the ring
// with a leading zero under ten. Run in postUpdate so it overwrites anything the
// engine wrote to its own (hidden) score text this frame.
function postUpdate(elapsed:Float) {
	if (mmRingText != null)
		mmRingText.text = ((mmRing < 10) ? "0" : "") + Std.string(mmRing);
	if (mmScoreTxt != null)
		mmScoreTxt.text = mmFormatMario(songScore, 6);
}

// 15654-15659: `ring++` for a hit Ring Note. The 'ringhit' sound belongs to
// data/notes/Ring Note.hx (it plays it on the same hit), so only the counter is
// touched here.
function onNoteHit(event) {
	if (!event.player) return;
	if (event.noteType != "Ring Note") return;
	mmRing += 1;
}

// 15210-15235 (`noteMiss`) and 15391-15410 (`noteMissPress`). A real miss halves
// the ring (> 5) or empties it, a miss-*press* always empties it; either way a
// miss with no rings kills BF on the spot. `nodamage` (494) then makes every
// miss for the next three seconds skip damage/animations. Actual notes must
// still be deleted: cancelling CNE's event leaves a late note alive, repeatedly
// missing until immunity expires. Source songMisses++ is outside nodamage.
// `event.ghostMiss` is a press with no note.
function onPlayerMiss(event) {
	if (mmNoDamage) {
		event.healthGain = 0;
		event.score = 0;
		event.misses = event.ghostMiss ? 0 : 1;
		event.accuracy = null;
		event.muteVocals = false;
		event.gfSad = false;
		event.preventAnim();
		event.preventStunned();
		event.preventMissSound();
		event.preventResetCombo();
		return;
	}
	mmNoDamage = true;
	new FlxTimer().start(3, function(tmr) { mmNoDamage = false; });

	// The stage owns BF's hit and GF's random sad pose. Stop CNE from
	// overwriting them with singMISS / its generic sad after this hook returns.
	event.preventAnim();
	event.preventStunned();
	event.gfSad = false;
	// noteMiss skips normal health drain on somari; noteMissPress still costs .04.
	event.healthGain = event.ghostMiss ? -0.04 : 0;

	var ghost:Bool = event.ghostMiss;

	if (mmRing == 0) {
		health = 0;
	} else {
		mmFlicker(boyfriend, 3, 0.2);
		FlxG.sound.play(Paths.sound("ringloss"));
		new FlxTimer().start(0.5, function(tmr) {
			if (boyfriend != null) boyfriend.dance();
		});
	}

	// noteMiss updates the ring *after* gf's sad animation, a miss-press before;
	// both then play BF's 'hit'.
	var gfSad:Bool = (gf != null && gf.curCharacter == "eeveefriend");
	if (ghost) {
		mmRing = 0;
		if (gfSad) gf.playAnim("sad" + FlxG.random.int(1, 4));
	} else {
		if (gfSad) gf.playAnim("sad" + FlxG.random.int(1, 4));
		mmRing = (mmRing > 5) ? Std.int(mmRing / 2) : 0;
	}

	if (boyfriend != null) boyfriend.playAnim("hit", true);
}

// 15755-15798: hand the window and the root scale back.
function destroy() {
	if (mmEstCam != null && FlxG.cameras != null && FlxG.cameras.list != null)
		FlxG.cameras.list.remove(mmEstCam);
	if (!mmScreenOn) return;
	mmScreenOn = false;

	if (window != null) {
		if (Std.int(window.width) == 800 && Std.int(window.height) == 600)
			window.move(Std.int(window.x) - 240, Std.int(window.y) - 60);
		window.resize(1280, 720);
		window.resizable = true;
		window.fullscreen = false;
		window.maximized = false;
	}
	if (Lib != null && Lib.current != null) {
		Lib.current.scaleX = 1;
		Lib.current.scaleY = 1;
	}
}

function onEvent(event) {
	// 14211-14228 / 14275-14280: on this stage the 'Show Song' card *is* this
	// stage's sprite - 0 plays `titleNES`' 'show' (and un-hides it), 1 plays
	// 'hide' - and the regular title/author card is skipped entirely. The card
	// script stands down here too (data/events/Show Song.hx returns early for
	// somari, exactly as it does for endstage and piracy).
	if (event.event.name == "Show Song") {
		var card = Std.parseInt(event.event.params[0]);
		if (card == null || Math.isNaN(card)) card = 0;
		var nes = mmGetTitleNES();
		if (card == 0) {
			nes.visible = true;
			nes.animation.play("show");
		} else {
			nes.animation.play("hide");
		}
		return;
	}

	if (event.event.name != "Triggers MARIO SING AND GAME RYTHM 9" && event.event.name != "Triggers Universal") return;
	var trigger = Std.parseInt(event.event.params[0]);
	if (trigger == null || Math.isNaN(trigger)) trigger = 0;
	var value2:String = (event.event.params.length > 1) ? StringTools.trim(Std.string(event.event.params[1])) : "";

	switch (trigger) {
		case 0:
			// 10474: the platform, BF and GF bob 126px up for three seconds and
			// back, with a one-second wait between passes.
			if (platformlol != null) FlxTween.tween(platformlol, {y: platformlol.y - 126}, 3, {type: FlxTween.PINGPONG, loopDelay: 1});
			if (boyfriend != null) FlxTween.tween(boyfriend, {y: boyfriend.y - 126}, 3, {type: FlxTween.PINGPONG, loopDelay: 1});
			if (gf != null) FlxTween.tween(gf, {y: gf.y - 126}, 3, {type: FlxTween.PINGPONG, loopDelay: 1});

		case 1:
			// 10480-10496: 'none' kills the spotlight (and drops the stars behind
			// the buildings), anything else lights it up with that animation's
			// frame (`spot 0/1/2/3` = full/left/right/double) and moves the stars
			// in front of it.
			if (value2 == "none") {
				if (pixelLights != null) pixelLights.visible = false;
				mmMoveBgStars("none");
			} else {
				if (pixelLights != null) {
					pixelLights.visible = true;
					pixelLights.animation.play(value2);
				}
				mmMoveBgStars((value2 == "full") ? "full" : "other");
			}
	}
}
// === end MM stage triggers ===
