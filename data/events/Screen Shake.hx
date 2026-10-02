// 'Screen Shake' - shakes the game and HUD cameras. Ported from Mario's
// Madness (source/PlayState.hx:9290-9310: value1 = game camera
// "duration, intensity", value2 = HUD camera "duration, intensity").
//
// The source's target list is [camGame, camHUD, camEst] but it only has the two
// values, so the loop ends on a missing array element - the two pairs are all it
// can ever apply, which is what this port does. Its `if (ClientPrefs.flashing)`
// gate is not reproducible (ClientPrefs is not script-readable, the same
// limitation virtual.hx records), so a player who turned flashes off still gets
// these shakes; three of the 35 chart uses are the single-value form
// ('', '0.3, 0.01'), which shakes only the HUD in both the source and here.
function onEvent(event) {
	if (event.event.name != "Screen Shake") return;

	var targets = [camGame, camHUD];
	var values = [event.event.params[0], event.event.params[1]];

	for (i in 0...targets.length) {
		var val = values[i];
		if (val == null || val == "") continue;
		var split = Std.string(val).split(",");
		if (split.length < 2) continue;
		var duration = Std.parseFloat(StringTools.trim(split[0]));
		var intensity = Std.parseFloat(StringTools.trim(split[1]));
		if (duration == null || Math.isNaN(duration)) duration = 0;
		if (intensity == null || Math.isNaN(intensity)) intensity = 0;
		if (duration > 0 && intensity != 0)
			targets[i].shake(intensity, duration);
	}
}
