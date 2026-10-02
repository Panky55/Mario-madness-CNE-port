// 'GF Duet' note type - both the singing character and the girlfriend play
// the sing animation. Ported from Mario's Madness (source/PlayState.hx).
//
// The source sets `holdTimer = 0` on both characters. Codename's Character has
// no `holdTimer`; its equivalent pair is `lastHit` + `holdTime`, and `tryDance()`
// holds the sing animation while `lastHit + stepCrochet * holdTime >= songPosition`.
// Resetting Psych's holdTimer starts a fresh hold; CNE must use SING context
// and the current song position, not a timestamp far in the past.
function singName(dir:Int):String {
	switch (dir) {
		case 0: return "singLEFT";
		case 1: return "singDOWN";
		case 2: return "singUP";
		default: return "singRIGHT";
	}
}

function onNoteHit(event) {
	if (event.noteType != "GF Duet") return;
	event.preventAnim();

	var anim = singName(event.direction);

	if (event.character != null) {
		event.character.playSingAnim(event.direction, event.animSuffix == null ? "" : event.animSuffix);
		event.character.lastHit = Conductor.songPosition; // source's holdTimer = 0
	}
	// `gf` is strumLines.members[2].characters[0]; non-null only when the chart
	// has a girlfriend strumline (see PORT_NOTES).
	if (gf != null) {
		gf.playSingAnim(event.direction, event.animSuffix == null ? "" : event.animSuffix);
		gf.lastHit = Conductor.songPosition; // source's holdTimer = 0
	}
}
