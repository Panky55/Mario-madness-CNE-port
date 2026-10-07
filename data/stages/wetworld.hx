

// === MM stage triggers (auto) ===
// 'Triggers Abandoned' - ported from PlayState.hx (case 'Triggers Abandoned',
// 13158-13275). Only abandoned runs on this stage, and its chart sends these
// beats as 'Triggers Universal' with a *float* value1 (3.5 is a real case), so
// both event names are accepted and the value is parsed as a float.
//
// This stage's whole presentation lives on Psych's `camEst` - the floor, the
// water, the black curtain, the TV static and the laughing Luigi are all
// `cameras = [camEst]`, which is exactly what the stage extractor skips - so the
// trigger block rebuilds them on a camera of its own (the same shape
// allfinal.hx's `mmEst` and hatebg.hx's `mmOgnCamera` use). Their creation order
// is the source's own (4026-4135: fondaso ... thefog, flood, blackBarThingie,
// redTVStat, redTV, luigilaugh, redStat), because that is what decides who draws
// over whom - the curtain in particular is added *after* the water and *before*
// the two TV feeds, so the water starts hidden behind the black plate (the song
// opens on a black screen) and the static fades in on top of it. The whole
// `postCreate` below has to keep that order; see the note there.
//   4027       `gfGroup.visible = false;` - she is not in this song at all.
//
// Stage-level behaviour that comes with the case:
//   4025-4026  `noCount = true; noHUD = true;` -> the engine's READY/SET/GO are
//              dropped (onCountdown cancelled) and camHUD starts at alpha 0 (the
//              chart's own 'Ocultar HUD' 2 brings it back at 12.8s).
//   4090-4093  `add(fondaso2); add(atra2); add(fondaso); add(atra);` - the 2D
//              pair the stage loads on, then the 3D pair above it, hidden until
//              case 10 (which shows the 3D set without hiding the 2D one, so
//              the two must keep this order). The XML lists them the same way.
//   4312-4341  `add(dadGroup)` (4312) ... `add(adel); add(adel2);` (4316-4317)
//              ... `add(boyfriendGroup)` (4341): the two front plates sit
//              between the fighters, over dad and under BF, so postCreate
//              re-seats them there (the XML only parks them at the bottom).
//   6678       a second instrumental (`wetworldinstALT`) that the flood crossfades
//              in, and 7394-7425 the flood itself: it rises, drains health and
//              ducks the inst/vocals against it. All of it is ported in
//              update() below (mmAltBuild/mmAltCross).
//   7841-7857  the intro: camEst zooms 0.5 -> 1 over 12s while redTV and
//              redTVStat fade up over 10s. `ClientPrefs.flashing` is not
//              script-reachable and the port always takes the flashing branch
//              (exeport.hx does the same), so the non-flashing `justStat` /
//              `redTVImg` pair is not built - `redTVImg` is dead code anyway,
//              the source never `add()`s it.
//   16733-16746 the per-step `adel`/`adel2`/`boyfriend` alpha toggle, driven off
//              the section's mustHitSection. A Codename chart has no such field,
//              but the conversion emits the same information as its 'Camera
//              Movement' events, so that is what drives it here (the same proxy
//              allfinal.hx uses for its pupil sway).
//
// The source's TV stack (`tvEffect`/`oldTV`, 4028-4029) *is* ported now - see
// the "The TV shader stack" section below - including the BrightnessContrast
// filter its own triggers 5/6 write (the source's `contrastFX`). NOT ported: the
// `warningPopup` sound trigger (the sprite itself is ported), and the
// create-time `vid` `VideoSprite` of 4145-4152, which is dead in the source too
// (started hidden, destroyed on finish, never shown). The live one - `luigidies`
// at beats 228/248 - is ported in `mmDyingVideo`/`beatHit` below, with the
// source's `blend = MULTIPLY` (5832) as its one omission.

// ---------------------------------------------------------------------------
// camEst
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
// would put this layer *above* camHUD - over the notes and the HUD - so it is
// slid back into camHUD's own index here (the fleet-wide convention: piracy,
// forest, nesbeat, meatworld, exeport all place their camEst the same way).
function mmEstBelowHud() {
	if (mmEst == null || mmEstPlaced) return;
	var list = mmCamList();
	if (list == null) {
		if (!mmEstWarned) {
			mmEstWarned = true;
			trace("[MM wetworld] camEst: no FlxG.cameras.list - the overlay stays above camHUD");
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

// A screen-locked overlay. `scrollFactor.set()` + a camera that never scrolls is
// Psych's camEst placement.
function mmOverlay(spr) {
	spr.scrollFactor.set(0, 0);
	spr.cameras = [mmGetEst()];
	add(spr);
	return spr;
}

// ---------------------------------------------------------------------------
// The 'Abandoned' death video (beatHit 228/248)
// ---------------------------------------------------------------------------
// The source's `luigidies` (5826-5835 + 16028-16039) is Psych's `VideoSprite`
// on camOther, the camera *above* camHUD - here a camera of this script's own
// appended after camHUD in `FlxG.cameras.list`, which is that slot. It plays
// `videos/luigifuckingdies.mp4` at beat 228, fades to alpha 0.6 over 2s and back
// to 0 over 2.2s at beat 248.
//
// The player is hxvlc's `hxvlc.flixel.FlxVideoSprite`, fetched with
// `Type.resolveClass` because HScript's scope does not import hxvlc (the class
// is in the engine), and every call goes through `Reflect` inside try/catch: an
// engine without the class or without libvlc traces one line and keeps playing.
// The source's `blend = MULTIPLY` (5832) is not applied - a video texture's
// blend mode is a FlixelBlendMode write this port cannot make from a script -
// so the clip shows normally instead of multiplied with the game behind it.
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

var mmDying = null;
var mmDyingTried:Bool = false;

function mmCall(obj, name:String, args:Array<Dynamic>):Bool {
	if (obj == null) return false;
	var fn = Reflect.field(obj, name);
	if (fn == null) return false;
	Reflect.callMethod(obj, fn, args);
	return true;
}

function mmDyingVideo() {
	if (mmDyingTried) return mmDying;
	mmDyingTried = true;
	try {
		var cls = Type.resolveClass("hxvlc.flixel.FlxVideoSprite");
		if (cls == null) {
			trace("[MM wetworld] beat 228: hxvlc.flixel.FlxVideoSprite is not script-reachable - the death video is skipped");
			return null;
		}
		mmDying = Type.createInstance(cls, []);
		if (mmDying == null) return null;
		mmDying.setPosition(300, 100);
		mmDying.scale.set(2, 2);
		mmDying.alpha = 0;
		mmDying.visible = false;
		mmDying.scrollFactor.set(0, 0);
		mmDying.cameras = [mmGetOther()];
		add(mmDying);
	} catch (e:Dynamic) {
		trace("[MM wetworld] beat 228: the video sprite could not be built - " + Std.string(e));
		mmDying = null;
	}
	return mmDying;
}

function beatHit() {
	// Only 'abandoned' runs on this stage (it is the only chart whose stage is
	// wetworld), so the source's `curSong == 'abandoned'` gate is structural here.
	switch (curBeat) {
		case 228:
			var v = mmDyingVideo();
			if (v == null) return;
			// Load first: a sprite with nothing loaded stays hidden rather than
			// sitting over the screen as an empty black plate.
			var ok:Bool = false;
			try {
				ok = Reflect.callMethod(v, Reflect.field(v, "load"), [Paths.video("luigifuckingdies")]) == true;
			} catch (e:Dynamic) { ok = false; }
			if (!ok) {
				trace("[MM wetworld] beat 228: the death video did not load ('luigifuckingdies.mp4')");
				return;
			}
			v.visible = true;
			mmCall(v, "play", []);
			FlxTween.tween(v, {alpha: 0.6}, 2, {ease: FlxEase.quadInOut});
		case 248:
			if (mmDying != null) FlxTween.tween(mmDying, {alpha: 0}, 2.2, {ease: FlxEase.quadInOut});
	}
}

// ---------------------------------------------------------------------------
// Character resolution (see exesequel.hx for the longer note)
// ---------------------------------------------------------------------------
// `boyfriend`/`dad` are properties over strumLines.members[1|0].characters[0],
// and case 10 swaps both, so the per-frame toggle below resolves the strumline
// instead of trusting the script global.
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

// `dadGroup` / `boyfriendGroup` do not exist here, so the source's group position
// has to be recovered from, and written back to, the character. Character.playAnim
// ends in
//     offset.set(globalOffset.x * (isPlayer != playerOffsets ? 1 : -1),
//                -globalOffset.y)
// so the sprite *renders* at `stored.x - k * globalOffset.x` / `stored.y +
// globalOffset.y` with k = (isPlayer != playerOffsets) ? 1 : -1, while the source
// renders it at `group + position` - the same derivation data/stages/forest.hx,
// allfinal.hx and data/events/Change Character.hx document, i.e.
//     stored.x = groupX + (k + 1) * globalOffset.x
//     stored.y = groupY                     (y carries no k)
// Both characters here are on the "already agrees" side (k = -1: the boyfriend
// node inherits getDefaultPos("boyfriend").flip = true, which is the isPlayer the
// engine builds him with, and both characters' XMLs carry the matching
// isPlayer - 'true' for the BF pair, 'false' for the two fountain Luigis), for
// which the two coincide - the helpers keep it exact regardless.
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

// Where the source's `group` puts `c` (the group x/y writes).
function mmPlaceGroup(c, gx:Float, gy:Float) {
	if (c == null) return;
	c.x = gx + (mmSideK(c) + 1) * c.globalOffset.x;
	c.y = gy;
}

// ---------------------------------------------------------------------------
// case 17's swing (13271-13274)
// ---------------------------------------------------------------------------
// `enemyY = dadGroup.y; extraTween.push(FlxTween.tween(dadGroup, {y: enemyY -
// 100}, 8, {ease: quadInOut, type: PINGPONG}))` - the fountain scene's whole
// framing drifts 100px down and back, forever, from 1.6s. The source's tween
// sits on the *group*, which keeps carrying whatever character the group holds,
// so case 10 (106.7s) drops the 3D Luigi into it mid-swing.
//
// A ported character has no group, and the tween cannot just be rebuilt on it at
// the swap: the engine's PINGPONG re-anchors on the value the tween is created
// at, so a restart mid-swing would leave Luigi swinging a few pixels instead of
// a hundred. The swing therefore runs on a bare proxy holding the group's y (the
// same `{x, y}` object songs/MMcamera.hx tweens) and the live character is parked
// on it every frame in update() - which is the source's own "the group moves, the
// character rides it", and makes the swap a no-op for the swing.
var mmPingOn:Bool = false;
var mmEnemyY:Float = 0;
var mmSwing = {"y": 0.0};   // dadGroup.y, as case 17 tweens it
var mmPingTween = null;

function mmPingStart(dy:Float) {
	mmPingOn = true;
	mmSwing.y = mmEnemyY;
	if (mmPingTween != null) mmPingTween.cancel();
	mmPingTween = FlxTween.tween(mmSwing, {y: mmEnemyY + dy}, 8, {ease: FlxEase.quadInOut, type: FlxTween.PINGPONG});
}

function mmPingApply() {
	if (!mmPingOn) return;
	var d = mmDadChar();
	if (d != null) d.y = mmSwing.y;
}

// Same swap as data/events/Change Character.hx; the two triggers the chart does
// not send itself (case 10's pair) call this directly.
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
	// The source's swap-in is not repositioned at all: 'Change Character' picks it
	// out of dadMap/boyfriendMap (6081-6122), where it was built *inside* the
	// group, so it sits at `group + its own position`, and the group's own tweens
	// keep moving it. The node applyCharStuff parks it on is only the group's
	// position while the group still sits at its default - and case 17 has been
	// swinging this group since 1.6s, so case 10's 3D Luigi arrived up to 100px
	// low and then stopped moving entirely (the tween kept driving the character
	// the swap had replaced).
	var gx:Float = mmGroupX(old);
	var gy:Float = mmGroupY(old);
	var oldIndex:Int = members.indexOf(old);

	remove(old);
	member.characters.remove(old);
	var fresh = new Character(0, 0, name, isPlayer);
	if (stage != null) stage.applyCharStuff(fresh, member.data.position, 0);
	// ...written back through the fresh character's own k/offset, which may differ
	// from the old one's (see the note above).
	mmPlaceGroup(fresh, gx, gy);
	// The source's group keeps its z-position across a swap, so the swap-in goes
	// back to the outgoing character's draw slot instead of the node's.
	if (oldIndex >= 0) {
		remove(fresh);
		insert(oldIndex, fresh);
	}
	// The source's death character is a global (GameOverSubstate.characterName) and
	// survives a swap; this port keeps it on the character (see songs/MMcamera.hx's
	// game-over table), so the current one has to ride across.
	fresh.gameOverCharacter = old.gameOverCharacter;
	member.characters.insert(0, fresh);
	var icon = index == 0 ? iconP1 : (index == 1 ? iconP2 : null);
	if (icon != null) icon.setIcon(fresh.getIcon());
}

// ---------------------------------------------------------------------------
// The camEst layers (4026-4135)
// ---------------------------------------------------------------------------
var mmFog = null;          // thefog, a plain PNG
var mmFlood = null;        // flood, 'water overlay'
var mmBlackBar = null;     // blackBarThingie
var mmRedTV = null;        // redTV, 'TV'
var mmRedTVStat = null;    // redTVStat, 'StaticFinal'
var mmRedStat = null;      // redStat, 'red static'
var mmLuigiLaugh = null;   // luigilaugh, 'laugh'
var mmWarningPopup = null; // camHUD, added at case 7

function mmAtlasSprite(asset:String, x:Float, y:Float, anim:String, fps:Int, loop:Bool) {
	var s = new FunkinSprite(x, y);
	s.frames = Paths.getSparrowAtlas(asset);
	s.animation.addByPrefix(anim, anim, fps, loop);
	s.animation.play(anim);
	return s;
}

function mmGetFog() {
	if (mmFog == null) {
		mmFog = new FunkinSprite(0, 0);
		mmFog.loadGraphic(Paths.image("mario/abandoned/fog")); // no .xml, plain image
		mmFog.alpha = 0;
		mmFog.screenCenter();
		mmOverlay(mmFog);
	}
	return mmFog;
}

function mmGetFlood() {
	if (mmFlood == null) {
		mmFlood = mmAtlasSprite("mario/abandoned/Flood_Assets", 0, 720, "water overlay", 24, true);
		mmFlood.alpha = 0.7;
		mmOverlay(mmFlood);
	}
	return mmFlood;
}

function mmGetBlackBar() {
	if (mmBlackBar == null) {
		mmBlackBar = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		mmBlackBar.scale.set(10, 10); // source's setGraphicSize(width * 10)
		mmBlackBar.alpha = 1;         // the stage loads on black
		mmOverlay(mmBlackBar);
	}
	return mmBlackBar;
}

function mmGetRedTV() {
	if (mmRedTV == null) {
		mmRedTV = mmAtlasSprite("mario/abandoned/Abandoned_Intro_Assets2", 0, 0, "TV", 24, true);
		mmRedTV.alpha = 0;
		mmRedTV.screenCenter();
		mmRedTV.x -= 210;
		mmRedTV.y -= 135;
		mmOverlay(mmRedTV);
	}
	return mmRedTV;
}

function mmGetRedTVStat() {
	if (mmRedTVStat == null) {
		mmRedTVStat = mmAtlasSprite("mario/abandoned/Abandoned_Intro_Assets2", 0, 0, "StaticFinal", 24, true);
		mmRedTVStat.alpha = 0;
		mmRedTVStat.screenCenter();
		mmOverlay(mmRedTVStat);
	}
	return mmRedTVStat;
}

function mmGetRedStat() {
	if (mmRedStat == null) {
		mmRedStat = mmAtlasSprite("mario/abandoned/redstatic", 0, 0, "red static", 24, true);
		mmRedStat.alpha = 0;
		mmOverlay(mmRedStat);
	}
	return mmRedStat;
}

function mmGetLuigiLaugh() {
	if (mmLuigiLaugh == null) {
		mmLuigiLaugh = mmAtlasSprite("mario/abandoned/Fountain_Luigi_2D_Laugh", 0, 0, "laugh", 24, false);
		mmLuigiLaugh.alpha = 0.00001;
		mmLuigiLaugh.screenCenter();
		mmLuigiLaugh.y += 50;
		mmOverlay(mmLuigiLaugh);
	}
	return mmLuigiLaugh;
}

// 4137-4143: on camHUD (not camEst) and only `add()`ed from case 7, so it is
// built but not added here - exactly like the source.
function mmGetWarningPopup() {
	if (mmWarningPopup == null) {
		mmWarningPopup = new FunkinSprite(0, 0);
		mmWarningPopup.loadGraphic(Paths.image("mario/abandoned/popup"));
		mmWarningPopup.scale.set(0.7, 0.7);
		mmWarningPopup.cameras = [camHUD];
		mmWarningPopup.alpha = 0;
		mmWarningPopup.screenCenter();
	}
	return mmWarningPopup;
}

// ---------------------------------------------------------------------------
// The flood (7394-7425)
// ---------------------------------------------------------------------------
// The rise and the health drain; `flooding` is cases 0/1/2's switch. The audio
// crossfade against `instALT` that the same block does is in mmAltCross below.
var mmFlooding:Bool = false;

// PlayState.hx:15516-15520, Water Note lowers the flood on a player hit.
function onNoteHit(event) {
	if (event.noteType != "Water Note" || !event.player || mmFlood == null) return;
	FlxTween.tween(mmFlood, {y: mmFlood.y + 60}, 0.35, {ease: FlxEase.quadInOut});
}

function update(elapsed:Float) {
	// case 17's swing owns the opponent's y for the whole song, so it is applied
	// before anything below can bail out.
	mmPingApply();
	if (mmFlood == null) return;
	if (mmFlooding) {
		if (mmFlood.y < 660)
			health -= (((((mmFlood.y + 90) / 750) - 1) * -1) / 160) * (60 * elapsed);
		if (mmFlood.y >= -90) mmFlood.y -= 1.5 * (60 * elapsed);
	}
	if (mmFlood.y > 720) mmFlood.y = 720;
	mmAltCross();
}

// ---------------------------------------------------------------------------
// The second instrumental, crossfaded by the flood (6678-6682, 6612,
// 7413-7427, 6927/7200-7208, 7578)
// ---------------------------------------------------------------------------
// Abandoned is mixed against two tracks: the inst, and `wetworldinstALT`, which
// the source loads for this stage (6678-6682) and plays with the song (6612).
// 7413-7427 then trades them against each other as the water rises - below
// `flood.y` 390 the ALT track comes up as the inst goes down and the vocals are
// pulled to the middle, past it the inst is back at 1 and the ALT is silent.
// The source keeps the vocals' restore point in `vocalvol`, which `mmVocalVol`
// mirrors. Pause/resume is the source's 6927/7578/7200-7208 pair, driven by the
// engine's own pause hooks because update() does not run while paused.
var mmAlt = null;
var mmAltDead:Bool = false;
var mmAltRunning:Bool = false;
var mmAltResume:Bool = false;
var mmVocalVol:Float = 1;

function mmAltVocals() {
	var ps = PlayState.instance;
	return (ps == null) ? null : ps.vocals;
}

function mmAltBuild() {
	if (mmAlt != null || mmAltDead) return mmAlt;
	var path = Paths.sound("wetworldinstALT");
	if (path == null || !Assets.exists(path)) {
		trace("[wetworld] instALT: sound missing -> " + path);
		mmAltDead = true;
		return null;
	}
	var s = new FlxSound().loadEmbedded(path);
	s.persist = false;
	s.volume = 0;
	mmAltRegister(s);
	mmAlt = s;
	return mmAlt;
}

// `Reflect.field` rather than `FlxG.sound.list.add` directly, the same guard
// promoshow.hx/exeport.hx use for `FlxG.cameras.list`: a lookup that comes back
// empty has to leave the track playing, not take the script down with it. Being
// in the group is what makes FlxSound advance its own `time` - which is how
// mmAltCross can tell how far the track has drifted; the audio plays either
// way.
function mmAltRegister(s) {
	var grp = Reflect.field(FlxG.sound, "list");
	if (grp == null || Reflect.field(grp, "add") == null) return;
	Reflect.callMethod(grp, Reflect.field(grp, "add"), [s]);
}

function mmAltCross() {
	var s = mmAltBuild();
	if (s == null) return;
	var mus = FlxG.sound.music;
	if (mus == null) return;
	if (!mus.playing) {
		if (s.playing) s.pause();
		mmAltRunning = false;
		return;
	}
	// 6612 / 7205-7208: start with the song, and re-time on every resume.
	if (!mmAltRunning || mmAltResume) {
		mmAltResume = false;
		mmAltRunning = true;
		var t = mus.time;
		if (Math.abs(s.time - t) > 10) {
			if (s.playing) s.pause();
			s.time = t;
		}
		s.play();
	}

	var voc = mmAltVocals();
	if (mmFlood.y < 390) {
		s.volume = ((((mmFlood.y + 90) / 480) - 1) * -1);
		mus.volume = ((mmFlood.y + 90) / 480);
		var v:Float = 0.5 + ((mmFlood.y + 90) / 960);
		if (voc != null) voc.volume = v;
		mmVocalVol = v;
	} else {
		if (voc != null) voc.volume = mmVocalVol;
		s.volume = 0;
		mmVocalVol = 1;
		mus.volume = 1;
	}
}

function onGamePause(event) {
	if (mmAlt != null && mmAlt.playing) mmAlt.pause();
	mmAltRunning = false;
}

function onSubstateClose(event) {
	// Dispatched while `paused` is still true, so this only marks a resumption -
	// mmAltCross re-times the track once the music is back.
	var ps = PlayState.instance;
	if (ps != null && ps.paused == true) mmAltResume = true;
}

// ---------------------------------------------------------------------------
// The TV shader stack (4028-4029, 5647-5690)
// ---------------------------------------------------------------------------
// `case 'wetworld'` sets *both* `tvEffect` and `oldTV`, so the whole song runs
// through the source's VCR stack: VCRMario85 (the tape wobble, the +/-0.003 RGB
// split and the 800-cycle scanline) and VCRBorder (the curved, vignetted bezel)
// on camGame/camEst/camHUD, plus OldTVShader (the rolling bands, the
// 16-direction blur, the black dropouts, the per-pixel static and the white
// sploches) between them because `oldTV` is set as well. The three are
// shaders/vcr85.frag, shaders/oldTv.frag and shaders/vcrBorder.frag, mounted in
// postCreate by mmTvStack and driven from postUpdate with the same per-second
// `time`/`iTime` the source feeds `vcr.update()` / `oldFX.update()` (7241/7246)
// - the wiring promoshow.hx uses.
//
// Wetworld is also the one stage whose own triggers *write* the brightness/
// contrast filter: 'Triggers Abandoned' 5/6 set `contrastFX.brightness` /
// `.contrast` (13200-13201 then 13218-13219), so shaders/brightnessContrast.frag
// is ported and mounted first on camGame - the source's filter order there is
// `[contrastFX, vcr, oldFX, border]` (5682), while camEst and camHUD get
// `[vcr, oldFX, border]` (5677-5678). The stage's camEst is this script's own
// camera (mmGetEst), so it is filtered too.
var mmVcr = null;            // VCRMario85 -> shaders/vcr85.frag
var mmOldFx = null;          // OldTVShader -> shaders/oldTv.frag
var mmVcrBorder = null;      // VCRBorder -> shaders/vcrBorder.frag
var mmContrast = null;       // BrightnessContrastShader -> shaders/brightnessContrast.frag
var mmVcrTime:Float = 0;     // VCRMario85 `time` - the source starts it at 0
var mmOldTime:Float = 0;     // OldTVShader `iTime` - seeded at mount (mmTvStack)
var mmTvOn:Bool = false;

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

// The source's camGame order is `[contrastFX, vcr, oldFX, border]` (5682) and
// `addShader` appends, so contrastFX is mounted on camGame before the other
// three; each shader mounts as soon as it is built, so a compile failure in one
// cannot cost the others their mount.
// The source's OldTVShader seeds its `iTime` with `Timer.stamp()` in its
// constructor (OldTVShader.new()), i.e. seconds since the process started, so
// the rolling bands and the static begin on that phase instead of on frame 0's
// zero state. `haxe.Timer.stamp` is inlined to a native call on this target and
// cannot be reflected from HScript, so the same quantity comes from
// FlxGame.ticks - the engine's own milliseconds-since-game-start counter. A
// build that cannot read it seeds 0, which is the old behaviour.
function mmProcessTime():Float {
	var game = Reflect.field(FlxG, "game");
	if (game == null || Reflect.field(game, "ticks") == null) return 0;
	var ms:Dynamic = Reflect.field(game, "ticks");
	return (ms == null) ? 0 : ms / 1000.0;
}

function mmTvStack() {
	if (mmTvOn || !mmShadersAllowed()) return;
	mmTvOn = true;
	// Source `OldTVShader.new()`: `iTime.value = [Timer.stamp()]`.
	mmOldTime = mmProcessTime();
	mmContrast = new CustomShader("brightnessContrast");
	if (camGame != null) camGame.addShader(mmContrast);
	mmVcr = new CustomShader("vcr85");
	mmTvMountAll(mmVcr);
	mmOldFx = new CustomShader("oldTv");
	mmTvMountAll(mmOldFx);
	mmVcrBorder = new CustomShader("vcrBorder");
	mmTvMountAll(mmVcrBorder);
}

// `vcr.update(elapsed)` / `oldFX.update(elapsed)` (7241/7246), which only ever
// accumulate the shader's own time uniform. The two are separate timers now:
// VCR starts at 0 like the source, OldTV starts at its process-time seed.
function mmTvTick(elapsed:Float) {
	if (mmVcr == null && mmOldFx == null) return;
	mmVcrTime += elapsed;
	mmOldTime += elapsed;
	if (mmVcr != null) mmVcr.data.time.value = [mmVcrTime];
	if (mmOldFx != null) mmOldFx.data.iTime.value = [mmOldTime];
}

// ---------------------------------------------------------------------------
// Load + intro
// ---------------------------------------------------------------------------
function onCountdown(event) {
	// `noCount = true` (4025): the source never builds its 3-2-1-GO sprites.
	event.cancelled = true;
}

function postCreate() {
	// The camEst layers in the source's own `add()` order (4094-4135). It is
	// load-bearing in both directions: the black plate is added *after* `flood`
	// and *before* the two redTV feeds, which is what keeps the water off screen
	// for the song's first forty seconds (they are rebuilt here at y 720 with
	// `mmFlooding` false, but camEst starts the song at 0.5 zoom, and scaling
	// about the camera's centre lifts the top of the 845px frame to screen y 540
	// - so without the curtain over it the wave is visible from the first frame)
	// and what puts the static on top of the black instead of under it.
	mmGetFog();
	mmGetFlood();
	mmGetBlackBar();
	mmGetRedTVStat();
	mmGetRedTV();
	mmGetLuigiLaugh();
	mmGetRedStat();
	// 4137-4143: built but not added - case 7 is the only `add()`.
	mmGetWarningPopup();

	// 4027: `gfGroup.visible = false` - GF is not in this song.
	if (gf != null) gf.visible = false;

	// 4316-4317: the source adds the front plates between the opponent and the
	// player - `add(gfGroup)` 4300, `add(dadGroup)` 4312, `add(adel)` 4316,
	// `add(adel2)` 4317, `add(boyfriendGroup)` 4341 - so they draw over dad and
	// under BF. The XML's own order parks them at the bottom of the world, whose
	// one visible consequence is dad standing in front of the foreground art;
	// they are re-seated the way superbad.hx re-seats its curtain.
	if (dad != null && adel != null && adel2 != null) {
		remove(adel, true);
		remove(adel2, true);
		var at:Int = members.indexOf(dad);
		at = (at < 0) ? 0 : at + 1;
		insert(at, adel);
		insert(at + 1, adel2);
	}

	// `noHUD = true` (4026).
	if (camHUD != null) camHUD.alpha = 0;

	// 7841-7857: the TV feeds fade in while camEst zooms out of its 0.5 zoom.
	// The port treats ClientPrefs.flashing as on, so redTVStat fades in directly
	// instead of switching to the 'justStat' frames + redTVImg.
	var est = mmGetEst();
	est.zoom = 0.5;
	FlxTween.tween(est, {zoom: 1}, 12, {ease: FlxEase.quadInOut});
	FlxTween.tween(mmGetRedTV(), {alpha: 1}, 10, {ease: FlxEase.quadInOut});
	FlxTween.tween(mmGetRedTVStat(), {alpha: 1}, 10, {ease: FlxEase.quadInOut});

	// 5647-5690: the filters are mounted at create, i.e. before the countdown
	// runs - the same slot promoshow.hx mounts its stack in.
	mmTvStack();
}

function postUpdate(elapsed:Float) {
	mmTvTick(elapsed);
}

// ---------------------------------------------------------------------------
// 'Triggers Abandoned' 0-17
// ---------------------------------------------------------------------------
function onEvent(event) {
	if (event.event.name == "Camera Movement") {
		// 16733-16746: the front layer (and BF) only show on the player's own
		// sections. `Camera Movement`'s param is the section's mustHitSection, so
		// 1 = BF sings, 0 = the opponent does.
		var bfOn:Bool = Std.parseInt(Std.string(event.event.params[0])) == 1;
		if (adel != null) FlxTween.tween(adel, {alpha: bfOn ? 1 : 0}, 0.13);
		if (adel2 != null) FlxTween.tween(adel2, {alpha: bfOn ? 1 : 0}, 0.13);
		var b = mmBfChar();
		if (b != null) FlxTween.tween(b, {alpha: bfOn ? 1 : 0}, 0.13);
		return;
	}

	if (event.event.name == "setProperty") {
		// The chart writes `blackBarThingie.alpha = 0` at 185.07s, one beat after
		// case 1 starts draining the flood, and it is what takes the curtain case
		// 13 raised (183.87s) back down for the song's last seventeen seconds -
		// without it the picture stays black from 184s to the end. The source's
		// `blackBarThingie` is a PlayState field; here the curtain is this
		// script's own sprite, so data/events/setProperty.hx's generic walk
		// (which looks for `blackBarThingie` on PlayState, finds nothing and
		// returns) cannot reach it and the write has to be taken here.
		if (Std.string(event.event.params[0]) == "blackBarThingie.alpha") {
			var v:Float = Std.parseFloat(Std.string(event.event.params[1]));
			if (!Math.isNaN(v)) mmGetBlackBar().alpha = v;
		}
		return;
	}

	if (event.event.name != "Triggers Abandoned" && event.event.name != "Triggers Universal") return;
	var trigger:Float = Std.parseFloat(Std.string(event.event.params[0]));
	if (trigger == null || Math.isNaN(trigger)) trigger = 0;

	switch (trigger) {
		case 0:
			// The flood starts rising (update()).
			mmFlooding = true;

		case 1:
			// ...and drains back down.
			mmFlooding = false;
			FlxTween.tween(mmGetFlood(), {y: 720}, 3, {ease: FlxEase.quadInOut, onComplete: function(twn) {
				mmGetFlood().y = 720;
			}});

		case 2:
			mmFlooding = false;

		case 3:
			// A wave comes up (two beats of it: 3 then 3.5) and Luigi laughs.
			FlxTween.tween(mmGetFlood(), {y: mmGetFlood().y - 120}, 0.25, {ease: FlxEase.quadOut});
			var d3 = mmDadChar();
			if (d3 != null) d3.playAnim("Hey", true);

		case 3.5:
			FlxTween.tween(mmGetFlood(), {y: mmGetFlood().y - 400}, 0.7, {ease: FlxEase.quadInOut});

		case 4:
			FlxTween.tween(mmGetRedStat(), {alpha: 0.8}, 0.4, {ease: FlxEase.quadIn});

		case 5:
			// The TV intro ends: everything fades out and the curtain goes.
			FlxTween.tween(mmGetRedTV(), {alpha: 0}, 1.1, {ease: FlxEase.quadInOut});
			FlxTween.tween(mmGetRedTVStat(), {alpha: 0}, 1.1, {ease: FlxEase.quadInOut});
			FlxTween.tween(mmGetRedStat(), {alpha: 0.8}, 1.1, {ease: FlxEase.quadInOut, onComplete: function(twn) {
				FlxG.camera.flash(FlxColor.WHITE, 0.5);
				mmGetBlackBar().alpha = 0;
				mmGetRedStat().alpha = 0;
				// 13200-13201: the intro's end darkens and hardens the picture.
				if (mmContrast != null) {
					mmContrast.data.brightness.value = [0.3];
					mmContrast.data.contrast.value = [2.0];
				}
			}});

		case 6:
			if (mmRedTV != null) mmRedTV.visible = false;
			if (mmRedTVStat != null) mmRedTVStat.visible = false;
			FlxTween.tween(mmGetRedStat(), {alpha: 0.8}, 0.4, {ease: FlxEase.quadInOut, onComplete: function(twn) {
				FlxG.camera.flash(FlxColor.WHITE, 0.5);
				mmGetRedStat().alpha = 0;
				// 13218-13219: and back towards normal as the intro fades.
				if (mmContrast != null) {
					mmContrast.data.brightness.value = [0.8];
					mmContrast.data.contrast.value = [1.0];
				}
			}});

		case 7:
			// 13222: the popup is only added now.
			var wp = mmGetWarningPopup();
			if (members.indexOf(wp) < 0) add(wp);
			FlxTween.tween(wp, {alpha: 1}, 0.5);

		case 8:
			FlxTween.tween(mmGetWarningPopup(), {alpha: 0}, 1, {ease: FlxEase.quadInOut});

		case 9:
			// Luigi laughs his way up from below, behind the closing curtain.
			var lg = mmGetLuigiLaugh();
			var nexty:Float = lg.y;
			lg.y += 500;
			lg.alpha = 1;
			FlxTween.tween(lg, {y: nexty}, 2, {ease: FlxEase.expoOut});
			lg.animation.play("laugh");
			FlxTween.tween(mmGetBlackBar(), {alpha: 1}, 1);

		case 10:
			// The 2D set goes, the 3D one (and the two 3D characters) arrives.
			if (fondaso != null) fondaso.visible = true;
			if (atra != null) atra.visible = true;
			if (adel != null) adel.visible = true;
			if (adel2 != null) adel2.visible = false;
			FlxG.camera.flash(FlxColor.WHITE, 0.5);
			mmGetRedStat().alpha = 0;
			mmGetLuigiLaugh().alpha = 0;
			mmGetBlackBar().alpha = 0;
			mmChangeChar(1, "luigi_fountain3d");
			mmChangeChar(0, "bf-back3d");

		case 11:
			FlxTween.tween(mmGetFog(), {alpha: 0.9}, 0.5);

		case 12:
			mmGetFog().alpha = 0;

		case 13:
			FlxTween.tween(mmGetBlackBar(), {alpha: 1}, 0.45, {ease: FlxEase.quadIn});
			FlxTween.tween(mmGetRedStat(), {alpha: 0.8}, 0.45, {ease: FlxEase.quadIn});

		case 14:
			// Out over 24 beats (9.6s at this song's 150bpm).
			var beats:Float = 24 * (1 / (Conductor.bpm / 60));
			FlxTween.tween(mmGetBlackBar(), {alpha: 1}, beats);
			FlxTween.tween(camHUD, {alpha: 0}, beats);

		case 15:
			// `if (ClientPrefs.flashing)` in the source; always on here.
			mmGetRedStat().alpha = 0;

		case 16:
			mmGetRedStat().alpha = 0.8;

		case 17:
			// 13271-13274: the whole 3D stage drifts down and back, around the group
			// y the trigger catches. See mmPingStart for why the swing rides a proxy.
			var d17 = mmDadChar();
			if (d17 != null) {
				mmEnemyY = mmGroupY(d17);
				mmPingStart(-100);
			}
	}
}
// === end MM stage triggers ===
