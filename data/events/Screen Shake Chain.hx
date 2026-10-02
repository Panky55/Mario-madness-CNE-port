// 'Screen Shake Chain' - one shake per beat while the chain runs.
// Ported from Mario's Madness (source/PlayState.hx):
//
//   9213-9225   case 'Screen Shake Chain': value1 = "gameShake, hudShake",
//               value2 = number of beats (stored in `totalShake` / `gameShake` /
//               `hudShake`)
//   16172-16175 beatHit: `totalShake -= 1` every beat, each one firing
//
//                   triggerEventNote('Screen Shake',
//                       (1 / (Conductor.bpm / 60)) + ', ' + gameShake, ...);
//
//               i.e. the shake lasts **one beat**, so its length follows the
//               song's tempo (`Conductor.bpm`) rather than a fixed number - the
//               port started with a hardcoded 0.2s, which is under half a beat at
//               Promotion's 130bpm and well under a beat at the 155bpm its second
//               half runs at.
var chainGameShake:Float = 0;
var chainHudShake:Float = 0;
var chainBeats:Int = 0;

function onEvent(event) {
	if (event.event.name != "Screen Shake Chain") return;
	var split = Std.string(event.event.params[0]).split(",");
	if (split.length >= 2) {
		chainGameShake = Std.parseFloat(StringTools.trim(split[0]));
		chainHudShake = Std.parseFloat(StringTools.trim(split[1]));
		if (chainGameShake == null || Math.isNaN(chainGameShake)) chainGameShake = 0;
		if (chainHudShake == null || Math.isNaN(chainHudShake)) chainHudShake = 0;
	}
	chainBeats = Std.parseInt(event.event.params[1]);
	if (chainBeats == null || Math.isNaN(chainBeats)) chainBeats = 0;
}

function beatHit(curBeat) {
	if (chainBeats <= 0) return;
	chainBeats--;

	var beat:Float = 1 / (Conductor.bpm / 60);
	if (chainGameShake != 0) camGame.shake(chainGameShake, beat);
	if (chainHudShake != 0) camHUD.shake(chainHudShake, beat);
}
