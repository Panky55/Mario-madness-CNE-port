// 'Yoshi Note' - drives the "funnylayer0" stage character (a Yoshi that sings
// along). Ported from Mario's Madness (source/PlayState.hx:8444).
//
// The source handles this note type inside its *opponent* note-hit chain
// (`else if (daNote.noteType == 'Yoshi Note')`), so the opponent character never
// plays its own sing animation for one - only funnylayer0 does. Preventing the
// animation only inside the exesequel/betamansion branch left w4r singing along
// with yoshi through the act 2 section, so it is now unconditional, exactly like
// the `else` chain it replaces. GF still gets the note on exesequel/betamansion,
// which is the branch below.
function singName(dir:Int):String {
	switch (dir) {
		case 0: return "singLEFT";
		case 1: return "singDOWN";
		case 2: return "singUP";
		default: return "singRIGHT";
	}
}

function onNoteHit(event) {
	if (event.noteType != "Yoshi Note") return;

	// Unconditional: the opponent does not sing a Yoshi Note on any stage.
	event.preventAnim();

	if (curStage == "exesequel" || curStage == "betamansion") {
		if (gf != null) {
			gf.playSingAnim(event.direction, "");
			gf.lastHit = Conductor.songPosition; // source's holdTimer = 0 starts a new hold
		}
	}

	// `Reflect.hasField` is false for every member of a class *instance* on the
	// cpp build, so this guard was dead there (see PORT_NOTES.md).
	if (Reflect.field(PlayState.instance, "onYoshiNote") != null)
		Reflect.callMethod(PlayState.instance, Reflect.field(PlayState.instance, "onYoshiNote"), [event.direction]);
}
