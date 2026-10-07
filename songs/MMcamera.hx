// Global camera helper for the Mario's Madness port (gameplay script, runs for
// every song).
//
// WHY THIS EXISTS
// ---------------
// The source hardcodes an ABSOLUTE per-character camera system (BF_CAM_X/Y,
// DAD_CAM_X/Y, GF_CAM_X/Y, BF_ZOOM/DAD_ZOOM/GF_ZOOM) and its update() points
// camFollowPos at the camera of the current section's character every frame.
//
// Codename instead derives the camera from the character (Character.hx):
//
//     getCameraPosition() = midpoint
//                           + (isPlayer ? -100 : 150)
//                           + globalOffset + cameraOffset
//
// and a stage's `camxoffset`/`camyoffset` are *added* to `cameraOffset`
// (Stage.hx, StageCharPos.prepareCharacter). The Psych convention
// (`absoluteCam - charPos`) that earlier builds wrote into the stage XMLs is
// therefore wrong for Codename: the camera lands ~150px too low and only pans
// a fraction of the way. The correct value would be
// `absoluteCam - midpoint - globalOffset`, which depends on the character's
// frame size and so cannot be computed statically. Hence this script.
//
// HOW IT WORKS
// ------------
// `onCameraMove` is the authoritative hook: the engine's moveCamera() runs every
// frame, derives camFollow from the current strumline and then lets scripts
// rewrite `event.position` (= camFollow). `postUpdate` re-applies the same
// values at the end of update() as a safety net.
//
// The target comes from the event's strumline (dad/bf/gf), and `Camera Movement`
// events - which the chart conversion emits from mustHitSection - keep it in
// sync with the source's curCameraTarget.
//
// `Set Cam Pos` / `Set Cam Zoom` rewrite the stored absolute values, exactly
// like the source's DAD_CAM_X/Y and DAD_ZOOM.
//
// FOLLOWCHARS / ZOOMCHARS
// -----------------------
// The source can stop following the section characters (FOLLOWCHARS=false) and
// drive camFollowPos itself - the 'Alone Mario' reveal does this: dad's camera
// is moved to (720, 75) while camFollowPos is tweened down to (720, -100) and
// the zoom is tweened to 0.65. `mmLockTo`/`mmStepOverride` reproduce that here.
//
// The source's camera moves are FlxTweens with an ease (quadInOut, cubeOut,
// expoIn, ...), so the eased variants here are real FlxTweens too, on our own
// `mmOv` / `mmZoomVal` rather than on camFollow / camGame - `mmApply` stays the
// only writer of those, so nothing fights a running tween for the property.
// Call sites without an ease keep the old exponential-lerp approximation.

var mmDadPos = null;
var mmBfPos = null;
var mmGfPos = null;
var mmDadZoom = null;
var mmBfZoom = null;
var mmGfZoom = null;

// 0 = dad, 1 = boyfriend, 2 = girlfriend (the source's curCameraTarget values).
var mmTarget = 0;
var mmActive = false;

// The create-time camera snaps - the source's `snapCamFollowToPos(x, y)` calls
// in create() (5838-5855). They are not a one-frame detail: the source's section
// camera is gated on `generatedMusic && SONG.notes[curStep / 16] != null`
// (7308-7312), and while the countdown runs curStep is negative, so that lookup
// is null and the camera stays exactly where create() put it. Codename has no
// such gate - moveCamera() starts as soon as generatedMusic is set - so the port
// holds the snap itself for as long as `Conductor.songPosition < 0`.
// `bootleg` (5851) is deliberately not listed: its snap is followed by
// `isCameraOnForcedPos = true` (5852), which the mmLockTo/mmOv machinery owns.
var MM_START_CAM =
	"directstream|1011,508.5;" +
	"promoshow|804,742;" +
	"realbg|1020,650;" +
	"superbad|280,400;";
var mmStartCam = null;
var mmSawMove = false;
var mmInitDone = false;

// FOLLOWCHARS / ZOOMCHARS (PlayState.hx). While `mmFollow` is false the section
// target is ignored and the camera is driven by `mmOv` instead.
var mmFollow = true;
var mmZoomFollow = true;
// `blockzoom` (PlayState.hx:536) - the fork's own gate on its per-frame zoom
// lerp (7962: `if (camZooming && curStage != 'somari' && !blockzoom)`). Only
// Nourishing Blood touches it (10445/10455), around the camHUD pulse it wraps.
var mmBlockZoom = false;
var mmOv = {x: 0.0, y: 0.0};   // locked camera position (tweened while locked)
var mmOvTo = null;             // [x, y] destination while locked, or null
var mmLockTime = 0.0;          // budget of an un-eased lock (see mmStepOverride)
var mmPosTween = null;         // eased FlxTween on `mmOv`, if any
var mmFollowPrev = true;       // mmFollow on the previous frame (see mmApply)

// Delayed mmLockTo + camera-zoom override. The All-Stars act transitions tween
// camFollowPos after a delay and tween camGame.zoom directly, so both need to be
// stepped from postUpdate (`mmStepOverride`) rather than driven by the engine.
var mmPendLock = null;         // {px, py, sec, delay, t, ease}
var mmOrbitTweens = [];        // the extra pingpong tweens of Paranoia's fly-around
var mmZoomDrive = null;        // {from, to, dur, delay, t[, eased]}
var mmZoomVal = {v: 0.0};      // tweened zoom value, applied by mmApply
var mmZoomTween = null;        // eased FlxTween on `mmZoomVal`, if any

// GFSINGDAD / GFSINGBF (PlayState.hx): while the girlfriend sings a 'GF Sing'
// note the source points the camera at her instead of the section character.
// Set from the note-hit hook and cleared by normal / 'GF Duet' notes.
var mmGFSingDad = false;
var mmGFSingBF = false;
// One row per stage:  <stage>|<dad x,y,zoom>|<bf x,y,zoom>|<gf x,y,zoom>
// Values come straight out of Mario-Madness/assets/preload/stages/<stage>.json,
// whose array format is [charX, charY, camX, camY, zoom]; the source reads those
// into BF_CAM_X/Y, DAD_CAM_X/Y, GF_CAM_X/Y and BF/DAD/GF_ZOOM.
// Stages that are not listed are left completely untouched.
var MM_CAM =
	"allfinal|-420,150,0.35|220,450,0.6|370,450,0.6;" +
	"betamansion|420,450,0.8|720,450,0.8|720,450,0.8;" +
	"bootleg|120,650,0.8|1120,750,0.8|1120,750,0.8;" +
	"castlestar|380,450,0.7|1320,520,0.7|1320,520,0.7;" +
	"demiseport|1220,0,0.4|380,350,0.6|380,350,0.6;" +
	"directstream|1011,558.5,0.66|1011,558.5,0.66|400,130,0.66;" +
	"endstage|350,450,0.45|820,500,0.45|820,500,0.45;" +
	"execlassic|400,350,0.5|1020,500,0.5|790,310,0.5;" +
	"execlassicold|400,250,0.9|1020,500,0.9|400,130,0.9;" +
	"exeport|360,450,0.6|1120,550,0.6|1120,550,0.6;" +
	"exesequel|550,250,0.5|1550,500,0.7|550,250,0.7;" +
	"forest|220,150,0.6|1020,550,0.45|1020,550,0.6;" +
	"hatebg|220,300,0.7|920,550,0.7|920,550,0.7;" +
	"landstage|420,450,1|720,500,1|720,500,1;" +
	"luigiout|620,450,0.9|320,450,0.9|920,450,0.9;" +
	"meatworld|-80,450,0.5|900,550,0.6|900,550,0.5;" +
	"nesbeat|620,450,0.9|620,450,0.9|620,450,0.9;" +
	"piracy|1300,600,1|1300,600,1|1300,600,1;" +
	"promoshow|1009,544,0.8|804,742,0.9|804,742,0.9;" +
	"racing|420,450,0.9|720,450,0.9|720,450,0.9;" +
	"realbg|1020,1850,1.3|1020,750,1.3|1020,720,1.3;" +
	"secretbg|220,350,0.9|950,550,0.9|670,450,0.7;" +
	"somari|100,100,1|770,100,1|400,130,1;" +
	"stage|100,100,0.9|770,100,0.9|400,130,0.9;" +
	"superbad|520,380,1.4|650,380,1.1|600,320,1.1;" +
	"turmoilsweep|420,500,0.9|970,550,0.9|500,50,0.9;" +
	"virtual|260,270,0.45|1220,550,0.7|400,130,0.6;" +
	"warioworld|620,550,1.1|620,550,1|400,130,1;" +
	"wetworld|450,50,1.2|1020,300,0.7|1020,300,0.7;";

function mmNum(v, def) {
	var f = Std.parseFloat(StringTools.trim(Std.string(v)));
	if (f == null) return def;
	if (f != f) return def; // NaN (only NaN is not equal to itself)
	return f;
}

function mmVec(csv) {
	var p = Std.string(csv).split(",");
	if (p.length < 2) return null;
	return [mmNum(p[0], 0), mmNum(p[1], 0)];
}

function mmStageName() {
	// `PlayState.SONG` is the accessor the engine's own bundled scripts use
	// (bare `SONG` is a static and not reliably reachable from a script).
	var st = null;
	if (PlayState.SONG != null && PlayState.SONG.stage != null) st = PlayState.SONG.stage;
	if ((st == null || st == "") && stage != null && stage.stageName != null) st = stage.stageName;
	return st;
}

// The song name a script can see (PlayState.SONG.meta.displayName).
function mmSongName() {
	var meta = (PlayState.SONG != null) ? PlayState.SONG.meta : null;
	if (meta == null) return null;
	return meta.displayName;
}

// hatebg is one stage for three songs, and 'Oh God No' is the one whose camera
// the source overrides by hand (see the override in mmInit).
function mmOgnSong():Bool {
	var n = mmSongName();
	if (n == null) return false;
	return StringTools.startsWith(StringTools.trim(Std.string(n)), "Oh God No");
}

function mmInit() {
	mmInitDone = true;
	var st = mmStageName();
	if (st == null || st == "") return;
	for (row in MM_CAM.split(";")) {
		var f = row.split("|");
		if (f.length < 4 || f[0] != st) continue;

		var d = Std.string(f[1]).split(",");
		var b = Std.string(f[2]).split(",");
		var g = Std.string(f[3]).split(",");

		mmDadPos = mmVec(f[1]); mmDadZoom = mmNum(d[2], null);
		mmBfPos = mmVec(f[2]); mmBfZoom = mmNum(b[2], null);
		mmGfPos = mmVec(f[3]); mmGfZoom = mmNum(g[2], null);
		mmActive = true;
		break;
	}

	// Per-song hardcoded camera overrides - the source's `case '...'` blocks in
	// create() that reassign BF_CAM_X/Y / DAD_CAM_X/Y in code, which no chart
	// event can carry. Oh God No is the first one folded in here: on the shared
	// hatebg stage it runs the fighters on *swapped sides* (create() sets
	// BF_CAM = (220, 350) and DAD_CAM = (620, 290) - i.e. bf on the left, dad on
	// the right - which is also why the source mirrors the health bar for this
	// song, `flipchar = true`).
	if (st == "hatebg" && mmOgnSong()) {
		mmBfPos = [220, 350];
		mmDadPos = [620, 290];
	}

	// Create-time camera *state* - the fork's hand-written `FOLLOWCHARS = false`
	// / `ZOOMCHARS = false` / `camGame.zoom` / `snapCamFollowToPos` lines that no
	// chart event carries. They are load-bearing: both flags gate the fork's own
	// per-frame camera writes (7310/7316 for the position, 7321-7329 for the
	// zoom), so without them a stage script's `defaultCamZoom = 1.7` is rewritten
	// by the section block on the very next frame (Bad Day 10047, Day Out 13765)
	// and a scripted camera tween snaps back to the section the moment it ends
	// (Nourishing Blood). Source: 'bootleg' 2241+5851, 'luigiout' 2307,
	// `if (curStage == 'superbad')` 5574-5590.
	if (st == "bootleg") {
		mmFollow = false; // 2241
		// 5851-5852: snapCamFollowToPos(850, -930) + isCameraOnForcedPos. The
		// flag is never read in this fork, so the snap plus FOLLOWCHARS = false is
		// simply "the camera stays here" - nothing in either Nourishing Blood
		// block tweens camFollowPos (10380-10466, 12161+), so it stays all song.
		mmForcePos(850, -930, true);
	} else if (st == "luigiout") {
		mmZoomFollow = false; // 2307 - ZOOMCHARS = false
	} else if (st == "superbad") {
		mmFollow = false; // 5582
		mmZoomFollow = false; // 5583
		// 5590: a hard write, not the 1.4 the preload carries - the stage's
		// triggers then move the *target* (`defaultCamZoom = 1.7` at 10047) and
		// the engine lerps towards it, which only happens with ZOOMCHARS off.
		if (FlxG.camera != null) FlxG.camera.zoom = 1.6;
	}

	for (row in MM_START_CAM.split(";")) {
		var f = row.split("|");
		if (f.length < 2 || f[0] != st) continue;
		mmStartCam = mmVec(f[1]);
		break;
	}
}

// ----------------------------------------------------------------------------
// Character preloads
// ----------------------------------------------------------------------------
// Every song that swaps a character mid-chart decodes that character's atlas on
// the spot the first time the swap builds it - a visible stall. The source does
// the warm-up in two places: `eventPushed` (6806-6838) walks the chart's own
// events *before the song starts* and calls `addCharacterToList` for every
// 'Change Character' and 'Triggers Race Traitors' target, and each stage's
// `case 'stage'` block in create() calls it again for the characters its
// hand-written triggers swap into (which no chart event carries).
//
// Both halves live here, in the one script that runs for every song. The chart
// half is driven by `PlayState.SONG.events`, so it covers all thirteen swapping
// charts without a per-song list; the trigger half is the small table below.
// `Paths.getFrames(...)` is the exact call `Character`'s loader
// (`FunkinSprite.loadSprite`) makes, cached under the same key, so the later
// `new Character()` reuses the frames instead of decoding a second copy.
//
// The '... Old' songs are skipped: they are the legacy duplicates and their
// atlases are left to decode on demand.
var mmCharsPreloaded:Bool = false;

// The per-stage `addCharacterToList` calls that have no chart 'Change
// Character' event behind them - the characters a stage's own triggers swap into
// (the source's create() blocks: wetworld 4038-4039, demiseport 3049-3050,
// endstage 3638, castlestar 3354, forest 2787). `racing` is the odd one out: its
// racers arrive through the 'Triggers Race Traitors' case (case 1, racing.hx),
// and while `racet2`/`racet3`/`race` are named by the chart's own events, the
// `racet1` of case 0 is only in the source's create() list (1886-1888) - the
// chart event that fires case 0 carries an empty value2. Stages whose preloads
// already live in their own script (allfinal.hx, exeport.hx, exesequel.hx,
// promoshow.hx, meatworld.hx) are not repeated here.
var MM_PRELOAD =
	"bootleg|bfcave,gfcave,grandcave,bfGD,gfGD,grand;" +
	"castlestar|devilmariotalk;" +
	"demiseport|mx_demiseUG,bf_demiseUG;" +
	"endstage|costumedark;" +
	"forest|peachtalk1;" +
	"racing|racet1;" +
	"wetworld|luigi_fountain3d,bf-back3d;";

// The display-name test for the legacy songs ("Overdue Old", "Powerdown Old",
// ...). Same idiom the stage scripts use (meatworld.hx's mmIsOld, exeport.hx's
// mmIsPowerdownOld): a script only ever sees the song through
// PlayState.SONG.meta.displayName.
function mmLegacySong():Bool {
	var n = mmSongName();
	if (n == null) return false;
	return StringTools.endsWith(StringTools.trim(Std.string(n)), " Old");
}

// The image a character's XML points at (`sprite="..."`) - the value the
// preload caches under and the one `FunkinSprite.loadSprite` later asks for.
function mmCharImage(name:String) {
	if (name == null || name == "") return null;
	var xmlPath = Paths.xml("characters/" + name);
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
	if (img == null || !Assets.exists(img)) return; // not a character this mod ships
	Paths.getFrames(img, true); // exactly Character's own loader call
}

function mmPreloadCharacters() {
	if (mmCharsPreloaded) return;
	mmCharsPreloaded = true;
	if (mmLegacySong()) return;

	// 6806-6838: the chart's own events - the half that generalises. Every
	// 'Change Character' / 'Triggers Race Traitors' target is warmed here without
	// a list per song.
	var song = PlayState.SONG;
	if (song != null && song.events != null) {
		for (ev in song.events) {
			if (ev == null || ev.name == null) continue;
			if (ev.name != "Change Character" && ev.name != "Triggers Race Traitors") continue;
			var p = ev.params;
			if (p == null || p.length < 2) continue;
			var name:String = StringTools.trim(Std.string(p[1]));
			if (name == "") continue;
			mmPreloadChar(name);
		}
	}

	// The stage's own trigger swaps (the source's create-branch lists).
	var st = mmStageName();
	if (st != null) {
		for (row in MM_PRELOAD.split(";")) {
			var f = row.split("|");
			if (f.length < 2 || f[0] != st) continue;
			for (name in Std.string(f[1]).split(",")) {
				if (name == "") continue;
				mmPreloadChar(name);
			}
			break;
		}
	}
}

// ----------------------------------------------------------------------------
// Game-over character and death sounds
// ----------------------------------------------------------------------------
// The source sets Psych's `GameOverSubstate` fields per stage in the same
// create() switch the preloads come from: `characterName` (the death sprite),
// `deathSoundName` (the mic-drop SFX) and `loopSoundName` (the music the screen
// loops). Codename keeps the first on the character itself
// (`PlayState.gameOver()`: `deathCharID.getDefault(charToUse.gameOverCharacter)`,
// the hook meatworld.hx's mmGameOver and luigiout.hx's case 9 already use) and
// the two sounds on the state (`lossSFX`, `gameOverSong`), so every stage's set
// is applied here from one table, the way the preloads are.
//
// `endSoundName` is deliberately not ported: the engine plays `retrySFX`
// through `Paths.sound` (GameOverSubstate.endBullshit) while the fork's files
// live in `music/` and are played with `Paths.music`, so a name that resolves in
// the fork would resolve to nothing here - the engine's own 'gameOverEnd' is
// left in place (the decision meatworld.hx's mmGameOver documents).
// `hasVA`/`vaCount` need the fork's voice-line system, which Codename has no
// equivalent for.
//
// Format: stage|character|lossSFX|gameOverSong; '' leaves the field alone. A
// `_#` in the loop is the fork's `FlxG.random.int(1, 24)` (Nourishing Blood's
// ghost track). meatworld.hx sets its own three from its script (it carries the
// ported `mmGameOver`), so it is not repeated here.
var mmGameOverSet:Bool = false;

// The non-legacy songs (the source's `if (SONG.song != '...')` / else halves).
var MM_GAME =
	"allfinal|bfASdeath||;" +
	"bootleg|bfGDDIES|gran_gag_sounddesign|GD/ghost_#;" +
	"castlestar|bfPowerdeath|POWERSTARDEATH|POWERSTARDEATH_LOOP_60BPM;" +
	"execlassic|bfexenewdeath||;" +
	"exesequel|bfexenewdeath||;" +
	"exeport|bf_PDdeath||;" +
	"demiseport|bf_demisedeath||;" +
	"hatebg|bfihydeath||;" +
	"landstage|||GBgameover;" +
	"luigiout|bf-ldo||;" +
	"nesbeat|||gameOverUB;" +
	"racing||racelose|;" +
	"secretbg|bfsecretgameover|goodbye_old_friend_sh_mario|;" +
	"superbad|bfbaddeath||;" +
	"turmoilsweep|bf-goomba|turmoil_death1|;";

// The '... Old' songs' halves (bfexe/bfgb/bfvhs and the Wario sounds). The two
// defaults the source re-states there ('gameOver' / 'gameOverEnd') are the
// engine's own, so they are left out.
var MM_GAME_OLD =
	"demiseport|bf_demisedeath||;" +
	"execlassic|bfexe||;" +
	"exeport|bfvhs||;" +
	"landstage|bfgb||;" +
	"warioworld||gameoverwario|;";

function mmGameOverApply(row:String) {
	if (row == null || row == "") return;
	var f = row.split("|");
	if (f.length < 4) return;
	var charName:String = Std.string(f[1]);
	var loss:String = Std.string(f[2]);
	var loop:String = Std.string(f[3]);
	if (charName != "" && boyfriend != null && Assets.exists(Paths.xml("characters/" + charName)))
		boyfriend.gameOverCharacter = charName;
	var ps = PlayState.instance;
	if (ps == null) return;
	if (loss != "" && Reflect.field(ps, "lossSFX") != null && Assets.exists(Paths.sound(loss)))
		Reflect.setProperty(ps, "lossSFX", loss);
	if (loop != "") {
		if (loop.indexOf("_#") >= 0) loop = loop.split("_#")[0] + "_" + FlxG.random.int(1, 24);
		if (Reflect.field(ps, "gameOverSong") != null && Assets.exists(Paths.music(loop)))
			Reflect.setProperty(ps, "gameOverSong", loop);
	}
}

function mmGameOverConfig() {
	if (mmGameOverSet) return;
	mmGameOverSet = true;
	var st = mmStageName();
	if (st == null || st == "") return;
	var table:String = mmLegacySong() ? MM_GAME_OLD : MM_GAME;
	for (row in table.split(";")) {
		if (row == "") continue;
		var f = row.split("|");
		if (f.length < 4 || f[0] != st) continue;
		mmGameOverApply(row);
		return;
	}
}

function postCreate() {
	mmInit();
	// 6806-6838 + the create() branches: warm the character atlases every swap on
	// this song will need, before the countdown (see the block above).
	mmPreloadCharacters();
	// The stage's game-over character and its two sounds (see the block above).
	mmGameOverConfig();
	// Stage scripts reach the camera through this (see mmCameraApi).
	//
	// The channel is CnE's own ScriptPack: `scripts.set(name, value)` puts the
	// variable in *every* loaded script and `scripts.get(name)` reads it back
	// (`funkin.backend.scripting.ScriptPack`, exactly what the engine's own
	// `game.scripts.getByName('pixel.hx')` uses). The previous version published
	// it with `Reflect.setProperty(PlayState.instance, "mmCamera", ...)`, which
	// on cpp logs `Invalid field:mmCamera` and **throws** - Haxe's Reflect only
	// touches fields that already exist, and PlayState has no `mmCamera` - so the
	// error aborted this function and the api was never published: every
	// `mmCam(...)` call in luigiout/bootleg/landstage/forest/realbg/superbad was
	// a silent no-op. (Same trap data/events/setProperty.hx and allfinal.hx
	// document.)
	if (PlayState.instance != null && PlayState.instance.scripts != null) {
		PlayState.instance.scripts.set("mmCamera", mmCameraApi());
		PlayState.instance.scripts.set("mmDodge", {
			active: function() { return mmDodging; },
			bot: mmDodgeBot,
			auto: mmStartDodge
		});
	}
	// The source hides the HUD in startCountdown() (`camHUD.alpha = 0`,
	// PlayState.hx:6366); doing it here instead only means it is already gone for
	// the frame or two before the countdown is asked to start. It stays hidden
	// until the chart's 'Ocultar HUD' 0 at 99.72s.
	if (mmStageName() == "virtual" && camHUD != null) camHUD.alpha = 0;
}

// Paranoia's intro, straight out of the source's startCountdown()
// (`curStage == 'virtual'`, PlayState.hx:6364-6383):
//
//     camHUD.alpha = 0;
//     eventTimers.push(new FlxTimer().start(1, function(tmr:FlxTimer) {
//         FlxG.sound.play(Paths.sound('virtualintro'));
//         blackBarThingie.alpha = 0;
//         camGame.zoom = 1;
//         eventTweens.push(FlxTween.tween(camGame, {zoom: 0.5}, 1.3, {ease: expoOut}));
//         startedCountdown = true;
//         effect.setStrength(40, 40);   // the CRT boot'up, 0.7s (virtual.hx)
//     }));
//
// `startedCountdown = true` sits *inside* that timer on purpose, and it is what
// makes the delay real: the fork only advances Conductor.songPosition while it
// is set (PlayState.hx:7829/7916), and it is set at the top of startCountdown()
// for every other stage - so for Paranoia the countdown, and with it the song,
// genuinely starts one second late, with the stinger and the CRT boot-up
// filling that second.
//
// Codename has both halves, so the delay is reproduced rather than skipped.
// startCountdown() fires a cancellable `onStartCountdown` before it touches
// anything (PlayState.hx:973-979; `_startCountdownCalled` makes sure it is only
// dispatched once), and its only caller is the cutscene callback (906), so
// holding it here is safe: nothing runs and the song cannot start, because
// update() gates on `startedCountdown` (1388). The 1s timer then calls it again
// - the event is skipped the second time, so it runs for real.
//
// (The re-call also re-arms `Conductor.songPosition` to the countdown's own
// lead-in, so the chart stays in sync; that lead-in is the engine's 4 crochets
// here against the fork's 5, which lands the song start 0.41s earlier.)
var mmIntroHeld:Bool = false;
function onStartCountdown(event) {
	if (mmStageName() != "virtual" || mmIntroHeld) return;
	mmIntroHeld = true;
	event.cancelled = true;

	new FlxTimer().start(1, function(tmr) {
		FlxG.sound.play(Paths.sound("virtualintro"));
		// The drive publishes defaultCamZoom *and* camGame.zoom, and starts from
		// the stored defaultCamZoom - seeding both here is what makes the ease
		// begin at 1 exactly like the source's `camGame.zoom = 1` + tween.
		defaultCamZoom = 1;
		if (FlxG.camera != null) FlxG.camera.zoom = 1;
		mmZoomDriveTo(0.5, 1.3, 0, FlxEase.expoOut);

		if (PlayState.instance != null) PlayState.instance.startCountdown();
	});
}

// The source runs this stage with `noCount = true` (PlayState.hx:2365, next to
// `virtualmode = true`): its 3-2-1-GO sprites and their sounds are never built
// (`if (!noCount)` at 6444/6502), and the 'virtualintro' stinger is this stage's
// countdown instead. Codename builds them in the cancellable `onCountdown`
// event (PlayState.hx:998-1042), so it is dropped here for the same reason -
// the engine's READY/SET/GO would otherwise play over the hold above.
function onCountdown(event) {
	if (mmStageName() == "virtual") event.cancelled = true;
}

function mmIndexFor(who) {
	if (who == "bf") return 1;
	if (who == "gf") return 2;
	return 0;
}

function mmPosFor(t) {
	if (t == 1) return mmBfPos;
	if (t == 2) return mmGfPos;
	return mmDadPos;
}

function mmZoomFor(t) {
	if (t == 1) return mmBfZoom;
	if (t == 2) return mmGfZoom;
	return mmDadZoom;
}

// ---------------------------------------------------------------------------
// Character resolution
// ---------------------------------------------------------------------------
// The source's 'Change Character' REASSIGNS the fields a script reads as `dad` /
// `boyfriend` / `gf` (PlayState.hx:9339 `dad = dadMap.get(value2)`), while this
// port swaps the *strumline's* character - the one that actually renders. The
// globals only track the swap by name, and a name cannot tell a live view apart
// from a duplicate object; resolving the strumline is correct either way, so the
// character comparisons below use it and keep the globals only as a fallback.
// Reflect.field returns null instead of throwing on a missing field, so this is
// safe in a song script.
function mmRoleChar(i:Int) {
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

// NOTE: this used to publish the resolved target onto the PlayState with
// `Reflect.setField(st, "mmCamTarget", ...)` so the stage script could read it.
// `Reflect.field` in this engine (Haxe `Reflect` on cpp) *throws*
// "Invalid field:<name>" for a field that does not exist yet instead of
// returning null, so the read threw once per frame - the log spam - and the
// value was never visible anyway. Nothing needs it: the stage script tracks the
// chart's own 'Camera Movement' events (the same value this resolves from), so
// the cross-script channel is gone.
// Which camera target a strumline belongs to, or null.
function mmWhoFor(strumLine) {
	if (strumLine == null) return null;
	var chars = strumLine.characters;
	if (chars == null) return null;
	// dad first: some setups bundle gf onto the opponent strumline.
	var cd = mmRoleChar(0);
	var cb = mmRoleChar(1);
	var cg = mmRoleChar(2);
	for (c in chars) {
		if (c == null) continue;
		if ((cd != null && c == cd) || c == dad) return "dad";
		if ((cb != null && c == cb) || c == boyfriend) return "bf";
		if ((cg != null && c == cg) || c == gf) return "gf";
	}
	return null;
}

// ---------------------------------------------------------------------------
// FOLLOWCHARS / ZOOMCHARS equivalents
// ---------------------------------------------------------------------------

// Locks the camera onto (px, py) for `seconds`. With an `ease` this is a real
// FlxTween, so the source's curve (quadInOut, cubeOut, expoIn, ...) is exact.
// Without one it keeps the exponential lerp at the rate the source lerps
// camFollowPos (elapsed * 2.4 * cameraSpeed), for the call sites whose source
// tween has not been traced yet. `seconds <= 0` is the source's instant snap
// (`camFollowPos.x = ...`): the legacy branch snaps and releases on the next
// step, so the snapped position is still applied for a frame.
function mmLockTo(px:Float, py:Float, seconds:Float, ease) {
	if (!mmLocked()) {
		if (camFollow != null) {
			mmOv.x = camFollow.x;
			mmOv.y = camFollow.y;
		} else {
			mmOv.x = px;
			mmOv.y = py;
		}
	}
	if (mmPosTween != null) {
		mmPosTween.cancel();
		mmPosTween = null;
	}
	mmOvTo = [px, py];
	mmLockTime = seconds;
	if (ease == null || seconds <= 0) return;
	mmPosTween = FlxTween.tween(mmOv, {x: px, y: py}, seconds, {ease: ease, onComplete: function(twn) {
		mmPosTween = null;
		mmOvTo = null; // FOLLOWCHARS takes the camera back
	}});
}

function mmLocked():Bool {
	return mmOvTo != null;
}

// The source's `isCameraOnForcedPos = true` (PlayState.hx:9262 and the stage
// triggers that call `triggerEventNote('Camera Follow Pos', ...)`): camFollow is
// pinned and stays pinned - unlike mmLockTo there is no duration, only an
// explicit release or a later camera command replacing it. The camera keeps
// easing towards the pinned point, which is what the source gets from its own
// camFollowPos lerp.
function mmForcePos(px:Float, py:Float, snap:Bool) {
	if (snap) {
		// The fork's `snapCamFollowToPos(x, y)` writes camFollowPos itself, i.e.
		// the point the camera is already following - an instant jump, not a
		// pan. mmOv *is* camFollowPos here (mmApply publishes it as camFollow and
		// the engine glides the scroll), so the snap has to land in mmOv before
		// the next mmApply reads it.
		mmOv.x = px;
		mmOv.y = py;
	} else if (!mmLocked() && camFollow != null) {
		mmOv.x = camFollow.x;
		mmOv.y = camFollow.y;
	}
	mmPendLock = null;
	if (mmPosTween != null) { mmPosTween.cancel(); mmPosTween = null; }
	mmOvTo = [px, py];
	mmLockTime = 1000000.0;
}

// `triggerEventNote('Camera Follow Pos', '', '')` - the release. FOLLOWCHARS takes
// the camera back on the next frame, so hand it the live point first (the source
// just stops overwriting camFollow).
function mmReleaseForce() {
	if (mmPosTween != null) { mmPosTween.cancel(); mmPosTween = null; }
	if (camFollow != null) {
		mmOv.x = camFollow.x;
		mmOv.y = camFollow.y;
	}
	mmOvTo = null;
	mmLockTime = 0.0;
}

// The camera API stage scripts use for the songs whose source code drives
// camFollowPos by hand (data/stages/luigiout.hx is the one that also calls
// 'Camera Follow Pos' itself). It has to go through this script: MMcamera writes
// camFollow every frame, so a stage script's own `FlxTween.tween(camFollow, ...)`
// would be overwritten before the camera ever reads it.
function mmCameraApi() {
	return {
		lock: function(x:Float, y:Float, sec:Float, ease) mmLockTo(x, y, sec, ease),
		// The source's `{startDelay: n}` pans (Golden Land 10764, Thalassophobia
		// 13916): the lock only takes the camera once the delay is up, until then
		// the character/section camera keeps it.
		lockDelay: function(x:Float, y:Float, sec:Float, delay:Float, ease) mmLockToDelay(x, y, sec, delay, ease),
		force: function(x:Float, y:Float) mmForcePos(x, y, false),
		snap: function(x:Float, y:Float) mmForcePos(x, y, true),
		release: function() mmReleaseForce(),
		follow: function(on:Bool) { mmFollow = on; },
		// The source's `DAD_CAM_X = 460` style writes - the section position and
		// its zoom, which only show while FOLLOWCHARS is on (Nourishing Blood
		// moves them at 10400/10420 with the camera frozen).
		setCam: function(who:String, x:Float, y:Float, z) mmSetCam(who, x, y, z),
		// Just the zoom half of setCam: the source's `DAD_ZOOM = 0.9` (Golden
		// Land 10715/10725) - live only while ZOOMCHARS is on, exactly like the
		// source, where that write is read by the per-frame block (7329).
		zoomFor: function(who:String, z:Float) mmSetCam(who, mmCamX(who), mmCamY(who), z),
		zoomStop: function() mmZoomStop(),
		// `ZOOMCHARS = false` / `true` from inside a trigger (Unbeatable's case
		// 27/0 stops it so its own 5.9s camGame.zoom tween is what lands, case
		// 17/0 turns it back on). zoomStop only cancels a drive; this is the
		// flag itself.
		zoomFollow: function(on:Bool) { mmZoomFollow = on; },
		zoom: function(z:Float, sec:Float, delay:Float, ease) mmZoomDriveTo(z, sec, delay, ease),
		// The source's `defaultCamZoom = x` written from inside a trigger (Day Out
		// case 2/4, Bad Day 10047). It is a plain assignment there, and it is only
		// *visible* while ZOOMCHARS is off - with ZOOMCHARS on the section block
		// rewrites it every frame, in the source as much as here.
		setZoom: function(z:Float) { defaultCamZoom = z; },
		toggleFollow: function() { mmFollow = !mmFollow; },
		gfSing: function(dad:Bool, bf:Bool) { mmGFSingDad = dad; mmGFSingBF = bf; },
		// The source's `camZooming = true` (Day Out case 2) - the flag that lets
		// the engine lerp camGame.zoom towards defaultCamZoom.
		zooming: function(on:Bool) {
			if (PlayState.instance != null) Reflect.setProperty(PlayState.instance, "camZooming", on);
		},
		// `blockzoom` (10445/10455): stops the zoom lerp without stopping the
		// zoom *target* writes.
		blockZoom: function(on:Bool) { mmBlockZoom = on; }
	};
}

// Current camera x/y (locked value, else camFollow).
function mmCurX():Float {
	if (mmLocked()) return mmOv.x;
	return (camFollow != null) ? camFollow.x : 0;
}
function mmCurY():Float {
	if (mmLocked()) return mmOv.y;
	return (camFollow != null) ? camFollow.y : 0;
}

// mmLockTo, but starting `delay` seconds from now. The source spells this
// `{startDelay: delay}`, so our lock only takes the camera when the delay is up
// (until then FOLLOWCHARS keeps driving it).
function mmLockToDelay(px, py, sec, delay, ease) {
	if (delay == null || delay <= 0) { mmLockTo(px, py, sec, ease); return; }
	mmPendLock = {px: px, py: py, sec: sec, delay: delay, t: 0.0, ease: ease};
}

// Eases the camera zoom (and defaultCamZoom) to `z` over `sec`, after `delay`.
// With an `ease` this is a real FlxTween on `mmZoomVal` (the source tweens
// camGame.zoom and defaultCamZoom with the same curve); without one it keeps
// the linear ramp stepped from mmStepOverride.
function mmZoomDriveTo(z, sec, delay, ease) {
	var from = (mmZoomDrive != null) ? mmZoomVal.v : ((defaultCamZoom != null) ? defaultCamZoom : z);
	if (mmZoomTween != null) {
		mmZoomTween.cancel();
		mmZoomTween = null;
	}
	mmZoomVal.v = from;
	var d = (delay == null) ? 0.0 : delay;
	if (ease == null || sec == null || sec <= 0) {
		mmZoomDrive = {from: from, to: z, dur: (sec == null) ? 0.0 : sec, delay: d, t: 0.0, done: false};
		return;
	}
	mmZoomDrive = {from: from, to: z, dur: sec, delay: d, t: 0.0, eased: true, done: false};
	mmZoomTween = FlxTween.tween(mmZoomVal, {v: z}, sec, {startDelay: d, ease: ease, onComplete: function(twn) {
		mmZoomTween = null;
		// Flag, do NOT clear: mmApply still has to publish this last value on the
		// frame the tween ends, and only after that may the drive be handed back
		// to mmZoomFollow. A drive that is never released keeps rewriting
		// camGame.zoom every frame - which is exactly why act 2/5's scream zoom
		// (DAD_ZOOM + 0.5) stayed on screen instead of returning to DAD_ZOOM when
		// ZOOMCHARS came back 0.1s later. See the release in mmApply.
		if (mmZoomDrive != null) mmZoomDrive.done = true;
	}});
}

// Stops a zoom drive (eased or not) so the stored per-character zoom / a
// 'Set Cam Zoom' value takes the zoom back over.
function mmZoomStop() {
	if (mmZoomTween != null) {
		mmZoomTween.cancel();
		mmZoomTween = null;
	}
	mmZoomDrive = null;
}

// Absolute per-character camera values (source's DAD_CAM_X/Y + DAD_ZOOM).
function mmSetCam(who:String, x:Float, y:Float, z) {
	if (who == "dad") { mmDadPos = [x, y]; if (z != null) mmDadZoom = z; }
	else if (who == "bf") { mmBfPos = [x, y]; if (z != null) mmBfZoom = z; }
	else { mmGfPos = [x, y]; if (z != null) mmGfZoom = z; }
}

// The same target array mmSetCam writes, for the source's many one-coordinate
// writes (`BF_CAM_X = 1550`, `DAD_CAM_Y = 250`) that the trigger blocks below
// are full of.
function mmCamPos(who:String) {
	if (who == "dad") return mmDadPos;
	if (who == "bf") return mmBfPos;
	return mmGfPos;
}

function mmSetCamX(who:String, x:Float) {
	var p = mmCamPos(who);
	if (p != null) p[0] = x;
}

function mmSetCamY(who:String, y:Float) {
	var p = mmCamPos(who);
	if (p != null) p[1] = y;
}

function mmCamX(who:String):Float {
	var p = mmCamPos(who);
	return (p != null) ? p[0] : 0.0;
}

function mmCamY(who:String):Float {
	var p = mmCamPos(who);
	return (p != null) ? p[1] : 0.0;
}

// Source: triggerEventNote('Set Cam Zoom', z, '') - an empty target sets every
// character zoom *and* defaultCamZoom (see the 'Set Cam Zoom' branch in
// onEvent). Cancels any running zoom drive so the stored value takes over.
function mmSetZoomAll(z:Float) {
	mmZoomStop();
	mmBfZoom = z; mmDadZoom = z; mmGfZoom = z;
	defaultCamZoom = z;
}

function mmStepOverride(elapsed:Float) {
	if (mmPendLock != null) {
		mmPendLock.t += elapsed;
		if (mmPendLock.t >= mmPendLock.delay) {
			mmLockTo(mmPendLock.px, mmPendLock.py, mmPendLock.sec, mmPendLock.ease);
			mmPendLock = null;
		}
	}
	// Eased drives are FlxTweens on `mmZoomVal` and are not stepped here.
	if (mmZoomDrive != null && !mmZoomDrive.eased) {
		mmZoomDrive.t += elapsed;
		if (mmZoomDrive.t > mmZoomDrive.delay) {
			var p:Float = (mmZoomDrive.t - mmZoomDrive.delay) / mmZoomDrive.dur;
			if (p >= 1) {
				// Same release as the eased path: land exactly on the target, then
				// let mmApply publish it once and hand the zoom back to mmZoomFollow.
				mmZoomVal.v = mmZoomDrive.to;
				mmZoomDrive.done = true;
			} else {
				mmZoomVal.v = mmZoomDrive.from + (mmZoomDrive.to - mmZoomDrive.from) * p;
			}
		}
	}
	if (mmOvTo == null) return;
	if (mmPosTween != null) return; // an eased FlxTween owns the motion
	var t:Float = elapsed * 2.4;
	if (t > 1) t = 1;
	mmOv.x = mmOv.x + (mmOvTo[0] - mmOv.x) * t;
	mmOv.y = mmOv.y + (mmOvTo[1] - mmOv.y) * t;
	mmLockTime -= elapsed;
	if (mmLockTime <= 0) {
		mmOv.x = mmOvTo[0];
		mmOv.y = mmOvTo[1];
		mmOvTo = null; // FOLLOWCHARS = true again
	}
}

// True while a create-time snap should still own the camera (see MM_START_CAM):
// the whole countdown, for the four stages that snap one. Nothing else writes
// camFollow that early - chart events only start firing at songPosition 0 - so
// the hold is the source's own behaviour rather than an override.
function mmPreSong():Bool {
	if (mmStartCam == null || camFollow == null) return false;
	if (Conductor.songPosition >= 0) return false;
	// The fields, not `camFollow.set(x, y)`: FlxPoint.set is inlined, so HScript
	// finds no function there and the call throws Null Function Pointer - once
	// per frame for the whole countdown.
	camFollow.x = mmStartCam[0];
	camFollow.y = mmStartCam[1];
	return true;
}

// Writes the camera for the current frame (camFollow + defaultCamZoom).
function mmApply() {
	if (!mmInitDone) mmInit(); // safety net if postCreate never fired
	if (!mmActive) return;
	if (mmPreSong()) return;
	// FOLLOWCHARS going false freezes camFollowPos where it is (the source just
	// stops lerping it), so seed our override from the live camera first -
	// otherwise a stale lock position would make the camera jump.
	if (!mmFollow && mmFollowPrev && !mmLocked() && camFollow != null) {
		mmOv.x = camFollow.x;
		mmOv.y = camFollow.y;
	}
	mmFollowPrev = mmFollow;
	var px = null;
	var py = null;
	var eff:Int = mmTarget;
	if (mmLocked()) {
		px = mmOv.x;
		py = mmOv.y;
	} else {
		if (mmFollow) {
			eff = mmEffectiveTarget();
			var pos = mmPosFor(eff);
			if (pos != null) { px = pos[0]; py = pos[1]; }
		} else {
			px = mmOv.x;
			py = mmOv.y;
		}
	}
	if (px != null && camFollow != null) camFollow.setPosition(px, py);
	if (mmZoomDrive != null) {
		defaultCamZoom = mmZoomVal.v;
		FlxG.camera.zoom = mmZoomVal.v;
		// A finished drive is released here, *after* its final value has been
		// published, so the frame it ends on still lands on the target. From the
		// next frame mmZoomFollow owns defaultCamZoom again and the engine lerps
		// camGame.zoom back to the character's own zoom - the source's ZOOMCHARS.
		if (mmZoomDrive.done) mmZoomDrive = null;
	} else if (mmZoomFollow) {
		var z = mmZoomFor(eff);
		if (z != null) {
			defaultCamZoom = z;
			// CnE applies `defaultCamZoom` to camGame.zoom in its own update, but
			// only while its `camZooming` flag is on - and that flag is only ever
			// turned on by a note hit (PlayState.hx:1934). While it is off, nothing
			// moves camGame.zoom away from the last value a finished drive
			// published, which is how act 4's 1.5 "sad perspective" push could stay
			// on screen through BF's solo instead of settling on BF_ZOOM (0.7).
			// Mirror the engine's lerp in exactly that case, never while it runs.
			if (FlxG.camera != null && !mmEngineZooming() && !mmBlockZoom)
				FlxG.camera.zoom = FlxG.camera.zoom + (z - FlxG.camera.zoom) * mmZoomLerp();
		}
	}
}

// Is CnE itself lerping camGame.zoom toward defaultCamZoom this frame?
function mmEngineZooming():Bool {
	var ps = PlayState.instance;
	if (ps == null) return false;
	return Reflect.field(ps, "camZooming") == true;
}

// The rate that lerp uses (PlayState.camGameZoomLerp, Flags.DEFAULT_CAM_ZOOM_LERP).
function mmZoomLerp():Float {
	var ps = PlayState.instance;
	if (ps != null) {
		var l = Reflect.field(ps, "camGameZoomLerp");
		if (l != null) return Std.parseFloat(Std.string(l));
	}
	return 0.05;
}

// GFSINGDAD / GFSINGBF: while GF sings the source targets her camera instead of
// the section's character (PlayState.hx update()).
function mmEffectiveTarget():Int {
	if (mmTarget == 1) return mmGFSingBF ? 2 : 1;
	return mmGFSingDad ? 2 : 0;
}

// moveCamera() fires this every frame and uses `event.position` as camFollow.
function onCameraMove(event) {
	if (!mmInitDone) mmInit();
	if (!mmActive) return;
	if (mmLocked()) {
		event.position.x = mmOv.x;
		event.position.y = mmOv.y;
		return;
	}
	var who = mmWhoFor(event.strumLine);
	if (who != null && mmFollow) {
		mmTarget = mmIndexFor(who);
		mmSawMove = true;
	}
	mmApply();
}

// PlayState.hx:8155-8173. CNE has no DODGE action; SPACE is the source default.
// Share one immunity/cooldown state with Last Course and No Hope's attacks.
var mmDodging = false;
var mmDodgeCooling = false;

function mmDodgeBot() {
	return strumLines != null && strumLines.members.length > 1
		&& strumLines.members[1] != null && strumLines.members[1].cpu;
}

function mmStartDodge() {
	mmDodging = true;
	mmDodgeCooling = true;
	var target = boyfriend;
	var oldDance = target == null ? true : target.danceOnBeat;
	if (target != null) {
		target.playAnim("dodge", true, "LOCK");
		target.danceOnBeat = false;
	}
	new FlxTimer().start(0.4, function(tmr) {
		mmDodging = false;
		if (target != null) {
			target.danceOnBeat = oldDance;
			if (target.lastAnimContext == "LOCK") target.lastAnimContext = null;
		}
	});
	new FlxTimer().start(1, function(tmr) { mmDodgeCooling = false; });
}

function mmPollDodge() {
	var st = mmStageName();
	if (st != "turmoilsweep" && st != "castlestar") return;
	var ps = PlayState.instance;
	if (ps == null || ps.startingSong || ps.inCutscene || ps.endingSong
		|| mmDodging || mmDodgeCooling || mmDodgeBot()) return;
	if (FlxG.keys.justPressed.SPACE) mmStartDodge();
}

// Source specialAnim blocks note singing during a dodge without blocking scoring.
function onPlayerHit(event) {
	if (mmDodging) event.preventAnim();
}

// Runs after moveCamera() and before the camera updates, so this is authoritative.
function postUpdate(elapsed) {
	mmPollDodge();
	mmStepOverride(elapsed);
	mmApply();
	// PlayState.hx:5635-5641 + 7713-7716. Day Out and Overdue own
	// specialised layouts; Promotion and Oh God No need the generic flipchar
	// layout here, after CNE's normal icon positioning has run.
	var st = mmStageName();
	if ((st == "promoshow" || mmOgnSong()) && healthBar != null && iconP1 != null && iconP2 != null) {
		healthBar.flipX = true;
		if (healthBarBG != null) healthBarBG.flipX = true;
		iconP1.flipX = true;
		iconP2.flipX = true;
		var base = healthBar.x - healthBar.width * (1 - health / 2);
		iconP1.x = base - (iconP1.width - 610);
		iconP2.x = base - (iconP1.width - 696);
	}
}

// The fork's beat pulse while `blockzoom` is set (PlayState.hx:16151-16154):
//
//     if (curStage == 'bootleg' && blockzoom) {
//         tween(camHUD, {zoom: 1}, 1 beat, elasticOut);
//         tween(FlxG.camera, {zoom: defaultCamZoom}, 1 beat, elasticOut);
//     }
//
// It lives here because this script owns camGame/camHUD's zoom: `blockzoom`
// itself is set through `mmCamera.blockZoom` (Nourishing Blood's 10445/10455,
// see bootleg.hx), and the guard at mmApply's zoom lerp means the two writes do
// not fight. A stage script cannot carry its own beat hook without duplicating
// the zoom state, so the whole beat is handled in one place.
function beatHit() {
	if (!mmBlockZoom) return;
	var sec:Float = 1 * (1 / (Conductor.bpm / 60));
	if (camHUD != null) FlxTween.tween(camHUD, {zoom: 1}, sec, {ease: FlxEase.elasticOut});
	if (FlxG.camera != null && defaultCamZoom != null)
		FlxTween.tween(FlxG.camera, {zoom: defaultCamZoom}, sec, {ease: FlxEase.elasticOut});
}

// 'Triggers <song>' camera beats (PlayState.hx cases 'Triggers Alone' /
// 'Triggers All-Stars' / 'Triggers Paranoia' / 'Triggers Starman Slaughter').
//
// The event NAME says nothing about what value1 means: the source resolves
// 'Triggers Universal' to 'Triggers <song name>' and every song then reads the
// same value1 as its *own* trigger index (Paranoia's 7 is a dupe-shader
// multiplier, Alone's 7 is the 'Alone Mario' reveal). The song is therefore the
// only thing that can interpret value1 - here that is the stage, since each of
// these songs has its own (allfinal / betamansion / virtual). Without the gate
// every song's 'Triggers Universal' 7 or 10 ran the Alone branch, and 20+ charts
// in this mod use those values - e.g. Paranoia's 7 dragged the camera to
// (720,-100) at zoom 0.65 in the last seconds of the song.
function mmTriggers(raw, raw2) {
	var st = mmStageName();
	// The End's chart jumps from 8 straight to 9.5 (the source's own
	// re-dispatch of 9 plus the character swap), so a value that is not a whole
	// number is kept as a Float for the stage that owns one; everything else uses
	// the same Int it always did.
	var trigger = Std.parseInt(StringTools.trim(Std.string(raw)));
	var ftrig:Float = 0;
	if (trigger == null) {
		var f = Std.parseFloat(StringTools.trim(Std.string(raw)));
		if (f == null || f != f) return; // missing or NaN
		ftrig = f;
	} else ftrig = trigger;
	if (st == "endstage") { mmEndTrigger(ftrig); return; }
	if (trigger == null) return;
	if (st == "allfinal") { mmAllStarsCamera(trigger, raw2); return; }
	if (st == "execlassic") { mmExeTrigger(trigger); return; }
	if (st == "betamansion") { mmAloneTrigger(trigger); return; }
	if (st == "virtual") { mmParanoiaTrigger(trigger); return; }
	// exesequel / demiseport are one song each (Starman Slaughter, Demise), so no
	// song gate is needed here - unlike hatebg below.
	if (st == "exesequel") { mmStarmanTrigger(trigger); return; }
	if (st == "demiseport") { mmDemiseTrigger(trigger); return; }
	if (st == "turmoilsweep") { mmLastCourseTrigger(trigger); return; }
	if (st == "piracy") { mmPiracyTrigger(trigger); return; }
	if (st == "castlestar") { mmCastleTrigger(trigger); return; }
	if (st == "secretbg") { mmDictatorTrigger(trigger); return; }
	if (st == "meatworld") { mmOverdueTrigger(trigger); return; }
	// hatebg is shared by 'I Hate You', 'I Hate You Old' and 'Oh God No'; only
	// the last one has camera beats in the source, and they are gated on the
	// song for the same reason hatebg.hx gates its trigger block.
	if (st == "hatebg") { if (mmOgnSong()) mmOgnCameraBeat(trigger); return; }
}

// Does the current stage own any 'Triggers <song>' camera beats? (Used to keep
// the differential trace off the ~35 songs that have none.)
function mmHasTriggers():Bool {
	var st = mmStageName();
	return st == "allfinal" || st == "betamansion" || st == "virtual" || st == "exesequel"
		|| st == "demiseport" || st == "endstage" || st == "execlassic"
		|| st == "turmoilsweep" || st == "piracy" || st == "castlestar"
		|| st == "secretbg" || st == "meatworld"
		|| (st == "hatebg" && mmOgnSong());
}

// 'Triggers Its a me' (PlayState.hx:9498-9527) - the camera half only; the fire
// rings, the smoke plate, the darkening and the pixel blur live in
// data/stages/execlassic.hx. The stage is shared by 'Its a me' and 'Its a me
// Old', and only the modern one sends these beats, so the stage gate is enough.
function mmExeTrigger(trigger:Int) {
	if (trigger != 1) return;
	// 9516: `camGame.zoom -> 1.3` over 5s, sineIn. ZOOMCHARS is not touched by
	// this case in the source either, but the drive has to own the zoom while it
	// runs (mmApply would otherwise pull camGame.zoom back to the character's
	// zoom every frame), so this side turns ZOOMCHARS off and leaves it off - the
	// song is over by the time the 5s tween lands.
	mmZoomFollow = false;
	mmZoomDriveTo(1.3, 5, 0, FlxEase.sineIn);
}

// 'Triggers The End' (PlayState.hx:13277-13352) - the camera half only. The
// curtain, the 'end'/'Lets A Go' cards, the character swap and the world hides
// live in data/stages/endstage.hx. This is the one trigger group whose value is
// a *Float*: the chart never sends 9, it sends 9.5, which the source handles by
// re-dispatching 'Triggers Universal' '9' from inside case 9.5 - the same pair is
// mirrored here (the zoom writes of 9 are what 9.5 must end up applying), which
// is why both labels carry them.
function mmEndTrigger(trigger:Float) {
	switch (trigger) {
		case 3:                                             // 56 (21.0s)
			mmSetCamX("dad", 200);
		case 6:                                             // 64 (23.99s)
			mmSetCamX("dad", 420);
			mmSetCamY("dad", 350);
		case 8:                                             // 295 (110.62s)
			mmSetCamX("dad", 180);
		case 9:                                             // 296 (111.0s)
			mmEndZoomSnap(1);
		case 9.5:                                           // 296 (111.0s)
			// The chart sends 9.5, which re-dispatches 9 in the source; the same
			// zoom write is what it has to end up applying.
			mmEndZoomSnap(1);
		case 10:                                            // 298 (111.75s)
			mmEndZoomSnap(1.1);
	}
}

// `defaultCamZoom = BF_ZOOM = DAD_ZOOM = z;` - a snap, with Psych's ZOOMCHARS
// lerp doing the visible move. MM_CAM carries GF_ZOOM 0.45 for this stage; the
// source only ever writes BF/DAD.
function mmEndZoomSnap(z:Float) {
	mmZoomStop();
	mmDadZoom = z; mmBfZoom = z;
	defaultCamZoom = z;
	mmZoomFollow = true;
}

// 'Triggers Demise' (PlayState.hx:11162-11295) - the camera half only; the
// cutscene, the underground swap and the backdrop stand-ins live in
// data/stages/demiseport.hx. `demise` and `demise-old` share this stage, but
// only the regular chart sends these beats (as 'Triggers Universal'), so the
// stage gate is enough - and they are all whole numbers, which is what
// mmTriggers' Std.parseInt needs.
function mmDemiseTrigger(trigger:Int) {
	switch (trigger) {
		case 3:
			// 1.03s in, a 20.21s linear pull to 0.4 - the dark section. DAD_ZOOM is
			// 0.4 on this stage, so the drive is only the (very slow) transition and
			// mmZoomFollow takes the zoom back when it ends.
			mmZoomDriveTo(0.4, 20.21, 1.03, null);
		case 5:
			// The cutscene lunge: zoom to 1.2 over 0.5s, lock onto (200, 500) over
			// 0.4s expoOut, then one crochet later ease to (1200, -100) over 6s and
			// the zoom back to 0.8.
			mmZoomDriveTo(1.2, 0.5, 0, null);
			mmLockTo(200.0, 500.0, 0.4, FlxEase.expoOut);
			new FlxTimer().start(1 / (Conductor.bpm / 60), function(tmr) {
				mmZoomDriveTo(0.8, 5, 0, null);
				mmLockTo(1200.0, -100.0, 6, FlxEase.quadInOut);
			});
		case 9:
			mmFollow = !mmFollow;
		case 10:
			mmZoomFollow = !mmZoomFollow;
	}
}

// 'Triggers Starman Slaughter' (PlayState.hx:9530-9739) - the camera half only.
// The sprites, the character swaps and the iconGF/blackBarThingie work live in
// data/stages/exesequel.hx; the chart sends these beats as 'Triggers Universal',
// so both scripts see the same dispatch. Only starman-slaughter runs on the
// stage, which is why this needs no song gate (unlike hatebg).
//
// The interesting one is case 12: the source turns FOLLOWCHARS/ZOOMCHARS back on
// at the end of the *stage* script's dad-fall tween chain, and the two scripts
// cannot see each other's state, so this side schedules the same 1.75s
// (0.8 delay + 0.6 + 0.35) itself.
function mmStarmanTrigger(trigger:Int) {
	switch (trigger) {
		case 0:                                              // 96  (44.99s)
			mmSetCamX("bf", 1050);
		case 1:                                              // 100 (46.87s)
			mmSetCamX("bf", 1550);
		case 2:                                              // 132 (61.88s)
			mmSetCamX("gf", 850);
			mmGfZoom = 0.7;
			mmZoomFollow = true;
		case 3:                                              // 196 (91.88s)
			mmSetCamX("gf", 550);
			mmGfZoom = 0.5;
		case 5:                                              // 262 (122.81s)
			mmBfZoom = 0.7; mmDadZoom = 0.7; mmGfZoom = 0.7;
			mmSetCamY("dad", 800);
		case 6:                                              // 266 (124.69s)
			mmFollow = false;
			mmZoomFollow = false;
			mmLockToDelay(550, 250, 1.25, 0.25, FlxEase.quadInOut);
			mmZoomDriveTo(0.65, 1.5, 0, FlxEase.quadInOut);
		case 7:                                              // 269 (125.86s)
			mmZoomFollow = true;
			mmBfZoom = 0.6; mmDadZoom = 0.6;
		case 8:                                              // 273 (127.97s)
			mmFollow = true;
			mmSetCamY("dad", 250);
			mmLockToDelay(mmCamX("bf"), mmCamY("bf"), 1.875, 0, FlxEase.quadInOut);
		case 9:                                              // 336 (157.5s)
			mmDadZoom = 0.5; mmBfZoom = 0.5;
			defaultCamZoom = 0.5;
		case 10:                                             // 391 (183.28s)
			mmFollow = false;
			mmZoomFollow = false;
			mmLockToDelay(mmCamX("dad"), mmCamY("dad") + 75, 2.5, 0, FlxEase.quadInOut);
		case 11:                                             // 396 (185.62s)
			mmDadZoom = 0.6; mmBfZoom = 0.6;
			mmSetCamX("bf", 1200);
			// The source tweens camFollowPos.x only, leaving y where it is - and
			// case 10's 2.5s lock is still running here (183.28 + 2.5 = 185.78), so
			// this one takes over from the live locked value, as the source's second
			// tween on the same object does.
			mmLockToDelay(mmCamX("dad") + 150, mmCurY(), 2, 0, FlxEase.quadInOut);
			mmZoomDriveTo(mmDadZoom + 0.15, 2, 0, FlxEase.quadInOut);
		case 12:                                             // 404 (189.375s)
			defaultCamZoom = 0.5;
			mmZoomDriveTo(0.5, 0.5, 0, FlxEase.quadInOut);
			new FlxTimer().start(1.75, function(tmr) { mmFollow = true; mmZoomFollow = true; });
		case 14:                                             // 408 (191.25s / 208.13s)
			mmSetCamX("bf", 1550);
			mmBfZoom = 0.5;
		case 16:                                             // 512 (240s)
			mmLockToDelay(550, 250, 1, 0, FlxEase.expoOut);
		case 17:                                             // 514 (240.94s)
			mmZoomFollow = false;
			mmZoomDriveTo(0.7, 3, 0, FlxEase.linear);
	}
}

// 'Triggers Last Course' (PlayState.hx:10565-10609) - the group is *camera
// only*: not one sprite write, so the whole port of it is here. last-course is
// the only song on turmoilsweep, so the stage gate is enough.
//
// The source's own comments mark the beats (1 / 14 / 32 / 192 / 208 / 219 / 220
// / 224); the chart sends them through 'Triggers Universal'.
function mmLastCourseTrigger(trigger:Int) {
	switch (trigger) {
		case 0:                                              // beat 1   (0.4s)
			// ZOOMCHARS = false, defaultCamZoom = camGame.zoom = 1.2, then a 5s
			// cubeInOut tween of camGame.zoom to 1. The 1.2 has to be seeded before
			// the drive reads it - the drive publishes both camGame.zoom and
			// defaultCamZoom from its own starting value.
			mmZoomFollow = false;
			defaultCamZoom = 1.2;
			if (FlxG.camera != null) FlxG.camera.zoom = 1.2;
			mmZoomDriveTo(1, 5, 0, FlxEase.cubeInOut);
		case 2:                                              // beat 14  (5.6s)
			// FOLLOWCHARS = false; camFollowPos -> (420, 500) over 5s and
			// camGame.zoom -> 0.9 over 6.4s, both cubeInOut.
			mmFollow = false;
			mmLockToDelay(420, 500, 5, 0, FlxEase.cubeInOut);
			mmZoomDriveTo(0.9, 6.4, 0, FlxEase.cubeInOut);
		case 3:                                              // beat 32  (12.8s)
			mmFollow = true;
		case 4:                                              // beat 192 (76.8s)
			mmSetCamX("bf", 600);
		case 5:                                              // beat 208 (83.2s)
			mmSetCamX("bf", 970);
		case 6:                                              // beat 219 (87.6s)
			mmFollow = false;
			mmLockToDelay(720, 500, 0.42, 0, FlxEase.cubeIn);
		case 7:                                              // beat 220 (88.0s)
			// `triggerEventNote('Set Cam Zoom', '0.75', '')` plus a 0.4s cubeOut
			// tween of camGame.zoom to the same 0.75.
			mmSetZoomAll(0.75);
			mmZoomDriveTo(0.75, 0.4, 0, FlxEase.cubeOut);
		case 8:                                              // beat 224 (89.6s)
			mmFollow = true;
	}
}

// 'Triggers No Party' (PlayState.hx:10498-10564) - the camera half: case 0's
// `FlxTween.num(1, 1.2, 6, quadInOut, v -> BF_ZOOM = v)` and case 2's
// `BF_ZOOM = 1`. The sprites (the spotlight, the black bar, the dj board) live
// in data/stages/piracy.hx. `no-party` and `no-party-old` share the stage and
// only the regular chart sends these beats, so the stage gate is enough.
function mmPiracyTrigger(trigger:Int) {
	switch (trigger) {
		case 0:                                              // 92.16s
			// BF_ZOOM is written every frame for 6s. With ZOOMCHARS on that is
			// the visible zoom only while BF's section is playing, exactly like the
			// source - so the stored value is updated as well and the drive does the
			// same ramp for the frames where BF is the target.
			mmBfZoom = 1.2;
			mmZoomDriveTo(1.2, 6, 0, FlxEase.quadInOut);
		case 2:                                              // 109.44s
			mmZoomStop();
			mmBfZoom = 1;
	}
}

// 'Triggers No Hope' (PlayState.hx:10611-10649) - the only camera write in the
// group is case 0's 3s quadInOut tween of camFollowPos to (DAD_CAM_X, DAD_CAM_Y).
// FOLLOWCHARS is left on by the source, and the follow target *is* DAD_CAM, so
// the tween and the follow agree on where the camera lands - which is why a lock
// is a faithful stand-in here (the sprite half is in data/stages/castlestar.hx).
function mmCastleTrigger(trigger:Int) {
	if (trigger != 0) return;                            // 52.17s
	mmLockToDelay(mmCamX("dad"), mmCamY("dad"), 3, 0, FlxEase.quadInOut);
}

// 'Triggers Dictator' (PlayState.hx:13808-13884) - the camera half. The
// explosion, the curtain and the Bullet Bill warning live in
// data/stages/secretbg.hx. `dictator` and `dictator-old` share the stage and
// only the regular chart sends these beats.
//
// Cases 5/6 are the GF-sing gimmick this stage keeps for itself: the source
// turns GFSINGDAD/GFSINGBF on (5) and off (6) and the *stage* exception in its
// note-hit code (`if (curStage != 'secretbg') GFSINGDAD = false;`) leaves them
// set between the two, so the girlfriend dances dad's notes and the camera
// points at her. Both flags and that exception are in this script already, so
// the two cases only have to flip them.
function mmDictatorTrigger(trigger:Int) {
	var beat:Float = 1 / (Conductor.bpm / 60);
	switch (trigger) {
		case 0:                                          // 0s
			// snapCamFollowToPos(220, -390): both camFollow and camFollowPos.
			mmFollow = false;
			mmLockTo(220.0, -390.0, 0, null);
		case 1:                                          // 2.09s
			mmDadPos = [220, 430];
			mmLockToDelay(220, 380, 4, 0, FlxEase.quadInOut);
			mmZoomDriveTo(1.2, 22.5 * beat, 0, FlxEase.quadInOut);
		case 2:                                          // 14.09s
			mmZoomDriveTo(1.3, 1, 0.5 * beat, FlxEase.backOut);
		case 3:                                          // 15.65s
			mmZoomDriveTo(0.8, 2 * beat, 0, FlxEase.quadIn);
		case 4:                                          // 16.69s
			mmFollow = true;
		case 5:                                          // 66.78s / 116.86s
			// `defaultCamZoom = 0.7` is a no-op in the source: ZOOMCHARS rewrites
			// it from GF_ZOOM every frame, and GF_ZOOM *is* 0.7 here (MM_CAM), so
			// only the two flags do anything.
			mmGFSingBF = true;
			mmGFSingDad = true;
		case 6:                                          // 75.13s / 127.30s
			mmGFSingBF = false;
			mmGFSingDad = false;
		case 7:                                          // 160.70s
			// FOLLOWCHARS = false, camFollowPos -> (1020, 550) over 2 beats
			// (quadIn), camGame.zoom -> 1 over 0.3s quadOut. The source's
			// `defaultCamZoom = 1` is overwritten by ZOOMCHARS on the next frame,
			// so only the tween is visible.
			mmFollow = false;
			mmLockToDelay(1020, 550, 2 * beat, 0, FlxEase.quadIn);
			mmZoomDriveTo(1, 0.3, 0, FlxEase.quadOut);
		case 8:                                          // 161.74s
			mmFollow = false;
			mmLockToDelay(mmCurX(), 50, 1 * beat, 0, FlxEase.quadOut);
		case 10:                                         // 117.39s-124.70s, 15x
			// `GF_ZOOM += 0.03` - the climb into the GF close-up of the second
			// GF-sing section (0.7 -> 1.15).
			mmGfZoom = ((mmGfZoom != null) ? mmGfZoom : 0.7) + 0.03;
	}
}

// 'Triggers Overdue' (PlayState.hx:13943-14130) - the camera half. The meat
// groups, the castle floor/ceiling, the hallways, the gun ammo, the third icon
// and the poison drain live in data/stages/meatworld.hx.
//
// Cases 14/15/16 are also delivered as the chart's own 'Set Cam Pos' / 'Set Cam
// Zoom' events (the conversion emits them next to the trigger), so the writes
// below are duplicated there for `overdue-old`, whose chart sends the trigger
// values without those events.
function mmOverdueTrigger(trigger:Int) {
	switch (trigger) {
		case 2:                                          // 20.21s (beat 2)
			// Source 13967-13970: `isCameraOnForcedPos = true;` +
			// `tween(camFollowPos, {x: -80, y: 450}, 1.64, expoInOut)`. FOLLOWCHARS
			// is **not** touched - the fork reads `isCameraOnForcedPos` nowhere (see
			// the 'Camera Follow Pos' entry), so all the beat does is nudge
			// camFollowPos towards (-80, 450) - meatworld's own DAD_CAM row - while
			// the section lerp keeps pulling it back onto the live section's camera.
			// Turning the follow *off* here is what froze the camera: the lock
			// releases after its 1.64s, but with FOLLOWCHARS DOWN nothing ever put
			// the camera back on a character, so it sat at (-80, 450) from 21.9s
			// until case 4 (84.71s) - the reported "camera character focus is broken
			// after Luigi goes into his monster form", with the meat/mouth slam of
			// cases 3/4 as the part that finally put it right. Only case 14 turns the
			// follow off (its own `FOLLOWCHARS = false; ZOOMCHARS = false;`, 14125)
			// and case 4 turns it back on (13998) - which is the source's real, 1.34s
			// camera window.
			mmLockToDelay(-80, 450, 1.64, 0, FlxEase.expoInOut);
		case 3:                                          // 84.32s
			mmZoomDriveTo(0.75, 0.4, 0, FlxEase.cubeInOut);
		case 4:                                          // 84.71s
			mmFollow = true;
			mmZoomFollow = true;
			mmBfZoom = 0.45;
			mmDadZoom = 0.35;
		case 5:                                          // 135.16s
			mmBfZoom = 0.5;
			mmDadZoom = 0.4;
			mmSetCam("bf", 1000, 450, null);
			mmLockToDelay(1000, 450, 5, 0, FlxEase.sineInOut);
			mmZoomDriveTo(0.5, 5, 0, FlxEase.sineInOut);
		case 7:                                          // 171.79s
			// The three `triggerEventNote`s of the case, re-dispatched by the source
			// itself and by the chart: 'Set Cam Pos' 1000, 500 bf + 'Set Cam Pos'
			// 1000, 150 dad + 'Set Cam Zoom' 0.5 bf + 0.35 dad.
			mmSetCam("bf", 1000, 500, 0.5);
			mmSetCam("dad", 1000, 150, 0.35);
		case 14:                                         // 83.37s
			mmBfZoom = 0.45;
			mmSetCam("bf", 675, 600, 0.45);
			mmFollow = false;
			mmZoomFollow = false;
			mmLockToDelay(675, 600, 1.1, 0, FlxEase.quadInOut);
			mmZoomDriveTo(0.45, 0.7, 0, FlxEase.quadInOut);
		case 15:                                         // 109.89s
			mmDadZoom = 0.25;
			mmBfZoom = 0.25;
			mmSetCam("dad", 500, 150, null);
			mmSetCam("bf", 1000, 350, null);
		case 16:                                         // 130.74s / 138.67s
			mmDadZoom = 0.35;
			mmBfZoom = 0.35;
			mmSetCam("dad", 300, 300, null);
			mmSetCam("bf", 900, 500, null);
	}
}

// 'Triggers Oh God No' (PlayState.hx:11296-11376) camera half. The sprite half
// (fires, degrad, cinema bars, the luigi cut, the silhouettes) lives in
// data/stages/hatebg.hx. The source also flips DAD_CAM_EXTEND between 0 and
// BF_CAM_EXTEND here; that is only the note-hit camera bounce (camDisplaceX/Y),
// which this port does not model at all - see PORT_NOTES.md.
//
//   0 - ZOOMCHARS = false, defaultCamZoom = 0.45, DAD_CAM = (600, 350), then
//       `FlxTween.tween(this, {defaultCamZoom: 0.8}, 11)` (linear).
//       camGame.zoom is not set directly: with ZOOMCHARS off the source leaves
//       defaultCamZoom alone and Psych lerps camGame.zoom toward it, so the
//       dip to 0.45 is an ease and the 11s ramp is what the player sees rise.
//       Both halves go through the drive, which is the only writer of
//       camGame.zoom / defaultCamZoom while it runs.
//   2 - cancels extraTween (with it the 11s ramp), DAD_CAM = (620, 290), then
//       `FlxTween.tween(this, {defaultCamZoom: 0.7}, 1)` whose onComplete turns
//       ZOOMCHARS back on (defaultCamZoom becomes the character's zoom again).
function mmOgnCameraBeat(trigger:Int) {
	switch (trigger) {
		case 0:
			mmZoomStop();
			// The ease has to start from the live zoom, and mmZoomDriveTo reads it
			// off defaultCamZoom - seed it before the drive takes over.
			if (FlxG.camera != null) defaultCamZoom = FlxG.camera.zoom;
			mmZoomFollow = false;
			mmDadPos = [600, 350];
			mmZoomDriveTo(0.45, 0.5, 0, FlxEase.quadOut);
			new FlxTimer().start(0.5, function(tmr) { mmZoomDriveTo(0.8, 11, 0, null); });
		case 2:
			mmZoomStop();
			mmDadPos = [620, 290];
			mmZoomDriveTo(0.7, 1, 0, null);
			new FlxTimer().start(1, function(tmr) { mmZoomFollow = true; });
	}
}

// 'Triggers Alone' (PlayState.hx). 7 = the 'Alone Mario' reveal, 10 = back to
// the section camera at zoom 0.8.
function mmAloneTrigger(trigger:Int) {
	if (trigger == 7) {
		// 'Alone Mario' reveal: `triggerEventNote('Set Cam Zoom', '0.55', '')`
		// sets all three per-character zooms *and* defaultCamZoom to 0.55,
		// FOLLOWCHARS = ZOOMCHARS = false, DAD_CAM = (720, 75), camGame.zoom
		// tweened to 0.65 over 2s quadInOut, camFollowPos tweened to
		// (720, DAD_CAM_Y - 175 = -100) over 2s cubeInOut, and *both* flags come
		// back on in that tween's onComplete - i.e. the camera drifts the last
		// 175px back up to the new DAD_CAM when the reveal ends. The lock carries
		// the tween; the timer is the onComplete.
		mmFollow = false;
		mmZoomFollow = false;
		mmDadPos = [720, 75];
		mmDadZoom = 0.55;
		mmBfZoom = 0.55;
		mmGfZoom = 0.55;
		defaultCamZoom = 0.55;
		mmLockTo(720.0, -100.0, 2.0, FlxEase.cubeInOut);
		mmZoomDriveTo(0.65, 2, 0, FlxEase.quadInOut);
		new FlxTimer().start(2, function(tmr) { mmFollow = true; mmZoomFollow = true; });
	} else if (trigger == 10) {
		// DAD_CAM = (420, 450), 'Set Cam Zoom' 0.8 - all three zooms and
		// defaultCamZoom, not just dad's.
		mmOvTo = null;
		mmFollow = true;
		mmZoomFollow = true;
		mmDadPos = [420, 450];
		mmDadZoom = 0.8;
		mmBfZoom = 0.8;
		mmGfZoom = 0.8;
		defaultCamZoom = 0.8;
	}
}

// 'Triggers Paranoia' (PlayState.hx). Only its two camera triggers are handled
// here; the sprites they move (turtle / vwall / gfwasTaken / ...) belong to
// data/stages/virtual.hx.
//
//   6 (Triggers Universal 6, 245.4s): FOLLOWCHARS = ZOOMCHARS = false,
//     camFollowPos -> (1200, 60) over 0.7s quadOut, and camGame.zoom *and*
//     defaultCamZoom -> 1.4 over 4s quadIn. Both zoom writes have to go through
//     the drive: an active drive owns camGame.zoom/defaultCamZoom, so the stage
//     script's own second tween on defaultCamZoom could never survive it.
//   1 (Triggers Paranoia 1, 260s; the `noVirtual` branch, and noVirtual defaults
//     to true): FOLLOWCHARS = ZOOMCHARS = true again, camFollowPos snapped to
//     (520, -1000) and then tweened x 520->920 (3s quadInOut PINGPONG) and
//     y ->720 (3s expoOut) -> 520 (5s quadInOut PINGPONG) - the camera flies up
//     out of the stage and then drifts, which is the look of the end of the
//     song. The source tweens `camFollow` (Psych's follow *target*) here as well,
//     but its own update rewrites camFollow from the section character every
//     frame while FOLLOWCHARS is on, so that tween never shows - no equivalent
//     here. The pingpongs run until trigger 4 cancels every `extraTween`.
//   4 (Triggers Paranoia 4, 324s): that cancel - the flight ends and the
//     section camera takes over again.
function mmParanoiaTrigger(trigger:Int) {
	switch (trigger) {
		case 6:
			mmFollow = false;
			mmZoomFollow = false;
			mmLockTo(1200.0, 60.0, 0.7, FlxEase.quadOut);
			mmZoomDriveTo(1.4, 4, 0, FlxEase.quadIn);
		case 1:
			mmFollow = true;
			mmZoomFollow = true;
			mmOrbit();
		case 4:
			mmOrbitStop();
	}
}

// The 'Triggers Paranoia' 1 fly-around. The camera is locked onto `mmOv` with
// three pingpong FlxTweens, so FOLLOWCHARS cannot take it back - the source's
// camFollowPos tweens do the same, with its `elapsed * 2.4` FOLLOWCHARS lerp
// (~4% a frame) trailing them.
function mmOrbit() {
	mmOrbitStop();
	mmOv.x = 520.0;
	mmOv.y = -1000.0;
	mmOvTo = [520.0, -1000.0]; // locked: mmApply publishes mmOv
	mmLockTime = 999999.0;     // never expires; mmPosTween keeps mmStepOverride off it
	mmPosTween = FlxTween.tween(mmOv, {x: 920}, 3, {ease: FlxEase.quadInOut, type: FlxTween.PINGPONG});
	mmOrbitTweens.push(FlxTween.tween(mmOv, {y: 720}, 3, {ease: FlxEase.expoOut, onComplete: function(twn) {
		mmOrbitTweens.push(FlxTween.tween(mmOv, {y: 520}, 5, {ease: FlxEase.quadInOut, type: FlxTween.PINGPONG}));
	}}));
}

// Ends the fly-around (source: the `for (tween in extraTween) tween.cancel()`
// of 'Triggers Paranoia' 4). `mmFollow` is already true by then, so FOLLOWCHARS
// takes the camera back the way the source does.
function mmOrbitStop() {
	if (mmPosTween != null) {
		mmPosTween.cancel();
		mmPosTween = null;
	}
	for (t in mmOrbitTweens) t.cancel();
	mmOrbitTweens = [];
	mmOvTo = null;
	mmLockTime = 0.0;
}

// Note hits drive GFSINGDAD (opponent side) and GFSINGBF (player side), plus
// the allfinal per-note camera pushes. Mirrors the source's two note-hit blocks
// (PlayState.hx opponent block + player block):
//   opponent: 'GF Sing' -> GFSINGDAD = true, 'GF Duet'/'' -> false,
//             'Yoshi Note'/'AS Bud Note' leave it alone.
//   player:   every hit resets GFSINGBF, 'GF Sing' -> true.
function onNoteHit(event) {
	var nt = event.noteType;
	var secretbg = (mmStageName() == "secretbg");

	if (event.player) {
		// Player side (source resets on every hit unless the stage is secretbg).
		if (nt == "GF Sing") mmGFSingBF = true;
		else if (!secretbg) mmGFSingBF = false;
		return;
	}

	if (nt == "GF Sing") mmGFSingDad = true;
	else if (nt == "GF Duet") mmGFSingDad = false;
	else if (nt != "Yoshi Note" && nt != "AS Bud Note" && !secretbg) mmGFSingDad = false;

	if (mmStageName() == "allfinal") {
		if (nt == "Yoshi Note") mmSetCam("dad", 780, 450, 0.7);
		else if (nt == "AS Bud Note") mmSetCam("dad", 520, 350, 0.6);
		else if (nt == null || nt == "") {
			// Resolve the opponent through the strumline: the `dad` global still names
			// the character the act 2/0 swap replaced, so this branch never fired for
			// wario and his camera beat fell through to the generic one.
			var mmWd = mmRoleChar(0);
			if (mmWd == null) mmWd = dad;
			if (mmWd != null && mmWd.curCharacter == "w4r") mmSetCam("dad", 260, 450, 0.7);
		}
	}
}

function onEvent(event) {
	if (!mmInitDone) mmInit();
	var name = event.event.name;

	if (name == "Camera Movement") {
		// params: [strumline target]. Mirrors the source's mustHitSection branch.
		var t = Std.parseInt(event.event.params[0]);
		if (t != null) mmTarget = t;

	} else if (name == "Set Cam Pos") {
		// params: "x, y", who
		mmPendLock = null;
		var pos = mmVec(event.event.params[0]);
		if (pos == null) return;
		var who = (event.event.params.length > 1) ? StringTools.trim(Std.string(event.event.params[1]).toLowerCase()) : "";
		if (who == "bf" || who == "boyfriend") mmBfPos = pos;
		else if (who == "gf" || who == "girlfriend") mmGfPos = pos;
		else if (who == "dad" || who == "opponent") mmDadPos = pos;

	} else if (name == "Camera Follow Pos") {
		// 9249-9263 sets `isCameraOnForcedPos = false`, writes camFollow from the
		// two values (an unparsable component becomes 0) and sets the flag true
		// again - but **nothing in this fork ever reads that flag**. Stock Psych's
		// `if (isCameraOnForcedPos) camFollowPos.setPosition(camFollow.x, ...)` was
		// replaced by the FOLLOWCHARS-gated lerp at 7359, and the section block
		// rewrites camFollow every frame before that lerp (7332-7352), so the
		// write only survives on frames where FOLLOWCHARS is off - and there
		// camFollow is read by nothing at all. The event is therefore inert in
		// this mod's source.
		//
		// Pinning the camera here (which the port used to do) is stock-Psych
		// behaviour: it held Day Out's camera at (720, 450) for the 56s between
		// that chart event (100.33s) and case 6's release. The write itself is
		// kept, because it is literally what the source does - mmApply overwrites
		// camFollow later in the frame, exactly like the section block does.
		var fx = mmNum(event.event.params[0], null);
		var fy = mmNum(event.event.params[1], null);
		if (fx == null && fy == null) {
			// `Camera Follow Pos '', ''`: `isCameraOnForcedPos = false`, also inert
			// in the fork. This only clears a pin one of our own stage scripts set.
			mmReleaseForce();
			return;
		}
		if (camFollow != null) {
			camFollow.x = (fx != null) ? fx : 0.0;
			camFollow.y = (fy != null) ? fy : 0.0;
		}

	} else if (name == "Set Cam Zoom") {
		// params: zoom, who (empty who = every target + defaultCamZoom)
		mmZoomStop();
		var z = mmNum(event.event.params[0], null);
		if (z == null) return;
		var who = (event.event.params.length > 1) ? StringTools.trim(Std.string(event.event.params[1]).toLowerCase()) : "";
		if (who == "bf" || who == "boyfriend") mmBfZoom = z;
		else if (who == "gf" || who == "girlfriend") mmGfZoom = z;
		else if (who == "dad" || who == "opponent") mmDadZoom = z;
		else {
			mmBfZoom = z;
			mmDadZoom = z;
			mmGfZoom = z;
			defaultCamZoom = z;
		}

	} else if (StringTools.startsWith(name, "Triggers ")) {
		if (!mmHasTriggers()) return;
		var p2 = (event.event.params.length > 1) ? event.event.params[1] : "";
		mmTriggers(event.event.params[0], p2);
	}
}

// ---------------------------------------------------------------------------
// All-Stars (allfinal) camera per act - PlayState.hx case 'Triggers All-Stars'.
// Group/value pairs are the chart's 'Triggers Universal' params. Only the
// camera state is handled here; the visual choreography lives in
// data/stages/allfinal.hx.
// ---------------------------------------------------------------------------
function mmAllStarsCamera(group, raw2) {
	if (group == null) return;
	var val:Int = Std.parseInt(StringTools.trim(Std.string(raw2)));
	if (val == null) val = 0;

	switch (group) {
		case 0:
			if (val == 3) { mmSetCam("dad", 520, 350, 0.6); mmFollow = true; mmZoomFollow = true; }
		case 2:
			switch (val) {
				case 0:
					mmSetCam("dad", 480, -220, 2);
					mmSetCam("bf", 520, 450, 0.8);
					mmFollow = true; mmZoomFollow = true;
				case 1:
					mmSetCam("gf", 520, 350, 0.7);
					mmFollow = true; mmZoomFollow = true;
				case 2:
					mmSetCam("dad", 260, 450, 0.7);					case 5:
						// omega scream: stop following, push the camera down and zoom in.
						// Source: camFollowPos.y -> DAD_CAM_Y - 250 over 0.8s, startDelay
						// 0.2, cubeOut; camGame.zoom -> DAD_ZOOM + 0.5 over 1s quadInOut.
						// The 1.1s timer below restores ZOOMCHARS, which is what pulls the
						// zoom back to DAD_ZOOM - that only works because the drive now
						// releases itself when its tween ends (see mmZoomDriveTo/mmApply).
					mmFollow = false; mmZoomFollow = false;
					var dady = (mmDadPos != null) ? mmDadPos[1] : 450;
					var dadz = (mmDadZoom != null) ? mmDadZoom : 0.7;
					mmLockToDelay(mmCurX(), dady - 250, 0.8, 0.2, FlxEase.cubeOut);
					mmZoomDriveTo(dadz + 0.5, 1, 0, FlxEase.quadInOut);
					new FlxTimer().start(1.1, function(tmr) { mmFollow = true; mmZoomFollow = true; });
				case 6:
					// camera pans lower for the bow. Source: camFollowPos.y -> 130 over
					// 0.6s quadOut, camGame.zoom -> 0.9 over 0.6s quadOut.
					mmFollow = false; mmZoomFollow = false;
					mmLockToDelay(mmCurX(), 130, 0.6, 0, FlxEase.quadOut);
					mmZoomDriveTo(0.9, 0.6, 0, FlxEase.quadOut);
			}
		case 3:
			switch (val) {
				case 0:
					mmSetCam("dad", -800, 400, 0.8);
					mmSetCam("bf", 350, 475, 0.6);
					mmFollow = true; mmZoomFollow = true;
					// Source: camFollowPos -> DAD_CAM over 3.2s, startDelay 1.6,
					// quadInOut; camGame.zoom -> DAD_ZOOM over 3.2s, startDelay 1.6,
					// quadOut.
					mmLockToDelay(-800, 400, 3.2, 1.6, FlxEase.quadInOut);
					mmZoomDriveTo(0.8, 3.2, 1.6, FlxEase.quadOut);
				case 2:
					mmSetCam("dad", -400, (mmDadPos != null) ? mmDadPos[1] : 400, 0.65);
				case 4:
					mmSetCam("dad", -240, 400, 0.5);
					mmSetCam("bf", -240, 400, 0.5);
					mmZoomFollow = false;
					// Source: camGame.zoom *and* defaultCamZoom -> 0.5 over 0.8s
					// cubeInOut.
					mmZoomDriveTo(0.5, 0.8, 0, FlxEase.cubeInOut);
				case 7:
					// Source: FOLLOWCHARS = false, camFollowPos.y -> BF_CAM_Y + 350 over
					// 1.6s quadInOut, camGame.zoom -> 0.6 over 1.2s quadInOut and then
					// -> 8 over 0.35s expoIn - the push into Ultra M's mouth. Both zoom
					// steps go through the drive because the drive owns
					// FlxG.camera.zoom / defaultCamZoom; the act script's own
					// camGame.zoom tween would be overwritten and the mouth zoom never
					// happened.
					mmFollow = false;
					var bfy = (mmBfPos != null) ? mmBfPos[1] : 400;
					mmLockToDelay(mmCurX(), bfy + 350, 1.6, 0, FlxEase.quadInOut);
					mmZoomDriveTo(0.6, 1.2, 0, FlxEase.quadInOut);
					new FlxTimer().start(1.2, function(tmr) { mmZoomDriveTo(8, 0.35, 0, FlxEase.expoIn); });
			}
		case 4:
			switch (val) {
				case 0:
					mmSetCam("dad", 190, 240, 2.5);
					mmSetCam("bf", 720, 480, 1.3);
					mmFollow = true; mmZoomFollow = true;
					mmZoomStop();
				case 1:
					// sad perspective transition. Source: camFollowPos -> BF_CAM over
					// 1.6s quadInOut, camGame.zoom -> BF_ZOOM over 1.6s quadInOut.
					mmSetCam("bf", 1000, 550, 1.5);
					mmLockToDelay(1000, 550, 1.6, 0, FlxEase.quadInOut);
					mmZoomDriveTo(1.5, 1.6, 0, FlxEase.quadInOut);
					// Source ends that 1.6s quadInOut tween to (BF_CAM_X, BF_CAM_Y)
					// with onComplete `camFollowPos.x += 40; camFollowPos.y -= 250`,
					// so the camera settles 40 right / 250 above BF_CAM before
					// FOLLOWCHARS drifts it back. Fires on the lock's own 1.6s.
					new FlxTimer().start(1.6, function(tmr) { mmLockToDelay(1040, 300, 0, 0, null); });
				case 2:
					mmSetCam("bf", (mmBfPos != null) ? mmBfPos[0] : 720, 425, 0.7);
				case 3:
					mmSetCam("bf", (mmBfPos != null) ? mmBfPos[0] : 720, (mmBfPos != null) ? mmBfPos[1] : 425, 0.6);
				case 5:
					mmZoomFollow = false;
					// Source: camGame.zoom -> 0.5 over 0.8s (quadInOut), then -> 1.2 over
					// 0.8s (cubeIn) on completion. Both steps have to go through the
					// drive - an active drive rewrites camGame.zoom *and* defaultCamZoom
					// every frame, so the act script's own tweens were being overwritten
					// and the zoom sat at 0.5 (same class of bug as the act 3 mouth zoom).
					mmZoomDriveTo(0.5, 0.8, 0, FlxEase.quadInOut);
					new FlxTimer().start(0.8, function(tmr) { mmZoomDriveTo(1.2, 0.8, 0, FlxEase.cubeIn); });
				case 6:
					var bfx = (mmBfPos != null) ? mmBfPos[0] : 720;
					var bfy2 = (mmBfPos != null) ? mmBfPos[1] : 480;
					// Source: DAD_CAM_X = BF_CAM_X -= 50; DAD_CAM_Y = BF_CAM_Y. BF_CAM_X
					// itself is mutated, and 4/13 reads it back as BF_CAM_X + 150, so
					// the BF target has to move with it.
					mmSetCam("bf", bfx - 50, bfy2, null);
					mmSetCam("dad", bfx - 50, bfy2, null);
					mmLockToDelay(bfx - 50, bfy2, 0.1, 0, FlxEase.linear);
					// Source: triggerEventNote('Set Cam Zoom', '1.05', ''). Stored here,
					// and shown for a frame by 4/7's `camGame.zoom = BF_ZOOM`.
					mmSetZoomAll(1.05);
				case 7:
					mmFollow = false;
					mmZoomFollow = false;
					// Source: ZOOMCHARS = true, `camGame.zoom = BF_ZOOM` (1.05, from 4/6)
					// and then 'Set Cam Zoom' 0.7 - the visible zoom settles at 0.7 and
					// BF_ZOOM becomes 0.7. 4/13's `BF_ZOOM + 0.4` reads it back, so the
					// stored value must be updated here (it used to stay at 0.6 from 4/3,
					// making 4/13 zoom to 1.0 instead of 1.1).
					mmSetZoomAll(0.7);
					mmZoomDriveTo(0.7, 0.1, 0, FlxEase.linear);
				case 8:
					mmZoomFollow = false;
					mmZoomDriveTo(0.1, 7.2, 0, FlxEase.quadIn);
				case 13:
					var bfz = (mmBfZoom != null) ? mmBfZoom : 0.7;
					// Source: camGame.zoom -> BF_ZOOM + 0.4 over 0.8s cubeIn (both the
					// zoom and the camFollowPos lunge use cubeIn).
					mmZoomDriveTo(bfz + 0.4, 0.8, 0, FlxEase.cubeIn);
					var bx = (mmBfPos != null) ? mmBfPos[0] : 1000;
					var by = (mmBfPos != null) ? mmBfPos[1] : 550;
					mmLockToDelay(bx + 150, by + 50, 0.8, 0, FlxEase.cubeIn);
					// Source snaps camFollowPos straight back to (BF_CAM_X, BF_CAM_Y) once
					// the 0.8s tween into the death close-up ends, so the camera lunges
					// towards BF and then returns. Same here with a `sec` of 0 (the lock
					// expires on the next step and snaps exactly, then FOLLOWCHARS
					// resumes). It is scheduled with a timer rather than a second
					// mmLockToDelay call, because that would overwrite the pending lock
					// and the lunge itself would never happen.
					new FlxTimer().start(0.8, function(tmr) { mmLockToDelay(bx, by, 0, 0, null); });				case 15:
					mmSetCam("dad", 570, 440, 1);
					mmFollow = true; mmZoomFollow = true;
					mmZoomStop();
			}
		}
}
