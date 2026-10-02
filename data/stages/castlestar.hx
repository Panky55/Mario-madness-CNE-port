import flixel.addons.effects.FlxTrail;

// === MM stage triggers (auto) ===
// 'Triggers No Hope' - ported from PlayState.hx:10611-10649, together with the
// stage half of `case 'castlestar'` (3342-3408, 4399-4403) and the camera half
// in songs/MMcamera.hx (mmCastleTrigger).
//
// The group is a four-beat cutscene: dad turns into `devilmariotalk` and starts
// talking (0), he is given a power-trail and an '-alt' idle (1) which are both
// taken away again (2), and finally the `warning` poster flies in and out (3).
//
// Stage-level behaviour that comes with the case:
//   3350-3352  `noCount`/`noHUD` - the READY/SET/GO are dropped (onCountdown
//              cancelled) and camHUD starts at alpha 0 (the chart's own
//              'Ocultar HUD' 2 brings it back at 14.6s), and the GF is off stage.
//   3359-3366  a full-screen black (`blackthing`, a `makeGraphic`) fades off over
//              2s after a one-second delay. On camEst there, which is *between*
//              camGame and camHUD, so the HUD stays visible through it - the
//              port's stand-in is a screen-space sprite in front of the draw
//              list (`scrollFactor(0, 0)`, the slot execlassic.hx describes). The
//              fade is create-relative in the source too, so it is started from
//              postCreate rather than from a countdown branch.
//   3398-3399  `powervitte`, a 'modstuff/126' vignette on camEst, starts at
//              0.000001 and is raised by Power Attack's wind-up.
//
// Art fix: five of the stage's `BGSprite`s are created from locals
// (`thex = -900`, `they = -930`) rather than literals, and the extractor folded
// the *scroll factors* of the five-argument constructor into x/y for exactly
// those - so data/stages/castlestar.xml places `bg`, `castle2`, `castle2_2`,
// `castle1` and `floor` at (0.1,0.1)/(0.25,0.25)/(0.4,0.4)/(1,1) with no scroll
// factors at all. mmFixArt() puts the source's own values back.
//
// The source's `GameOverSubstate.characterName = 'bfPowerdeath'` and its two
// sounds ride `songs/MMcamera.hx`'s game-over table
// (`castlestar|bfPowerdeath|POWERSTARDEATH|POWERSTARDEATH_LOOP_60BPM`), and the
// `addCharacterToList` targets (3352-3354) are warmed by `mmPreloadCharacters`.
// NOT ported: the source's `hasVA`/`vaCount` fields.

// ----------------------------------------------------------------------------
// camEst stand-in + helpers
// ----------------------------------------------------------------------------
// A screen-locked sprite, appended to the draw list: above the world and the
// fighters, below camHUD.
var mmEstCam = null;
var mmPowerVignette = null;

function mmEst() {
	if (mmEstCam == null) {
		mmEstCam = new FlxCamera(0, 0, FlxG.width, FlxG.height);
		mmEstCam.bgColor = FlxColor.TRANSPARENT;
		FlxG.cameras.add(mmEstCam, false);
		var list = FlxG.cameras.list;
		list.remove(mmEstCam);
		var at = list.indexOf(camHUD);
		list.insert(at < 0 ? list.length : at, mmEstCam);
	}
	return mmEstCam;
}

function mmScreen(spr) {
	spr.cameras = [mmEst()];
	spr.scrollFactor.set(0, 0);
	add(spr);
	return spr;
}

// The fork's `remove(x); add(x)` idiom, done the way this engine needs it: a
// bare `remove` only nulls the slot and `add` re-fills that same slot, so the
// splice is what actually moves the sprite.
function mmToFront(obj) {
	if (obj == null) return obj;
	remove(obj, true);
	insert(members.length, obj);
	return obj;
}

// Codename's `Stage` is not a group (`class Stage extends FlxBasic`), so
// `stage.add`/`stage.members` do not exist and HScript resolves them to null -
// calling them throws Null Function Pointer and aborts the rest of the handler.
// `Stage.addSprite` instead puts every stage sprite straight into the *state's*
// draw list and `Stage.applyCharStuff` inserts each character at its marker, so
// a bare `members`/`insert`/`add` here is the state's list and the world layer
// is the run of sprites below the character band.
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

// Same swap as data/events/Change Character.hx (index 0 = boyfriend,
// 1 = opponent, 2 = girlfriend - the source's own numbering).
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

// The opponent, resolved through the strumline: 'Change Character' swaps the
// strumline's character, and a script global can lag that by a frame (see the
// longer note in exesequel.hx). `dad` stays the fallback.
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

function mmDadChar() {
	var d = mmMem(0);
	return (d != null) ? d : dad;
}

// 10614-10616: `triggerEventNote('Alt Idle Animation', 'Dad', suffix)` - what
// data/events/Alt Idle Animation.hx does for the chart's own events.
function mmAltIdle(suffix:String) {
	var d = mmDadChar();
	if (d == null) return;
	Reflect.setProperty(d, "idleSuffix", suffix);
	if (Reflect.hasField(d, "recalculateDanceIdle"))
		Reflect.callMethod(d, Reflect.field(d, "recalculateDanceIdle"), []);
}

// ----------------------------------------------------------------------------
// The sprites the group owns
// ----------------------------------------------------------------------------
var mmBlackOut = null;   // `blackthing` (3359), camEst, fades off at load
var mmWarning = null;    // `powerWarning` (3401), camEst, hidden until case 3
var mmTrail = null;      // `powerTrail` (10618), the FlxTrail behind dad

function mmGetBlackOut() {
	if (mmBlackOut == null) {
		mmBlackOut = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		mmBlackOut.scale.x = 10; mmBlackOut.scale.y = 10; // source's setGraphicSize(width * 10)
		mmBlackOut.alpha = 1;
		mmScreen(mmBlackOut);
	}
	return mmBlackOut;
}

function mmGetWarning() {
	if (mmWarning == null) {
		mmWarning = new FlxSprite().loadGraphic(Paths.image("mario/star/warning"));
		mmWarning.screenCenter();
		mmWarning.visible = false;
		mmScreen(mmWarning);
	}
	return mmWarning;
}

// 10618-10619: `new FlxTrail(dad, null, 4, 5, 0.5, 0.069)` inserted just behind
// the dad group. The class comes from flixel-addons and is already instantiated
// from an engine script this way (assets/data/characters/spirit.hx), so it is
// safe from HScript. "Just behind the fighters" is the front of this port's world
// layer (characters are always drawn after it), which is where allfinal.hx puts
// the characters it has to hide behind them.
function mmGetTrail() {
	if (mmTrail == null) {
		var target = mmDadChar();
		mmTrail = new FlxTrail(target, null, 4, 5, 0.5, 0.069);
		mmTrail.beforeCache = target.beforeTrailCache;
		mmTrail.afterCache = target.afterTrailCache;
		mmWorldAdd(mmTrail);
	}
	return mmTrail;
}

// ----------------------------------------------------------------------------
// Load
// ----------------------------------------------------------------------------
function onCountdown(event) {
	// `noCount = true` (3350): the source never builds its 3-2-1-GO sprites.
	event.cancelled = true;
}

// 3355-3356/4355-4369: the five `thex`/`they` layers.
function mmFixArt() {
	if (bg != null) { bg.setPosition(-900, -930); bg.scrollFactor.set(0.1, 0.1); }
	if (castle2 != null) { castle2.setPosition(-1100, -930); castle2.scrollFactor.set(0.1, 0.1); }
	if (castle2_2 != null) { castle2_2.setPosition(-1100, -930); castle2_2.scrollFactor.set(0.25, 0.25); }
	if (castle1 != null) { castle1.setPosition(-1100, -930); castle1.scrollFactor.set(0.4, 0.4); }
	if (floor != null) { floor.setPosition(-900, -930); floor.scrollFactor.set(1, 1); }
}

function postCreate() {
	mmFixArt();

	// 4399-4403: the source builds `fore` inside the *foreground* switch and
	// adds it after the character groups, so the brick wall draws over the
	// fighters. The stage XML carries it as an ordinary child; it is lifted to
	// the end of the state's draw list (its 1.5 scroll factor is already in the
	// XML).
	mmToFront(fore);

	// 3352: the GF is off stage for the whole song, and 3351's `noHUD` is
	// camHUD's alpha (the same substitution every other port makes).
	if (gf != null) gf.visible = false;
	if (camHUD != null) camHUD.alpha = 0;

	// 3359-3366: the stage opens behind a black film that clears from 1s over 2s.
	FlxTween.tween(mmGetBlackOut(), {alpha: 0}, 2, {startDelay: 1, ease: FlxEase.quadInOut});

	// 3401-3405: built hidden and only revealed by case 3.
	mmPowerVignette = new FlxSprite().loadGraphic(Paths.image("modstuff/126"));
	mmPowerVignette.alpha = 0.000001;
	mmPowerVignette.screenCenter();
	mmScreen(mmPowerVignette);
	mmGetWarning();
	if (PlayState.instance.scripts != null)
		PlayState.instance.scripts.set("onTrigger", function(name, v1, v2) {
			if (name == "Power Attack") mmPowerAttack();
		});
}

function destroy() {
	if (mmEstCam != null) {
		FlxG.cameras.remove(mmEstCam, true);
		mmEstCam = null;
	}
}

// PlayState.hx:10856-10898. The chart's Char Attack delegates here.
function mmPowerAttack() {
	marioattack.x = -70;
	marioattack.y = -40;
	// The live dad, not the global: the chart's 52.17s swap (`devilmariotalk`)
	// and 56.33s `devilmario` are long before 14 of the 15 'Char Attack' events
	// (the first is at 32.35s), so the global would hide an object that is no
	// longer in the game and leave the devil Mario on screen through the whole
	// wind-up.
	var dPA = mmDadChar();
	if (dPA != null) dPA.visible = false;
	marioattack.visible = true;
	marioattack.animation.play("prevAttack", true);
	var newzoom = defaultCamZoom + 0.2;
	var camera = PlayState.instance.scripts.get("mmCamera");
	FlxG.sound.play(Paths.sound("psPre"));
	FlxTween.tween(mmPowerVignette, {alpha: 1}, 0.6875, {ease: FlxEase.quadIn});
	if (camera != null) camera.zoom(newzoom, 0.6875, 0, FlxEase.quadIn);
	new FlxTimer().start(0.6875, function(tmr) {
		camGame.shake(0.007, 0.15);
		camHUD.shake(0.007, 0.15);
		FlxG.sound.play(Paths.sound("psAtt"));
		FlxTween.tween(mmPowerVignette, {alpha: 0}, 0.5, {ease: FlxEase.quadOut});
		if (camera != null) camera.zoom(newzoom - 0.2, 0.5, 0, FlxEase.quadOut);
		var dodge = PlayState.instance.scripts.get("mmDodge");
		if (dodge != null && dodge.bot()) dodge.auto();
		else if (dodge == null || !dodge.active())
			FlxTween.tween(PlayState.instance, {health: health - 1}, 0.2, {ease: FlxEase.quadOut});
		marioattack.x = 200;
		marioattack.y = 90;
		marioattack.animation.play("Attack", true);
		new FlxTimer().start(0.5, function(tmr2) {
			marioattack.visible = false;
			// Resolved again - the restore is 1.19s out.
			var dBack = mmDadChar();
			if (dBack != null) dBack.visible = true;
		});
	});
}

// ----------------------------------------------------------------------------
// 'Triggers No Hope' 0-3
// ----------------------------------------------------------------------------
// Sent as 'Triggers Universal' by the chart (the source re-dispatches that to
// 'Triggers <song>' at runtime, 9489-9496), so both names are accepted.
function onEvent(event) {
	if (event.event.name == "Power Attack") {
		mmPowerAttack();
		return;
	}
	if (event.event.name != "Triggers No Hope" && event.event.name != "Triggers Universal") return;
	var trigger = Std.parseInt(event.event.params[0]);
	if (trigger == null || Math.isNaN(trigger)) trigger = 0;
	var value2:String = (event.event.params.length > 1) ? StringTools.trim(Std.string(event.event.params[1])) : "";

	switch (trigger) {
		case 0:
			// 52.17s: dad turns into the talking devil mario and starts talking.
			mmChangeChar(1, "devilmariotalk");
			var d0 = mmDadChar();
			if (d0 != null) d0.playAnim("talk", true);
		case 1:
			// 73.04s: the power-trail appears and dad's idle switches to '-alt'.
			mmAltIdle("-alt");
			mmGetTrail();
		case 2:
			// 89.74s: both are taken away.
			mmAltIdle("");
			if (mmTrail != null) mmTrail.visible = false;
		case 3:
			// 13.57s (value2 '') and 32.35s (value2 'a'): the warning poster
			// flies in from above, scales up and fades out. The empty value2 is
			// the source's *first* one: it vanishes after 3s instead of 1.5s and
			// plays the 'psPre' stinger.
			var w = mmGetWarning();
			if (w == null) return;
			w.screenCenter();
			var oldY:Float = w.y;
			w.y = oldY - 1000;
			w.alpha = 1;
			w.scale.x = 0.1; w.scale.y = 0.1;
			w.visible = true;

			var vanish:Float = 1.5;
			if (value2 == "") {
				vanish = 3;
				FlxG.sound.play(Paths.sound('psPre'));
			}
			FlxTween.tween(w, {y: oldY}, 1, {ease: FlxEase.expoOut});
			FlxTween.tween(w.scale, {x: 0.4, y: 0.4}, 1.2, {ease: FlxEase.expoOut});
			FlxTween.tween(w, {alpha: 0}, 1, {startDelay: vanish});
	}
}
// === end MM stage triggers ===
