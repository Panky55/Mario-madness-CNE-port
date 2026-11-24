

// === MM stage triggers (auto) ===
// 'Triggers Bad Day' - ported from PlayState.hx (case 'Triggers Bad Day',
// 11836-12160, plus the stage's own create-time pieces).
//
// The sprites the previous version of this file called "not part of the
// extracted stage art" are in the mod's images after all, so they are ported
// now:
//
//   2024-2042  `badGrad1`/`badGrad2` ('mario/BadMario/sideBar', the two poison
//              side bars) and `badPoisonVG` (the purple wash). The wash is
//              data/notes/Bad Poison.hx's; the two bars are built here at alpha
//              0, invisible, decayed per frame (7378-7381) and shown by case 15.
//              The source puts them on camOther, the camera *above* camHUD,
//              which Codename does not have; they go on camHUD, the same
//              substitution Bad Poison.hx makes for the wash.
//   2044-2051  `badHUDMario` ('mario/BadMario/HUD_Mario', the little Mario that
//              wrecks the HUD through cases 10-14), on camHUD at 5x, built but
//              not added - case 10 adds it.
//   5574-5604  the create-time camera state (handled by songs/MMcamera.hx's
//              mmInit: FOLLOWCHARS/ZOOMCHARS false, dadGroup at (-50, 400),
//              camGame.zoom = 1.6) and `byecirc` ('modstuff/bye', the goodbye /
//              bye bye / hello cutscene plate on camEst, alpha ~0 until case 0
//              plays 'p1').
//
// Camera: `songs/MMcamera.hx` owns camFollow/defaultCamZoom for this stage, so
// the source's `BF_CAM_X = ...` / `DAD_CAM_X = ...` writes go through the api it
// publishes through the engine's ScriptPack like every other staged camera move. Psych's
// camEst (the layer between camGame and camHUD) is a camera of this script's own,
// slid in at camHUD's index - cases 14/15 drag the bar's whole block onto it and
// tilt it, which is the "mario breaks the health bar" gag (see `mmHudSet`).
//
// Cases that re-dispatch events instead of doing the work inline are inlined:
// 'Triggers Universal' 13 is case 13's `badFlash` and 'Triggers Universal' 11 is
// case 11's HUD-Mario hop, both dispatched from inside the *downscroll* half of
// case 12 (see mmBadFlash / mmHudMarioHop). The source's `Screen Shake` dispatch
// of case 14 is inlined with the same values, and its `eventTweens` mass-cancel
// has no port equivalent (the port's tweens are not tracked in one array).
//
// The source's `GameOverSubstate.characterName = 'bfbaddeath'` rides
// `songs/MMcamera.hx`'s game-over table (`superbad|bfbaddeath`) and its
// `addCharacterToList` target is warmed by `mmPreloadCharacters`.
// NOT ported: `gf.specialAnim = false` (CNE's Character has no such field -
// see data/events/MM Play Animation.hx) and `customHB`/`customHBweegee`, the
// 'healthBarNEW' frames the fork draws over the health bar: Codename draws its
// own bar and has no such sprite. The engine's bar does have a frame and a score
// line though, and those are what the player saw left behind when only the fill
// fell - `mmHudSet` is that whole block, so cases 14/15 move all of it.
function mmCam(which:String, args:Array<Dynamic>):Dynamic {
	// songs/MMcamera.hx publishes its api through CnE's ScriptPack
	// (`PlayState.instance.scripts.set/get`), the engine's own cross-script
	// channel. It cannot be a `Reflect.setProperty(PlayState.instance, ...)`
	// field: Haxe's Reflect on cpp only touches fields that already exist and
	// throws `Invalid field:<name>` otherwise (see the note in MMcamera.hx).
	var ps = PlayState.instance;
	if (ps == null || ps.scripts == null) return null;
	var api:Dynamic = ps.scripts.get("mmCamera");
	if (api == null) return null;
	if (!Reflect.hasField(api, which)) return null;
	return Reflect.callMethod(api, Reflect.field(api, which), args);
}

function mmDownscroll():Bool {
	// `PlayState.downscroll` is a get/set property over `camHUD.downscroll`; on
	// cpp `Reflect.field` returns null for get/set properties (only
	// `Reflect.getProperty`, which is what a script's field access compiles to,
	// runs the getter), so read the property itself.
	var d = (camHUD != null) ? camHUD.downscroll : null;
	if (d != null) return d == true;
	if (PlayState.instance != null && PlayState.instance.downscroll != null)
		return PlayState.instance.downscroll == true;
	return false;
}

// Psych's HUD rows are physical screen positions, and CNE's HudCamera draws a HUD
// sprite at `height - y - sprite.height`, so a row copied from the source is
// mirrored a second time. Callers pass the row they want the sprite drawn on;
// the fork's own downscroll rows are hand-built for a camera that does not flip.
function mmHudY(s, up:Float, down:Float):Float {
	if (!mmDownscroll()) return up;
	var h:Float = (camHUD != null) ? camHUD.height : FlxG.height;
	return h - down - s.height;
}

// `playerStrums.members[i].x` in the source. Codename has no `playerStrums` field:
// the charts build the opponent line first, so BF's is `strumLines.members[1]`
// (songs/MMmodfields.hx's FW_LINE says the same).
function mmPlayerStrum(i:Int) {
	var ps = PlayState.instance;
	if (ps == null) return null;
	var lines = Reflect.field(ps, "strumLines");
	if (lines == null) return null;
	var mem = Reflect.field(lines, "members");
	if (mem == null || mem.length <= 1) return null;
	var line = mem[1];
	if (line == null) return null;
	var strums = Reflect.field(line, "members");
	if (strums == null || strums.length <= i) return null;
	return strums[i];
}

function mmStrumX(i:Int):Float {
	var s = mmPlayerStrum(i);
	return (s != null) ? s.x : 0;
}

// The row BF's strums sit on. The source's HUD Mario rows are relative to Psych's
// row of 50, so they are rebuilt from this engine's row instead.
var MM_SOURCE_STRUM_ROW:Float = 50;
function mmStrumY():Float {
	var s = mmPlayerStrum(0);
	if (s != null && s.y != null) return s.y;
	return MM_SOURCE_STRUM_ROW;
}

// Centres a HUD sprite on one of BF's lanes. The source's
// `playerStrums.members[3].x + 105` (12015) is measured from Psych's strum origin,
// so it lands off the right of the line here. Lane spacing is the step from lane 0
// to lane 3; a strum's width is not read because it may already carry the note
// scale.
function mmCenterOnStrums(s, lane:Int = 3) {
	if (s == null) return;
	var a:Float = mmStrumX(0);
	var d:Float = mmStrumX(3);
	if (a == 0 && d == 0) {
		s.x = (FlxG.width - s.width) / 2;
		return;
	}
	var step:Float = (d - a) / 3;
	s.x = a + step * lane + step / 2 - s.width / 2;
}

// The hop moves him left as it plays - `x -= 80` at once, then 45 more over 0.8
// beats - so at the peak he sits about 102px left of where he started. Columns
// are offset right by that much.
var MM_HOP_LEAN:Float = 102.5;

// Case 11 fires the hop three times and case 12 a fourth; the source's 125px per
// hop is about one lane, so he stomps lanes 3, 2, 1, 0. Each hop re-anchors while
// the previous one is off screen (row 800).
var mmHudHop:Int = 0;
function mmHudMarioColumn(m, lane:Int) {
	if (m == null) return;
	mmCenterOnStrums(m, lane);
	m.x += MM_HOP_LEAN;
}

function mmHudMarioNextColumn(m) {
	var lane:Int = 3 - mmHudHop;
	if (lane < 0) lane = 0;
	mmHudHop += 1;
	mmHudMarioColumn(m, lane);
}

// ---------------------------------------------------------------------------
// The camEst layer (see the header)
// ---------------------------------------------------------------------------
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

function mmEstBelowHud() {
	if (mmEstCam == null) return;
	var list = (FlxG.cameras != null) ? FlxG.cameras.list : null;
	if (list == null) return;
	list.remove(mmEstCam);
	var at:Int = -1;
	var i:Int = 0;
	while (i < list.length) {
		if (list[i] == camHUD) { at = i; break; }
		i += 1;
	}
	if (at < 0) { list.push(mmEstCam); return; }
	list.insert(at, mmEstCam);
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

// ---------------------------------------------------------------------------
// The stage's sprites
// ---------------------------------------------------------------------------
var mmBye:FlxSprite = null;
function mmGetBye():FlxSprite {
	if (mmBye == null) {
		// 5593-5604. (The existence guard asks for the atlas' *png*, the way
		// data/notes/Bad Poison.hx does - Paths.getSparrowAtlas returns frames.)
		if (!Assets.exists(Paths.image("modstuff/bye"))) return null;
		mmBye = new FlxSprite();
		mmBye.frames = Paths.getSparrowAtlas("modstuff/bye");
		mmBye.animation.addByPrefix("p1", "goodbye", 15, false);
		mmBye.animation.addByPrefix("p2", "bye bye", 15, false);
		mmBye.animation.addByPrefix("p3", "hello", 24, false);
		mmBye.scrollFactor.set(0, 0);
		mmBye.cameras = [mmEst()];
		mmBye.alpha = 0.0000001;
		mmBye.screenCenter();
		mmBye.y -= 2;
		mmBye.x -= 2;
		add(mmBye);
	}
	return mmBye;
}

var mmHudMario = null;
function mmGetHudMario() {
	if (mmHudMario == null) {
		// 2044-2051.
		if (!Assets.exists(Paths.image("mario/BadMario/HUD_Mario"))) return null;
		mmHudMario = new FlxSprite(0, 0);
		mmHudMario.frames = Paths.getSparrowAtlas("mario/BadMario/HUD_Mario");
		mmHudMario.animation.addByPrefix("walk", "mario walk", 12, true);
		mmHudMario.animation.addByPrefix("spin", "mario spin jump", 18, true);
		mmHudMario.animation.addByPrefix("jump", "jump", 12, true);
		mmHudMario.animation.addByPrefix("fall", "fall", 12, true);
		mmHudMario.scale.set(5, 5);
		mmHudMario.cameras = [camHUD];
		// mmHudY and the camera mirror both use the sprite's own box.
		mmHudMario.updateHitbox();
	}
	return mmHudMario;
}

var mmGrad1:FlxSprite = null;
var mmGrad2:FlxSprite = null;
function mmGetGrads() {
	if (mmGrad1 == null) {
		// 2024-2035 (camOther -> camHUD, see the header).
		if (!Assets.exists(Paths.image("mario/BadMario/sideBar"))) return;
		mmGrad1 = new FlxSprite(0, 0).loadGraphic(Paths.image("mario/BadMario/sideBar"));
		mmGrad1.cameras = [camHUD];
		mmGrad1.visible = false;
		mmGrad1.alpha = 0;
		add(mmGrad1);

		mmGrad2 = new FlxSprite(600, 0).loadGraphic(Paths.image("mario/BadMario/sideBar"));
		mmGrad2.cameras = [camHUD];
		mmGrad2.visible = false;
		mmGrad2.alpha = 0;
		mmGrad2.flipX = true;
		add(mmGrad2);
	}
}

// 2053-2055 + 5574-5580: `blackBarThingie` for this stage - see postCreate.
var mmSuperbadBar = null;

// badmario.xml's own `x="90" y="535"` (Psych's badmario.json `position`): the
// engine adds a character's own position to the stage's, so his frame is drawn
// that far in from the sprite's stored `dad.x`/`dad.y`. Anything the source
// spawns at `dad.x + n, dad.y + n` needs the pair added to it - without it the
// case 6 shell started 535px above his head, off the top of the screen.
var MM_MARIO_OX = 90;
var MM_MARIO_OY = 535;

function postCreate() {
	mmGetBye();
	mmGetHudMario(); // built, not added - case 10 adds it
	mmGetGrads();

	// 2013: `camHUD.visible = false` in the create switch - the song opens with
	// no HUD at all, not the alpha-0 the other stages use. Case 3 is what turns
	// it back on (its 0.75s alpha fade in case 0 is independent of it).
	if (camHUD != null) camHUD.visible = false;

	// 5574-5590: the create-time block the source's own "im sorry little one..."
	// comment sits on. `blackBarThingie` (2053-2055) is a 10x-scaled opaque black
	// plate (no alpha write at all) inserted right after the boyfriend, with
	// dadGroup put back right after the plate - so the world and *the boyfriend*
	// are behind it and only dad shows. It stays up until case 3 sets
	// `visible = false` (11868), i.e. through the whole byecirc intro; that is
	// the fork's screen, kept literal.
	if (mmSuperbadBar == null) {
		mmSuperbadBar = new FunkinSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		mmSuperbadBar.scale.set(10, 10);
		add(mmSuperbadBar);
		if (boyfriend != null) {
			remove(mmSuperbadBar, true);
			var bi:Int = members.indexOf(boyfriend);
			insert(bi >= 0 ? bi + 1 : 0, mmSuperbadBar);
		}
		if (dad != null) {
			remove(dad, true);
			var pi:Int = members.indexOf(mmSuperbadBar);
			insert(pi >= 0 ? pi + 1 : members.length, dad);
		}
	}

	// 5584-5585: `dadGroup.x = -50` / `dadGroup.y = 400` on top of the stage
	// JSON's own dad marker (`opponent: [90, -190, ...]`, i.e. the XML's
	// 90/-190). A group offset is a plain shift of what is already on screen, so
	// it lands dad at (40, 210).
	if (dad != null) {
		dad.x -= 50;
		dad.y += 400;
	}
}

// 7378-7381: the poison side bars fade down towards 0.15 (0.1 with flashes off,
// which this port takes as on).
function postUpdate(elapsed) {
	if (mmGrad1 != null && mmGrad1.alpha >= 0.15) mmGrad1.alpha -= 0.01;
	if (mmGrad2 != null && mmGrad2.alpha >= 0.15) mmGrad2.alpha -= 0.01;
}

// ---------------------------------------------------------------------------
// The two pieces cases 11/12/13 re-dispatch
// ---------------------------------------------------------------------------
// Case 13 (12104-12138): mario's little white flash, inserted right above the
// HUD Mario.
function mmBadFlash() {
	var m = mmGetHudMario();
	if (m == null) return;
	var badFlash = new FlxSprite(m.x + 70, m.y + 150);
	badFlash.frames = Paths.getSparrowAtlas("mario/BadMario/HUD_Mario");
	badFlash.animation.addByPrefix("idle", "flash", 10, false);
	badFlash.cameras = [camHUD];
	badFlash.scale.set(5, 5);
	if (!mmDownscroll()) {
		FlxG.sound.play(Paths.sound("bad-day/smw_stomp2"), 0.5);
	} else {
		// 12097-12101: row 730, 70px under the jump. The source also centres it on
		// the screen; here it keeps the `m.x + 70` it was built with so it stays on
		// him (see mmHudY for the row).
		badFlash.updateHitbox();
		badFlash.y = mmHudY(badFlash, 0, 570);
	}
	insert(members.indexOf(m) + 1, badFlash);
	badFlash.animation.play("idle", true);
}

// Case 11's downscroll half (12026-12046): the HUD Mario hops, with the shell
// drop of case 12's own else branch (12048-12084) kept separate below.
function mmHudMarioHop() {
	var m = mmGetHudMario();
	if (m == null) return;
	// Next lane left, then the source's own 80 + 45 walk.
	mmHudMarioNextColumn(m);
	m.x -= 80;
	m.animation.play("jump", true);
	FlxG.sound.play(Paths.sound("bad-day/smw_jump"), 0.7);
	FlxTween.tween(m, {x: m.x - 45}, 0.8 / (Conductor.bpm / 60), {startDelay: 0.1, ease: FlxEase.quadIn});
	// 12030-12044: up to 660 and back down to 800. The fall has to end off screen
	// or he is left hanging there after the last hop (see mmHudY).
	FlxTween.tween(m, {y: mmHudY(m, 0, 500)}, 0.4 / (Conductor.bpm / 60), {startDelay: 0.1, ease: FlxEase.quadOut, onComplete: function(twn) {
		m.animation.play("fall", true);
		FlxG.sound.play(Paths.sound("bad-day/smw_stomp2"), 0.5);
		FlxTween.tween(m, {y: mmHudY(m, 0, 800)}, 0.4 / (Conductor.bpm / 60), {ease: FlxEase.linear});
	}});
}

// Case 12's downscroll half (12061-12084): mario throws a second shell, on the
// HUD this time. It climbs from the bottom row up to the health bar, then drops
// back off the screen - which is the hit that case 14 answers with the bar
// falling away.
function mmHudShell() {
	var m = mmGetHudMario();
	if (m == null || !Assets.exists(Paths.image("mario/BadMario/shell"))) return;
	FlxG.sound.play(Paths.sound("bad-day/smw_shell_kick"), 0.5);
	var shell = new FlxSprite().loadGraphic(Paths.image("mario/BadMario/shell"));
	shell.scale.set(5, 5);
	shell.x = (FlxG.width - shell.width) / 2;
	shell.updateHitbox();
	shell.y = mmHudY(shell, 0, 710);
	shell.angle -= 30;
	shell.cameras = [camHUD];
	insert(members.indexOf(m) + 1, shell);
	mmBadFlash();
	FlxTween.tween(shell, {angle: 30}, 1 / (Conductor.bpm / 60));
	FlxTween.tween(shell, {y: mmHudY(shell, 0, 60)}, 1 / (Conductor.bpm / 60), {onComplete: function(twn) {
		FlxTween.tween(shell, {x: shell.x + 90}, 1.5);
		FlxTween.tween(shell, {y: mmHudY(shell, 0, 900)}, 1.5, {ease: FlxEase.backIn, onComplete: function(twn2) { shell.kill(); }});
	}});
}

// The block case 14 drags onto camEst. The source moves `healthBar` and the icons
// and its AttachedSprite frame follows; here the frame is its own engine sprite,
// and the source's one `scoreTxt` is three (`scoreTxt`, `missesTxt`,
// `accuracyTxt`), so they are all listed.
function mmHudSet() {
	return [healthBar, healthBarBG, iconP1, iconP2, scoreTxt, missesTxt, accuracyTxt];
}

// Moving a sprite off camHUD loses the HudCamera's downscroll mirror, which flips
// the drawn position rather than the sprite. Mirror each y on the way out and
// `mmHudBack` restores the logical ones.
var mmHudSaved = null;
function mmHudTo(est) {
	if (mmHudSaved == null) mmHudSaved = [];
	if (mmHudSaved.length > 0) return;
	var h:Float = (camHUD != null) ? camHUD.height : FlxG.height;
	for (s in mmHudSet()) {
		if (s == null) continue;
		mmHudSaved.push({spr: s, y: s.y});
		if (mmDownscroll()) s.y = h - s.y - s.height;
		s.cameras = [est];
	}
}

function mmHudBack() {
	if (mmHudSaved == null) return;
	for (e in mmHudSaved) {
		if (e.spr == null) continue;
		e.spr.y = e.y;
		e.spr.cameras = [camHUD];
	}
	mmHudSaved = [];
}

// 11897-11916 and the shroom's 11925-11940: both spawn 140/80 from the top-left
// of mario's frame, which the engine draws MM_MARIO_OX/OY in from his stored
// position.
function mmShellFromMario(spr) {
	if (dad == null) return;
	spr.setPosition(dad.x + MM_MARIO_OX + 140, dad.y + MM_MARIO_OY + 80);
}

// ---------------------------------------------------------------------------
// 'Triggers Bad Day' 0-15
// ---------------------------------------------------------------------------
function onEvent(event) {
	if (event.event.name != "Triggers Bad Day" && event.event.name != "Triggers Universal") return;
	var trigger = Std.parseInt(event.event.params[0]);
	if (trigger == null || Math.isNaN(trigger)) trigger = 0;
	var trigger2 = Std.parseInt(event.event.params[1]);
	if (trigger2 == null || Math.isNaN(trigger2)) trigger2 = 0;

	switch (trigger) {
		case 0:
			// 11845-11855 (see the header for the camera write and the bars).
			mmCam("setCam", ["dad", 500, 390, null]);
			if (mmGrad1 != null) FlxTween.tween(mmGrad1, {alpha: 0}, 0.2, {ease: FlxEase.quadInOut});
			if (mmGrad2 != null) FlxTween.tween(mmGrad2, {alpha: 0}, 0.2, {ease: FlxEase.quadInOut});
			FlxTween.tween(camHUD, {alpha: 0}, 0.75, {ease: FlxEase.quadInOut});
			var bye = mmGetBye();
			if (bye != null) {
				bye.alpha = 1;
				bye.animation.play("p1");
			}
		case 1:
			// 11856-11858.
			var bye2 = mmGetBye();
			if (bye2 != null) {
				bye2.animation.play("p2");
				bye2.alpha = 1;
			}
		case 2:
			FlxTween.tween(dad, {x: 90}, 0.8);
			dad.playAnim("jump1", true);
			FlxTween.tween(dad, {y: -350}, 0.55, {ease: FlxEase.quadOut, onComplete: function(twn) {
				dad.playAnim("jump2", true);
				FlxTween.tween(dad, {y: -180}, 0.25, {ease: FlxEase.quadIn});
			}});
		case 3:
			// 11866-11872: the plate comes off, the HUD comes on, the camera is
			// handed back to the section block and dad's zoom target goes to 1.4.
			if (mmSuperbadBar != null) mmSuperbadBar.visible = false;
			dad.playAnim("singDOWN", true);
			mmCam("follow", [true]);
			mmCam("zoomFollow", [true]);
			mmCam("zoomFor", ["dad", 1.4]);
			camHUD.visible = true;
			FlxG.camera.flash(FlxColor.WHITE, 0.8);
		case 4:
			// 11883-11886: DAD_CAM_X/Y = 380, 410 and DAD_ZOOM = 1.7.
			mmCam("setCam", ["dad", 380, 410, 1.7]);
		case 5:
			// 11888-11891.
			mmCam("setCam", ["dad", 520, 380, 1.4]);
		case 6:
			if (trigger2 == 0) {
				dad.playAnim("shell", true);
				new FlxTimer().start(0.4, function(tmr) {
					FlxG.sound.play(Paths.sound("bad-day/smw_shell_kick"), 0.5);
					if (!Assets.exists(Paths.image("mario/BadMario/shell"))) return;
					var shell = new FlxSprite().loadGraphic(Paths.image("mario/BadMario/shell"));
					shell.scale.set(4, 4);
					mmShellFromMario(shell);
					add(shell);
					FlxTween.tween(shell, {y: shell.y + 40}, 0.5 / (Conductor.bpm / 60), {ease: FlxEase.quadIn});
					FlxTween.tween(shell, {x: shell.x + 360}, 0.5 / (Conductor.bpm / 60), {onComplete: function(twn) {
						boyfriend.playAnim("hit", true);
						health -= 0.25;
						FlxG.sound.play(Paths.sound("bad-day/smw_stomp"), 0.5);
						FlxTween.tween(shell, {x: shell.x - 90}, 0.8);
						FlxTween.tween(shell, {y: 900}, 0.8, {ease: FlxEase.backIn, onComplete: function(twn2) { shell.kill(); }});
					}});
				});
			} else {
				dad.playAnim("shroom", true);
				new FlxTimer().start(0.4, function(tmr) {
					FlxG.sound.play(Paths.sound("bad-day/smw_shell_kick"), 0.5);
					if (!Assets.exists(Paths.image("mario/BadMario/shroom"))) return;
					var shroom = new FlxSprite().loadGraphic(Paths.image("mario/BadMario/shroom"));
					shroom.scale.set(4, 4);
					mmShellFromMario(shroom);
					add(shroom);
					FlxTween.tween(shroom, {y: 900}, 1 / (Conductor.bpm / 60), {ease: FlxEase.quadIn});
					FlxTween.tween(shroom, {x: shroom.x + 200}, 1 / (Conductor.bpm / 60), {onComplete: function(twn) { shroom.kill(); }});
				});
			}
		case 7:
			dad.flipX = true;
			dad.playAnim("walk", true);
			FlxTween.tween(dad, {x: -230}, 1.5 / (Conductor.bpm / 60), {ease: FlxEase.quadIn, onComplete: function(twn) {
				new FlxTimer().start(1.5 / (Conductor.bpm / 60), function(tmr) {
					dad.playAnim("run", true);
					dad.flipX = false;
					FlxTween.tween(dad, {x: 90}, 0.6 / (Conductor.bpm / 60));
				});
			}});
			new FlxTimer().start(3.6 / (Conductor.bpm / 60), function(tmr) {
				FlxTween.tween(dad, {x: 1200}, 2 / (Conductor.bpm / 60));
				dad.playAnim(FlxG.random.bool(50) ? "vile creature" : "jump3", true);
				FlxG.sound.play(Paths.sound("bad-day/smw_jump"), 0.7);
				FlxTween.tween(dad, {y: -400}, 0.8 / (Conductor.bpm / 60), {ease: FlxEase.quadOut, onComplete: function(twn) {
					FlxTween.tween(dad, {y: -280}, 0.6 / (Conductor.bpm / 60), {ease: FlxEase.quadIn, onComplete: function(twn2) {
						FlxG.sound.play(Paths.sound("bad-day/smw_stomp2"), 0.5);
						if (gf != null) gf.playAnim("hit", true);
						FlxTween.tween(dad, {y: -360}, 0.3 / (Conductor.bpm / 60), {ease: FlxEase.quadOut, onComplete: function(twn3) {
							FlxTween.tween(dad, {y: -120}, 0.3 / (Conductor.bpm / 60), {ease: FlxEase.quadIn});
						}});
					}});
				}});
			});
		case 8:
			dad.setPosition(-70, -540);
			FlxTween.tween(dad, {x: 90}, 1 / (Conductor.bpm / 60));
			FlxTween.tween(dad, {y: -180}, 1 / (Conductor.bpm / 60), {ease: FlxEase.quadIn, onComplete: function(twn) {
				dad.playAnim("singDOWN", true);
			}});
		case 9:
			// 11991-11994: `BF_CAM_X = 730; BF_CAM_Y = 420; BF_ZOOM = 1.3;` - the
			// section follows BF again from here, which is what makes the write
			// visible (this stage's create block leaves FOLLOWCHARS off).
			mmCam("setCam", ["bf", 730, 420, 1.3]);
		case 10:
			// 11996-12024: mario jumps up to the notes and walks across them.
			var m10 = mmGetHudMario();
			if (m10 == null) return;
			add(m10);
			if (!mmDownscroll()) {
				// 12002/12006/12008: 100, -110 and -10 on Psych's row of 50, i.e.
				// +50, -160 and -60 from the row (see mmStrumY).
				m10.setPosition(1280, mmStrumY() + 50);
				m10.animation.play("spin", true);
				FlxG.sound.play(Paths.sound("bad-day/smw_spinjump"), 0.6);
				FlxTween.tween(m10, {x: mmStrumX(3) + 35}, 1.5 / (Conductor.bpm / 60));
				FlxTween.tween(m10, {y: mmStrumY() - 160}, 0.9 / (Conductor.bpm / 60), {ease: FlxEase.quadOut, onComplete: function(twn) {
					FlxTween.tween(m10, {y: mmStrumY() - 60}, 0.6 / (Conductor.bpm / 60), {ease: FlxEase.quadIn, onComplete: function(twn2) {
						FlxTween.tween(m10, {x: mmStrumX(0) - 110 - 400}, 7.5 / (Conductor.bpm / 60));
					}});
				}});
			} else {
				// 12015 parks him on row 800, under the bottom edge that cases 11/12 hop
				// him out of (see mmHudY). Column from the lanes, not the source's `+ 105`.
				m10.y = mmHudY(m10, 0, 800);
				mmHudHop = 0;
				mmHudMarioColumn(m10, 3);
			}
		case 11:
			// 12026-12046.
			if (!mmDownscroll()) {
				mmBadFlash();
				var m11 = mmGetHudMario();
				if (m11 == null) return;
				FlxTween.tween(m11, {y: mmStrumY() - 130}, 0.5 / (Conductor.bpm / 60), {ease: FlxEase.quadOut, onComplete: function(twn) {
					FlxTween.tween(m11, {y: mmStrumY() - 60}, 0.5 / (Conductor.bpm / 60), {ease: FlxEase.quadIn});
				}});
			} else {
				mmHudMarioHop();
			}
		case 12:
			// 12048-12084: the last hop, or the HUD shell that falls on the bar.
			if (!mmDownscroll()) {
				mmBadFlash();
				var m12 = mmGetHudMario();
				if (m12 == null) return;
				FlxTween.tween(m12, {y: mmStrumY() - 130}, 0.5 / (Conductor.bpm / 60), {ease: FlxEase.quadOut, onComplete: function(twn) {
					FlxTween.tween(m12, {y: 575}, 2 / (Conductor.bpm / 60), {ease: FlxEase.quadIn});
				}});
			} else {
				// 12058-12060: the downscroll half re-dispatches case 11 (the hop)
				// straight away and throws the shell 1.5 beats later, not at once.
				mmHudMarioHop();
				new FlxTimer().start(1.5 / (Conductor.bpm / 60), function(tmr) {
					mmHudShell();
				});
			}
		case 13:
			mmBadFlash();
		case 14:
			// 12104-12138: the bar's block is dragged onto camEst and the camera is
			// thrown off the screen - mario has just stomped it. See mmHudSet for
			// what `healthBar`/`healthBarBG`/the icons/the score are here.
			var est = mmEst();
			mmHudTo(est);
			if (!mmDownscroll()) {
				FlxTween.tween(est, {y: 500}, 0.8, {ease: FlxEase.backIn});
				FlxTween.tween(est, {angle: 20}, 0.8, {ease: FlxEase.cubeIn});
				// the case's own `triggerEventNote('Screen Shake', '0.15, 0.03',
				// '0.1, 0.05')`, inlined (see data/events/Screen Shake.hx).
				camGame.shake(0.03, 0.15);
				camHUD.shake(0.05, 0.1);
				FlxG.sound.play(Paths.sound("bad-day/smw_thud"), 1);
				var m14 = mmGetHudMario();
				if (m14 != null) {
					FlxTween.tween(m14, {x: m14.x - 70}, 1.2 / (Conductor.bpm / 60));
					FlxTween.tween(m14, {y: m14.y - 100}, 0.5 / (Conductor.bpm / 60), {ease: FlxEase.quadOut, onComplete: function(twn) {
						FlxTween.tween(m14, {y: 800}, 0.7 / (Conductor.bpm / 60), {ease: FlxEase.quadIn});
					}});
				}
			} else {
				FlxG.sound.play(Paths.sound("bad-day/smw_break_block"), 0.5);
				est.shake(0.07, 0.2);
				new FlxTimer().start(0.5 / (Conductor.bpm / 60), function(tmr) {
					FlxTween.tween(est, {y: 800}, 1, {ease: FlxEase.quadIn});
					FlxTween.tween(est, {x: -80}, 1, {ease: FlxEase.quadIn});
					FlxTween.tween(est, {angle: 15}, 1, {ease: FlxEase.quadIn});
				});
			}
		case 15:
			// 12140-12160: yahoo - the HUD is put back and the screen flashes.
			var est2 = mmEst();
			est2.setPosition(0, 0);
			est2.angle = 0;
			mmHudBack();
			mmGetGrads();
			if (mmGrad1 != null) mmGrad1.visible = true;
			if (mmGrad2 != null) mmGrad2.visible = true;
			FlxG.camera.flash(FlxColor.WHITE, 1.5);
	}
}
// === end MM stage triggers ===
