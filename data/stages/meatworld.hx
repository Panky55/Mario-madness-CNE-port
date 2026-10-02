

// === MM stage triggers (auto) ===
// 'Triggers Overdue' - ported from PlayState.hx:13943-14130, together with the
// stage half of `case 'meatworld'` (3411-3628, 4454-4457, 8019-8031, 8581-8585,
// 16111-16137) and the camera half in songs/MMcamera.hx (mmOverdueTrigger).
//
// `overdue` and `overdue-old` share this stage and the source's group is written
// for both: the values are the same indices (`overdue-old`'s chart sends a
// subset - 3/4/6/14/15/16 - and its own gunAmmo starting values, see mmCreateGun).
//
// What the group does, in order of the song:
//   2  (20.21s)  the camera drops into the opening shot (MMcamera)
//   1  (24.01s)  the poison starts draining dad's health (0.005/hit, and the
//                chart's second call at 171.71s takes it to 0.0175)
//   14 (83.37s)  the close-up on BF (MMcamera)
//   3  (84.34s)  the meat foreground slams down: the bottom teeth (ID 1) drop
//                with the 'teethslam' sound and the top teeth (ID 2) slide in
//   4  (84.71s)  the street is destroyed, both fighters are moved, the meat
//                world arrives at BF_ZOOM 0.45 / DAD_ZOOM 0.35 and the fog comes
//                up, the second teeth (ID 2) drops out of the world
//   5  (135.16s) the third health icon (latemario) joins the HUD and gf drifts
//                while the camera pulls to BF
//   6  (161.68s) the castle floor and ceiling fade up while the meat fades out
//   7  (171.79s) the hallway: the three TLL backdrops and the foreground one
//                slide in, dad is thrown off screen, GF leaves, BF becomes
//                `pico_run` - whose own script gets the 'fuckoff' tag here and
//                builds its running rig - and the health bar flips
//   8  (212.21s) the hallway fades out
//   9  (214.74s) camGame and camHUD are turned off (the song is over)
//   10 (45.47s)  the bullet ammo counter slides up and dims
//   12 (93.9s)   BF drifts right, ping-ponging
//   13 (170.86s) the ammo and the third icon fade out
//   15/16        the camera zooms for the final sections (MMcamera)
//
// Stage-level behaviour that comes with the case:
//   3412       `gfGroup.alpha = 0.00000001` - GF is invisible until case 5.
//   3413-3418  the three `addCharacterToList` preloads (`picodeath`, `picodiag`,
//              `pico_run`) and the chart's own swap targets (`picodiag`, `pico`,
//              `luigi-toolate`) are warmed at script load by mmPreloadAll; the
//              `GameOverSubstate`'s character / death sound / loop are written
//              by mmGameOver.
//   3419-3428  `castleFloor`/`castleCeiling` (in the XML, with their Floor/Top
//              animations) start at alpha 0 and are played `idle`.
//   3429-3450  the street: four sprites in the XML, one `FlxTypedGroup` there -
//              case 4 destroys the lot, so they are tracked as a set here.
//   3451-3520  the two meat groups: six world sprites (`TL_Meat_*`) and five
//              foreground ones (`TL_Meat_FG_*`/`TL_Meat_CloseFG`), each with an
//              `ID` the group's cases address (1 = the pupil, 2 = the second
//              teeth...), a per-sprite scale and a `setPosition(x + width / n,
//              y + height / n)` offset the extractor folded into the XML's scale
//              instead. mmFixMeat() puts the source's own values back.
//   3521-3532  both groups are built invisible and at alpha 0.
//   3534-3538  `gunShotPico` - a muzzle-flash atlas that follows BF every frame.
//   3540-3545  `fogblack` ('modstuff/126', a vignette) on camEst, alpha 1.
//   3547-3552  `meatfog` ('TL_Meat_Fog', a noise plate) on camEst, alpha 0.
//   3554-3592  the four `FlxBackdrop`s (three `Too_Late_Luigi_Hallway` copies and
//              the FG one). See the stand-in below.
//   3597-3602  `blackBarThingie`.
//   3604-3619  `gunAmmo`: the bullet counter, on camEst, alpha 0.8 (0.2 and y 450
//              for Overdue Old).
//   3621-3628  `iconGF`: `icons/icon-latemario`, camHUD, alpha 0, flipX.
//   629/15275  the gun: `ammo` starts at 3, every *missed* 'Bullet' note takes
//              one off and re-animates the counter ('Bullet <n>'), restarts the
//              dim-and-slide tween on it and flashes it black->white, and the
//              fourth miss is fatal (`health = 0`). See mmShoot/onPlayerMiss.
//   10757-10796 the 'Pico Shoot' event the source fires from every *hit*
//              'Bullet' note (15608-15611): `gunShotPico` on, BF and dad out, a
//              random +/-5 degree camera tilt, the 'Screen Shake' (skipped on
//              beats 204-268), the 40fps 'Shoot' strip, dad back over 0.7s, the
//              tilt out over 0.2s and the flash off after 0.3s. mmShoot().
//   4454-4457  `add(streetFore); add(meatForeGroup); add(fgTLL);` run in the
//              *foreground* switch - the street's front trees, the meat
//              foreground and the hallway foreground are all in front of the
//              fighters there, so postCreate lifts them out of the world layer
//              with mmToFront (the fork's `remove(x); add(x)` has to be written
//              as a splice + append here - see that function).
//   8019-8031  the per-frame controller (gunShotPico, iconGF).
//   8581-8585  dad's note hits drain `poison` while he is `luigi-toolate`, and
//              kick hallTLL1 into the pose that matches the note (the hallway
//              Luigi sings along to dad; `update()` puts him back on 'idle'
//              while dad is idle, 7759).
//   16111-16137 the pupil (meat ID 1) slides between x 530 and 430 with the
//              chart's sections.
//
// The second instrumental - `meatworldinstALT`, a full track layered over the
// inst - is here too: 6678-6682 loads it for this stage only (and not for
// 'Overdue Old'), 6612 starts it with the song, 6927/7578 pause it with the
// music, 7200-7208 re-times and resumes it, 8599-8601 keeps its volume at 1 and
// 14354 stops it when the song ends. See mmAltBuild/mmAltTick.
//
// The four camEst overlays above (`fogblack` 3540, `meatfog` 3547,
// `blackBarThingie` 3597, `gunAmmo` 3604) are drawn on a camera this script
// builds, because Codename has no camEst: a zoom-1, never-scrolled FlxCamera at
// camHUD's size, slid into camHUD's slot in `FlxG.cameras.list` - see the
// "camEst layer" block below. On the state's own draw list they ride camGame,
// which this chart zooms to 0.35-0.5 for most of the song, so the ammo counter
// (y 850, i.e. off the bottom of the window until case 10) was visible from the
// start and the screen-wide plates only covered the middle of the screen.
//
// 3413-3418 - the three `addCharacterToList` preloads (`picodeath`, `picodiag`,
// `pico_run`, plus the two the chart swaps into) and the three
// `GameOverSubstate` fields of 3415-3417 - are ported at the bottom of the
// file: the atlases are warmed at script load (mmPreloadAll) and the death
// character / death sound / game-over loop are written in mmGameOver.
//
// `triggerEventNote('fuckoff', '', '')` (14074) has no case in the source's own
// switch - it exists only for the Lua side: `triggerEventNote` ends with
// `callOnLuas('onEvent', [eventName, value1, value2])` (14337), and
// assets/preload/characters/pico_run.lua's `onEvent` builds the running rig off
// exactly that tag. The port's own pico_run.hx listens for it the same way, so
// the case fires it here through mmFireEvent (the Reflect-guarded
// PlayState.executeEvent call exeport.hx's 'Show Song' write uses) - otherwise
// the 171.79s swap leaves BF as a torso with no legs.
//
// NOT ported: the two `PauseSubState.muymalo` writes (cases 1/7: the pause
// menu's track index is not script-reachable) and the `farmingSound` precache
// (5882 - 'FAILGUN' *is* played, by
// data/notes/Bullet.hx, as that note's own audio; and the weapon itself is
// warmed by mmCreateGun's own loaded atlas).
//
// 7686-7740 - the `overFuckYou` half of the flipped HUD - *is* ported, in
// postUpdate: case 7 of the group turns on the flag and the source's own
// per-frame `updateIconPositions` override then parks iconP2 at
// `healthBar.x - 100` and tilts it with the health. The engine positions the
// icons itself, so the layout is re-applied there, after its own update.

// ----------------------------------------------------------------------------
// The camEst layer
// ----------------------------------------------------------------------------
// Psych runs four cameras - camGame -> camEst -> camHUD -> camOther (826-836)
// - and this stage's overlays live on camEst: `fogblack` (3539), `meatfog`
// (3546), `blackBarThingie` (3600) and the `gunAmmo` ammo counter (3610).
// Codename ships only camGame and camHUD, so the layer has to be built: a plain
// FlxCamera at camHUD's own size, zoom 1 and never scrolled (camEst is a bare
// `new FlxCamera()` in the source, and 'Set Cam Zoom'/'Set Cam Pos' only ever
// write camGame's), added with defaultDraw=false and then slid into camHUD's
// slot in `FlxG.cameras.list` - which *is* camEst's slot in Psych.
//
// Drawing them on the state's draw list instead (what this file did first)
// puts them on camGame, and this chart drives camGame to 0.35-0.5 for most of
// the song: the ammo counter sits at y 850, past the bottom of the window, and
// only case 10 (45.47s) slides it up to 450 - but at 0.35-0.5 zoom the whole
// lower half of the world is inside the window, so the counter was on screen
// from the first beat, half-size and drifting with the camera; and the
// screen-wide overlays (the case 0 black-out, the fog, the vignette) only ever
// covered the middle of the screen. Same layer exeport.hx/promoshow.hx build.
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

function mmEstBelowHud() {
	if (mmEstCam == null || mmEstPlaced) return;
	var list = mmCamList();
	if (list == null) {
		if (!mmEstWarned) {
			mmEstWarned = true;
			trace("[meatworld] camEst: no FlxG.cameras.list - the layer stays above camHUD");
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

function mmCamW():Int {
	return (camHUD != null) ? camHUD.width : FlxG.width;
}

function mmCamH():Int {
	return (camHUD != null) ? camHUD.height : FlxG.height;
}

// ----------------------------------------------------------------------------
// Helpers
// ----------------------------------------------------------------------------
// The source's camEst puts a sprite in screen coordinates: that camera is never
// moved or zoomed, so scrollFactor and the camera's own transform both drop out.
function mmScreen(spr) {
	spr.scrollFactor.set(0, 0);
	spr.cameras = [mmEst()];
	add(spr);
	return spr;
}

// Codename's `Stage` is not a group (`class Stage extends FlxBasic`), so
// `stage.add`/`stage.remove`/`stage.members` do not exist and HScript resolves
// them to null - calling them throws Null Function Pointer and aborts the rest
// of the handler. `Stage.addSprite` instead puts every stage sprite straight into
// the *state's* draw list and `Stage.applyCharStuff` inserts each character at
// its marker, so a bare `members`/`add`/`insert`/`remove` here is the state's
// list and the world layer is the run of sprites below the character band.
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

// The source's `remove(x); add(x)` on its own state sprites = "move to the very
// front". A stage sprite already lives in the state's draw list, so it is that
// same remove + re-add - but the bare pair is a NO-OP in Flixel, and that is
// what kept this stage's teeth behind the fighters. `FlxGroup.remove(basic,
// splice = false)` only nulls the slot (`members[index] = null`, `length`
// untouched) and `FlxGroup.add` re-fills the *first* null slot it finds
// (`getFirstNull()` is `members.indexOf(null)`), which is that very slot: the
// sprite lands exactly where it was. A hole left anywhere earlier in the list
// (a character swapped out, say) would pull it backwards instead. Both halves
// have to be spelled out - splice the object out of the list, then insert it
// past the current end (insert() would otherwise re-use the freed slot it is
// handed, so the append position is read from the array itself).
function mmToFront(obj) {
	if (obj == null) return obj;
	remove(obj, true);
	insert(members.length, obj);
	return obj;
}

// The source addresses GF, BF and dad by their FlxSpriteGroups; a ported
// character has no group, so the group position has to be recovered from the
// character and written back. FlxSprite draws at `x - offset` and
// Character.playAnim sets
//     offset.x = globalOffset.x * (isPlayer != playerOffsets ? 1 : -1)
//     offset.y = -globalOffset.y
// so a character *renders* at `stored.x + k * globalOffset.x` with
// k = (isPlayer != playerOffsets) ? 1 : -1, while the source renders it at
// `group + position` - i.e. groupX = stored.x - (k + 1) * globalOffset.x, and y
// is the simple half (stored.y == groupY). dad and GF are the k = -1 side, so
// for them the two numbers are the same. (Same derivation as allfinal.hx's
// mmSideK/mmPlaceGroup and exeport.hx's mmGroupX/mmGroupY.)
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

function mmPlaceGroup(c, gx:Float, gy:Float) {
	if (c == null) return;
	c.x = gx + (mmSideK(c) + 1) * c.globalOffset.x;
	c.y = gy;
}

// Same swap as data/events/Change Character.hx (0 = boyfriend, 1 = opponent,
// 2 = girlfriend).
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
	// The group's current position and the incoming character's draw slot, read
	// off the character being replaced (mmGroupX/mmGroupY above).
	var gx:Float = mmGroupX(old);
	var gy:Float = mmGroupY(old);
	var oldIndex:Int = members.indexOf(old);

	remove(old);
	member.characters.remove(old);

	var fresh = new Character(0, 0, name, isPlayer);
	if (stage != null) stage.applyCharStuff(fresh, member.data.position, 0);
	// The source's swap-in enters the source's own FlxSpriteGroup and rides
	// wherever that group currently is: `dadGroup.add(newDad)` (6102) bakes the
	// group's position into the sprite, `startCharacterPos` only adds the
	// character's own position on top, and every later group move carries it
	// along. `applyCharStuff` instead parks it at the bare stage node - only the
	// group's position while the group still sits at its default, and case 4 has
	// already moved the pair to (950, 200) / (-250, 225) before case 7's swap -
	// so the swap-in is placed back where the group is (the same recovery
	// forest.hx/exeport.hx/allfinal.hx and data/events/Change Character.hx make:
	// the port renders at `x - k * globalOffset.x` while the source renders
	// `groupX + position.x`, hence `x = groupX + (k + 1) * globalOffset.x`).
	mmPlaceGroup(fresh, gx, gy);
	// The outgoing character's draw slot, so a swap mid-scene keeps its
	// z-position (the source re-adds into the same persistent group).
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
}

// ----------------------------------------------------------------------------
// Firing an event from a script
// ----------------------------------------------------------------------------
// Case 7's `triggerEventNote('fuckoff', '', '')` (14074) is the one event of
// this group that has to be re-dispatched rather than inlined: it has no case in
// the source's own switch at all, it exists only for the scripts
// (`triggerEventNote` ends with `callOnLuas('onEvent', [eventName, value1,
// value2])`, 14337), and the script that answers it is the character's -
// pico_run.lua builds the running rig (legs/arm sprites + the per-frame bob)
// from that tag, and this port's data/characters/pico_run.hx does the same.
// A stage script cannot queue chart events, but the engine's dispatcher is
// public and already delivers 'onEvent' to the game *and* character scripts
// (PlayState.executeEvent -> gameAndCharsEvent), so it is called through
// Reflect - the same guarded-call idiom exeport.hx's 'Show Song' write uses - so
// that a build without it degrades to a logged no-op.
function mmFireEvent(name:String, params:Array<Dynamic>) {
	if (PlayState.instance == null) return;
	if (!Reflect.hasField(PlayState.instance, "executeEvent")) {
		trace("[meatworld] no PlayState.executeEvent - dropped event '" + name + "'");
		return;
	}
	Reflect.callMethod(PlayState.instance, Reflect.field(PlayState.instance, "executeEvent"), [{name: name, time: 0, params: params}]);
}

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

// The live character of each line. The chart swaps this stage's fighters early
// - BF at 21.5s/24.2s/42.9s/44.1s (`picodiag`/`pico`), dad at 24.0s
// (`luigi-toolate`) - and case 7 swaps BF again (`pico_run`), but a stage
// script's `dad`/`boyfriend` globals are a load-time snapshot: they keep naming
// the objects those swaps removed. Every write below that can run after a swap
// resolves through the strumline instead (see data/events/Change Character.hx).
function mmDadChar() return mmMem(0);
function mmBfChar() return mmMem(1);

// ----------------------------------------------------------------------------
// The meat (3451-3532)
// ----------------------------------------------------------------------------
// {s: sprite, id: Int}, in the source's group order.
var mmMeatWorld = [];
var mmMeatFore = [];
var mmMeatVisible = false;
var mmPupilShifted:Bool = false;
var mmBfHome = [0.0, 0.0]; // BF_X / BF_Y (the stage XML's own BF position)

function mmMeatAdd(list, s, id:Int, sx:Float, sy:Float, scl:Float, half:Float) {
	if (s == null) return;
	s.alpha = 0;
	if (scl != 0) s.scale.set(scl, scl);
	if (half != 0) s.setPosition(sx + s.width * half, sy + s.height * half);
	else s.setPosition(sx, sy);
	list.push({s: s, id: id});
}

function mmMeatSetVisible(on:Bool) {
	mmMeatVisible = on;
	for (m in mmMeatWorld) m.s.visible = on;
	for (m in mmMeatFore) m.s.visible = on;
}

function mmMeatAlpha(list, a:Float, sec:Float) {
	for (m in list) {
		if (sec > 0) FlxTween.tween(m.s, {alpha: a}, sec);
		else m.s.alpha = a;
	}
}

// 3451-3520, the source's own numbers: base position, scale and the
// `setPosition(x + width / n, y + height / n)` offset (1/4 for the sky, 1/2 for
// the rest).
function mmFixMeat() {
	mmMeatAdd(mmMeatWorld, meat1, 0, -2350, -1350, 4, 0.25);
	mmMeatAdd(mmMeatWorld, meat2, 0, -2350, -1350, 2, 0.5);
	mmMeatAdd(mmMeatWorld, meat3, 0, -2350, -1350, 2, 0.5);
	mmMeatAdd(mmMeatWorld, meat4, 0, -2350, -1350, 2, 0.5);
	mmMeatAdd(mmMeatWorld, meat5, 0, -2350, -1350, 2, 0.5);
	mmMeatAdd(mmMeatWorld, meat6, 1, 530, -100, 1, 0);

	mmMeatAdd(mmMeatFore, meat1_2, 0, -2350 + 3660, -1350 + 395, 2, 0.5);
	mmMeatAdd(mmMeatFore, meat2_2, 1, -2350 + 1245, -1350 + 1969 + 750, 2, 0.5);
	mmMeatAdd(mmMeatFore, meat3_2, 0, -2350 + 879, -1350, 1, 0);
	mmMeatAdd(mmMeatFore, meat4_2, 2, -2350 + 921, -1350 + 411 - 1300, 1, 0);
	mmMeatAdd(mmMeatFore, meat5_2, 0, -2280, -1350 - 50, 2, 0.5);

	mmMeatSetVisible(false);
}

// ----------------------------------------------------------------------------
// The hallway backdrops (3554-3592)
// ----------------------------------------------------------------------------
// The source uses four `FlxBackdrop`s. The class is not safe to instantiate from
// HScript (its constructor takes a `FlxAxes` enum; passing enums through a
// script call is what breaks), so each one becomes the same handful of copies the
// class would draw: identical sprites at `i * step`, slid left at the source's
// velocity and wrapped every `step` px - the same stand-in demiseport.hx uses
// for seven of them, with the additional detail that three of these four are
// *animated* (`Too_Late_Luigi_Hallway`'s 'tll idle'), so every copy plays the
// animation too.
//
// `step` is *not* the source's `spacingX`. flixel-addons lays its tiles out at
// `(frameWidth + spacingX) * scale` (`FlxBackdrop.drawComplex` - its doc calls
// `spacingX` the "amount of spacing between tiles"), so the hallway's
// `new FlxBackdrop(X, -1170)` - a 1584px frame with a *negative* gap - tiles
// every 1584 - 1170 = 414px, not every 1170. At the old 1170 the copies stood
// 1170 apart while each one only draws a ~412px-wide corridor slice (the idle
// frame's opaque bbox), so the hallway read as isolated slivers snapping in and
// out instead of one continuous corridor. mmHall measures the step off the
// first copy it builds (`updateHitbox` has already folded the scale into
// `width`).
var mmHalls = [];
var mmHallAtlas = null;
var mmHallTLL1 = null;
var mmHallTLL2 = null;
var mmHallTLL3 = null;
var mmHallFG = null;

// One copy of a backdrop, configured exactly like the source's FlxBackdrop (the
// same frames / animations / scale / tint), placed at (px, py) and added to the
// state's draw list.
function mmHallMake(asset:String, atlas:Bool, anim:String, sing:String, scl:Float, col, colourSet:Bool, px:Float, py:Float) {
	var s = new FunkinSprite(px, py);
	if (atlas) {
		if (mmHallAtlas == null) mmHallAtlas = Paths.getSparrowAtlas(asset);
		s.frames = mmHallAtlas;
		s.animation.addByPrefix("idle", anim, 24, false);
		if (sing != null && sing != "") {
			s.animation.addByPrefix("singUP", sing + " up", 24, false);
			s.animation.addByPrefix("singDOWN", sing + " down", 24, false);
			s.animation.addByPrefix("singLEFT", sing + " left", 24, false);
			s.animation.addByPrefix("singRIGHT", sing + " right", 24, false);
		}
		s.animation.play("idle", true);
	} else {
		s.loadGraphic(Paths.image(asset));
	}
	if (scl != 0 && scl != 1) s.scale.set(scl, scl);
	s.updateHitbox();
	s.antialiasing = true;
	if (colourSet) s.color = col;
	s.alpha = 0.000001;
	mmWorldAdd(s);
	return s;
}

// `sing` is the prefix the source registers hallTLL1's four sing poses with
// (3558-3562: 'tll up' / 'tll down' / 'tll left' / 'tll right'); the two dimmer
// backdrops only have 'idle' there and pass an empty string.
function mmHall(asset:String, atlas:Bool, anim:String, sing:String, spacing:Float, speed:Float, scl:Float, col, colourSet:Bool, x:Float, y:Float) {
	var scaleV:Float = (scl == 0) ? 1 : scl;
	// The first copy measures the tile step: `width` is frameWidth * scale
	// after updateHitbox, and flixel-addons adds the (unscaled) spacing before
	// scaling, i.e. step = (frameWidth + spacing) * scale.
	var probe = mmHallMake(asset, atlas, anim, sing, scl, col, colourSet, x, y);
	var step:Float = probe.width + spacing * scaleV;
	if (step <= 1) step = probe.width;
	var need:Int = Std.int(Math.ceil(6000 / step)) + 1;
	if (need < 3) need = 3;
	var sprs = [probe];
	for (i in 1...need) sprs.push(mmHallMake(asset, atlas, anim, sing, scl, col, colourSet, x + i * step, y));
	var g = {sprs: sprs, tile: step, v: speed, t: 0.0};
	mmHalls.push(g);
	return g;
}

function mmHallAlpha(g, a:Float, sec:Float) {
	if (g == null) return;
	for (s in g.sprs) FlxTween.tween(s, {alpha: a}, sec);
}

// Every copy plays the same animation from the same call, so they stay in step.
function mmHallPlay(g, anim:String) {
	if (g == null || anim == null || anim == "") return;
	for (s in g.sprs) s.animation.play(anim, true);
}

// The source's `animToPlay` (8405-8416), which the hallway reuses at 8584.
function mmSingName(dir:Int):String {
	switch (dir) {
		case 0: return "singLEFT";
		case 1: return "singDOWN";
		case 2: return "singUP";
		case 3: return "singRIGHT";
	}
	return "singLEFT";
}

// 3585-3590: the row each hallway sits on, and the foreground one's 1.4 scroll.
function mmHallPlace(g, y:Float, sf:Float) {
	if (g == null) return;
	for (s in g.sprs) {
		s.y = y;
		if (sf != 0) s.scrollFactor.set(sf, sf);
	}
}

// ----------------------------------------------------------------------------
// The sprites the group owns
// ----------------------------------------------------------------------------
var mmBlackBar = null;   // 3597, camEst, alpha ~0
var mmMeatFog = null;    // 3547, camEst, alpha 0
var mmFogBlack = null;   // 3540, camEst, alpha 1 (the vignette)
var mmGunAmmo = null;    // 3604, camEst
var mmIconGF = null;     // 3621, camHUD, added at case 5
var mmIconGFAdded:Bool = false;
var mmFlipped:Bool = false;
var mmPoison:Float = 0;

function mmGetBlackBar() {
	if (mmBlackBar == null) {
		mmBlackBar = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		mmBlackBar.scale.set(10, 10); // source's setGraphicSize(width * 10)
		mmBlackBar.alpha = 0.000001;
		mmBlackBar.visible = false;
		mmScreen(mmBlackBar);
	}
	return mmBlackBar;
}

function mmGetMeatFog() {
	if (mmMeatFog == null) {
		mmMeatFog = new FlxSprite().loadGraphic(Paths.image("mario/TooLateBG/meat/TL_Meat_Fog"));
		mmMeatFog.alpha = 0;
		mmMeatFog.screenCenter();
		mmScreen(mmMeatFog);
	}
	return mmMeatFog;
}

// 3540-3545: `fogblack`, the black vignette ('modstuff/126' - 1280x720, the
// corners at ~247 alpha and a clear centre) pinned on camEst at alpha 1 for the
// whole song; the source never touches it again. Builds the frame around every
// shot on this stage, so without it the meat world is flat to the edges.
function mmGetFogBlack() {
	if (mmFogBlack == null) {
		mmFogBlack = new FlxSprite().loadGraphic(Paths.image("modstuff/126"));
		mmFogBlack.alpha = 1;
		mmFogBlack.antialiasing = true;
		mmFogBlack.screenCenter();
		mmScreen(mmFogBlack);
	}
	return mmFogBlack;
}

// 3604-3619: the ammo counter. Overdue Old starts it dimmer and lower.
function mmCreateGun() {
	if (mmGunAmmo != null) return mmGunAmmo;
	mmGunAmmo = new FunkinSprite(50, 850);
	mmGunAmmo.frames = Paths.getSparrowAtlas("mario/TooLateBG/street/Bullet Ammo");
	mmGunAmmo.animation.addByPrefix("Bullet 3", "Bullet Ammo 3", 5, false);
	mmGunAmmo.animation.addByPrefix("Bullet 2", "Bullet Ammo 2", 5, false);
	mmGunAmmo.animation.addByPrefix("Bullet 1", "Bullet Ammo 1", 5, false);
	mmGunAmmo.animation.addByPrefix("Bullet 0", "Bullet Ammo 0", 5, false);
	mmGunAmmo.animation.play("Bullet 3");
	mmGunAmmo.scale.set(0.65, 0.65);
	mmGunAmmo.updateHitbox();
	mmGunAmmo.alpha = 0.8;
	if (mmIsOld()) {
		mmGunAmmo.alpha = 0.2;
		mmGunAmmo.y = 450;
	}
	mmScreen(mmGunAmmo);
	return mmGunAmmo;
}

// ----------------------------------------------------------------------------
// The gun: the muzzle flash and the ammo counter
// ----------------------------------------------------------------------------
// `ammo` is PlayState's own field in the source (629: starts at 3, and every
// *missed* 'Bullet' note takes one off - 15275-15296 in `noteMiss`), and it
// drives the stage's counter sprite. Nothing resets it, so missing four Bullet
// notes on this stage is a death: `if (ammo < 0) health = 0`.
//
// The other half is 'Pico Shoot' (10757-10796), the event the source
// re-dispatches from every *hit* Bullet note (15608-15611, `goodNoteHit`). It is
// what `gunShotPico` - the muzzle-flash atlas the per-frame hook above keeps
// parked on BF - is for: flash on, BF and dad blink out, the game camera takes a
// random +/-5 degree tilt, a 'Screen Shake' follows (skipped between beats 204
// and 268), the 40fps 'Shoot' strip plays, dad fades back over 0.7s, the tilt
// eases out over 0.2s, and 0.3s later the flash is off and BF is back. Neither
// half was ported before, so the counter never moved and no shot was ever fired.
var mmAmmo:Int = 3;
var mmAmmoTween = null;
var mmFlashTween = null;
var mmFlashTimer = null;
var mmAngleTween = null;
var mmBeatNow:Int = 0;

// `extraTween`/`extraTimers` of the case: each new shot cancels what the last one
// left running, the same way the source does.
function mmShoot() {
	if (gunShotPico == null) return;
	if (mmFlashTween != null) mmFlashTween.cancel();
	if (mmFlashTimer != null) mmFlashTimer.cancel();
	if (mmAngleTween != null) mmAngleTween.cancel();
	gunShotPico.alpha = 1;
	// The blink-out is on the *live* pair: the chart has already swapped both
	// (`picodiag`/`pico`, `luigi-toolate`) by the first 'Bullet' hit, so the
	// globals would hide the objects the swaps removed and leave the fighters
	// on screen.
	var bShot = mmBfChar();
	var dShot = mmDadChar();
	if (bShot != null) bShot.alpha = 0;
	if (dShot != null) dShot.alpha = 0;
	if (camGame != null) {
		camGame.angle = FlxG.random.bool(50) ? 5 : -5;
		// `triggerEventNote('Screen Shake', '0.15, 0.007', '0.15, 0.007')`.
		if (!(mmBeatNow >= 204 && mmBeatNow <= 268)) camGame.shake(0.007, 0.15);
	}
	if (camHUD != null && !(mmBeatNow >= 204 && mmBeatNow <= 268)) camHUD.shake(0.007, 0.15);
	gunShotPico.animation.play("Shoot");
	if (dShot != null) mmFlashTween = FlxTween.tween(dShot, {alpha: 1}, 0.7, {ease: FlxEase.quadOut});
	if (camGame != null) mmAngleTween = FlxTween.tween(camGame, {angle: 0}, 0.2, {ease: FlxEase.quadOut});
	mmFlashTimer = new FlxTimer().start(0.3, function(tmr) {
		gunShotPico.alpha = 0;
		// Resolved again: the source's own closure reads the live `boyfriend`.
		var bBack = mmBfChar();
		if (bBack != null) bBack.alpha = 1;
	});
}

// The source's `curBeat` for the 'Pico Shoot' screen-shake gate above.
function beatHit(curBeat:Int) {
	mmBeatNow = curBeat;
}

// 3621-3628: `icons/icon-latemario` - a two-frame icon like allfinal.hx's mmIcon.
function mmGetIconGF() {
	if (mmIconGF != null) return mmIconGF;
	var path = Paths.image("icons/icon-latemario");
	if (path == null || !Assets.exists(path)) {
		trace("[meatworld] iconGF: image missing -> " + path);
		return null;
	}
	var s = new FlxSprite();
	s.loadGraphic(path, true, 150, 150);
	s.animation.add("win", [0], 10, true);
	s.animation.add("lose", [1], 10, true);
	s.cameras = [camHUD];
	s.alpha = 0;
	s.flipX = true;
	mmIconGF = s;
	return mmIconGF;
}

function mmIconGFAdd() {
	var ic = mmGetIconGF();
	if (ic == null) return null;
	if (!mmIconGFAdded) {
		add(ic);
		mmIconGFAdded = true;
	}
	return ic;
}

function mmIsOld():Bool {
	var n = null;
	if (PlayState.SONG != null && PlayState.SONG.meta != null) n = PlayState.SONG.meta.displayName;
	if (n == null) return false;
	return StringTools.startsWith(StringTools.trim(Std.string(n)), "Overdue Old");
}

// ----------------------------------------------------------------------------
// The second instrumental (6678-6682, 6612, 6927/7200-7208, 8599-8601, 14354)
// ----------------------------------------------------------------------------
// `meatworldinstALT` is a whole extra track the song is mixed against - the
// source plays it *in addition to* the inst, so without it Overdue is missing a
// layer of its music. The source's own lines:
//
//   6678-6682  `instALT = new FlxSound().loadEmbedded(Paths.sound(curStage +
//              'instALT'))` - only for this stage, and only when the song is not
//              'Overdue Old' (which gets an empty FlxSound instead);
//   6612       `instALT.play()` in startSong, i.e. with the inst;
//   6927/7578  `instALT.pause()` when the game pauses (both the substate path and
//              the pause menu);
//   7200-7208  the resume: `instALT.time = Conductor.songPosition`, then play;
//   8599-8601  every opponent note pins `instALT.volume` to 1 on this stage (the
//              same line zeroes it on every other one);
//   14354      finishSong zeroes the volume and pauses it.
//
// A stage script cannot touch the engine's own pause code, so the two halves
// that update() cannot see are driven by the engine's script hooks: the alt is
// paused from `onGamePause` (which CNE dispatches from pauseGame) and marked for
// resumption from `onSubstateClose` (dispatched while `paused` is still set,
// i.e. *before* the engine resyncs and restarts its own sounds) - mmAltTick then
// does the 7205-7208 re-time on the first frame the song is running again.
var mmAlt = null;
var mmAltDead:Bool = false;
var mmAltRunning:Bool = false;
var mmAltResume:Bool = false;

function mmAltBuild() {
	if (mmAlt != null || mmAltDead) return mmAlt;
	// 6678: 'Overdue Old' never gets a second track.
	if (mmIsOld()) { mmAltDead = true; return null; }
	var path = Paths.sound("meatworldinstALT");
	if (path == null || !Assets.exists(path)) {
		trace("[meatworld] instALT: sound missing -> " + path);
		mmAltDead = true;
		return null;
	}
	var s = new FlxSound().loadEmbedded(path);
	s.persist = false;
	s.volume = 1;
	mmAltRegister(s);
	mmAlt = s;
	return mmAlt;
}

// `Reflect.field` rather than `FlxG.sound.list.add` directly, the same guard
// promoshow.hx/exeport.hx use for `FlxG.cameras.list`: a lookup that comes back
// empty has to leave the track playing, not take the script down with it. Being
// in the group is what makes FlxSound advance its own `time` - which is how
// mmAltTick can tell how far the track has drifted; the audio plays either way.
function mmAltRegister(s) {
	var grp = Reflect.field(FlxG.sound, "list");
	if (grp == null || !Reflect.hasField(grp, "add")) return;
	Reflect.callMethod(grp, Reflect.field(grp, "add"), [s]);
}

function mmAltTick() {
	var s = mmAltBuild();
	if (s == null) return;
	var mus = FlxG.sound.music;
	if (mus == null) return;
	if (!mus.playing) {
		// The song's end (14354), or a restart: nothing may outlive it.
		if (s.playing) s.pause();
		mmAltRunning = false;
		return;
	}
	if (mmAltRunning && !mmAltResume) return;
	mmAltResume = false;
	mmAltRunning = true;
	// 7205-7208: the resume re-times the track to the song position first.
	var t = mus.time;
	if (Math.abs(s.time - t) > 10) {
		if (s.playing) s.pause();
		s.time = t;
	}
	s.play();
}

// ----------------------------------------------------------------------------
// Load-time: the character preloads and the GameOverSubstate fields
// ----------------------------------------------------------------------------
// 3413-3418: three `addCharacterToList`s - `picodeath` (the death sprite), then
// `picodiag` and `pico_run` - and the chart swaps characters on this song four
// more times ('BF'/'0' -> `picodiag`/`pico` at 21.47s, 24.24s, 42.95s and
// 170.64s, '1' -> `luigi-toolate` at 24.00s). The source preloads those too:
// its `eventPushed` pass runs `addCharacterToList(value2, charType)` for every
// 'Change Character' in the chart before the song starts. A `new Character()`
// whose atlas is not cached decodes it on the spot, which is a mid-song stall,
// so all five are warmed here the way allfinal.hx/promoshow.hx warm theirs:
// `Paths.getFrames(<the character XML's own sprite>)`, the exact call
// Character's loader makes, cached under the same key, from SCRIPT LOAD (i.e.
// inside PlayState creation, before the countdown).
var mmPreloadChars = ["picodeath", "picodiag", "pico_run", "luigi-toolate", "pico"];

// The image a character's XML points at (`sprite="..."`), which is the value
// the preload caches under.
function mmCharImage(name:String) {
	var xmlPath = Paths.xml("characters/" + name);
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
	if (img == null) { trace("[meatworld] preload: no sprite attribute for " + name); return; }
	if (!Assets.exists(img)) { trace("[meatworld] preload: no image at " + img); return; }
	Paths.getFrames(img, true);
}

function mmPreloadAll() {
	for (name in mmPreloadChars) mmPreloadChar(name);
}

// 3415-3417: the fork's `GameOverSubstate` fields for this stage - dying as BF
// shows `picodeath`, the death sound is 'TOOPOOP_LUIGI' and the screen loops
// 'overdueGameover'. Codename reads the death character off the character
// itself (`PlayState.gameOver()`: `deathCharID.getDefault(charToUse.
// gameOverCharacter)`, the hook luigiout.hx's case 9 uses) and the two sounds
// off the state (the substate's loss SFX and its music - Psych's
// `deathSoundName`/`loopSoundName`), so each goes there; every write sits
// behind an `Assets.exists` check so a missing file cannot take the death
// screen down. `endSoundName` stays the engine's own 'gameOverEnd'.
function mmGameOver() {
	if (boyfriend != null && Assets.exists(Paths.xml("characters/picodeath")))
		boyfriend.gameOverCharacter = "picodeath";
	var ps = PlayState.instance;
	if (ps == null) return;
	if (Reflect.hasField(ps, "lossSFX") && Assets.exists(Paths.sound("TOOPOOP_LUIGI")))
		Reflect.setProperty(ps, "lossSFX", "TOOPOOP_LUIGI");
	if (Reflect.hasField(ps, "gameOverSong") && Assets.exists(Paths.music("overdueGameover")))
		Reflect.setProperty(ps, "gameOverSong", "overdueGameover");
}

// ----------------------------------------------------------------------------
// Load
// ----------------------------------------------------------------------------
function postCreate() {
	// 3412: GF is invisible for the whole song (case 5 only moves her).
	if (gf != null) gf.alpha = 0.00000001;

	// The two fighters are at the stage XML's own position now, before any case
	// moves them: that pair is the source's BF_X/BF_Y for case 7.
	if (boyfriend != null) mmBfHome = [mmGroupX(boyfriend), mmGroupY(boyfriend)];

	mmFixMeat();

	// 3419-3428: both castle halves start hidden and played 'idle'.
	for (c in [castleFloor, castleCeiling]) {
		if (c == null) continue;
		c.alpha = 0;
		c.animation.play("idle");
	}

	// 4454-4457: in front of the fighters there.
	mmToFront(streetFore);
	for (m in mmMeatFore) mmToFront(m.s);

	// 3554-3592: the three hallways and their foreground copy. The source adds
	// the three TLL backdrops in the *background* switch, back to front as
	// hallTLL3 -> hallTLL2 -> hallTLL1 (each `add()` lands in front of the last),
	// so they are built in that order here and each goes to the top of the world
	// layer. All three are the source's `new FlxBackdrop(X, -1170)` - a 1584px
	// frame with a -1170 gap, i.e. a 414px step (see mmHall) - at velocity
	// -2800 / -2240 / -1680 and 1 / 0.8 / 0.6 scale (the dimmer two via their
	// colour); the foreground one is the source's `..., X, 1545` on the 1031px
	// FG_Too_Late_Luigi, i.e. a 2576px step, at 3920 px/s and is added by the
	// *foreground* switch (4457), i.e. in front of the fighters - its copies are
	// lifted accordingly. Both happen before the camEst stand-ins below, so
	// those still draw over the foreground.
	mmHallTLL3 = mmHall("Too_Late_Luigi_Hallway", true, "tll idle", "", -1170, 1680, 0.6, 0xFF696969, true, 0, 0);
	mmHallTLL2 = mmHall("Too_Late_Luigi_Hallway", true, "tll idle", "", -1170, 2240, 0.8, 0xFF979797, true, 0, 0);
	mmHallTLL1 = mmHall("Too_Late_Luigi_Hallway", true, "tll idle", "tll", -1170, 2800, 1, null, false, 0, 0);
	mmHallFG = mmHall("mario/TooLateBG/feet/FG_Too_Late_Luigi", false, "", "", 1545, 3920, 1, null, false, 0, 0);
	if (mmHallFG != null) for (s in mmHallFG.sprs) mmToFront(s);

	mmGetBlackBar();
	mmGetMeatFog();
	mmGetFogBlack();
	mmCreateGun();
	// 3415-3417: the stage's game-over character, death sound and loop.
	mmGameOver();
	// 6678-6682: built with the rest of the stage; mmAltTick starts it with the
	// song (it is silent until then).
	mmAltBuild();

	// 3621: built but not added - the source only `add()`s it from case 5.
	mmGetIconGF();
}

// ----------------------------------------------------------------------------
// Per-frame (8019-8031) + the backdrop slide
// ----------------------------------------------------------------------------
function update(elapsed:Float) {
	for (g in mmHalls) {
		g.t -= g.v * elapsed;
		while (g.t <= -g.tile) g.t += g.tile;
		var i:Int = 0;
		for (s in g.sprs) { s.x = i * g.tile + g.t; i += 1; }
	}
	// 7759-7763: while dad is idle the hallway is put back on its idle loop.
	// (`force` is the source's own `play('idle', true)`, so the anim restarts on
	// every one of those frames - that is what the fork shows.)
	var dIdle = mmDadChar();
	if (mmHallTLL1 != null && dIdle != null && dIdle.animation != null) {
		var ca = dIdle.animation.curAnim;
		if (ca != null && ca.name == "idle") mmHallPlay(mmHallTLL1, "idle");
	}
	mmAltTick();
}

function postUpdate(elapsed) {
	// The camEst layer: placed once (and re-placed until camHUD is in the list),
	// then kept at camHUD's size - exeport.hx/promoshow.hx do the same.
	mmEstBelowHud();
	mmEstSize();

	// 8019-8031: gunShotPico rides BF, iconGF rides the player's icon.
	var bGun = mmBfChar();
	if (gunShotPico != null && bGun != null) {
		gunShotPico.x = mmGroupX(bGun) - 210;
		gunShotPico.y = mmGroupY(bGun) + 180;
	}
	if (mmIconGF != null && mmIconGFAdded) {
		if (iconP1 != null) {
			mmIconGF.x = iconP1.x + 55;
			mmIconGF.y = iconP1.y - 40;
			mmIconGF.scale.set(iconP1.scale.x - 0.2, iconP1.scale.y - 0.2);
		}
		if (health < 0.4) mmIconGF.animation.play("lose");
		else mmIconGF.animation.play("win");
	}

	// 7686-7740: with `flipchar` on (case 7 sets it) the source lays the HUD out
	// mirrored - the two bars flip, iconP1 flips, iconP2 is parked at
	// `healthBar.x - 100` and shakes with the health. The engine positions the
	// icons itself, so the flipped layout is re-applied *after* its own update.
	if (!mmFlipped) return;
	// Psych's health bar percent is `health * 50` (an `FlxBar` over `health`, min
	// 0 / max 2 - source 5213-5218), which is what the source's flipped layout
	// reads - the engine's own bar is not consulted, so this does not depend on
	// how *its* `percent` is scaled. The source's slide term is
	// `FlxMath.remapToRange(healthBar.percent, 0, 100, 100, 0) * 0.01`, i.e.
	// `1 - percent / 100` - the *complement* of the percent, which is what the
	// engine's unflipped `remapToRange(percent, 0, 100, 1, 0)` gives it too.
	var pct:Float = health * 50;
	var slide:Float = 1 - (pct * 0.01);
	if (iconP1 != null && healthBar != null)
		iconP1.x = healthBar.x - (healthBar.width * slide) - (iconP1.width - 640);
	if (iconP2 != null && healthBar != null) {
		iconP2.x = healthBar.x - 100;
		var shF:Int = Std.int(10 - (pct / 10));
		if (shF < 0) shF = 0;
		iconP2.angle = FlxG.random.int(-shF, shF);
	}
}

// ----------------------------------------------------------------------------
// The poison (8581-8585)
// ----------------------------------------------------------------------------
// `health -= poison` on every opponent note while dad is `luigi-toolate`, and
// hallTLL1 is kicked to the note's own animation there (the direction is not
// visible to a stage script, so the hallway keeps its idle loop - see the
// header).
function onNoteHit(event) {
	// 15608-15611: a hit 'Bullet' note fires the muzzle flash.
	if (event.player && event.noteType == "Bullet") mmShoot();
	if (event.player) return;
	// 8599-8601 runs for every opponent note.
	if (mmAlt != null) mmAlt.volume = 1;
	var d = mmMem(0);
	if (d == null || d.curCharacter != "luigi-toolate") return;
	// 8581-8585: the poison, and the hallway onto the note's own pose.
	if (mmPoison > 0 && health >= 0.2) health -= mmPoison;
	mmHallPlay(mmHallTLL1, mmSingName(event.direction));
}

// 15275-15296: a *missed* 'Bullet' note costs a round. `ammo` is PlayState's
// field there and the counter sprite is the stage's, so both halves sit here -
// including the `health = 0` once the count goes negative, which is what makes
// four missed bullets fatal. The 'FAILGUN' hiss is data/notes/Bullet.hx's, the
// same split the source has (the sound is played by PlayState, the note type
// owns nothing here).
function onPlayerMiss(event) {
	if (event.noteType != "Bullet") return;
	mmAmmo -= 1;
	var g = mmGunAmmo;
	if (g != null) {
		if (mmAmmo >= 0) g.animation.play("Bullet " + mmAmmo); // 'Bullet -1' is not an anim
		if (mmAmmoTween != null) mmAmmoTween.cancel();
		mmAmmoTween = FlxTween.tween(g, {alpha: 0.2}, 3, {startDelay: 5, ease: FlxEase.quadInOut});
		FlxTween.color(g, 0.5, FlxColor.BLACK, FlxColor.WHITE);
	}
	if (mmAmmo < 0) health = 0;
}

// ----------------------------------------------------------------------------
// The song's start, and the pause / resume pair (6612, 6927, 7200-7208, 7578)
// ----------------------------------------------------------------------------
function onSongStart() {
	mmAltTick();
}

function onGamePause(event) {
	if (mmAlt != null && mmAlt.playing) mmAlt.pause();
	mmAltRunning = false;
}

function onSubstateClose(event) {
	// Dispatched while `paused` is still true, so this only ever marks a
	// resumption - mmAltTick does the re-time once the music is back.
	var ps = PlayState.instance;
	if (ps != null && ps.paused == true) mmAltResume = true;
}

// ----------------------------------------------------------------------------
// The pupil (16111-16137)
// ----------------------------------------------------------------------------
// The chart's 'Camera Movement' events are the conversion's mustHitSection
// (1 = BF's section), the same proxy wetworld.hx/allfinal.hx read for theirs.
function mmPupil(bfSection:Bool) {
	if (bfSection) {
		if (mmPupilShifted) return;
		mmPupilShifted = true;
		for (m in mmMeatWorld) if (m.id == 1) FlxTween.tween(m.s, {x: 530}, 1.5, {ease: FlxEase.quadInOut});
	} else {
		if (!mmPupilShifted) return;
		mmPupilShifted = false;
		for (m in mmMeatWorld) if (m.id == 1) FlxTween.tween(m.s, {x: 430}, 1.5, {ease: FlxEase.quadInOut});
	}
}

// ----------------------------------------------------------------------------
// 'Triggers Overdue' 0-16
// ----------------------------------------------------------------------------
// Sent as 'Triggers Universal' by the chart (the source re-dispatches that to
// 'Triggers <song>' at runtime, 9489-9496), so both names are accepted.
function onEvent(event) {
	if (event.event.name == "Camera Movement") {
		var t = Std.parseInt(event.event.params[0]);
		if (t != null) mmPupil(t == 1);
		return;
	}
	if (event.event.name != "Triggers Overdue" && event.event.name != "Triggers Universal") return;
	var trigger = Std.parseInt(event.event.params[0]);
	if (trigger == null || Math.isNaN(trigger)) trigger = 0;
	var value2:String = (event.event.params.length > 1) ? StringTools.trim(Std.string(event.event.params[1])) : "";

	switch (trigger) {
		case 0:
			// 64.74s onwards, alternating with 0.5: the world blacks out.
			var a:Float = 0.8;
			var parsed = Std.parseFloat(value2);
			if (parsed != null && parsed == parsed) a = parsed;
			var bar = mmGetBlackBar();
			bar.visible = true;
			FlxTween.tween(bar, {alpha: a}, 1);
			if (a != 0) {
				// `triggerEventNote('Screen Shake', '2, 0.002', '2.2, 0.002')`.
				if (camGame != null) camGame.shake(0.002, 2);
				if (camHUD != null) camHUD.shake(0.002, 2.2);
			}
		case 1:
			// 24.01s (0.005) and 171.71s (0.0175): the poison starts.
			var p = Std.parseFloat(value2);
			if (p == null || p != p) p = 0;
			mmPoison = p;
		case 3:
			// 84.34s: the meat foreground arrives - the teeth slam down.
			mmMeatSetVisible(true);
			for (m in mmMeatFore) {
				if (m.id > 0) m.s.alpha = 1;
				if (m.id == 1)
					FlxTween.tween(m.s, {y: (-1350 + 1969 - 400) + (m.s.height / 2)}, 0.3, {ease: FlxEase.cubeIn});
				else if (m.id == 2)
					FlxTween.tween(m.s, {y: -1350 + 411 - 400}, 0.3, {ease: FlxEase.cubeIn, onComplete: function(twn) {
						FlxG.sound.play(Paths.sound('teethslam'), 0.5);
					}});
			}
		case 4:
			// 84.71s: the street is gone, the fighters are moved and the meat
			// world takes over completely.
			for (s in [street1, street2, street3, street4, streetFore]) {
				if (s == null) continue;
				remove(s);
				s.destroy();
			}
			// 13995-13996: `boyfriendGroup.setPosition(950, 200)` /
			// `dadGroup.setPosition(-250, 225)` - both go through the group mapping,
			// since BF's stored x is not his group x. Both also resolve the live
			// character: this case is at 84.71s, an hour after the chart swapped
			// both lines, so the globals name the objects the swaps removed.
			mmPlaceGroup(mmBfChar(), 950, 200);
			mmPlaceGroup(mmDadChar(), -250, 225);
			for (m in mmMeatWorld) m.s.alpha = 1;
			for (m in mmMeatFore) {
				m.s.alpha = 1;
				if (m.id == 1) {
					FlxTween.tween(m.s, {y: (-1350 + 1969) + (m.s.height / 2)}, 0.4, {ease: FlxEase.cubeInOut});
					FlxTween.tween(mmGetMeatFog(), {alpha: 0.6}, 0.4, {ease: FlxEase.cubeInOut});
				} else if (m.id == 2) {
					FlxTween.tween(m.s, {y: -1350 + 411 - 1300}, 0.4, {ease: FlxEase.cubeIn, onComplete: function(twn) {
						m.s.visible = false;
					}});
				}
			}
		case 5:
			// 135.16s: the third icon joins and gf drifts in.
			mmIconGFAdd();
			if (gf != null) {
				mmPlaceGroup(gf, 900, mmGroupY(gf)); // gfGroup.x = 900
				FlxTween.tween(gf, {y: gf.y + 40}, 2, {startDelay: 0.2, ease: FlxEase.quadInOut, type: FlxTween.PINGPONG});
				FlxTween.tween(gf, {x: gf.x - 30}, 4, {startDelay: 0.2, ease: FlxEase.quadInOut, type: FlxTween.PINGPONG});
				FlxTween.tween(gf, {alpha: 0.7}, 5);
			}
			if (mmIconGF != null) FlxTween.tween(mmIconGF, {alpha: 0.7}, 5);
		case 6:
			// 161.68s: the castle arrives as the meat leaves.
			for (c in [castleFloor, castleCeiling]) {
				if (c == null) continue;
				c.x = -1000;
				c.y = (c == castleFloor) ? (1000 - 350) : (-750 - 350);
				c.alpha = 1;
				c.animation.play("idle");
			}
			mmMeatAlpha(mmMeatWorld, 0, 10);
			mmMeatAlpha(mmMeatFore, 0, 10);
			FlxTween.tween(mmGetMeatFog(), {alpha: 0}, 10);
		case 7:
			// 171.79s: the hallway. Dad is thrown off screen, GF leaves, BF turns
			// into `pico_run` and the HUD flips over. Dad here is the
			// `luigi-toolate` the chart swapped in at 24.0s - the same character
			// the poison loop above has been reading.
			var dHall = mmDadChar();
			if (dHall != null) {
				dHall.y = 150; // dadGroup.y = 150
				FlxTween.tween(dHall, {x: -2350}, 0.8);
			}
			if (gf != null) gf.visible = false;

			mmHallPlace(mmHallTLL1, -850 - 350, 0);
			mmHallPlace(mmHallTLL2, -600 - 350, 0);
			mmHallPlace(mmHallTLL3, -350 - 350, 0);
			mmHallPlace(mmHallFG, -600 - 350, 1.4);

			mmChangeChar(0, "pico_run");
			// The case re-dispatches its own 'Set Cam Pos'/'Set Cam Zoom' events,
			// which the chart carries too and songs/MMcamera.hx applies.
			// 14074: `triggerEventNote('fuckoff', '', '')` - no case of the source's
			// own switch answers to it, but the Lua dispatch at the end of
			// triggerEventNote (14337) does, and pico_run.lua is what builds the
			// running rig from it. The swap above is what loads data/characters/
			// pico_run.hx, so the event has to come after it - as it does in the
			// source, which fires it right before the `boyfriendGroup` write below.
			mmFireEvent("fuckoff", ["", ""]);
			// `boyfriendGroup.setPosition(BF_X - 150, BF_Y)` - on the `pico_run`
			// the swap above put in. The global still names the character that
			// swap replaced, so the old write moved an object that is no longer
			// in the game and Pico stayed at the stage node.
			mmPlaceGroup(mmBfChar(), mmBfHome[0] - 150, mmBfHome[1]);

			mmHallAlpha(mmHallTLL1, 1, 0.2);
			mmHallAlpha(mmHallTLL2, 1, 0.2);
			mmHallAlpha(mmHallTLL3, 1, 0.2);
			mmHallAlpha(mmHallFG, 1, 1.5);

			for (c in [castleFloor, castleCeiling]) {
				if (c == null) continue;
				c.animation.play("loop", true);
			}

			// `flipchar = true` + `overFuckYou = true` (5642-5646 and 7710-7730).
			mmFlipped = true;
			if (healthBar != null) healthBar.flipX = true;
			if (healthBarBG != null) healthBarBG.flipX = true;
			if (iconP1 != null) iconP1.flipX = true;
		case 8:
			// 212.21s: the hallway and the opponent's icon fade away.
			mmHallAlpha(mmHallTLL1, 0, 1.5);
			mmHallAlpha(mmHallTLL2, 0, 1.5);
			mmHallAlpha(mmHallTLL3, 0, 1.5);
			mmHallAlpha(mmHallFG, 0, 1.5);
			if (iconP2 != null) FlxTween.tween(iconP2, {alpha: 0}, 1.5);
		case 9:
			// 214.74s: both cameras off - the song is over.
			if (camGame != null) camGame.alpha = 0;
			if (camHUD != null) camHUD.alpha = 0;
		case 10:
			// 45.47s: the ammo counter rises and dims.
			if (mmGunAmmo == null) return;
			FlxTween.tween(mmGunAmmo, {y: 450}, 3, {ease: FlxEase.expoOut});
			FlxTween.tween(mmGunAmmo, {alpha: 0.2}, 3, {startDelay: 5, ease: FlxEase.quadInOut});
		case 12:
			// 93.90s: BF drifts right, ping-ponging. The source tweens
			// `boyfriendGroup.x + 200`; a +200 on the live character's stored x
			// reads as the same +200 on screen, and it is the chart's `pico`
			// that drifts (BF was swapped at 44.13s).
			var bDrift = mmBfChar();
			if (bDrift != null)
				FlxTween.tween(bDrift, {x: bDrift.x + 200}, 6, {ease: FlxEase.quadInOut, type: FlxTween.PINGPONG});
		case 13:
			// 170.86s: the ammo and the third icon go.
			if (mmGunAmmo != null) FlxTween.tween(mmGunAmmo, {alpha: 0}, 0.5, {ease: FlxEase.quadOut});
			if (mmIconGF != null) FlxTween.tween(mmIconGF, {alpha: 0}, 0.5);
	}
}

// 3413-3418: script load - the source creates its characters and precaches
// ahead of the countdown, inside PlayState creation.
mmPreloadAll();
// === end MM stage triggers ===
