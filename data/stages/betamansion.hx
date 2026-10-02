// Ported from PlayState.hx beatHit() (case 'exesequel' | 'betamansion' | 'nesbeat').
// starman GF bounces left/right every beat, but a 'hey' animation is allowed
// to play through before the dance resumes.
function beatHit(curBeat:Int) {
	// 16366: the source's whole betamansion/exesequel/nesbeat bounce block sits
	// inside `if (SONG.song != 'Alone Old')` - the old song has no starman GF.
	if (mmIsAloneOld()) return;
	var anim = starmanGF.animation.curAnim;
	if (curBeat % 2 == 0) {
		if (anim == null || anim.name != 'hey' || anim.finished)
			starmanGF.playAnim('danceRight', true);
	} else {
		starmanGF.playAnim('danceLeft', true);
	}
}

// === MM stage triggers (auto) ===
import flixel.text.FlxText;

// 'Triggers Alone' - ported from PlayState.hx (case 'Triggers Alone').
// Also ports the betamansion-specific support code the first pass missed:
//   - create()  : lluvia rain overlay (mario/LuigiBeta/old/Beta_Luigi_Rain_V1) + iconGF
//   - stepHit() : auto-fires 'Triggers Alone' 3 every step while lluvia is visible
//   - update()  : iconGF position / win-lose animation controller
//   - postCreate()/onSongStart() : the Alone cinematic start state (full-screen
//                  black tint, GF tiny/off-screen, BF + starman GF transparent,
//                  camera zoom-in)
//   - noCount/noHUD : 1917/1921 - the engine's READY/SET/GO are dropped (1917
//                  is unconditional) and, on the modern song only (1921 sits
//                  inside the `SONG.song != 'Alone Old'` guard), camHUD starts
//                  at alpha 0
// Still not reproduced: the HUD timebar / customHB / timeTxt fades of cases 4/5
// (the port fades the engine's health bar and the two icons instead, as
// exesequel.hx does) and the special-game-over cinematic (update()'s
// curStage == 'betamansion' restart reset - which is also where the source's
// `goodNight` plate at 9032 lives, on camEst, so that one is not wireable
// without the substate swap this engine has no script hook for). `bfcolgao`
// (case 0) *is* built now, for both songs: the source creates it in the stage's
// own 5178-5192 block, outside any song gate. So is 'Alone Old's own art branch
// (1987-2014): its three `Beta_Luigi_BG_Assets_*` plates replace the modern
// layers (which the XML only ever carried) and its `lluvia` is the world-space
// foreground sprite the source adds at 4421, not the camEst one. Case 13's
// per-letter ghost text is one text per letter now, as in the source.
//
// This script also carries the stage's camEst layer (see below): `lluvia`
// (1959-1962) and `fogblack` (5179-5184) both sit on it in the source, above
// the world and the fighters and below the notes and the HUD.

// ---------------------------------------------------------------------------
// camEst (1959, 5179)
// ---------------------------------------------------------------------------
// Psych's camEst is a bare `new FlxCamera()` created right after camGame (827)
// and added before camHUD (833-836): the same view rectangle, its canvas
// composited between the world's and the HUD's. Codename ships only camGame and
// camHUD, and in flixel a camera's canvas is composited in `FlxG.cameras.list`
// order - so the port adds a camera of its own the normal way
// (`defaultDraw = false`, the world is not redrawn into it) and then slides it
// in at camHUD's own index, i.e. camEst's slot.
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
			trace("[MM betamansion] camEst: no FlxG.cameras.list - the overlays stay above camHUD");
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

// 5179-5184: `fogblack`, the 'modstuff/126' vignette at 0.8 - the stage's own
// permanent darkening, built unconditionally (both songs get it, unlike the
// Alone cinematic below), after `lluvia` and so drawn over it. The source never
// touches it again; realbg's copy of the same asset is trigger 3's business.
var mmFogBlack = null;

function mmGetFogBlack() {
	if (mmFogBlack == null) {
		mmFogBlack = new FlxSprite(0, 0);
		mmFogBlack.loadGraphic(Paths.image("modstuff/126"));
		mmFogBlack.antialiasing = true; // ClientPrefs.globalAntialiasing, taken as on
		mmFogBlack.cameras = [mmEst()];
		mmFogBlack.alpha = 0.8;
		mmFogBlack.screenCenter();
		add(mmFogBlack);
	}
	return mmFogBlack;
}

// blackBarThingie - the source's full-screen black tint. The source makes a
// screen-sized graphic then setGraphicSize(*10) so it still covers everything
// at any camera zoom (a 1x copy is shrunk back below full-screen by zooms).
var mmBlackBar:FlxSprite;
function mmGetBlackBar():FlxSprite {
	if (mmBlackBar == null) {
		mmBlackBar = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		mmBlackBar.scale.set(10, 10); // source's setGraphicSize(width * 10)
		mmBlackBar.scrollFactor.set(0, 0);
		mmBlackBar.alpha = 1;
		mmBlackBar.cameras = [mmEst()]; // 1974: screen-space, below camHUD
		add(mmBlackBar);
	}
	return mmBlackBar;
}

// bgsprite 'mario/LuigiBeta/old/Beta_Luigi_Rain_V1', -170, 50, ['RainLuigi']
// 1959-1962: on camEst in the source, i.e. a screen-wide rain sheet fixed to the
// view - camEst never scrolls and never zooms, so the sheet does not slide with
// the camera and is not rescaled by the chart's zoom moves. It is *not* a world
// sprite, which is what this used to be.
var mmLluvia:FunkinSprite;
function mmGetLluvia():FunkinSprite {
	if (mmLluvia == null) {
		mmLluvia = new FunkinSprite(-170, 50);
		mmLluvia.frames = Paths.getSparrowAtlas("mario/LuigiBeta/old/Beta_Luigi_Rain_V1");
		mmLluvia.animation.addByPrefix("RainLuigi", "RainLuigi", 24, true);
		mmLluvia.animation.play("RainLuigi");
		mmLluvia.scale.set(1.7, 1.7);
		mmLluvia.alpha = 0;
		mmLluvia.antialiasing = true;
		mmLluvia.cameras = [mmEst()];
		add(mmLluvia);
	}
	return mmLluvia;
}

// 'Alone Old' is the legacy half of this stage: the source's create switch has a
// branch of its own for it (1987-2014) with three background plates and its own
// `lluvia` (a *world* sprite, alpha 0.5, `visible = false` until case 2, added in
// the foreground switch at 4421 - in front of the fighters). The extractor only
// ever lifted the modern branch, so the port hides the modern layers and rebuilds
// the old ones, in the source's own order: bg -> mansion -> lights, all below the
// characters; the rain above them.
function mmIsAloneOld():Bool {
	var meta = (PlayState.SONG != null) ? PlayState.SONG.meta : null;
	if (meta == null) return false;
	return StringTools.trim(Std.string(meta.displayName)) == "Alone Old";
}

// Index of the first character (the top of the world layer) - the helper
// hatebg.hx/secretbg.hx use.
function mmWorldTop():Int {
	var at:Int = members.length;
	for (c in [gf, dad, boyfriend]) {
		var i:Int = members.indexOf(c);
		if (c != null && i >= 0 && i < at) at = i;
	}
	return at;
}

var mmOldBg = null;
var mmOldMansion = null;
var mmOldLights = null;
var mmOldRain = null;

// A single-PNG BGSprite stand-in (the old plates have no atlas).
function mmOldPlate(path:String, x:Float, y:Float, sx:Float, sy:Float) {
	var s = new FunkinSprite(x, y);
	s.loadGraphic(Paths.image(path));
	s.scrollFactor.set(sx, sy);
	s.antialiasing = true; // ClientPrefs.globalAntialiasing, taken as on
	return s;
}

function mmBuildOldStage() {
	if (mmOldBg != null) return;

	// The modern layers the XML carries are not this song's.
	if (bg != null) bg.visible = false;
	if (scarymansion != null) scarymansion.visible = false;
	if (betafire1 != null) betafire1.visible = false;
	if (betafire2 != null) betafire2.visible = false;
	if (scaryfloor != null) scaryfloor.visible = false;
	if (starmanGF != null) starmanGF.visible = false;

	// 1987-2001: `Beta_Luigi_BG_Assets_2` at (-400, -50) scroll 0.5, `_1` at
	// (-350, -170) and `_3` at (320, 50), the last two at 1.1x. Inserted
	// in source order just before the character band, including on engines
	// whose character markers have already been replaced.
	mmOldLights = mmOldPlate("mario/LuigiBeta/old/Beta_Luigi_BG_Assets_3", 320, 50, 1, 1);
	mmOldLights.scale.set(1.1, 1.1);
	mmOldMansion = mmOldPlate("mario/LuigiBeta/old/Beta_Luigi_BG_Assets_1", -350, -170, 1, 1);
	mmOldMansion.scale.set(1.1, 1.1);
	mmOldBg = mmOldPlate("mario/LuigiBeta/old/Beta_Luigi_BG_Assets_2", -400, -50, 0.5, 0.5);

	var at:Int = mmWorldTop();
	for (s in [mmOldBg, mmOldMansion, mmOldLights]) {
		insert(at, s);
		at += 1;
	}
}

function mmBuildOldRain() {
	if (mmOldRain != null) return;
	mmOldRain = new FunkinSprite(-170, 50);
	mmOldRain.frames = Paths.getSparrowAtlas("mario/LuigiBeta/old/Beta_Luigi_Rain_V1");
	mmOldRain.animation.addByPrefix("RainLuigi", "RainLuigi", 24, true);
	mmOldRain.animation.play("RainLuigi");
	mmOldRain.scale.set(1.7, 1.7);
	mmOldRain.antialiasing = true;
	mmOldRain.alpha = 0.5;
	mmOldRain.visible = false;
	add(mmOldRain); // 4421: the foreground switch, in front of the fighters
}

// 5186-5192: `bfcolgao`, the hanging BF the thunder flashes in. Its create block
// (5178) is not song-gated in the source, so both songs get it; case 0 plays it.
var mmBfColgao = null;
function mmGetBfColgao() {
	if (mmBfColgao == null) {
		mmBfColgao = new FlxSprite(700, -100);
		mmBfColgao.frames = Paths.getSparrowAtlas("modstuff/Beta_BF_Hang");
		mmBfColgao.animation.addByPrefix("idle", "BFHang", 24);
		mmBfColgao.antialiasing = true; // ClientPrefs.globalAntialiasing, taken as on
		mmBfColgao.cameras = [mmEst()];
		mmBfColgao.alpha = 0;
		add(mmBfColgao);
	}
	return mmBfColgao;
}

// iconGF - the third (Alone Mario) health icon, from the source's create().
// The source sizes this off icons/icon-LG and then reloads icon-alonemario
// with width/2 x height frames. Both sheets are 300x150, so the frame size can
// be passed straight in - no dependence on the first load succeeding. Returns
// null (rather than throwing) if the image is missing, so the icon can never
// take the rest of the 'Alone Mario' reveal down with it.
var mmIconGF:FlxSprite;
function mmGetIconGF():FlxSprite {
	if (mmIconGF != null) return mmIconGF;
	var path = Paths.image("icons/icon-alonemario");
	if (path == null || !Assets.exists(path)) {
		trace("[betamansion] iconGF: image missing -> " + path);
		return null;
	}
	var s = new FunkinSprite();
	s.loadGraphic(path, true, 150, 150);
	s.animation.add("win", [0], 10, true);
	s.animation.add("lose", [1], 10, true);
	s.cameras = [camHUD];
	s.antialiasing = true;
	s.alpha = 0;
	add(s);
	mmIconGF = s;
	return mmIconGF;
}

// The source builds starman GF's bounce from two halves of the sheet:
//   danceRight = GFIdle[15..29]
//   danceLeft  = GFIdle[30,0..14]   (index 30 is past the end of a 30 frame sheet,
//                                    so danceLeft is really GFIdle[0..14])
// Registering them here keeps them exact no matter how the stage XML was parsed.
function mmFixStarmanAnim() {
	if (starmanGF == null || starmanGF.animation == null) return;
	var right:Array<Int> = [];
	for (i in 15...30) right.push(i);
	var left:Array<Int> = [];
	for (i in 0...15) left.push(i);
	starmanGF.animation.addByIndices('danceRight', 'GFIdle', right, "", 24, false);
	starmanGF.animation.addByIndices('danceLeft', 'GFIdle', left, "", 24, false);
	starmanGF.animation.addByPrefix('sad', 'GFMiss', 24, false);
	// The source's BGSprite starts on the first anim of its list ('GFIdle').
	starmanGF.animation.play('GFIdle', true);
}

// stepHit() (_ref_ 15984): while lluvia is visible the stage keeps firing
// 'Triggers Alone' 3 (the gota rain drop spawner). The source gates the whole
// block on the modern song; 'Alone Old' keeps its own rain sheet (case 2) and
// never spawns drops.
function stepHit(curStep:Int) {
	if (mmIsAloneOld()) return;
	if (mmLluvia != null && mmLluvia.alpha != 0) mmSpawnGota();
}

function mmSpawnGota() {
	var gota = new FunkinSprite(FlxG.random.int(0, 1270), FlxG.random.int(600, 1000));
	gota.frames = Paths.getSparrowAtlas("mario/LuigiBeta/gota");
	gota.animation.addByPrefix("rain", "rain", 24, false);
	gota.animation.play("rain");
	gota.alpha = 0.4;
	gota.antialiasing = true;
	if (gota.y > 850) add(gota); else insert(members.indexOf(dad) - 1, gota);
	FlxTween.tween(gota, {alpha: 0}, 2, {startDelay: 0.3, onComplete: function(twn) { gota.destroy(); }});
}

// update() (_ref_ 8048): iconGF hugs the opponent icon and reflects health.
function update(elapsed:Float) {
	if (mmIconGF == null || mmIconGF.alpha == 0) return;
	if (iconP2 != null) {
		mmIconGF.x = iconP2.x - 70;
		// Source 8048-8056 updates x/scale only; keep case 7's y offset.
	}
	if (iconP1 != null) mmIconGF.scale.set(iconP1.scale.x - 0.2, iconP1.scale.y - 0.2);
	var hp:Dynamic = Reflect.getProperty(PlayState.instance, "health");
	if (hp == null) hp = 1;
	if (hp > 1.6 || hp < 0.4) mmIconGF.animation.play("lose");
	else mmIconGF.animation.play("win");
}

// Start-of-song state (_ref_ 7863, update()'s startingSong block for
// betamansion). The modern Alone cinematic starts zoomed in: GF is shrunk and
// parked off-screen at the top, BF and the starman GF are transparent and the
// third icon is off. The 'Triggers Alone' events reveal everything later.
// Only applies to 'Alone' - 'Alone Old' keeps the plain stage.
// (`noCount = true` at 1917 drops the engine's READY/SET/GO - see onCountdown -
// and the hidden state is applied as early as postCreate instead.)
function mmIsAlone() {
	var meta = (PlayState.SONG != null) ? PlayState.SONG.meta : null;
	var songName = (meta != null) ? meta.displayName : null;
	return (songName == null || songName == "Alone");
}

function mmDownScroll():Bool {
	return downscroll == true;
}

function mmCam(which:String, args:Array<Dynamic>):Dynamic {
	var ps = PlayState.instance;
	if (ps == null || ps.scripts == null) return null;
	var api:Dynamic = ps.scripts.get("mmCamera");
	if (api == null || !Reflect.hasField(api, which)) return null;
	return Reflect.callMethod(api, Reflect.field(api, which), args);
}

var mmCanFade:Bool = false;
// Source scales the GF group, on top of mario-alone's own 1.2 scale.
var mmGfScaleX:Float = 1;
var mmGfScaleY:Float = 1;

function postUpdate(elapsed:Float) {
	// 8145-8154: after case 6's fade completes, health drives the ghost BF's
	// opacity, clamped by the source's explicit thresholds; case 11 stops it.
	if (boyfriend != null && boyfriend.curCharacter == "bfbetanew" && mmCanFade)
		boyfriend.alpha = (health > 1.8) ? 0.9 : ((health < 0.4) ? 0.2 : health / 2);
}

function mmApplyAloneHiddenState() {
	if (starmanGF != null) starmanGF.alpha = 0;
	if (boyfriend != null) boyfriend.alpha = 0;
	if (gf != null) {
		gf.scale.set(mmGfScaleX * 0.2, mmGfScaleY * 0.2);
		gf.scrollFactor.set(0.8, 0.8);
		gf.alpha = 0.000001;
		gf.x = 310;
		gf.y = -360;
	}
	if (iconP1 != null) iconP1.alpha = 0;
	if (iconP2 != null) iconP2.alpha = 0;
	if (healthBar != null) healthBar.alpha = 0;
	if (healthBarBG != null) healthBarBG.alpha = 0;
	if (scoreTxt != null) scoreTxt.alpha = 0;
}

function onCountdown(event) {
	// `noCount = true` (1917): the source never builds its 3-2-1-GO sprites for
	// this stage, on either song.
	event.cancelled = true;
}

// earliest reliable hook: PlayState has created the characters and the stage
// sprites by now
function postCreate() {
	mmFixStarmanAnim();
	if (gf != null) { mmGfScaleX = gf.scale.x; mmGfScaleY = gf.scale.y; }
	// The stage XML places Mario's GF group behind the fire sheets (1931).
	// The stage's two camEst layers, in the source's own order (that is what
	// decides who draws over whom): `lluvia` first - inside the modern-only
	// create branch at 1959-1962, so 'Alone Old' does not get it - and then the
	// 5179-5184 vignette, which both songs do get. The rain stays at alpha 0
	// until case 0 fades it in.
	if (mmIsAloneOld()) { mmBuildOldStage(); mmBuildOldRain(); }
	if (mmIsAlone()) {
		mmGetLluvia();
		mmGetBlackBar(); // source order: rain -> curtain -> vignette -> hanging BF
	}
	mmGetFogBlack();
	mmGetBfColgao();
	if (!mmIsAlone()) return;
	mmApplyAloneHiddenState();
	// `noHUD = true` (1921), inside the modern-only `if (SONG.song != 'Alone
	// Old')` block -> 5630-5633. The chart's own 'Ocultar HUD' 2 restores it.
	if (camHUD != null) camHUD.alpha = 0;
	// The screen-space curtain built above fades to 0.5 on song start.
}

function onSongStart() {
	if (!mmIsAlone()) return;
	mmApplyAloneHiddenState();

	health = 2; // 7881: the original intro starts at full health
	camGame.zoom = 1.3;
	mmCam("setZoom", [1.3]);
	mmCam("zoom", [0.8, 3.7, 0, FlxEase.quadOut]);
	FlxTween.tween(mmGetBlackBar(), {alpha: 0.5}, 3.5, {startDelay: 1, ease: FlxEase.quadInOut});

	FlxTween.tween(boyfriend, {y: boyfriend.y - 20}, 3, {ease: FlxEase.quadInOut, type: FlxTween.PINGPONG});
	FlxTween.tween(boyfriend, {x: boyfriend.x + 40}, 5, {ease: FlxEase.quadInOut, type: FlxTween.PINGPONG});

	// 7877-7878 capture the original GF GROUP position before the following
	// lines move it to (310, -360). Stage JSON is (400, 100), so these targets
	// are (380, 140), not the hidden character's later position/offsets.
	var gfX:Float = 400;
	var gfY:Float = 100;
	if (starmanGF != null) {
		FlxTween.tween(starmanGF, {y: gfY + 40}, 2, {startDelay: 0.2, ease: FlxEase.quadInOut, type: FlxTween.PINGPONG});
		FlxTween.tween(starmanGF, {x: gfX - 20}, 4, {startDelay: 0.2, ease: FlxEase.quadInOut, type: FlxTween.PINGPONG});
	}
}

function onEvent(event) {
	if (event.event.name != "Triggers Alone" && event.event.name != "Triggers Universal") return;
	var trigger = Std.parseInt(event.event.params[0]);
	if (trigger == null || Math.isNaN(trigger)) trigger = 0;

	switch (trigger) {
		case 0:
			FlxG.camera.flash(FlxColor.WHITE, 1);
			// 11681-11697: the thunder cue is the old song's, `bfcolgao` plays for
			// both songs, and the two fade-ins are `!= 'Alone Old'` - the old song
			// shows its own rain sheet from case 2 instead.
			if (mmIsAloneOld()) {
				FlxG.sound.play(Paths.sound("thunder_1"));
			} else {
				FlxTween.tween(mmGetBlackBar(), {alpha: 0}, 5);
				FlxTween.tween(mmGetLluvia(), {alpha: 0.6}, 5);
			}
			var colgao = mmGetBfColgao();
			if (colgao != null) {
				colgao.animation.play("idle");
				colgao.alpha = 1;
				FlxTween.tween(colgao, {alpha: 0}, 2, {ease: FlxEase.quadOut});
			}
		case 1:
			FlxG.camera.flash(FlxColor.WHITE, 1);
			if (mmIsAloneOld()) FlxG.sound.play(Paths.sound("thunder_1"));
		case 2:
			FlxG.camera.flash(FlxColor.WHITE, 1);
			if (mmIsAloneOld()) {
				FlxG.sound.play(Paths.sound("thunder_1"));
				if (mmOldRain != null) mmOldRain.visible = true;
			}
		case 3:
			if (!mmIsAloneOld()) mmSpawnGota();
		case 4:
			FlxTween.tween(iconP1, {alpha: 1}, 2);
			FlxTween.tween(iconP2, {alpha: 1}, 2);
			// The source's customHB / timeBar / timeTxt half; the engine's bar is
			// this port's stand-in, as in exesequel.hx's case 16.
			FlxTween.tween(healthBar, {alpha: 1}, 2);
			FlxTween.tween(healthBarBG, {alpha: 1}, 2);
		case 5:
			FlxTween.tween(iconP1, {alpha: 0}, 2);
			FlxTween.tween(iconP2, {alpha: 0}, 2);
			FlxTween.tween(healthBar, {alpha: 0}, 2);
			FlxTween.tween(healthBarBG, {alpha: 0}, 2);
		case 6:
			FlxTween.tween(starmanGF, {alpha: 0.8}, 2);
			FlxTween.tween(boyfriend, {alpha: 0.8}, 2, {onComplete: function(twn) { mmCanFade = true; }});
		case 7:
			// source: '//alone mario' - iconGF appears and gfGroup grows back in.
			// `gf` is strumLines.members[2].characters[0]; for Alone the chart's
			// player3 makes that 'mario-alone', which is the character the source
			// reveals here. The icon is created before the timer starts and the
			// callback guards it, so a missing icon can't abort the reveal.
			var ic = mmGetIconGF();
			new FlxTimer().start(1, function(tmr) {
				if (ic != null) {
					// 11765: `iconGF.y = iconP2.y - (!hasDownScroll ? 15 : -15)`.
					// CNE already mirrors icon positions: source's physical +15
					// in downscroll becomes logical -15 (both icons are 150px).
					ic.y = (iconP2 != null) ? iconP2.y - 15 : ic.y;
					ic.alpha = 0;
					FlxTween.tween(ic, {alpha: 0.7}, 2, {ease: FlxEase.quadOut});
				}

				var g = gf;
				if (g == null) return;
				g.alpha = 0;
				FlxTween.tween(g, {alpha: 0.9}, 2, {ease: FlxEase.quadOut});
				FlxTween.tween(g.scale, {x: mmGfScaleX, y: mmGfScaleY}, 3, {ease: FlxEase.quadOut});
				FlxTween.tween(g.scrollFactor, {x: 0.95, y: 0.95}, 3, {ease: FlxEase.quadOut});
				FlxTween.tween(g, {x: 630, y: -420}, 1.5, {ease: FlxEase.quadInOut, onComplete: function(twn) {
					FlxTween.tween(g, {x: 600, y: -360}, 1.5, {ease: FlxEase.quadInOut, onComplete: function(twn2) {
						FlxTween.tween(g, {x: g.x - 550}, 5, {ease: FlxEase.quadInOut, type: FlxTween.PINGPONG});
						FlxTween.tween(g, {y: g.y + 100}, 1.75, {ease: FlxEase.quadInOut, type: FlxTween.PINGPONG});
					}});
				}});
			});
			// The camera pan/zoom for this reveal lives in songs/MMcamera.hx, which
			// owns camFollow/defaultCamZoom (writing them here would be overwritten
			// by the engine's own moveCamera a frame later).
		case 8:
			if (mmIconGF != null) FlxTween.tween(mmIconGF, {alpha: 0}, 1.75, {ease: FlxEase.quadInOut});
			var g8 = gf;
			if (g8 != null) {
				FlxTween.tween(g8, {y: -900}, 1.75, {ease: FlxEase.cubeIn});
				FlxTween.tween(g8, {alpha: 0}, 1.75, {ease: FlxEase.cubeIn});
			}
		case 10:
			// The source sets camFollow/defaultCamZoom directly, but its own
			// per-frame FOLLOWCHARS/ZOOMCHARS block overwrites both on the very
			// next frame - so they were one-frame no-ops there too. MMcamera owns
			// camFollow/defaultCamZoom, and the chart's own events drive them.
			defaultCamZoom = 0.8;
		case 11:
			FlxTween.tween(starmanGF, {alpha: 0}, 2.4);
			FlxTween.tween(boyfriend, {alpha: 0}, 2.4, {onComplete: function(twn) { mmCanFade = false; }});
		case 12:
			FlxTween.tween(mmGetBlackBar(), {alpha: 1}, 2);
		case 13:
			// 11816-11840: one FlxText *per letter* of value2, each carrying its own
			// letter padded out to the full string's width with two spaces on each
			// side, centred in the 720px box - so the word is spread across the
			// screen and every letter flies on its own random timing.
			var msg:String = Std.string(event.event.params[1]);
			if (msg == null) break;
			for (i in 0...msg.length) {
				var line = "";
				for (p in 0...msg.length) {
					if (p != i) line += "  ";
					else line = msg.charAt(i);
				}
				var text = new FlxText(980, 610, 720, line, 30);
				text.setFormat(Paths.font("vcr.ttf"), 30, 0xFF198C0E, "center");
				text.borderSize = 1.25;
				text.cameras = [camHUD];
				text.alpha = 0;
				text.ID = i;
				add(text);

				// Both tweens capture their target y at creation, as the source's do:
				// the letter rises from 610 to ~570 (a 0-5px random extra) and then
				// drops to 650 as it fades out, three beats later.
				var y0 = text.y;
				FlxTween.tween(text, {y: (y0 - 40) - FlxG.random.int(0, 5), alpha: 1, angle: 0},
					FlxG.random.float(1, 1.8), {ease: FlxEase.expoOut});
				FlxTween.tween(text, {y: y0 + 40, alpha: 0}, FlxG.random.float(1.4, 1.6),
					{startDelay: (3 * (1 / (Conductor.bpm / 60))), ease: FlxEase.cubeIn,
					onComplete: function(twn) { text.destroy(); }});
			}
	}
}
// === end MM stage triggers ===
