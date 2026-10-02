

// === MM stage triggers (auto) ===
// 'Triggers Day Out' - ported from PlayState.hx (case 'Triggers Day Out', 13725)
// plus everything else the stage carries outside that group.
//
// The walking characters live in the stage XML. Every camera call goes through
// data/songs/MMcamera.hx, which *is* this song's camera: it writes camFollow
// while FOLLOWCHARS is on, so a stage script's own
// `FlxTween.tween(camFollow, ...)` is overwritten before the camera ever reads
// it. The mapping is the source's own:
//
//   FOLLOWCHARS = false/true            -> mmCamera.follow(false/true)
//   tween(camFollowPos, ...)            -> mmCamera.lock(x, y, sec, ease)
//   defaultCamZoom = x                  -> mmCamera.setZoom(x)
//   camZooming = true                   -> mmCamera.zooming(true)
//   triggerEventNote('Camera Follow Pos', '', '')   -> mmCamera.release()
//
// `Camera Follow Pos '320' '450'` (case 5) is *not* a camera move here: the fork
// follows camFollowPos, not camFollow, and with FOLLOWCHARS off nothing lerps
// camFollowPos towards the written value - see the same note in MMcamera's own
// 'Camera Follow Pos' handler. Only the FOLLOWCHARS = false half of case 5 does
// anything.
//
// Create-time (the rest of the stage's own `case 'luigiout'` and the blocks it
// turns on), all of it in postCreate/onCountdown below:
//
//   2306-2307   `noCount`/`noHUD` - the engine's READY/SET/GO are dropped
//               (`onCountdown` cancelled) and camHUD starts at alpha 0
//               (5630-5633). The chart's own 'Ocultar HUD' 2 brings it back at
//               18.95s, which is the frame its first note lands on.
//   2308        `flipchar = true` - 5635-5641 mirrors both health bars and both
//               icons, and 7686-7716 lays the pair out on the *other* side of
//               the mirrored bar; both halves are ported (see postUpdate -
//               Codename's own `updateIconPositions` knows nothing about
//               `flipchar`). The third thing the flag turns on is not a loss:
//               the `modManager.setValue("opponentSwap", 1)` at 7700 is guarded
//               by `!songIsModcharted` and Day Out has a modchart of its own
//               (`Modcharts.hx:419-440`, ported as
//               songs/day-out/scripts/modchart.hx), so the fork does not reach
//               that write for this song either - the fields trade sides through
//               the modchart in both.
//   2335-2359   the five end-scene walkers. The source *declares* them
//               gfwalk/gfspeak/bfwalk/mrwalk/lgwalk but `add()`s them gfspeak,
//               lgwalk, mrwalk, bfwalk, gfwalk (2355-2359) - and add order is
//               draw order - so Luigi's walk is drawn *under* the other three
//               and gf's still under all four. The XML follows the declarations
//               instead, which is what put Luigi on top of the group; postCreate
//               re-seats the band.
//   2310        `ZOOMCHARS = false` - what makes case 1/2's defaultCamZoom writes
//               stick instead of being rewritten by the section block every
//               frame; MMcamera's mmInit carries it (see the create-time camera
//               state there).
//   4548-4551   `boyfriendGroup.alpha = 0.000001` - Day Out hides the real BF,
//               and the walking sprites only take over at case 0, which the
//               chart does not send until 173.0s (its lone 'Triggers Day Out'),
//               so without this BF stands on screen for nearly the whole song
//               where the fork shows only dad and gf. Case 7's
//               `boyfriend.alpha = 1` matches the source's
//               `boyfriendGroup.alpha = 1`, and like there it does not undo
//               case 0's `visible = false`.
//   4673-4679   `blackBarThingie` for luigiout/realbg/turmoilsweep/secretbg: a
//               full-screen black on camEst created at alpha **1**, so this
//               stage opens on black. The countdown branch 7832-7836 (the one
//               luigiout shares with secretbg) then fades it out over 0.5s after
//               a one-second delay, which is what onSongStart() does here.
//               camEst sits between camGame and camHUD, so the port's stand-in is
//               a screen-space sprite in front of the draw list (the shape
//               secretbg.hx/execlassic.hx use) - the 10x scale the source gives
//               it is what keeps it covering the window once the camera stops
//               being the unzoomed intro one. camHUD is hidden here anyway, and
//               it is back well before the first note, so the layer this sprite
//               sits on cannot matter.
//   5243-5249   Day Out is the only stage that adds the two health icons the
//               other way round (`add(iconP2); add(iconP1);`), i.e. BF's icon
//               over dad's. Codename adds them iconP1-then-iconP2
//               (`for (icon in iconArray) add(icon)`), so BF's is lifted back
//               over dad's here.
//   7686-7716   `flipchar`'s mirrored HUD layout, the generic branch (the one
//               `demiseport`/`overFuckYou` do not take): both icons trade sides
//               and ride the health bar. The engine cannot be left to do this -
//               see postUpdate.
//
// 15943-15987 - the stage's own `stepHit()` block, on the **swing** steps (the
// even steps that are not beats: `curStep % 2 == 0 && curStep % 4 != 0`). Two of
// its four halves are not portable and are left to the engine: the
// `FlxG.camera.zoom += 0.015` / `camHUD.zoom += 0.03` on `(curStep - 2) % 16 == 0`
// and the icon pop to 1.1 are exactly what Codename already does for every stage
// on its own beat (`PlayState.beatHit`'s `icon.bump()` and the `camZooming`
// bump). The fork simply excludes this song from both generic blocks
// (16138/16180) and runs them here instead - one per four beats, at the swing
// offset - so a second manual bump would double either. What is left is the two
// things no engine does: `gflol`'s half-loops and the fighters' dance - and the
// dance is `tryDance()`, not `dance()`, because the source's `dance()` is
// `specialAnim`-guarded and this chart's `MM Play Animation` events depend on
// that (see `stepHit` below).
//
// NOT ported: the stage's game-over music (`endSoundName = 'LDOgameover'` /
// `loopSoundName = 'LDOconfirm'`, GameOverSubstate.hx:91-93) does not exist in
// the source's assets at all - `shared/music` has no LDO file, only the
// `LDOLuigideath` sound ships - so the engine's own game-over track stays
// (MMcamera's MM_GAME row still carries the stage's `bf-ldo` death character).
// The per-character `deathSoundName = 'LDOLuigideath'` (GameOverSubstate.hx:108,
// on the 'luigi-ldo' branch) is character-level state, and Codename keeps that
// sound on the state's `lossSFX`, which cannot vary with the death character.

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

// ---------------------------------------------------------------------------
// Create-time state (2306-2310, 4548-4551, 4673-4679, 5243-5249, 5630-5641)
// ---------------------------------------------------------------------------

// Screen-space (scrollFactor 0) sprite in front of the state's draw list - the
// port's stand-in for the fork's camEst layer (see the header).
function mmScreen(spr) {
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

// Index of the first character (the top of the world layer), the same
// derivation meatworld.hx/secretbg.hx use: the girlfriend node is the first
// character node in every ported stage XML and her marker sits one slot past her
// character, so `indexOf(marker) - 1` is the band start.
function mmWorldTop():Int {
	var st = PlayState.instance;
	if (st == null || stage == null) return -1;
	var poses = Reflect.field(stage, "characterPoses");
	var gfPos = (poses != null) ? poses.get("girlfriend") : null;
	if (gfPos == null) return -1;
	var i:Int = st.members.indexOf(gfPos);
	return (i >= 0) ? i - 1 : -1;
}

var mmCurtain = null;    // blackBarThingie (4673), alpha 1 at load
function mmGetCurtain() {
	if (mmCurtain == null) {
		mmCurtain = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		mmCurtain.scale.set(10, 10); // source's setGraphicSize(width * 10)
		mmCurtain.alpha = 1;
		mmScreen(mmCurtain);
	}
	return mmCurtain;
}

// `noCount = true` (2306): the source never builds its 3-2-1-GO sprites.
function onCountdown(event) {
	event.cancelled = true;
}

// 7832-7836 (the branch luigiout shares with secretbg): the curtain lifts half a
// second in, starting one second after the song does.
function onSongStart() {
	FlxTween.tween(mmGetCurtain(), {alpha: 0}, 0.5, {startDelay: 1, ease: FlxEase.quadInOut});
}

function postCreate() {
	// 4548-4551 (see the header).
	if (boyfriend != null) boyfriend.alpha = 0.000001;

	// `noHUD = true` (2307) -> 5630-5633.
	if (camHUD != null) camHUD.alpha = 0;

	// 5635-5641: `flipchar` (2308) mirrors both health bars and both icons.
	if (healthBar != null) healthBar.flipX = true;
	if (healthBarBG != null) healthBarBG.flipX = true;
	if (iconP1 != null) iconP1.flipX = true;
	if (iconP2 != null) iconP2.flipX = true;

	// 5243-5249: BF's icon goes back over dad's. A bare `remove(iconP1); add(
	// iconP1)` would be a no-op - `remove` nulls the slot and `add` re-fills the
	// first null slot, which is that same one - hence the splice.
	if (iconP1 != null && iconP2 != null && members.indexOf(iconP1) >= 0) {
		remove(iconP1, true);
		var j:Int = members.indexOf(iconP2);
		insert((j >= 0) ? j + 1 : members.length, iconP1);
	}

	// 2355-2359: the walkers are re-seated in the order the source adds them
	// (see the header). They are drawn between `gflol` and the characters, so
	// the whole band is lifted out and put back just under the character markers
	// - `remove(obj, true)` is the splicing half of the pair (a bare `remove()`
	// only nulls the slot, see meatworld.hx).
	var walkers = [gfspeak, lgwalk, mrwalk, bfwalk, gfwalk];
	for (s in walkers) {
		if (s == null) continue;
		remove(s, true);
	}
	// The band start has to be read *after* the five are lifted out - the splice
	// drops them from the list outright, so every index past them moves down.
	var w:Int = mmWorldTop();
	if (w >= 0) {
		var k:Int = 0;
		for (s in walkers) {
			if (s == null) continue;
			insert(w + k, s);
			k += 1;
		}
	}

	// 4417-4418: `add(lightWall)` in the foreground switch - the city overlay
	// draws over the fighters. The stage XML carries it as an ordinary child, so
	// it is lifted to the end of the state's draw list, ahead of the load-time
	// curtain added just after.
	mmToFront(lightWall);

	mmGetCurtain();
}

// ---------------------------------------------------------------------------
// 7686-7716 - `flipchar`'s mirrored HUD layout (see the header)
// ---------------------------------------------------------------------------
// The source lays the flipped pair out inside its own per-frame
// `updateIconPositions` override (7677-7716), i.e. after the icons have been
// positioned, and this song takes the generic branch (it is neither
// `demiseport` nor `overFuckYou`):
//
//     iconOffset  = 610
//     iconOffset2 = 86
//     iconP1.x = healthBar.x - (healthBar.width * (FlxMath.remapToRange(healthBar.percent, 0, 100, 100, 0) * 0.01)) - (iconP1.width - iconOffset);
//     iconP2.x = healthBar.x - (healthBar.width * (FlxMath.remapToRange(healthBar.percent, 0, 100, 100, 0) * 0.01)) - (iconP1.width - (iconOffset + iconOffset2));
//
// That is the engine's own slide (`center = healthBar.x + healthBar.width *
// FlxMath.remapToRange(healthBar.percent, 0, 100, 1, 0)`, `_ref_src/
// PlayState.hx:1361`) mirrored to the far side of the bar (`healthBar.x - ...`),
// with the 610/696 icon offsets. `remapToRange(percent, 0, 100, 100, 0) * 0.01`
// is `1 - percent / 100`, and Psych's `healthBar.percent` is `health * 50` (an
// `FlxBar` over `health`, min 0 / max 2 - 5213-5218), so the slide term is
// `1 - health / 2`. Both writes read **`iconP1.width`** - the source's own
// quirk, `iconP2`'s is never used in this branch - and `iconOffset2` is only
// spent here, in the generic branch, so a `demiseport`/`overFuckYou` port could
// not reuse this block.
//
// Codename's `updateIconPositions` has no `flipchar` in it at all, so without
// this the icons sit on their normal sides while both bars are mirrored. It runs
// from the state's `update()` (1431), hence `postUpdate` here - the engine
// positions the icons itself, and the flipped layout is re-applied after it (the
// same shape meatworld.hx's `overFuckYou` block has).
function postUpdate(elapsed:Float) {
	if (iconP1 == null || iconP2 == null || healthBar == null) return;
	var pct:Float = health * 50;         // 5213: healthBar.percent over `health`
	var slide:Float = 1 - (pct * 0.01);  // remapToRange(percent, 0, 100, 100, 0) * 0.01
	var base:Float = healthBar.x - healthBar.width * slide;
	iconP1.x = base - (iconP1.width - 610);
	iconP2.x = base - (iconP1.width - 696);
}

// ---------------------------------------------------------------------------
// 15943-15987 - the swing-beat block (see the header for its two engine halves)
// ---------------------------------------------------------------------------
function stepHit(curStep:Int) {
	if (curStep % 2 != 0 || curStep % 4 == 0) return;

	// 15974-15985: `gflol`'s two half-loops are played one at a time, so it is
	// replayed on the other half once the current one has run out.
	if (gflol != null && gflol.animation.curAnim != null) {
		var name:String = gflol.animation.curAnim.name;
		if (gflol.animation.curAnim.finished || name == "danceleft" || name == "danceright")
			gflol.animation.play(name == "danceleft" ? "danceright" : "danceleft");
	}

	// 15962-15973: the two fighters dance on the off-beats as well, as long as
	// they are not already singing (`StringTools.startsWith`, not the member
	// form - `String` has no such member in HScript).
	//
	// `tryDance()` and not `dance()`. The source's `dance()` is a no-op while the
	// character's `specialAnim` is set (`Character.hx:288-306`, cleared only when
	// the animation finishes, 247-249), and that guard is the whole reason this
	// chart's twelve 'MM Play Animation' events hold on Mario - the opening
	// 'smoke hold' at 0.01s, then 'gonnatell' 3.24, 'betternot' 9.21, 'hey' 15.92,
	// 'dumbass' 68.16 and 'idiot' 100.33 - instead of being cut off. Codename's
	// `dance()` has no such guard and plays `danceLeft`/`danceRight` outright, so
	// calling it here killed 'smoke hold' a quarter of a second in. `tryDance()`
	// is the engine's own equivalent: it is what `Character.beatHit` and
	// `Character.update` call, and a non-`DANCE`-context animation holds it until
	// it finishes (`tryDance`'s `default:` branch), which is exactly what the
	// source's `specialAnim` does for a 'Play Animation' event - so those events
	// now survive the swing step the way they do in the fork.
	if (boyfriend != null) {
		var ba = boyfriend.animation.curAnim;
		var bn:String = (ba != null) ? ba.name : "";
		if (bn != "" && !StringTools.startsWith(bn, "sing")) boyfriend.tryDance();
	}
	if (dad != null) {
		var da = dad.animation.curAnim;
		var dn:String = (da != null) ? da.name : "";
		if (dn != "" && !StringTools.startsWith(dn, "sing") && !dad.stunned) dad.tryDance();
	}
}

function onEvent(event) {
	if (event.event.name != "Triggers Day Out" && event.event.name != "Triggers Universal") return;
	var trigger = Std.parseInt(event.event.params[0]);
	if (trigger == null || Math.isNaN(trigger)) trigger = 0;
	var trigger2 = Std.parseInt(event.event.params[1]);
	if (trigger2 == null || Math.isNaN(trigger2)) trigger2 = 0;

	switch (trigger) {
		case 0:
			// 13735-13736: FOLLOWCHARS = false, then the camera pans to dad's own
			// position (DAD_CAM_X/Y = 620, 450 from the stage preload).
			mmCam("follow", [false]);
			mmCam("lock", [620, 450, 1.5, FlxEase.quadOut]);
			mrwalk.alpha = 1;
			dad.visible = false;
			gfwalk.alpha = 1;
			gflol.visible = false;
			bfwalk.alpha = 1;
			boyfriend.visible = false;
			lgwalk.alpha = 1;
			gf.visible = false;
			gfwalk.playAnim("why", true);
			bfwalk.playAnim("why", true);
			mrwalk.playAnim("why", true);
			lgwalk.playAnim("why", true);
			gfspeak.alpha = 1;
			FlxTween.tween(gfwalk, {y: gfwalk.y + 400, x: gfwalk.x + 2533}, 6, {startDelay: 7.71});
			FlxTween.tween(bfwalk, {y: bfwalk.y + 400, x: bfwalk.x + 2533}, 6, {startDelay: 7.85});
			FlxTween.tween(mrwalk, {y: mrwalk.y + 400, x: mrwalk.x + 2533}, 6, {startDelay: 6.19});
			FlxTween.tween(lgwalk, {y: lgwalk.y + 400, x: lgwalk.x + 2533}, 6, {startDelay: 9.14});
		case 1:
			// 13755-13758: the only place the source touches the zoom before the
			// triggers take over - camGame.zoom -> 1 over 2.4s with defaultCamZoom
			// set to the same value, so the engine's lerp holds it there.
			mmCam("follow", [false]);
			mmCam("lock", [1050, 450, 2.5, FlxEase.cubeInOut]);
			mmCam("zoom", [1, 2.4, 0, FlxEase.quadInOut]);
		case 2:
			// 13760-13764: hand the camera back to the section and re-arm the zoom
			// lerp, with a new target zoom of 0.75.
			mmCam("follow", [true]);
			mmCam("zooming", [true]);
			mmCam("release", []);
			mmCam("setZoom", [0.75]);
		case 3:
			gflol.playAnim("why");
			mmCam("follow", [false]);
			mmCam("lock", [320, 450, 1, FlxEase.quadOut]);
		case 4:
			// 13775-13777: the release is inert in this fork (case 5 writes
			// camFollow with FOLLOWCHARS off, and nothing reads it again), but the
			// FOLLOWCHARS = true half is real - and it is what makes case 5's write
			// matter in the source at all.
			mmCam("follow", [true]);
			mmCam("release", []);
		case 5:
			// 13779-13781: FOLLOWCHARS = false + 'Camera Follow Pos' '320','450'.
			// The write is dead in this fork (see the header), so the camera simply
			// freezes where case 3's pan left it.
			mmCam("follow", [false]);
		case 6:
			// 13783-13790: the GFSING flags are cleared here, the camera pans to
			// (920, 450) over 3s, and the (inert) release fires at the start of
			// that pan - not after it, which is why the port keeps the tween as the
			// lock's own expiry rather than releasing over it.
			mmCam("follow", [false]);
			mmCam("gfSing", [false, false]);
			mmCam("lock", [920, 450, 3, FlxEase.quadInOut]);
			mmCam("release", []);
		case 7:
			// 13791-13795. The source tweens camGame.zoom only, leaving
			// defaultCamZoom at case 2's 0.75 (its lerp then pulls the zoom back to
			// 0.75 after the tween); the drive publishes both, so the camera settles
			// 0.05 away from the source's resting zoom.
			mmCam("lock", [320, 450, 2.4, FlxEase.cubeInOut]);
			mmCam("zoom", [0.7, 2.4, 0, FlxEase.cubeInOut]);
			boyfriend.alpha = 1;
			gflol.alpha = 1;
		case 8:
			// 13797-13798: no FOLLOWCHARS write - case 6 already turned it off.
			mmCam("lock", [720, 450, 1.4, FlxEase.cubeOut]);
		case 9:
			// 13799-13803: `GameOverSubstate.characterName = 'bf-ldo' | 'luigi-ldo'`.
			// The fork has one global death character; Codename asks the dying
			// character for its own `gameOverCharacter` (PlayState.gameOver():
			// `deathCharID.getDefault(charToUse.gameOverCharacter)`), so the two
			// names go on BF and dad respectively, which is also what makes the
			// choice in value2 meaningful. The chart sends this 12 times.
			if (trigger2 == 0) boyfriend.gameOverCharacter = "bf-ldo";
			else dad.gameOverCharacter = "luigi-ldo";
	}
}
// === end MM stage triggers ===
