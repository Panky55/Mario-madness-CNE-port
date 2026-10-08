

// === MM stage triggers (auto) ===
// 'Triggers Demise' - ported from PlayState.hx (case 'Triggers Demise',
// 11162-11295). Both `demise` and `demise-old` run on this stage, but only the
// regular chart sends these beats (demise-old sends none), and it sends them as
// 'Triggers Universal' - so both event names are accepted.
//
// The camera half (cases 3, 5, 7, 9, 10) is in songs/MMcamera.hx
// (`mmDemiseTrigger`): camGame.zoom at case 3 and 5, camFollowPos at case 5, the
// camHUD fade at case 5/7 and the FOLLOWCHARS/ZOOMCHARS toggles at 9/10.
//
// This stage's backdrop is entirely `FlxBackdrop` in the source (3040-3196: the
// sky, the level and the ground of both the surface and the underground world
// are backdrops, which is why the extractor - which only lifts BGSprite art -
// left the stage with a floor and two foreground layers and nothing else). They
// are rebuilt in postCreate as small tiled groups with the source's own y,
// scroll factors, velocities and spacings (see mmBackdrop).
//
// Stage-level behaviour that comes with the case:
//   3041-3046  `noCount = true` (the READY/SET/GO are dropped), the HUD icons
//              flip (`flipchar` + the demiseport override at 5642-5646:
//              iconP1/iconP2 flipX on, both health bars off) and health starts
//              at 2.
//   4445-4452  `demoFore1..4` and `underdemFore1/2` are added in the *foreground*
//              switch, i.e. after the character groups - the XML puts every
//              sprite below them, so postCreate lifts them to the front.
//   16489      beatHit()'s demFlash pulse (case 11 toggles `demFlash`).
//
// Game-over configuration/preloads live in MMcamera; the default field swap
// is in MMmodfields. `tvEffect` (3043) is ported: this stage sets it without
// `oldTV`, so camGame, camHUD and the camEst layer get VCRMario85 + VCRBorder
// (5647-5663) - see "The TV filter stack" below. Still open: `demColor`'s
// visible effect - it is a makeGraphic curtain added *behind* every backdrop, so
// the beat pulse below is faithful but invisible, as it is in the source.

// ---------------------------------------------------------------------------
// camEst (the transition wipe, 3196-3199)
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
// would put this layer *above* camHUD - over the notes and the HUD, and over the
// wipe's own 3:1 plate - so it is slid back into camHUD's own index here (the
// fleet-wide convention: piracy, forest, nesbeat, meatworld, exeport all place
// their camEst the same way).
// (The list is only half of a camera's place: its own flashSprite in the
// display list is the surface that composites, and `add` leaves a fresh one on
// top of camHUD - which is what `mmSyncCameraOrder` below re-asserts.)
function mmEstBelowHud() {
	if (mmEst == null || mmEstPlaced) return;
	var list = mmCamList();
	if (list == null) {
		if (!mmEstWarned) {
			mmEstWarned = true;
			trace("[MM demiseport] camEst: no FlxG.cameras.list - the wipe stays above camHUD");
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

function mmOverlay(spr) {
	spr.scrollFactor.set(0, 0);
	spr.cameras = [mmGetEst()];
	add(spr);
	return spr;
}

// ---------------------------------------------------------------------------
// The TV filter stack (3043 + 5647-5663)
// ---------------------------------------------------------------------------
// `case 'demiseport'` sets `tvEffect` (3043) without `oldTV`, so the source
// mounts exactly two filters, `[VCRMario85, VCRBorder]`, on camGame, camEst and
// camHUD (5651-5663) while `ClientPrefs.filtro85` is on - which this port takes
// as on, like every other stage script. The camEst layer here is mmGetEst(); the
// pair lives in shaders/vcr85.frag and shaders/vcrBorder.frag, mounted from
// postCreate and driven from postUpdate with `vcr.update(elapsed)`'s own
// accumulation of the time uniform (7241). The border carries no uniform.
var mmVcr = null;            // VCRMario85 -> shaders/vcr85.frag
var mmVcrBorder = null;      // VCRBorder -> shaders/vcrBorder.frag
var mmTvOn:Bool = false;
var mmTvTime:Float = 0;

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

// `addShader` appends, so mounting vcr before border on each camera reproduces
// the source's `[vcr, border]` filter order.
function mmTvStack() {
	if (mmTvOn || !mmShadersAllowed()) return;
	mmTvOn = true;
	mmVcr = new CustomShader("vcr85");
	mmTvMountAll(mmVcr);
	mmVcrBorder = new CustomShader("vcrBorder");
	mmTvMountAll(mmVcrBorder);
}

// `vcr.update(elapsed)` (7241) only accumulates the shader's own time uniform.
function mmTvTick(elapsed) {
	if (mmVcr == null) return;
	mmTvTime += elapsed;
	mmVcr.data.time.value = [mmTvTime];
}

// Codename's `Stage` is not a group (`class Stage extends FlxBasic`), so
// `stage.add`/`stage.remove`/`stage.insert`/`stage.members` do not exist and
// HScript resolves them to null - calling them throws Null Function Pointer and
// aborts the rest of the handler. `Stage.addSprite` instead puts every stage
// sprite straight into the *state's* draw list and `Stage.applyCharStuff` inserts
// each character at its marker, so a bare `members`/`add`/`insert`/`remove` here
// is the state's list and the world layer is the run of sprites below the
// character band.
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

// ---------------------------------------------------------------------------
// Character resolution (see exesequel.hx for the longer note)
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
function mmBfChar() { return mmMem(1); }

// Same swap as data/events/Change Character.hx, for the four pairs the case
// fires itself (mx_demiseUG/bf_demiseUG underground, mx_demise/bf_demise back).
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
// FlxBackdrop stand-ins
// ---------------------------------------------------------------------------
// The source uses `new FlxBackdrop(Paths.image(img), X)` with an optional
// spacing (defaults to the graphic's width) and a `velocity`; the class itself is
// not safe to instantiate from HScript, so each backdrop becomes a handful of
// copies at `i * spacing`, travelling at the source's velocity and wrapped every
// `spacing` px. That is exactly what FlxBackdrop draws (the same graphic tiled at
// `spacing`, offset by the accumulated velocity), minus the tile count.
//
// The direction is Flixel's, not an assumption: `FlxBackdrop.velocity` is plain
// `FlxObject.velocity`, so the sprite's own x/y is what moves, and the tiling is
// derived from it - a positive velocity.x slides the pattern **right**, and the
// negative-y ones slide it up. This was inverted when the backdrops were first
// rebuilt (the copies travelled against the velocity), which no static check can
// see; the source's velocities here are all positive, so all seven were drifting
// the wrong way.
// `tile` is the wrap distance; `width` is only used to know how many copies are
// needed to cover the world window.
var mmBackdrops = [];

// The last sprite of a group, or `fallback` when the group never got built - so
// the insert chain below still has an anchor after a missing image.
function mmLastSpr(g, fallback) {
	if (g == null || g.sprs.length < 1) return fallback;
	return g.sprs[g.sprs.length - 1];
}

// `after` is the world sprite this backdrop must be drawn on top of (the copies
// go in one after the other, so the group stays contiguous).
function mmBackdrop(img:String, y:Float, sfX:Float, sfY:Float, speed:Float, tile:Float, visible:Bool, after) {
	var path = Paths.image(img);
	if (path == null || !Assets.exists(path)) {
		trace("[demiseport] backdrop missing -> " + path);
		return null;
	}
	if (tile <= 0) tile = 2600;
	var n:Int = Std.int(Math.ceil(2600 / tile)) + 1;
	if (n < 2) n = 2;
	var sprs = [];
	var anchor = after;
	for (i in 0...n) {
		var s = new FunkinSprite(i * tile, y);
		s.loadGraphic(path);
		s.scrollFactor.set(sfX, sfY);
		s.updateHitbox();
		s.visible = visible;
		var idx:Int = (anchor != null) ? members.indexOf(anchor) : -1;
		if (idx < 0) mmWorldAdd(s); else insert(idx + 1, s);
		sprs.push(s);
		anchor = s;
	}
	var g = {sprs: sprs, tile: tile, v: speed, t: 0.0};
	mmBackdrops.push(g);
	return g;
}

function mmBackdropVisible(g, on:Bool) {
	if (g == null) return;
	for (s in g.sprs) s.visible = on;
}

function mmBackdropFade(g, a:Float, t:Float, ease) {
	if (g == null) return;
	for (s in g.sprs) {
		if (ease == null) FlxTween.tween(s, {alpha: a}, t);
		else FlxTween.tween(s, {alpha: a}, t, {ease: ease});
	}
}

function update(elapsed:Float) {
	for (b in mmBackdrops) {
		if (b.v == 0) continue;
		// The phase is kept in (-tile, 0] and travels with the velocity (see
		// above): positive slides the pattern right, negative left, and the wrap
		// at either end lands every copy on an identical one's old spot.
		b.t += b.v * elapsed;
		while (b.t <= -b.tile) b.t += b.tile;
		while (b.t > 0) b.t -= b.tile;
		var i:Int = 0;
		for (s in b.sprs) { s.x = i * b.tile + b.t; i += 1; }
	}
}

// ---------------------------------------------------------------------------
// The surface / underground backdrops (3044-3110)
// ---------------------------------------------------------------------------
var mmDemColor = null;
var mmDemBg = null;
var mmDemLevel = null;
var mmDemGround = null;
var mmUnderBg = null;
var mmUnderLevel = null;
var mmUnderGround1 = null;
var mmUnderGround2 = null;
var mmWhenYoureRed = null;
var mmDemiseTran = null;

function mmInsertAfter(anchor, obj) {
	if (obj == null) return;
	var i:Int = (anchor != null) ? members.indexOf(anchor) : -1;
	if (i < 0) { mmWorldAdd(obj); return; }
	insert(i + 1, obj);
}

// 3050-3053: a full-screen white graphic whose `color` is BLACK - a curtain at
// the very back of the draw list.
function mmGetDemColor() {
	if (mmDemColor == null) {
		mmDemColor = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		mmDemColor.scale.set(10, 10); // source's setGraphicSize(width * 10)
		mmDemColor.scrollFactor.set(0, 0);
		insert(0, mmDemColor);
	}
	return mmDemColor;
}

// 3115-3120: the red wash under the cutscene, after the underground roof.
function mmGetWhenYoureRed() {
	if (mmWhenYoureRed == null) {
		mmWhenYoureRed = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xFFD10000);
		mmWhenYoureRed.scale.set(10, 10);
		mmWhenYoureRed.alpha = 0;
		mmInsertAfter(underroofdemise, mmWhenYoureRed);
	}
	return mmWhenYoureRed;
}

// 3196-3200: the wipe, on camEst, three times as wide as it is tall.
function mmGetDemiseTran() {
	if (mmDemiseTran == null) {
		mmDemiseTran = new FunkinSprite(-1600, 0);
		mmDemiseTran.loadGraphic(Paths.image("mario/MX/demise/1/transition"));
		mmDemiseTran.scale.set(3, 1);
		mmOverlay(mmDemiseTran);
	}
	return mmDemiseTran;
}

// The backdrops go in one by one, each on top of the previous one, so the world
// layer ends up in the source's order: demColor, dembg, demLevel, floordemise
// (XML), demGround, underdembg, underdemLevel, underdemGround1, underdemGround2,
// underfloordemise (XML), underroofdemise (XML), whenyourered, then the four
// cutscene bodies and gordobondiola (XML).
function mmBuildBackdrops() {
	mmGetDemColor();
	mmDemBg = mmBackdrop("mario/MX/demise/1/Demise_BG_BG2", -500, 0.3, 0.3, 100, 0, true, mmDemColor);
	mmDemLevel = mmBackdrop("mario/MX/demise/1/Demise_BG_BGCaca", -300, 0.5, 0.5, 250, 0, true, mmLastSpr(mmDemBg, mmDemColor));
	mmDemGround = mmBackdrop("mario/MX/demise/1/Demise_BG_BG1", -70, 0.9, 0.9, 3200, 800, true, floordemise);
	mmUnderBg = mmBackdrop("mario/MX/demise/2/Demise_BG2_Mountains.png", -500, 0.3, 0.3, 100, 0, false, mmLastSpr(mmDemGround, floordemise));
	mmUnderLevel = mmBackdrop("mario/MX/demise/2/Demise_BG2_BGLower.png", -1400, 0.5, 0.5, 250, 0, false, mmLastSpr(mmUnderBg, floordemise));
	mmUnderGround1 = mmBackdrop("mario/MX/demise/2/Demise_BG2_BG1", -800, 0.9, 0.9, 3200, 6000, false, mmLastSpr(mmUnderLevel, floordemise));
	mmUnderGround2 = mmBackdrop("mario/MX/demise/2/Demise_BG2_BG2", -800, 0.9, 0.9, 3200, 4000, false, mmLastSpr(mmUnderGround1, floordemise));
	mmGetWhenYoureRed();
	mmGetDemiseTran();
}

// ---------------------------------------------------------------------------
// The foreground cars (16819-16871)
// ---------------------------------------------------------------------------
// The source picks a random 1..4 (1..2 underground), slides that sprite across,
// and half a second later picks again - `Reflect.getProperty(this, under +
// 'demFore' + coso)`, which here is an index into the two lists.
var mmFore = [];
var mmUnderFore = [];

function mmStartFore(lastSprite:Int) {
	var coso:Int = FlxG.random.int(1, 4);
	var under:Bool = false;
	if (underfloordemise != null && underfloordemise.visible) {
		coso = FlxG.random.int(1, 2);
		under = true;
	}
	if (coso == lastSprite) {
		mmStartFore(coso);
		return;
	}
	var list = under ? mmUnderFore : mmFore;
	var s = (coso - 1 < list.length) ? list[coso - 1] : null;
	if (s == null) return;

	if (FlxG.random.bool(50)) {
		if (!under && coso == 3) {
			s.x = -1800;
			FlxTween.tween(s, {x: 6800}, 1.3);
		} else {
			s.x = -3800;
			FlxTween.tween(s, {x: 3800}, 1.3);
			if (under)
				new FlxTimer().start(1, function(tmr) { mmStartFore(coso); });
		}
		if (!under)
			new FlxTimer().start(0.5, function(tmr) { mmStartFore(coso); });
	} else {
		new FlxTimer().start(0.5, function(tmr) { mmStartFore(lastSprite); });
	}
}

// ---------------------------------------------------------------------------
// The underground swap (case 1 and case 2)
// ---------------------------------------------------------------------------
function mmDemWorld(under:Bool) {
	if (under) {
		mmChangeChar(1, "mx_demiseUG");
		mmChangeChar(0, "bf_demiseUG");
	} else {
		mmChangeChar(1, "mx_demise");
		mmChangeChar(0, "bf_demise");
	}
	mmBackdropVisible(mmUnderBg, under);
	mmBackdropVisible(mmUnderLevel, under);
	mmBackdropVisible(mmUnderGround1, under);
	mmBackdropVisible(mmUnderGround2, under);
	if (underfloordemise != null) underfloordemise.visible = under;
	if (underroofdemise != null) underroofdemise.visible = under;
	mmBackdropVisible(mmDemBg, !under);
	mmBackdropVisible(mmDemLevel, !under);
	if (floordemise != null) floordemise.visible = !under;
	mmBackdropVisible(mmDemGround, !under);
	for (s in mmFore) if (s != null) s.visible = !under;
}

// ---------------------------------------------------------------------------
// Load
// ---------------------------------------------------------------------------
function onCountdown(event) {
	// `noCount = true` (3041).
	event.cancelled = true;
}

function postCreate() {
	// PlayState.hx:3044-3046: hidden GF and a full opening health bar.
	if (gf != null) gf.visible = false;
	health = 2;
	// 5642-5646: `flipchar` plus the demiseport override - both icons mirrored,
	// both health bars back to normal.
	if (iconP1 != null) iconP1.flipX = true;
	if (iconP2 != null) iconP2.flipX = true;
	if (healthBar != null) healthBar.flipX = false;
	if (healthBarBG != null) healthBarBG.flipX = false;

	// 4445-4452: the foreground switch adds these after the character groups, so
	// they belong in front of the fighters. The lift is a splice plus an append,
	// not a bare remove + re-add: `remove(x)` only nulls the slot and `add(x)`
	// re-fills the first null slot of the list, which is that same one.
	for (s in [demFore1, demFore2, demFore3, demFore4, underdemFore1, underdemFore2]) {
		if (s == null) continue;
		remove(s, true);
		insert(members.length, s);
	}
	mmFore = [demFore1, demFore2, demFore3, demFore4];
	mmUnderFore = [underdemFore1, underdemFore2];

	mmBuildBackdrops();

	// The source's cutscene sprites 2..4 are placed relative to demcut1
	// (`demcut1.x + 650` and friends), which the extractor could not fold - the
	// XML has them all at (0, 0). Put them where the source puts them.
	if (demcut2 != null) { demcut2.x = -450; demcut2.y = -250; }
	if (demcut3 != null) { demcut3.x = 0; demcut3.y = 120; }
	if (demcut4 != null) { demcut4.x = -830; demcut4.y = -220; }

	mmStartFore(1);

	// 5647-5663: the filters are mounted at create, before the countdown runs.
	mmTvStack();
}

// PlayState.hx:7705-7707, the Demise-specific flipchar icon layout.
function postUpdate(elapsed) {
	// The VCR/border stack's time uniform (`vcr.update(elapsed)`), before the
	// HUD early-return below - the filters do not depend on the icons.
	mmTvTick(elapsed);
	if (healthBar == null || iconP1 == null || iconP2 == null) return;
	iconP2.x = healthBar.x + healthBar.width - 40;
	iconP1.x = healthBar.x + healthBar.width * (1 - health / 2) - 35;
}

// 16489-16493: the flash pulse, one crochet long, on every beat while case 11
// has `demFlash` on.
var mmDemFlash:Bool = false;

function beatHit(curBeat:Int) {
	if (!mmDemFlash) return;
	var c = mmGetDemColor();
	FlxTween.color(c, 1 / (Conductor.bpm / 60), 0xFF4D0000, FlxColor.BLACK);
}

// ---------------------------------------------------------------------------
// 'Triggers Demise' 0-11
// ---------------------------------------------------------------------------
function onEvent(event) {
	if (event.event.name != "Triggers Demise" && event.event.name != "Triggers Universal") return;
	var trigger:Float = Std.parseFloat(Std.string(event.event.params[0]));
	if (trigger == null || Math.isNaN(trigger)) trigger = 0;

	switch (trigger) {
		case 0:
			// 11167: the 'HA!' that flies off to the left.
			var hatext = new FlxText(900, -270, 600, "HA!", 120);
			hatext.setFormat(Paths.font("mariones.ttf"), 120, FlxColor.WHITE, "left");
			add(hatext);
			hatext.angle = FlxG.random.float(-20, 20);
			FlxTween.tween(hatext, {x: 500, y: (hatext.angle * 20) - 270, alpha: 0}, 1, {ease: FlxEase.expoOut, onComplete: function(twn) {
				remove(hatext);
			}});

		case 1:
			// 11177: wipe to the underground, and two crochets later the swap.
			var tr1 = mmGetDemiseTran();
			tr1.x = -1600;
			FlxTween.tween(tr1, {x: 2600}, 1.4);
			new FlxTimer().start(2 * (1 / (Conductor.bpm / 60)), function(tmr) { mmDemWorld(true); });

		case 2:
			// 11204: the same wipe, back to the surface.
			var tr2 = mmGetDemiseTran();
			tr2.x = -1600;
			FlxTween.tween(tr2, {x: 2600}, 1.4);
			new FlxTimer().start(2 * (1 / (Conductor.bpm / 60)), function(tmr) { mmDemWorld(false); });

		case 3:
			// 11232: everything goes dark red and the fighters turn to
			// silhouettes; the 20.21s zoom to 0.4 is MMcamera's.
			FlxTween.tween(mmGetWhenYoureRed(), {alpha: 1}, 1, {ease: FlxEase.quadOut});
			if (underdemFore1 != null) FlxTween.tween(underdemFore1, {alpha: 0}, 1, {ease: FlxEase.quadOut});
			if (underdemFore2 != null) FlxTween.tween(underdemFore2, {alpha: 0}, 1, {ease: FlxEase.quadOut});
			var b3 = mmBfChar();
			if (b3 != null) FlxTween.color(b3, 1, FlxColor.WHITE, FlxColor.BLACK, {ease: FlxEase.quadOut});
			var d3 = mmDadChar();
			if (d3 != null) FlxTween.color(d3, 1, FlxColor.WHITE, FlxColor.BLACK, {ease: FlxEase.quadOut});

		case 4:
			// 11244: and back.
			FlxTween.tween(mmGetWhenYoureRed(), {alpha: 0}, 2, {ease: FlxEase.quadInOut});
			if (underdemFore1 != null) FlxTween.tween(underdemFore1, {alpha: 1}, 2, {ease: FlxEase.quadOut});
			if (underdemFore2 != null) FlxTween.tween(underdemFore2, {alpha: 1}, 2, {ease: FlxEase.quadOut});
			var b4 = mmBfChar();
			if (b4 != null) FlxTween.color(b4, 2, FlxColor.BLACK, FlxColor.WHITE, {ease: FlxEase.quadInOut});
			var d4 = mmDadChar();
			if (d4 != null) FlxTween.color(d4, 2, FlxColor.BLACK, FlxColor.WHITE, {ease: FlxEase.quadInOut});

		case 5:
			// 11254: the cutscene. The fighters go, the four cutscene bodies
			// appear, the floor/ground fade out and the camera lunges in
			// (MMcamera owns the zoom and the camFollowPos tweens).
			var b5 = mmBfChar();
			if (b5 != null) b5.alpha = 0;
			var d5 = mmDadChar();
			if (d5 != null) d5.alpha = 0;
			for (s in [demcut1, demcut2, demcut3, demcut4]) {
				if (s == null) continue;
				s.visible = true;
				s.animation.play("idle", true);
			}
			if (floordemise != null) FlxTween.tween(floordemise, {alpha: 0}, 0.5);
			mmBackdropFade(mmDemGround, 0, 0.5, null);
			FlxTween.tween(camHUD, {alpha: 0.1}, 0.5);

		case 6:
			if (floordemise != null) FlxTween.tween(floordemise, {alpha: 1}, 1);
			mmBackdropFade(mmDemGround, 1, 1, null);

		case 7:
			// 11284: MX drops in and the cutscene bodies go grey.
			if (gordobondiola != null) FlxTween.tween(gordobondiola, {x: 1000, y: -900}, 1.85, {ease: FlxEase.expoIn});
			for (s in [demcut1, demcut2, demcut3, demcut4])
				if (s != null) FlxTween.color(s, 0.4, FlxColor.WHITE, 0xFF5E5E5E);
			FlxTween.tween(camHUD, {alpha: 1}, 0.5);

		case 8:
			for (s in [demcut1, demcut2, demcut3, demcut4])
				if (s != null) FlxTween.color(s, 0.4, 0xFF5E5E5E, FlxColor.WHITE);

		case 9:
			// FOLLOWCHARS = !FOLLOWCHARS - the camera side.
			break;

		case 10:
			// ZOOMCHARS = !ZOOMCHARS - the camera side.
			break;

		case 11:
			mmDemFlash = !mmDemFlash;
	}
}
// === end MM stage triggers ===
