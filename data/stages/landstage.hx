

// === MM stage triggers (auto) ===
// 'Triggers Golden Land' - ported from PlayState.hx (case 'Triggers Golden
// Land', 10651-10729), the stage's own create branch (1245-1371) and its shared
// 4657-4669 block. quitarvida drains once per beat, as in the source's beatHit
// switch, rather than once per rendered frame. The stage's own opening blackout
// (6361-6368) is wired at the bottom of the file.
//
// The stage carries **two** songs with two different stages under one name:
// 'Golden Land' builds the EXE2 'bad'/'normal' art plus a TVStatic+VCRBorder
// filter pair on camGame (1309-1371), while 'Golden Land Old' builds the
// 'mario/EXE2/old/*' art instead (1249-1308) - and the extractor only ever
// lifted the modern branch. The port hides the modern layers for the old song
// and rebuilds the old ones here, the way betamansion.hx does for 'Alone Old'.
// `estaland` (4657-4669) belongs to neither branch: it is a camEst overlay both
// songs get, shown by case 0.
// Camera: this stage's beats move the camera (`camFollowPos` tweens, camGame
// zoom, DAD_ZOOM), and data/songs/MMcamera.hx owns camFollow/defaultCamZoom -
// it writes them every frame. Every camera call below therefore goes through the
// api it publishes through the engine's ScriptPack (`lock`/`zoom`/`zoomFor`),
// because a direct write is overwritten on the same frame.
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

// `noCount = true` (1247): the source never builds its 3-2-1-GO sprites for this
// stage, so the engine's are dropped here (PlayState.hx builds them in the
// cancellable `onCountdown`; the same thing hatebg.hx/wetworld.hx do).
function onCountdown(event) {
	event.cancelled = true;
}

// `quitarvida` (PlayState.hx:207) - the Golden Land life drain.
var mmQuitarVida = false;
function beatHit(curBeat) {
	if (mmQuitarVida && health >= 0.1) health -= 0.035; // 16332-16336, beatHit, not update
}

var mmBlackBar:FlxSprite;
function mmGetBlackBar():FlxSprite {
	if (mmBlackBar == null) {
		mmBlackBar = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		mmBlackBar.scrollFactor.set();
		mmBlackBar.alpha = 0;
		add(mmBlackBar);
	}
	return mmBlackBar;
}

// ---------------------------------------------------------------------------
// The opening (6361-6368)
// ---------------------------------------------------------------------------
// Golden Land is a `noCount` stage (1247), so the countdown branch that would
// have shown READY/SET/GO replaced itself with this: a black plate on
// **camOther** (above camHUD, so it covers the HUD too) fading out over one
// second. It is a *fresh* sprite per play, separate from the trigger group's
// `blackBarThingie` above - the source creates it there and never references it
// again, so the two must not share one sprite (the chart's blackouts would then
// start from the wrong alpha). Codename has no camOther, so the port adds a
// camera of its own last in `FlxG.cameras.list` - the shape piracy.hx's
// `drawspot` layer uses - which composites above camHUD.
var mmOther:FlxCamera = null;

function mmGetOther():FlxCamera {
	if (mmOther == null) {
		mmOther = new FlxCamera(0, 0, FlxG.width, FlxG.height);
		mmOther.bgColor = FlxColor.TRANSPARENT;
		mmOther.zoom = 1;
		FlxG.cameras.add(mmOther, false); // defaultDraw=false -> world not redrawn
	}
	return mmOther;
}

var mmOpenBlack = null;
var mmOpenDone:Bool = false;

function mmLandOpening() {
	if (mmOpenDone) return;
	mmOpenDone = true;

	mmOpenBlack = new FlxSprite(0, 0);
	mmOpenBlack.makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
	mmOpenBlack.scale.set(10, 10);
	mmOpenBlack.scrollFactor.set(0, 0);
	mmOpenBlack.alpha = 1;
	mmOpenBlack.cameras = [mmGetOther()];
	add(mmOpenBlack);

	FlxTween.tween(mmOpenBlack, {alpha: 0}, 1, {ease: FlxEase.quadInOut});
}

function onSongStart() {
	mmLandOpening();
}

// ---------------------------------------------------------------------------
// The stage's two variants (1245-1371) and the shared estaland overlay
// ---------------------------------------------------------------------------
// Psych's camEst is a bare camera added right after camGame: composited above
// the world and the fighters and below camHUD. Codename has only camGame/camHUD,
// so the port adds one of its own (`defaultDraw = false`) and slides it in at
// camHUD's index - the shape betamansion.hx/warioworld.hx use.
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
		FlxG.cameras.add(mmEstCam, false);
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
			trace("[MM landstage] camEst: no FlxG.cameras.list - estaland stays above camHUD");
		}
		return;
	}
	list.remove(mmEstCam);
	var at:Int = (camHUD != null) ? list.indexOf(camHUD) : -1;
	if (at < 0) {
		list.push(mmEstCam);
		return;
	}
	list.insert(at, mmEstCam);
	mmEstPlaced = true;
}

// 4657-4669: `estaland`, the demon-king overlay - a screen-centred 2x atlas at
// alpha 0.2 on camEst, hidden until case 0 shows it. Both songs get it.
var mmEstand = null;
function mmGetEstand() {
	if (mmEstand == null) {
		mmEstand = new FunkinSprite(0, 0);
		mmEstand.frames = Paths.getSparrowAtlas("modstuff/Mario_Phase2_Background_Assets_Overlay");
		mmEstand.animation.addByPrefix("idle", "aeiuo instancia 1", 12);
		mmEstand.animation.play("idle");
		mmEstand.antialiasing = false;
		mmEstand.scale.set(2, 2);
		mmEstand.updateHitbox();
		mmEstand.alpha = 0.2;
		mmEstand.visible = false;
		mmEstand.cameras = [mmEst()];
		mmEstand.screenCenter();
		add(mmEstand);
	}
	return mmEstand;
}

// 1309-1316: `staticShader = new TVStatic()` + a VCRBorder, both mounted on
// camGame for the modern song only, with `strengthMulti = 0.5` and
// `imtoolazytonamethis = 0.3`. The shaders are additive in `addShader` order, the
// source's filter order is [static, border]. `iTime` is fed from postUpdate the
// way the source's `staticShader.update(elapsed)` is (7289-7290).
var mmStaticShader = null;
var mmStaticBorder = null;
var mmStaticTime:Float = 0;
var mmStaticOn:Bool = false;

// With the engine's "Gameplay Shaders" option off, `new CustomShader(...)` stays
// null and its setters no-op (the same read virtual.hx/warioworld.hx make).
function mmShadersAllowed():Bool {
	if (Options == null) return true;
	if (!Reflect.hasField(Options, "gameplayShaders")) return true;
	return Options.gameplayShaders;
}

function mmIsLandOld():Bool {
	var meta = (PlayState.SONG != null) ? PlayState.SONG.meta : null;
	if (meta == null) return false;
	return StringTools.trim(Std.string(meta.displayName)) == "Golden Land Old";
}

function mmMountStatic() {
	if (mmStaticOn || mmIsLandOld() || !mmShadersAllowed()) return;
	mmStaticOn = true;
	mmStaticShader = new CustomShader("tvStatic");
	if (mmStaticShader != null) {
		mmStaticShader.data.strengthMulti.value = [0.5];
		mmStaticShader.data.imtoolazytonamethis.value = [0.3];
		if (camGame != null) camGame.addShader(mmStaticShader);
	}
	mmStaticBorder = new CustomShader("vcrBorder");
	if (mmStaticBorder != null && camGame != null) camGame.addShader(mmStaticBorder);
}

// ---------------------------------------------------------------------------
// 'Golden Land Old' (1249-1308)
// ---------------------------------------------------------------------------
// The old branch's seven plates, all `mario/EXE2/old/*`, all below the
// characters except Nubes4 (the source's foreground `add(bricksland)`,
// 4374-4376); the three demon layers and the GF start at alpha 0 and case 0
// fades them in. `gfGroup.visible = false` (1259) - the GF is off stage for the
// whole song, its cut-out `gfwasTaken` is the prop that appears instead.
var mmOldNubes = null;
var mmOldNubes2 = null;
var mmOldNubes3 = null;
var mmOldNubes4 = null;
var mmOldStatic = null;
var mmOldWater = null;
var mmOldGf = null;
var mmOldFloor = null;

function mmWorldTop():Int {
	var st = PlayState.instance;
	if (st == null || stage == null) return -1;
	var poses = Reflect.field(stage, "characterPoses");
	var gfPos = (poses != null) ? poses.get("girlfriend") : null;
	if (gfPos == null) return -1;
	var i:Int = st.members.indexOf(gfPos);
	return (i >= 0) ? i - 1 : -1;
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

function mmOldPlate(path:String, x:Float, y:Float, sx:Float, sy:Float, scale:Float, alpha:Float) {
	var s = new FunkinSprite(x, y);
	s.loadGraphic(Paths.image(path));
	s.scrollFactor.set(sx, sy);
	s.scale.set(scale, scale);
	s.updateHitbox();
	s.antialiasing = false; // the old branch sets false on every plate
	s.alpha = alpha;
	return s;
}

function mmBuildOldStage() {
	if (mmOldNubes != null) return;

	// The XML only carries the modern art.
	if (bgland != null) bgland.visible = false;
	if (bgwater != null) bgwater.visible = false;
	if (floor != null) floor.visible = false;
	if (bglandEXE != null) bglandEXE.visible = false;
	if (bgwaterEXE != null) bgwaterEXE.visible = false;
	if (floorEXE != null) floorEXE.visible = false;
	if (bricksland != null) bricksland.visible = false;
	if (brickslandEXE != null) brickslandEXE.visible = false;
	if (bgfeo != null) bgfeo.visible = false;
	if (gf != null) gf.visible = false;

	// 1261-1305, at the source's own scales (3x on the Nubes/weaspuki plates,
	// 2.5x on the static, 2.8x on the GF) and scroll factors.
	mmOldNubes = mmOldPlate("mario/EXE2/old/Nubes", 400, 300, 0.5, 0.5, 3, 1);
	mmOldNubes2 = mmOldPlate("mario/EXE2/old/Nubes2", 400, 700, 0.7, 0.7, 3, 1);
	mmOldNubes3 = mmOldPlate("mario/EXE2/old/Nubes3", 400, 800, 1, 1, 3, 1);
	mmOldStatic = mmOldPlate("mario/EXE2/old/Mario_Phase2_Background_Assets_Static", 200, 300, 0.6, 0.6, 2.5, 0);
	mmOldWater = mmOldPlate("mario/EXE2/old/weaspuki2", 400, 700, 0.7, 0.7, 3, 0);
	mmOldGf = mmOldPlate("mario/EXE2/old/Mario_Phase2_GF_Assets_v1", 600, 1000, 0.9, 0.9, 2.8, 0);
	mmOldFloor = mmOldPlate("mario/EXE2/old/weaspuki1", 400, 800, 1, 1, 3, 0);
	mmOldNubes4 = mmOldPlate("mario/EXE2/old/Nubes4", 600, 200, 0.9, 0.9, 3, 1);

	// Back-to-front at the world top leaves them in the source's order (each
	// insert lands above the previous one).
	for (s in [mmOldFloor, mmOldGf, mmOldWater, mmOldStatic, mmOldNubes3, mmOldNubes2, mmOldNubes]) {
		var i = mmWorldTop();
		if (i >= 0) insert(i, s); else add(s);
	}
	add(mmOldNubes4); // 4374-4376: the foreground switch, in front of the fighters

	// 1254-1257: the old song's camera row - BF_CAM_Y is 450 here, where the
	// modern table (songs/MMcamera.hx) carries 500. It is re-sent once from
	// postUpdate as well: `mmCam` is a no-op until MMcamera's own postCreate has
	// published its api, nothing orders the two scripts' postCreate calls, and if
	// this one ran first the old song would keep the modern row all song.
	mmCam("setCam", ["dad", 420, 450, 1]);
	mmCam("setCam", ["bf", 720, 450, 1]);
	mmOldCamPending = true;
}

var mmOldCamPending:Bool = false;

function mmOldCamApply() {
	var ps = PlayState.instance;
	if (ps == null || ps.scripts == null || ps.scripts.get("mmCamera") == null) return;
	mmCam("setCam", ["dad", 420, 450, 1]);
	mmCam("setCam", ["bf", 720, 450, 1]);
	mmOldCamPending = false;
}

function postCreate() {
	if (mmIsLandOld()) mmBuildOldStage();
	mmGetEstand();
	mmMountStatic();

	// 1336: the stage branch adds `gfGroup` *inside* its art build, right between
	// `bgwaterEXE` and `floorEXE` - i.e. behind the whole backdrop (the normal
	// trio the source adds after her covers the screen, so she is invisible
	// until case 0 hides `landbg` at 44.92s, the moment she is revealed sunk in
	// the pit; the modern chart sends only that one trigger). This engine adds
	// the characters on top of the stage instead, which left her standing in
	// front of the normal art for the whole first act, so put her back in the
	// source's slot. The old song hides her outright (`gfGroup.visible = false`
	// on the other branch), so this only matters for the modern one.
	if (gf != null && floorEXE != null) {
		remove(gf, true);
		var at:Int = members.indexOf(floorEXE);
		if (at >= 0) insert(at, gf); else add(gf);
	}

	// 4374-4376: the foreground switch re-adds both brick layers after the
	// fighters. `bricksland` (normal/1) is the modern song's and `brickslandEXE`
	// (bad/1) swaps in at case 0; the old song hides both in `mmBuildOldStage`
	// and appends its own Nubes4 instead.
	mmToFront(bricksland);
	mmToFront(brickslandEXE);
}

function postUpdate(elapsed:Float) {
	if (mmOldCamPending) mmOldCamApply();
	if (mmStaticShader == null) return;
	mmStaticTime += elapsed;
	mmStaticShader.data.iTime.value = [mmStaticTime];
}

function onEvent(event) {
	if (event.event.name != "Triggers Golden Land" && event.event.name != "Triggers Universal") return;
	var trigger = Std.parseInt(event.event.params[0]);
	if (trigger == null || Math.isNaN(trigger)) trigger = 0;
	var black = Std.parseFloat(event.event.params[1]);
	if (black == null || Math.isNaN(black)) black = 1;

	switch (trigger) {
		case 0:
			// 10665/10702: `estaland.visible = true` is neither song's branch -
			// both show the overlay here.
			mmGetEstand().visible = true;
			if (mmIsLandOld()) {
				// 10695-10704: the demon layers fade in over the old art. The
				// source's `tiempoN` is 0.001 with `ClientPrefs.flashing` on and 1s
				// with it off; the port takes it as on.
				if (mmOldStatic != null) FlxTween.tween(mmOldStatic, {alpha: 1}, 0.001, {ease: FlxEase.quadInOut});
				if (mmOldWater != null) FlxTween.tween(mmOldWater, {alpha: 1}, 0.001, {ease: FlxEase.quadInOut});
				if (mmOldFloor != null) FlxTween.tween(mmOldFloor, {alpha: 1}, 0.001, {ease: FlxEase.quadInOut});
				if (mmOldGf != null) FlxTween.tween(mmOldGf, {alpha: 1}, 0.001, {ease: FlxEase.quadInOut});
			} else {
				// 10659-10669: `landbg.visible = false` hides the whole normal
				// group - all three of its plates - and the two normal bricks swap
				// for the EXE set.
				bgland.visible = false;
				bgwater.visible = false;
				floor.visible = false;
				bricksland.visible = false;
				brickslandEXE.visible = true;
				if (gf != null) {
					gf.playAnim("idle", true);
					gf.y += 450;
				}
			}
		case 1:
			if (mmIsLandOld()) {
				// 10705-10708: the old song drops the GF cut-out instead of the
				// GF herself.
				if (mmOldGf != null) FlxTween.tween(mmOldGf, {y: 450}, 1, {ease: FlxEase.quadOut});
			} else {
				camGame.shake(0.05, 0.15);
				if (gf != null) FlxTween.tween(gf, {y: gf.y - 450}, 1, {ease: FlxEase.quadOut});
			}
		case 2:
			FlxTween.tween(mmGetBlackBar(), {alpha: black}, 0.5, {ease: FlxEase.quadInOut});
		case 5:
			FlxTween.tween(camHUD, {alpha: 0.1}, 0.5);
		case 3:
			// 10706-10707: `quitarvida = true` - the life drain the source runs in
			// beatHit() (`case 'landstage': if (quitarvida && health >= 0.1)
			// health -= 0.035;`, 16332-16336): once per beat, not per frame.
			mmQuitarVida = true;
		case 4:
			mmQuitarVida = false;
		case 6:
			// 10721-10722: `tween(camGame, {zoom: 1.3}, 1.34, expoIn)`. Raw camGame
			// writes are fought by MMcamera's own zoom handling, so the zoom goes
			// through its api (`zoom`) like every other staged camera move.
			mmCam("zoom", [1.3, 1.34, 0, FlxEase.expoIn]);
		case 7:
			// 10714-10727. The source sets DAD_X/DAD_Y/DAD_ZOOM (the *character*
			// group's create-time values - 119-132, 980-1003 - of which only
			// DAD_ZOOM is still read at runtime, 7329) and then tweens
			// **camFollowPos** to (380, 350) over 1.34s cubeOut. That tween is the
			// camera move, so it is a `lock` here; writing camFollow directly (what
			// this used to do) is overwritten by MMcamera on the same frame and the
			// pan never happened.
			mmCam("zoomFor", ["dad", 0.9]);
			mmCam("lock", [380, 350, 1.34, FlxEase.cubeOut]);
			camGame.shake(0.008, 0.4);
			dad.playAnim("laugh", true);
			FlxTween.tween(camHUD, {alpha: 0.4}, 0.2);
			mmCam("zoom", [0.9, 0.2, 0, FlxEase.cubeOut]);
		case 8:
			// 10723-10725: DAD_ZOOM = 0.8 and the HUD comes back. The DAD_X/DAD_Y
			// writes next to it are dead in the fork (the group was built at create
			// time), and there is no camFollowPos tween here, so the camera returns
			// to the section on its own once case 7's lock expires.
			mmCam("zoomFor", ["dad", 0.8]);
			FlxTween.tween(camHUD, {alpha: 1}, 0.2);
	}
}
// === end MM stage triggers ===
