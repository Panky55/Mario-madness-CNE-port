

// === MM stage triggers (auto) ===
// 'Triggers Dark Forest' - ported from PlayState.hx (case 'Triggers Dark
// Forest'). The stage's own two camEst overlays are ported as well: `lluvia`
// (the same 'mario/LuigiBeta/old/Beta_Luigi_Rain_V1' rain sheet betamansion.hx
// uses, 3015-3020) and `fogred` ('modstuff/232', 3021-3026), with the alpha
// writes the triggers make on them (case 1 drops the rain, case 2 raises the
// red fog, case 3 shows the rain for the thunder, case 5 tints it black).
// The stage build (2783-3062) is the whole Coronation scene: `faropapu`,
// `lospapus`, `atrasarboleda`, `aas`, `sopapo`, `casa0`, `casa1`, `s2` and
// `s3` are 4K plates the extractor dropped (its `new FlxSprite(x, y,
// Paths.image(...))` form), so they were added back to forest.xml at the
// source's own coordinates and add() order, and `casa2`/`nerve0`-`nerve3`
// had the extractor's placeholder y=1 replaced with their real ones
// (`casa + -3600` / `casa + -2500`, casa = 300). The create-time loops that
// move them are `mmStartLoops`, and the colour tweens the cases write on them
// are reproduced as well.
//
// Change Character / Play Animation sub-events are handled by the chart's own
// events, except the two the source re-dispatches from cases 1 and 2
// (`peachthe` / `peachtheG`), which the chart does not carry.
//
// Every one of those swaps - those two and the chart's own four (92.8s-94.6s,
// the scream's `peachtheG` flashes) - has to leave the character where the
// source's *group* is. The source's swap-in is pre-created inside the same
// FlxSpriteGroup and rides every move the group makes, and case 1 has already
// carried the dad 3750px down to the treehouse by the time the chart's swaps
// fire: with the swap-in parked at the bare stage node instead, Peach dropped
// back to the empty first-part stage for the whole treehouse act and only came
// back when case 2 reset the node (see mmChangeChar and
// data/events/Change Character.hx).
//
// `case 'forest'` (5856-5861) opens the stage on its act-1 palette: dad, GF and
// BF all 0xFF93ADB5. 'Triggers Dark Forest' 1 (81.88s) then repaints
// dad/BF/capenose - but never GF - and case 2 (105.44s) repaints all four, so
// GF's two colours have to be written here.
//
// Camera: `songs/MMcamera.hx` drives this stage, and it writes camFollow every
// frame - so the cases that move the camera (5's `camFollowPos.y -> 150`, 11's
// pan to BF_CAM, 13's `y -> -3250`) go through the api it publishes through
// the engine's ScriptPack, and its `FOLLOWCHARS`/`ZOOMCHARS` writes (cases 1, 8,
// 9 and 12) through `follow`/`zoomFollow`. Writing the fields directly is what the source
// does to a *different* object (`camFollowPos`), which does not exist here.
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

// The source's `blackBarThingie`: created at alpha **1** (5014-5018), so the
// stage loads on black, lifted by the opening below, and raised again by case
// 14's end-of-song blackout (13577-13578). The source puts it on camEst; the
// port's screen-space copy is equivalent for a 10x black plate (it covers the
// screen at any zoom) and keeps the HUD, which camEst would already be under,
// readable.
var mmBlackBar:FlxSprite;
function mmGetBlackBar():FlxSprite {
	if (mmBlackBar == null) {
		mmBlackBar = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		mmBlackBar.scale.set(10, 10);
		mmBlackBar.scrollFactor.set(0, 0);
		mmBlackBar.alpha = 1;
		add(mmBlackBar);
	}
	return mmBlackBar;
}

// ---------------------------------------------------------------------------
// camEst (5020-5027)
// ---------------------------------------------------------------------------
// The stage's opening plate lives on Psych's camEst: the same view rectangle as
// the HUD, composited between the world's and the HUD's canvas. Codename ships
// only camGame and camHUD, so the port adds a camera of its own the normal way
// (`defaultDraw = false`) and slides it in at camHUD's own index.
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
			trace("[MM forest] camEst: no FlxG.cameras.list - startbf stays above camHUD");
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

// 3015-3026: the stage's two camEst overlays, both screen-fixed on the layer the
// camera below gives them. `lluvia` is a rain sheet at 1.7x starting invisible
// behind an alpha 0.6 - case 3 is what shows it - and `fogred` is the
// 'modstuff/232' red fog, dark until case 2.
var mmLluvia = null;

function mmGetLluvia() {
	if (mmLluvia == null) {
		mmLluvia = new FunkinSprite(-170, 50);
		mmLluvia.frames = Paths.getSparrowAtlas('mario/LuigiBeta/old/Beta_Luigi_Rain_V1');
		mmLluvia.animation.addByPrefix('RainLuigi', 'RainLuigi', 24, true);
		mmLluvia.animation.play('RainLuigi');
		mmLluvia.setGraphicSize(Std.int(mmLluvia.width * 1.7));
		mmLluvia.alpha = 0.6;
		mmLluvia.visible = false;
		mmLluvia.antialiasing = true; // ClientPrefs.globalAntialiasing, taken as on
		mmLluvia.cameras = [mmEst()];
		add(mmLluvia);
	}
	return mmLluvia;
}

var mmFogRed = null;

function mmGetFogRed() {
	if (mmFogRed == null) {
		mmFogRed = new FlxSprite(0, 0);
		mmFogRed.loadGraphic(Paths.image('modstuff/232'));
		mmFogRed.antialiasing = true; // ClientPrefs.globalAntialiasing, taken as on
		mmFogRed.cameras = [mmEst()];
		mmFogRed.alpha = 0;
		mmFogRed.screenCenter();
		add(mmFogRed);
	}
	return mmFogRed;
}

// 5020-5027: `startbf`, the 'modstuff/hatestart' plate at 3x, screen-centred on
// camEst at alpha 0 - flashed for one second by the opening below. It is the
// same asset hatebg.hx uses for I Hate You / Oh God No (whose 'M' variant is
// the OGN one; Dark Forest's is the plain one).
var mmStartBf = null;

function mmGetStartBf() {
	if (mmStartBf == null) {
		mmStartBf = new FlxSprite(0, 0);
		mmStartBf.loadGraphic(Paths.image('modstuff/hatestart'));
		mmStartBf.setGraphicSize(Std.int(mmStartBf.width * 3));
		mmStartBf.antialiasing = false;
		mmStartBf.updateHitbox();
		mmStartBf.cameras = [mmEst()];
		mmStartBf.alpha = 0;
		mmStartBf.screenCenter();
		add(mmStartBf);
	}
	return mmStartBf;
}

// The opening (6399-6417, the `curStage == 'hatebg' || curStage == 'forest'`
// half of the source's countdown branch - which is why the port wires it for
// both stages): 0.8s in, the hatestart plate flashes with the 'smw_coin'
// cue; a second later it goes and the curtain lifts over one
// second. Dark Forest is a `noCount` stage (2784) whose `else` branch starts
// the song straight away, so this hangs off onSongStart rather than a countdown
// the engine never runs.
var mmIntroDone:Bool = false;

function mmForestIntro() {
	if (mmIntroDone) return;
	mmIntroDone = true;

	new FlxTimer().start(0.8, function(tmr) {
		mmGetStartBf().alpha = 1;
		FlxG.sound.play(Paths.sound('smw_coin'));
	});

	new FlxTimer().start(1.8, function(tmr) {
		mmGetStartBf().alpha = 0;
		FlxTween.tween(mmGetBlackBar(), {alpha: 0}, 1, {ease: FlxEase.quadOut});
	});
}

function onSongStart() {
	mmForestIntro();
}

// ---------------------------------------------------------------------------
// Character resolution and the source's group coordinates
// ---------------------------------------------------------------------------
// A script's `dad` / `boyfriend` / `gf` are a snapshot of the play state taken
// when the script loads: after a swap they still name the character the swap
// *replaced* (the same hazard songs/MMcamera.hx records for wario, and why
// data/stages/allfinal.hx's act 2 note says "omega is not the object the `dad`
// global still names, so the old write went nowhere"). Dark Forest swaps the
// opponent three times itself - case 0's `peachtalk1`, case 1's `peachthe`,
// case 2's `peachtheG` - plus the chart's own four, so every write that can run
// after 72.88s goes through the strumline and never through the script global.
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

// In the generated charts the opponent strumline is first, the player
// strumline second, the girlfriend third - the same order
// data/events/Change Character.hx uses.
function mmDadChar() return mmMem(0);
function mmBfChar() return mmMem(1);

// The source moves whole FlxSpriteGroups (`dadGroup.y += -3750`,
// `boyfriendGroup.y = -3800`, `dad.x = 100`) and a ported character has no
// group: the group's position has to be recovered from, and written back to,
// the character. Character.playAnim ends in
//     offset.set((isPlayer != playerOffsets) ? globalOffset.x : -globalOffset.x,
//                -globalOffset.y);
// so the sprite *renders* at `stored.x - k * globalOffset.x` /
// `stored.y + globalOffset.y` with k = (isPlayer != playerOffsets) ? 1 : -1,
// while the source renders it at `group + position` - the same derivation
// exeport.hx / exesequel.hx / allfinal.hx document, i.e.
//     stored.x = groupX + (k + 1) * globalOffset.x
//     stored.y = groupY                     (y carries no k)
// Every character in this song is on the opponent side (k = -1), for which the
// two coincide and a plain x/y write already *is* the group write; the helpers
// keep it exact for a character whose side flips the sign.
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

function mmGroupXTo(c, gx:Float):Float {
	if (c == null) return gx;
	return gx + (mmSideK(c) + 1) * c.globalOffset.x;
}

// Where the source's `group` puts `c` (the group x/y writes).
function mmPlaceGroup(c, gx:Float, gy:Float) {
	if (c == null) return;
	c.x = mmGroupXTo(c, gx);
	c.y = gy;
}

// Where an *absolute* sprite write puts `c`: the source's `dad.x = 100` is the
// sprite's own x (FlxSpriteGroup.add bakes the group's x/y into each child once,
// at add time, so by act 3 the child's x is the position itself). Only case 2
// writes one; every other character write in this song is a group write.
function mmPlaceWorld(c, worldX:Float, worldY:Float) {
	if (c == null) return;
	c.x = worldX + mmSideK(c) * c.globalOffset.x;
	c.y = worldY - c.globalOffset.y;
}

// Case 0's two sub-events. The source re-dispatches them into
// data/events/Change Character.hx and data/events/MM Play Animation.hx, but the
// dark-forest chart does *not* carry them itself (it fires only `Triggers Dark
// Forest 0` at 72.88s), so without this case the cutscene's first act kept the
// previous dad and never played 'talk'. Same swap as data/events/Change
// Character.hx (value2 = character name, value1 = 1 for the opponent line).
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
	// `Reflect.hasField` answers false for every member of a class *instance* on
	// the cpp build, so this guard was dead in the shipped game (see
	// PORT_NOTES.md). `Reflect.field` resolves the member on both targets.
	if (Reflect.field(ic, "setIcon") == null || Reflect.field(c, "getIcon") == null) return;
	var n = c.getIcon();
	if (n != null && n != "") ic.setIcon(n);
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
	// The source's swap-in is not repositioned at all: 'Change Character' picks
	// the character out of dadMap (`dadGroup.add` + `startCharacterPos`,
	// 6081-6122) and it keeps the group it was built in - `group + its own
	// position`. The node applyCharStuff parks it on is only the group's
	// position while the group still sits at its default, which stops being true
	// the moment case 1 moves the dad 3750px down; the chart's dialogue swaps at
	// 92.8s-94.6s then dropped Peach back to the empty first-part stage.
	var gx:Float = mmGroupX(old);
	var gy:Float = mmGroupY(old);
	var oldIndex:Int = members.indexOf(old);

	remove(old);
	member.characters.remove(old);

	var fresh = new Character(0, 0, name, isPlayer);
	stage.applyCharStuff(fresh, member.data.position, 0);
	// The source's group keeps its draw slot across a swap, so the fresh
	// character goes back where the outgoing one was in the state's list (not
	// where applyCharStuff left it).
	mmPlaceGroup(fresh, gx, gy);
	// The source keeps the Peach variants inside dadGroup: the opening
	// (5859) and treehouse (13376) group tints also colour the hidden variants.
	// This port rebuilds each variant as a white sprite, so carry the current
	// lighting across a swap. Cases 1/2 still set their new palettes below.
	// The chart's scream swaps need the same carry in Change Character.hx.
	fresh.color = old.color;
	if (oldIndex >= 0) {
		remove(fresh);
		insert(oldIndex, fresh);
	}
	// The source's death character is a global (GameOverSubstate.characterName) and
	// survives a swap; this port keeps it on the character (see songs/MMcamera.hx's
	// game-over table), so the current one has to ride across.
	fresh.gameOverCharacter = old.gameOverCharacter;
	member.characters.insert(0, fresh);
	mmSwapIcon(index, fresh);
	// The source's tweens sit on the group, not on the sprite, so the act's
	// ping-pong keeps driving whatever character is live.
	mmRetargetPingpong();
}

// The fork's `remove(x); add(x)` idiom, done the way this engine needs it: a
// bare `remove` only nulls the slot and `add` re-fills that same slot, so the
// splice is what actually moves the sprite. Appending puts it in front of the
// characters, which is where the source's own foreground `add()`s land.
function mmToFront(obj) {
	if (obj == null) return obj;
	remove(obj, true);
	insert(members.length, obj);
	return obj;
}

// ---------------------------------------------------------------------------
// Create-time motion, dad's ping-pong bookkeeping and the cape BF
// ---------------------------------------------------------------------------
// 2906-2997: the loops the source starts at create - the `thenerve` plates
// drift and the leaves fall and the two balls bounce. They are FlxTween loops,
// which a stage XML cannot carry. nerve4/5 are left out because the source
// creates those two locals but never `add()`s them (2891/2895 are a copy-paste
// slip that re-`add`s nerve0/nerve1), so their tweens have nothing to move here
// either - the XML's two nerve extras stay hidden.
function mmStartLoops() {
	FlxTween.tween(nerve0, {y: -5000}, 4.5, {type: FlxTween.LOOPING, loopDelay: 0.2});
	FlxTween.tween(nerve1, {y: -5000}, 4, {type: FlxTween.LOOPING, loopDelay: 0.3});
	FlxTween.tween(nerve2, {y: -5000}, 3, {type: FlxTween.LOOPING, loopDelay: 0.6});
	FlxTween.tween(nerve3, {y: -5000}, 3, {type: FlxTween.LOOPING, loopDelay: 0.5});
	FlxTween.tween(nerve0, {x: -450}, 0.4, {type: FlxTween.PINGPONG});
	FlxTween.tween(nerve1, {x: 350}, 0.2, {type: FlxTween.PINGPONG});
	FlxTween.tween(nerve2, {x: 850}, 0.3, {type: FlxTween.PINGPONG});
	FlxTween.tween(nerve3, {x: 250}, 3.5, {type: FlxTween.PINGPONG});
	FlxTween.tween(leaf0, {y: 1500, x: leaf0.x + 500}, 1.3, {type: FlxTween.LOOPING, loopDelay: 0.3});
	FlxTween.tween(leaf1, {y: 1500, x: leaf1.x + 500}, 1, {type: FlxTween.LOOPING});
	FlxTween.tween(leaf2, {y: 1500, x: leaf2.x + 500}, 1, {type: FlxTween.LOOPING, loopDelay: 0.6});
	FlxTween.tween(bola0, {x: 1100}, 0.5, {ease: FlxEase.quadInOut, type: FlxTween.PINGPONG});
	FlxTween.tween(bola1, {x: 400}, 0.5, {ease: FlxEase.quadInOut, type: FlxTween.PINGPONG});
	FlxTween.tween(bola0, {y: 1500}, 4, {type: FlxTween.LOOPING, loopDelay: 1});
	FlxTween.tween(bola1, {y: 1500}, 4, {type: FlxTween.LOOPING, loopDelay: 0.6});
}

// 5009-5016: the source remembers dad's position when the stage is built
// (`enemyY = dad.y; enemyX = dad.x`) and cases 1/2/10 pan their ping-pong
// tweens around those *captured* values, not around wherever dad happens to be
// when the trigger fires. Cases 1 and 2 overwrite the pair with the position
// they just parked him at, which is what makes the same two tweens reappear
// with new targets.
var mmEnemyX:Float = 0;
var mmEnemyY:Float = 0;

// The source's `extraTween` list: the dad ping-pongs, cancelled whole by cases
// 1 and 2 before they start their own. `mmPingOn`/`mmPingDy`/`mmPingTarget`
// are the port's own bookkeeping for the pair (see mmRetargetPingpong).
var mmExtra:Array<FlxTween> = [];
var mmPingOn:Bool = false;
var mmPingDy:Float = 0;
var mmPingTarget = null;

function mmExtraCancel() {
	for (t in mmExtra) if (t != null) t.cancel();
	mmExtra = [];
	mmPingOn = false;
	mmPingTarget = null;
}

// The source's pair is `dadGroup -> {x: enemyX - 220}` / `{y: enemyY ± dy}`,
// i.e. the *group* moves and the character rides it: -220 on x and dy on y,
// measured from wherever the character stands when the pair starts. x is
// written as that delta rather than `mmEnemyX - 220` because case 2's
// `dad.x = 100` moves the sprite while the group stays where the cancelled pair
// left it - the group still only shifts by -220, and an absolute target read
// off the character would land 2 * globalOffset.x away. y has no such sprite
// write, so `mmEnemyY` (the character's own y, i.e. the group's) is exact.
function mmDadPingpongNow(dy:Float) {
	mmPingOn = true;
	mmPingDy = dy;
	var d = mmDadChar();
	if (d == null) return;
	mmPingTarget = d;
	mmExtra.push(FlxTween.tween(d, {x: d.x - 220}, 4, {ease: FlxEase.quadInOut, type: FlxTween.PINGPONG}));
	mmExtra.push(FlxTween.tween(d, {y: mmEnemyY + dy}, 1.4, {ease: FlxEase.quadInOut, type: FlxTween.PINGPONG}));
}

// A swap replaces the character the pair drives. The source's tweens sit on the
// group and never notice a swap, so rebuild the pair on the live character.
// (The chart's own swaps run in data/events/Change Character.hx, which cannot
// reach these tweens; beatHit re-checks the target for those.)
function mmRetargetPingpong() {
	if (!mmPingOn) return;
	for (t in mmExtra) if (t != null) t.cancel();
	mmExtra = [];
	mmDadPingpongNow(mmPingDy);
}

// Cases 1 and 2 wait 0.2s before starting dad's pair; case 10 starts it on the
// spot.
function mmDadPingpong(dy:Float) {
	new FlxTimer().start(0.2, function(tmr) mmDadPingpongNow(dy));
}

// 15197/15383/15421 + the beat restore at 16275: the cape BF behind the
// fighters takes his miss pose when the player misses and goes back to his
// idle on a hit, a miss-press included.
function mmCapeIdle() {
	if (capenose != null) capenose.playAnim('idle', true);
}

function onPlayerMiss(event) {
	if (capenose != null) capenose.playAnim('miss', true);
}

function onNoteHit(event) {
	if (event.player) mmCapeIdle();
}

function onCountdown(event) {
	// `noCount = true` (2784): the source never builds its 3-2-1-GO sprites.
	event.cancelled = true;
}

function postCreate() {
	// `noHUD = true` (2785) -> 5630-5633. The chart's own 'Ocultar HUD' 2 brings
	// the HUD back at 2.82s.
	if (camHUD != null) camHUD.alpha = 0;
	// 3015-3026 and 5014-5027: the stage's camEst overlays and the curtain, all
	// created here, before the first frame - the source's create order too
	// (lluvia, fogred, then the curtain and the opening plate).
	mmGetLluvia();
	mmGetFogRed();
	mmGetBlackBar();
	mmGetStartBf();
	var dTint = mmDadChar();
	var bTint = mmBfChar();
	if (dTint != null) dTint.color = 0xFF93ADB5;
	if (bTint != null) bTint.color = 0xFF93ADB5;
	if (gf != null) gf.color = 0xFF93ADB5;
	// 3035/3042: these are separate sprites, outside the character groups.
	if (capenose != null) capenose.color = 0xFF93ADB5;
	if (fresco != null) fresco.color = 0xFF93ADB5;
	// 2906-2997: the source's looping tweens, started in the stage branch.
	mmStartLoops();
	// 5009-5016: dad's captured position, for cases 1/2/10.
	var dCap = mmDadChar();
	if (dCap != null) {
		mmEnemyX = mmGroupX(dCap);
		mmEnemyY = mmGroupY(dCap);
	}

	// 4361-4373: the foreground switch re-adds these eleven *after* the
	// character groups, so in the source they all draw over the fighters. The
	// stage XML carries them as ordinary children (below the character band), so
	// each is lifted to the end of the state's draw list in the source's own
	// order - fresco is the bottom of the eleven, bola1 the top.
	for (s in [fresco, glitch0, glitch1, glitch2, glitch3, cososuelo, leaf0, leaf1, leaf2, bola0, bola1]) mmToFront(s);
}

// The source Lua re-dispatches these stage effects outside the chart.
function beatHit(curBeat) {
	// 16275: once BF is done singing the source restores the cape BF's idle on
	// the beat. BF's own miss poses keep it off until he dances again (the
	// source's `boyfriend.dance()` branch is the same condition).
	var nm:String = (boyfriend != null && boyfriend.animation != null && boyfriend.animation.curAnim != null)
		? boyfriend.animation.curAnim.name : null;
	if (nm == null || (!StringTools.startsWith(nm, "sing") && nm.indexOf("miss") < 0)) mmCapeIdle();

	// The chart's dialogue swaps (92.8s-94.6s) run in
	// data/events/Change Character.hx, which cannot see this script's pair: the
	// source's group tweens ride a swap, so hand the pair to the live character.
	var dLive = mmDadChar();
	if (mmPingOn && dLive != null && mmPingTarget != dLive) mmRetargetPingpong();

	if (curBeat % 8 == 0 && curBeat >= 136 && curBeat <= 199)
		onEvent({event: {name: "Triggers Dark Forest", params: ["4", ""]}});
	if (curBeat >= 300)
		onEvent({event: {name: "Triggers Dark Forest", params: ["6", ""]}});
}

function stepHit(curStep) {
	// assets/preload/data/songData/dark-forest/script.lua `onStepHit`: the
	// scream. Its four steps land on the chart's own scream events
	// (92.82s-94.59s), but the zoom and the HUD strobe are lua-only. Step
	// 1052's `doTweenZoom` is the source's own camGame.zoom tween and goes
	// through MMcamera like every other camera write this stage makes
	// (MMcamera owns camGame.zoom; ZOOMCHARS stays on here, so once the tween
	// ends the section zoom takes the camera back - the source's ZOOMCHARS
	// block keeps rewriting defaultCamZoom throughout). The alpha tweens are
	// plain: nothing else in the song touches camHUD.alpha after the chart's
	// 'Ocultar HUD' 2 brought it back at 81.97s.
	if (curStep == 1052) {
		mmCam("zoom", [1, 0.5, 0, FlxEase.cubeOut]);
		if (camHUD != null) FlxTween.tween(camHUD, {alpha: 0.5}, 0.10, {ease: FlxEase.linear});
	}
	if (curStep == 1056 && camHUD != null)
		FlxTween.tween(camHUD, {alpha: 1}, 0.10, {ease: FlxEase.linear});
	if (curStep == 1068) {
		mmCam("zoom", [1, 0.4, 0, FlxEase.cubeOut]);
		if (camHUD != null) FlxTween.tween(camHUD, {alpha: 0}, 0.10, {ease: FlxEase.linear});
	}
	if (curStep == 1072 && camHUD != null)
		FlxTween.tween(camHUD, {alpha: 1}, 0.10, {ease: FlxEase.linear});

	if (curStep > 160 && curStep < 1190)
		onEvent({event: {name: "Triggers Dark Forest", params: ["7", ""]}});
	if (curStep > 1200)
		onEvent({event: {name: "Triggers Dark Forest", params: ["7", "1"]}});
}

function onEvent(event) {
	if (event.event.name != "Triggers Dark Forest" && event.event.name != "Triggers Universal") return;
	var trigger = Std.parseInt(event.event.params[0]);
	if (trigger == null || Math.isNaN(trigger)) trigger = 0;
	switch (trigger) {
		case 0:
			// 13359-13361, cutscene part 1: dad becomes `peachtalk1` and talks.
			mmChangeChar(1, "peachtalk1");
			var d0 = mmDadChar();
			if (d0 != null) d0.playAnim("talk", true);
		case 1:
			// 13403-13408: the treehouse act's own swap and plate. The chart
			// does not carry this one (its four Change Character events are the
			// dialogue swaps at 92.8s-94.6s), so the re-dispatch is the only
			// thing that turns dad into `peachthe` here, and `casa0` is the
			// second-part plate it reveals.
			// 13409-13411: the outgoing character's pair is cancelled first, so the
			// character coming in is not handed its tweens.
			mmExtraCancel();
			mmChangeChar(1, "peachthe");
			// The source's `dadGroup`/`boyfriendGroup` ride a swap; a ported
			// character does not, so every write below resolves the live one - the
			// script's `dad` still names the character case 0 replaced.
			var d1 = mmDadChar();
			var b1 = mmBfChar();
			if (casa0 != null) casa0.visible = true;
			mmCam("follow", [true]);
			mmCam("zoomFollow", [true]);
			// 13416-13417: DAD_CAM_Y / BF_CAM_Y - the section rows the camera
			// pans along while following the fighters down to the house.
			mmCam("setCam", ["dad", 220, -3450, null]);
			mmCam("setCam", ["bf", 1020, -3250, null]);
			// 13397: the rain goes as the act does.
			FlxTween.tween(mmGetLluvia(), {alpha: 0}, 0.5, {ease: FlxEase.quadOut});
			if (d1 != null) {
				d1.color = 0xFF758186;
				d1.visible = true;
				// 13412: `dadGroup.y += -3750` - y is the group's own axis, so the
				// character takes the same delta.
				d1.y += -3750;
			}
			if (b1 != null) {
				b1.color = 0xFFBECDD4;
				b1.visible = true;
				b1.y = -3800; // 13413: boyfriendGroup.y = -3800
			}
			capenose.color = 0xFFBECDD4;
			capenose.visible = true;
			capenose.y = ((b1 != null) ? b1.y : -3800) + 460;
			FlxTween.tween(camGame, {zoom: 0.65}, 1.4, {ease: FlxEase.sineOut});
			if (b1 != null)
				FlxTween.tween(b1, {y: -3550}, 1, {startDelay: 0.5 * (1 / (Conductor.bpm / 60)), ease: FlxEase.bounceOut});
			FlxTween.tween(capenose, {y: -3090}, 1, {startDelay: 0.5 * (1 / (Conductor.bpm / 60)), ease: FlxEase.bounceOut});
			// 13419-13425: dad's pair, off the position this case parked him at.
			mmEnemyY = mmGroupY(d1);
			mmEnemyX = mmGroupX(d1);
			mmDadPingpong(100);
		case 2:
			// 13452-13454: like case 1, the chart does not carry this swap - the
			// source turns dad into `peachtheG` here.
			mmExtraCancel();
			mmChangeChar(1, "peachtheG");
			var d2 = mmDadChar();
			var b2 = mmBfChar();
			// 13480 (`enemyX = dadGroup.x`): captured before `dad.x = 100` below,
			// which moves the sprite and not the group.
			var gx2:Float = mmGroupX(d2);
			// 13473-13474: the third act's own section rows.
			mmCam("setCam", ["dad", 220, 150, null]);
			mmCam("setCam", ["bf", 1020, 550, null]);
			fresco.visible = false;
			for (s in [seaweed1, seaweed2, seaweed3, glitch0, glitch1, glitch2, glitch3, cososuelo, leaf0, leaf1, leaf2, bola0, bola1]) s.visible = true;
			if (gf != null) gf.color = 0xFFB8837F; // gfGroup.color = color1
			if (b2 != null) {
				b2.color = 0xFFB8837F;
				b2.y = 250; // 13450: boyfriendGroup.y = 250
			}
			capenose.color = 0xFFB8837F;
			capenose.y = ((b2 != null) ? b2.y : 250) + 460;
			if (d2 != null) {
				d2.color = 0xFFB8837F;
				// 13447-13449: `dadGroup.y = -200` (a group write) and then
				// `dad.x = 100`, the one *sprite* write in the song: an absolute x,
				// which puts the character at 100 wherever the group sits.
				d2.y = -200;
				mmPlaceWorld(d2, 100, d2.y + d2.globalOffset.y);
			}
			// 13478-13485: dad's pair again, off the parked position.
			mmEnemyY = mmGroupY(d2);
			mmEnemyX = gx2;
			mmDadPingpong(-100);
			// 13455: the third act raises the red fog over half a second.
			FlxTween.tween(mmGetFogRed(), {alpha: 0.8}, 0.5, {ease: FlxEase.quadOut});
		case 3:
			// 13456-13462: the thunder act's white flash, and the rain comes back
			// (both under `ClientPrefs.flashing`, taken as on).
			FlxG.camera.flash(FlxColor.WHITE, 1);
			mmGetLluvia().visible = true;
		case 4:
			// The thunder beats (136-199, 48s-70s) run before the first swap in
			// this song, but the source's tweens sit on the groups and survive one;
			// resolve the live characters like every other case.
			var d4 = mmDadChar();
			var b4 = mmBfChar();
			trueno.visible = true;
			trueno.playAnim("rayo");
			trueno.x = FlxG.random.float(-180, 600);
			trueno.flipX = FlxG.random.bool(50);
			FlxG.sound.play(Paths.sound("smw_thunder" + FlxG.random.int(1, 3)));
			new FlxTimer().start(0.2917, function(tmr) { trueno.visible = false; });
			FlxTween.color(d4 != null ? d4 : dad, 1.3, 0xFF353F42, 0xFF93ADB5, {startDelay: 0.2, ease: FlxEase.quadOut});
			FlxTween.color(gf, 1.3, 0xFF353F42, 0xFF93ADB5, {startDelay: 0.2, ease: FlxEase.quadOut});
			FlxTween.color(b4 != null ? b4 : boyfriend, 1.3, 0xFF353F42, 0xFF93ADB5, {startDelay: 0.2, ease: FlxEase.quadOut});
			FlxTween.color(capenose, 1.3, 0xFF353F42, 0xFF93ADB5, {startDelay: 0.2, ease: FlxEase.quadOut});
			// 13492-13497: the six forest plates flash grey with each strike.
			for (bg in [lospapus, atrasarboleda, aas, sopapo, s3, s2])
				FlxTween.color(bg, 1.3, 0xFF808080, FlxColor.WHITE, {startDelay: 0.2, ease: FlxEase.quadOut});
			camGame.shake(0.03, 0.15);
		case 6:
			glitch0.x = FlxG.random.float(-200, 1500);
			glitch1.x = FlxG.random.float(-200, 1500);
			glitch2.x = FlxG.random.float(-200, 1500);
			glitch3.x = FlxG.random.float(-200, 1500);
			glitch0.y = FlxG.random.float(200, 1200);
			glitch1.y = FlxG.random.float(200, 1200);
			glitch2.y = FlxG.random.float(200, 1200);
			glitch3.y = FlxG.random.float(200, 1200);
			glitch0.scale.set(FlxG.random.float(1, 5), FlxG.random.float(1, 5));
			glitch1.scale.set(FlxG.random.float(1, 5), FlxG.random.float(1, 5));
			glitch2.scale.set(FlxG.random.float(1, 5), FlxG.random.float(1, 5));
			glitch3.scale.set(FlxG.random.float(1, 5), FlxG.random.float(1, 5));
		case 7:
			var gota = new FunkinSprite(FlxG.random.int(-300, 2070), FlxG.random.int(800, 1000));
			gota.frames = Paths.getSparrowAtlas("mario/LuigiBeta/gota");
			gota.animation.addByPrefix("rain", "rain", 24, false);
			gota.animation.play("rain");
			if (Std.string(event.event.params[1]) == "1") gota.color = 0xFF000000;
			if (gota.y > 950) add(gota); else insert(members.indexOf(gf) - 1, gota);
			gota.alpha = 0.4;
			FlxTween.tween(gota, {alpha: 0}, 2, {startDelay: 0.3, onComplete: function(twn) { gota.destroy(); }});
		case 5:
			// 13499-13512: `camFollowPos.y -> 150` over 5 beats, plus the colour
			// tweens of the rain and the seven forest plates.
			mmCam("lock", [camFollow.x, 150, (5 * (1 / (Conductor.bpm / 60))), FlxEase.cubeInOut]);
			FlxTween.color(mmGetLluvia(), 0.5, 0x00000000, FlxColor.BLACK, {startDelay: 0.7, ease: FlxEase.quadOut});
			// 13502-13508: the forest plates take the same angry red as the cast.
			for (bg in [faropapu, lospapus, atrasarboleda, aas, sopapo, s3, s2])
				FlxTween.color(bg, 1.3, FlxColor.WHITE, 0xFFFF8B82, {startDelay: 0.2, ease: FlxEase.quadOut});
		case 8:
			// 13546-13550: `FOLLOWCHARS = false; ZOOMCHARS = false;` plus the two
			// camera tweens - the zoom to 0.8 and camFollowPos to the DAD row.
			// (The chart fires this one early, at 1.41s: 'Triggers Universal' 8
			// re-dispatches as this group, so the intro holds this framing until
			// case 9 releases it at 2.82s.)
			mmCam("follow", [false]);
			mmCam("zoomFollow", [false]);
			FlxTween.tween(camGame, {zoom: 0.8}, 1.5, {ease: FlxEase.cubeInOut});
			mmCam("lock", [220, 150, 1.5, FlxEase.cubeInOut]);
		case 9:
			// 13553-13555: `FOLLOWCHARS = true; ZOOMCHARS = true;`
			mmCam("follow", [true]);
			mmCam("zoomFollow", [true]);
		case 10:
			// 13527-13530, the source's own 'time for nate code' case: the same
			// pair case 1 starts, immediately and off the same captured position.
			mmDadPingpongNow(100);
		case 11:
			// 13561-13562: `camFollowPos -> (BF_CAM_X, BF_CAM_Y)` over 2 beats
			// (forest's own preload row: 1020, 550).
			mmCam("lock", [1020, 550, (2 * (1 / (Conductor.bpm / 60))), FlxEase.cubeInOut]);
		case 12:
			// 13564-13567: `FOLLOWCHARS = false; ZOOMCHARS = true;`
			mmCam("follow", [false]);
			mmCam("zoomFollow", [true]);
			// The source hides the two *groups*; both swaps before this one
			// replaced their characters, so resolve them.
			var d12 = mmDadChar();
			var b12 = mmBfChar();
			if (d12 != null) d12.visible = false;
			if (b12 != null) b12.visible = false;
			capenose.visible = false;
			fresco.alpha = 1;
			fresco.playAnim("llevar");
		case 13:
			FlxTween.tween(fresco, {y: -865}, (3 * (1 / (Conductor.bpm / 60))), {ease: FlxEase.quadIn});
			mmCam("lock", [camFollow.x, -3250, (4 * (1 / (Conductor.bpm / 60))), FlxEase.expoInOut]);
		case 14:
			// 13577-13578: `blackBarThingie.alpha = 1` - the end-of-song blackout.
			mmGetBlackBar().alpha = 1;
	}
}
// === end MM stage triggers ===
