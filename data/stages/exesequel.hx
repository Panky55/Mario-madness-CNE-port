// Ported from PlayState.hx beatHit() (case 'exesequel' | 'betamansion' | 'nesbeat').
// starman GF bounces left/right every beat, but a 'hey' animation is allowed
// to play through before the dance resumes.
function beatHit(curBeat:Int) {
	var anim = starmanGF.animation.curAnim;
	if (curBeat % 2 == 0) {
		if (anim == null || anim.name != 'hey' || anim.finished)
			starmanGF.playAnim('danceRight', true);
	} else {
		starmanGF.playAnim('danceLeft', true);
	}
}

// === MM stage triggers (auto) ===
// 'Triggers Starman Slaughter' - ported from PlayState.hx (case 'Triggers
// Starman Slaughter', 9530-9739). Only starman-slaughter runs on this stage.
//
// The camera half of every case (BF/DAD/GF_CAM_X/Y, BF/DAD/GF_ZOOM, FOLLOWCHARS,
// ZOOMCHARS and the camFollowPos / camGame.zoom tweens) lives in
// songs/MMcamera.hx (mmStarmanTrigger), which owns camFollow and defaultCamZoom.
// Everything that is a sprite, a character or a HUD write is here.
//
// What the source also does for this stage, and where each piece lands:
//   1167-1250  create(): the stage art (XML), plus `iconGF` (the third health
//              icon - john dick, later yoshiexe) and `blackBarThingie`, both of
//              which are built *here* because the source builds them in the
//              background switch, i.e. below the characters. The source does not
//              `add()` iconGF until trigger 2, so this port does not either.
//   4351-4355  the foreground switch's `platform2` (SS_foreground), added after
//              `add(boyfriendGroup)` - a sprite in front of the fighters. The
//              XML puts every stage sprite below the characters, so postCreate
//              lifts it out of the world layer, exactly like allfinal.hx does
//              for its own foreground sprites.
//   8033-8048  update(): the iconGF controller (the only per-frame piece).
//   15206/15323 noteMiss/noteMissPress: the stage GF plays 'sad'.
//   16366      beatHit(): the starman GF dance, generated into the stage head.
//   script.lua `onCreatePost`'s `setObjectOrder('gfGroup', 7)` - the girlfriend
//              is drawn behind the backdrop until trigger 4 (postCreate below).
//   9739       case 17 hides `boyfriendGroup` *before* showing the black bar -
//              the black is a world sprite there, so whatever is not hidden
//              draws over it.
//
// The source's `GameOverSubstate.characterName = 'bfexenewdeath'` rides
// `songs/MMcamera.hx`'s game-over table (`exesequel|bfexenewdeath`, applied by
// `mmGameOverConfig` at load). NOT ported: `iconGF.antialiasing` (the port
// leaves it at the engine default). The four `addCharacterToList` calls
// (1172-1175) *are* the character preloads - see that section below.

// ---------------------------------------------------------------------------
// Character access
// ---------------------------------------------------------------------------
// The song swaps both fighters' characters mid-choreography (`Change Character`
// at trigger 4 and 12), and PlayState.gf/boyfriend/dad are properties over
// strumLines.members[2|1|0].characters[0] - so the read has to go through the
// strumline to be sure it sees the swap-in (the same reasoning as allfinal.hx's
// mmDad/mmBf/mmGf and MMcamera's mmRoleChar).
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
function mmGfChar() { return mmMem(2); }

// ---------------------------------------------------------------------------
// Character preloads (1172-1175)
// ---------------------------------------------------------------------------
// The source's create branch calls `addCharacterToList` for four characters,
// which *builds* them (and therefore decodes their atlas) up front; the song
// then swaps them in mid-choreography. Doing that decode at swap time is a
// visible stall, so the three the triggers actually use are decoded here at
// script load: `yoshi-exe` and `peach-exe` at trigger 4, `mariohorror-melt` at
// trigger 12. The fourth, `bfexenewdeath`, is the source's game-over character -
// now carried by `songs/MMcamera.hx`'s table (`exesequel|bfexenewdeath`) - but it
// is only built on death, so it stays off this load-time list.
//
// `Paths.getFrames` caches by path and is exactly what `Character`'s own loader
// (`FunkinSprite.loadSprite`) calls, so this makes the later `new Character()`
// reuse the frames instead of decoding them a second time.
var mmPreloadChars:Array<String> = ["yoshi-exe", "peach-exe", "mariohorror-melt"];

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
// The source's group coordinates
// ---------------------------------------------------------------------------
// The source moves `gfGroup.x/y` and `dadGroup.x/y`; a ported character has no
// group, so the group position has to be recovered from (and written back to)
// the character. FlxSprite draws at `x - offset` and Character.playAnim sets
//     offset.x = globalOffset.x * (isPlayer != playerOffsets ? 1 : -1)
//     offset.y = -globalOffset.y
// so a character *renders* at `stored.x + k * globalOffset.x` with
// k = (isPlayer != playerOffsets) ? 1 : -1, while the source renders it at
// `group + position`. y is the simple half (stored.y == groupY); x needs the
// correction below. For exesequel's girlfriend and dad strumlines k is -1, so
// these are identity there - but the player side is +1 and the swap-in at
// trigger 4 is built by mmChangeChar, so the correction is what keeps both
// exact. (Same derivation as allfinal.hx's mmSideK/mmPlaceGroup.)
function mmSideK(c):Float {
	if (c == null) return 1;
	return (c.isPlayer != c.playerOffsets) ? 1 : -1;
}

function mmGroupX(c):Float {
	if (c == null) return 0;
	return c.x - (mmSideK(c) + 1) * c.globalOffset.x;
}

function mmGroupY(c):Float {
	return (c == null) ? 0 : c.y;
}

// The stored x that renders the character at group x `gx`.
function mmGroupXTo(c, gx:Float):Float {
	if (c == null) return gx;
	return gx + (mmSideK(c) + 1) * c.globalOffset.x;
}

function mmPlaceGroup(c, gx:Float, gy:Float) {
	if (c == null) return;
	c.x = mmGroupXTo(c, gx);
	c.y = gy;
}

// Same swap as data/events/Change Character.hx, called directly because the
// source's triggers fire 'Change Character' themselves (trigger 4 -> gf
// yoshi-exe and dad peach-exe, trigger 12 -> dad mariohorror-melt) and only the
// two *chart* swaps go through the event file. Unlike the event file this keeps
// the group position: the source drops the swap-in into the same group and it
// sits at `group + its own position`.
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
	var gx:Float = mmGroupX(old);
	var gy:Float = mmGroupY(old);
	var oldIndex:Int = members.indexOf(old);

	remove(old);
	member.characters.remove(old);

	var fresh = new Character(0, 0, name, isPlayer);
	if (stage != null) stage.applyCharStuff(fresh, member.data.position, 0);
	mmPlaceGroup(fresh, gx, gy);
	// The source re-adds into the same persistent group, so the group keeps its
	// draw slot - reproduce that by keeping the replaced character's index.
	if (oldIndex >= 0) {
		remove(fresh);
		insert(oldIndex, fresh);
	}
	// The source's death character is a global (GameOverSubstate.characterName) and
	// survives a swap; this port keeps it on the character (see songs/MMcamera.hx's
	// game-over table), so the current one has to ride across.
	fresh.gameOverCharacter = old.gameOverCharacter;
	member.characters.insert(0, fresh);
}

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------
var mmDownscroll:Bool = false;
function mmDownScroll():Bool {
	// `PlayState.downscroll` is a get/set property over `camHUD.downscroll`; on
	// cpp `Reflect.field` returns null for get/set properties (only
	// `Reflect.getProperty`, which is what a script's field access compiles to,
	// runs the getter), so read the property itself.
	var d = (camHUD != null) ? camHUD.downscroll : null;
	if (d != null) return d == true;
	if (PlayState.instance != null && PlayState.instance.downscroll != null)
		return PlayState.instance.downscroll == true;
	return mmDownscroll;
}

// The source's `extraTween` list: trigger 4 cancels everything in it.
var mmExtra = [];

// FlxFlicker.flicker(spr, duration, interval, EndVisibility=false): blink for
// `duration` every `interval` and end hidden. FlxFlicker itself is not
// script-reachable, so this toggles visibility on a timer (as exeport.hx does).
function mmFlicker(spr, duration:Float, interval:Float) {
	if (spr == null) return;
	var n:Int = Std.int(duration / interval);
	if (n < 1) n = 1;
	spr.visible = true;
	spr.alpha = 1;
	var i:Int = 0;
	new FlxTimer().start(interval, function(tmr) {
		i += 1;
		spr.visible = (i < n);
	}, n);
}

// ---------------------------------------------------------------------------
// iconGF - the third health icon (1228-1234)
// ---------------------------------------------------------------------------
// `new FlxSprite().loadGraphic('icons/icon-LG'); width = width / 2;` then a
// reload of 'icons/icon-johndick' with `floor(width) x floor(height)` frames.
// Both sheets are 300x150, so the 150x150 frame size is the same the source
// computes, without depending on the first load. Not added to the draw list:
// the source only `add()`s it from trigger 2.
var mmIconGF:FlxSprite = null;
var mmIconGFAdded:Bool = false;

function mmIconGFLoad(ic, sheet:String):Bool {
	var path = Paths.image(sheet);
	if (path == null || !Assets.exists(path)) {
		trace("[exesequel] iconGF: image missing -> " + path);
		return false;
	}
	ic.loadGraphic(path, true, 150, 150);
	ic.animation.add("win", [0], 10, true);
	ic.animation.add("lose", [1], 10, true);
	return true;
}

function mmGetIconGF():FlxSprite {
	if (mmIconGF != null) return mmIconGF;
	var s = new FlxSprite();
	if (!mmIconGFLoad(s, "icons/icon-johndick")) return null;
	s.cameras = [camHUD];
	mmIconGF = s;
	return mmIconGF;
}

function mmIconGFAdd():FlxSprite {
	var ic = mmGetIconGF();
	if (ic == null) return null;
	if (!mmIconGFAdded) {
		add(ic);
		mmIconGFAdded = true;
	}
	return ic;
}

// ---------------------------------------------------------------------------
// blackBarThingie (1236-1238)
// ---------------------------------------------------------------------------
// makeGraphic(width, height, BLACK), setGraphicSize(width * 10), scrollFactor
// (0, 0), visible = false, added in the *stage-creation* switch - i.e. before
// `add(boyfriendGroup)` (4341), so the fighters draw over it. See mmWorldAdd for
// where "the world layer" is here.
var mmBlackBar:FlxSprite = null;

// ---------------------------------------------------------------------------
// Stage sprite lookup
// ---------------------------------------------------------------------------
// A sprite the stage XML named (`<sprite name="..."/>`). The loader also hands
// each of them to the stage script as a variable (`setStagesSprites`), but this
// reads the stage's own map so that a lookup for a plate the XML may not carry
// cannot abort the script. postCreate uses it to anchor the girlfriend's draw
// slot on the plate the source's own index resolves to.
function mmStageSprite(name:String) {
	var st = PlayState.instance;
	if (st == null || stage == null) return null;
	var map = Reflect.field(stage, "stageSprites");
	if (map == null) return null;
	return map.get(name);
}

// The source's create-switch sprites are world sprites: on the state's draw list
// below every character. Codename's `Stage` is not a group - `class Stage
// extends FlxBasic`, and FlxBasic has no `add`/`remove`/`insert`, so a
// `stage.add(...)` resolves to null and throws Null Function Pointer, aborting
// the rest of the handler (that is what left this bar out of the draw list
// entirely, and case 17 without its blackout). The *state* is the group, and the
// stage loader fills it in that exact order: the XML's sprites appended first,
// then one invisible marker per character with the character inserted at the
// marker's index (Stage.addSprite / StageCharPos.prepareCharacter +
// applyCharStuff). Inserting immediately before the girlfriend's marker is
// therefore the same slot the source's create-switch `add()` gave the bar.
function mmWorldAdd(spr) {
	var st = PlayState.instance;
	if (st == null || stage == null) { add(spr); return; }
	var idx:Int = -1;
	var poses = Reflect.field(stage, "characterPoses");
	var gfPos = (poses == null) ? null : poses.get("girlfriend");
	// the character is inserted *at* its marker, so the marker ends up one past
	// it - one before the marker is the character's own index
	if (gfPos != null) idx = st.members.indexOf(gfPos) - 1;
	if (idx < 0) {
		var gfChr = mmGfChar();
		if (gfChr != null) idx = st.members.indexOf(gfChr);
	}
	if (idx < 0) add(spr); else st.insert(idx, spr);
}

function mmBlackBarSpr():FlxSprite {
	if (mmBlackBar == null) {
		mmBlackBar = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		mmBlackBar.scale.set(10, 10); // source's setGraphicSize(width * 10)
		mmBlackBar.scrollFactor.set(0, 0);
		mmBlackBar.visible = false;
		mmWorldAdd(mmBlackBar);
	}
	return mmBlackBar;
}

// ---------------------------------------------------------------------------
// update() (8033-8048) - the iconGF controller
// ---------------------------------------------------------------------------
function update(elapsed:Float) {
	if (mmIconGF == null || !mmIconGFAdded) return;
	if (iconP2 != null) mmIconGF.x = iconP2.x - 70;
	if (iconP1 != null) {
		// NOTE: the source compares against 'yoshiexe' while the character it
		// swaps in at trigger 4 is called 'yoshi-exe', so that branch can never
		// be taken - the icon keeps the player icon's scale for the whole song.
		// Kept literal on purpose.
		var g = mmGfChar();
		if (g != null && g.curCharacter == "yoshiexe")
			mmIconGF.scale.set(iconP1.scale.x - 0.2, iconP1.scale.y - 0.2);
		else
			mmIconGF.scale.set(iconP1.scale.x, iconP1.scale.y);
	}
	var hp:Dynamic = (PlayState.instance != null) ? Reflect.getProperty(PlayState.instance, "health") : null;
	if (hp == null) hp = 1;
	if (hp > 1.6) mmIconGF.animation.play("lose");
	else mmIconGF.animation.play("win");
}

// noteMiss (15206) / noteMissPress (15323): the stage GF recoils, gated on
// `combo > 5` exactly like the source.
function onPlayerMiss(event) {
	if (starmanGF == null) return;
	var st = PlayState.instance;
	if (st == null || Reflect.field(st, "combo") == null) return;
	var n:Float = Std.parseFloat(Std.string(Reflect.field(st, "combo")));
	if (n != n || n <= 5) return; // NaN or too low a combo
	starmanGF.animation.play("sad");
}

function postCreate() {
	// 4351-4355: platform2 is added after the character groups, so it is in front
	// of the fighters. Every stage sprite in the XML sits below them, so lift it
	// out of the world layer to the front (the same move allfinal.hx makes for
	// its act 1/3 foreground layers). The lift has to be a splice plus an append:
	// `remove(x)` alone only nulls the slot and `add(x)` then re-fills the first
	// null slot of the list, which is that same one - a bare remove + re-add
	// leaves the sprite exactly where it was.
	if (platform2 != null) {
		remove(platform2, true);
		insert(members.length, platform2);
	}

	// assets/preload/data/songData/starman-slaughter/script.lua (`onCreatePost`):
	// `setObjectOrder('gfGroup', 7)`. In the source that 7 is the *floor* plate:
	// its create() switch adds sky, castillo, fireL, fireR, platform0, starmanPOW,
	// platform1 and then floor as members 0-7, so "index 7" means "directly
	// behind SS_floor" - over the two pillar plates (SS_farplatforms and
	// SS_midplatforms) and under the ground. Codename's list is one entry longer
	// at the front, though: `camFollow` is added before the stage is
	// (PlayState.hx:660-662), so the same numeric 7 lands on platform1
	// (SS_midplatforms) and the starman Koopa was drawn *under* that pillar. The
	// slot therefore comes off the plate the source's index resolves to instead
	// of off a number - insert directly above `floor`, which is the source's own
	// "7" wherever the engine's own members happen to sit. Codename has no
	// `gfGroup`, and its draw list is the flat one the XML filled (stage sprites
	// and the character markers, then the characters inserted at them), so the
	// move is a `remove` + `insert` on the girl's own character - the shape
	// allfinal.hx uses for its group reorders.
	var gfo = mmGfChar();
	if (gfo != null && members.indexOf(gfo) >= 0) {
		remove(gfo);
		// looked up *after* the splice: the plate's own index is the one the
		// insert has to land on, and removing her can move it
		var idx:Int = -1;
		var flo = mmStageSprite("floor");
		if (flo != null) idx = members.indexOf(flo);
		// A backdrop without the plate falls back to the front, which is where
		// the source's own index lands once it is past the end of the list.
		if (idx < 0) idx = members.length;
		insert(idx, gfo);
	}

	mmBlackBarSpr();
}

// ---------------------------------------------------------------------------
// 'Triggers Starman Slaughter' 0-17
// ---------------------------------------------------------------------------
// Sent as 'Triggers Universal' by the chart (the source re-dispatches that to
// 'Triggers <song>' at runtime, 9489-9496), so both names are accepted - the
// same shape every other stage script here uses.
function onEvent(event) {
	if (event.event.name != "Triggers Starman Slaughter" && event.event.name != "Triggers Universal") return;
	var trigger = Std.parseInt(event.event.params[0]);
	if (trigger == null || Math.isNaN(trigger)) trigger = 0;

	switch (trigger) {
		case 2:
			// 132 (61.88s): john dick slides up beside the opponent's icon and
			// the starman GF rises. The icon tween is the source's `eventTweens`
			// (finished long before trigger 4), the gf pair is `extraTween`.
			var ic2 = mmIconGFAdd();
			if (ic2 != null) {
				ic2.y = mmDownScroll() ? -150 : 820;
				var ty:Float = (iconP2 != null ? iconP2.y : 0) - (mmDownScroll() ? -15 : 35);
				FlxTween.tween(ic2, {y: ty}, 3, {ease: FlxEase.expoOut});
			}
			var g2 = mmGfChar();
			if (g2 != null) {
				mmExtra.push(FlxTween.tween(g2, {y: 0}, 3, {ease: FlxEase.expoOut, onComplete: function(twn) {
					mmExtra.push(FlxTween.tween(g2, {y: g2.y - 80}, 2, {ease: FlxEase.quadInOut, type: FlxTween.PINGPONG}));
				}}));
				mmExtra.push(FlxTween.tween(g2, {x: g2.x - 100}, 3, {ease: FlxEase.quadInOut, type: FlxTween.PINGPONG}));
			}

		case 4:
			// 256 (120s): the starman GF flies off, yoshi-exe is swapped in and
			// dropped onto the stage, then dad is swapped for peach-exe and
			// hidden. Everything here is `extraTween` except the first icon tween.
			var d4 = mmDadChar();
			var dadgx:Float = mmGroupX(d4);
			var dadgy:Float = mmGroupY(d4);

			for (t in mmExtra) t.cancel();
			mmExtra = [];

			var ic4 = mmGetIconGF();
			if (ic4 != null)
				mmExtra.push(FlxTween.tween(ic4, {y: mmDownScroll() ? -150 : 820}, 1.5, {ease: FlxEase.expoIn}));

			var g4 = mmGfChar();
			if (g4 == null) return;
			mmExtra.push(FlxTween.tween(g4, {x: mmGroupXTo(g4, 3500)}, 1.5, {ease: FlxEase.quadInOut}));
			mmExtra.push(FlxTween.tween(g4, {y: -400}, 1.5, {ease: FlxEase.cubeIn, onComplete: function(twn) {
				g4.scrollFactor.set(0.55, 0.55);
				mmChangeChar(2, "yoshi-exe");
				var g4b = mmGfChar();
				if (g4b == null) return;
				// The source writes `gfGroup.scrollFactor` (0.55) just before the
				// swap, and the gf slot's factor is what the swap-in ends up with -
				// that is what keeps yoshi-exe standing on the platform instead of
				// sliding across it with the camera (the community CNE port gives
				// him the same value, `<char name="yoshi-exe" scroll="0.55"/>`).
				// This port builds the swap-in fresh, so it has to be written on
				// him directly, *after* mmChangeChar - which runs the stage's own
				// character position and would otherwise reset it.
				g4b.scrollFactor.set(0.55, 0.55);
				mmPlaceGroup(g4b, 685, -1200);
				g4b.playAnim("prepow", true);

				mmExtra.push(FlxTween.tween(g4b, {y: 20}, 0.20, {startDelay: 1.04, onComplete: function(twn2) {
					// Screen Shake '0.8, 0.02' with an empty HUD value: the game
					// camera only (data/events/Screen Shake.hx).
					camGame.shake(0.02, 0.8);
					g4b.playAnim("pow", true);
					var dd = mmDadChar();
					if (dd == null) return;
					dd.playAnim("xd", true);
					if (starmanPOW != null) starmanPOW.visible = false;

					mmExtra.push(FlxTween.tween(dd, {y: 1500}, 0.6, {ease: FlxEase.quadIn, onComplete: function(twn3) {
						mmPlaceGroup(dd, dadgx, dadgy);
						mmChangeChar(1, "peach-exe");
						var dEnd = mmDadChar();
						if (dEnd != null) dEnd.visible = false;
					}}));
				}}));
			}}));

		case 7:
			// 269 (125.86s): peach's cuts float in from the left and land on the
			// stage while the john dick icon becomes the yoshiexe one.
			if (peachCuts != null) {
				peachCuts.x = -2000;
				peachCuts.y = -700;
				peachCuts.alpha = 1;
				peachCuts.animation.play("floats");
			}
			var ic7 = mmGetIconGF();
			if (ic7 != null) {
				if (iconP2 != null) ic7.y = iconP2.y - (mmDownScroll() ? -15 : 35);
				mmIconGFLoad(ic7, "icons/icon-yoshiex");
			}
			if (peachCuts != null) {
				mmExtra.push(FlxTween.tween(peachCuts, {y: -380}, 1.25, {ease: FlxEase.quadInOut}));
				mmExtra.push(FlxTween.tween(peachCuts, {x: -235}, 1.5, {ease: FlxEase.backOut, onComplete: function(twn) {
					mmExtra.push(FlxTween.tween(peachCuts, {y: -200}, 0.4, {startDelay: 0.1, ease: FlxEase.backIn, onComplete: function(twn2) {
						peachCuts.animation.play("fall");
						new FlxTimer().start(0.5833, function(tmr) {
							peachCuts.visible = false;
							var d7 = mmDadChar();
							if (d7 != null) d7.visible = true;
						});
					}}));
				}}));
			}

		case 10:
			// 391 (183.28s): dad is swapped for peach's cut sprite, which then
			// dies and flickers away.
			new FlxTimer().start(1.875, function(tmr) {
				var d10 = mmDadChar();
				if (d10 != null) d10.visible = false;
				if (peachCuts != null) {
					peachCuts.visible = true;
					peachCuts.animation.play("dies");
					peachCuts.x = -500;
					peachCuts.y = -275;
				}
				var g10 = mmGfChar();
				if (g10 != null) g10.playAnim("duro", true);
				new FlxTimer().start(2.5, function(tmr2) {
					mmFlicker(peachCuts, 2, 0.12);
				});
			});

		case 11:
			// 396 (185.62s): the starman GF dies on screen and the icon goes.
			new FlxTimer().start(1.875, function(tmr) {
				var g11 = mmGfChar();
				if (g11 != null) g11.playAnim("death", true);
				if (mmIconGF != null) mmExtra.push(FlxTween.tween(mmIconGF, {alpha: 0}, 0.75, {ease: FlxEase.expoIn}));
				new FlxTimer().start(2.0833, function(tmr2) {
					var g11b = mmGfChar();
					if (g11b != null) g11b.visible = false;
				});
			});

		case 12:
			// 404 (189.375s): horror mario drops in from above and lands in a
			// singDOWN. The source's trailing FOLLOWCHARS/ZOOMCHARS = true are the
			// camera's, and MMcamera schedules them off this trigger's own 1.75s
			// chain (0.8 + 0.6 + 0.35).
			mmChangeChar(1, "mariohorror-melt");
			var d12 = mmDadChar();
			if (d12 == null) return;
			d12.visible = true;
			d12.playAnim("jump", true);
			d12.x -= 800;
			d12.y += 1200;
			FlxTween.tween(d12, {x: d12.x + 800}, .95, {startDelay: 0.8, ease: FlxEase.linear});
			FlxTween.tween(d12, {y: d12.y - 2200}, 0.6, {startDelay: 0.8, ease: FlxEase.quadOut, onComplete: function(twn) {
				d12.playAnim("fall", true);
				FlxTween.tween(d12, {y: d12.y + 1000}, 0.35, {ease: FlxEase.quadIn, onComplete: function(twn2) {
					d12.playAnim("singDOWN", true);
				}});
			}});

		case 16:
			// 512 (240s): the HUD clears for the ending. The source fades
			// timeBarBG/timeBar/timeTxt/customHB as well; none of those is
			// script-reachable here, so the health bar and the two icons stand in
			// (the same substitution allfinal.hx and nesbeat.hx make). camHUD is
			// the catch-all - 'Ocultar HUD' 2 already faded it once at 126.4s and
			// its 1 case brought it back, so it has to be taken out again.
			var d16 = mmDadChar();
			if (d16 != null) FlxTween.tween(d16, {alpha: 0}, 2, {startDelay: 1.875});
			FlxTween.tween(camHUD, {alpha: 0}, 2, {startDelay: 1.875});
			FlxTween.tween(iconP1, {alpha: 0}, 0.5);
			FlxTween.tween(iconP2, {alpha: 0}, 0.5);
			FlxTween.tween(healthBar, {alpha: 0}, 0.5);
			FlxTween.tween(healthBarBG, {alpha: 0}, 0.5);

		case 17:
			// 514 (240.94s) - the last chart event of the song. The black bar is a
			// world sprite (below the characters), so what is not hidden draws over
			// it: boyfriend goes here, gf went at trigger 11, and dad is still fully
			// visible because his own fade (trigger 16) only starts at 241.875s.
			// Screen Shake '3.8, 0.01' with an empty HUD value: the game camera
			// only.
			var b17 = mmBfChar();
			if (b17 != null) b17.visible = false;
			mmBlackBarSpr().visible = true;
			if (platform2 != null) platform2.visible = false;
			FlxG.camera.flash(FlxColor.RED, 0.5);
			camGame.shake(0.01, 3.8);
	}
}

mmPreloadAll();
// === end MM stage triggers ===
