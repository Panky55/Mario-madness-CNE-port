

// === MM stage triggers (auto) ===
// 'Triggers Race Traitors' - ported from PlayState.hx (case 'Triggers Race
// Traitors', 11514-11660).
//
// The character half of the group is ported: case 0 (11516-11527) drops the
// opponent in and, on the *modern* song only, dispatches the 'Change Character'
// the source fires by hand (`triggerEventNote('Change Character', '1',
// 'racet1')`), and case 1 (11528-11570) is the racers' swap itself - `dad`
// becomes the chart's `value2` (`racet2` / `racet3` / `race` on the modern chart,
// those plus `racet1` on the old one), is parked at x 50, and `race` then starts
// his ping-pong once case 0's drop-in has finished (`jodaflota`). The old song
// also forces the two HUD icons to 'icon-bfr' / 'icon-race'.
//
// `mmChangeChar` is the same swap data/events/Change Character.hx performs (the
// chart's Change Character events cannot be used here: the racers arrive through
// this trigger, not the event file), and `racing|racet1` is in songs/MMcamera.hx's
// `MM_PRELOAD` table because nothing else names it - the modern chart only
// carries `racet2` / `racet3` / `race`, which the global sweep picks up on its
// own. So every racer this case can swap to is warmed at load and the swap no
// longer decodes an atlas mid-song.
//
// The shell game (cases 2-8, 11572-11660) **is** ported. `caja` and `redS` are
// the source's own HUD sprites (`modstuff/cajamk` / `modstuff/shellmk`, built at
// 4883-4900 and 5556-5568): the box starts parked off screen - above (`-200`) on
// upscroll, below (`760`) on downscroll - case 2 drops it to the shown row
// (`50`/`570`) while it spins 'random', 3/4/5/8 re-snap it to `40`/`560` and
// tween it back to `50`/`570` over 0.2s while swapping the animation
// ('shell'/'ghost'/'bomb'/'1up'). These are physical rows: mmHudY cancels
// CNE's automatic downscroll mirror. Case 6 slides it back off screen, and 7 fires
// `redS` from its parked `-200` at `iconP1.x` over one beat (backIn) and hits for
// -0.4 - the 'shellhit' sound, the 0.5s retreat and the camera shake, which the
// source gates on `ClientPrefs.flashing` (taken as on, like every pref this port
// cannot read). Case 8 also tweens the song's own speed to its `value2` (`3.5`
// on the modern chart) over 16 seconds - Psych's `SONG.speed` is this engine's
// `PlayState.scrollSpeed` (the field the built-in 'Scroll Speed Change' event
// tweens, and the one the converter wrote the chart's 2.7974 from), so the ramp
// drives that. Deviations: `ClientPrefs.middleScroll` is not script-readable in
// this build (see realbg.hx's helper), so the box is always screen-centred;
// `ClientPrefs.hideHud` has no twin either, so `redS` is always visible, since a
// stage script cannot hide the engine's HUD; and `ClientPrefs.globalAntialiasing`
// is taken as on. `getspeed` is not reproduced: in the fork it exists only to put
// the *global* `SONG.speed` back when the chart editor or a game over is opened,
// and this port tweens the live instance field instead, which no later song
// inherits. The old song's `reloadHealthBarColors()` (11549) still has no
// script-reachable twin here (the engine recolours `healthBar` from its own
// characters).
//
// Case 10 (11667-11672) is the end-of-song blackout - a fresh 10x `makeGraphic`
// plate on the fork's camEst layer, sent once at 113.1s on the modern chart -
// and it **is** ported now: see "The end-of-song black curtain" below, which
// builds the port's own camEst camera and slides it in at camHUD's index. The
// same create block's other camEst sprite, the rare `fernan` easter-egg plate
// (1905-1913), is built there too - with the fork's own 0.05 roll, units slip
// included.
var mmJodaFlota:Bool = false;
var mmCaja = null;   // 'modstuff/cajamk' - the shell-game box, on camHUD
var mmRedS = null;   // 'modstuff/shellmk' - the shell that flies at iconP1

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

// Same swap as data/events/Change Character.hx (0 = boyfriend, 1 = opponent,
// 2 = girlfriend - the source's own numbering).
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
	mmSwapIcon(index, fresh);
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

// The source gates two of the case's writes on `PlayState.SONG.song !=
// 'Racetraitors Old'` (11516: the racet1 dispatch; 11547: the forced icons). A
// script sees the song through `PlayState.SONG.meta.displayName` (same test
// meatworld.hx's mmIsOld and exeport.hx's mmIsPowerdownOld use).
function mmIsRaceOld():Bool {
	var meta = (PlayState.SONG != null) ? PlayState.SONG.meta : null;
	if (meta == null) return false;
	return StringTools.trim(Std.string(meta.displayName)) == "Racetraitors Old";
}

// ---------------------------------------------------------------------------
// The shell game's two HUD sprites (4883-4900, 5556-5568)
// ---------------------------------------------------------------------------
// Psych's rows are physical HUD positions; CNE's HudCamera mirrors them with
// height - y - sprite.height. Invert that once, including the actual hitbox,
// so the source's downscroll placement isn't mirrored a second time.
function mmHudY(s, up:Float, down:Float):Float {
	if (!downscroll) return up;
	var h:Float = (camHUD != null) ? camHUD.height : FlxG.height;
	return h - down - s.height;
}

function mmCam(which:String, args:Array<Dynamic>):Dynamic {
	var ps = PlayState.instance;
	if (ps == null || ps.scripts == null) return null;
	var api:Dynamic = ps.scripts.get("mmCamera");
	if (api == null || !Reflect.hasField(api, which)) return null;
	return Reflect.callMethod(api, Reflect.field(api, which), args);
}

// The modern song's opening camera pushes are beat-only, not chart events
// (PlayState.hx:16382-16395). MMcamera owns zoom, so use its drive rather than
// a camGame tween that its postUpdate would overwrite. Old skips this block.
function beatHit(curBeat:Int) {
	if (mmIsRaceOld()) return;
	switch (curBeat) {
		case 4: mmCam("zoom", [1, 0.5, 0, FlxEase.backOut]);
		case 11: mmCam("zoom", [1.2, 0.5, 0, FlxEase.backOut]);
		case 16: mmCam("zoom", [0.9, 0.4, 0, FlxEase.backOut]);
	}
}

// `new FlxSprite` + a sparrow atlas, `cameras = [camHUD]`.
function mmGetCaja() {
	if (mmCaja != null) return mmCaja;
	mmCaja = new FlxSprite(0, 0);
	mmCaja.frames = Paths.getSparrowAtlas('modstuff/cajamk');
	mmCaja.animation.addByPrefix('idle', 'cajamk nada', 15);
	mmCaja.animation.addByPrefix('random', 'cajamk random', 15);
	mmCaja.animation.addByPrefix('shell', 'cajamk shell', 15);
	mmCaja.animation.addByPrefix('bomb', 'cajamk bomb', 15);
	mmCaja.animation.addByPrefix('ghost', 'cajamk ghost', 15);
	mmCaja.animation.addByPrefix('1up', 'cajamk 1up', 15);
	mmCaja.antialiasing = true; // ClientPrefs.globalAntialiasing, taken as on
	mmCaja.camera = camHUD;
	mmCaja.updateHitbox();
	mmCaja.y = mmHudY(mmCaja, -200, 760);
	// The source centres it unless `ClientPrefs.middleScroll` is on, which no
	// script can read here.
	mmCaja.screenCenter(FlxAxes.X);
	add(mmCaja);
	return mmCaja;
}

function mmGetRedS() {
	if (mmRedS != null) return mmRedS;
	mmRedS = new FlxSprite(-200, 535);
	mmRedS.frames = Paths.getSparrowAtlas('modstuff/shellmk');
	mmRedS.animation.addByPrefix('idle', 'idle', 15);
	mmRedS.animation.addByPrefix('hit', 'hit', 15, false);
	mmRedS.animation.play('idle');
	mmRedS.antialiasing = true;
	mmRedS.visible = true; // source `!ClientPrefs.hideHud`, not script-readable
	mmRedS.camera = camHUD;
	mmRedS.updateHitbox();
	mmRedS.y = mmHudY(mmRedS, 535, -10); // 5565-5568
	add(mmRedS);
	return mmRedS;
}

function mmCajaAnim(name:String) {
	if (mmCaja == null) mmGetCaja();
	mmCaja.animation.play(name);
}

// 11579-11604 / 11645-11656: cases 3/4/5/8 snap the box back to its off-screen
// row and tween it down to the shown row (40 -> 50 upscroll, 560 -> 570 down).
function mmCajaDrop() {
	if (mmCaja == null) return;
	mmCaja.y = mmHudY(mmCaja, 40, 560);
	FlxTween.tween(mmCaja, {y: mmHudY(mmCaja, 50, 570)}, 0.2, {ease: FlxEase.quadOut});
}

// 11605-11643: `redS` flies at the player's health icon over one beat, then the
// hit lands on the tween's completion (which is why `health` moves here and not
// in the case): -0.4 over 0.2s, the 'hit' frame, and half a second later the
// shell is back at its parked -200.
function mmShellHit() {
	if (mmRedS == null) return;
	mmRedS.animation.play('idle');
	var target:Float = (iconP1 != null) ? iconP1.x : mmRedS.x;
	FlxTween.tween(mmRedS, {x: target}, 1 * (1 / (Conductor.bpm / 60)), {ease: FlxEase.backIn, onComplete: function(twn) {
		camGame.shake(0.02, 0.1); // source gates on ClientPrefs.flashing
		FlxG.sound.play(Paths.sound('shellhit'));
		FlxTween.tween(PlayState.instance, {health: health - 0.4}, 0.2, {ease: FlxEase.quadOut});
		mmRedS.animation.play('hit');
		new FlxTimer().start(0.5, function(tmr) {
			mmRedS.x = -200;
		});
	}});
}

// 11658-11662: `getspeed = SONG.speed; FlxTween.tween(SONG, {speed: value2},
// 16);` - the 16-second song-speed ramp. `scrollSpeed` is the engine's live song
// speed (the built-in 'Scroll Speed Change' event tweens the same field), so the
// tween lands on the state's instance value rather than the static chart data.
function mmSongSpeed(target:Float) {
	var ps = PlayState.instance;
	if (ps == null || Reflect.field(ps, "scrollSpeed") == null) return;
	FlxTween.tween(ps, {scrollSpeed: target}, 16);
}

// ---------------------------------------------------------------------------
// camEst - the layer case 10's curtain lives on (11667-11672)
// ---------------------------------------------------------------------------
// Psych's camEst is a bare `new FlxCamera()` created right after camGame (827)
// and added before camHUD (833-836): the same view rectangle, its canvas
// composited between the world's and the HUD's. Codename ships only camGame and
// camHUD, and in flixel a camera's canvas is composited in `FlxG.cameras.list`
// order - so the port adds a camera of its own the normal way
// (`defaultDraw = false`, the world is not redrawn into it) and then slides it
// in at camHUD's own index, i.e. camEst's slot. The plate on it therefore covers
// the world and the characters but not the HUD (the notes, icons and health
// bar), which is what the fork's curtain does.
var mmEstCam:FlxCamera = null;
var mmEstPlaced:Bool = false;
var mmEstWarned:Bool = false;

// `Reflect.field` rather than `FlxG.cameras.list` directly: the array is a real
// field of the engine's camera front end, but a lookup that comes back empty
// must leave the camera where it is, not take the script down with it (the same
// guard exeport.hx/demiseport.hx use).
function mmCamList() {
	return Reflect.field(FlxG.cameras, "list");
}

function mmEst():FlxCamera {
	if (mmEstCam == null) {
		// camEst and camHUD are the same rectangle in Psych (both are bare
		// FlxCameras there), so the layer is pinned to camHUD's size rather than
		// FlxG's: if the engine ever resizes the HUD camera the plate follows it,
		// and a stale rectangle cannot crop a full-screen cover down to a corner.
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
			trace("[MM racing] camEst: no FlxG.cameras.list - the curtain stays above camHUD");
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

// 1905-1913: `fernan` - a 'mario/Races/fernan' plate at (50, 20) on camEst,
// scaled 0.9, built in the stage's create block and **added only when the roll
// passes**: `if (FlxG.random.bool(0.05)) add(fernan);`. Flixel's `bool` takes a
// percentage from 0 to 100 (`float(0, 100) < Chance`, the same in the fork's
// flixel 4.11 and in this engine's 5.x), so 0.05 is 0.05% - the fork's own
// unit slip, which is why the egg is all but never seen there either. Kept
// literal, the way this port keeps the fork's other quirk comparisons; a plain
// `5` would be the 5% the line looks like it wants.
var mmFernan = null;

function mmGetFernan() {
	if (mmFernan == null) {
		mmFernan = new FlxSprite(50, 20);
		mmFernan.loadGraphic(Paths.image('mario/Races/fernan'));
		mmFernan.setGraphicSize(Std.int(mmFernan.width * 0.9));
		mmFernan.antialiasing = true; // ClientPrefs.globalAntialiasing, taken as on
		mmFernan.cameras = [mmEst()];
		// The sprite is built either way; only the draw-list add is rolled.
		if (FlxG.random.bool(0.05)) add(mmFernan);
	}
	return mmFernan;
}

// The curtain itself (11668-11672): `new FlxSprite().makeGraphic(FlxG.width,
// FlxG.height, FlxColor.BLACK)`, `setGraphicSize(width * 10)` so the cover
// cannot depend on the window's size, `scrollFactor.set(0, 0)` to fix it in
// screen space, on camEst, added to the draw list. The source builds a *fresh*
// sprite every time case 10 fires and keeps the latest in `blackBarThingie`; the
// modern chart sends it once (113.1s), so this port builds it once and hands
// back what it already has - a second call could only re-black an already black
// screen while leaking a sprite into the draw list.
var mmCurtain = null;

function mmBlackCurtain() {
	if (mmCurtain == null) {
		mmCurtain = new FlxSprite(0, 0);
		mmCurtain.makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		mmCurtain.setGraphicSize(Std.int(mmCurtain.width * 10));
		mmCurtain.scrollFactor.set(0, 0);
		mmCurtain.cameras = [mmEst()];
		add(mmCurtain);
	}
	return mmCurtain;
}

// `noCount = true; noHUD = true;` (1883-1884): the source never builds its
// 3-2-1-GO sprites and hides the HUD from creation. The engine's countdown is
// dropped by cancelling `onCountdown` (PlayState.hx builds the sprites there),
// and camHUD starts at alpha 0 - the modern chart's own 'Ocultar HUD' 2 brings
// it back at 8.79s, the old chart's at its own mark.
function onCountdown(event) {
	event.cancelled = true;
}

function postCreate() {
	// `noHUD = true` (1884) -> 5630-5633.
	if (camHUD != null) camHUD.alpha = 0;
	// 4883-4900 / 5556-5568: both HUD sprites are built at create, the box parked
	// off screen until case 2.
	mmGetCaja();
	mmGetRedS();
	// 1911-1913: the easter-egg plate, rolled for here (the source's create
	// switch is the same load-time moment).
	mmGetFernan();
}

function onEvent(event) {
	if (event.event.name != "Triggers Race Traitors" && event.event.name != "Triggers Universal") return;
	var trigger = Std.parseInt(event.event.params[0]);
	if (trigger == null || Math.isNaN(trigger)) trigger = 0;
	var value2:String = (event.event.params.length > 1) ? StringTools.trim(Std.string(event.event.params[1])) : "";
	// 11515-11518: the source parses value2 as a Float too - case 8 tweens the
	// song speed to it.
	var triggerBox:Float = Std.parseFloat(value2);
	if (Math.isNaN(triggerBox)) triggerBox = 0;

	switch (trigger) {
		case 0:
			// 11516-11519: the source turns the opponent into racet1 here, but only
			// on the modern song - the line is gated on the song name, and the old
			// chart reaches him through case 1's own swaps.
			if (!mmIsRaceOld()) mmChangeChar(1, "racet1");
			// 11520-11527: the drop-in. `jodaflota` is what arms case 1's
			// `race` ping-pong, so it has to land on the tween's completion.
			var d0 = mmDadChar();
			if (d0 != null)
				FlxTween.tween(d0, {x: 50}, 1, {ease: FlxEase.expoOut, onComplete: function(twn) { mmJodaFlota = true; }});
		case 1:
			// 11528-11570: the racers' swap.
			if (value2 == "") return;
			var d = mmDadChar();
			if (d != null && d.curCharacter == value2) return;
			mmChangeChar(1, value2);
			var nd = mmDadChar();
			if (nd == null) return;
			nd.x = 50;
			// 11547-11551: the old song forces the two HUD icons. The names are
			// the source's literal 'icon-bfr' / 'icon-race', which is exactly what
			// this build's `setIcon` wants - it asks for `icons/<name>`
			// (`HealthIcon.hx`), and the mod ships `images/icons/icon-bfr.png` /
			// `icon-race.png`.
			if (mmIsRaceOld()) {
				// Instance-member guards are false on cpp (see PORT_NOTES.md).
				if (Reflect.field(iconP1, "setIcon") != null) iconP1.setIcon("icon-bfr");
				if (Reflect.field(iconP2, "setIcon") != null) iconP2.setIcon("icon-race");
			}
			// 11555-11567: once the box is down, 'race' bounces out and back. The
			// source's `upDad` sentinel resolves to dad.x (just parked at 50).
			if (nd.curCharacter == "race" && mmJodaFlota)
				FlxTween.tween(nd, {x: nd.x + 100}, 1.5, {ease: FlxEase.quadInOut, type: FlxTween.PINGPONG});
		case 2:
			// 11572-11577: the box drops in from its parked row, spinning.
			if (mmCaja == null) mmGetCaja();
			mmCaja.animation.play('random');
			FlxTween.tween(mmCaja, {y: mmHudY(mmCaja, 50, 570)}, 1, {ease: FlxEase.quadInOut});
		case 3:
			// 11579-11586.
			mmCajaDrop();
			mmCajaAnim('shell');
		case 4:
			// 11587-11594.
			mmCajaDrop();
			mmCajaAnim('ghost');
		case 5:
			// 11595-11602.
			mmCajaDrop();
			mmCajaAnim('bomb');
		case 6:
			// 11603-11612: back off screen, the other way from case 2.
			if (mmCaja != null) FlxTween.tween(mmCaja, {y: mmHudY(mmCaja, -200, 760)}, 1, {ease: FlxEase.quadInOut});
		case 7:
			// 11613-11643: the shell itself.
			mmShellHit();
		case 8:
			// 11644-11662: the '1up' box and the 16-second song-speed ramp.
			mmCajaDrop();
			mmCajaAnim('1up');
			mmSongSpeed(triggerBox);
		case 9:
			// 11663-11665: the KRAAAATOOOOOS sign (a stage-XML sprite, so it is
			// already in the world layer) slides from its parked 2460 to 460.
			FlxTween.tween(xboxigualGOD, {x: 460}, 0.5, {ease: FlxEase.quadIn});
		case 10:
			// 11667-11672: the end-of-song blackout.
			mmBlackCurtain();
	}
}
// === end MM stage triggers ===
