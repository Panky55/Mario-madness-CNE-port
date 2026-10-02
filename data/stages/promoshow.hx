// This stage's `beatHit` is in the appended trigger block below -
// the crowd's idle and the camera tilt both need state that lives there.

// === MM stage triggers (auto) ===
// 'Triggers Promotion' (promoshow) - the whole song's staging, ported from
// PlayState.hx:
//
//   1816-1880    the stage's own create branch (both songs)
//   4304-4305    add(promoDesk) after gfGroup - see the layering note below
//   5635-5641    the `flipchar` block (1817 sets flipchar = true for this stage)
//   5855         snapCamFollowToPos(804, 742): the pre-song framing
//   13057-13142  'Triggers Promotion' itself (cases 0-7)
//   16305-16329  beatHit(): the Stanley section's idles and camera tilt
//
// ---------------------------------------------------------------------------
// The camEst layer (1867-1877)
// ---------------------------------------------------------------------------
// Two of the create branch's sprites are not stage art but camEst layers, and
// both are load-bearing here:
//
//   * `blackBarThingie` (1867-1870) - a window-sized black fill scaled 10x at
//     alpha 0. Case 0 raises it for the 76.85s switch and case 7 (179.86s)
//     raises it again for the ending.
//   * `tvTransition` (1872-1877) - 'mario/promo/tv_trans', whose frames are
//     exactly 1280x720, created hidden and played by case 0 ('dothething'). The
//     extractor did lift it (images/mario/promo/tv_trans.png/.xml are in the
//     mod); the earlier version of this script left it out and set the black
//     fill directly instead.
//
// Psych's camEst sits *between* camGame and camHUD (833-836: added right after
// camGame), so both draw over the world and the fighters and *under* the notes -
// which is also why the 10x fill and the 1:1 transition survive this chart
// driving camGame: 0.6-1.1 zoom, `restartCameraFollow`-style pans, and the
// `cameraTilt` angles that `setProperty ['cameraTilt', N]` puts on camGame
// (applied at 16316/16327, see beatHit below). The port builds that layer the
// way exeport.hx does: a plain FlxCamera at camHUD's own size, added with
// defaultDraw=false and then slid into camHUD's slot in `FlxG.cameras.list`.
//
// The previous version of this file put the fill on the state's draw list with
// `scrollFactor(0, 0)`: a scrollFactor-0 sprite is still *scaled* by its
// camera's zoom (about the screen centre), so at the chart's 0.8 the "blackout"
// was a 1024x576 box with a border of untouched screen around it.
//
// ---------------------------------------------------------------------------
// cameraTilt (16305-16329)
// ---------------------------------------------------------------------------
// The song's second half is Stanley behind a desk while the whole picture tilts
// on the beat. The tilt value is not in the chart as a camera event but as a
// generic property write - `setProperty ['cameraTilt', '6']` at 82.27s,
// '0' at 94.28s, '6' at 95.78s, '8'/'10'/'0' at 140.85-142.27s, '6' at 143.77s,
// '2' at 167.77s, '0' at 179.77s - and CNE's PlayState has no such field, so
// this script reads those events itself (see onEvent) and beatHit applies them.
//
// ---------------------------------------------------------------------------
// The TV shader stack (1817-1819, 5647-5690)
// ---------------------------------------------------------------------------
// `case 'promoshow'` sets *both* `tvEffect` and `oldTV`, so the whole song runs
// through the source's VCR stack: VCRMario85 (the tape wobble, the +/-0.003 RGB
// split, the 800-cycle scanline) and VCRBorder (the curved, vignetted bezel) on
// camGame/camEst/camHUD, plus OldTVShader (the rolling bands, the 16-direction
// blur, the black dropouts, the per-pixel static and the white sploches) between
// them because `oldTV` is set as well. The three are shaders/vcr85.frag,
// shaders/oldTv.frag and shaders/vcrBorder.frag, mounted at create by mmTvStack
// and driven from postUpdate with the same per-second `time`/`iTime` the source
// feeds `vcr.update()` / `oldFX.update()` (7241/7246).
//
// `BrightnessContrastShader` (contrastFX) is the one filter of the block that is
// left out: the promotion chart never writes its uniforms, and its own defaults
// (`brightness = contrast = 1.0`, 5627-5631) are an exact identity pass - the
// 0.3/2.0 and 0.8/1.0 writes at 13200/13218 belong to 'Triggers Abandoned'. It
// is also unmount-only in the source: nothing removes the stack again.
//
// Promotion's stack, endstage's, warioworld's ('Apparition' only) and
// wetworld's are wired; the remaining `tvEffect` stages (exeport, nesbeat,
// demiseport) still omit their own.
//
// ---------------------------------------------------------------------------
// Deviations
// ---------------------------------------------------------------------------
//   * `PauseSubState.muymalo = 2` (case 1) is not script-reachable.
//   * the `flipchar` *positions* (7686 and the mirrored layout maths around it)
//     are the engine's: the port writes the same four `flipX` flags the source
//     does (5635-5641) and leaves the icon placement to Codename's
//     `updateIconPositions`, the same choice demiseport.hx makes.
//   * `add(promoDesk)` (4304-4305, "Shitty layering but whatev it works LOL")
//     is *not* a deviation any more. The source adds the desk right after
//     gfGroup and right before dadGroup, so the counter covers the girlfriend
//     (and the speakers baked into `Promotion_GF_Assets`) while staying behind
//     the fighters. Codename draws a stage's sprites in the order their nodes
//     appear and slots each character in at the marker its own node produced,
//     so `port_stages.py`'s AFTER_GF table emits the desk's node between
//     <girlfriend/> and <dad/> - same order, same result. The desk is hidden
//     from case 1 (79.15s) onwards.
//   * `dad.idleSuffix = '-alt'` (case 5) is written through Reflect and followed
//     by `recalculateDanceIdle()` when the character has it, the way the port's
//     own 'Alt Idle Animation' event does - the source writes the field alone,
//     but the suffix is only consulted when the idle is recalculated.
//   * case 6 (13119-13123) cancels every tween in the source's `extraTween`
//     array; on this stage that array only ever holds case 5's camera tween, so
//     the cancel is the camera release - and it is a no-op in practice, because
//     the tween is 3s long and case 6 fires at 167.86s.

var mmBlackBar:FlxSprite;
var mmTvTrans = null;
var mmStanText:Int = 1;
var mmTilt:Float = 0;
var mmCamTween = null;
var mmStanLines = null;      // the state-level 'lines' sprite (1855-1864, added at 13082)

// --- the TV stack (see the header) ---------------------------------------- //
var mmVcr = null;            // VCRMario85 -> shaders/vcr85.frag
var mmOldFx = null;          // OldTVShader -> shaders/oldTv.frag
var mmVcrBorder = null;      // VCRBorder -> shaders/vcrBorder.frag
var mmVcrTime:Float = 0;     // VCRMario85 `time` - the source starts it at 0
var mmOldTime:Float = 0;     // OldTVShader `iTime` - seeded at mount (mmTvStack)
var mmTvOn:Bool = false;

// ---------------------------------------------------------------------------
// The camEst layer (see the header)
// ---------------------------------------------------------------------------
var mmEstCam:FlxCamera = null;
var mmEstPlaced:Bool = false;
var mmEstWarned:Bool = false;

// `Reflect.field` rather than `FlxG.cameras.list` directly: the array is a real
// field of the engine's camera front end, but a lookup that comes back empty
// must leave the camera where it is, not take the script down with it.
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
// camHUD, and in flixel a camera's canvas is composited in `FlxG.cameras.list`
// order - so the port adds its camera the normal way and then slides it in at
// camHUD's own index, i.e. camEst's slot.
function mmEstBelowHud() {
	if (mmEstCam == null || mmEstPlaced) return;
	var list = mmCamList();
	if (list == null) {
		if (!mmEstWarned) {
			mmEstWarned = true;
			trace("[promoshow] camEst: no FlxG.cameras.list - the layer stays above camHUD");
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

// camEst and camHUD are the same rectangle in Psych (both are bare FlxCameras),
// so the layer is pinned to camHUD's size rather than assumed to be FlxG's.
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

function mmEstAdd(spr) {
	spr.cameras = [mmEst()];
	add(spr);
	return spr;
}

// 1867-1870: window-sized black, then `setGraphicSize(width * 10)` - the 10x is
// the source's own way of staying full-screen on a layer that is never zoomed.
function mmGetBlackBar():FlxSprite {
	if (mmBlackBar == null) {
		mmBlackBar = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		mmBlackBar.setGraphicSize(Std.int(mmBlackBar.width * 10));
		mmBlackBar.alpha = 0;
		mmEstAdd(mmBlackBar);
	}
	return mmBlackBar;
}

// 1872-1877: 'mario/promo/tv_trans', 'dothething' = the "transition" frames at
// 24fps, one-shot, created hidden. It is the wipe itself, so it has to be 1:1 on
// a zoom-1 layer - every frame is exactly 1280x720.
function mmGetTvTrans() {
	if (mmTvTrans == null) {
		mmTvTrans = new FlxSprite(0, 0);
		mmTvTrans.frames = Paths.getSparrowAtlas("mario/promo/tv_trans");
		mmTvTrans.animation.addByPrefix("dothething", "transition", 24, false);
		mmTvTrans.visible = false;
		mmEstAdd(mmTvTrans);
	}
	return mmTvTrans;
}

// 1855-1864: `new BGSprite('mario/promo/stanley_lines', 550, 500, ['lines'], false)`
// plus the eight single-frame `line1..line8` anims, which is the sprite the source
// adds to the state at 13082. Its frames come from the stage XML sprite - the same
// atlas, already parsed, so this costs one FlxSprite and no second decode - and the
// XML copy stays hidden. It cannot be used directly: it is a child of the stage, and
// a stage child always draws under the characters, while CNE's Stage exposes no
// reflectable remove() to detach it with (the call threw Null Function Pointer and
// took the whole of case 1 with it).
function mmGetStanLines() {
	if (mmStanLines == null) {
		if (stanlines == null) return null;
		mmStanLines = new FlxSprite(550, 500);
		if (stanlines.frames != null) mmStanLines.frames = stanlines.frames;
		mmStanLines.animation.addByIndices("line1", "lines", [0], "", 24, true);
		mmStanLines.animation.addByIndices("line2", "lines", [1], "", 24, true);
		mmStanLines.animation.addByIndices("line3", "lines", [2], "", 24, true);
		mmStanLines.animation.addByIndices("line4", "lines", [3], "", 24, true);
		mmStanLines.animation.addByIndices("line5", "lines", [4], "", 24, true);
		mmStanLines.animation.addByIndices("line6", "lines", [5], "", 24, true);
		mmStanLines.animation.addByIndices("line7", "lines", [6], "", 24, true);
		mmStanLines.animation.addByIndices("line8", "lines", [7], "", 24, true);
		mmStanLines.antialiasing = stanlines.antialiasing;
	}
	return mmStanLines;
}

// ---------------------------------------------------------------------------
// `addCharacterToList('stanley', 1)` (1879)
// ---------------------------------------------------------------------------
// Case 1 (79.15s) swaps the opponent for Stanley. Decoding that atlas mid-song
// is a visible stall, so it is decoded once here, at script load, the way
// allfinal.hx/exeport.hx do it: `FunkinSprite.loadSprite` resolves frames
// through `Paths.getFrames(path)`, which caches by path, so this call makes the
// later `new Character()` reuse the frames.
var mmPreloadChars:Array<String> = ["stanley"];

// The image a character's XML points at (`sprite="..."`) - the value the preload
// caches under and the one `FunkinSprite.loadSprite` later asks for.
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
	if (img == null || !Assets.exists(img)) return;
	Paths.getFrames(img, true); // exactly Character's own loader call
}

function mmPreloadAll() {
	for (name in mmPreloadChars) mmPreloadChar(name);
}

// ---------------------------------------------------------------------------
// The character swap case 1 fires (source: triggerEventNote('Change Character'))
// ---------------------------------------------------------------------------
// Same swap as data/events/Change Character.hx. The event file's version is
// enough here because the source sets `dad.x = 697; dad.y = 215;` on the very
// next two lines, so nothing about the swap-in's own position survives either
// way (unlike exeport.hx's case 5, which needs the group anchor kept).
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

// The live character of a strumline. A stage script's `dad` is a snapshot taken
// when it loads, and this stage swaps the opponent at 79.15s ('Triggers
// Promotion' 1 -> `stanley`) - so every write after that has to resolve through
// the strumlines (the same hazard the other stage scripts document).
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

// The source's `dad.x = 697; dad.y = 215` (13091-13092) is a *sprite* write,
// i.e. an absolute position: FlxSpriteGroup bakes the group's position into its
// children as they are added and moved, so a direct write is screen-space. This
// build renders at `x - k * globalOffset.x` / `y + globalOffset.y`, so the
// write goes back through that pair (allfinal.hx/forest.hx use the same one).
function mmPlaceWorld(c, worldX:Float, worldY:Float) {
	if (c == null) return;
	var k:Float = (c.isPlayer != c.playerOffsets) ? 1 : -1;
	c.x = worldX + k * c.globalOffset.x;
	c.y = worldY - c.globalOffset.y;
}

function mmChangeChar(index:Int, name:String) {
	if (name == null || name == "" || name == "null") return;
	if (!Assets.exists(Paths.xml("characters/" + name))) return;

	// In the generated charts the opponent strumline is first, the player
	// strumline is second, and the girlfriend (if any) is third.
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
	stage.applyCharStuff(fresh, member.data.position, 0);
	// The source's death character is a global (GameOverSubstate.characterName) and
	// survives a swap; this port keeps it on the character (see songs/MMcamera.hx's
	// game-over table), so the current one has to ride across.
	fresh.gameOverCharacter = old.gameOverCharacter;
	member.characters.insert(0, fresh);
	mmSwapIcon(index, fresh);
}

// ---------------------------------------------------------------------------
// 'Triggers Promotion' (13057-13142)
// ---------------------------------------------------------------------------
function onEvent(event) {
	// The chart's `setProperty ['cameraTilt', N]` writes (see the header). CNE's
	// PlayState has no such field, so the value is taken here, and
	// data/events/setProperty.hx skips that one write (its SETPROP_SOURCE_ONLY
	// list) rather than being handed a field it cannot set.
	if (event.event.name == "setProperty") {
		if (Std.string(event.event.params[0]) == "cameraTilt") {
			var v:Float = Std.parseFloat(Std.string(event.event.params[1]));
			if (v != null && !Math.isNaN(v)) mmTilt = v;
		}
		return;
	}

	if (event.event.name != "Triggers Promotion" && event.event.name != "Triggers Universal") return;
	var trigger = Std.parseInt(event.event.params[0]);
	if (trigger == null || Math.isNaN(trigger)) trigger = 0;

	switch (trigger) {
		case 0:
			// 13061-13069: the TV transition is the wipe - it plays first, and the
			// black fill and the HUD cut land 0.08s later, on the transition's
			// second pose. Both writes are inside the source's own timer.
			var tv = mmGetTvTrans();
			tv.animation.play("dothething");
			tv.visible = true;
			new FlxTimer().start(0.08, function(tmr) {
				mmGetBlackBar().alpha = 1;
				if (camHUD != null) camHUD.alpha = 0;
			});
		case 1:
			// 13070-13101: the switch to the Stanley section.
			promoBG.visible = false;
			promoBGSad.visible = false;
			promoDesk.visible = false;
			boyfriend.visible = false;
			gf.visible = false;
			darkFloor.visible = true;
			defaultCamZoom = 0.7;
			// Source (13082): `add(stanlines); stanlines.alpha = 0` - this is what
			// both shows the sprite and puts it above dad, the desk and the promo BGs.
			// The XML twin of it starts hidden for the same reason (HIDDEN_AT_LOAD in
			// port_stages.py); the state-level sprite is built in mmGetStanLines.
			if (mmGetStanLines() != null) {
				add(mmStanLines);
				mmStanLines.visible = true;
				mmStanLines.alpha = 0;
			}
			if (health > 1) health = 1;
			// 13091: triggerEventNote('Change Character', '1', 'stanley').
			mmChangeChar(1, "stanley");
			// 13091-13092: the source writes the *sprite* right after the swap -
			// an absolute position, on the character the swap just put in.
			mmPlaceWorld(mmDadChar(), 697, 215);
			FlxTween.tween(mmGetBlackBar(), {alpha: 0}, 4, {ease: FlxEase.quadInOut});
			if (camHUD != null) FlxTween.tween(camHUD, {alpha: 1}, 4, {ease: FlxEase.quadInOut});
		case 2:
			FlxTween.tween(bgLuigi, {alpha: 1}, 0.4, {ease: FlxEase.quadInOut});
		case 3:
			FlxTween.tween(bgPeach, {alpha: 1}, 0.4, {ease: FlxEase.quadInOut});
		case 4:
			// 13103-13118: one of the eight `lines` poses, thrown at a random angle
			// and drifting to a random side, then fading on the second beat.
			var lines = mmGetStanLines();
			if (lines == null) return;
			lines.alpha = 1;
			// `animation.play` and not `playAnim`: this sprite is a bare FlxSprite,
			// and `playAnim` is FunkinSprite's own helper (the stage's own art and
			// the characters have it, FlxSprite does not).  The member resolved to
			// null and threw Null Function Pointer on *every* one of the Stanley
			// section's `lines` triggers - one per beat, for the rest of the song -
			// which also meant the pose was never switched and the sprite never
			// drifted, so case 4 did nothing at all.
			lines.animation.play("line" + mmStanText, true);
			mmStanText++;
			lines.angle = FlxG.random.int(-30, 30);
			lines.x = 550;
			lines.y = 500;
			FlxTween.tween(lines, {x: lines.x + (FlxG.random.bool(50) ? -150 : 150)},
				(2 * (1 / (Conductor.bpm / 60))) - 0.05, {ease: FlxEase.quadOut});
			FlxTween.tween(lines, {y: lines.y + (FlxG.random.bool(50) ? -75 : 75)},
				(2 * (1 / (Conductor.bpm / 60))) - 0.05, {ease: FlxEase.quadOut});
			FlxTween.tween(lines, {alpha: 0}, (1 * (1 / (Conductor.bpm / 60))) - 0.05,
				{startDelay: (1 * (1 / (Conductor.bpm / 60)))});
		case 5:
			// 13124-13136: the desk flash, the dad's 'depression', the camera pan to
			// the desk and - 1.1s later - the depressing background.
			promoDesk.playAnim("flash");
			// Case 5 fires at 56.77s, before the 79.15s swap, but it reads the
			// live field like every other write in this group.
			var d5 = mmDadChar();
			if (d5 != null) {
				d5.playAnim("depression", true);
				// 13093: `dad.idleSuffix = '-alt'`.
				Reflect.setProperty(d5, "idleSuffix", "-alt");
				if (Reflect.hasField(d5, "recalculateDanceIdle"))
					Reflect.callMethod(d5, Reflect.field(d5, "recalculateDanceIdle"), []);
			}
			// `extraTween` in the source - stored so case 6 can cancel it.
			mmCamTween = FlxTween.tween(camFollow, {x: 1009, y: 544}, 3, {ease: FlxEase.quadInOut});
			new FlxTimer().start(0.3, function(tmr) {
				promoDesk.playAnim("luigi");
				new FlxTimer().start(0.8, function(tmr2) {
					promoBGSad.visible = true;
					FlxTween.tween(promoBG, {alpha: 0}, 1, {ease: FlxEase.quadInOut});
				});
			});
		case 6:
			// 13119-13123: "not sure what this does but i will add it lol 408" -
			// everything in `extraTween` is cancelled; on this stage that is the
			// case-5 camera tween.
			if (mmCamTween != null) mmCamTween.cancel();
		case 7:
			// 13138-13141: the ending fade.
			FlxTween.tween(mmGetBlackBar(), {alpha: 1}, 4);
			if (camHUD != null) FlxTween.tween(camHUD, {alpha: 0}, 4);
	}
}

// ---------------------------------------------------------------------------
// beatHit: the Stanley section's idles and the camera tilt (16305-16329)
// ---------------------------------------------------------------------------
// While Stanley is the opponent, every even beat snaps camGame.angle to
// `cameraTilt` and re-plays the three idles, then eases the angle back to 0 over
// a beat minus 0.05s; every 4th beat does the same with the '-alt' idles and the
// *negative* tilt. On those beats the source runs both branches, so the
// 4th-beat branch is the one that lands - the order is kept.
// The stage's whole beat script: PlayState.hx's `case 'promoshow'` block
// (16305-16332) keeps the crowd's idle alternation inside the same
// `dad.curCharacter == 'stanley'` guard as dad's own idle, so the generated
// stage head does not carry a `beatHit` of its own for this stage (see
// port_stage_scripts.py) - this is the only one, and `mmStanIdle` plays the
// three of them together.
function beatHit() {
	// The guard reads the live character: the switch to Stanley lands at 79.15s,
	// after which the `dad` global names the object that swap removed - with the
	// global the whole Stanley-section beat script (the idle snaps and the
	// camera tilt) never ran.
	var dBeat = mmDadChar();
	if (dBeat == null || dBeat.curCharacter != "stanley") return;
	var beatTime:Float = 1 / (Conductor.bpm / 60);
	if (curBeat % 2 == 0) {
		mmStanIdle("idle");
		mmCameraTilt(mmTilt, beatTime);
	}
	if (curBeat % 4 == 0) {
		mmStanIdle("idle-alt");
		mmCameraTilt(-mmTilt, beatTime);
	}
}

// `dad.animation.play` and not `playAnim`, because the source drives the raw
// animation here (16313/16322) - the character's own dance/offset bookkeeping is
// not involved. The two background sprites are stage XML sprites, i.e.
// FunkinSprites, so their `playAnim` *is* the atlas one.
//
// The sing check uses `StringTools.startsWith`, not `a.name.startsWith`: `String`
// has no such member in Haxe 4 (the two are static on `StringTools`), so the
// member form resolves to null in HScript and throws "Null Function Pointer" on
// every beat of the Stanley section.
function mmStanIdle(anim:String) {
	var d = mmDadChar();
	if (d != null) {
		var a = (d.animation == null) ? null : d.animation.curAnim;
		if (a == null || a.name == null || !StringTools.startsWith(a.name, "sing")) d.animation.play(anim, true);
	}
	if (bgLuigi != null) bgLuigi.playAnim(anim, true);
	if (bgPeach != null) bgPeach.playAnim(anim, true);
}

function mmCameraTilt(angle:Float, beatTime:Float) {
	if (camGame == null) return;
	camGame.angle = angle;
	FlxTween.tween(camGame, {angle: 0}, beatTime - 0.05, {ease: FlxEase.quadIn});
}

// ---------------------------------------------------------------------------
// The TV stack (1817-1819, 5647-5690)
// ---------------------------------------------------------------------------
// Same read virtual.hx makes: with the engine's "Gameplay Shaders" option off,
// `new CustomShader(...)` stays null and its setters no-op.
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

// The source's filter order is `[vcr, oldFX, border]` (5678/5682), applied to
// camGame, camEst and camHUD; `addShader` appends, so mounting in that order on
// each camera reproduces it. Each shader is mounted as soon as it is built,
// rather than after all three are: a shader that fails to compile is the one
// thing that can go wrong here (shaders/oldTv.frag guards its prng with
// `__VERSION__` for exactly that reason), and a failure there must not cost
// the other two their mount.

// The source's OldTVShader seeds its `iTime` with `Timer.stamp()` in its
// constructor (OldTVShader.new()), i.e. seconds since the process started, so
// the rolling bands and the static begin on that phase instead of on frame 0's
// zero state. `haxe.Timer.stamp` is inlined to a native call on this target and
// cannot be reflected from HScript, so the same quantity comes from
// FlxGame.ticks - the engine's own milliseconds-since-game-start counter. A
// build that cannot read it seeds 0, which is the old behaviour.
function mmProcessTime():Float {
	var game = Reflect.field(FlxG, "game");
	if (game == null || !Reflect.hasField(game, "ticks")) return 0;
	var ms:Dynamic = Reflect.field(game, "ticks");
	return (ms == null) ? 0 : ms / 1000.0;
}

function mmTvStack() {
	if (mmTvOn || !mmShadersAllowed()) return;
	mmTvOn = true;
	// Source `OldTVShader.new()`: `iTime.value = [Timer.stamp()]`.
	mmOldTime = mmProcessTime();
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
// postCreate
// ---------------------------------------------------------------------------
function postCreate() {
	// 5635-5641: `flipchar` (1817) mirrors both health bars and both icons for
	// the whole song.
	if (healthBar != null) healthBar.flipX = true;
	if (healthBarBG != null) healthBarBG.flipX = true;
	if (iconP1 != null) iconP1.flipX = true;
	if (iconP2 != null) iconP2.flipX = true;

	// The camEst layer itself (1867-1877), in the source's own creation order:
	// the black fill first, then the transition on top of it.
	mmGetBlackBar();
	mmGetTvTrans();

	// 5647-5690: the filters are mounted at create, i.e. before the countdown runs.
	mmTvStack();
}

// Same slot exeport.hx uses for its camEst layer: the camera is placed once (and
// re-placed until camHUD is in the list) and kept at camHUD's size.
function postUpdate(elapsed:Float) {
	mmEstBelowHud();
	mmEstSize();
	mmTvTick(elapsed);
}

mmPreloadAll();
// === end MM stage triggers ===
