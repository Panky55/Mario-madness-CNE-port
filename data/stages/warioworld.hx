

// === MM stage triggers (auto) ===
// 'Triggers Apparition' - ported from PlayState.hx (case 'Triggers Apparition').
//
// The stage also carries the source's TV filter stack (`tvEffect`/`oldTV`,
// 1751-1753) - see the section below.
//
// ---------------------------------------------------------------------------
// The TV shader stack (1751-1753, 5647-5690)
// ---------------------------------------------------------------------------
// `case 'warioworld'` sets *both* `tvEffect` and `oldTV`, but only when the song
// is neither 'Apparition Old' nor 'Forbidden Star' (1749-1753) - the two legacy
// songs keep the plain stage. Where it is set, the song runs through the source's
// VCR stack: VCRMario85 (the tape wobble, the +/-0.003 RGB split and the
// 800-cycle scanline) and VCRBorder (the curved, vignetted bezel) on
// camGame/camHUD, plus OldTVShader (the rolling bands, the 16-direction blur,
// the black dropouts, the per-pixel static and the white sploches) between them
// because `oldTV` is set as well. The three are shaders/vcr85.frag,
// shaders/oldTv.frag and shaders/vcrBorder.frag, mounted in postCreate by
// mmTvStack and driven from postUpdate with the same per-second `time`/`iTime`
// the source feeds `vcr.update()` / `oldFX.update()` (7241/7246) - the wiring
// promoshow.hx uses. OldTV keeps the source's integer PRNG wherever the compiler
// takes GLSL 1.30+ and its iTime starts from a process-time seed (the source's
// Timer.stamp()); only the camera-sampling adaptation and the sub-1.30 float
// hash fallback remain - see oldTv.frag's header.
//
// The source also filters its camEst layer, which on this stage holds exactly
// one sprite - `fogbad`, the Wario apparition overlay (5538-5546) - so the port
// builds the same camEst camera the other stages use and mounts the three
// filters on it too (5647-5663 filters camGame, camEst and camHUD alike).
//
// `BrightnessContrastShader` (contrastFX) is the one filter of the block that is
// left out, exactly as in promoshow.hx/endstage.hx: nothing on this stage writes
// its uniforms, and its defaults are an identity pass.
var mmVcr = null;            // VCRMario85 -> shaders/vcr85.frag
var mmOldFx = null;          // OldTVShader -> shaders/oldTv.frag
var mmVcrBorder = null;      // VCRBorder -> shaders/vcrBorder.frag
var mmVcrTime:Float = 0;     // VCRMario85 `time` - the source starts it at 0
var mmOldTime:Float = 0;     // OldTVShader `iTime` - seeded at mount (mmTvStack)
var mmTvOn:Bool = false;

// 1749-1753: the stack is set for every song on this stage *except* the two
// legacy ones. `PlayState.SONG.meta.displayName` is what a script can see (the
// same test racing.hx / exeport.hx make).
function mmWarioTvOn():Bool {
	var meta = (PlayState.SONG != null) ? PlayState.SONG.meta : null;
	if (meta == null) return true;
	var name = StringTools.trim(Std.string(meta.displayName));
	return name != "Apparition Old" && name != "Forbidden Star";
}

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
	var est = mmEst();
	if (est != null) est.addShader(s);
}

// The source's filter order is `[vcr, oldFX, border]` (5676-5682); `addShader`
// appends, so mounting in that order reproduces it. Each shader mounts as soon
// as it is built, so a compile failure in one cannot cost the other two their
// mount.
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
	if (mmTvOn || !mmWarioTvOn() || !mmShadersAllowed()) return;
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
// camEst (5538-5546)
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
			trace("[MM warioworld] camEst: no FlxG.cameras.list - the overlay stays above camHUD");
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

// 5538-5546: `fogbad`, a sparrow atlas ('modstuff/Wario_Apparition_Overlay_v1')
// whose 'idle' loop is the source's 'WarioOverlay', screen-centred on camEst at
// alpha 0. It is the stage's red-tint companion: 'Triggers Apparition' 1 fades it
// to 0.6 over the same ten seconds it tints the cast, and 2 takes it back down.
var mmFogBad = null;

function mmGetFogBad() {
	if (mmFogBad == null) {
		mmFogBad = new FlxSprite(0, 0);
		mmFogBad.frames = Paths.getSparrowAtlas('modstuff/Wario_Apparition_Overlay_v1');
		mmFogBad.animation.addByPrefix('idle', 'WarioOverlay', 24);
		mmFogBad.antialiasing = true; // ClientPrefs.globalAntialiasing, taken as on
		mmFogBad.cameras = [mmEst()];
		mmFogBad.alpha = 0;
		mmFogBad.animation.play('idle');
		mmFogBad.screenCenter();
		add(mmFogBad);
	}
	return mmFogBad;
}

// 4553-4558, the stage's own create block: Wario arrives as a speck in the dark.
// `dad.alpha = 0` and `dad.scale` 0.1 are load-bearing - case 0 below grows him
// (`tween(dad, {alpha: 1})` plus `dad.scale -> 1.2`), which only reads right from
// these values, and without them he stands full-size from the first frame. GF sits
// the song out (`gf.visible = false`, which the source never undoes).
// The fork's `remove(x); add(x)` idiom, done the way this engine needs it: a
// bare `remove` only nulls the slot and `add` re-fills that same slot, so the
// splice is what actually moves the sprite.
function mmToFront(obj) {
	if (obj == null) return obj;
	remove(obj, true);
	insert(members.length, obj);
	return obj;
}

function postCreate() {
	if (gf != null) gf.visible = false;
	if (dad != null) {
		dad.alpha = 0;
		// Fields, not `.scale.set(...)`: FlxPoint.set is inlined (see check_mod
		// trap 5), so HScript finds no function there.
		dad.scale.x = 0.1;
		dad.scale.y = 0.1;
	}

	// 1796-1804: the two legacy songs have their own BF body sheets and no
	// modern miss layers. Reuse the XML sprites so tint events keep their targets.
	if (!mmWarioTvOn()) {
		bftors.frames = Paths.getSparrowAtlas("mario/Wario/BoyFriend_Wario_Assets_v3_Body1");
		bftors.x = 460; bftors.y = 705;
		bftors.animation.addByPrefix("idle", "BF Body Idle 1", 48, true);
		bftors.animation.play("idle", true);
		bfext.frames = Paths.getSparrowAtlas("mario/Wario/BoyFriend_Wario_Assets_v3_Body2");
		bfext.x = 410; bfext.y = 655;
		bfext.animation.addByPrefix("idle", "BF Body Idle 2", 48, true);
		bfext.animation.play("idle", true);
		if (bftorsmiss != null) bftorsmiss.visible = false;
		if (bfextmiss != null) bfextmiss.visible = false;
		if (bfFall != null) bfFall.visible = false;
	}

	// 4320-4323: back legs sit after dad but immediately before BF, not
	// behind Wario as their declaration-time XML placement would put them.
	remove(bftors, true);
	if (bftorsmiss != null) remove(bftorsmiss, true);
	var at:Int = members.indexOf(boyfriend);
	if (at >= 0) insert(at, bftors); else add(bftors);
	if (bftorsmiss != null) {
		at = members.indexOf(boyfriend);
		if (at >= 0) insert(at, bftorsmiss); else add(bftorsmiss);
	}

	// 4423-4426: the foreground switch adds BF's two leg layers after the
	// character groups, so in the source they draw *over* him - which is the
	// point of `bfext`/`bfextmiss` (his front legs and their miss pair, this
	// stage's own rig). The stage XML carries both as ordinary children; each is
	// lifted to the end of the state's draw list in the source's own order.
	mmToFront(bfext);
	mmToFront(bfextmiss);

	// The camEst layer (fogbad) exists before the filters look for it.
	mmGetFogBad();
	// 5647-5690: the filters are mounted at create (no-op on the two legacy
	// songs, see mmWarioTvOn).
	mmTvStack();
}

function onEvent(event) {
	if (event.event.name != "Triggers Apparition" && event.event.name != "Triggers Universal") return;
	var trigger = Std.parseInt(event.event.params[0]);
	if (trigger == null || Math.isNaN(trigger)) trigger = 0;

	switch (trigger) {
		case 0:
			FlxTween.tween(dad, {alpha: 1}, 1, {ease: FlxEase.quadInOut});
			FlxTween.tween(dad.scale, {x: 1.2, y: 1.2}, 1, {ease: FlxEase.quadInOut});
		case 1:
			FlxTween.color(boyfriend, 10, FlxColor.WHITE, 0xfff96d63, {ease: FlxEase.quadInOut});
			FlxTween.color(dad, 10, FlxColor.WHITE, 0xfff96d63, {ease: FlxEase.quadInOut});
			FlxTween.color(bftors, 10, FlxColor.WHITE, 0xfff96d63, {ease: FlxEase.quadInOut});
			FlxTween.color(bfext, 10, FlxColor.WHITE, 0xfff96d63, {ease: FlxEase.quadInOut});
			FlxTween.color(bgwario, 10, FlxColor.WHITE, 0xfff96d63, {ease: FlxEase.quadInOut});
			FlxTween.tween(mmGetFogBad(), {alpha: 0.6}, 10, {ease: FlxEase.quadInOut});
		case 2:
			FlxTween.color(boyfriend, 0.5, 0xfff96d63, FlxColor.WHITE, {ease: FlxEase.quadInOut});
			FlxTween.color(dad, 0.5, 0xfff96d63, FlxColor.WHITE, {ease: FlxEase.quadInOut});
			FlxTween.color(bftors, 0.5, 0xfff96d63, FlxColor.WHITE, {ease: FlxEase.quadInOut});
			FlxTween.color(bfext, 0.5, 0xfff96d63, FlxColor.WHITE, {ease: FlxEase.quadInOut});
			FlxTween.color(bgwario, 0.5, 0xfff96d63, FlxColor.WHITE, {ease: FlxEase.quadInOut});
			FlxTween.tween(mmGetFogBad(), {alpha: 0}, 0.5, {ease: FlxEase.quadInOut});
		case 4:
			FlxTween.tween(dad, {alpha: 0}, 3, {startDelay: 1, ease: FlxEase.quadOut});
			FlxTween.tween(dad, {y: dad.y + 140, x: dad.x + 50}, 4, {ease: FlxEase.quadOut});
			FlxTween.tween(dad.scale, {x: 0.6, y: 0.6}, 4, {ease: FlxEase.quadOut});
		case 5:
			// 11508-11512: every camera off - the source lists camGame, camEst,
			// camHUD and camOther, which here is camGame, the port's own camEst
			// layer, camHUD and (no camOther in this stage).
			camHUD.visible = false;
			camGame.visible = false;
			if (mmEstCam != null) mmEstCam.visible = false;
	}
}

// ---------------------------------------------------------------------------
// Per-frame: the BF leg layers
// ---------------------------------------------------------------------------
// Two source behaviours live here, both about the bftors/bfext layers *this*
// stage owns (the source keeps them as PlayState fields, read from a lua and from
// update(); stage sprites are only visible to this script in this engine).
//
// 1. assets/preload/characters/bfrunv2.lua `onUpdatePost`:
//      if boyfriend.animation.curAnim.name == 'idle' then
//          boyfriend.animation.frameIndex = bftors.animation.frameIndex
//    bfrunv2's own `idle` runs at fps 0 (data/characters/bfrunv2.xml), so nothing
//    advances it - the animated back-legs layer drives it, which is what keeps the
//    torso lined up with the legs. Without this BF's idle sits frozen on frame 0
//    while the legs animate under him.
//
// 2. PlayState.hx:7449 (the warioworld branch of update):
//      bftors.visible = bfext.visible = !(bftorsmiss.visible = bfextmiss.visible
//          = boyfriend.animation.curAnim.name.endsWith('miss'));
//    i.e. the miss layers swap in while BF is in a miss animation. The source
//    gates that block on `song != 'Apparition Old' && song != 'Forbidden Star'`;
//    both of those songs play `bfrun` instead of `bfrunv2`, so the character
//    check below excludes them the same way.
function postUpdate(elapsed:Float) {
	mmTvTick(elapsed);
	if (boyfriend == null) return;
	if (boyfriend.curCharacter != "bfrunv2") return;

	var anim = boyfriend.animation.curAnim;
	var name:String = (anim != null) ? anim.name : "";
	// `StringTools.endsWith`, not `name.endsWith` - `String` has no such member in
	// Haxe 4, so the member form is a null function pointer on every frame.
	var missing:Bool = StringTools.endsWith(name, "miss");

	if (bftors != null) bftors.visible = !missing;
	if (bfext != null) bfext.visible = !missing;
	if (bftorsmiss != null) bftorsmiss.visible = missing;
	if (bfextmiss != null) bfextmiss.visible = missing;

	if (name == "idle" && bftors != null && bftors.animation != null)
		boyfriend.animation.frameIndex = bftors.animation.frameIndex;
}
// === end MM stage triggers ===
