// 'GF Sing' note type - the girlfriend sings the note instead of the
// opponent/player. Ported from Mario's Madness (source/PlayState.hx).
function singName(dir:Int):String {
	switch (dir) {
		case 0: return "singLEFT";
		case 1: return "singDOWN";
		case 2: return "singUP";
		default: return "singRIGHT";
	}
}

function onNoteHit(event) {
	if (event.noteType != "GF Sing" || gf == null) return;
	event.preventAnim();
	gf.playSingAnim(event.direction, event.animSuffix == null ? "" : event.animSuffix);
	// Resetting holdTimer starts a fresh sing hold, it does not expire it.
	gf.lastHit = Conductor.songPosition;
}

function onPlayerMiss(event) {
	if (event.noteType != "GF Sing" || gf == null) return;
	event.preventAnim();
	gf.playAnim(singName(event.direction) + "miss", true);
}
