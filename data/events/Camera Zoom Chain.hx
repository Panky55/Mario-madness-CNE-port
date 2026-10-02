// 'Camera Zoom Chain' - pulses the cameras (and optionally shakes them) every
// `timeBeat` beats for `totalBeat` triggers.
//
// Ported from Mario's Madness (source/PlayState.hx, case 'Camera Zoom Chain'):
//   value1 = "gameZoom, hudZoom[, gameShake, hudShake]"
//   value2 = "beats, timeBeat"
//
// The source stores toBeat/timeBeat and then, in its beat loop:
//
//   if (totalBeat > 0 && curBeat % timeBeat == 0) {
//       triggerEventNote('Add Camera Zoom', '' + gameZ, '' + hudZ);
//       totalBeat -= 1;
//   }
//
// i.e. one pulse every `timeBeat` beats, `totalBeat` pulses in total. Applying
// the pulse on every beat (and counting down per beat) multiplies both the
// number and the rate of pulses, which is what made the chain overshoot.

var chainGameZoom:Float = 0.015;
var chainHudZoom:Float = 0.03;
var chainGameShake:Float = 0;
var chainHudShake:Float = 0;
var chainShake:Bool = false;
// `timeBeat` is a Float in the source (`var timeBeat:Float = 1;`, assigned from
// the parsed value2), so a fractional interval is legal there; it is kept as a
// float here too rather than rounded to an Int.
var chainTotalBeat:Int = 0;
var chainTimeBeat:Float = 1;

function mmChainNum(v, def) {
	var f = Std.parseFloat(StringTools.trim(Std.string(v)));
	if (f == null) return def;
	if (f != f) return def; // NaN (only NaN is not equal to itself)
	return f;
}

function onEvent(event) {
	if (event.event.name != "Camera Zoom Chain") return;

	var s1 = Std.string(event.event.params[0]).split(",");
	var gz = Std.parseFloat(StringTools.trim(s1[0]));
	var hz = (s1.length > 1) ? Std.parseFloat(StringTools.trim(s1[1])) : Math.NaN;
	// The source parses both values and then stores the *defaults* - 9188-9189:
	//
	//     if (!Math.isNaN(gameZoom)) gameZ = 0.015;
	//     if (!Math.isNaN(hudZoom))  hudZ  = 0.03;
	//
	// (the `gameZ = gameZoom` those lines were clearly meant to be never
	// happens), so the numbers in the chart are inert: every chain in the mod
	// pulses 0.015 game / 0.03 HUD, and the parsed pair only decides whether a
	// pulse happens at all. Reading them at face value is what made this chart's
	// 143.86s chain (value1 "0.25, 0.6, 0.0015, 0.0015") pulse 17x the game zoom
	// and 20x the HUD zoom the source ever did - every beat, for 64 beats.
	if (gz != null && !Math.isNaN(gz)) chainGameZoom = 0.015;
	if (hz != null && !Math.isNaN(hz)) chainHudZoom = 0.03;
	if (s1.length >= 4) {
		chainGameShake = mmChainNum(s1[2], 0.003);
		chainHudShake = mmChainNum(s1[3], 0.003);
		chainShake = true;
	} else {
		chainShake = false;
	}

	var s2 = Std.string(event.event.params[1]).split(",");
	chainTotalBeat = Std.int(mmChainNum(s2[0], 4));
	chainTimeBeat = (s2.length > 1) ? mmChainNum(s2[1], 1) : 1;
	if (chainTimeBeat < 1) chainTimeBeat = 1;
}

function beatHit(curBeat) {
	if (chainTotalBeat <= 0) return;
	if (curBeat % chainTimeBeat != 0) return;

	chainTotalBeat--;

	// 16166-16167: the chain's shake is not a fixed duration - it fires a Screen
	// Shake whose *duration* is half a beat times `timeBeat`, with the game camera
	// taking value1 and the HUD value2. That is where the port's hardcoded 0.2
	// came from; at 130bpm a half beat is 0.2308s.
	var shakeDur:Float = (1 / (Conductor.bpm / 60)) * 0.5 * chainTimeBeat;

	camGame.zoom += chainGameZoom;
	camHUD.zoom += chainHudZoom;

	if (chainShake) {
		camGame.shake(chainGameShake, shakeDur);
		camHUD.shake(chainHudShake, shakeDur);
	}
}
