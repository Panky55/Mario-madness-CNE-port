

// === MM stage triggers (auto) ===
// 'Triggers The End' - ported from PlayState.hx:13277-13352, together with the
// stage half of `case 'endstage'` (3631-3676, 4405-4410, 5488-5505, 7896-7900)
// and the 'Show Song' card this stage swaps for its own sprite (14206-14290).
//
// Stage-level behaviour that comes with the case:
//   3632-3636  `gfGroup.visible = false; noCount = true; noHUD = true;
//              tvEffect = true; oldTV = true;` - the GF is off stage, the
//              engine's READY/SET/GO are dropped (onCountdown cancelled) and
//              camHUD starts at alpha 0.
//   5488-5505  the HUD pieces the source creates for every other stage are
//              *hidden* on this one (timeBarBG/timeBar/timeTxt/customHB/
//              healthBar/iconP1/iconP2), because trigger 2 turns camHUD back on
//              at 12s and only the notes should be visible then. Of those, the
//              health bar, the two icons and the three score texts exist here
//              and are hidden below (the source does not even create the texts
//              on this stage).
//   4405-4410  `add(castle0); add(funnylayer0); add(blackBarThingie);
//              add(linefount); add(elfin);` - all *after* the character groups,
//              i.e. in front of the fighters. Every sprite in a Codename stage
//              XML sits below them, so the three the XML already has are lifted
//              out of the world layer to the front, in that order.
//   7896-7900  the startCountdown branch makes the 'end' card visible and moves
//              it to camEst - above the world and the fighters, below camHUD.
//              The port puts it in the same slot with the front-of-draw-list
//              placement described in execlassic.hx.
//   3668-3670  `elfin.setGraphicSize(1280); updateHitbox(); screenCenter();` -
//              the XML cannot carry those, so they are applied here.
//
// The source's TV stack (`tvEffect`/`oldTV`, 3635-3636) *is* ported - see the
// "The TV shader stack" section below. NOT ported: the two
// `PauseSubState.muymalo` writes of cases 6/10 (the pause menu's track index,
// not script-reachable). `linefount` is dead code in the source's *trigger*
// group - it only ever shows as the stage's own title card, via 'Show Song'.

var mmBlackBar = null;  // the ending curtain (world level in the source)
var mmLetsago = null;   // 'Lets A Go' card, on camEst in the source
var mmLinefount = null; // 'mario/costume/endtext', the stage's own title card

// A screen-space sprite, appended to the draw list (see the header).
function mmScreen(spr) {
	spr.scrollFactor.set(0, 0);
	add(spr);
	return spr;
}

// The source's `remove(x); add(x)` on one of its own state sprites means "move
// to the very front of the draw list". A stage sprite already lives in this
// state's draw list (`Stage.addSprite`), so it is that same remove + re-add -
// but neither call does what it says on its own: `FlxGroup.remove(basic,
// splice = false)` only nulls the slot (`members[index] = null`) and
// `FlxGroup.add` re-fills the *first* null slot (`getFirstNull()` =
// `members.indexOf(null)`), which is that very slot, so the pair is a no-op and
// the sprite never leaves the world layer. Splice it out and append it past the
// end of the list instead.
function mmToFront(obj) {
	remove(obj, true);
	insert(members.length, obj);
}

// ---------------------------------------------------------------------------
// Character resolution / swap (the same helpers exesequel.hx and wetworld.hx
// carry; the source's 'Change Character' reassigns the `dad` field, this port
// swaps the strumline's character - the one that actually renders).
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
// The stage's own sprites
// ---------------------------------------------------------------------------
function mmGetBlackBar() {
	if (mmBlackBar == null) {
		mmBlackBar = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		mmBlackBar.scale.set(10, 10); // source's setGraphicSize(width * 10)
		mmBlackBar.alpha = 1;         // the stage opens behind it
		mmScreen(mmBlackBar);
	}
	return mmBlackBar;
}

// 'mario/costume/Costume_Letsago', anim 'go' = prefix 'Lets A Go', 24fps, once
// (3661-3665: alpha 0, on camEst, not screen-centred in the source either).
function mmGetLetsago() {
	if (mmLetsago == null) {
		mmLetsago = new FunkinSprite(0, 0);
		mmLetsago.frames = Paths.getSparrowAtlas("mario/costume/Costume_Letsago");
		mmLetsago.animation.addByPrefix("go", "Lets A Go", 24, false);
		mmLetsago.alpha = 0;
		mmScreen(mmLetsago);
	}
	return mmLetsago;
}

// 'mario/costume/endtext' (3672-3676): a plain image, screen-centred, on camEst,
// created invisible. It is never touched by the trigger group - the source shows
// it as this stage's title card instead of the regular one (14214-14226).
function mmGetLinefount() {
	if (mmLinefount == null) {
		mmLinefount = new FlxSprite(0, 0);
		mmLinefount.loadGraphic(Paths.image("mario/costume/endtext")); // no .xml
		mmLinefount.screenCenter();
		mmLinefount.visible = false;
		mmScreen(mmLinefount);
	}
	return mmLinefount;
}

// ---------------------------------------------------------------------------
// The TV shader stack (3635-3636, 5647-5690)
// ---------------------------------------------------------------------------
// `case 'endstage'` sets *both* `tvEffect` and `oldTV`, so the whole song runs
// through the source's VCR stack: VCRMario85 (the tape wobble, the +/-0.003 RGB
// split and the 800-cycle scanline) and VCRBorder (the curved, vignetted bezel)
// on camGame/camHUD, plus OldTVShader (the rolling bands, the 16-direction blur,
// the black dropouts, the per-pixel static and the white sploches) between them
// because `oldTV` is set as well. The three are shaders/vcr85.frag,
// shaders/oldTv.frag and shaders/vcrBorder.frag, mounted in postCreate by
// mmTvStack and driven from postUpdate with the same per-second `time`/`iTime`
// the source feeds `vcr.update()` / `oldFX.update()` (7241/7246) - the wiring
// promoshow.hx uses.
//
// The source also filters its camEst layer; this stage has no camEst camera (the
// camEst sprites - `letsago`, `linefount`, `elfin` - are screen-space sprites on
// camGame's draw list, see mmScreen), so camGame and camHUD cover everything the
// stage draws.
//
// `BrightnessContrastShader` (contrastFX) is the one filter of the block that is
// left out, exactly as in promoshow.hx: nothing on this stage writes its
// uniforms, and its defaults (`brightness = contrast = 1.0`) are an identity
// pass.
var mmVcr = null;            // VCRMario85 -> shaders/vcr85.frag
var mmOldFx = null;          // OldTVShader -> shaders/oldTv.frag
var mmVcrBorder = null;      // VCRBorder -> shaders/vcrBorder.frag
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
}

// The source's filter order is `[vcr, oldFX, border]` (5676-5682); `addShader`
// appends, so mounting in that order reproduces it. Each shader is mounted as
// soon as it is built, rather than after all three are: a shader that fails to
// compile is the one thing that can go wrong here, and a failure there must not
// cost the other two their mount.
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

function postCreate() {
	// 3632: the girlfriend is not on this stage.
	if (gf != null) gf.visible = false;

	// 5488-5505: see the header. The notes are the one HUD layer that stays. The
	// three text fields are hidden too: the source never even creates them on
	// this stage, and their `visible` follows the same branch everywhere else.
	if (healthBar != null) healthBar.visible = false;
	if (healthBarBG != null) healthBarBG.visible = false;
	if (iconP1 != null) iconP1.visible = false;
	if (iconP2 != null) iconP2.visible = false;
	if (scoreTxt != null) scoreTxt.visible = false;
	if (missesTxt != null) missesTxt.visible = false;
	if (accuracyTxt != null) accuracyTxt.visible = false;

	// 4405-4410 order: `castle0`, `funnylayer0`, the curtain and the 'end' card
	// are all on camGame there, in that order; `letsago` and `linefount` are
	// camEst sprites - i.e. above all of them - and `letsago` is created first
	// (3651 vs 3672), so the card draws on top of the "Lets A Go" one. Both are
	// built here rather than lazily: the source creates them at load, and the
	// 4096x4096 atlas should not be decoded mid-song.
	if (castle0 != null) mmToFront(castle0);
	if (funnylayer0 != null) mmToFront(funnylayer0);
	mmGetBlackBar();
	if (elfin != null) {
		elfin.setGraphicSize(1280); // 3668-3670, not carried by the XML
		elfin.updateHitbox();
		elfin.screenCenter();
		mmToFront(elfin);
	}
	mmGetLetsago();
	mmGetLinefount();

	// `noHUD = true` (3634).
	if (camHUD != null) camHUD.alpha = 0;

	// 5647-5690: the filters are mounted at create, i.e. before the countdown
	// runs - the same slot promoshow.hx mounts its stack in.
	mmTvStack();
}

function postUpdate(elapsed:Float) {
	mmTvTick(elapsed);
}

// `noCount = true` (3633): the source never builds its 3-2-1-GO sprites for this
// stage, so the engine's are dropped here (the same thing hatebg.hx does; the
// song starts immediately).
function onCountdown(event) {
	event.cancelled = true;
}

// ---------------------------------------------------------------------------
// 'Triggers The End' 0-11
// ---------------------------------------------------------------------------
// The chart sends these as 'Triggers Universal' (the source re-dispatches that
// to 'Triggers <song>' at runtime, 9489-9496). The value is parsed as a Float:
// the chart jumps straight from 8 to **9.5**, and 9.5 is the source's own
// re-dispatch of 9 plus the character swap, so the port has to keep the halves
// apart (wetworld.hx does the same for Abandoned's 3.5).
function onEvent(event) {
	if (event.event.name == "Show Song") {
		// 14214-14226: this stage's card is `linefount` instead of the regular
		// title/author text, shown for the three seconds between the chart's
		// 'Show Song' 0 (9.0s) and 1 (12.0s). data/events/Show Song.hx stands
		// down for this stage.
		var card = Std.parseInt(event.event.params[0]);
		if (card == null || Math.isNaN(card)) card = 0;
		mmGetLinefount().visible = (card == 0);
		return;
	}

	if (event.event.name != "Triggers The End" && event.event.name != "Triggers Universal") return;

	var trigger = Std.parseFloat(Std.string(event.event.params[0]));
	if (trigger == null || Math.isNaN(trigger)) trigger = 0;

	switch (trigger) {
		case 0:
			// 1.5s: the 'end' card fades in over 2s and the lamp goes out
			// (instant, no tween).
			if (elfin != null) FlxTween.tween(elfin, {alpha: 1}, 2);
			if (funnylayer0 != null) funnylayer0.alpha = 0;

		case 1:
			// 4.5s: ...and back out over 4s.
			if (elfin != null) FlxTween.tween(elfin, {alpha: 0}, 4);

		case 2:
			// 11.99s: the curtain comes halfway down, the HUD comes back (after
			// the stage's own `noHUD`) and the card is gone.
			mmGetBlackBar().alpha = 0.6;
			if (camHUD != null) camHUD.alpha = 1;
			if (elfin != null) elfin.visible = false;

		case 3:
			// 21.0s: DAD_CAM_X = 200 (songs/MMcamera.hx).

		case 4:
			// 21.75s: the curtain closes.
			FlxTween.tween(mmGetBlackBar(), {alpha: 1}, 0.8);

		case 5:
			// 22.5s: "Lets a go!" - the card appears and plays its one shot.
			var go5 = mmGetLetsago();
			go5.alpha = 1;
			go5.animation.play("go");

		case 6:
			// 23.99s: the cutscene is over - the card and the curtain go and the
			// lamp comes back. (`PauseSubState.muymalo = 2` skipped.)
			mmGetLetsago().alpha = 0;
			FlxTween.tween(mmGetBlackBar(), {alpha: 0}, 0.2);
			if (funnylayer0 != null) FlxTween.tween(funnylayer0, {alpha: 1}, 0.2);

		case 7:
			// 109.88s: the curtain closes again and the HUD goes with it.
			FlxTween.tween(mmGetBlackBar(), {alpha: 1}, 0.6);
			if (funnylayer0 != null) FlxTween.tween(funnylayer0, {alpha: 0}, 0.6);
			if (camHUD != null) FlxTween.tween(camHUD, {alpha: 0}, 0.6);

		case 8:
			// 110.62s: DAD_CAM_X = 180.

		case 9:
			mmEndHide();

		case 9.5:
			// 111.0s: the source re-dispatches 9 and then swaps the opponent to
			// `costumedark` and asks him for the 'wahoo' animation - which is the
			// *new* character, so the swap has to come first.
			mmEndHide();
			mmChangeChar(1, "costumedark");
			var d9 = mmDadChar();
			if (d9 != null) d9.playAnim("wahoo", true);

		case 10:
			// 111.75s: the HUD returns and the camera pushes to 1.1 (the zoom
			// pair is in songs/MMcamera.hx). (`PauseSubState.muymalo = 3` skipped.)
			if (camHUD != null) FlxTween.tween(camHUD, {alpha: 1}, 0.6);

		case 11:
			// 138.75s: the ending blackout.
			FlxTween.tween(mmGetBlackBar(), {alpha: 1}, 0.6);
			if (camHUD != null) FlxTween.tween(camHUD, {alpha: 0}, 1);
	}
}

// 13335-13341: the world is cut away for the ending - the foreground, both
// backdrop layers, the floor, the table and the boyfriend are hidden, and the
// curtain drops to 0. The zooms that come with it (1, i.e. a close-up) are in
// songs/MMcamera.hx. 9.5 re-dispatches this step (`triggerEventNote('Triggers
// Universal', '9', '')`), which is why both cases call it.
function mmEndHide() {
	if (castle0 != null) castle0.visible = false;
	if (bg != null) bg.visible = false;
	if (floor != null) floor.visible = false;
	if (mesa != null) mesa.visible = false;
	if (boyfriend != null) boyfriend.visible = false; // source: boyfriendGroup.visible
	mmGetBlackBar().alpha = 0;
}
// === end MM stage triggers ===
