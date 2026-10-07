// Ported from PlayState.hx beatHit() (case 'exesequel' | 'betamansion' | 'nesbeat'
// and case 'nesbeat').
function beatHit(curBeat:Int) {
	if (curBeat >= 0) mmTurn(mmTurnTarget);
	// 16368-16371: while the dupe section is armed, every beat re-spikes the
	// angel - `angel.pixelSize = 0.5; angel.strength = shit;`. The update hook
	// decays both back between beats, which is what makes it pulse.
	if (mmDupeTimer != 0 && mmAngel != null) {
		mmAngel.data.pixel.value = [0.5, 0.5];
		mmAngel.data.stronk.value = [mmShit, mmShit];
	}
	// starman GF bounces left/right every beat, but a 'hey' animation is
	// allowed to play through before the dance resumes.
	var anim = starmanGF.animation.curAnim;
	if (curBeat % 2 == 0) {
		if (anim == null || anim.name != 'hey' || anim.finished)
			starmanGF.playAnim('danceRight', true);
	} else {
		starmanGF.playAnim('danceLeft', true);
	}

	// Yoshi restarts his idle every other beat, but only while idling.
	if (curBeat % 2 == 0) {
		var yan = funnylayer0.animation.curAnim;
		if (yan != null && yan.name == 'idle') {
			funnylayer0.playAnim('idle');
			funnylayer0.offset.x = 0;
			funnylayer0.offset.y = 0;
		}
	}
}

// === MM stage triggers (auto) ===
// 'Triggers Unbeatable' - ported from PlayState.hx (case 'Triggers Unbeatable',
// a ~750 line stage cutscene). This is a *feasible subset*: it reproduces the
// stage-art choreography (duck / bowser / TV-static cutscenes, clown car,
// fire bar, ycbu lightning & heads, spawned duck / bullet / podoboos) plus the
// character swaps, health changes and camera fades.
//
// Deliberately NOT reproduced (no Codename equivalent or engine-internal):
// titleText/autorText, resyncVocals() and the HUD-only pieces
// (timeBar/timeTxt/scoreTxt/customHB/healthFake, ycbuIconPos*). The 'Play
// Animation' / 'Screen Shake' / 'Add Camera Zoom' cross-event calls are
// inlined. Case 33 is the one case with no branch below: it moves the song-name
// finale icons only (the iconW4 / iconY0 fades and the ycbuIconPos1/2/3 swaps),
// and this port has no sprite for them - the chart sends it eleven times through
// the finale.
//
// The camEst layer the source gives this stage's overlay art - the two lightning
// strips, the two head columns, the crosshair and the static (2616-2696) - is
// built now, and with it the heads' `FlxBackdrop(Y)` columns: see "camEst and
// the ycbu head columns" below. That also gives the TV stack its third filter
// order, camEst's `[vcr, border, angel]` (5664-5666), a camera of its own.
//
// `ClientPrefs.flashing` and `ClientPrefs.filtro85` are not script-readable, so
// this file takes both as on - the choice exeport.hx/wetworld.hx/realbg.hx
// document. The red flashes, the `duckbg` colours and every `angel.strength`
// write of the block (cases 6, 7, 17/2 and 28/0-3) are ported unconditionally,
// behind an `mmAngel != null` guard for the gameplay-shaders option.
//
// The camera flags the block turns on and off - `FOLLOWCHARS`/`ZOOMCHARS` in
// cases 17/0 and 27/0 - go through songs/MMcamera.hx via mmCam() below, because
// MMcamera rewrites camFollow and the zoom every frame while those flags are
// set, so a stage script's own writes would be overwritten before they were
// read. `nomiss` (cases 9/10) is kept as well: it is a 31-second window
// (142.7s-173.6s in the chart) in which the fork turns every player miss into
// `health = 0`, and onPlayerMiss() below is what runs it here.
//
// The firebar is not just the case 21/22 in/out: its create block puts it on
// camHUD at 6x with a 10fps loop, and update() (7258-7276) spins it a quarter
// turn whenever that loop ends and drains `health -= elapsed * 2` through the
// source's five (angle, frame) damage windows. postCreate/postUpdate carry both
// halves.
//
// The draw-order reshuffles *are* ported. Every case where the source pulls a
// sprite out of its slot and re-inserts it relative to another one (4, 6/2,
// 7/1, 16, 17/1, 17/2, 20, 23, 25, 27, 32 - case 19 touches none of them) goes
// through mmReinsert() below, which spells out the splice that the source's
// bare `remove(x); insert(members.indexOf(anchor) + off, x)` pair performs on a
// list with no null holes in it.
//
// The source's TV filter stack (`tvEffect`, and the nesbeat-only beatend/angel
// pair, 5647-5667) *is* ported - see "The TV shader stack" below.
//
// `ycbu text` IS here, because it is not a pure cross-event call: 550 of
// Unbeatable's chart events are it, and it is also what drives the gyromite /
// lakitu / head sprites and the two beat texts the source builds in this stage's
// own create block (2605-2611 `beatText`, 2697-2702 `otherBeatText`, 2704-2760
// the sprites). It lives in mmYcbuText() below and is reached from three places:
// the chart event itself, the source's own re-dispatches (cases 25 and 26), and
// `data/events/ycbu text.hx`, which now delegates here.

var mmBlackFront:FunkinSprite;
var mmDuckBg:FunkinSprite;
var mmScreenColor:FunkinSprite;
var mmYcbuWhite:FunkinSprite;
var mmYcbuCrosshair:FunkinSprite;
var mmFireBar:FunkinSprite;
var mmEstatica:FunkinSprite;
var mmYcbuHeadL:FunkinSprite;
var mmYcbuHeadR:FunkinSprite;
// The two beat texts of the source's create block. `beatText` is added in the
// sprite pass and `otherBeatText` in the *foreground* pass (2611 vs 4385), so
// one renders behind the cast and the other in front of them.
var mmBeatText:FlxText;
var mmOtherBeatText:FlxText;
var mmYcbuTextTimers = [];
var mmTurnTarget = 0;
var mmTurnWasPlayer = false;
var mmNomiss:Bool = false;      // source `nomiss` (586), armed by case 9/10

// The source reassigns its cast fields on a swap; a stage script's globals
// remain snapshots. Resolve every later cast write and draw-order anchor from
// the strumlines, including callbacks and section turns. The fallback is for
// setup before the lines exist (and the no-swap regression mocks).
function mmMem(i:Int) {
	var ps = PlayState.instance;
	if (ps == null || ps.strumLines == null || ps.strumLines.members.length <= i) return null;
	var line = ps.strumLines.members[i];
	return (line != null && line.characters.length > 0) ? line.characters[0] : null;
}
function mmDadChar() { var c = mmMem(0); return (c != null) ? c : dad; }
function mmBfChar() { var c = mmMem(1); return (c != null) ? c : boyfriend; }
function mmGfChar() { var c = mmMem(2); return (c != null) ? c : gf; }

// Source beatHit():16068-16108 toggles the TV cast every beat by section.
// Converted Camera Movement events carry the same mustHitSection information.
function mmTurn(target) {
	if (mmBlackFront == null || mmEstatica == null) return;
	var playerTurn = target == 1;
	mmDadChar().visible = !playerTurn;
	mmBfChar().visible = playerTurn;
	starmanGF.visible = playerTurn;
	mmBlackFront.alpha = playerTurn ? 0.3 : 0;
	if (playerTurn) {
		mmBfChar().alpha = 1;
		starmanGF.alpha = 1;
		if (ycbuGyromite.visible && ycbuLakitu.visible)
			ycbuGyromite.visible = ycbuLakitu.visible = false;
	}
	if (playerTurn != mmTurnWasPlayer) {
		mmEstatica.alpha = 0.6;
		FlxTween.tween(mmEstatica, {alpha: 0.05}, 0.5, {ease: FlxEase.quadInOut});
		mmTurnWasPlayer = playerTurn;
	}
}

// ---------------------------------------------------------------------------
// camEst and the ycbu head columns (2616-2696)
// ---------------------------------------------------------------------------
// The source builds this stage's overlay art on its own camera - `cameras =
// [camEst]` on the two lightning strips (2616/2631), the two heads (2646/2663),
// the crosshair (2664) and the static (2683). Psych's camEst is the layer
// between the world and camHUD, so the port builds that camera: a zoom-1,
// never-scrolled FlxCamera added with `defaultDraw = false` and slid into
// camHUD's slot in `FlxG.cameras.list` - the same mmEst() exeport.hx,
// piracy.hx, demiseport.hx and the rest use. On camGame those six sprites rode
// the chart's 1.4 zoom and the camera's scroll and drew under the crosshair and
// the static; on mmEst they sit still and keep the source's own draw order. The
// TV stack mounts the source's `[vcr, border, angel]` (5664-5666) on it.
//
// Both heads are `new FlxBackdrop(Y)` (2634/2651): the head graphic tiled every
// frame-height and streamed with `velocity`, so each is an endless column rather
// than a single sprite that leaves the screen after a second. FlxBackdrop cannot
// be instantiated from HScript (see demiseport.hx), so each head keeps its
// scripted sprite as the *leader* - every case-28 write (the velocity tweens,
// the x swaps, flipX, the animations) still lands on it - and a row of copies
// repeats it on the lattice the class would draw. The tile step is Flixel's own
// `(frame + spacing) * scale` (flixel-addons `FlxBackdrop.drawComplex`), which
// for this atlas is 0.6 * 601 (the 'Rotat e' frames) and 0.6 * 507/487 for the
// two one-shot poses; a column is one frame-height per turn.
var mmEstCam:FlxCamera = null;
var mmEstPlaced:Bool = false;
var mmEstWarned:Bool = false;
var mmHeadRows = [];
var mmHeadStepBase:Float = 290; // only used if a frame height cannot be read

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
			trace("[MM nesbeat] camEst: no FlxG.cameras.list - the layer stays above camHUD");
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

// One row per head. The copies are sized for a step three quarters of the
// current one, so a later animation with shorter frames cannot open a gap;
// surplus copies overlap exactly and are invisible. Each lands right after its
// leader in the draw list, which keeps the source's order among these sprites.
function mmHeadRow(lead) {
	if (lead == null) return null;
	var step:Float = lead.frameHeight * lead.scale.y;
	if (!(step > 0)) step = mmHeadStepBase;
	var base:Float = step * 0.75;
	var count:Int = Std.int(Math.ceil((FlxG.height + base) / base)) + 2;
	if (count < 4) count = 4;
	var sprs = [];
	var at:Int = members.indexOf(lead);
	for (i in 0...count) {
		var c = new FunkinSprite(lead.x, lead.y);
		c.frames = lead.frames;
		c.animation.addByPrefix('LOL', 'Rotat e', 24, true);
		c.animation.addByPrefix('gyromite', 'Bird Up', 24, false);
		c.animation.addByPrefix('lakitu', 'Lakitu', 24, false);
		c.animation.play('LOL', true);
		c.scale.set(lead.scale.x, lead.scale.y);
		c.antialiasing = lead.antialiasing;
		c.flipX = lead.flipX;
		c.visible = lead.visible;
		c.cameras = [mmEst()];
		if (at >= 0) insert(at + 1, c); else add(c);
		sprs.push(c);
	}
	var g = {lead: lead, sprs: sprs, anim: null, loop: false, cf: 0, tail: sprs[sprs.length - 1]};
	mmHeadRows.push(g);
	return g;
}

// FlxBackdrop derives its vertical tiles from the sprite's own y, so the copies
// are that lattice - `phase + i * step`, wrapped once per turn of the column -
// with `phase` the leader's y taken modulo the turn. The wrap shifts a copy by
// whole tiles, which is invisible: every copy is the same head.
function mmHeadTick() {
	for (g in mmHeadRows) {
		var lead = g.lead;
		if (lead == null || lead.frames == null) continue;
		var step:Float = lead.frameHeight * lead.scale.y;
		if (!(step > 0)) step = mmHeadStepBase;
		var span:Float = step * g.sprs.length;
		var phase:Float = lead.y % span;
		if (phase < 0) phase += span;
		var i:Int = 0;
		for (c in g.sprs) {
			var y:Float = phase + i * step;
			if (y >= span) y -= span;
			c.x = lead.x;
			c.y = y;
			c.flipX = lead.flipX;
			c.visible = lead.visible;
			c.alpha = lead.alpha;
			i += 1;
		}
		mmHeadAnim(g);
	}
}

// A name change replays every copy, and for the looping spin a frame that wrapped
// back to 0 does the same - that is what keeps a cycle-aligned rotation looking
// like one column. The two one-shot poses ('gyromite', 'lakitu') hold their last
// frame like the leader, so they need no replay once started.
function mmHeadAnim(g) {
	var lead = g.lead;
	if (lead == null) return;
	var a = lead.animation.curAnim;
	if (a == null) return;
	var name:String = a.name;
	var cf:Int = lead.animation.frameIndex;
	if (name != g.anim) {
		g.anim = name;
		g.loop = (name == 'LOL');
		g.cf = cf;
		for (c in g.sprs) c.animation.play(name, true);
		return;
	}
	if (g.loop && cf < g.cf) {
		for (c in g.sprs) c.animation.play(name, true);
	}
	g.cf = cf;
}

// ---------------------------------------------------------------------------
// The TV shader stack (5647-5667)
// ---------------------------------------------------------------------------
// `case 'nesbeat'` sets `tvEffect` (2490), and the source's filter block mounts
// VCRMario85 + VCRBorder on camGame and camHUD plus, for this stage only, the
// two extra shaders its own branch creates (5664-5667): YCBUEndingShader and
// AngelShader. The orders are `[vcr, border, beatend, angel]` on camGame (5666),
// `[vcr, border]` on camHUD (5659-5661) and `[vcr, border, angel]` on camEst
// (5664-5666), which is this port's mmEst() - see the camEst section above. The
// four live in shaders/vcr85.frag, shaders/vcrBorder.frag, shaders/ycbuEnding.frag
// and shaders/angel.frag; the stack is mounted from postCreate and driven from
// postUpdate - including `vcr.update(elapsed)`'s own time uniform (7241), which
// this stage used to leave frozen.
//
// * `beatend` is the RGB-split ending glitch. The source's own `update()` for it
//   only runs while `endingnes` (7282-7286), which 'Triggers Unbeatable' 8 sets.
//   Unbeatable's chart never sends trigger 8 (checked across its
//   charts/normal.json), so the port matches the source exactly: the shader is
//   mounted and tears the picture with a *frozen* seed, and only starts ramping
//   if that trigger is ever sent.
// * `angel` is the per-beat RGB tear. 'Triggers Unbeatable' 18 (12643-12646)
//   sets `shit` and `dupeTimer`; every beat with a non-zero `dupeTimer` spikes
//   it (16368-16371), and the update hook decays strength and pixel size back to
//   a no-op (7215-7221, with the non-virtual factor of 4).
var mmVcr = null;            // VCRMario85 -> shaders/vcr85.frag
var mmVcrBorder = null;      // VCRBorder -> shaders/vcrBorder.frag
var mmYcbu = null;           // YCBUEndingShader -> shaders/ycbuEnding.frag
var mmAngel = null;          // AngelShader -> shaders/angel.frag
var mmTvOn:Bool = false;
var mmTvTime:Float = 0;         // 7241: `vcr.update(elapsed)`'s accumulator
var mmEndingNes:Bool = false;   // source `endingnes` (case 8)
var mmYcbuVal:Float = 0;        // source `val` (7283-7284)
var mmShit:Float = 0;           // source `shit` (case 18)
var mmDupeTimer:Int = 0;        // source `dupeTimer` (case 18)

// Same read virtual.hx/promoshow.hx make: with the engine's "Gameplay Shaders"
// option off, `new CustomShader(...)` stays null and its setters no-op.
function mmShadersAllowed():Bool {
	if (Options == null) return true;
	if (!Reflect.hasField(Options, "gameplayShaders")) return true;
	return Options.gameplayShaders;
}

// `addShader` appends, so mounting in the source's order reproduces its filter
// list. The seed starts where the source's does - an arbitrary real-time value -
// so the frozen channel split is not always the same pattern.
function mmTvStack() {
	if (mmTvOn || !mmShadersAllowed()) return;
	mmTvOn = true;

	mmVcr = new CustomShader("vcr85");
	mmVcrBorder = new CustomShader("vcrBorder");
	mmYcbu = new CustomShader("ycbuEnding");
	mmYcbu.data.seed.value = [FlxG.random.float(0, 1000)];
	mmYcbu.data.intensity.value = [0];
	mmAngel = new CustomShader("angel");
	mmAngel.data.stronk.value = [0];
	mmAngel.data.pixel.value = [1, 1];

	if (camGame != null) {
		camGame.addShader(mmVcr);
		camGame.addShader(mmVcrBorder);
		camGame.addShader(mmYcbu);
		camGame.addShader(mmAngel);
	}
	if (camHUD != null) {
		camHUD.addShader(mmVcr);
		camHUD.addShader(mmVcrBorder);
	}
	// 5664-5666: camEst takes [vcr, border, angel] - it has no beatend.
	var est = mmEst();
	if (est != null) {
		est.addShader(mmVcr);
		est.addShader(mmVcrBorder);
		est.addShader(mmAngel);
	}
}

function postUpdate(elapsed:Float) {
	// The camEst layer lands under camHUD once camHUD exists, and the head
	// columns follow their leaders.
	mmEstBelowHud();
	mmHeadTick();
	// 7241: `vcr.update(elapsed)` accumulates the VCR shader's own time uniform -
	// the tape wobble and the scanline hang off it.
	mmTvTime += elapsed;
	if (mmVcr != null) mmVcr.data.time.value = [mmTvTime];

	// 7215-7221: the angel decays back to a no-op every frame. `curStage !=
	// 'virtual'` is true here, so the factor is 4 (virtual uses 8).
	if (mmAngel != null) {
		var s = FlxMath.lerp(mmAngel.data.stronk.value[0], 0, FlxMath.bound(elapsed * 4, 0, 1));
		mmAngel.data.stronk.value = [s, s]; // AngelShader.set_strength writes [v, v]
		var p = FlxMath.lerp(mmAngel.data.pixel.value[0], 1, FlxMath.bound(elapsed * 4, 0, 1));
		mmAngel.data.pixel.value = [p, p];
		mmAngel.data.iTime.value = [Conductor.songPosition / 1000];
	}

	// 7258-7276: the firebar's own update half. It steps 90 degrees each time
	// its 8-frame loop ends (0 > 90 > 180 > 270 > 0) and, while it is on screen,
	// drains 2 health/s whenever the current (angle, frame) pair sits inside one
	// of the source's five damage windows - each window stops at its own health
	// floor. The iconP1 hit-shake is part of the same block.
	if (mmFireBar != null) {
		var fbar = mmFireBar.animation.curAnim;
		if (fbar != null && fbar.finished) {
			mmFireBar.animation.play('loop');
			if (mmFireBar.angle >= 270) mmFireBar.angle = 0;
			else mmFireBar.angle += 90;
		}
		if (mmFireBar.visible) {
			var placeVals:Array<Dynamic> = [[270, 2, 7, 1.9], [0, 0, 2, 1.7], [0, 3, 4, 1.5], [0, 5, 7, 1.0], [90, 0, 3, 1.3]];
			for (row in placeVals) {
				if (mmFireBar.angle == row[0] && mmFireBar.animation.frameIndex >= row[1]
					&& mmFireBar.animation.frameIndex <= row[2] && health > row[3]) {
					health -= elapsed * 2;
					var icp1 = mmGetIcon(false);
					if (icp1 != null) {
						FlxTween.angle(icp1, FlxG.random.float(-20, 20), 0, mmBeat(), {ease: FlxEase.backOut});
						FlxTween.color(icp1, mmBeat(), 0xFF3B3B3B, FlxColor.WHITE, {ease: FlxEase.circOut});
					}
				}
			}
		}
	}

	// 7282-7286: `beatend.update(val, elapsed)` while `endingnes`. The shader's
	// own update adds `elapsed` to seed and `amount` to intensity, bounded 0..1.
	if (mmEndingNes && mmYcbu != null) {
		mmYcbuVal += elapsed;
		mmYcbuVal /= 4;
		mmYcbu.data.seed.value[0] += elapsed;
		var i0 = mmYcbu.data.intensity.value[0] + mmYcbuVal;
		if (i0 > 1) i0 = 1;
		else if (i0 < 0) i0 = 0;
		mmYcbu.data.intensity.value = [i0];
	}
}

// 12527/12532: cases 9 and 10 arm and disarm the fork's `nomiss`: at
// 15176/15337 any miss while it is set does `health = 0` - an instant death,
// not a mercy rule. The chart turns it on at 142.7s and off at 173.6s, both
// through 'Triggers Universal'. Codename's miss hook is the one
// meatworld.hx/somari.hx use.
function onPlayerMiss(event) {
	if (mmNomiss) health = 0;
}

// 15612-15635 (`goodNoteHit`, so player notes only): on the 'Hey!' note BF
// waves and the girlfriend cheers - except on this stage, where the source
// swaps the cheer for the starman GF's own 'hey'
// (`starmanGF.animation.play('hey', true)`, 15633). The stage XML gives
// starmanGF that animation (`GF Cheer`), and beatHit() above lets it finish
// before the dance resumes. data/notes/Hey!.hx stands its girlfriend half down
// while this stage is active.
function onNoteHit(event) {
	if (!event.player || event.noteType != "Hey!") return;
	if (starmanGF != null) starmanGF.playAnim('hey', true);
}

function onCountdown(event) {
	event.cancelled = true; // source 2488: noCount
}

function postCreate() {
	// Source 4562-4567; BF/starmanGF are revealed by the section-turn logic,
	// while GF is revealed explicitly by the hunter swap and later cutscenes.
	mmDadChar().alpha = 0;
	mmBfChar().alpha = starmanGF.alpha = mmGfChar().alpha = 0.000001;
	if (camHUD != null) camHUD.alpha = 0; // source noHUD

	// engine ignores the XML 'visible' attribute, so re-apply the source's
	// initial hidden state here
	ducktree.visible = false;
	duckleafs.visible = false;
	bowbg.visible = false;
	bowbg2.visible = false;
	bowplat.visible = false;
	bowlava.visible = false;
	cutbg.visible = false;
	cutskyline.visible = false;
	cutstatic.visible = false;
	ycbuLightningL.visible = false;
	ycbuLightningR.visible = false;
	ycbuGyromite.visible = false;
	ycbuLakitu.visible = false;
	clownCar.visible = false;

	// 2605-2611: the beat text, behind everything the source adds after it
	// (including the characters). mariones at 130, scaled 1.5x vertically, its own
	// 1818px field so screenCenter() centres the full-width line.
	mmBeatText = new FlxText(-230, 150, 1818, "", 130);
	mmBeatText.setFormat(Paths.font('mariones.ttf'), 130, FlxColor.WHITE, "center");
	mmBeatText.scrollFactor.x = 0;
	mmBeatText.scrollFactor.y = 0;
	mmBeatText.scale.x = 1;
	mmBeatText.scale.y = 1.5;
	mmBeatText.updateHitbox();
	mmBeatText.screenCenter();
	mmInsertBehindChars(mmBeatText);

	// these are screenCentered at runtime in the source
	cutbg.screenCenter();
	cutskyline.screenCenter();
	cutstatic.screenCenter();

	// generated sprites (the source creates these with makeGraphic/loadGraphic,
	// so they were never part of the extracted stage XML)
	mmBlackFront = new FunkinSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
	mmBlackFront.scale.set(10, 10);
	mmBlackFront.alpha = 1;
	add(mmBlackFront);

	mmDuckBg = new FunkinSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.WHITE);
	mmDuckBg.scale.set(10, 10);
	mmDuckBg.alpha = 0;
	mmDuckBg.color = 0xFF5595DA;
	add(mmDuckBg);

	mmScreenColor = new FunkinSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.RED);
	mmScreenColor.scale.set(10, 10);
	mmScreenColor.alpha = 0;
	mmScreenColor.scrollFactor.set(0, 0);
	add(mmScreenColor);

	mmYcbuWhite = new FunkinSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.WHITE);
	mmYcbuWhite.scale.set(10, 10);
	mmYcbuWhite.alpha = 0;
	add(mmYcbuWhite);

	mmEstatica = new FunkinSprite(0, 0);
	mmEstatica.frames = Paths.getSparrowAtlas('modstuff/Mario_static');
	mmEstatica.animation.addByPrefix('idle', 'static play', 15);
	mmEstatica.animation.play('idle');
	mmEstatica.antialiasing = false;
	mmEstatica.alpha = 0.05;
	mmEstatica.screenCenter();
	add(mmEstatica);

	mmYcbuCrosshair = new FunkinSprite(0, 0);
	mmYcbuCrosshair.loadGraphic(Paths.image('mario/beatus/duckCrosshair'));
	mmYcbuCrosshair.scale.set(28, 28);
	mmYcbuCrosshair.screenCenter();
	mmYcbuCrosshair.visible = false;
	add(mmYcbuCrosshair);

	// 5267-5277: a HUD piece (the source's `cameras = [camHUD]`) at 6x, its
	// 10fps loop already playing - postUpdate spins it a quarter turn per cycle.
	mmFireBar = new FunkinSprite(80, 750);
	mmFireBar.frames = Paths.getSparrowAtlas('mario/beatus/firebar');
	mmFireBar.animation.addByPrefix('loop', 'firebar loop', 10, false);
	mmFireBar.setGraphicSize(Std.int(mmFireBar.width * 6));
	mmFireBar.updateHitbox();
	mmFireBar.antialiasing = false;
	mmFireBar.animation.play('loop');
	mmFireBar.scrollFactor.set(1.1, 1.1);
	mmFireBar.camera = camHUD;
	mmFireBar.visible = false;
	add(mmFireBar);

	mmYcbuHeadL = new FunkinSprite(0, 0);
	mmYcbuHeadL.frames = Paths.getSparrowAtlas('mario/beatus/YouCannotBeatUS_Fellas_Assets');
	mmYcbuHeadL.animation.addByPrefix('LOL', 'Rotat e', 24, true);
	mmYcbuHeadL.animation.addByPrefix('gyromite', 'Bird Up', 24, false);
	mmYcbuHeadL.animation.addByPrefix('lakitu', 'Lakitu', 24, false);
	mmYcbuHeadL.animation.play('LOL', true);
	mmYcbuHeadL.scale.set(0.6, 0.6);
	mmCenterX(mmYcbuHeadL);
	mmYcbuHeadL.x -= 450;
	mmYcbuHeadL.flipX = true;
	mmYcbuHeadL.visible = false;
	add(mmYcbuHeadL);

	mmYcbuHeadR = new FunkinSprite(0, 0);
	mmYcbuHeadR.frames = Paths.getSparrowAtlas('mario/beatus/YouCannotBeatUS_Fellas_Assets');
	mmYcbuHeadR.animation.addByPrefix('LOL', 'Rotat e', 24, true);
	mmYcbuHeadR.animation.addByPrefix('gyromite', 'Bird Up', 24, false);
	mmYcbuHeadR.animation.addByPrefix('lakitu', 'Lakitu', 24, false);
	mmYcbuHeadR.animation.play('LOL', true);
	mmYcbuHeadR.scale.set(0.6, 0.6);
	mmCenterX(mmYcbuHeadR);
	mmYcbuHeadR.x += 445;
	mmYcbuHeadR.visible = false;
	add(mmYcbuHeadR);

	// 2634/2651: both heads are vertical FlxBackdrop columns - the rows above
	// repeat their leaders (see the camEst section).
	mmHeadRow(mmYcbuHeadL);
	mmHeadRow(mmYcbuHeadR);

	// 2616-2696: the six sprites the source puts on camEst.
	ycbuLightningL.cameras = [mmEst()];
	ycbuLightningR.cameras = [mmEst()];
	mmYcbuHeadL.cameras = [mmEst()];
	mmYcbuHeadR.cameras = [mmEst()];
	mmYcbuCrosshair.cameras = [mmEst()];
	mmEstatica.cameras = [mmEst()];
	// The source builds the crosshair and the static *after* the heads
	// (2664/2683, and the create order is additive there), so on that camera
	// they draw over the columns - this port added them earlier in the list.
	if (mmHeadRows.length > 0 && mmHeadRows[mmHeadRows.length - 1].tail != null) {
		mmReinsert(mmYcbuCrosshair, mmHeadRows[mmHeadRows.length - 1].tail, 1);
		mmReinsert(mmEstatica, mmYcbuCrosshair, 1);
	}

	// 2697-2702: the same text again, in black, added in the source's *foreground*
	// pass - it is the one 'ycbu text' writes when value2 is 1 (the 1,000,000
	// count-up of case 26 runs on it), and the one the chart's 32 trigger2==1
	// events use. `add()` puts it on top of the world, i.e. in front of the cast.
	mmOtherBeatText = new FlxText(-230, 150, 1818, "", 130);
	mmOtherBeatText.setFormat(Paths.font('mariones.ttf'), 130, FlxColor.BLACK, "center");
	mmOtherBeatText.scrollFactor.x = 0;
	mmOtherBeatText.scrollFactor.y = 0;
	mmOtherBeatText.scale.x = 1;
	mmOtherBeatText.scale.y = 1.5;
	mmOtherBeatText.updateHitbox();
	mmOtherBeatText.screenCenter();
	add(mmOtherBeatText);

	// 5647-5667: the TV filters are mounted at create, before the countdown.
	mmTvStack();

	// The shared 'onTrigger' hook, through CnE's ScriptPack (`scripts.set` /
	// `scripts.get`) - see the note in turmoilsweep.hx: the old
	// `Reflect.setProperty(PlayState.instance, ...)` threw `Invalid
	// field:onTrigger` on cpp, so nothing was ever registered here either.
	if (PlayState.instance != null && PlayState.instance.scripts != null)
		PlayState.instance.scripts.set("onTrigger",
			function(name:String, v1:String, v2:String) {
				if (name == "Triggers Unbeatable") mmUnbeatable(v1, v2);
				else if (name == "ycbu text") mmYcbuText(v1, v2);
			});
}

function onEvent(event) {
	if (event.event.name == "Camera Movement") {
		mmTurnTarget = Std.int(event.event.params[0]);
		if (Conductor.songPosition >= 0) mmTurn(mmTurnTarget);
		return;
	}
	if (event.event.name == "ycbu text") {
		mmYcbuText(event.event.params[0], event.event.params[1]);
		return;
	}
	if (event.event.name != "Triggers Unbeatable" && event.event.name != "Triggers Universal") return;
	mmUnbeatable(event.event.params[0], event.event.params[1]);
}

// The source adds `beatText` behind everything that follows it in the sprite
// pass, but this port's stage sprites are all appended on top of the world - so
// to put a text *behind* the cast it has to be inserted before the first
// character in the state's member list.
function mmInsertBehindChars(spr) {
	var idx:Int = -1;
	for (i in 0...members.length) {
		var m = members[i];
		if (m == mmDadChar() || m == mmBfChar() || m == mmGfChar()) { idx = i; break; }
	}
	if (idx < 0) add(spr) else insert(idx, spr);
}

// Every `remove(x); insert(members.indexOf(anchor) + off, x)` in the source's
// Unbeatable block means 'move x next to the anchor': off = 1 puts it directly
// in front of the anchor, off = -1 directly behind it. Neither half does that on
// its own here: `FlxGroup.remove(x, splice = false)` only nulls x's slot and the
// following `insert` hands that same slot straight back to it, so x never moves
// - the object has to be *spliced* out first. The anchor is looked up after that
// splice for the same reason: the source's indices carry the null hole x leaves
// behind, this list does not. The insert itself is the source's, shifting tail
// and all: an `off = -1` move lands the object at the anchor's index minus one
// *before* the array grows, so the element that sat there ends up between the
// two - which is what the fork draws as well.
function mmReinsert(obj, anchor, off:Int) {
	if (obj == null) return;
	remove(obj, true);
	var i:Int = (anchor != null) ? members.indexOf(anchor) : -1;
	if (i < 0) {
		// The anchor is not in this state (a stage without that sprite). Keep
		// the sprite on the side the source asked for: below the cast for a
		// 'behind the anchor' move, at the front otherwise.
		if (off < 0) mmInsertBehindChars(obj);
		else add(obj);
		return;
	}
	var p:Int = i + off;
	if (p < 0) p = 0;
	insert(p, obj);
}

// songs/MMcamera.hx publishes its api through CnE's ScriptPack (the engine's
// own cross-script channel, `PlayState.instance.scripts.set/get` - a Reflect
// field cannot be created on the cpp build). It is the camera for this stage:
// while FOLLOWCHARS/ZOOMCHARS are on it rewrites camFollow and the zoom every
// frame, so the two flag writes in the trigger block have to go through it.
function mmCam(which:String, args:Array<Dynamic>):Dynamic {
	var ps = PlayState.instance;
	if (ps == null || ps.scripts == null) return null;
	var api:Dynamic = ps.scripts.get("mmCamera");
	if (api == null) return null;
	if (!Reflect.hasField(api, which)) return null;
	return Reflect.callMethod(api, Reflect.field(api, which), args);
}

// 'ycbu text' (PlayState.hx:13007-13057). Two jobs in one event:
//
//   13011-13026  value2 drives the stage's own sprites - 1|2 idle the gyromite
//                and lakitu, 3 hides the lakitu, 4 idles the gyromite and plays
//                'gyromite' on both heads, 5 idles the lakitu and plays 'lakitu'.
//                The chart uses all five (4 and 5 alone are 200 of Unbeatable's
//                550 events), and the port used to drop every one of them.
//   13028-13057  value1 (with ';' turned into a newline) is written to
//                `otherBeatText` when value2 is 1 and to `beatText` otherwise,
//                re-centred, flashed orange, and restored 0.1s later (WHITE for
//                beatText, BLACK for otherBeatText) by a timer that replaces the
//                previous one. The source's `if (ClientPrefs.flashing)` only
//                wraps the *colour* - the text and the re-centre always happen -
//                and ClientPrefs is not script-readable, so the flash is kept.
function mmYcbuText(v1, v2) {
	var trigger2:Float = Std.parseFloat(Std.string(v2));
	if (trigger2 == null || Math.isNaN(trigger2)) trigger2 = 0;

	switch (trigger2) {
		case 1 | 2:
			ycbuGyromite.animation.play('idle', true);
			ycbuLakitu.animation.play('idle', true);
		case 3:
			ycbuLakitu.alpha = 0;
		case 4:
			ycbuGyromite.animation.play('idle', true);
			mmYcbuHeadL.animation.play('gyromite', true);
			mmYcbuHeadR.animation.play('gyromite', true);
		case 5:
			ycbuLakitu.animation.play('idle', true);
			mmYcbuHeadL.animation.play('lakitu', true);
			mmYcbuHeadR.animation.play('lakitu', true);
	}

	var text:String = StringTools.replace(Std.string(v1), ";", "\n");
	var which = (trigger2 == 1) ? mmOtherBeatText : mmBeatText;
	which.color = 0xFFF87858;
	which.text = text;
	which.updateHitbox();
	which.screenCenter();

	// 13041-13056: cancel the previous restore timer rather than stacking them -
	// the case 26 count-up fires this every frame for 0.75s, so without the cancel
	// the colour would be restored ~45 times over and the flash would never be
	// visible.
	for (tmr in mmYcbuTextTimers) tmr.cancel();
	mmYcbuTextTimers = [];
	mmYcbuTextTimers.push(new FlxTimer().start(0.1, function(tmr) {
		if (trigger2 == 1) mmOtherBeatText.color = FlxColor.BLACK;
		else mmBeatText.color = FlxColor.WHITE;
	}));
}

function mmBeat():Float {
	return 1 / (Conductor.bpm / 60);
}

// `hasDownScroll` (PlayState.hx:742). PlayState.downscroll is a get/set
// property, so read it defensively - the same idiom allfinal.hx, exesequel.hx
// and hatebg.hx use.
function mmDownScroll():Bool {
	if (PlayState.instance == null || Reflect.field(PlayState.instance, "downscroll") == null) return false;
	return Reflect.field(PlayState.instance, "downscroll") == true;
}

function mmCenterX(spr) {
	spr.x = (FlxG.width - spr.width) / 2;
}

function mmGetIcon(p2:Bool) {
	if (PlayState.instance == null) return null;
	for (n in (p2 ? ["iconP2", "icoP2"] : ["iconP1", "icoP1"])) {
		var v = Reflect.field(PlayState.instance, n);
		if (v != null) return v;
	}
	return null;
}

function mmFadeIcon(p2:Bool, a:Float, t:Float) {
	var ic = mmGetIcon(p2);
	if (ic != null) FlxTween.tween(ic, {alpha: a}, t);
}

// mirrors our data/events/Change Character.hx (source value1: 0 bf, 1 opp, 2 gf)
function mmChar(index:Int, name:String) {
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
	var oldIndex:Int = members.indexOf(old);
	remove(old, true);
	member.characters.remove(old);
	var fresh = new Character(0, 0, name, isPlayer);
	stage.applyCharStuff(fresh, member.data.position, 0);
	// dadGroup/gfGroup keep their draw slot in the source, including after
	// cases 17/20 re-stack the cast. Do not reset a later swap to its XML node.
	if (oldIndex >= 0) {
		remove(fresh, true);
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

// The source's two case-28 angel writes are gated on the left head still
// showing its 'LOL' loop (`ycbuHeadL.animation.curAnim.name == 'LOL'`); the
// null guard is this port's, because `curAnim` is null until an animation is
// played.
function mmHeadLOL():Bool {
	if (mmYcbuHeadL == null) return false;
	var a = mmYcbuHeadL.animation.curAnim;
	return a != null && a.name == 'LOL';
}

function mmUnbeatable(value1, value2) {
	var triggerMR:Float = Std.parseFloat(Std.string(value1));
	var triggerMR2:Float = Std.parseFloat(Std.string(value2));
	if (triggerMR2 == null || Math.isNaN(triggerMR2)) triggerMR2 = 0;
	if (triggerMR == null || Math.isNaN(triggerMR)) return;

	switch (triggerMR) {
		case -1:
			FlxTween.tween(mmBlackFront, {alpha: 0.3}, 10, {ease: FlxEase.quadInOut});

		case 0:
			FlxTween.tween(camHUD, {alpha: 1}, 5, {ease: FlxEase.quadInOut});

		case 0.5:
			mmDadChar().alpha = 1;
			mmBlackFront.alpha = 0;
			// titleText / autorText / resyncVocals omitted

		case 1:
			FlxTween.tween(mmDadChar(), {alpha: 0}, 2, {ease: FlxEase.quadInOut});
			mmFadeIcon(true, 0, 2);

		case 2:
			var weanose:Float = mmDadChar().y;
			mmDadChar().alpha = 1;
			mmChar(1, "hunter");
			var ic2 = mmGetIcon(true);
			if (ic2 != null) ic2.alpha = 0;
			mmDadChar().y += 800;
			mmDadChar().x -= 75;
			duckleafs.visible = true;
			ducktree.visible = true;
			if (health > 1) FlxTween.tween(PlayState.instance, {health: 1}, 1, {ease: FlxEase.quadOut});
			mmFadeIcon(true, 1, 1);
			FlxTween.tween(mmDuckBg, {alpha: 1}, 1, {ease: FlxEase.quadOut});
			FlxTween.tween(duckfloor, {alpha: 1}, 2, {ease: FlxEase.quadOut});
			FlxTween.tween(duckleafs, {x: 800}, 1, {startDelay: 1, ease: FlxEase.quadOut});
			FlxTween.tween(ducktree, {x: 0}, 1, {startDelay: 1, ease: FlxEase.quadOut});
			FlxTween.tween(mmDadChar(), {y: weanose}, 1, {ease: FlxEase.quadInOut, onComplete: function(twn:FlxTween) {
				FlxTween.tween(mmDadChar(), {y: weanose + 100}, 1, {ease: FlxEase.quadInOut});
			}});

		case 3:
			var icp1 = mmGetIcon(false);
			if (icp1 != null) {
				var whiteSquare = new FunkinSprite().makeGraphic(50, 50, FlxColor.WHITE);
				whiteSquare.camera = camHUD;
				whiteSquare.setPosition(icp1.x + 60, icp1.y + 30);
				add(whiteSquare);
				new FlxTimer().start(0.05, function(tmr:FlxTimer) {
					whiteSquare.destroy();
					icp1.color = 0x000000;
					new FlxTimer().start(0.05, function(tmr2:FlxTimer) { icp1.color = 0xFFFFFF; });
				});
			}
			var newhealth3:Float = health - 0.1;
			FlxTween.tween(PlayState.instance, {health: newhealth3}, 0.1, {ease: FlxEase.quadOut});
			mmDuckBg.color = 0xFFDAAFA9;
			new FlxTimer().start(0.2, function(tmr:FlxTimer) { mmDuckBg.color = 0xFF5595DA; });
			mmZoom(0.010);
			mmShake(0.05, 0.007, 0.003);

		case 4:
			var elpato:Int = FlxG.random.int(0, 2);
			var track:Int = FlxG.random.int(0, 4);
			var timeDuck:Float = 1;
			var duck = new FunkinSprite(250, 650);
			duck.frames = Paths.getSparrowAtlas('mario/beatus/duck' + elpato);
			duck.animation.addByPrefix('upB', 'duck up', 12, true);
			duck.animation.addByPrefix('idleB', 'duck fly', 12, true);
			duck.scale.set(6.5, 6.5);
			duck.updateHitbox();
			duck.antialiasing = false;
			duck.animation.play('upB');
			mmReinsert(duck, duckfloor, -1); // 12358: just behind the duck-hunt floor
			switch (track) {
				case 0:
					timeDuck = 3;
					duck.y = -200; duck.x = 1500;
					duck.animation.play('idleB');
					duck.flipX = true;
					FlxTween.tween(duck, {x: -400, y: 300}, timeDuck);
				case 1:
					timeDuck = 3.5;
					duck.y = 800; duck.x = 100;
					FlxTween.tween(duck, {x: 600, y: -500}, timeDuck);
				case 2:
					timeDuck = 3;
					duck.animation.play('idleB');
					duck.y = 0; duck.x = -800;
					FlxTween.tween(duck, {x: 1600, y: 300}, timeDuck);
				case 3:
					timeDuck = 3;
					duck.y = 200; duck.x = 1500;
					duck.flipX = true;
					FlxTween.tween(duck, {x: 200, y: -300}, timeDuck);
				case 4:
					timeDuck = 3;
					duck.y = 200; duck.x = -800;
					FlxTween.tween(duck, {x: 1600, y: -500}, timeDuck);
			}
			new FlxTimer().start(timeDuck, function(tmr:FlxTimer) { duck.destroy(); });

		case 5:
			mmEstatica.alpha = 0.6;
			FlxTween.tween(mmEstatica, {alpha: 0.05}, 0.5, {ease: FlxEase.quadInOut});
			mmChar(1, "koopa");
			duckleafs.visible = ducktree.visible = duckfloor.visible = false;
			mmDuckBg.visible = false;
			bowbg.visible = bowbg2.visible = bowplat.visible = bowlava.visible = false;
			cutbg.visible = cutstatic.visible = true;
			cutskyline.visible = false;
			cutbg.animation.play('bowser');
			var newhealth5:Float = health - 0.1;
			FlxTween.tween(PlayState.instance, {health: newhealth5}, 0.1, {ease: FlxEase.quadOut});

		case 5.5:
			mmChar(1, "mrSYS");
			mmDadChar().alpha = 1;
			if (Std.string(value2) != "cheese") {
				mmEstatica.alpha = 0.6;
				FlxTween.tween(mmEstatica, {alpha: 0.05}, 0.5, {ease: FlxEase.quadInOut});
			}
			duckleafs.visible = ducktree.visible = duckfloor.visible = false;
			mmDuckBg.visible = false;
			bowbg.visible = bowbg2.visible = bowplat.visible = bowlava.visible = false;
			cutbg.visible = cutstatic.visible = cutskyline.visible = false;

		case 6:
			switch (triggerMR2) {
				case 0:
					mmChar(1, "hunter");
				case 1:
					mmChar(2, "hunter");
					mmUnbeatable("30", "");
					mmGfChar().x = mmDadChar().x - 25;
					mmGfChar().y = mmDadChar().y + 50;
					mmGfChar().visible = true;
					mmGfChar().alpha = 1;
					mmDadChar().alpha = 0.00001;
				case 2:
					mmChar(1, "mrSYS");
					mmUnbeatable("30", "");
					mmDadChar().alpha = 1;
					mmDadChar().y += 1000;
					mmReinsert(mmGfChar(), mmDadChar(), -1); // 12453-12454: GF drops back behind dad
					FlxTween.tween(mmDadChar(), {y: mmDadChar().y - 1000}, 1.25, {ease: FlxEase.backOut});
					FlxTween.tween(mmGfChar(), {x: mmGfChar().x - 425, y: mmGfChar().y + 50}, 0.75, {ease: FlxEase.cubeOut});
			}
			var newhealth6:Float = health - 0.5;
			FlxTween.tween(PlayState.instance, {health: newhealth6}, 0.1, {ease: FlxEase.quadOut});
			if (triggerMR2 != 2) {
				// 12463-12466: `if (ClientPrefs.flashing && ClientPrefs.filtro85)` -
				// taken as on, see the header.
				if (mmAngel != null) mmAngel.data.stronk.value = [0.325, 0.325];
				mmEstatica.alpha = 0.6;
				FlxTween.tween(mmEstatica, {alpha: 0.05}, 0.5, {ease: FlxEase.quadInOut});
			}
			cutbg.visible = cutstatic.visible = true;
			cutskyline.visible = false;
			cutbg.animation.play('duck');

		case 7:
			switch (triggerMR2) {
				case 0:
					mmChar(1, "koopa");
					mmUnbeatable("30", "");
					mmEstatica.alpha = 0.6;
					FlxTween.tween(mmEstatica, {alpha: 0.05}, 0.5, {ease: FlxEase.quadInOut});
				case 1:
					mmChar(1, "mrSYSwb");
					mmReinsert(funnylayer0, mmDadChar(), -1); // 12490: Bowser drops back behind dad
					funnylayer0.x = 600; funnylayer0.y = 100;
					funnylayer0.x += 700; funnylayer0.y += 700;
					funnylayer0.visible = true;
					FlxTween.tween(funnylayer0, {x: funnylayer0.x - 700, y: funnylayer0.y - 700}, 1.25, {ease: FlxEase.backOut});
			}
			var newhealth7:Float = health - 0.5;
			FlxTween.tween(PlayState.instance, {health: newhealth7}, 0.1, {ease: FlxEase.quadOut});
			// 12504-12505: flashing/filtro85 taken as on.
			if (mmAngel != null) mmAngel.data.stronk.value = [0.325, 0.325];
			cutbg.visible = cutskyline.visible = cutstatic.visible = true;
			cutbg.animation.play('bowser');
			cutskyline.animation.play('duck');

		case 8:
			// 12510-12520: the ending static. `endingnes` turns on the
			// YCBUEndingShader ramp (7282-7286) and the source fades a *fake*
			// health bar to 0 and hides `estatica`; the fake bar is the fork's
			// `healthBar.parentVariable`, which this engine's bar has no
			// equivalent for, so only the flag is kept. The chart never sends
			// this trigger (checked across unbeatable/charts/normal.json), so the
			// shader stays on its frozen seed in practice - exactly as in the
			// source, whose `beatend.update` only runs while the flag is set.
			mmEndingNes = true;

		case 9:
			mmFadeIcon(false, 0, 1);
			mmFadeIcon(true, 0, 1);
			// timeBar / timeTxt / customHB omitted
			mmNomiss = true; // 12527

		case 10:
			mmFadeIcon(false, 1, 0.001);
			mmFadeIcon(true, 1, 0.001);
			mmNomiss = false; // 12532

		case 11:
			switch (triggerMR2) {
				case 0:
					FlxTween.tween(duckleafs, {y: duckleafs.y + 1200}, 1.5, {ease: FlxEase.quadIn});
					FlxTween.tween(ducktree, {y: ducktree.y + 1200}, 1.5, {ease: FlxEase.quadIn});
					FlxTween.tween(duckfloor, {y: duckfloor.y + 1200}, 1.5, {ease: FlxEase.quadIn, onComplete: function(twn:FlxTween) {
						duckleafs.visible = ducktree.visible = duckfloor.visible = false;
					}});
					FlxTween.color(mmDuckBg, 2, mmDuckBg.color, FlxColor.BLACK, {ease: FlxEase.cubeInOut});
				case 1:
					bowbg.visible = bowbg2.visible = bowlava.visible = bowplat.visible = true;
					bowbg2.y -= 200;
					bowbg.y += 1000;
					bowplat.x += 800;
					FlxTween.tween(bowbg2, {y: bowbg2.y + 200}, 0.5, {ease: FlxEase.quadOut});
					if (health > 1) FlxTween.tween(PlayState.instance, {health: 1}, 1, {ease: FlxEase.quadOut});
				case 2:
					FlxTween.tween(bowbg, {y: bowbg.y - 1000}, 0.5, {ease: FlxEase.quadOut});
				case 3:
					FlxTween.tween(bowplat, {x: 800}, 0.5, {ease: FlxEase.quadOut, onComplete: function(twn:FlxTween) {
						FlxTween.tween(bowplat, {x: 600}, 1.5, {type: FlxTween.PINGPONG, loopDelay: 0.5});
					}});
				case 4:
					var weanose4:Float = mmDadChar().y;
					mmChar(1, "koopa");
					mmDadChar().alpha = 1;
					mmDadChar().y += 800;
					FlxTween.tween(bowlava, {y: 550}, 1.5, {ease: FlxEase.quadInOut, onComplete: function(twn:FlxTween) {
						FlxTween.tween(bowlava, {y: 775}, 1.25, {ease: FlxEase.quadInOut, onComplete: function(twn2:FlxTween) {
							FlxTween.tween(bowlava, {y: 750}, 0.5, {ease: FlxEase.quadInOut});
						}});
					}});
					FlxTween.tween(mmDadChar(), {y: weanose4 - 100}, 1, {ease: FlxEase.quadInOut, onComplete: function(twn:FlxTween) {
						FlxTween.tween(mmDadChar(), {y: weanose4}, 1, {ease: FlxEase.quadInOut});
					}});
					mmFadeIcon(true, 1, 1.5);
			}

		case 12 | 13:
			// 12584-12587: case 12 ('lava rise') is an empty fall-through to case
			// 13, so both fire the same red screen flash.
			mmScreenColor.alpha = 0.7;
			FlxTween.tween(mmScreenColor, {alpha: 0}, mmBeat());

		case 14:
			FlxTween.tween(mmBlackFront, {alpha: 0.7}, 5, {ease: FlxEase.quadInOut});

		case 15:
			FlxTween.tween(mmBlackFront, {alpha: 0}, 0.7, {ease: FlxEase.quadInOut});

		case 16:
			mmYcbuWhite.color = FlxColor.BLACK;
			mmReinsert(mmBeatText, mmYcbuWhite, 1); // 12595-12596: the text lifts over the cast
			FlxTween.tween(camHUD, {alpha: 0}, 0.5, {ease: FlxEase.quadInOut});
			FlxTween.tween(mmYcbuWhite, {alpha: 1}, 0.5, {ease: FlxEase.quadInOut, onComplete: function(twn:FlxTween) {
				mmUnbeatable("5.5", "cheese");
			}});

		case 17:
			switch (triggerMR2) {
				case 0:
					mmYcbuWhite.color = FlxColor.WHITE;
					ycbuLakitu.visible = ycbuGyromite.visible = mmGfChar().visible = funnylayer0.visible = false;
					camGame.zoom = 0.9;
					// 12607-12608: the stage's own camera comes back on.
					mmCam("follow", [true]);
					mmCam("zoomFollow", [true]);
				case 1:
					mmChar(1, "mrSYSwb");
					mmReinsert(mmDadChar(), mmOtherBeatText, 1); // 12611-12612: dad in front of the text
					mmDadChar().alpha = 0;
					FlxTween.tween(mmDadChar(), {alpha: 1}, 0.75, {ease: FlxEase.cubeOut});
				case 2:
					mmChar(1, "mrSYS");
					mmUnbeatable("15", "");
					FlxTween.tween(mmYcbuWhite, {alpha: 0}, 0.25, {ease: FlxEase.quadOut});
					FlxTween.tween(camHUD, {alpha: 1}, 0.25, {ease: FlxEase.quadOut});
					mmReinsert(mmBeatText, starmanGF, -1); // 12628-12629: back behind the starman GF
					// 12636-12637: flashing/filtro85 taken as on.
					if (mmAngel != null) mmAngel.data.stronk.value = [0.325, 0.325];
					if (health > 1) health = 1;
			}

		case 18:
			// 12643-12646: `var split = value2.split(','); dupeTimer =
			// Std.parseInt(split[1]); shit = Std.parseFloat(split[0]);` - the
			// angel's per-beat spike value and the beats it stays armed for.
			var split:Array<String> = Std.string(value2).split(",");
			var dt:Int = Std.parseInt(StringTools.trim(split.length > 1 ? split[1] : ""));
			mmDupeTimer = (dt == null || Math.isNaN(dt)) ? 0 : dt;
			var sh:Float = Std.parseFloat(StringTools.trim(split.length > 0 ? split[0] : ""));
			mmShit = (sh == null || Math.isNaN(sh)) ? 0 : sh;

		case 19:
			mmYcbuWhite.alpha = 1;
			FlxTween.tween(mmYcbuWhite, {alpha: 0}, 0.25, {ease: FlxEase.quadOut});
			mmBlackFront.alpha = 0.85;
			cutbg.visible = cutskyline.visible = cutstatic.visible = false;

		case 20:
			mmUnbeatable("5.5", "");
			mmChar(1, "mrSYS");
			mmBlackFront.alpha = 0;
			mmYcbuWhite.alpha = ycbuGyromite.alpha = ycbuLakitu.alpha = 1;
			cutbg.visible = cutskyline.visible = cutstatic.visible = funnylayer0.visible = mmGfChar().visible = false;
			ycbuLakitu.x = 0;
			ycbuGyromite.x = 800;
			ycbuGyromite.y = ycbuLakitu.y = 400;
			mmReinsert(ycbuGyromite, mmBeatText, 1); // 12662-12663
			if (triggerMR2 == 1) {
				mmChar(1, "mrSYSwb");
				mmYcbuWhite.color = FlxColor.BLACK;
				mmYcbuWhite.alpha = 1;
				// 12668-12677: the 'Level 4' re-stack, in the source's order -
				// white behind the text, the text back in front of it, the
				// gyromite behind the text, then GF and dad to just in front of
				// the lakitu / of each other (the source reads GF's new index).
				mmReinsert(mmYcbuWhite, mmBeatText, -1);
				mmReinsert(mmBeatText, mmYcbuWhite, 1);
				mmReinsert(ycbuGyromite, mmBeatText, 1);
				mmReinsert(mmGfChar(), ycbuLakitu, 1);
				mmReinsert(mmDadChar(), mmGfChar(), 1);
				ycbuGyromite.y = ycbuLakitu.y -= 350;
				mmGfChar().visible = funnylayer0.visible = true;
			}

		case 21:
			// 12695-12697: the bar enters from the bottom in upscroll and from the
			// top - spun the other way - in downscroll; case 22's exit (750) is the
			// same in both, like the source.
			var fbDs:Bool = mmDownScroll();
			mmFireBar.visible = true;
			mmFireBar.angle = fbDs ? -180 : 180;
			mmFireBar.y = fbDs ? -400 : 750;
			FlxTween.tween(mmFireBar, {y: fbDs ? -100 : 450}, 2 * mmBeat(), {ease: FlxEase.expoOut});

		case 22:
			FlxTween.tween(mmFireBar, {y: 750}, 2 * mmBeat(), {ease: FlxEase.backIn});
			new FlxTimer().start(2 * mmBeat(), function(tmr:FlxTimer) { mmFireBar.visible = false; });

		case 23:
			// 12704-12749: the finale hand-off. Both beat texts drop behind the
			// lakitu sprite, then the branch the chart sent (0, 2, 3, 1 at 617.2s /
			// 620.9s / 622.9s / 625.0s) rises one actor back in. The '30'/'0.5'
			// call is the source's own re-dispatch.
			mmReinsert(mmOtherBeatText, ycbuLakitu, -1);
			mmReinsert(mmYcbuWhite, mmOtherBeatText, -1);
			mmUnbeatable("30", "0.5");
			ycbuGyromite.alpha = 0;
			ycbuLakitu.alpha = 0;
			mmYcbuWhite.alpha = 1;
			mmDadChar().alpha = 0;
			switch (triggerMR2) {
				case 0:
					mmChar(1, "hunter");
					var weanose23:Float = mmDadChar().y;
					mmDadChar().y += 950;
					mmDadChar().alpha = 1;
					FlxTween.tween(mmDadChar(), {y: weanose23}, 1.25, {ease: FlxEase.backOut});
					mmReinsert(mmDadChar(), mmOtherBeatText, 1); // 12722-12723
				case 1:
					mmChar(1, "koopa");
					var weanose23b:Float = mmDadChar().y;
					mmDadChar().y += 1000;
					mmDadChar().alpha = 1;
					FlxTween.tween(mmDadChar(), {y: weanose23b}, 1.25, {ease: FlxEase.backOut});
					mmReinsert(mmDadChar(), mmOtherBeatText, 1); // 12731-12732
				case 2:
					mmCenterX(ycbuGyromite);
					ycbuGyromite.visible = true;
					ycbuGyromite.y = FlxG.height;
					FlxTween.tween(ycbuGyromite, {y: 200}, 1.25, {ease: FlxEase.backOut});
					ycbuGyromite.alpha = 1;
					mmReinsert(ycbuGyromite, mmOtherBeatText, 1); // 12739-12740
				case 3:
					mmCenterX(ycbuLakitu);
					ycbuLakitu.visible = true;
					ycbuLakitu.y = FlxG.height;
					FlxTween.tween(ycbuLakitu, {y: 200}, 1.25, {ease: FlxEase.backOut});
					ycbuLakitu.alpha = 1;
					mmReinsert(ycbuLakitu, mmOtherBeatText, 1); // 12747-12748
			}

		case 24:
			clownCar.visible = true;
			clownCar.screenCenter();
			clownCar.y += 175;
			clownCar.color = FlxColor.BLACK;
			mmUnbeatable("5.5", "cheese");
			mmDadChar().alpha = 0;
			new FlxTimer().start(0.25, function(tmr:FlxTimer) {
				FlxTween.color(clownCar, 0.4, FlxColor.BLACK, FlxColor.WHITE);
				FlxTween.tween(clownCar, {y: -1100}, 2, {ease: FlxEase.quintIn});
				FlxTween.tween(clownCar.scale, {x: 4, y: 4}, 2, {ease: FlxEase.cubeOut});
			});

		case 25:
			// 12764-12766: the source calls 'ycbu text' with empty values - which
			// clears beatText, since trigger2 0 takes the else branch - then
			// flashes white and shakes both cameras.
			mmYcbuText("", "");
			FlxG.camera.flash(FlxColor.WHITE, 2);
			mmShake(2, 0.003, 0.003);
			cutbg.visible = cutskyline.visible = cutstatic.visible = funnylayer0.visible = mmGfChar().visible = false;
			// 12768-12771: dad fades out, and BF and the starman GF leave the
			// draw list for good - the source removes the boyfriend group and the
			// starman GF outright; there are no groups here, so the characters
			// themselves go.
			mmDadChar().alpha = 0;
			remove(mmBfChar(), true);
			remove(starmanGF, true);

		case 26:
			// 12769-12779: a 0.75s count to 1,000,000 on otherBeatText (trigger2 1 -
			// the orange-then-black copy), which is the "score" slot machine.
			FlxTween.num(0, 1000000, 0.75, {ease: FlxEase.cubeOut}, function(v) {
				mmYcbuText("score;" + Math.floor(v), "1");
			});

		case 27:
			switch (triggerMR2) {
				case 0:
					mmReinsert(ycbuLakitu, mmOtherBeatText, 3); // 12784-12785
					// 12786-12787: `ZOOMCHARS = false; FOLLOWCHARS = false;` - the
					// 5.9s push to 1.4 below only lands because both stop: with
					// FOLLOWCHARS on MMcamera rewrites camFollow every frame, and with
					// ZOOMCHARS on it rewrites the zoom.
					mmCam("zoomFollow", [false]);
					mmCam("follow", [false]);
					ycbuLakitu.x = -600;
					ycbuLakitu.y = FlxG.height;
					ycbuLakitu.visible = true;
					FlxTween.tween(ycbuLakitu, {x: -50}, 1, {ease: FlxEase.quadOut});
					FlxTween.tween(ycbuLakitu, {y: 400}, 1, {ease: FlxEase.quadIn});
					FlxTween.tween(camGame, {zoom: 1.4}, 5.9, {ease: FlxEase.quintIn});
				case 1:
					mmReinsert(funnylayer0, mmOtherBeatText, 1); // 12797
					funnylayer0.x = 650;
					funnylayer0.y = FlxG.height;
					funnylayer0.visible = true;
					FlxTween.tween(funnylayer0, {y: -100}, 1.5, {ease: FlxEase.backOut});
				case 2:
					mmReinsert(ycbuGyromite, mmOtherBeatText, 4); // 12804-12805
					ycbuGyromite.x = 1300;
					ycbuGyromite.y = FlxG.height;
					ycbuGyromite.visible = true;
					FlxTween.tween(ycbuGyromite, {x: 850}, 1, {ease: FlxEase.quadOut});
					FlxTween.tween(ycbuGyromite, {y: 400}, 1, {ease: FlxEase.quadIn});
				case 3:
					mmReinsert(mmGfChar(), mmOtherBeatText, 2); // 12813-12814
					mmGfChar().x = mmDadChar().x - 470;
					mmGfChar().y = FlxG.height;
					mmGfChar().visible = true;
					mmGfChar().alpha = 1;
					FlxTween.tween(mmGfChar(), {y: mmDadChar().y - 180}, 1.5, {ease: FlxEase.backOut});
			}

		case 28:
			// 12821-12907: hardstyle side stuff. Branches 0 and 1 clear the beat
			// text and re-spike the angel (12826/12828 and 12832/12834), 2 and 3
			// drop it to 0.1 while the left head still loops 'LOL' (12845/12855).
			switch (triggerMR2) {
				case 0:
					// hide all
					mmYcbuText("", "");
					if (mmAngel != null) mmAngel.data.stronk.value = [0.325, 0.325];
					ycbuLightningL.visible = ycbuLightningR.visible = false;
					mmYcbuHeadL.visible = mmYcbuHeadR.visible = false;
				case 1:
					// show all
					mmYcbuText("", "");
					if (mmAngel != null) mmAngel.data.stronk.value = [0.325, 0.325];
					mmYcbuHeadL.velocity.y = 600;
					mmYcbuHeadR.velocity.y = -600;
					mmCenterX(ycbuLightningL);
					mmCenterX(ycbuLightningR);
					ycbuLightningL.x -= 440;
					ycbuLightningR.x += 455;
					ycbuLightningL.visible = ycbuLightningR.visible = true;
					mmYcbuHeadL.visible = mmYcbuHeadR.visible = true;
				case 2:
					// reverse direction
					if (mmAngel != null && Math.abs(mmYcbuHeadL.velocity.y) != 1 && mmHeadLOL())
						mmAngel.data.stronk.value = [0.1, 0.1];
					FlxTween.tween(mmYcbuHeadL, {y: mmYcbuHeadL.y + mmYcbuHeadL.velocity.y}, 0.1, {ease: FlxEase.quadOut});
					FlxTween.tween(mmYcbuHeadR, {y: mmYcbuHeadR.y + mmYcbuHeadR.velocity.y}, 0.1, {ease: FlxEase.quadOut});
					FlxTween.tween(mmYcbuHeadL.velocity, {y: mmYcbuHeadL.velocity.y * -1}, 0.1, {ease: FlxEase.quadOut});
					FlxTween.tween(mmYcbuHeadR.velocity, {y: mmYcbuHeadR.velocity.y * -1}, 0.1, {ease: FlxEase.quadOut});
				case 3:
					// skip
					if (mmAngel != null && mmHeadLOL())
						mmAngel.data.stronk.value = [0.1, 0.1];
					FlxTween.tween(mmYcbuHeadL, {y: mmYcbuHeadL.y + (250 * (mmYcbuHeadL.velocity.y / Math.abs(mmYcbuHeadL.velocity.y)))}, 0.25, {ease: FlxEase.quadOut});
					FlxTween.tween(mmYcbuHeadR, {y: mmYcbuHeadR.y + (250 * (mmYcbuHeadR.velocity.y / Math.abs(mmYcbuHeadR.velocity.y)))}, 0.25, {ease: FlxEase.quadOut});
				case 4:
					mmYcbuHeadL.velocity.y /= Math.abs(mmYcbuHeadL.velocity.y);
					mmYcbuHeadR.velocity.y /= Math.abs(mmYcbuHeadR.velocity.y);
				case 5:
					mmYcbuHeadL.velocity.y *= 420;
					mmYcbuHeadR.velocity.y *= 420;
				case 6:
					var firstX:Float = mmYcbuHeadL.x;
					FlxTween.tween(mmYcbuHeadL, {x: mmYcbuHeadR.x}, 0.2, {ease: FlxEase.quadOut});
					FlxTween.tween(mmYcbuHeadR, {x: firstX}, 0.2, {ease: FlxEase.quadOut});
					var firstXL:Float = ycbuLightningL.x;
					FlxTween.tween(ycbuLightningL, {x: ycbuLightningR.x}, 0.2, {ease: FlxEase.quadOut});
					FlxTween.tween(ycbuLightningR, {x: firstXL}, 0.2, {ease: FlxEase.quadOut});
				case 7:
					mmYcbuHeadL.animation.play('LOL', true);
					mmYcbuHeadR.animation.play('LOL', true);
					mmYcbuHeadL.flipX = true;
					mmYcbuHeadR.flipX = false;
					mmCenterX(mmYcbuHeadL);
					mmYcbuHeadL.x -= 450;
					mmCenterX(mmYcbuHeadR);
					mmYcbuHeadR.x += 445;
				case 8:
					mmYcbuHeadL.animation.play('gyromite', true);
					mmYcbuHeadR.animation.play('gyromite', true);
					mmYcbuHeadL.flipX = false;
					mmYcbuHeadR.flipX = true;
					mmYcbuHeadL.x = -50;
					mmYcbuHeadR.x = 830;
				case 9:
					mmYcbuHeadL.animation.play('lakitu', true);
					mmYcbuHeadR.animation.play('lakitu', true);
					mmYcbuHeadL.flipX = true;
					mmYcbuHeadR.flipX = false;
					mmYcbuHeadL.x = -50;
					mmYcbuHeadR.x = 840;
			}

		case 29:
			switch (triggerMR2) {
				case 0:
					mmYcbuCrosshair.visible = true;
					camHUD.visible = false;
					mmYcbuCrosshair.color = (mmYcbuCrosshair.color == FlxColor.WHITE) ? FlxColor.RED : FlxColor.WHITE;
				case 1:
					mmYcbuCrosshair.visible = false;
					camHUD.visible = true;
			}

		case 30:
			var newhealth:Float = health - ((triggerMR2 == 0) ? 1 : triggerMR2);
			if (newhealth < 0.2) newhealth = 0.2;
			FlxTween.tween(PlayState.instance, {health: newhealth}, 0.1, {ease: FlxEase.quadOut});

		case 31:
			var ycbuBullet = new FunkinSprite().loadGraphic(Paths.image('mario/beatus/bullet'));
			ycbuBullet.scale.set(7, 7);
			ycbuBullet.camera = camHUD;
			ycbuBullet.y = FlxG.random.int(40, 680);
			ycbuBullet.antialiasing = false;
			add(ycbuBullet);
			switch (triggerMR2) {
				case 0:
					ycbuBullet.x = 1320;
					FlxTween.tween(ycbuBullet, {x: -60}, 1.5, {onComplete: function(twn:FlxTween) { ycbuBullet.kill(); }});
				case 1:
					ycbuBullet.x = -60;
					ycbuBullet.flipX = true;
					FlxTween.tween(ycbuBullet, {x: 1320}, 1.5, {onComplete: function(twn:FlxTween) { ycbuBullet.kill(); }});
			}

		case 32:
			var ycbuPodoboo = new FunkinSprite().loadGraphic(Paths.image('mario/beatus/fire'));
			ycbuPodoboo.scale.set(6, 6);
			ycbuPodoboo.updateHitbox();
			ycbuPodoboo.antialiasing = false;
			ycbuPodoboo.angle = 0;
			switch (triggerMR2) {
				case 0:
					ycbuPodoboo.setPosition(FlxG.random.int(125, 275), 900);
					mmUnbeatable("32", "2");
					FlxTween.color(mmDuckBg, 0.5, 0xFF740000, FlxColor.BLACK, {ease: FlxEase.quadOut});
					mmZoom(0.006);
					mmShake(0.15, 0.003, 0.002);
				case 1:
					ycbuPodoboo.setPosition(FlxG.random.int(25, 350), 900);
				case 2:
					ycbuPodoboo.setPosition(FlxG.random.int(775, 1100), 900);
			}
			mmReinsert(ycbuPodoboo, bowlava, -1); // 12975: behind the lava
			FlxTween.tween(ycbuPodoboo, {angle: FlxG.random.bool(50) ? 180 : -180}, 0.5 * mmBeat(), {startDelay: 0.75 * mmBeat(), ease: FlxEase.quadInOut});
			FlxTween.tween(ycbuPodoboo, {y: 300}, mmBeat(), {ease: FlxEase.quadOut, onComplete: function(twn:FlxTween) {
				FlxTween.tween(ycbuPodoboo, {y: 900}, mmBeat(), {ease: FlxEase.quadIn, onComplete: function(twn2:FlxTween) {
					ycbuPodoboo.kill();
				}});
			}});

		case 33:
			// 12983-13002: the song-name finale icons only - the iconW4 / iconY0
			// alpha fades and the ycbuIconPos1/2/3 swaps. HUD-only, see the header:
			// the chart sends it eleven times through the finale and there is no
			// sprite for it here, so this stays a documented no-op instead of an
			// omission.
			null;
	}
}

function mmZoom(amount:Float) { defaultCamZoom += amount; }

function mmShake(duration:Float, intensity:Float, ?hudIntensity:Float) {
	if (camGame != null) camGame.shake(intensity, duration);
	// The source's 'Screen Shake' takes a second pair for camHUD and its cases
	// pass a smaller one (0.003 in cases 3/25, 0.002 in 32/0).
	if (hudIntensity != null && camHUD != null) camHUD.shake(hudIntensity, duration);
}
// === end MM stage triggers ===
