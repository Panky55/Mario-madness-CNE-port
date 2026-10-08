// Ported from PlayState.hx beatHit() (case 'hatebg').
// The drowned Marios dance every other beat once their section starts.
// NOTE: the source's 'I Hate You Old' branch only changes x/y/offset instead
// of the animation offset -- the default offset branch is used here.
function beatHit(curBeat:Int) {
	if (curBeat >= 320 && curBeat % 2 == 0) {
		blueMario.playAnim('dance', false);
		blueMario.offset.x = -55;
	}
	if (curBeat >= 330 && curBeat % 2 == 0) {
		blueMario2.playAnim('dance', false);
		blueMario2.offset.x = -55;
	}
}

// === MM stage triggers (auto) ===
// ---------------------------------------------------------------------------
// IHY lava layer
// ---------------------------------------------------------------------------
// Source: PlayState.hx:5049-5100 (creation) and the 'Sacar Lava' handler at
// 9413. The lava is a foreground layer drawn on the HUD camera, so it stays put
// while the world scrolls. Creation (the `!ClientPrefs.lowQuality` branch - the
// low-quality variant is not reachable from a script):
//   new FlxSprite(-18, 750); sparrow 'modstuff/Luigi_IHY_Background_Assets_Lava';
//   addByPrefix('idle', 'Lava', 12); setGraphicSize(width * 1.3);
//   cameras = [camHUD]; downscroll: y = -440 and flipY = true.
// The source also drives a `lavaEmitter` particle system beside it; its
// LavaParticle class is not script-reachable, so only the lava layer is ported.
// This used to live in data/events/Sacar Lava.hx, which read a PlayState field
// nothing ever created - the sprite belongs to this stage, so it is created here.
var mmIhyLava:FlxSprite = null;
var mmLavaTween = null;

function mmDownScroll():Bool {
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

function mmGetLava():FlxSprite {
	if (mmIhyLava != null) return mmIhyLava;
	mmIhyLava = new FlxSprite(-18, 750);
	mmIhyLava.frames = Paths.getSparrowAtlas("modstuff/Luigi_IHY_Background_Assets_Lava");
	mmIhyLava.animation.addByPrefix("idle", "Lava", 12);
	mmIhyLava.setGraphicSize(Std.int(mmIhyLava.width * 1.3));
	mmIhyLava.updateHitbox();
	mmIhyLava.animation.play("idle");
	if (mmDownScroll()) {
		mmIhyLava.y = -440;
		mmIhyLava.flipY = true;
	}
	mmIhyLava.cameras = [camHUD];
	add(mmIhyLava);
	return mmIhyLava;
}

// Source PlayState.hx:9413. params[0] = target y, params[1] = mode:
// 0 = quick (0.25s quadOut), 1 = ping-pong (2s quadInOut, kept in `mmLavaTween`
// so mode 3 can cancel it), 2 = slow (5s quadInOut), 3 = cancel.
// Downscroll mirrors the coordinate (`lavacord * -1 + 350`).
function mmSacarLava(params) {
	var lava = mmGetLava();
	if (lava == null) return;

	var cord = Std.parseFloat(Std.string(params[0]));
	if (cord == null || Math.isNaN(cord)) cord = 730;
	var mode:Float = 0;
	if (params.length > 1) mode = Std.parseFloat(Std.string(params[1]));
	if (mode == null || Math.isNaN(mode)) mode = 0;

	var target:Float = mmDownScroll() ? (cord * -1 + 350) : cord;
	if (mode == 0) {
		FlxTween.tween(lava, {y: target}, 0.25, {ease: FlxEase.quadOut});
	} else if (mode == 1) {
		mmLavaTween = FlxTween.tween(lava, {y: target}, 2, {ease: FlxEase.quadInOut, type: FlxTween.PINGPONG});
	} else if (mode == 2) {
		FlxTween.tween(lava, {y: target}, 5, {ease: FlxEase.quadInOut});
	} else if (mode == 3) {
		if (mmLavaTween != null) mmLavaTween.cancel();
	}
}

// 'Triggers I Hate You' - ported from PlayState.hx (case 'Triggers I Hate You').
// `capenose` - I Hate You's cape BF - is built in the script (the art ships:
// the same sheet forest's `capenose` uses); see the cape section below. Cases
// 9/10 use approximate camera targets (the source tweens DAD_CAM_X/Y, which
// songs/MMcamera.hx owns). `startbf` and the black curtain are the stage's
// (mmHateStartbf / mmHateCurtainSpr below).

function onEvent(event) {
	if (event.event.name == "Sacar Lava") {
		mmSacarLava(event.event.params);
		return;
	}
	// hatebg is shared: 'I Hate You', 'I Hate You Old' and 'Oh God No' all run on
	// it, and all three send their beats under the generic 'Triggers Universal'
	// name (the source re-dispatches it to 'Triggers <song>' at runtime). The
	// song is therefore the only thing that can read value1 - the two songs'
	// numbering overlaps (0-6 is both the start of Oh God No's story and part of
	// I Hate You's), so an ungated switch would run the wrong song's beats. Same
	// gate, same reason, as MMcamera's per-stage dispatch.
	if (mmOgnSong()) {
		if (event.event.name != "Triggers Oh God No" && event.event.name != "Triggers Universal") return;
		var ogn = Std.parseInt(event.event.params[0]);
		if (ogn == null || Math.isNaN(ogn)) ogn = 0;
		mmOgnTrigger(ogn);
		return;
	}
	if (event.event.name != "Triggers I Hate You" && event.event.name != "Triggers Universal") return;
	var trigger = Std.parseInt(event.event.params[0]);
	if (trigger == null || Math.isNaN(trigger)) trigger = 0;

	switch (trigger) {
		case 0:
			// 11383-11392: 'I Hate You Old' whips its ghosts in fast (0.5-0.8s,
			// to x -100/1100/1050) where the modern song's drift in over 2-3s.
			if (mmIhyOld()) {
				FlxTween.tween(eyelessboo, {alpha: 1, x: -100}, 0.6, {ease: FlxEase.quadOut});
				FlxTween.tween(eyelessboo2, {alpha: 1, x: 1100}, 0.5, {ease: FlxEase.quadOut});
				FlxTween.tween(eyelessboo3, {alpha: 1, x: 1050}, 0.8, {ease: FlxEase.quadOut});
			} else {
				FlxTween.tween(eyelessboo, {alpha: 1, x: -300}, 2, {ease: FlxEase.expoOut});
				FlxTween.tween(eyelessboo2, {alpha: 1, x: 1300}, 3, {ease: FlxEase.expoOut});
				FlxTween.tween(eyelessboo3, {alpha: 1, x: 1250}, 2.5, {ease: FlxEase.expoOut});
			}
		case 1:
			bgsign.alpha = 1;
			camGame.shake(0.05, 0.2);
		case 2:
			new FlxTimer().start(0.1, function(tmr) { blueMario.visible = true; });
			blueMario.playAnim("hey", false);
		case 3:
			new FlxTimer().start(0.1, function(tmr) { blueMario2.visible = true; });
			blueMario2.playAnim("hey", false);
		case 4:
			// `startbf` out, the curtain out, the HUD in. Neither I Hate You chart
			// actually sends 4 (they use 0-3 and then 5/6/9/10/11 through 'Triggers
			// Universal'), so the curtain is really lifted by the countdown's own
			// 1.8s timer in mmHateIntroTimers; this stays for completeness.
			FlxTween.tween(mmHateStartbf(), {alpha: 0}, 1, {ease: FlxEase.quadOut});
			FlxTween.tween(mmHateCurtainSpr(), {alpha: 0}, 1, {ease: FlxEase.quadOut});
			FlxTween.tween(camHUD, {alpha: 1}, 1, {ease: FlxEase.quadInOut});
		case 5:
			// 11418: the cape goes before BF's prejump (the modern song only).
			if (mmIhyCapeActive() && mmIhyCape != null) mmIhyCape.visible = false;
			boyfriend.playAnim("prejump", true);
		case 6:
			boyfriend.playAnim("spin", true);
			FlxTween.tween(boyfriend, {y: -100}, 0.2, {ease: FlxEase.quadOut, onComplete: function(twn) {
				FlxTween.tween(boyfriend, {y: 60}, 0.2, {ease: FlxEase.quadIn});
			}});
			FlxTween.tween(boyfriend, {x: 50}, 0.4, {onComplete: function(twn) {
				boyfriend.playAnim("attack", true);
				dad.playAnim("fall", true);
				camGame.shake(0.007, 0.15);
				camHUD.shake(0.007, 0.15);
				FlxTween.tween(dad, {x: -1600}, 1.5);
				FlxTween.tween(dad, {angle: -67}, 1.5, {ease: FlxEase.quadOut});
				FlxTween.tween(dad, {y: -300}, 0.6, {ease: FlxEase.cubeOut, onComplete: function(twn2) {
					FlxTween.tween(dad, {y: 1900}, 0.9, {ease: FlxEase.quadIn});
					// 11436-11442 + 7823-7824: 0.19s into the fall the cape BF
					// reappears at BF's own (group) x + 260.
					new FlxTimer().start(0.19, function(tmr) {
						if (!mmIhyCapeActive()) return;
						var cape = mmIhyCapenose();
						cape.visible = true;
						cape.x = mmOgnGroupX(boyfriend) + 260;
					});
				}});
			}});
			new FlxTimer().start((7 * (1 / (Conductor.bpm / 60))), function(tmr) {
				dad.playAnim("hand", true);
				dad.setPosition(-1200, 500);
				dad.angle = 0;
				FlxTween.tween(dad, {y: 800}, 2, {startDelay: 0.3, onComplete: function(twn) {
					dad.visible = false;
				}});
			});
		case 9:
			FlxTween.tween(camFollow, {x: dad.x + 100, y: dad.y - 200}, 2.5, {ease: FlxEase.cubeInOut});
		case 10:
			FlxTween.tween(camFollow, {y: camFollow.y + 250}, 10, {ease: FlxEase.cubeInOut});
			FlxTween.tween(camGame, {zoom: 1}, 10, {ease: FlxEase.cubeInOut});
			FlxTween.tween(this, {defaultCamZoom: 1}, 10, {ease: FlxEase.cubeInOut});
		case 11:
			// The song ends on the curtain (135.7s).
			mmHateCurtainSpr().alpha = 1;
}
}

// ===========================================================================
// Oh God No - PlayState.hx's `case 'hatebg'` + every `SONG.song == 'Oh God No'`
// branch. The stage is shared with I Hate You, so all of it is gated on the
// song (mmOgnSong, used by onEvent above).
// ===========================================================================
// What the source does for this song, and where each piece lands here:
//   1538-1556  flipchar, gfGroup -> alpha 0.000001, boyfriendGroup.x = 0 /
//              dadGroup.x = 770, and the per-character camera boxes (BF 220/350,
//              DAD 620/290). The camera half is MMcamera's (mmOgnCamera).
//   1588-1612  the four `mario/IHY/OGN_Fireball` layers.
//   1691-1697  the *complete* bridge instead of the broken one.
//   1716-1719  blackOGNThingie, a screen-sized black overlay.
//   4357-4359  `add(fire2); add(fire1);` - in front of the fighters, unlike the
//              other two, which are added before `add(boyfriendGroup)` (4331).
//   4585-4589  a SilhouetteShader on BF (255,0,59) and dad (20,180,0).
//   5035-5039  `blackBarThingie`, the black curtain the stage loads on.
//   5039-5046  `startbf` from `modstuff/hatestartM`.
//   5099-5148  the opening cutscene: `introbg` / `introM` / `introL`.
//   5150-5170  `bbar1`/`bbar2` (the two cinema bars) and `luigiCut`.
//   6384-6415  the startCountdown() branch that animates the cutscene, flashes
//              `startbf`, lifts the curtain and holds the song for four seconds.
//   11296-11376 'Triggers Oh God No' 0-6.
//   15990-16010 (stepHit) the 1235 shake and the 1380 blood cut.
//
// The source's own PlayState never touches `introLText` (5136-5148) or
// `introM`'s `shock`/`scared`/`idle` and `introL`'s `worked`/`alone`/
// `transition` after creating them - but the song's *lua* does:
// `assets/preload/data/songData/oh-god-no/script.lua` drives the dialogue half
// of this cutscene from its own steps (`onStepHit`: 6/10/15/21/24/25) and
// re-frames the camera on beat 23 (`onBeatHit`). All of that is ported below
// (`mmOgnIntroText` plus the head of `stepHit`; the beat rides along there as
// step 92, because this stage's *generated* head already owns `beatHit`); the
// walk-in itself is PlayState's, in
// onStartCountdown.
//
// DRAW ORDER. In a stage script a bare `add()` is the *PlayState's* draw list
// (see virtual.hx's note on mmGetVirtuaBg), and the source's `camEst` is a
// camera of its own above the world and below the HUD.
// This port gives the Oh God No layers one such camera (mmOgnCamera) and builds
// them in the source's own camEst order - degrad, introbg, introM, introL,
// bbar1/bbar2, blackBarThingie, luigiCut, startbf - because that is what decides
// what is in front of what: the curtain is added after the cutscene art (so the
// stage loads on black and the cutscene is revealed when it lifts) but before
// `luigiCut` (so the 1220 cut plays *over* the blackened screen) and `startbf`
// (so the hatestartM flash is visible on that black).
//
// Everything the source gives `cameras = [camEst]` is skipped by the stage
// extractor (`port_stages.py` only lifts sprites that draw on the default
// camera), so those are rebuilt here on a camera of its own - the same shape
// allfinal.hx uses for `mmEst` and the upstream port uses for its `extra`
// HudCamera. The four fireball entries the extractor *did* emit are dead: their
// constructor x is `FlxG.random.float(...)`, which the ctor parser cannot fold,
// so it shifted the argument list (they came out at x = -1200, y = 1.5, no
// scrolly - i.e. visible at the top of the screen, and during I Hate You too).
// They are created here instead, with the source's own random ranges.
function mmOgnLog(msg:String) trace("[MM hatebg] " + msg);

function mmOgnSong():Bool {
	if (PlayState.SONG == null || PlayState.SONG.meta == null) return false;
	var name = PlayState.SONG.meta.displayName;
	if (name == null) return false;
	return StringTools.startsWith(StringTools.trim("" + name), "Oh God No");
}

// 'I Hate You Old' - the only song of the three on this stage that sends the
// fast half of 'Triggers I Hate You' 0 (11383-11392).
function mmIhyOld():Bool {
	if (PlayState.SONG == null || PlayState.SONG.meta == null) return false;
	var name = PlayState.SONG.meta.displayName;
	return name != null && StringTools.trim("" + name) == "I Hate You Old";
}

// The source's `camEst` - the overlay camera the cutscene, the fire overlay,
// the degrad layer, the cinema bars and luigiCut all draw on.
var mmOgnCam:FlxCamera = null;
var mmEstPlaced:Bool = false;
var mmEstWarned:Bool = false;

function mmCamList() {
	return Reflect.field(FlxG.cameras, "list");
}

function mmOgnCamera():FlxCamera {
	if (mmOgnCam == null) {
		mmOgnCam = new FlxCamera(0, 0, FlxG.width, FlxG.height);
		mmOgnCam.bgColor = FlxColor.TRANSPARENT;
		mmOgnCam.zoom = 1;
		FlxG.cameras.add(mmOgnCam, false); // defaultDraw=false -> world not redrawn
		mmEstBelowHud();
	}
	return mmOgnCam;
}

// Psych builds camEst right after camGame (FlxCamera 826-828), so it composites
// between the world's canvas and camHUD's. `FlxG.cameras.add` appends, which
// would put this layer *above* camHUD - over the notes and the HUD, and over the
// cinema bars the cutscene puts at the screen's own edges - so it is slid back
// into camHUD's own index here (the fleet-wide convention: piracy, forest,
// nesbeat, meatworld, exeport all place their camEst the same way).
// (The list is only half of a camera's place: its own flashSprite in the
// display list is the surface that composites, and `add` leaves a fresh one on
// top of camHUD - which is what `mmSyncCameraOrder` below re-asserts.)
function mmEstBelowHud() {
	if (mmOgnCam == null || mmEstPlaced) return;
	var list = mmCamList();
	if (list == null) {
		if (!mmEstWarned) {
			mmEstWarned = true;
			trace("[MM hatebg] camEst: no FlxG.cameras.list - the overlays stay above camHUD");
		}
		return;
	}
	list.remove(mmOgnCam); // no-op when it is not in the list yet
	var at:Int = (camHUD != null) ? list.indexOf(camHUD) : -1;
	if (at < 0) {
		list.push(mmOgnCam); // no camHUD yet: stay on top
		return;
	}
	list.insert(at, mmOgnCam);
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

// A screen-locked overlay on that camera. `scrollFactor.set()` + a camera that
// never scrolls is Psych's camEst placement.
function mmOgnOverlay(spr) {
	spr.scrollFactor.set(0, 0);
	spr.cameras = [mmOgnCamera()];
	add(spr);
	return spr;
}

// Codename's `Stage` is not a group (`class Stage extends FlxBasic`), so
// `stage.add`/`stage.members` do not exist and HScript resolves them to null -
// calling them throws Null Function Pointer and aborts the rest of the handler.
// `Stage.addSprite` instead puts every stage sprite straight into the *state's*
// draw list and `Stage.applyCharStuff` inserts each character at its marker, so
// a bare `members`/`add`/`insert` here is the state's list and the world layer is
// the run of sprites below the character band.
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

// The source writes the two character *groups* for Oh God No (`boyfriendGroup.x
// = 0` / `dadGroup.x = 770`, 1550-1551); a ported character has no group, so the
// group coordinate is written back onto the sprite - the derivation exeport.hx
// documents: `Character` folds `globalOffset` into its render position
// (`offset.x = globalOffset.x * (isPlayer != playerOffsets ? 1 : -1)`), so the
// stored x is `group + (k + 1) * globalOffset.x` with k = isPlayer !=
// playerOffsets ? 1 : -1. For the two ordinary fighters here the term is zero,
// but the helper keeps the write correct for any offset pair.
function mmOgnSideK(c):Float {
	if (c == null) return 1;
	return (c.isPlayer != c.playerOffsets) ? 1 : -1;
}

function mmOgnGroupX(c):Float {
	if (c == null) return 0;
	return c.x - (mmOgnSideK(c) + 1) * c.globalOffset.x;
}

function mmOgnGroupXTo(c, gx:Float):Float {
	if (c == null) return gx;
	return gx + (mmOgnSideK(c) + 1) * c.globalOffset.x;
}

// 1588-1612. All four fireballs are the same sheet at different scroll factors,
// sizes and frame rates. fire3/fire4 are `add()`ed during create (1607/1611),
// i.e. before `add(boyfriendGroup)` (4331), so they draw behind the fighters;
// fire1/fire2 are held back and `add()`ed at 4357-4359, *after* it, so they
// draw in front of them - which is what the 5 case's falling fire is supposed
// to look like. The stage group is this port's world layer, so that is the
// split here: fire3/fire4 into the stage, fire1/fire2 onto the state.
var mmOgnFires = [null, null, null, null];
function mmOgnFire(i:Int):FlxSprite {
	if (i < 1 || i > 4) return null;
	if (mmOgnFires[i - 1] != null) return mmOgnFires[i - 1];

	// index -> [x range, scroll factor, fps]
	var xmin:Float = (i == 1 || i == 3) ? -900 : 230;
	var xmax:Float = (i == 1 || i == 3) ? 230 : 1360;
	var scroll:Float = [1.5, 1.5, 0.6, 0.5][i - 1];
	var fps:Int = [21, 26, 24, 25][i - 1];

	var f = new FlxSprite(FlxG.random.float(xmin, xmax), -1200);
	f.frames = Paths.getSparrowAtlas("mario/IHY/OGN_Fireball");
	f.animation.addByPrefix("idle", "flame", fps, true);
	if (i >= 3) f.setGraphicSize(Std.int(f.width * 0.5));
	f.updateHitbox();
	f.scrollFactor.set(scroll, scroll);
	f.animation.play("idle");
	if (i <= 2) add(f);   // in front of the fighters
	else mmWorldAdd(f);   // behind them (top of the world layer)
	mmOgnFires[i - 1] = f;
	return f;
}

// 1616-1621: `mario/IHY/asset_deg`, screen-centred on camEst, drawn x4. The
// source's `new BGSprite(...)` has no anim list there, i.e. it is a plain image
// (there is no asset_deg.xml), so this loads it as one - and in the source's
// order: centre first, *then* scale, which leaves the x4 plate hanging off the
// bottom-right of the screen centre rather than centred itself.
var mmOgnDegradSpr:FlxSprite = null;
function mmOgnDegrad():FlxSprite {
	if (mmOgnDegradSpr == null) {
		mmOgnDegradSpr = new FlxSprite(260, 280);
		mmOgnDegradSpr.loadGraphic(Paths.image("mario/IHY/asset_deg"));
		mmOgnDegradSpr.screenCenter();
		mmOgnDegradSpr.setGraphicSize(Std.int(mmOgnDegradSpr.width * 4));
		mmOgnDegradSpr.updateHitbox();
		mmOgnOverlay(mmOgnDegradSpr);
	}
	return mmOgnDegradSpr;
}

// 1716-1719: a screen-sized black overlay, used by the 0 and 2 cuts. The
// source adds it bare (not to camEst) at a point *before* `add(boyfriendGroup)`,
// so it blacks out the stage but leaves the fighters - who are the silhouettes
// by then - on top. In the state's draw list that is the top of the world layer
// (mmWorldAdd), not the bare `add` the rest of this file uses.
var mmOgnBlackSpr:FlxSprite = null;
function mmOgnBlack():FlxSprite {
	if (mmOgnBlackSpr == null) {
		mmOgnBlackSpr = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		mmOgnBlackSpr.setGraphicSize(Std.int(mmOgnBlackSpr.width * 10));
		mmOgnBlackSpr.scrollFactor.set();
		mmOgnBlackSpr.alpha = 0;
		mmWorldAdd(mmOgnBlackSpr);
	}
	return mmOgnBlackSpr;
}

// 5039-5046: the hatestart plate, x3, screen-centred on camEst, invisible until
// the countdown flashes it. The source picks the image with `cosomario`, which
// is 'M' for Oh God No and empty for I Hate You / I Hate You Old - the only
// per-song difference there is.
var mmHateStartBf:FlxSprite = null;
function mmHateStartbf():FlxSprite {
	if (mmHateStartBf == null) {
		mmHateStartBf = new FlxSprite().loadGraphic(Paths.image(mmOgnSong() ? "modstuff/hatestartM" : "modstuff/hatestart"));
		mmHateStartBf.setGraphicSize(Std.int(mmHateStartBf.width * 3));
		mmHateStartBf.updateHitbox();
		mmHateStartBf.screenCenter();
		mmOgnOverlay(mmHateStartBf);
		mmHateStartBf.alpha = 0;
	}
	return mmHateStartBf;
}

// 5150-5158: the two cinema bars, one screen off each side of camEst.
var mmOgnBarL:FlxSprite = null;
var mmOgnBarR:FlxSprite = null;
function mmOgnBars() {
	if (mmOgnBarL != null) return;
	mmOgnBarL = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
	mmOgnBarL.x = 1152;
	mmOgnOverlay(mmOgnBarL);
	mmOgnBarR = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
	mmOgnBarR.x = -1152;
	mmOgnOverlay(mmOgnBarR);
}

// 5162-5167: the Luigi cutscene. `anim` is the fall-in, `end` the blood sprite
// the 1380 stepHit plays.
var mmOgnLuigi:FlxSprite = null;
function mmOgnLuigiCut():FlxSprite {
	if (mmOgnLuigi == null) {
		mmOgnLuigi = new FlxSprite(300, 0);
		mmOgnLuigi.frames = Paths.getSparrowAtlas("mario/IHY/cutscene/OGN_Cutscene");
		mmOgnLuigi.animation.addByPrefix("anim", "LuigiAnim", 24, false);
		mmOgnLuigi.animation.addByPrefix("end", "blood", 5, false);
		mmOgnOverlay(mmOgnLuigi);
		mmOgnLuigi.alpha = 0.0000001;
	}
	return mmOgnLuigi;
}

// ---------------------------------------------------------------------------
// The black curtain, and the opening cutscene.
// ---------------------------------------------------------------------------
// 5035-5039 `blackBarThingie`: a full-screen black on camEst, created with
// alpha 1, so the whole stage loads on a black screen. The countdown branch
// below lifts it at 1.8s (6384-6417, the `else if (curStage == 'hatebg' ||
// curStage == 'forest')` half - which is why *both* songs open this way, not
// just Oh God No), the 3 case raises it again (124.6s) for the Luigi cut, the
// 6 case drops it (130.9s), `stepHit` 1380 raises it for the blood frame, and
// I Hate You's trigger 11 raises it at 135.7s - the song ends on it.
//
// It lives on the cutscene camera (mmOgnCamera), which is the port's camEst:
// above the world and the fighters, below nothing. That is what makes it a real
// cut - the fighters and the stage go with it - at the cost of the HUD, which
// in the source sits on a camera *above* camEst and so shows through; I Hate
// You's first note is at 11.4s and its HUD is faded in at 1.4s, so nothing of
// the song is missed in practice.
//
// (An earlier revision of this file gave I Hate You a world-level black bar at
// alpha 0 instead, which is why its trigger 4 fade-out was a no-op and the
// opening black was never shown.)
var mmHateCurtain:FlxSprite = null;
function mmHateCurtainSpr():FlxSprite {
	if (mmHateCurtain == null) {
		mmHateCurtain = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		mmHateCurtain.setGraphicSize(Std.int(mmHateCurtain.width * 10));
		mmHateCurtain.alpha = 1;
		mmOgnOverlay(mmHateCurtain);
	}
	return mmHateCurtain;
}

// The 0.8s/1.8s half of that countdown branch (6399-6417), shared by both songs:
// the hatestart plate flashes with the 'smw_coin' sound one crochet in, and a
// second later it goes and the curtain lifts over a second. The source starts
// these timers when the countdown starts, so this is called from
// onStartCountdown - for I Hate You without holding anything (its `else` branch
// just sets `startedCountdown = true`), for Oh God No as part of the cutscene
// hold below.
var mmHateIntroTimersDone:Bool = false;
function mmHateIntroTimers() {
	if (mmHateIntroTimersDone) return;
	mmHateIntroTimersDone = true;

	new FlxTimer().start(0.8, function(tmr) {
		mmHateStartbf().alpha = 1;
		FlxG.sound.play(Paths.sound("smw_coin"));
	});

	new FlxTimer().start(1.8, function(tmr) {
		mmHateStartbf().alpha = 0;
		FlxTween.tween(mmHateCurtainSpr(), {alpha: 0}, 1, {ease: FlxEase.quadOut});
	});
}

// ---------------------------------------------------------------------------
// I Hate You's cape BF (`capenose`)
// ---------------------------------------------------------------------------
// 4333-4337: the source builds a second BF - the caped one, `capenose` - in its
// create switch, for the modern song only (`!= 'I Hate You Old' && != 'Oh God
// No'`), right before `add(boyfriendGroup)`, so it draws behind the fighters.
// It is the same 'characters/MM_IHY_Boyfriend_AssetsFINAL' sheet forest's
// `capenose` uses, so it is built here rather than standing in hatebg.xml (the
// old note in this file that called the art unextracted was wrong). Its
// animation follows BF from five places in the source - the update() idle
// restore (7612), a miss (15201), a miss-press (15383/15389), a hit (15420) and
// BF's dance branch of beatHit (16275) - and the trigger group drives its
// visibility: case 5 hides it before BF's prejump, case 6 reveals it 0.19s into
// dad's fall at BF's own x + 260 (11418, 11436-11442, 7823-7824).
var mmIhyCape = null;
var mmIhyCapeLast = "";

function mmIhyCapeActive():Bool {
	return !mmOgnSong() && !mmIhyOld();
}

function mmIhyCapenose():FlxSprite {
	if (mmIhyCape == null) {
		mmIhyCape = new FlxSprite(1130, 520);
		mmIhyCape.frames = Paths.getSparrowAtlas("characters/MM_IHY_Boyfriend_AssetsFINAL");
		mmIhyCape.animation.addByPrefix("idle", "Capejajacomoelcharter", 24, true);
		mmIhyCape.animation.addByPrefix("miss", "CapeFail", 24, false);
		mmIhyCape.animation.play("idle");
		mmIhyCapeLast = "idle";
		mmWorldAdd(mmIhyCape); // 4332: added just before `add(boyfriendGroup)`
	}
	return mmIhyCape;
}

// The source's `animation.play(name)` is not forced, but a finished anim still
// restarts on the next call, so every entry point plays through here - and the
// last name is remembered so the per-frame idle below does not restart the
// loop every tick.
function mmIhyCapePlay(name:String) {
	if (mmIhyCape == null) return;
	mmIhyCapeLast = name;
	mmIhyCape.playAnim(name, true);
}

function mmBfAnimName():String {
	if (boyfriend == null || boyfriend.animation == null) return null;
	if (Reflect.field(boyfriend.animation, "curAnim") == null) return null;
	var ca = boyfriend.animation.curAnim;
	return (ca == null) ? null : Reflect.field(ca, "name");
}

// 7612: while BF is not in a miss pose the cape rides his idle, every frame.
function postUpdate(elapsed:Float) {
	if (!mmIhyCapeActive() || mmIhyCape == null) return;
	var nm:String = mmBfAnimName();
	if (nm == null || nm.indexOf("miss") < 0) {
		if (mmIhyCapeLast != "idle") mmIhyCapePlay("idle");
	}
}

// 15201 (noteMiss) and 15383/15389 (missPress): both flinch it.
function onPlayerMiss(event) {
	if (mmIhyCapeActive() && mmIhyCape != null) mmIhyCapePlay("miss");
}

// 15420: a good hit puts it back on idle.
function onNoteHit(event) {
	if (event.player && mmIhyCapeActive() && mmIhyCape != null && mmIhyCapeLast != "idle") mmIhyCapePlay("idle");
}

// 5099-5148 the cutscene art (minus `introLText`, which the source never shows)
// and 6384-6415, the Oh God No half of the countdown branch - the shared
// 0.8s/1.8s timers above, plus the scene itself, which runs behind the black
// screen and is only revealed as the curtain lifts:
//
//   2s    Mario walks in 0 -> 400 in 1.5s, then holds 'stand'.
//   4.3s  he looks up and Luigi walks in 1200 -> 800 in 1.5s.
//   5.8s  Luigi stops ('stand') and Mario turns his head ('huh').
//   4s    `startedCountdown = true`, i.e. the song is released. It starts five
//         crochets later in the source; here it is the engine's own lead-in,
//         which is one crochet shorter (the same 0.42s the Paranoia intro in
//         songs/MMcamera.hx documents) - so the music starts 0.12s before the
//         cutscene's last pose lands.
//
// The lua fades all six cutscene layers out again on its own step 24 (see
// stepHit below) and the source's PlayState is what leaves them up until then -
// so the port does not need a fade of its own. It used to fade the three it
// built as soon as the walk-in finished, which was both invented and early
// enough to cut the dialogue sequence below short. The reference port this
// project checked against destroys them right after its intro instead
// ('Oh God No'/scripts/OGN.hx case 28).
var mmOgnIntroBg:FlxSprite = null;
var mmOgnIntroM:FlxSprite = null;
var mmOgnIntroL:FlxSprite = null;
var mmOgnIntroLText:FlxSprite = null;
// Guards the Oh God No countdown hold below: onStartCountdown cancels the
// engine's countdown and runs the cutscene in its place. I Hate You returns
// before ever setting this (its `else` branch just releases the song), so the
// flag only ever covers the cutscene.
var mmOgnIntroHeld:Bool = false;

function mmOgnIntro():FlxSprite {
	if (mmOgnIntroBg != null) return mmOgnIntroBg;

	// 5100-5109: the street plate. The source centres it and then pins y to 180,
	// both *before* the x4 scale, which is what this order reproduces.
	mmOgnIntroBg = new FlxSprite(0, 180);
	mmOgnIntroBg.frames = Paths.getSparrowAtlas("mario/IHY/cutscene/ihy_intro_bg");
	mmOgnIntroBg.screenCenter();
	mmOgnIntroBg.y = 180;
	mmOgnIntroBg.animation.addByPrefix("idle", "ihy intro bg stage no way", 5, true);
	mmOgnIntroBg.animation.play("idle");
	mmOgnIntroBg.setGraphicSize(Std.int(mmOgnIntroBg.width * 4));
	mmOgnOverlay(mmOgnIntroBg);

	// 5111-5123: Mario, from x=0, y=475. Only walk -> stand -> look -> huh is
	// ever played.
	mmOgnIntroM = new FlxSprite(0, 475);
	mmOgnIntroM.frames = Paths.getSparrowAtlas("mario/IHY/cutscene/mario_intro_ihy");
	mmOgnIntroM.animation.addByPrefix("walk", "mario intro ihy walk", 12, true);
	mmOgnIntroM.animation.addByIndices("stand", "mario intro ihy walk", [2], "", 12, false);
	mmOgnIntroM.animation.addByPrefix("look", "mario intro ihy looking up", 12, false);
	mmOgnIntroM.animation.addByPrefix("huh", "mario intro ihy huh", 12, false);
	// Only the lua plays these three (steps 15/21/24).
	mmOgnIntroM.animation.addByPrefix("shock", "mario intro ihy shocked", 12, false);
	mmOgnIntroM.animation.addByPrefix("scared", "mario intro ihy scared", 12, false);
	mmOgnIntroM.animation.addByPrefix("idle", "mario intro ihy transition", 12, false);
	mmOgnIntroM.animation.play("walk");
	mmOgnIntroM.setGraphicSize(Std.int(mmOgnIntroM.width * 4));
	mmOgnOverlay(mmOgnIntroM);

	// 5125-5135: Luigi, from x=1200, y=470. PlayState plays walk and stand; the
	// lua's dialogue steps drive the other three.
	mmOgnIntroL = new FlxSprite(1200, 470);
	mmOgnIntroL.frames = Paths.getSparrowAtlas("mario/IHY/cutscene/ihy_luigi_intro");
	mmOgnIntroL.animation.addByPrefix("walk", "ihy luigi intro walk", 12, true);
	mmOgnIntroL.animation.addByPrefix("stand", "ihy luigi intro stand", 12, false);
	// Only the lua plays these three (steps 15/21/24).
	mmOgnIntroL.animation.addByPrefix("worked", "ihy luigi intro worked", 12, false);
	mmOgnIntroL.animation.addByPrefix("alone", "ihy luigi intro alone", 12, false);
	mmOgnIntroL.animation.addByPrefix("transition", "ihy luigi intro transition", 12, false);
	mmOgnIntroL.animation.play("walk");
	mmOgnIntroL.setGraphicSize(Std.int(mmOgnIntroL.width * 4));
	mmOgnOverlay(mmOgnIntroL);

	// 5136-5148: the dialogue plate, added after Luigi so it draws over him. The
	// source creates it playing '4' (its last line) and *invisible*; the lua is
	// what un-hides it and walks the frames 0 -> 4.
	mmOgnIntroText();

	return mmOgnIntroBg;
}

// 5136-5148: `introLText` - the five sprite "YOU / THOUGHT / KOOPA / WORKED /
// ALONE" lines of the dialogue. Same shape as the two characters above: the
// source's own constructor, on the cutscene camera, invisible, playing its last
// frame. The lua's step sequence (see stepHit) is what shows it and walks it.
function mmOgnIntroText():FlxSprite {
	if (mmOgnIntroLText != null) return mmOgnIntroLText;

	mmOgnIntroLText = new FlxSprite(600, 400);
	mmOgnIntroLText.frames = Paths.getSparrowAtlas("mario/IHY/cutscene/ihy_intro_text");
	mmOgnIntroLText.animation.addByPrefix("0", "ihy intro text you", 12, true);
	mmOgnIntroLText.animation.addByPrefix("1", "ihy intro text thought", 12, false);
	mmOgnIntroLText.animation.addByPrefix("2", "ihy intro text koopa", 12, false);
	mmOgnIntroLText.animation.addByPrefix("3", "ihy intro text worked", 12, false);
	mmOgnIntroLText.animation.addByPrefix("4", "ihy intro text alone", 12, false);
	mmOgnIntroLText.animation.play("4");
	mmOgnIntroLText.setGraphicSize(Std.int(mmOgnIntroLText.width * 4));
	mmOgnIntroLText.visible = false;
	mmOgnOverlay(mmOgnIntroLText);
	return mmOgnIntroLText;
}

// `noCount = true` at the top of `case 'hatebg'` (PlayState.hx:1533): the
// source never builds its 3-2-1-GO sprites for this stage, so the engine's
// READY/SET/GO are dropped here. (In Codename `onCountdown` is the per-tick
// event that builds them - cancelling it does not stop the countdown itself,
// which is the same thing songs/MMcamera.hx does for Paranoia's `noCount`.)
function onCountdown(event) {
	event.cancelled = true;
}

// The Oh God No half of the source's startCountdown() branch (6384-6415): hold
// the countdown, play the scene, then let the engine start the song for real
// four seconds later. `event.cancelled` swallows the first startCountdown()
// exactly the way songs/MMcamera.hx holds Paranoia's. I Hate You takes the
// branch's `else` - it holds nothing, and only shares the opening timers, which
// postCreate has already started by the time this runs.
//
// That split is deliberate: in Codename `startCountdown()` runs at the end of
// the state's create(), the same frame postCreate does, so scheduling the
// opening from postCreate is the same instant - and it means a stage script that
// never received this event would still lift its curtain instead of sitting on
// a black screen for the whole song. What is left here (the cancel and the
// hold) degrades to "the song just starts normally".
function onStartCountdown(event) {
	if (!mmOgnSong() || mmOgnIntroHeld) return;
	mmOgnIntroHeld = true;
	event.cancelled = true;

	// postCreate normally built this already; every builder is idempotent, so
	// this only matters if the countdown is asked for before it ran.
	mmOgnBuild();

	new FlxTimer().start(2, function(tmr) {
		FlxTween.tween(mmOgnIntroM, {x: 400}, 1.5, {onComplete: function(twn) {
			mmOgnIntroM.animation.play("stand");
			new FlxTimer().start(0.8, function(tmr2) {
				mmOgnIntroM.animation.play("look");
				FlxTween.tween(mmOgnIntroL, {x: 800}, 1.5, {onComplete: function(twn2) {
					mmOgnIntroM.animation.play("huh");
					mmOgnIntroL.animation.play("stand");
				}});
			});
		}});
	});

	new FlxTimer().start(4, function(tmr) {
		if (PlayState.instance != null) PlayState.instance.startCountdown();
	});
}

// 4585-4589: `boyfriend.shader = new SilhouetteShader(255, 0, 59)` and
// `dad.shader = new SilhouetteShader(20, 180, 0)`. `amount` is the ramp the
// source's transitionOGN() drives; a missing sprite-shader field (or the
// engine's shader option being off) leaves both null and mmOgnTransition a
// no-op, which is the pre-transition look rather than a crash.
var mmSilBf = null;
var mmSilDad = null;
var mmOgnShade:Float = 0.0;   // source's `shaderOGN`

function mmOgnShadersAllowed():Bool {
	if (Options == null) return true;
	if (!Reflect.hasField(Options, "gameplayShaders")) return true;
	return Options.gameplayShaders;
}

function mmOgnSilhouettes() {
	if (mmSilBf != null || mmSilDad != null) return;
	if (!mmOgnShadersAllowed()) { mmOgnLog("OGN: gameplay shaders off, silhouette skipped"); return; }

	mmSilBf = new CustomShader("silhouette");
	mmSilBf.data.col.value = [255 / 255, 0 / 255, 59 / 255];
	mmSilBf.data.amount.value = [0];

	mmSilDad = new CustomShader("silhouette");
	mmSilDad.data.col.value = [20 / 255, 180 / 255, 0 / 255];
	mmSilDad.data.amount.value = [0];

	if (!mmOgnAttachShader(boyfriend, mmSilBf)) mmSilBf = null;
	if (!mmOgnAttachShader(dad, mmSilDad)) mmSilDad = null;
}

function mmOgnAttachShader(char, sh):Bool {
	if (char == null || sh == null) return false;
	if (Reflect.field(char, "shader") == null) {
		mmOgnLog("OGN: this build has no sprite shader field, silhouette skipped");
		return false;
	}
	char.shader = sh;
	return true;
}

// The source's `amount.value[0] += amount1` plus its `while (value > 1) value -= 1`
// wrap. In practice the ramp stops at 0.95 / 0.05 so the wrap never fires, but
// it is the source's own guard against a stray extra step.
function mmOgnSetShade(v:Float) {
	while (v > 1) v -= 1;
	mmOgnShade = v;
	if (mmSilBf != null) mmSilBf.data.amount.value = [v];
	if (mmSilDad != null) mmSilDad.data.amount.value = [v];
}

// PlayState.hx:5949-5994 `transitionOGN()`. Steps `shaderOGN` by 0.05 every
// 0.05s until it reaches 0.95 (in) or 0.05 (out). `imgonnakillsomeone` does NOT
// recurse: it only schedules one extra 1.05s-delayed step of 0.04999, which is
// what carries the ramp the last sliver off the 0.05 grid and makes the 0 and 2
// transitions (triggered on the beat) land exactly on full/zero.
//
// The step in the source's update() is commented out (PlayState.hx:7634-7635),
// so these timers are the ramp's only driver.
function mmOgnTransition(inOut:Bool, kill:Bool) {
	if (mmSilBf == null && mmSilDad == null) return;
	var step:Float = inOut ? 0.05 : -0.05;
	mmOgnSetShade(mmOgnShade + step);

	if (kill) {
		new FlxTimer().start(1.05, function(tmr) {
			mmOgnSetShade(mmOgnShade + (inOut ? 0.04999 : -0.04999));
		});
	}

	if (inOut ? mmOgnShade < 0.95 : mmOgnShade > 0.05) {
		new FlxTimer().start(0.05, function(tmr) {
			mmOgnTransition(inOut, false);
		});
	}
}

// The 'Triggers Oh God No' beats that own tweens the 2 case cancels - the
// source's `extraTween` list. (Its other members are MMcamera's zoom ramp.)
var mmOgnTweens = [];
function mmOgnCancelTweens() {
	for (t in mmOgnTweens) t.cancel();
	mmOgnTweens = [];
}

// 11296-11376. The camera half of 0 and 2 (ZOOMCHARS, the BF/DAD boxes and the
// 0.45 -> 0.8 -> 0.7 zoom ramps) is MMcamera's mmOgnCamera(); everything that
// is a sprite lives here.
function mmOgnTrigger(trigger:Int) {
	switch (trigger) {
		case 0:
			mmOgnTransition(true, true);
			mmOgnTweens.push(FlxTween.tween(mmOgnFire(1), {alpha: 0}, 1, {ease: FlxEase.quadInOut}));
			mmOgnTweens.push(FlxTween.tween(mmOgnFire(2), {alpha: 0}, 1, {ease: FlxEase.quadInOut}));
			mmOgnTweens.push(FlxTween.tween(mmOgnCamera(), {alpha: 0}, 1, {ease: FlxEase.quadInOut}));
			mmOgnTweens.push(FlxTween.tween(mmOgnBlack(), {alpha: 1}, 1, {ease: FlxEase.quadInOut}));

		case 1:
			mmOgnTweens.push(FlxTween.tween(gf, {alpha: 0.3}, 11));

		case 2:
			mmOgnCancelTweens();
			mmOgnDegrad().alpha = 1;
			mmOgnTweens.push(FlxTween.tween(mmOgnFire(1), {alpha: 1}, 1, {ease: FlxEase.quadInOut}));
			mmOgnTweens.push(FlxTween.tween(mmOgnFire(2), {alpha: 1}, 1, {ease: FlxEase.quadInOut}));
			mmOgnTweens.push(FlxTween.tween(mmOgnDegrad(), {alpha: 0.6}, 0.5, {ease: FlxEase.quadInOut, type: FlxTween.PINGPONG}));
			mmOgnTweens.push(FlxTween.tween(gf, {alpha: 0}, 1, {ease: FlxEase.quadInOut}));
			mmOgnTweens.push(FlxTween.tween(mmOgnCamera(), {alpha: 1}, 1, {ease: FlxEase.quadInOut}));
			mmOgnTweens.push(FlxTween.tween(mmOgnBlack(), {alpha: 0}, 1, {ease: FlxEase.quadInOut}));

		case 3:
			mmOgnTweens.push(FlxTween.tween(mmHateCurtainSpr(), {alpha: 1}, 1));

		case 4:
			camGame.alpha = 0;
			var cut = mmOgnLuigiCut();
			cut.y += 200;
			mmOgnTweens.push(FlxTween.tween(cut, {y: cut.y - 200, alpha: 1}, 1.5, {ease: FlxEase.cubeOut}));
			cut.animation.play("anim");

		case 5:
			// The four fireballs start falling, on the source's own delays.
			mmOgnFireFall(1, 5, 5, -900, 230);
			mmOgnFireFall(2, 5, 7, 230, 1360);
			mmOgnFireFall(3, 4, 8, -900, 230);
			mmOgnFireFall(4, 4, 1, 230, 1360);

		case 6:
			camGame.alpha = 1;
			mmHateCurtainSpr().alpha = 0;
			mmOgnLuigiCut().alpha = 0;
			FlxG.camera.flash(FlxColor.WHITE, 0.5);
	}
}

// The LOOPING fall of one fireball (source: `FlxTween.tween(fire1, {y: 1000},
// 5, {startDelay: 5, type: LOOPING, onComplete: fire1.x = random})`).
function mmOgnFireFall(i:Int, dur:Float, delay:Float, xmin:Float, xmax:Float) {
	var f = mmOgnFire(i);
	if (f == null) return;
	FlxTween.tween(f, {y: 1000}, dur, {startDelay: delay, type: FlxTween.LOOPING, onComplete: function(twn) {
		f.x = FlxG.random.float(xmin, xmax);
	}});
}

// The Oh God No build: every layer the source creates at load, in its own draw
// order (the camEst members first, then the world ones), plus the fighters'
// shaders. Both songs get the curtain, just not the rest of it.
function mmOgnBuild() {
	mmOgnDegrad();
	mmOgnIntro();
	mmOgnBars();
	mmHateCurtainSpr();
	mmOgnLuigiCut();
	mmHateStartbf();
	mmOgnFire(3);
	mmOgnFire(4);
	mmOgnBlack();
	mmOgnFire(1);
	mmOgnFire(2);
	mmOgnSilhouettes();
}

function postCreate() {
	// 1691-1697: the stage's bridge exists in two variants ('PuenteCompleto' for
	// Oh God No, 'Puente Roto' for the regular song) at the same spot, and the
	// extractor emitted both - so exactly one has to be picked. I Hate You is the
	// regular song here, so that is the default; Oh God No swaps in the complete
	// one.
	if (puenteHate != null) puenteHate.visible = false;
	if (mmOgnSong()) {
		if (puenteHate_2 != null) puenteHate_2.visible = false;
		if (puenteHate != null) puenteHate.visible = true;
	}

	// `noHUD = true` (1534) for the whole stage: camHUD starts at alpha 0 and the
	// songs' own 'Ocultar HUD' 2 (I Hate You at 0, Oh God No at 2.73s) fades it
	// back in. The curtain hides all of it in the meantime either way.
	if (camHUD != null) camHUD.alpha = 0;

	if (mmOgnSong()) mmOgnBuild();
	else mmHateCurtainSpr(); // I Hate You / I Hate You Old: the opening black

	// The 0.8s flash and the 1.8s curtain lift, for both songs (see
	// mmHateIntroTimers).
	mmHateIntroTimers();

	if (mmOgnSong()) {
		// 1538-1556: the real GF is only a sliver for this song (she is off camera
		// until the 1 case brings her back at alpha 0.3).
		if (gf != null) gf.alpha = 0.000001;

		// 1550-1551: the song fights on swapped sides. The source moves the two
		// character groups (`boyfriendGroup.x = 0`, `dadGroup.x = 770`), and both
		// its camera boxes (BF 220/350, DAD 620/290 - MMcamera) and the chart's
		// own swapped note fields are built around that: without the move the
		// fighters stand on the wrong side of their own camera.
		if (boyfriend != null) boyfriend.x = mmOgnGroupXTo(boyfriend, 0);
		if (dad != null) dad.x = mmOgnGroupXTo(dad, 770);
		return;
	}

	// 4333-4337: I Hate You's cape BF (the modern song only - the same gate as
	// the source, `!= 'I Hate You Old' && != 'Oh God No'`).
	if (mmIhyCapeActive()) mmIhyCapenose();
}

// 15990-16010: the ending's shakes and the blood cut. The chart's steps, not
// beats - the trigger block of this stage has no stepHit of its own. The head
// of this function is the *other* half: the opening dialogue, which is the
// song's lua, not PlayState (`onStepHit`: 6/10/15/21/24/25). Comments in the
// lua name each line; `introLText` anim '0' loops ('YOU') and the rest are
// one-shots.
function stepHit(curStep:Int) {
	if (!mmOgnSong()) return;

	switch (curStep) {
		case 6:
			var txt = mmOgnIntroText();
			txt.visible = true;
			txt.animation.play("0");
			FlxTween.tween(mmOgnCamera(), {zoom: 1.2}, 2, {ease: FlxEase.cubeOut});
			FlxTween.tween(mmOgnCamera().scroll, {y: 40}, 2, {ease: FlxEase.cubeOut});
		case 10:
			mmOgnIntroText().animation.play("1");
		case 15:
			mmOgnIntroText().animation.play("2");
			if (mmOgnIntroL != null) mmOgnIntroL.animation.play("worked");
			if (mmOgnIntroM != null) mmOgnIntroM.animation.play("shock");
		case 21:
			mmOgnIntroText().animation.play("3");
			if (mmOgnIntroL != null) mmOgnIntroL.animation.play("alone");
			if (mmOgnIntroM != null) mmOgnIntroM.animation.play("scared");
		case 24:
			// The music starts: both characters settle into their transition
			// poses and every cutscene layer fades out over 0.5s.
			if (mmOgnIntroM != null) mmOgnIntroM.animation.play("idle");
			if (mmOgnIntroL != null) mmOgnIntroL.animation.play("transition");
			for (s in [mmOgnIntroBg, mmOgnIntroM, mmOgnIntroL, mmOgnIntroText(), mmOgnBarL, mmOgnBarR])
				if (s != null) FlxTween.tween(s, {alpha: 0}, 0.5);
		case 25:
			mmOgnIntroText().animation.play("4");
			FlxTween.tween(mmOgnCamera(), {zoom: 1.4}, 1, {ease: FlxEase.cubeIn});
			FlxTween.tween(mmOgnCamera().scroll, {y: 80}, 1, {ease: FlxEase.cubeIn});
		// The lua's `onBeatHit`'s only beat - the camera settling back once the
		// dialogue is over (`doTweenZoom("test4","camEst",1,3,'cubeInOut')` +
		// `doTweenY("test5","camEst.scroll",0,3,'cubeInOut')`). It is serviced from
		// here rather than a `beatHit` of its own: this stage's *generated* head
		// already defines one (the drowned Marios' dance), and a second
		// `function beatHit` in the same script would shadow it. Beat 23 is
		// exactly step 92.
		case 92:
			FlxTween.tween(mmOgnCamera(), {zoom: 1}, 3, {ease: FlxEase.cubeInOut});
			FlxTween.tween(mmOgnCamera().scroll, {y: 0}, 3, {ease: FlxEase.cubeInOut});
	}

	if (curStep == 1235) {
		mmOgnCamera().shake(0.01, 0.2);
	} else if (curStep == 1380) {
		var cut = mmOgnLuigiCut();
		cut.animation.play("end");
		cut.alpha = 1;
		cut.x -= 100;
		cut.y += 100;
		mmHateCurtainSpr().alpha = 1;
		camGame.alpha = 0;
		camHUD.alpha = 0;
		mmOgnCamera().shake(0.03, 0.4);
		mmOgnTweens.push(FlxTween.tween(cut, {y: cut.y - 100}, 4, {ease: FlxEase.cubeIn}));
		mmOgnTweens.push(FlxTween.tween(cut.scale, {x: 0.1, y: 0.1}, 4, {ease: FlxEase.cubeIn}));
		mmOgnTweens.push(FlxTween.tween(cut, {alpha: 0}, 1, {startDelay: 2}));
	} else if (curStep >= 1384) {
		mmOgnCamera().shake(0.005, 0.1);
	}
}
// === end MM stage triggers ===
